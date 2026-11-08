# WP-05 report — Progress privacy resolver

Branch: cloud/wp-05 (from origin/wip/port-loc)

## Files written
- Core/NativeChannelProgressPrivacyResolver.swift (new; pure resolver, `ChannelPermission`, `Resolved`, `defaultPhotoScope`, `teammateCanSeePhotos`)
- Core/NativeChannelProgressContracts.swift (appended `breadth`/`strictest(with:)` extensions on scope enums; no wire change)
- Core/NativeChannelProgressPrivacyJournal.swift (appended `resolvedValues(preference:channel:)` extension exposing the resolver)
- Tests/CoreTests/WP05ProgressPrivacyResolverTests.swift
- docs/owner-plan/wp-05-new-strings.md (no new strings)

## Tests written (WP05ProgressPrivacyResolverTests)
testStrictestScopeWinsAggregate, testStrictestScopeWinsDetail, testTeammatePhotoDefaultsClosed,
testPhotoOriginalNeverWiderThanDetail, testAuditProjectionNotMergedIntoUserScopes, testLeaderboardOutOverridesChannelIn

## NOT verified
- Nothing compiled or run: no Swift toolchain in this cloud environment. Tests were not confirmed red-then-green.
- Design choices to review: scope strictness order SELF < TEAM < CHANNEL < PUBLIC; detail clamped to never exceed aggregate and never PUBLIC; `.team`/`.admin` photo both treated as non-private and require detail wider than SELF; the audit-projection test is a reflection/rawValue check since no audit type exists in the files in scope.
- The resolver is not wired into the privacy view model (view files are off-list); only exposed via the journal extension.
- Existing `NativeChannelProgress*Tests` untouched and not re-run.
