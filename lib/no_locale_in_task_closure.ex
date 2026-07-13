defmodule Credo.Check.Extra.NoLocaleInTaskClosure do
  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @moduledoc """
  DMV Rule #25: Capture locale before spawning.

  `Gettext.get_locale()` returns the locale of the calling process. Inside a
  `Task.async` closure, it will return the task's process locale (usually the
  default), not the caller's locale. Capture the locale in the parent process
  and pass it into the closure.

  ## Examples (non-compliant)

      Task.async(fn ->
        Gettext.dgettext(MyApp.Gettext, "domain", "message")  # ❌ wrong locale
      end)

  ## Examples (compliant)

      locale = Gettext.get_locale()
      Task.async(fn ->
        Gettext.put_locale(locale)
        Gettext.dgettext(MyApp.Gettext, "domain", "message")  # ✅ correct locale
      end)
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  @gettext_funcs [:gettext, :dgettext, :gettext!, :dgettext!, :get_locale, :put_locale, :exists?]

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues_with_path(
      source_file,
      &check_gettext_in_task/3
    )
  end

  defp check_gettext_in_task(call, path, source_file) when is_tuple(call) do
    if in_task_async?(path) and is_gettext_call?(call) and
         not locale_captured_before_task?(call, path) do
      issue(source_file, call)
    else
      nil
    end
  end

  defp in_task_async?(path) do
    Enum.any?(path, fn
      {{:., _, [inner, :async]}, _, _} ->
        case inner do
          {:__aliases__, _, [:Task]} -> true
          _ -> false
        end

      {:async, _, _} ->
        true

      _ ->
        false
    end)
  end

  defp is_gettext_call?(call) do
    case call do
      {{:., _, [inner, func]}, _, _}
      when func in @gettext_funcs and func not in [:put_locale, :get_locale] ->
        case inner do
          {:__aliases__, _, [:Gettext]} -> true
          {:__aliases__, _, segments} -> List.last(segments) == :Gettext
          _ -> false
        end

      {func, _, _} when func in @gettext_funcs and func not in [:put_locale, :get_locale] ->
        true

      _ ->
        false
    end
  end

  defp locale_captured_before_task?(call, path) do
    case Enum.find(path, fn
           {:stmts, _} -> true
           _ -> false
         end) do
      {:stmts, stmts} ->
        idx = Enum.find_index(stmts, &ASTTraversal.contains_node?(&1, call))

        if idx do
          stmts
          |> Enum.take(idx)
          |> Enum.any?(&contains_put_locale?/1)
        else
          Enum.any?(path, &contains_put_locale?/1)
        end

      _ ->
        Enum.any?(path, &contains_put_locale?/1)
    end
  end

  defp contains_put_locale?(ast) do
    case ast do
      {{:., _, [_, :put_locale]}, _, _} ->
        true

      {:put_locale, _, _} ->
        true

      ast when is_tuple(ast) ->
        ast
        |> Tuple.to_list()
        |> Enum.any?(&contains_put_locale?/1)

      ast when is_list(ast) ->
        Enum.any?(ast, &contains_put_locale?/1)

      _ ->
        false
    end
  end

  defp issue(source_file, call) do
    {_, meta, _} = call

    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      column: meta[:column] || 0,
      trigger: Issue.no_trigger(),
      message: """
        Gettext call inside a Task.async closure without capturing the locale.\n" <>
        "Gettext functions use the calling process's locale, which in a task is\n" <>
        "the default locale, not the user's locale.\n\n" <>
        "Capture the locale before spawning the task:\n\n" <>
        "  locale = Gettext.get_locale()\n" <>
        "  Task.async(fn ->\n" <>
        "    Gettext.put_locale(locale)\n" <>
        "    # ... your gettext calls here ...\n" <>
        "  end)\n"
      """
    }
  end
end
