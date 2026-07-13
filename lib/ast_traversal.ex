defmodule IronLawCredo.ASTTraversal do
  @moduledoc """
  Shared AST traversal utilities for Iron Law Credo checks.
  """

  @doc """
  Recursively traverse an AST tree, applying `fun` to each node.
  """
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
  Like `traverse/2` but tracks the ancestor path for context-aware checks.
  """
  def traverse_with_path(ast, fun) when is_list(ast) do
    Enum.flat_map(ast, &traverse_with_path(&1, fun))
  end

  def traverse_with_path(ast, fun) when is_tuple(ast) do
    result = fun.(ast)
    children = Tuple.to_list(ast) |> Enum.drop(2) |> List.flatten()
    new_path = [ast | fun.path()]
    [result | traverse_with_path(children, fun)]
  end

  def traverse_with_path(_ast, _fun) do
    []
  end

  @doc """
  Flatten a nested AST tuple into a flat list of nodes.
  Recurses into 3-tuples with list children, including the parent node itself.
  """
  def flatten(children) when is_list(children) do
    Enum.flat_map(children, &flatten/1)
  end

  def flatten(node = {_, _, children}) when is_list(children) do
    [node] ++ Enum.flat_map(children, &flatten/1)
  end

  def flatten(node = {_, _, children}) when is_tuple(children) do
    [node] ++ flatten(children)
  end

  def flatten(node = {_, children}) when is_tuple(children) do
    [node] ++ flatten(children)
  end

  def flatten(node = {_, _}) when is_tuple(node) do
    [node] ++ flatten(Tuple.to_list(node))
  end

  def flatten(node) do
    [node]
  end

  @doc """
  Collect issues from AST traversal, filtering out nil results.
  The `fun` receives (ast_node, source_file) for each tuple node.
  """
  def collect_issues(source_file, fun) do
    Credo.SourceFile.ast(source_file)
    |> traverse(&fun.(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  @doc """
  Collect issues from AST traversal with path tracking, filtering out nil results.
  The `fun` receives (ast_node, path, source_file) for each tuple node.
  """
  def collect_issues_with_path(source_file, fun, initial_path \\ []) do
    source_file_ast = Credo.SourceFile.ast(source_file)

    # Use an accumulator-based approach to build path as we traverse
    do_collect_with_path(source_file_ast, fun, source_file, initial_path)
    |> Enum.filter(&(&1 != nil))
  end

  defp do_collect_with_path(ast, fun, source_file, path) when is_list(ast) do
    Enum.flat_map(ast, &do_collect_with_path(&1, fun, source_file, path))
  end

  defp do_collect_with_path(ast, fun, source_file, path) when is_tuple(ast) do
    result = fun.(ast, path, source_file)
    children = Tuple.to_list(ast) |> Enum.drop(tuple_size(ast) - 1) |> List.flatten()
    new_path = [ast | path]
    [result | do_collect_with_path(children, fun, source_file, new_path)]
  end

  defp do_collect_with_path(_ast, _fun, _source_file, _path) do
    []
  end
end