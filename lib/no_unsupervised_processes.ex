
  defmodule Credo.Check.Extra.NoUnsupervisedProcesses do
  @moduledoc """
  Supervise all long-lived processes.

  Flags bare `GenServer.start_link`, `Agent.start_link`, `Task.start`,
  `Task.start_link`, `GenServer.start` calls that are not inside a supervisor's
  `children` list. Long-lived processes should always be supervised so they can
  be restarted on failure.

  ## Examples (non-compliant)

      def start_link(opts) do
        GenServer.start_link(MyWorker, opts, name: __MODULE__)  # ❌ no supervisor
      end

  ## Examples (compliant)

      def children(_opts) do
        [
          {MyWorker, opts}  # ✅ supervised via Supervisor
        ]
      end
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @start_functions ~w(start_link start)a
  @process_modules ~w(GenServer Agent Task)a

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues_with_path(
      source_file,
      &check_unsupervised_process/3
    )
  end

  defp check_unsupervised_process(call, path, source_file) when is_tuple(call) do
    if process_start_call?(call) and not in_supervisor_children?(path) do
      issue(source_file, call)
    else
      nil
    end
  end

  defp process_start_call?({:., _, [inner, func]}) do
    if func in @start_functions do
      case inner do
        {:__aliases__, _, segments} ->
          List.last(segments) in @process_modules

        _ ->
          false
      end
    else
      false
    end
  end

  defp process_start_call?(_), do: false

  defp in_supervisor_children?(path) do
    Enum.any?(path, fn
      {:def, _, [{:children, _, _} | _]} -> true
      _ -> false
    end)
  end

  defp issue(source_file, call) do
    {_, meta, [{:__aliases__, _, segments}, func]} = call

    mod = to_string(List.last(segments))
    func_str = Atom.to_string(func)

    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      column: meta[:column] || 0,
      trigger: Issue.no_trigger(),
      message: """
        #{mod}.#{func_str} called outside a supervisor's children list. Long-lived\n" <>
        "processes must be supervised so they can be restarted on failure.\n\n" <>
        "Add the process to a Supervisor's children list:\n\n" <>
        "  def children(_opts) do\n" <>
        "    [{#{mod}, opts}]\n" <>
        "  end\n"
      """
    }
  end
end
