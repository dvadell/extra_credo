defmodule Credo.Check.IronLaw.NoRawUntrusted do
  @moduledoc """
  Iron Law #12: NEVER use `raw/1` with untrusted content — XSS vulnerability.

  `raw/1` bypasses HTML encoding. Using it with user-controlled content creates
  XSS vulnerabilities. Only use `raw/1` with trusted, hardcoded HTML strings.

  ## Examples (non-compliant)

      <%= raw(@user_bio) %>  # ❌ XSS vulnerability
      <%= raw(params["content"]) %>  # ❌ XSS vulnerability

  ## Examples (compliant)

      <%= raw("<p>Static content</p>") %>  # ✅ hardcoded string is safe
  """

  use Credo.Check, [category: :security,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    filename = source_file.filename

    unless String.ends_with?(filename, ".heex") or
           String.ends_with?(filename, "_live.ex") or
           String.ends_with?(filename, "_component.ex") do
      []
    end

    Map.get(source_file, :ast)
    |> traverse_call(&check_raw(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp check_raw({:., _, [{:., _, [:Phoenix, :HTML]}, :raw]} = call, source_file) do
    case extract_args(call) do
      [arg] ->
        if is_untrusted?(arg) do
          issue(source_file, arg)
        else
          nil
        end
      _ -> nil
    end
  end

  defp check_raw({:raw, _meta, [arg]} = _call, source_file) do
    if is_untrusted?(arg) do
      issue(source_file, arg)
    else
      nil
    end
  end

  defp check_raw(_, _), do: nil

  defp is_untrusted?({:_, _, []}) do
    true  # _ wildcard — unknown content
  end

  defp is_untrusted?({var, _, []}) when is_atom(var) and var != :__MODULE__ do
    var not in [:true, :false, :nil]
  end

  defp is_untrusted?({:access_key, _, _}) do
    true  # @assign access
  end

  defp is_untrusted?({:elem, _, _}) do
    true  # tuple element
  end

  defp is_untrusted?({:"[]", _, _}) do
    true  # map/list access
  end

  defp is_untrusted?({:get_in, _, _}) do
    true  # nested access
  end

  defp is_untrusted?({:string_quoted, _, _}) do
    false  # string literal — safe
  end

  defp is_untrusted?({:charlist_quoted, _, _}) do
    false  # charlist literal — safe
  end

  defp is_untrusted?(_) do
    false
  end

  defp extract_args({:., _, [_mod, _func, args]}) when is_list(args) do
    args
  end

  defp extract_args(_) do
    []
  end

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:., _, [{:., _, [:Phoenix, :HTML]}, :raw | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(call = {:raw, _, [_]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, arg) do
    arg_name = case arg do
      {var, _, []} -> to_string(var)
      _ -> "content"
    end

    %Issue{
      filename: source_file.filename,
      line_no: line_from_ast(arg),
      message: """
      raw() with variable content (#{arg_name}) — potential XSS vulnerability.\n" <>
      "Only use raw() with hardcoded string literals. For user content, use\n" <>
      "Phoenix.HTML.safe_to_string/1 or sanitize with a library first.\n\n" <>
      "  <%= @user_bio %>  # Auto-escaped by default\n"
    """
    }
  end

  defp line_from_ast({_, meta, _}) when is_map(meta) do
    meta[:line] || 0
  end

  defp line_from_ast(_) do
    0
  end
end