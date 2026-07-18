defmodule Credo.Check.Extra.NoColorfulEmoji do
  @moduledoc """
  No colorful emoji in source files.

  Flags characters in these Unicode emoji blocks:
    - U+2600..U+26FF  Miscellaneous Symbols  (stars, crosses, suits, music notes, etc.)
    - U+2700..U+27BF  Dingbats              (check marks, crosses, stars, scissors, etc.)
    - U+1F300..U+1F9FF  Misc Symbols & Pictographs, Emoticons
    - U+1FA00..U+1FAFF  Symbols & Pictographs Extended-A
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile

  # Unicode emoji blocks covered:
  #   U+2600..U+26FF    Miscellaneous Symbols
  #   U+2700..U+27BF    Dingbats
  #   U+1F300..U+1F9FF  Misc Symbols & Pictographs, Emoticons
  #   U+1FA00..U+1FAFF  Symbols & Pictographs Extended-A
  @emoji_regex Regex.compile!(
                 "[\\x{2600}-\\x{27BF}\\x{1F300}-\\x{1F9FF}\\x{1FA00}-\\x{1FAFF}]",
                 "u"
               )

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    source_file
    |> SourceFile.lines()
    |> Enum.filter(fn {_line_no, text} -> Regex.match?(@emoji_regex, text) end)
    |> Enum.map(fn {line_no, text} -> issue(source_file, line_no, text) end)
  end

  defp issue(source_file, line_no, line) do
    [emoji] = Regex.run(@emoji_regex, line)

    %Issue{
      filename: source_file.filename,
      line_no: line_no,
      trigger: emoji,
      check: __MODULE__,
      category: :consistency,
      message: """
      Colorful emoji found: #{emoji} -- use plain text instead.
      """
    }
  end
end
