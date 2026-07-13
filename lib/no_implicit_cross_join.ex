defmodule Credo.Check.IronLaw.NoImplicitCrossJoin do
  @moduledoc """
  Iron Law #15: NO IMPLICIT CROSS JOINS in Ecto queries.

  `from(a in A, b in B)` without a `join:` clause creates a Cartesian product
  — every row in A paired with every row in B. Use explicit `join: ... on: ...`
  instead.

  ## Examples (non-compliant)

      from(a in Account, b in Booking)  # ❌ implicit cross join

  ## Examples (compliant)

      from(a in Account, join: b in assoc(a, :bookings), on: true)  # ✅ explicit join
  """

  use Credo.Check, [category: :design,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    IronLawCredo.ASTTraversal.collect_issues(source_file, &check_cross_join/2)
  end

  defp check_cross_join({:from, meta, [clause | filters]}, source_file) do
    binding_count = count_bindings(clause)
    has_explicit_join? = Enum.any?(filters, &is_join_clause?/1)

    if binding_count > 1 and not has_explicit_join? do
      issue(source_file, meta)
    else
      nil
    end
  end

  defp check_cross_join(_, _source_file), do: nil

  defp count_bindings({:-, _, [{:{}, _, bindings, _}, _]}) do
    length(bindings)
  end

  defp count_bindings({:-, _, [{_, _, [_, _]}, _]}) do
    1
  end

  defp count_bindings(_) do
    0
  end

  defp is_join_clause?({:join, _, _}), do: true
  defp is_join_clause?({:left_join, _, _}), do: true
  defp is_join_clause?({:right_join, _, _}), do: true
  defp is_join_clause?({:cross_join, _, _}), do: true
  defp is_join_clause?(_) do
    false
  end

  defp issue(source_file, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
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