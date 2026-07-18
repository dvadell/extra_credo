defmodule ExtraCredo do
  @moduledoc """
  Custom Credo checks for Extra rules.

  Add as a dependency in your project's `mix.exs`:

      def deps do
        [
          {:extra_credo, "~> 0.1.0"}
        ]
      end

  Then register the checks in `.credo.exs`:

      %{
        configs: [
          %{
            checks: %{
              enabled: [
                {Credo.Check.Extra.NoFloatForMoney, []},
                {Credo.Check.Extra.NoBareChangesetError, []},
                {Credo.Check.Extra.NoAssignNewInMount, []},
                {Credo.Check.Extra.NoAuthInHandleEvent, []},
                {Credo.Check.Extra.NoExternalResource, []},
                {Credo.Check.Extra.NoImplicitCrossJoin, []},
                {Credo.Check.Extra.NoPubsubWithoutConnected, []},
                {Credo.Check.Extra.NoRawUntrusted, []},
                {Credo.Check.Extra.ObanAtomKeys, []},
                {Credo.Check.Extra.ObanStructInArgs, []},
                {Credo.Check.Extra.UnpinnedQueryBindings, []}
              ]
            }
          }
        ]
      }
  """

  @doc """
  Returns all available check modules.
  """
  @spec checks() :: [module()]
  def checks do
    [
      Credo.Check.Extra.NoAssignNewInMount,
      Credo.Check.Extra.NoAuthInHandleEvent,
      Credo.Check.Extra.NoBareChangesetError,
      Credo.Check.Extra.NoCommentsAsCommitMessages,
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
      Credo.Check.Extra.NoUnsupervisedProcesses,
      Credo.Check.Extra.ObanAtomKeys,
      Credo.Check.Extra.ObanStructInArgs,
      Credo.Check.Extra.UnpinnedQueryBindings,
      Credo.Check.Extra.NoColorfulEmoji
    ]
  end
end
