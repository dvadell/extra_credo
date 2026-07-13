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
    IronLawCredo.ASTTraversal.collect_issues(source_file, &check_file_read/2)
  end

  defp check_file_read({:., meta, [{:__aliases__, _, [file]}, func]}, source_file)
       when func in [:read!, :read, :stream!, :stream] do
    cond do
      file == :File -> issue(source_file, func, meta)
      true -> nil
    end
  end

  defp check_file_read({:., meta, [{{:., _, [file, func]}, _, _}]}, source_file)
       when func in [:read!, :read, :stream!, :stream] do
    cond do
      file == :File -> issue(source_file, func, meta)
      is_tuple(file) and tl(Tuple.to_list(file)) == [:File] -> issue(source_file, func, meta)
      true -> nil
    end
  end

  defp check_file_read({:., meta, [{:., _, [file, func]} | _]}, source_file)
       when func in [:read!, :read, :stream!, :stream] do
    cond do
      file == :File -> issue(source_file, func, meta)
      is_tuple(file) and tl(Tuple.to_list(file)) == [:File] -> issue(source_file, func, meta)
      true -> nil
    end
  end

  defp check_file_read(_, _source_file), do: nil

  defp issue(source_file, func, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
      message: """
      File.#{func}/1 at module level without @external_resource. The module will\n" <>
      "not recompile when the file changes. Add @external_resource before the read.\n\n" <>
      "  @external_resource \"path/to/file\"\n" <>
      "  @data File.#{func}(\"path/to/file\")\n"
    """
    }
  end
end