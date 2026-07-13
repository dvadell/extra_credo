defmodule Credo.Check.Extra.NoPubsubWithoutConnected do
  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @moduledoc """
  Extra Rule #3: CHECK `connected?/1` before PubSub subscribe.

  Mount runs twice (init + socket connected). Unconditional `subscribe/3` calls
  cause double-delivery of messages. Every subscribe must be inside a
  `if connected?(socket)` block or equivalent guard.

  ## Examples (non-compliant)

      def mount(_params, _session, socket) do
        Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")  # ❌ runs twice
        {:ok, socket}
      end

  ## Examples (compliant)

      def mount(_params, _session, socket) do
        if connected?(socket) do
          Phoenix.PubSub.subscribe(MyApp.PubSub, "topic")
        end
        {:ok, socket}
      end
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    if String.ends_with?(source_file.filename, "_live.ex") do
      ASTTraversal.collect_issues_with_path(source_file, &check_subscribe/3)
    else
      []
    end
  end

  defp check_subscribe(call, path, source_file) when is_tuple(call) do
    if is_subscribe_call?(call) and not in_connected_guard?(path) do
      issue(source_file, call)
    else
      nil
    end
  end

  defp is_subscribe_call?({:., _, [inner, :subscribe]}) do
    case inner do
      {:__aliases__, _, [:Phoenix, :PubSub]} -> true
      _ -> false
    end
  end

  defp is_subscribe_call?({:subscribe, _, _}), do: true
  defp is_subscribe_call?(_), do: false

  defp in_connected_guard?(path) do
    Enum.any?(path, &has_connected_guard?/1)
  end

  defp has_connected_guard?({:if, _, [condition | _]}) do
    is_connected_call?(condition)
  end

  defp has_connected_guard?(_), do: false

  defp is_connected_call?({:connected?, _, args}) when is_list(args), do: true

  defp is_connected_call?({{:., _, [inner, :connected?]}, _, _args}) do
    case inner do
      {:__aliases__, _, [:Phoenix, :LiveView]} -> true
      {:__aliases__, _, [:Phoenix, :LiveView, :Socket]} -> true
      _ -> false
    end
  end

  defp is_connected_call?(_), do: false

  defp issue(source_file, call) do
    meta =
      case call do
        {_, meta, _} when is_map(meta) -> meta
        _ -> %{}
      end

    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      column: meta[:column] || 0,
      trigger: Issue.no_trigger(),
      message: """
      PubSub.subscribe called without connected? guard. Mount runs twice, causing\n" <>
      "double-delivery. Wrap in `if connected?(socket) do ... end`.\n\n" <>
      "  if connected?(socket) do\n" <>
      "    Phoenix.PubSub.subscribe(MyApp.PubSub, \"topic\")\n" <>
      "  end\n"
      """
    }
  end
end
