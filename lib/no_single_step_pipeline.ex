defmodule Credo.Check.Extra.NoSingleStepPipeline do
  @moduledoc """
  Forbid pipelines with only one function call.

  `Credo.Check.Refactor.PipeChainStart` requires pipelines to start with a
  variable. This check goes further: when a pipeline has exactly two members
  AND starts with a variable (i.e. `PipeChainStart` would pass), it should be
  rewritten as a direct function call.

  ## Examples (non-compliant)

      user |> update(opts)
      data |> parse()
      result |> IO.inspect()

  ## Examples (compliant)

      update(user, opts)
      parse(data)
      IO.inspect(result)

      # Multi-step pipelines are fine
      user
      |> update(opts)
      |> save()

      # Pipeline starts with a function — PipeChainStart already handles this
      update(opts) |> save()
  """

  use Credo.Check,
    category: :design,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues_with_path(source_file, fn ast, path, source_file ->
      check_pipe(ast, path, source_file)
    end)
  end

  # A local function call: {name, meta, args} where args is a list
  defp function_start?({_name, _meta, args}) when is_list(args), do: true
  # A remote function call: {{:., dot_meta, [mod, fun]}, meta, args}
  defp function_start?({{:., _, _}, _, _}), do: true
  defp function_start?(_), do: false

  defp check_pipe({:|>, meta, [lhs, _rhs]}, path, source_file) do
    parent_is_pipe? = path != [] and match?({:|>, _, _}, hd(path))

    if parent_is_pipe? or match?({:|>, _, _}, lhs) or function_start?(lhs) do
      nil
    else
      %Issue{
        filename: source_file.filename,
        line_no: meta[:line] || 0,
        trigger: Issue.no_trigger(),
        check: __MODULE__,
        category: :design,
        message:
          "Pipelines with a single function add no readability benefit. Use a direct call instead."
      }
    end
  end

  defp check_pipe(_ast, _path, _source_file), do: nil
end
