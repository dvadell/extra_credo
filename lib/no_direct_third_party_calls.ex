defmodule Credo.Check.Extra.NoDirectThirdPartyCalls do
  @moduledoc """
  Wrap third-party library APIs.

  Direct calls to third-party libraries (HTTPoison, Tesla, ExAws, etc.) in
  context modules make testing harder and coupling tighter. Wrap external
  service calls in a dedicated module so they can be mocked in tests and
  changed without touching business logic.
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @third_party_modules ~w(HTTPoison Tesla ExAws Finch Hackney Req)

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, params) do
    extra_modules = Keyword.get(params, :modules, [])
    all_modules = @third_party_modules ++ extra_modules

    ASTTraversal.collect_issues(
      source_file,
      fn node, sf -> check_direct_call(node, sf, all_modules) end
    )
  end

  defp check_direct_call(
         {:., _dot_meta, [{:__aliases__, alias_meta, segments}, _func]},
         source_file,
         modules
       ) do
    if to_string(List.last(segments)) in modules do
      issue(source_file, alias_meta, List.last(segments))
    else
      nil
    end
  end

  defp check_direct_call(_, _, _), do: nil

  defp issue(source_file, meta, module) do
    module_str = Atom.to_string(module)

    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      column: meta[:column] || 0,
      trigger: module_str,
      check: __MODULE__,
      category: :consistency,
      message:
        "Direct #{module_str} call in context module. Third-party library APIs\n" <>
          "should be wrapped in a dedicated module (e.g. MyApp.HttpClient) so they\n" <>
          "can be mocked in tests and swapped without touching business logic.\n\n" <>
          "  defmodule MyApp.HttpClient do\n" <>
          "    def get(url), do: #{module_str}.get(url)\n" <>
          "  end"
    }
  end
end
