defmodule Credo.Check.IronLaw.NoAuthInHandleEvent do
  @moduledoc """
  Iron Law #11: AUTHORIZE in EVERY LiveView `handle_event`.

  Every `handle_event` must verify the current user is authorized to perform
  the action. Mount-time authorization is insufficient — users can bypass mount
  by calling events directly via WebSocket.

  ## Examples (non-compliant)

      def handle_event("save", _params, socket) do  # ❌ no auth check
        MyApp.update_user(user, attrs)
        {:noreply, socket}
      end

  ## Examples (compliant)

      def handle_event("save", _params, socket) do
        user = socket.assigns.current_user

        if authorized?(user, :update, resource) do  # ✅ auth check
          MyApp.update_user(user, attrs)
          {:noreply, socket}
        else
          {:noreply, put_flash(socket, :error, "Unauthorized")}
        end
      end
  """

  use Credo.Check, [category: :security,
    exit_status: 2]

  @auth_functions ~w(authorized? authorize authorize! can? cannot? permitted?
                     check_auth verify_auth access? allowed? deny? forbid?)

  @impl true
  def run(%SourceFile{} = source_file, _params) do
    unless String.ends_with?(source_file.filename, "_live.ex") do
      []
    end

    Map.get(source_file, :ast)
    |> traverse_call(&check_handle_event(&1, source_file))
    |> Enum.filter(&(&1 != nil))
  end

  defp check_handle_event({:def, meta, [{:handle_event, _, [_event, _params, _socket]} | body]} = _call, source_file) do
    if has_auth_check?(body) do
      nil
    else
      issue(source_file, meta)
    end
  end

  defp check_handle_event(_, _), do: nil

  defp has_auth_check?(body) do
    body
    |> flatten()
    |> Enum.any?(&is_auth_call?/1)
  end

  defp flatten({_, _, children}) when is_list(children) do
    Enum.flat_map(children, &flatten/1)
  end

  defp flatten(node) do
    [node]
  end

  defp is_auth_call?({:., _, [_, func]}) do
    to_string(func) in @auth_functions
  end

  defp is_auth_call?({func, _, _}) when is_atom(func) do
    to_string(func) in @auth_functions
  end

  defp is_auth_call?({:if, _, [{auth_call, _, _}]}) do
    is_auth_call?(auth_call)
  end

  defp is_auth_call?({:case, _, [{auth_call, _, _}]}) do
    is_auth_call?(auth_call)
  end

  defp is_auth_call?({:with, _, clauses}) do
    Enum.any?(clauses, &is_auth_call?/1)
  end

  defp is_auth_call?(_) do
    false
  end

  defp traverse_call(ast, fun) when is_list(ast), do: Enum.flat_map(ast, &traverse_call(&1, fun))

  defp traverse_call(call = {:def, _, [{:handle_event, _, [_]} | _]} = _call, fun) do
    [fun.(call)] ++ Enum.flat_map(elem(call, 2), &traverse_call(&1, fun))
  end

  defp traverse_call(ast, fun) when is_tuple(ast) do
    [fun.(ast)] ++ Enum.flat_map(Tuple.to_list(ast), &traverse_call(&1, fun))
  end

  defp traverse_call(_ast, _fun), do: []

  defp issue(source_file, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      message: """
      handle_event without authorization check. Mount-time authorization is\n" <>
      "insufficient — users can call events directly via WebSocket. Add an\n" <>
      "authorized?/authorize check in every handle_event.\n\n" <>
      "  if authorized?(user, :action, resource) do\n"
    """
    }
  end
end