defmodule Credo.Check.IronLaw.ObanStructInArgs do
  @moduledoc """
  Iron Law #9: NEVER store structs in Oban args — store IDs.

  Oban serializes job args to JSON. Structs lose their `__struct__` field and
  become plain maps on deserialization. Store IDs and fetch the struct in
  `perform/1` instead.

  ## Examples (non-compliant)

      MyApp.Worker.perform_async(%{user: %User{id: 1}})  # ❌ struct in args

  ## Examples (compliant)

      MyApp.Worker.perform_async(%{user_id: user.id})  # ✅ ID in args
  """

  use Credo.Check, [category: :consistency,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    Map.get(source_file, :ast)
    |> traverse_call(&check_struct_in_args(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp check_struct_in_args({:., _, [{:., _, [:Oban, :insert!]}, :insert!, [_ | args]]} = call, source_file) do
    case extract_args_from_call(args) do
      nil -> nil
      args_ast -> find_structs(args_ast, call, source_file)
    end
  end

  defp check_struct_in_args({:., _, [mod, :perform_async]} = call, source_file)
       when is_atom(mod) do
    case extract_args_from_call(elem(call, 2)) do
      nil -> nil
      args_ast -> find_structs(args_ast, call, source_file)
    end
  end

  defp check_struct_in_args({:., _, [mod, :new]} = call, source_file)
       when is_atom(mod) do
    case extract_args_from_call(elem(call, 2)) do
      nil -> nil
      args_ast -> find_structs(args_ast, call, source_file)
    end
  end

  defp check_struct_in_args(_, _), do: nil

  defp extract_args_from_call([arg]) do
    case arg do
      {:%, _, [_, fields]} ->
        # %Oban.Job{args: ...} — extract args field
        case List.keyfind(fields, :args, 0) do
          {:args, args_ast} -> args_ast
          _ -> nil
        end
      args when is_tuple(args) and elem(args, 0) == :"%{" ->
        args
      _ -> nil
    end
  end

  defp extract_args_from_call(_), do: nil

  defp find_structs(args_ast, call, source_file) when is_tuple(args_ast) do
    if elem(args_ast, 0) == :"%{" do
      pairs = elem(args_ast, 2)
      structs = Enum.filter(pairs, fn
        {key, value} when is_atom(key) ->
          is_struct_like?(value)
        _ -> false
      end)

      case structs do
        [] -> nil
        [{key, value} | _] -> issue(source_file, key, value, call)
      end
    else
      nil
    end
  end

  defp find_structs(_, _, _), do: nil

  defp is_struct_like?({:module, _, [name]}) do
    String.match?(to_string(name), ~r/^[A-Z]/)
  end

  defp is_struct_like?({name, _, []}) when is_atom(name) do
    String.match?(to_string(name), ~r/^[A-Z]/)
  end

  defp is_struct_like?({:module, _, _}) do
    true
  end

  defp is_struct_like?(_), do: false

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:., _, [{:., _, [:Oban, :insert!]} | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(call = {:., _, [_mod, :perform_async | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(call = {:., _, [_mod, :new | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(call = {:., _, [_mod, :insert! | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, _key, value, call) do
    module = case value do
      {:module, _, [name]} -> to_string(name)
      {name, _, []} when is_atom(name) -> to_string(name)
      _ -> "a struct"
    end

    %Issue{
      filename: source_file.filename,
      line_no: line_from_ast(call),
      message: """
      Oban args contain struct #{module}. Oban serializes args to JSON, losing\n" <>
      "the __struct__ field. Store an ID and fetch the struct in perform/1.\n\n" <>
      "  MyApp.Worker.perform_async(%{user_id: user.id})\n"
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