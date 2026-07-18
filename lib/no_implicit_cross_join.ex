defmodule Credo.Check.Extra.NoImplicitCrossJoin do
  @moduledoc """
  Extra Rule #15: NO IMPLICIT CROSS JOINS in Ecto queries.

  `from(a in A, b in B)` without a `join:` clause creates a Cartesian product
  — every row in A paired with every row in B. Use explicit `join: ... on: ...`
  instead.

  ## Examples (non-compliant)

      from(a in Account, b in Booking)  # [cross] implicit cross join

  ## Examples (compliant)

      from(a in Account, join: b in assoc(a, :bookings), on: true)  # [check] explicit join
  """

  use Credo.Check,
    category: :design,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues(source_file, &check_cross_join/2)
  end

  defp check_cross_join({:from, meta, args}, source_file) when is_list(args) do
    in_count = Enum.count(args, fn arg -> is_tuple(arg) && elem(arg, 0) == :in end)
    has_explicit_join? = Enum.any?(args, &join_clause?/1)

    if in_count > 1 and not has_explicit_join? do
      issue(source_file, meta)
    else
      nil
    end
  end

  defp check_cross_join(_, _source_file), do: nil

  defp join_clause?([{:join, _} | _]), do: true
  defp join_clause?([{:left_join, _} | _]), do: true
  defp join_clause?([{:right_join, _} | _]), do: true
  defp join_clause?([{:cross_join, _} | _]), do: true
  defp join_clause?(_), do: false

  defp issue(source_file, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
      check: __MODULE__,
      category: :design,
      message: """
        Implicit cross join detected — from(a in A, b in B) without join: on: ...
        creates a Cartesian product. Use explicit join with an on: condition.\n\n" <>
        "  from(a in Account,\n" <>
        "       join: b in assoc(a, :bookings),\n" <>
        "       on: true)\n"
      """
    }
  end
end
