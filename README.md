# IronLawCredo

Custom Credo checks that enforce the Iron Laws for Elixir/Phoenix projects.

## Installation

Add `iron_law_credo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:iron_law_credo, "~> 0.1.0"}
  ]
end
```

Then register the checks in `.credo.exs`:

```elixir
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
```

## Available Checks

| Check | Iron Law | Category |
|---|---|---|
| `NoFloatForMoney` | #4 — Never use `:float` for money | Design |
| `UnpinnedQueryBindings` | #5 — Always pin with `^` in Ecto queries | Security |
| `ObanAtomKeys` | #8 — Oban args use string keys | Consistency |
| `ObanStructInArgs` | #9 — Store IDs, not structs in Oban args | Consistency |
| `StringToAtom` | #10 — No `String.to_atom` on user input | Security |
| `NoAuthInHandleEvent` | #11 — Authorize in every `handle_event` | Security |
| `NoRawUntrusted` | #12 — Never `raw/1` with untrusted content | Security |
| `NoImplicitCrossJoin` | #15 — No implicit cross joins in Ecto | Design |
| `NoExternalResource` | #16 — `@external_resource` for compile-time files | Consistency |
| `NoPubsubWithoutConnected` | #3 — Check `connected?` before PubSub subscribe | Consistency |
| `NoAssignNewInMount` | #21 — Never `assign_new` for values refreshed every mount | Consistency |
| `NoBareChangesetError` | #24 — Match `{:error, %Ecto.Changeset{}}` explicitly | Consistency |

## Development

```bash
mix compile
mix test
mix credo
mix dialyzer
```
