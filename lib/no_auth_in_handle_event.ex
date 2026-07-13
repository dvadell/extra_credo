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

    IronLawCredo.ASTTraversal.collect_issues(source_file, &check_handle_event/2)
  end

  defp check_handle_event({:def, meta, [{:handle_event, _, [_event, _params, _socket]} | body]}, source_file) do
    if has_auth_check?(body) do
      nil
    else
      issue(source_file, meta)
    end
  end

  defp check_handle_event(_, _source_file), do: nil

  defp has_auth_check?(body) do
    body
    |> IronLawCredo.ASTTraversal.flatten()
    |> Enum.any?(&is_auth_call?/1)
  end

  defp is_auth_call?({:., _, [_, func]}) do
    to_string(func) in @auth_functions
  end

  defp is_auth_call?({func, _, _}) when is_atom(func) do
    to_string(func) in @auth_functions
  end

  defp is_auth_call?({:if, _, [condition | _]}) do
    is_auth_call?(condition)
  end

  defp is_auth_call?({:case, _, [subject | _]}) do
    is_auth_call?(subject)
  end

  defp is_auth_call?({:with, _, clauses}) do
    Enum.any?(clauses, &is_auth_call?/1)
  end

  defp is_auth_call?({key, node}) when key in [:do, :else, :after] do
    is_auth_call?(node)
  end

  defp is_auth_call?(_) do
    false
  end

  defp issue(source_file, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
message: "handle_event without authorization check. Mount-time authorization is\n" <>
                "insufficient — users can call events directly via WebSocket. Add an\n" <>
                "authorized?/authorize check in every handle_event.\n\n" <>
                "  if authorized?(user, :action, resource) do\n"
    }
  end
end