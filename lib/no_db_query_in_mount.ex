defmodule Credo.Check.Extra.NoDbQueryInMount do
  @moduledoc """
  No unconditional DB queries in mount/3.

  Flags Repo.all/1, Repo.get/2, Repo.get!/2, Repo.one/1, Repo.one!/1,
  Repo.insert/1-2, Repo.insert!/1-2, Repo.update/1-2, Repo.update!/1-2,
  Repo.delete/1, Repo.delete!/1 calls inside mount/3 that are not guarded
  by `if connected?(socket)` or `assign_new`/`assign_async`.

  ## Examples (non-compliant)

      def mount(_params, _session, socket) do
        user = MyApp.Repo.get(User, socket.assigns.user_id)  # [cross] runs twice
        {:ok, assign(socket, :user, user)}
      end

  ## Examples (compliant)

      def mount(_params, _session, socket) do
        if connected?(socket) do
          user = MyApp.Repo.get(User, socket.assigns.user_id)
          {:ok, assign(socket, :user, user)}
        else
          {:ok, socket}
        end
      end
  """

  use Credo.Check,
    category: :consistency,
    exit_status: 2

  alias Credo.Issue
  alias Credo.SourceFile
  alias ExtraCredo.ASTTraversal

  @repo_functions ~w(all get get! one one! insert insert! update update! delete delete!)a

  @spec run(Credo.SourceFile.t(), keyword()) :: [%Issue{}]
  @impl true
  def run(%SourceFile{} = source_file, _params) do
    ASTTraversal.collect_issues_with_path(source_file, &check_mount_db_query/3)
  end

  @spec check_mount_db_query(tuple(), [tuple()], Credo.SourceFile.t()) :: %Issue{} | nil
  defp check_mount_db_query(
         {:def, _meta, [{:mount, _, [_params, _session, _socket]} | _body]},
         _path,
         _source_file
       ) do
    # This is the mount/3 function definition itself; check children via path
    nil
  end

  defp check_mount_db_query(call, path, source_file) when is_tuple(call) do
    if in_mount_3?(path) and repo_call?(call) and not in_connected_guard?(path) and
         not in_assign_new_async?(path) do
      issue(source_file, call)
    else
      nil
    end
  end

  @spec in_mount_3?([tuple()]) :: boolean()
  defp in_mount_3?(path) do
    Enum.any?(path, fn
      {:def, _, [{:mount, _, args} | _]} -> length(args) == 3
      _ -> false
    end)
  end

  @spec repo_call?(tuple()) :: boolean()
  defp repo_call?({:., _, [inner, func]}) do
    if func in @repo_functions do
      case inner do
        {:__aliases__, _, segments} -> List.last(segments) == :Repo
        _ -> false
      end
    else
      false
    end
  end

  defp repo_call?(_), do: false

  @spec in_connected_guard?([tuple()]) :: boolean()
  defp in_connected_guard?(path) do
    Enum.any?(path, fn
      {:if, _, [condition | _]} -> has_connected_call?(condition)
      _ -> false
    end)
  end

  @spec in_assign_new_async?([tuple()]) :: boolean()
  defp in_assign_new_async?(path) do
    Enum.any?(path, fn
      {:assign_new, _, _} -> true
      {:assign_async, _, _} -> true
      _ -> false
    end)
  end

  @spec has_connected_call?(tuple()) :: boolean()
  defp has_connected_call?({:connected?, _, _args}), do: true

  defp has_connected_call?({{:., _, [inner, :connected?]}, _, _args}) do
    case inner do
      {:__aliases__, _, [:Phoenix, :LiveView]} -> true
      {:__aliases__, _, [:Phoenix, :LiveView, :Socket]} -> true
      _ -> false
    end
  end

  defp has_connected_call?(_), do: false

  @spec issue(Credo.SourceFile.t(), tuple()) :: %Issue{}
  defp issue(source_file, {:., meta, [_, func]}) do
    %Issue{
      filename: source_file.filename,
      line_no: meta[:line] || 0,
      column: meta[:column] || 0,
      trigger: Issue.no_trigger(),
      check: __MODULE__,
      category: :consistency,
      message:
        "Repo.#{func}/N in mount/3 without connected? guard. Mount runs twice (init + socket connected), causing duplicate queries. Wrap in `if connected?(socket) do ... end` or use assign_async/3."
    }
  end
end
