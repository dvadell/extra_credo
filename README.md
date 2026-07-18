# ExtraCredo

> **Note:** These Credo checks were originally developed from rules documented at [github.com/oliver-kriska/claude-elixir-phoenix](https://github.com/oliver-kriska/claude-elixir-phoenix).

Custom Credo checks that enforce best practices for Elixir/Phoenix projects.

## Installation

Add `extra_credo` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:extra_credo, "~> 0.1.0"}
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
```

## Available Checks

### Extra rules

| Check | What it does |
|---|---|
| `NoPubsubWithoutConnected` | Flags `Phoenix.PubSub.subscribe` calls in LiveView callbacks that aren't guarded by `connected?`, preventing double-delivery. |
| `NoFloatForMoney` | Flags `:float` type used for money-related fields in Ecto schemas and migrations. Use `:decimal` or `:integer` instead. |
| `UnpinnedQueryBindings` | Flags Ecto query variables used without the `^` pin operator, preventing SQL injection risks. |
| `ObanAtomKeys` | Flags atom keys in Oban job args patterns. Oban serializes to JSON (string keys), so atom key matching always fails. |
| `ObanStructInArgs` | Flags structs passed as Oban job args. Structs lose their `__struct__` field during JSON serialization. |
| `NoAuthInHandleEvent` | Ensures every LiveView `handle_event` callback contains an authorization check, since mount-time authorization can be bypassed via WebSocket. |
| `NoRawUntrusted` | Flags `raw/1` calls with potentially untrusted input to prevent XSS vulnerabilities. |
| `NoImplicitCrossJoin` | Flags Ecto queries with multiple `from` bindings missing explicit `join` clauses, preventing Cartesian products. |
| `NoExternalResource` | Flags compile-time file reads (`File.read!`, etc.) at the module level that lack a corresponding `@external_resource` declaration. |
| `NoAssignNewInMount` | Flags `assign_new` usage in `mount/3` for values that should be refreshed on every page load. |
| `NoBareChangesetError` | Flags bare `{:error, _}` pattern matches in `handle_event` that swallow changeset errors and prevent form re-render. |
| `NoDbQueryInMount` | Flags unconditional database queries in `mount/3` that aren't guarded by `connected?`, preventing duplicate queries. |
| `NoNonIdempotentJobs` | Flags bang variants of Ecto repo functions (`insert!`, `update!`, `delete!`) in Oban `perform` functions, since jobs may be retried. |
| `NoDedupBeforeCastAssoc` | Flags `cast_assoc` calls that aren't preceded by deduplication of the input list, preventing duplicate associated records. |
| `NoUnsupervisedProcesses` | Flags `GenServer.start_link`, `Agent.start_link`, `Task.start` outside of a supervisor's children list. |
| `NoDirectThirdPartyCalls` | Flags direct calls to third-party libraries (HTTPoison, Tesla, ExAws, etc.) in context modules. Wrap them in dedicated modules. |
| `NoLocaleInTaskClosure` | Flags Gettext calls inside `Task.async` closures that don't capture the caller's locale first, preventing wrong-locale bugs. |
| `NoCommentsAsCommitMessages` | Flags TODO, FIXME, HACK, XXX comments and issue/PR references that belong in commit messages, not source code. |

## Development

```bash
mix compile
mix format
mix credo
mix dialyzer
MIX_ENV=test mix test
```

## Testing on `iex`
It's useful to use `dbg()` inside `iex` to test rules. 

For example, let's debug `Credo.Check.Extra.NoDirectThirdPartyCalls`:

1. Add a `dbg()` statement in the `run/2` function in `lib/no_direct_third_party_calls.ex`.

2. Run the following into `iex --dbg pry -S mix`:
```
iex> file = "lib/no_direct_third_party_calls.ex"

iex> (
file
|> File.read!()
|> Credo.SourceFile.parse(file)
|> Credo.Check.Extra.NoDirectThirdPartyCalls.run([]) )
```

It will only run `Credo.Check.Extra.NoDirectThirdPartyCalls` and stop in the `dbg()` statement.
