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

      %Credo.Config{
        checks: [
          %{check: Credo.Check.IronLaw.NoFloatForMoney},
          %{check: Credo.Check.IronLaw.NoBareChangesetError},
          %{check: Credo.Check.IronLaw.NoAssignNewInMount},
          %{check: Credo.Check.IronLaw.NoAuthInHandleEvent},
          %{check: Credo.Check.IronLaw.NoExternalResource},
          %{check: Credo.Check.IronLaw.NoImplicitCrossJoin},
          %{check: Credo.Check.IronLaw.NoPubsubWithoutConnected},
          %{check: Credo.Check.IronLaw.NoRawUntrusted},
          %{check: Credo.Check.IronLaw.ObanAtomKeys},
          %{check: Credo.Check.IronLaw.ObanStructInArgs},
          %{check: Credo.Check.IronLaw.StringToAtom},
          %{check: Credo.Check.IronLaw.UnpinnedQueryBindings}
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