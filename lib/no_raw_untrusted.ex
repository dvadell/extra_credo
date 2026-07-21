defmodule Credo.Check.Extra.NoRawUntrusted do
  @moduledoc """
  Extra Rule #12: NEVER use `raw/1` with untrusted content — XSS vulnerability.

  `raw/1` bypasses HTML encoding. Using it with user-controlled content creates
  XSS vulnerabilities. Only use `raw/1` with trusted, hardcoded HTML strings.

  ## Examples (non-compliant)

      <%= raw(@user_bio) %>  # [cross] XSS vulnerability
      <%= raw(params["content"]) %>  # [cross] XSS vulnerability

  ## Examples (compliant)

      <%= raw("<p>Static content</p>") %>  # [check] hardcoded string is safe
  """

  use Credo.Check,
    category: :warning,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues(source_file, &check_raw/2)
  end

  defp check_raw({{:., _, [{:__aliases__, _, [:Phoenix, :HTML]}, :raw]}, _, args}, source_file) do
    case List.first(args) do
      nil ->
        nil

      arg ->
        if untrusted?(arg) do
          issue(source_file, arg)
        else
          nil
        end
    end
  end

  defp check_raw({:raw, _meta, [arg]}, source_file) do
    if untrusted?(arg) do
      issue(source_file, arg)
    else
      nil
    end
  end

  defp check_raw(_, _source_file), do: nil

  defp untrusted?({var, _, []}) when is_atom(var) do
    var not in [true, false, nil, :__MODULE__]
  end

  defp untrusted?({:@, _, [{var, _, _}]}) when is_atom(var) do
    var not in [true, false, nil, :__MODULE__]
  end

  defp untrusted?({:get_in, _, _}), do: true
  defp untrusted?({:elem, _, _}), do: true
  defp untrusted?({:access_key, _, _}), do: true
  defp untrusted?({:sigil_s, _, _}), do: false
  defp untrusted?({:sigil_c, _, _}), do: false
  defp untrusted?({:&, _, _}), do: false
  defp untrusted?({:fn, _, _}), do: false
  defp untrusted?({:case, _, _}), do: true
  defp untrusted?({:cond, _, _}), do: true
  defp untrusted?({:if, _, _}), do: true
  defp untrusted?({:with, _, _}), do: true
  defp untrusted?({:try, _, _}), do: true
  defp untrusted?({:receive, _, _}), do: true
  defp untrusted?({:for, _, _}), do: true

  defp untrusted?({:<<>>, _, _parts}), do: false
  defp untrusted?(_), do: false

  defp issue(source_file, arg) do
    arg_name =
      case arg do
        {var, _, []} -> to_string(var)
        _ -> "input"
      end

    %Issue{
      filename: source_file.filename,
      line_no: line_from_ast(arg),
      trigger: Issue.no_trigger(),
      check: __MODULE__,
      category: :warning,
      message:
        "raw/1 used with potentially untrusted input (#{arg_name}). This is an XSS vulnerability. Only use raw/1 with hardcoded, trusted HTML strings."
    }
  end

  defp line_from_ast({_, meta, _}) when is_map(meta), do: meta[:line] || 0

  defp line_from_ast(_) do
    0
  end
end
