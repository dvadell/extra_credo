defmodule Credo.Check.Extra.NoAuthInHandleEvent do
  @moduledoc """
  Extra Rule #11: AUTHORIZE in EVERY LiveView `handle_event`.

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

  ## Configuring in `.credo.exs`

  If your project uses custom authorization function names, add them via
  the `:auth_functions` param:

      {Credo.Check.Extra.NoAuthInHandleEvent,
       [auth_functions: ~w(may_access? grant? policy_allows?)]}
  """

  use Credo.Check,
    category: :security,
    exit_status: 2

  alias Credo.Issue
  alias ExtraCredo.ASTTraversal

  @default_auth_functions ~w(authorized? authorize authorize! can? cannot? permitted?
                             check_auth verify_auth access? allowed? deny? forbid?)

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, params) do
    if not String.ends_with?(source_file.filename, "_live.ex") do
      []
    else
      auth_functions = Keyword.get(params, :auth_functions, @default_auth_functions)

      ASTTraversal.collect_issues(source_file, fn node, sf ->
        check_handle_event(node, sf, auth_functions)
      end)
    end
  end

  defp check_handle_event(
         {:def, meta, [{:handle_event, _, [_event, _params, _socket]} | body]},
         source_file,
         auth_functions
       ) do
    if has_auth_check?(body, auth_functions) do
      nil
    else
      issue(source_file, meta)
    end
  end

  defp check_handle_event(_, _source_file, _auth_functions), do: nil

  defp has_auth_check?(body, auth_functions) do
    body
    |> ASTTraversal.flatten()
    |> Enum.any?(&auth_call?(&1, auth_functions))
  end

  defp auth_call?({{:., _, [_, func]}, _, _}, auth_functions) do
    to_string(func) in auth_functions
  end

  defp auth_call?({func, _, _}, auth_functions) when is_atom(func) do
    to_string(func) in auth_functions
  end

  defp auth_call?({:if, _, [condition | _]}, auth_functions),
    do: auth_call?(condition, auth_functions)

  defp auth_call?({:case, _, [subject | _]}, auth_functions),
    do: auth_call?(subject, auth_functions)

  defp auth_call?({:with, _, clauses}, auth_functions),
    do: Enum.any?(clauses, &auth_call?(&1, auth_functions))

  defp auth_call?({key, node}, auth_functions) when key in [:do, :else, :after] do
    auth_call?(node, auth_functions)
  end

  defp auth_call?(_, _auth_functions) do
    false
  end

  defp issue(source_file, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
      message:
        "handle_event without authorization check. Mount-time authorization is\n" <>
          "insufficient — users can call events directly via WebSocket. Add an\n" <>
          "authorized?/authorize check in every handle_event.\n\n" <>
          "  if authorized?(user, :action, resource) do\n"
    }
  end
end
