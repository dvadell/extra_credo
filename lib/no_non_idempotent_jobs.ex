defmodule Credo.Check.Extra.NoNonIdempotentJobs do
  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @moduledoc """
  DMV Rule #7: Jobs must be idempotent.

  Oban jobs may be retried on failure. Non-idempotent operations like
  `Repo.insert!/1`, `Repo.update!/2`, `Repo.delete!/1` will cause errors
  or duplicate data on retry. Use idempotent alternatives (`Repo.insert/2`,
  `Repo.update/2`, `Repo.delete/2`) and handle the result explicitly.

  ## Examples (non-compliant)

      def perform(%Oban.Job{args: args}) do
        user = build_user(args)
        MyApp.Repo.insert!(user)  # ❌ fails on retry if already inserted
        {:ok, result}
      end

  ## Examples (compliant)

      def perform(%Oban.Job{args: args}) do
        user = build_user(args)
        case MyApp.Repo.insert(user) do
          {:ok, _} -> {:ok, result}
          {:error, _} -> {:ok, result}  # already exists, that's fine
        end
      end
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  @non_idempotent_functions ~w(insert! update! delete!)a

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues_with_path(
      source_file,
      &check_non_idempotent_in_perform/3
    )
  end

  defp check_non_idempotent_in_perform(
         {:def, _meta, [{:perform, _, [arg]} | _]},
         _path,
         _source_file
       ) do
    case arg do
      {:%, _, [{:__aliases__, _, [:Oban, :Job]} | _]} -> nil
      {:%, _, [{:__aliases__, _, [:Oban, :Job, :Args]} | _]} -> nil
      _ -> nil
    end
  end

  defp check_non_idempotent_in_perform(call, path, source_file) when is_tuple(call) do
    if in_perform_1?(path) and is_non_idempotent_repo_call?(call) do
      issue(source_file, call)
    else
      nil
    end
  end

  defp in_perform_1?(path) do
    Enum.any?(path, fn
      {:def, _, [{:perform, _, [arg]} | _]} ->
        case arg do
          {:%, _, [{:__aliases__, _, [:Oban, :Job]} | _]} -> true
          {:%, _, [{:__aliases__, _, [:Oban, :Job, :Args]} | _]} -> true
          _ -> false
        end

      _ ->
        false
    end)
  end

  defp is_non_idempotent_repo_call?({:., _, [inner, func]}) do
    if func in @non_idempotent_functions do
      case inner do
        {:__aliases__, _, segments} -> List.last(segments) == :Repo
        _ -> false
      end
    else
      false
    end
  end

  defp is_non_idempotent_repo_call?(_), do: false

  defp issue(source_file, call) do
    {_, meta, [_, func]} = call

    func_str = Atom.to_string(func)

    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      column: meta[:column] || 0,
      trigger: Issue.no_trigger(),
      message: """
        Repo.#{func_str} used in a job perform/1 function. Jobs may be retried on\n" <>
        "failure, so non-idempotent operations cause errors or duplicate data.\n\n" <>
        "Use the non-bang variant (Repo.#{String.replace_trailing(func_str, "!", "")})\n" <>
        "and handle the result explicitly.\n\n" <>
        "  case Repo.#{String.replace_trailing(func_str, "!", "")}(record) do\n" <>
        "    {:ok, _} -> {:ok, result}\n" <>
        "    {:error, _} -> {:ok, result}  # already handled, that's fine\n" <>
        "  end\n"
      """
    }
  end
end
