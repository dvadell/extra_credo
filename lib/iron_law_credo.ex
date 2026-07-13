defmodule IronLawCredo do
  @moduledoc """
  Custom Credo checks for Iron Laws.

  Add as a dependency in your project's `mix.exs`:

      def deps do
        [
          {:iron_law_credo, "~> 0.1.0"}
        ]
      end

  Then register the checks in `.credo.exs`:

      %{
        configs: [
          %{
            checks: %{
              enabled: [
                {Credo.Check.IronLaw.NoFloatForMoney, []},
                {Credo.Check.IronLaw.NoBareChangesetError, []},
                {Credo.Check.IronLaw.NoAssignNewInMount, []},
                {Credo.Check.IronLaw.NoAuthInHandleEvent, []},
                {Credo.Check.IronLaw.NoExternalResource, []},
                {Credo.Check.IronLaw.NoImplicitCrossJoin, []},
                {Credo.Check.IronLaw.NoPubsubWithoutConnected, []},
                {Credo.Check.IronLaw.NoRawUntrusted, []},
                {Credo.Check.IronLaw.ObanAtomKeys, []},
                {Credo.Check.IronLaw.ObanStructInArgs, []},
                {Credo.Check.IronLaw.StringToAtom, []},
                {Credo.Check.IronLaw.UnpinnedQueryBindings, []}
              ]
            }
          }
        ]
      }
  """

  @doc """
  Returns all available check modules.
  """
  def checks do
    [
      Credo.Check.IronLaw.NoAssignNewInMount,
      Credo.Check.IronLaw.NoAuthInHandleEvent,
      Credo.Check.IronLaw.NoBareChangesetError,
      Credo.Check.IronLaw.NoExternalResource,
      Credo.Check.IronLaw.NoFloatForMoney,
      Credo.Check.IronLaw.NoImplicitCrossJoin,
      Credo.Check.IronLaw.NoPubsubWithoutConnected,
      Credo.Check.IronLaw.NoRawUntrusted,
      Credo.Check.IronLaw.ObanAtomKeys,
      Credo.Check.IronLaw.ObanStructInArgs,
      Credo.Check.IronLaw.StringToAtom,
      Credo.Check.IronLaw.UnpinnedQueryBindings
    ]
  end
end