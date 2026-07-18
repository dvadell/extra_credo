defmodule Credo.Check.Extra.NoBareChangesetError do
  @moduledoc """
  Extra Rule #24: MATCH `{:error, %Ecto.Changeset{}}` EXPLICITLY.

  Bare `{:error, _}` pattern matching in `handle_event` callbacks swallows
  changeset errors. The form never re-renders validation errors because the
  changeset is lost in the generic `_` match.

  ## Examples (non-compliant)

      def handle_event("save", params, socket) do
        case MyApp.update_user(user, params) do
          {:ok, user} -> {:noreply, socket}
          {:error, _} -> {:noreply, socket}  # [cross] changeset errors lost
        end
      end

  ## Examples (compliant)

      def handle_event("save", params, socket) do
        case MyApp.update_user(user, params) do
          {:ok, user} -> {:noreply, socket}
          {:error, %Ecto.Changeset{} = cs} ->  # [check] re-renders form with errors
            {:noreply, assign(socket, form: to_form(cs))}
        end
      end
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  alias Credo.Issue
  alias ExtraCredo.ASTTraversal

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    if String.ends_with?(source_file.filename, "_live.ex") do
      ASTTraversal.collect_issues(source_file, &check_bare_changeset_error/2)
    else
      []
    end
  end

  defp check_bare_changeset_error(
         {:def, _meta, [{:handle_event, _, [_event, _params, _socket]} | body]},
         source_file
       ) do
    find_case_with_changeset(body, source_file)
  end

  defp check_bare_changeset_error(_, _source_file), do: nil

  defp find_case_with_changeset(ast, source_file) when is_list(ast) do
    Enum.find_value(ast, fn
      {key, value} when is_atom(key) ->
        find_case_with_changeset(value, source_file)

      other ->
        find_case_with_changeset(other, source_file)
    end)
  end

  defp find_case_with_changeset({:case, _meta, [subject, clauses]}, source_file)
       when is_list(clauses) do
    if changeset_call?(subject) do
      case find_bare_error_in_clauses(clauses) do
        nil -> nil
        line -> issue(source_file, line)
      end
    else
      find_case_with_changeset(clauses, source_file)
    end
  end

  defp find_case_with_changeset({key, value}, source_file)
       when is_atom(key) do
    find_case_with_changeset(value, source_file)
  end

  defp find_case_with_changeset({_, _meta, children}, source_file)
       when is_list(children) do
    Enum.find_value(children, &find_case_with_changeset(&1, source_file))
  end

  defp find_case_with_changeset(_, _source_file), do: nil

  defp find_bare_error_in_clauses(clauses) when is_list(clauses) do
    Enum.find_value(clauses, fn
      {:do, clause_list} ->
        find_bare_error_in_clauses(clause_list)

      {:->, _, [patterns, _body]} ->
        Enum.find_value(patterns, fn
          {error, {:_, meta, _}} when error == :error ->
            meta[:line]

          {error, {:=, _, _}} when error == :error ->
            nil

          {error, {var, meta, _}}
          when error == :error and is_atom(var) and var not in [:changeset, :cs] ->
            meta[:line]

          _ ->
            nil
        end)

      _ ->
        nil
    end)
  end

  defp changeset_call?({{:., _, [_, func]}, _, _})
       when func in [
              :insert,
              :insert!,
              :update,
              :update!,
              :delete,
              :delete!,
              :get_by,
              :get_by!,
              :get_by_fields,
              :get_by_fields!,
              :change,
              :update_change,
              :put_change,
              :fetch_change,
              :validate_change,
              :trigger_change
            ] do
    true
  end

  defp changeset_call?({{:., _, [_, func]}, _, _}) when is_atom(func) do
    func_str = Atom.to_string(func)

    func_str in ["changeset", "validate_changeset", "cast", "cast_embed", "cast_embeds"] or
      String.starts_with?(func_str, "create_") or
      String.starts_with?(func_str, "update_") or
      String.starts_with?(func_str, "insert_") or
      String.starts_with?(func_str, "delete_") or
      String.starts_with?(func_str, "change_") or
      String.contains?(func_str, "changeset")
  end

  defp changeset_call?(_), do: false

  defp issue(source_file, line) do
    %Issue{
      filename: source_file.filename,
      line_no: line,
      trigger: Issue.no_trigger(),
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
