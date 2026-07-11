defmodule Credo.Check.IronLaw.NoBareChangesetError do
  @moduledoc """
  Iron Law #24: MATCH `{:error, %Ecto.Changeset{}}` EXPLICITLY.

  Bare `{:error, _}` pattern matching in `handle_event` callbacks swallows
  changeset errors. The form never re-renders validation errors because the
  changeset is lost in the generic `_` match.

  ## Examples (non-compliant)

      def handle_event("save", params, socket) do
        case MyApp.update_user(user, params) do
          {:ok, user} -> {:noreply, socket}
          {:error, _} -> {:noreply, socket}  # ❌ changeset errors lost
        end
      end

  ## Examples (compliant)

      def handle_event("save", params, socket) do
        case MyApp.update_user(user, params) do
          {:ok, user} -> {:noreply, socket}
          {:error, %Ecto.Changeset{} = cs} ->  # ✅ re-renders form with errors
            {:noreply, assign(socket, form: to_form(cs))}
        end
      end
  """

  use Credo.Check, [category: :consistency,
    exit_status: 2]

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    unless String.ends_with?(source_file.filename, "_live.ex") do
      []
    end

    Map.get(source_file, :ast)
    |> traverse_call(&check_bare_changeset_error(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp check_bare_changeset_error({:def, meta, [{:handle_event, _, [_event, _params, _socket]} | body]} = _call, source_file) do
    case find_bare_error(body) do
      nil -> nil
      line -> issue(source_file, line || meta[:line] || 0)
    end
  end

  defp check_bare_changeset_error(_, _), do: nil

  defp find_bare_error(body) do
    body
    |> flatten()
    |> Enum.find_value(fn
      # {:error, _} — bare wildcard
      {{:error, {:_, _, []}}, _} -> true
      # {:error, var} where var is a plain atom (not %Changeset{})
      {{:error, {var, meta, []}}, _} when is_atom(var) ->
        if var == :changeset or var == :cs do
          nil  # Likely already pattern-matched as %Changeset{} = cs
        else
          meta[:line]
        end
      _ -> nil
    end)
  end

  defp flatten({_, _, children}) when is_list(children) do
    Enum.flat_map(children, &flatten/1)
  end

  defp flatten(node) do
    [node]
  end

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:def, _, [{:handle_event, _, [_]} | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, line) do
    %Issue{
      filename: source_file.filename,
      line_no: line,
      message: """
      Bare {:error, _} in handle_event — changeset errors are swallowed and the\n" <>
      "form won't re-render validation errors. Match {:error, %Ecto.Changeset{}\n" <>
      "= cs} explicitly to pass the changeset to to_form/1.\n\n" <>
      "  {:error, %Ecto.Changeset{} = cs} ->\n" <>
      "    {:noreply, assign(socket, form: to_form(cs))}\n"
    """
    }
  end
end