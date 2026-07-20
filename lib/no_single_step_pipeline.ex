defmodule Credo.Check.Extra.NoSingleStepPipeline do
  @moduledoc """
  Forbid pipelines with only one function call.

  A single-step pipeline like `user |> update(opts)` adds no readability benefit
  over the direct call `update(user, opts)`. Pipelines are useful when chaining
  multiple operations, but a lone pipe is just noise.

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

  defp check_pipe({:|>, meta, [lhs, _rhs]}, path, source_file) do
    parent_is_pipe? = path != [] and match?({:|>, _, _}, hd(path))

    if parent_is_pipe? or match?({:|>, _, _}, lhs) do
      nil
    else
      %Issue{
        filename: source_file.filename,
        line_no: meta[:line] || 0,
        trigger: Issue.no_trigger(),
        check: __MODULE__,
        category: :design,
        message: """
        Avoid a pipeline with only one function.

        A single-step pipe adds no readability benefit over a direct call.
        Only use the pipe operator when chaining multiple operations.

          # Instead of this:
          user |> update(opts)

          # Write this:
          update(user, opts)
        """
      }
    end
  end

  defp check_pipe(_ast, _path, _source_file), do: nil
end
