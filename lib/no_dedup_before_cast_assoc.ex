defmodule Credo.Check.Extra.NoDedupBeforeCastAssoc do
  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @moduledoc """
  DMV Rule #17: Deduplicate before cast_assoc.

  `cast_assoc/3` with a list input should be deduplicated first to avoid
  inserting duplicate associated records. Flags `cast_assoc` calls where the
  input is a variable (not a literal list) and there's no preceding dedup
  step (`Enum.uniq/1`, `Enum.uniq_by/2`, `Enum.dedup/1`, `Enum.dedup_by/2`).

  ## Examples (non-compliant)

      changeset = Changeset.cast_assoc(changeset, :items, with: &changeset/1)  # ❌ items may have duplicates

  ## Examples (compliant)

      items = Enum.uniq_by(items, & &1.id)
      changeset = Changeset.cast_assoc(changeset, :items, with: &changeset/1)  # ✅ deduped
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  @dedup_functions ~w(uniq uniq_by dedup dedup_by)a

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues_with_path(
      source_file,
      &check_cast_assoc/3
    )
  end

  defp check_cast_assoc(call, path, source_file) when is_tuple(call) do
    if is_cast_assoc_call?(call) and not preceded_by_dedup?(call, path) do
      issue(source_file, call)
    else
      nil
    end
  end

  defp is_cast_assoc_call?({:., _, [inner, :cast_assoc]}) do
    case inner do
      {:__aliases__, _, [:Ecto, :Changeset]} ->
        true

      {:__aliases__, _, segments} when length(segments) >= 2 ->
        List.last(segments) == :Changeset

      _ ->
        false
    end
  end

  defp is_cast_assoc_call?({:cast_assoc, _, _}), do: true
  defp is_cast_assoc_call?(_), do: false

  defp preceded_by_dedup?(call, path) do
    case Enum.find(path, fn
           {:stmts, _} -> true
           _ -> false
         end) do
      {:stmts, stmts} ->
        idx = Enum.find_index(stmts, &ASTTraversal.contains_node?(&1, call))

        if idx do
          stmts
          |> Enum.take(idx)
          |> Enum.any?(&contains_dedup?/1)
        else
          # If not found directly in sibling list, it might be in a piped expression
          # or we can check the ancestors
          Enum.any?(path, &contains_dedup?/1)
        end

      _ ->
        Enum.any?(path, &contains_dedup?/1)
    end
  end

  defp contains_dedup?(ast) do
    case ast do
      {{:., _, [_, func]}, _, _} when func in @dedup_functions ->
        true

      {func, _, _} when func in @dedup_functions ->
        true

      {:., _, [_, func]} when func in @dedup_functions ->
        true

      ast when is_tuple(ast) ->
        ast
        |> Tuple.to_list()
        |> Enum.any?(&contains_dedup?/1)

      ast when is_list(ast) ->
        Enum.any?(ast, &contains_dedup?/1)

      _ ->
        false
    end
  end

  defp issue(source_file, call) do
    {_, meta, [_ | args]} = call

    assoc_name =
      case args do
        [name, _] when is_atom(name) -> Atom.to_string(name)
        _ -> "association"
      end

    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      column: meta[:column] || 0,
      trigger: Issue.no_trigger(),
      message: """
        cast_assoc(:#{assoc_name}) without deduplication. If the input list\n" <>
        "contains duplicates, cast_assoc will insert duplicate associated records.\n\n" <>
        "Deduplicate the list before passing to cast_assoc:\n\n" <>
        "  items = Enum.uniq_by(items, & &1.id)\n" <>
        "  changeset = cast_assoc(changeset, :#{assoc_name}, with: &changeset/1)\n"
      """
    }
  end
end
