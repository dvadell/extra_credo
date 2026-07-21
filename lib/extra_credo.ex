defmodule ExtraCredo do
  @moduledoc """
  Custom Credo checks for Extra rules.

  ## Setup

  Add as a dependency in your project's `mix.exs`:

      def deps do
        [
          {:extra_credo, "~> 0.1.0"}
        ]
      end

  Then register the plugin in `.credo.exs`:

      %{
        configs: [
          %{
            name: "default",
            plugins: [{ExtraCredo, []}]
          }
        ]
      }

  This auto-enables all checks. Use `ExtraCredo.checks/0` to list all available
  checks and cherry-pick individual ones via `checks.enabled` if desired.
  """

  import Credo.Plugin

  @checks [
    Credo.Check.Extra.NoAssignNewInMount,
    Credo.Check.Extra.NoAuthInHandleEvent,
    Credo.Check.Extra.NoBareChangesetError,
    Credo.Check.Extra.NoCommentsAsCommitMessages,
    Credo.Check.Extra.NoColorfulEmoji,
    Credo.Check.Extra.NoDbQueryInMount,
    Credo.Check.Extra.NoDedupBeforeCastAssoc,
    Credo.Check.Extra.NoDirectThirdPartyCalls,
    Credo.Check.Extra.NoExternalResource,
    Credo.Check.Extra.NoFloatForMoney,
    Credo.Check.Extra.NoImplicitCrossJoin,
    Credo.Check.Extra.NoLocaleInTaskClosure,
    Credo.Check.Extra.NoNonIdempotentJobs,
    Credo.Check.Extra.NoPubsubWithoutConnected,
    Credo.Check.Extra.NoRawUntrusted,
    Credo.Check.Extra.NoSingleStepPipeline,
    Credo.Check.Extra.NoUnsupervisedProcesses,
    Credo.Check.Extra.ObanAtomKeys,
    Credo.Check.Extra.ObanStructInArgs,
    Credo.Check.Extra.UnpinnedQueryBindings
  ]

  @recommended_checks @checks

  def init(exec) do
    append_task(exec, :resolve_config, __MODULE__.EnableExtraChecks)
  end

  @doc """
  Returns all available check modules.
  """
  @spec checks() :: [module()]
  def checks, do: @checks

  @doc """
  Returns the recommended check modules (enabled by default via the plugin).
  """
  @spec recommended_checks() :: [module()]
  def recommended_checks, do: @recommended_checks

  defmodule EnableExtraChecks do
    @moduledoc false
    use Credo.Execution.Task

    def call(exec, _opts) do
      extra = Enum.map(ExtraCredo.recommended_checks(), &{&1, []})
      enabled = exec.checks.enabled |> Keyword.merge(extra)
      %{exec | checks: %{exec.checks | enabled: enabled}}
    end
  end
end
