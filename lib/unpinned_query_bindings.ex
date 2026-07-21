defmodule Credo.Check.Extra.UnpinnedQueryBindings do
  @moduledoc """
  Extra Rule #5: ALWAYS pin values with `^` in Ecto queries.

  In Ecto query comprehensions, variables from the outer scope must be pinned
  with `^` to prevent them from being treated as column bindings. Unpinned
  variables can cause SQL injection or unexpected query behavior.

  ## Examples (non-compliant)

      user_id = get_user_id()
      from(u in User, where: u.id == user_id)  # [cross] unpinned

  ## Examples (compliant)

      user_id = get_user_id()
      from(u in User, where: u.id == ^user_id)  # [check] pinned
  """

  use Credo.Check,
    category: :security,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @ecto_query_functions ~w(where having order_by group_by select distinct limit offset dynamic)a

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues_with_path(source_file, &check_node/3)
  end

  defp check_node({:from, meta, [clause | filters]}, _path, source_file) do
    bindings = extract_bindings(clause)

    issues = Enum.flat_map(filters, &find_unpinned_vars(&1, bindings, meta, source_file))

    if Enum.empty?(issues) do
      nil
    else
      hd(issues)
    end
  end

  defp check_node({name, meta, args}, path, source_file)
       when name in @ecto_query_functions and is_list(args) and length(args) >= 2 do
    if inside_from?(path) do
      nil
    else
      [bindings_node, expression] = Enum.take(args, -2)

      if is_list(bindings_node) do
        bindings = extract_bindings_from_list(bindings_node)
        issues = find_unpinned_vars(expression, bindings, meta, source_file)

        if Enum.empty?(issues) do
          nil
        else
          hd(issues)
        end
      else
        nil
      end
    end
  end

  defp check_node(_, _path, _source_file), do: nil

  defp inside_from?(path) do
    Enum.any?(path, fn
      {:from, _, _} -> true
      _ -> false
    end)
  end

  defp extract_bindings_from_list(list) when is_list(list) do
    list
    |> Enum.map(fn
      {name, _, _} when is_atom(name) -> name
      _ -> nil
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp extract_bindings({:in, _, [binding, _source]}) do
    [elem(binding, 0)]
  end

  defp extract_bindings({:-, _, [{:{}, _, bindings, _}, _]}) do
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
      # List of sub-expressions (e.g. where clause body)
      list when is_list(list) ->
        Enum.flat_map(list, &find_unpinned_vars(&1, bindings, meta, source_file))

      # {:==, _, [lhs, rhs]} or {:!=, _, [lhs, rhs]} etc.
      {op, _, [lhs, rhs]} when op in [:==, :!=, :=, :>, :<, :>=, :<=, :in] ->
        find_unpinned_vars(lhs, bindings, meta, source_file) ++
          find_unpinned_vars(rhs, bindings, meta, source_file)

      # {:and, _, [a, b]} / {:or, _, [a, b]}
      {op, _, [a, b]} when op in [:and, :or] ->
        find_unpinned_vars(a, bindings, meta, source_file) ++
          find_unpinned_vars(b, bindings, meta, source_file)

      # ^pinned — OK
      {:^, _, [_]} ->
        []

      # Bare variable not in bindings (context is nil or [])
      {var, _, ctx} when is_atom(var) and ctx in [nil, []] ->
        if var not in bindings and var not in [true, false, nil, :__MODULE__] do
          [issue(source_file, var, meta)]
        else
          []
        end

      # Keyword list item: {:where, [...]} etc. — recurse into value
      {key, value} when is_atom(key) ->
        find_unpinned_vars(value, bindings, meta, source_file)

      # Tuple with children
      {_, _, children} when is_list(children) ->
        Enum.flat_map(children, &find_unpinned_vars(&1, bindings, meta, source_file))

      _ ->
        []
    end
  end

  defp issue(source_file, var, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
      check: __MODULE__,
      category: :security,
      message:
        "Variable #{var} used in Ecto query without ^ pin operator. Use ^#{var} to bind outer-scope variables. Unpinned variables are treated as column references, which can cause SQL injection."
    }
  end
end
