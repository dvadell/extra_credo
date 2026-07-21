defmodule Credo.Check.Extra.NoExternalResource do
  @moduledoc """
  Extra Rule #16: @external_resource FOR COMPILE-TIME FILES.

  Modules that read files at compile time MUST declare `@external_resource` so
  the compiler knows to recompile the module when the file changes.

  ## Examples (non-compliant)

      defmodule MyModule do
        @html File.read!("templates/index.html")  # [cross] won't recompile

  ## Examples (compliant)

      defmodule MyModule do
        @external_resource "templates/index.html"
        @html File.read!("templates/index.html")  # [check] will recompile
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    has_external_resource = module_has_external_resource?(source_file)

    ASTTraversal.collect_issues_with_path(source_file, fn call, path, sf ->
      if in_module_attribute?(path) and not has_external_resource do
        check_file_read(call, sf)
      else
        nil
      end
    end)
  end

  defp in_module_attribute?(path) do
    function_constructs = [
      :def,
      :defp,
      :defmacro,
      :defmacrop,
      :defdelegate,
      :defoverridable,
      :defstruct,
      :defexception,
      :defcallback
    ]

    not Enum.any?(path, fn
      {name, _, _} when is_atom(name) -> name in function_constructs
      _ -> false
    end)
  end

  defp module_has_external_resource?(source_file) do
    ASTTraversal.collect_issues(source_file, fn node, _sf ->
      case node do
        {:external_resource, _, _} -> :found
        _ -> nil
      end
    end) != []
  end

  defp check_file_read({:., meta, [{:__aliases__, _, [file]}, func]}, source_file)
       when func in [:read!, :read, :stream!, :stream] do
    if file == :File, do: issue(source_file, func, meta), else: nil
  end

  defp check_file_read(_, _source_file), do: nil

  defp issue(source_file, func, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
      check: __MODULE__,
      category: :consistency,
      message:
        "File.#{func}/1 at module level without @external_resource. The module will not recompile when the file changes. Add @external_resource before the read."
    }
  end
end
