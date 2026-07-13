defmodule Credo.Check.IronLaw.UnpinnedQueryBindings do
  @moduledoc """
  Iron Law #5: ALWAYS pin values with `^` in Ecto queries.

  In Ecto query comprehensions, variables from the outer scope must be pinned
  with `^` to prevent them from being treated as column bindings. Unpinned
  variables can cause SQL injection or unexpected query behavior.

  ## Examples (non-compliant)

      user_id = get_user_id()
      from(u in User, where: u.id == user_id)  # ❌ unpinned

  ## Examples (compliant)

      user_id = get_user_id()
      from(u in User, where: u.id == ^user_id)  # ✅ pinned
  """

  use Credo.Check, [category: :security,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    IronLawCredo.ASTTraversal.collect_issues(source_file, &check_unpinned/2)
  end

  # Detect from(x in Schema, ...) comprehensions
  defp check_unpinned({:from, meta, [clause | filters]}, source_file) do
    bindings = extract_bindings(clause)

    issues = Enum.flat_map(filters, &find_unpinned_vars(&1, bindings, meta, source_file))

    if Enum.empty?(issues) do
      nil
    else
      hd(issues)
    end
  end

  defp check_unpinned(_, _source_file), do: nil

  defp extract_bindings({:-, _, [{:"{}" , _, bindings, _}, _]}) do
    Enum.map(bindings, &elem(&1, 0))
  end

  defp extract_bindings({:-, _, [{binding, _, _}, _]}) do
    [elem(binding, 0)]
  end

  defp extract_bindings(_) do
    []
  end

  defp find_unpinned_vars(ast, bindings, meta, source_file) do
    case ast do
      # {:==, _, [lhs, rhs]} or {:!=, _, [lhs, rhs]} etc.
      {op, _, [lhs, rhs]} when op in [:==, :!=, :=, :>, :<, :>=, :<=, :in] ->
        check_side(lhs, bindings, meta, source_file) ++
          check_side(rhs, bindings, meta, source_file)

      # {:and, _, [a, b]} / {:or, _, [a, b]}
      {op, _, [a, b]} when op in [:and, :or] ->
        find_unpinned_vars(a, bindings, meta, source_file) ++
          find_unpinned_vars(b, bindings, meta, source_file)

      # ^pinned — OK
      {:^, _, [_]} -> []

      # Bare variable not in bindings
      {var, _, []} when is_atom(var) ->
        if var not in bindings and var not in [:true, :false, :nil, :__MODULE__] do
          [issue(source_file, var, meta)]
        else
          []
        end

      # Tuple with children
      {_, _, children} when is_list(children) ->
        Enum.flat_map(children, &find_unpinned_vars(&1, bindings, meta, source_file))

      _ -> []
    end
  end

  defp check_side(ast, bindings, meta, source_file) do
    find_unpinned_vars(ast, bindings, meta, source_file)
  end

  defp issue(source_file, var, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
      message: """
      Variable #{var} used in Ecto query without ^ pin operator.\n" <>
      "Use ^#{var} to bind outer-scope variables. Unpinned variables are treated\n" <>
      "as column references, which can cause SQL injection.\n\n" <>
      "  from(u in User, where: u.id == ^#{var})\n"
    """
    }
  end
end