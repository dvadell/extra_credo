defmodule Credo.Check.IronLaw.StringToAtom do
  @moduledoc """
  Iron Law #10: NO `String.to_atom` with user input — atom exhaustion DoS.

  `String.to_atom/1` on user-controlled input allows atom exhaustion DoS attacks.
  Use `String.to_existing_atom/1` instead, which only returns atoms that already
  exist.

  ## Examples (non-compliant)

      String.to_atom(user_input)  # ❌ DoS vulnerability
      String.to_atom(params["type"])  # ❌ DoS vulnerability

  ## Examples (compliant)

      String.to_existing_atom(user_input)  # ✅ safe
  """

  use Credo.Check, [category: :security,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    Map.get(source_file, :ast)
    |> traverse_call(&check_string_to_atom(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp check_string_to_atom({:., _, [:String, :to_atom]} = call, source_file) do
    case extract_args(call) do
      [arg] ->
        if is_variable?(arg) do
          issue(source_file, arg)
        else
          nil
        end
      _ -> nil
    end
  end

  defp check_string_to_atom({:to_atom, _meta, [arg]} = _call, source_file) do
    if is_variable?(arg) do
      issue(source_file, arg)
    else
      nil
    end
  end

  defp check_string_to_atom(_, _), do: nil

  defp is_variable?({var, _, []}) when is_atom(var) and var != :__MODULE__ do
    var not in [:to_existing_atom, :true, :false, :nil]
  end

  defp is_variable?({:get_in, _, _}), do: true
  defp is_variable?({:"[]", _, [_map, _key]}), do: true
  defp is_variable?({:elem, _, _}), do: true
  defp is_variable?({:access_key, _, _}), do: true
  defp is_variable?({:string_quoted, _, _}), do: false
  defp is_variable?({:charlist_quoted, _, _}), do: false
  defp is_variable?(_), do: false

  defp extract_args({:., _, [_mod, _func, args]}) when is_list(args) do
    args
  end

  defp extract_args(_) do
    []
  end

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:., _, [:String, :to_atom | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(call = {:to_atom, _, [_]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, arg) do
    arg_name = case arg do
      {var, _, []} -> to_string(var)
      _ -> "input"
    end

    %Issue{
      filename: source_file.filename,
      line_no: line_from_ast(arg),
      message: """
      String.to_atom with variable (#{arg_name}). Use String.to_existing_atom to\n" <>
      "prevent atom exhaustion DoS. String.to_existing_atom raises if the atom\n" <>
      "doesn't already exist, which is the safe behavior.\n\n" <>
      "  String.to_existing_atom(#{arg_name})\n"
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