defmodule Credo.Check.Extra.NoCommentsAsCommitMessages do
  @moduledoc """
  Comments aren't commit messages.

  Flags comments that look like commit messages, TODOs, issue references,
  or PR links. These belong in Git history, not in source code.

  ## Examples (non-compliant)

      # TODO: refactor this function
      # Fixes #42
      # Closes https://github.com/org/repo/pull/15

  ## Examples (compliant)

      # The regex matches ISO 8601 timestamps with optional timezone
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    source = SourceFile.source(source_file)

    case Code.string_to_quoted_with_comments(source) do
      {:ok, _ast, comments} ->
        Enum.flat_map(comments, &check_comment(&1, source_file))

      _ ->
        []
    end
  end

  defp check_comment(%{text: text, line: line_no}, source_file) do
    trimmed = String.trim(String.trim_leading(text, "#"))

    cond do
      String.starts_with?(trimmed, "TODO") ->
        issue(source_file, line_no, trimmed, "TODO comment")

      String.starts_with?(trimmed, "FIXME") ->
        issue(source_file, line_no, trimmed, "FIXME comment")

      String.starts_with?(trimmed, "HACK") ->
        issue(source_file, line_no, trimmed, "HACK comment")

      String.starts_with?(trimmed, "XXX") ->
        issue(source_file, line_no, trimmed, "XXX comment")

      String.match?(trimmed, ~r/^(fixes|closes|resolves|ref|see)\s+#\d+/i) ->
        issue(source_file, line_no, trimmed, "issue reference")

      String.match?(trimmed, ~r/^(fixes|closes|resolves|ref|see)\s+https?:\/\//i) ->
        issue(source_file, line_no, trimmed, "PR/URL reference")

      String.match?(trimmed, ~r/^(fixes|closes|resolves)\s+#[0-9]+/i) ->
        issue(source_file, line_no, trimmed, "commit-style message")

      true ->
        []
    end
  end

  defp issue(source_file, line_no, _text, kind) do
    [
      %Issue{
        filename: source_file.filename,
        line_no: line_no,
        column: 1,
        trigger: Issue.no_trigger(),
        check: __MODULE__,
        category: :consistency,
        message:
          "Comment looks like a #{kind} instead of explaining code behavior. TODOs, issue references, and PR links belong in Git commit messages or issue trackers, not in source code."
      }
    ]
  end
end
