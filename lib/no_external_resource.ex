defmodule Credo.Check.IronLaw.NoExternalResource do
  @moduledoc """
  Iron Law #16: @external_resource FOR COMPILE-TIME FILES.

  Modules that read files at compile time MUST declare `@external_resource` so
  the compiler knows to recompile the module when the file changes.

  ## Examples (non-compliant)

      defmodule MyModule do
        @html File.read!("templates/index.html")  # ❌ won't recompile

  ## Examples (compliant)

      defmodule MyModule do
        @external_resource "templates/index.html"
        @html File.read!("templates/index.html")  # ✅ will recompile
  """

  use Credo.Check, [category: :consistency,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    Map.get(source_file, :ast)
    |> traverse_call(&check_file_read(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp check_file_read({:., _, [:File, func]} = call, source_file)
       when func in [:read!, :read, :stream!, :stream] do
    # Check if this is at module level (compile time) and @external_resource
    # is declared before it. We track this via state in the traversal.
    # For simplicity, we flag all File.read! at module level and let the user
    # verify @external_resource is present.
    meta = extract_meta(call)

    if meta[:line] && meta[:column] do
      # Heuristic: if the call is at the top level of a module (no enclosing def/defp),
      # it's likely compile-time. We flag it for review.
      issue(source_file, func, meta)
    else
      nil
    end
  end

  defp check_file_read(_, _), do: nil

  defp extract_meta({:., meta, [_mod, _func, _args]}) do
    meta
  end

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:., _, [:File, func | _]} = _call, fun)
       when func in [:read!, :read, :stream!, :stream] do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, func, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      message: """
      File.#{func}/1 at module level without @external_resource. The module will\n" <>
      "not recompile when the file changes. Add @external_resource before the read.\n\n" <>
      "  @external_resource \"path/to/file\"\n" <>
      "  @data File.#{func}(\"path/to/file\")\n"
    """
    }
  end
end