defmodule Credo.Check.Extra.NoRawUntrusted do
  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @moduledoc """
  Extra Rule #12: NEVER use `raw/1` with untrusted content — XSS vulnerability.

  `raw/1` bypasses HTML encoding. Using it with user-controlled content creates
  XSS vulnerabilities. Only use `raw/1` with trusted, hardcoded HTML strings.

  ## Examples (non-compliant)

      <%= raw(@user_bio) %>  # ❌ XSS vulnerability
      <%= raw(params["content"]) %>  # ❌ XSS vulnerability

  ## Examples (compliant)

      <%= raw("<p>Static content</p>") %>  # ✅ hardcoded string is safe
  """

  use Credo.Check,
    category: :security,
    exit_status: 2

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
        if is_untrusted?(arg) do
          issue(source_file, arg)
        else
          nil
        end
    end
  end

  defp check_raw({:raw, _meta, [arg]}, source_file) do
    if is_untrusted?(arg) do
      issue(source_file, arg)
    else
      nil
    end
  end

  defp check_raw(_, _source_file), do: nil

  defp is_untrusted?({var, _, []}) when is_atom(var) do
    var not in [true, false, nil, :__MODULE__]
  end

  defp is_untrusted?({:@, _, [{var, _, _}]}) when is_atom(var) do
    var not in [true, false, nil, :__MODULE__]
  end

  defp is_untrusted?({:get_in, _, _}), do: true
  defp is_untrusted?({:elem, _, _}), do: true
  defp is_untrusted?({:access_key, _, _}), do: true
  defp is_untrusted?({:sigil_s, _, _}), do: false
  defp is_untrusted?({:sigil_c, _, _}), do: false
  defp is_untrusted?({:&, _, _}), do: false
  defp is_untrusted?({:fn, _, _}), do: false
  defp is_untrusted?({:case, _, _}), do: true
  defp is_untrusted?({:cond, _, _}), do: true
  defp is_untrusted?({:if, _, _}), do: true
  defp is_untrusted?({:with, _, _}), do: true
  defp is_untrusted?({:try, _, _}), do: true
  defp is_untrusted?({:receive, _, _}), do: true
  defp is_untrusted?({:for, _, _}), do: true

  defp is_untrusted?({:<<>>, _, _parts}), do: false
  defp is_untrusted?(_), do: false

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
      message: """
        raw/1 used with potentially untrusted input (#{arg_name}). This is an XSS\n" <>
        "vulnerability. Only use raw/1 with hardcoded, trusted HTML strings.\n\n" <>
        "  <%= @user_bio %>\n"
      """
    }
  end

  defp line_from_ast({_, meta, _}) when is_map(meta), do: meta[:line] || 0

  defp line_from_ast(_) do
    0
  end
end
