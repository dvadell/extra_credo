defmodule IssueStructFieldsTest do
  use ExUnit.Case

  test "every %Issue{} struct has check: __MODULE__ and category:" do
    for check <- ExtraCredo.checks() do
      blocks = issue_blocks(check)

      for {block, line} <- blocks do
        assert block =~ "check: __MODULE__",
               "#{check_name(check)}:#{line} missing check: __MODULE__"

        assert block =~ ~r/category:\s*:\w+/,
               "#{check_name(check)}:#{line} missing category:"
      end
    end
  end

  defp check_name(module), do: module |> Module.split() |> List.last()

  defp source_path(module) do
    module.module_info(:compile)[:source] |> List.to_string()
  end

  defp issue_blocks(module) do
    source = File.read!(source_path(module))
    lines = String.split(source, "\n")

    lines
    |> Enum.with_index(1)
    |> Enum.reduce([], fn
      {line, idx}, acc ->
        if String.contains?(line, "%Issue{") and struct_line?(line) do
          {text, _} = collect_block(Enum.drop(lines, idx - 1))
          [{text, idx} | acc]
        else
          acc
        end
    end)
    |> Enum.reverse()
  end

  defp struct_line?(line), do: line =~ ~r/^\s*%Issue\{$/

  defp collect_block(lines) do
    lines
    |> Enum.reduce_while({"", 0}, fn line, {acc, depth} ->
      opens = count_brace(line, ?{)
      closes = count_brace(line, ?})
      new_depth = depth + opens - closes
      new_acc = if acc == "", do: line, else: acc <> "\n" <> line

      if new_depth <= 0 do
        {:halt, {new_acc, new_depth}}
      else
        {:cont, {new_acc, new_depth}}
      end
    end)
  end

  defp count_brace(str, char) do
    str |> String.graphemes() |> Enum.count(&(&1 == <<char::utf8>>))
  end
end
