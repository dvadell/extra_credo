%{
  configs: [
    %{
      name: "default",
      files: %{
        included: [
          "lib/",
          "src/",
          "test/",
          "web/",
          "apps/"
        ],
        excluded: []
      },
      plugins: [],
      requires: [],
      strict: false,
      parse_timeout: 5000,
      color: true,
      checks: %{
        disabled: [],
        enabled: [
          # --- Readability ---
          {Credo.Check.Readability.AliasAs, []},
          {Credo.Check.Readability.AliasOrder, []},
          {Credo.Check.Readability.BlockPipe, []},
          {Credo.Check.Readability.FunctionNames, []},
          {Credo.Check.Readability.MaxLineLength, [priority: :low, max_length: 120]},
          {Credo.Check.Readability.ModuleAttributeNames, []},
          {Credo.Check.Readability.ModuleDoc, []},
          {Credo.Check.Readability.ModuleNames, []},
          {Credo.Check.Readability.ParenthesesInCondition, []},
          {Credo.Check.Readability.PreferImplicitTry, []},
          {Credo.Check.Readability.PredicateFunctionNames, [priority: :low]},
          {Credo.Check.Readability.MultiAlias, []},
          {Credo.Check.Readability.Semicolons, []},
          {Credo.Check.Readability.SpaceAfterCommas, []},
          {Credo.Check.Readability.StringSigils, []},
          {Credo.Check.Readability.TrailingBlankLine, []},
          {Credo.Check.Readability.TrailingWhiteSpace, []},
          {Credo.Check.Readability.UnnecessaryAliasExpansion, []},
          {Credo.Check.Readability.VariableNames, []},
          {Credo.Check.Readability.StrictModuleLayout, [priority: :low]},

          # --- Refactoring ---
          {Credo.Check.Refactor.Apply, []},
          {Credo.Check.Refactor.CondStatements, []},
          {Credo.Check.Refactor.FilterCount, []},
          {Credo.Check.Refactor.IoPuts, []},
          {Credo.Check.Refactor.MatchInCondition, []},
          {Credo.Check.Refactor.NegatedConditionsInUnless, []},
          {Credo.Check.Refactor.Nesting, [max_nesting: 3]},
          {Credo.Check.Refactor.RedundantWithClauseResult, []},
          {Credo.Check.Refactor.UnlessWithElse, []},
          {Credo.Check.Refactor.VariableRebinding, []},

          # --- Consistency ---
          {Credo.Check.Consistency.MultiAliasImportRequireUse, []},
          {Credo.Check.Consistency.ParameterPatternMatching, [priority: :low]},
          {Credo.Check.Consistency.SpaceAroundOperators, []},

          # --- Design ---
          {Credo.Check.Design.AliasUsage, []},
          {Credo.Check.Design.TagTODO, [exit_status: 2]},
          {Credo.Check.Design.TagFIXME, []},
          {Credo.Check.Design.DuplicatedCode, []},

          # --- Warnings ---
          {Credo.Check.Warning.Dbg, []},
          {Credo.Check.Warning.IoInspect, []},
          {Credo.Check.Warning.Dbg, []},

          # --- Custom Extra Checks ---
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
          {Credo.Check.Extra.UnpinnedQueryBindings, []},
          {Credo.Check.Extra.NoCommentsAsCommitMessages, []},
          {Credo.Check.Extra.NoDbQueryInMount, []},
          {Credo.Check.Extra.NoDedupBeforeCastAssoc, []},
          {Credo.Check.Extra.NoDirectThirdPartyCalls, []},
          {Credo.Check.Extra.NoLocaleInTaskClosure, []},
          {Credo.Check.Extra.NoNonIdempotentJobs, []},
           {Credo.Check.Extra.NoUnsupervisedProcesses, []},
           {Credo.Check.Extra.NoColorfulEmoji, []}
        ]
      }
    }
  ]
}
