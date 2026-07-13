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
    IronLawCredo.ASTTraversal.collect_issues(source_file, &check_string_to_atom/2)
  end

  defp check_string_to_atom({:., _, [{:., _, [:String, :to_atom]} | args]}, source_file) do
    case List.first(args) do
      nil -> nil
      arg ->
        if is_variable?(arg) do
          issue(source_file, arg)
        else
          nil
        end
    end
  end

  defp check_string_to_atom({:to_atom, _meta, [arg]}, source_file) do
    if is_variable?(arg) do
      issue(source_file, arg)
    else
      nil
    end
  end

  defp check_string_to_atom(_, _source_file), do: nil

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

  defp issue(source_file, arg) do
    arg_name = case arg do
      {var, _, []} -> to_string(var)
      _ -> "input"
    end

    %Issue{
      filename: source_file.filename,
      line_no: line_from_ast(arg),
      trigger: Issue.no_trigger(),
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