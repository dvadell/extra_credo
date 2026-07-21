defmodule Credo.Check.Extra.ObanStructInArgs do
  @moduledoc """
  Extra Rule #9: NEVER store structs in Oban args — store IDs.

  Oban serializes job args to JSON. Structs lose their `__struct__` field and
  become plain maps on deserialization. Store IDs and fetch the struct in
  `perform/1` instead.

  ## Examples (non-compliant)

      MyApp.Worker.perform_async(%{user: %User{id: 1}})  # [cross] struct in args

  ## Examples (compliant)

      MyApp.Worker.perform_async(%{user_id: user.id})  # [check] ID in args
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
    ASTTraversal.collect_issues(source_file, &check_struct_in_args/2)
  end

  defp check_struct_in_args(
         {{:., _, [{:__aliases__, _, [:Oban]}, func]}, call_meta, args},
         source_file
       )
       when func in [:insert, :insert!] do
    case extract_args_from_call(args) do
      nil -> nil
      args_ast -> find_structs(args_ast, call_meta, source_file)
    end
  end

  defp check_struct_in_args(
         {{:., _, [_, :perform_async]}, call_meta, args},
         source_file
       ) do
    case extract_args_from_call(args) do
      nil -> nil
      args_ast -> find_structs(args_ast, call_meta, source_file)
    end
  end

  defp check_struct_in_args(
         {{:., _, [_, :new]}, call_meta, args},
         source_file
       ) do
    case extract_args_from_call(args) do
      nil -> nil
      args_ast -> find_structs(args_ast, call_meta, source_file)
    end
  end

  defp check_struct_in_args(_, _source_file), do: nil

  defp extract_args_from_call([arg]) do
    case arg do
      {:%, _, [_, fields]} ->
        pairs = if is_list(fields), do: fields, else: elem(fields, 2)

        case List.keyfind(pairs, :args, 0) do
          {:args, args_ast} -> args_ast
          _ -> nil
        end

      {:%{}, _, _} = args ->
        args

      _ ->
        nil
    end
  end

  defp extract_args_from_call(_), do: nil

  defp find_structs(args_ast, call_meta, source_file) when is_tuple(args_ast) do
    if elem(args_ast, 0) == :%{} do
      pairs = elem(args_ast, 2)

      structs =
        Enum.filter(pairs, fn
          {key, value} when is_atom(key) ->
            struct_like?(value)

          _ ->
            false
        end)

      case structs do
        [] -> nil
        [{key, value} | _] -> issue(source_file, key, value, call_meta)
      end
    else
      nil
    end
  end

  defp find_structs(_, _, _), do: nil

  defp struct_like?({:%, _, _}), do: true
  defp struct_like?(_), do: false

  defp issue(source_file, _key, _value, call_meta) do
    %Issue{
      filename: source_file.filename,
      line_no: call_meta[:line] || 0,
      trigger: Issue.no_trigger(),
      check: __MODULE__,
      category: :consistency,
      message:
        "Oban args contain a struct. Oban serializes args to JSON, losing the __struct__ field. Store an ID and fetch the struct in perform/1."
    }
  end
end
