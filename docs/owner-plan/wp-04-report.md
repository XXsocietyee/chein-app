# WP-04 report — Owner-decision guard tests

Branch: cloud/wp-04 (from origin/wip/port-loc). Layer reached: **source written only**.

## Files written
- `Tests/CoreTests/WP04OwnerDecisionGuardTests.swift` (new; only non-doc file)
- `docs/owner-plan/wp-04-new-strings.md` (none needed)
- `docs/owner-plan/wp-04-report.md`

No non-test file and no existing test touched.

## Tests written (`WP04OwnerDecisionGuardTests`)
- `testManagementTransportHasNoChannelMoveRoute` — scans Core/NativeChannelManagement*.swift + NativeTeamChannelManagementSource for move/reparent/transfer-channel routes or symbols and a `case move*`.
- `testNoRandomTeamMatchmakingSymbolsInAppOrCore` — forbids random-matchmaking symbols in Core/App; any other `matchmak*` use outside the two existing reject-only files fails.
- `testFreeExploreCancelQuoteStillUnavailableWithoutServerContract` — runtime: gated canceler and `FreeExploreCancelModel` return/stay `.unavailable`; scan: coordinator still throws `cancellationQuoteUnavailable`, no `cancel-quote` route.
- `testNoClientSideRefundArithmeticInFreeExploreCore` — regex scan of FreeExplore*.swift (comments and string literals stripped) for refund/fee/amount arithmetic; asserts `expectedOutcome` comes from the quote.
- `testShippedCompositionIsUnconfigured` — scans App/RegionalLaunchConfiguration.swift: `makeComposition(reviewed: nil, ...)`, no reviewed path in `composition`, empty approved-URL registry.
- `testNoMinorAgeDerivedFeatureEnablement` — forbids isMinor/ageBand/birthDate-style symbols in Core/App.

## Could NOT verify
- Compile: no Swift toolchain in this cloud environment; nothing was compiled.
- Test run: no test was executed (neither `swift test` nor Xcode).
- Because the tests are source scans, I emulated the regexes/`contains` checks with Python against the current tree: all scans came back clean / all positive checks true. Swift `NSRegularExpression` semantics may differ slightly from Python's `re` (e.g. the `(?i)` inline flag, lookahead) — unconfirmed.
- Scans rely on `#filePath` resolving to the repo (works under `swift test`; may not under a sandboxed Xcode test host). The test is in the Core package target (`Tests/CoreTests`), which cannot import App code, hence source-text for App/.
- Tests were written green-by-construction on the current tree; the "confirm red first" step was not done (they guard absence, so red would require injecting a violation).
- App/ scans iterate the whole App directory; the file list is read at run time.
