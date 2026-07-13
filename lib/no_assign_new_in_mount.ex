defmodule Credo.Check.Extra.NoAssignNewInMount do
  alias Credo.Issue
  alias ExtraCredo.ASTTraversal

  @moduledoc """
  Extra Rule #21: NEVER use `assign_new` for values refreshed every mount.

  `assign_new/3` skips the function if the key already exists. In `mount/3`
  which runs on every page load, this means stale values persist across
  requests. Use `assign/3` for values that must be refreshed on every mount.

  ## Examples (non-compliant)

      def mount(_params, _session, socket) do
        socket
        |> assign_new(:locale, fn -> get_locale() end)  # ❌ stale on revisit
        |> assign_new(:current_user, fn -> load_user(socket) end)  # ❌ stale

  ## Examples (compliant)

      def mount(_params, _session, socket) do
        socket
        |> assign(:locale, get_locale())  # ✅ always refresh
        |> assign(:current_user, load_user(socket))  # ✅ always refresh
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    if String.ends_with?(source_file.filename, "_live.ex") do
      ASTTraversal.collect_issues(source_file, &check_assign_new_in_mount/2)
    else
      []
    end
  end

  defp check_assign_new_in_mount(
         {:def, meta, [{:mount, _, [_params, _session, _socket]} | body]},
         source_file
       ) do
    case find_assign_new(body) do
      nil -> nil
      {key, line} -> issue(source_file, key, line || meta[:line] || 0)
    end
  end

  defp check_assign_new_in_mount(_, _source_file), do: nil

  defp find_assign_new(body) do
    body
    |> ASTTraversal.flatten()
    |> Enum.find_value(fn
      {:assign_new, meta, [key, _]} ->
        {key, meta[:line]}

      _ ->
        nil
    end)
  end

  defp issue(source_file, key, line) do
    key_str =
      case key do
        name when is_atom(name) -> to_string(name)
        _ -> "key"
      end

    %Issue{
      filename: source_file.filename,
      line_no: line,
      trigger: Issue.no_trigger(),
      message: """
      assign_new(:#{key_str}) in mount — value won't refresh on subsequent visits.
      assign_new/3 skips if the key exists, causing stale data. Use assign/3
      for values that must update every mount (locale, current_user, etc.).

        assign(socket, :#{key_str}, get_#{key_str}())
      """
    }
  end
end
