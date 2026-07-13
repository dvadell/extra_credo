defmodule Credo.Check.Extra.ObanAtomKeys do
  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @moduledoc """
  Extra Rule #8: Oban args use STRING keys, not atoms.

  Oban serializes job args as JSON, which uses string keys. Pattern matching
  on atom keys (`%{user_id: id}`) will always fail. Must use string keys
  (`%{"user_id" => id}`).

  ## Examples (non-compliant)

      def perform(%Oban.Job{args: %{user_id: id}}) do  # ❌ atom key

  ## Examples (compliant)

      def perform(%Oban.Job{args: %{"user_id" => id}}) do  # ✅ string key
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    if String.contains?(source_file.filename, "worker") or
         String.ends_with?(source_file.filename, "_job.ex") do
      ASTTraversal.collect_issues(source_file, &check_oban_atom_keys/2)
    else
      []
    end
  end

  defp check_oban_atom_keys({:def, meta, [{:perform, _, [arg]} | _]}, source_file) do
    oban_args = extract_oban_args(arg)

    case oban_args do
      nil -> nil
      args_ast -> find_atom_keys(args_ast, meta, source_file)
    end
  end

  defp check_oban_atom_keys(_, _source_file), do: nil

  defp extract_oban_args({:%, _, [struct_info, {:%{}, _, pairs}]}) do
    if match_oban_job?(struct_info) do
      case Enum.find(pairs, fn
             {:args, _} -> true
             _ -> false
           end) do
        {:args, args_ast} -> args_ast
        nil -> nil
      end
    else
      nil
    end
  end

  defp extract_oban_args(_), do: nil

  defp match_oban_job?({:__aliases__, _, [:Oban, :Job]}) do
    true
  end

  defp match_oban_job?(_), do: false

  defp find_atom_keys({:%{}, _, pairs}, meta, source_file) do
    atom_keys =
      Enum.filter(pairs, fn
        {key, _} when is_atom(key) -> true
        _ -> false
      end)

    case atom_keys do
      [] -> nil
      [{key, _} | _] -> issue(source_file, key, meta)
    end
  end

  defp find_atom_keys(_, _, _), do: nil

  defp issue(source_file, key, meta) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      trigger: Issue.no_trigger(),
      message: """
        Oban worker uses atom key #{key} in args pattern. Oban serializes args as\n" <>
        "JSON (string keys). Use \"#{key}\" => instead of #{key}:.\n\n" <>
        "  def perform(%Oban.Job{args: %{"#{key}" => id}}) do\n"
      """
    }
  end
end
