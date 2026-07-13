defmodule ExtraCredo.ASTTraversal do
  @moduledoc """
  Shared AST traversal utilities for Extra Credo checks.
  """

  alias Credo.SourceFile

  @doc """
  Recursively traverse an AST tree, applying `fun` to each node.
  """
  @spec traverse(term(), function()) :: [term()]
  def traverse(ast, fun) when is_list(ast) do
    Enum.flat_map(ast, &traverse(&1, fun))
  end

  def traverse(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse(&1, fun))
  end

  def traverse(_ast, _fun) do
    []
  end

  @doc """
  Flatten a nested AST tuple into a flat list of nodes.
  Recurses into 3-tuples with list children.
  """
  @spec flatten(term()) :: [term()]
  def flatten(children) when is_list(children) do
    Enum.flat_map(children, &flatten/1)
  end

  def flatten(node = {_, _, children}) when is_list(children) do
    [node] ++ Enum.flat_map(children, &flatten/1)
  end

  def flatten(node = {_, children}) when is_tuple(children) do
    [node] ++ flatten(children)
  end

  def flatten(node = {_, _}) do
    [node] ++ flatten(Tuple.to_list(node))
  end

  def flatten(node) do
    [node]
  end

  @doc """
  Collect issues from AST traversal, filtering out nil results.
  The `fun` receives (ast_node, source_file) for each tuple node.
  """
  @spec collect_issues(Credo.SourceFile.t(), function()) :: [term()]
  def collect_issues(source_file, fun) do
    SourceFile.ast(source_file)
    |> traverse(&fun.(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  @doc """
  Collect issues from AST traversal with path tracking, filtering out nil results.
  The `fun` receives (ast_node, path, source_file) for each tuple node.

  When inside a `:do` block, the path includes a `{:stmts, [stmts]}` entry
  so checks can detect sibling relationships (e.g. dedup before cast_assoc).
  """
  @spec collect_issues_with_path(Credo.SourceFile.t(), function(), [term()]) :: [term()]
  def collect_issues_with_path(source_file, fun, initial_path \\ []) do
    source_file_ast = SourceFile.ast(source_file)
    ast_list = if is_tuple(source_file_ast), do: [source_file_ast], else: source_file_ast

    do_collect_with_path(ast_list, fun, source_file, initial_path)
    |> Enum.filter(&(&1 != nil))
  end

  # Handle list of nodes
  defp do_collect_with_path(ast, fun, source_file, path) when is_list(ast) do
    Enum.flat_map(ast, &do_collect_with_path(&1, fun, source_file, path))
  end

  # Handle {:stmts, stmts} - expand each statement into the path
  # The :stmts entry is in the path so checks can see sibling statements
  defp do_collect_with_path({:stmts, stmts} = stmts_entry, fun, source_file, path)
       when is_list(stmts) do
    path_with_stmts = [stmts_entry | path]
    Enum.flat_map(stmts, &do_collect_with_path(&1, fun, source_file, path_with_stmts))
  end

  # Handle :do blocks - transparent (don't add to path)
  defp do_collect_with_path({:do, body} = ast, fun, source_file, path) do
    result = fun.(ast, path, source_file)
    [result | do_collect_with_path(body, fun, source_file, path)]
  end

  # Handle :else blocks - transparent (don't add to path)
  defp do_collect_with_path({:else, body} = ast, fun, source_file, path) do
    result = fun.(ast, path, source_file)
    [result | do_collect_with_path(body, fun, source_file, path)]
  end

  # Handle regular AST tuples
  defp do_collect_with_path(ast, fun, source_file, path) when is_tuple(ast) do
    result = fun.(ast, path, source_file)
    new_path = [ast | path]

    children =
      case ast do
        {:__block__, _meta, stmts} when is_list(stmts) ->
          [{:stmts, stmts}]

        _ ->
          Tuple.to_list(ast)
      end

    [result | do_collect_with_path(children, fun, source_file, new_path)]
  end

  defp do_collect_with_path(_ast, _fun, _source_file, _path) do
    []
  end

  @doc """
  Check if an AST tree contains a specific node.
  Uses structural equality (==) to find the target node.
  """
  @spec contains_node?(term(), term()) :: boolean()
  def contains_node?(target, target), do: true

  def contains_node?(ast, target) when is_tuple(ast) do
    ast
    |> Tuple.to_list()
    |> Enum.any?(&contains_node?(&1, target))
  end

  def contains_node?(ast, target) when is_list(ast) do
    Enum.any?(ast, &contains_node?(&1, target))
  end

  def contains_node?(_, _), do: false
end
