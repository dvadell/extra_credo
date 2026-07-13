defmodule Credo.Check.IronLaw.NoBareChangesetError do
  @moduledoc """
  Iron Law #24: MATCH `{:error, %Ecto.Changeset{}}` EXPLICITLY.

  Bare `{:error, _}` pattern matching in `handle_event` callbacks swallows
  changeset errors. The form never re-renders validation errors because the
  changeset is lost in the generic `_` match.

  ## Examples (non-compliant)

      def handle_event("save", params, socket) do
        case MyApp.update_user(user, params) do
          {:ok, user} -> {:noreply, socket}
          {:error, _} -> {:noreply, socket}  # ❌ changeset errors lost
        end
      end

  ## Examples (compliant)

      def handle_event("save", params, socket) do
        case MyApp.update_user(user, params) do
          {:ok, user} -> {:noreply, socket}
          {:error, %Ecto.Changeset{} = cs} ->  # ✅ re-renders form with errors
            {:noreply, assign(socket, form: to_form(cs))}
        end
      end
  """

  use Credo.Check, [category: :consistency,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    unless String.ends_with?(source_file.filename, "_live.ex") do
      []
    end

    IronLawCredo.ASTTraversal.collect_issues(source_file, &check_bare_changeset_error/2)
  end

  defp check_bare_changeset_error({:def, meta, [{:handle_event, _, [_event, _params, _socket]} | body]}, source_file) do
    case find_bare_error(body) do
      nil -> nil
      line -> issue(source_file, line || meta[:line] || 0)
    end
  end

  defp check_bare_changeset_error(_, _source_file), do: nil

  defp find_bare_error(body) do
    body
    |> IronLawCredo.ASTTraversal.flatten()
    |> Enum.find_value(fn
      # In case expressions, {:error, _} is represented as error: {:_, ...}
      {error, {:_, meta, _}} when error == :error ->
        meta[:line]
      # Also match tuple form {:error, {:_, ...}}
      {:error, {:_, meta, _}} ->
        meta[:line]
      # {:error, var} as keyword: error: {var, meta, []}
      {error, {var, meta, _}} when error == :error and is_atom(var) and var != :changeset and var != :cs ->
        meta[:line]
      # {:error, var} as tuple
      {:error, {var, meta, _}} when is_atom(var) and var != :changeset and var != :cs ->
        meta[:line]
      _ -> nil
    end)
  end

  defp issue(source_file, line) do
    %Issue{
      filename: source_file.filename,
      line_no: line,
      trigger: Issue.no_trigger(),
      message: """
      Bare {:error, _} in handle_event — changeset errors are swallowed and the\n" <>
      "form won't re-render validation errors. Match {:error, %Ecto.Changeset{}\n" <>
      "= cs} explicitly to pass the changeset to to_form/1.\n\n" <>
      "  {:error, %Ecto.Changeset{} = cs} ->\n" <>
      "    {:noreply, assign(socket, form: to_form(cs))}\n"
    """
    }
  end
end