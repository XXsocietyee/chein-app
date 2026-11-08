# WP-14 report — NPC chat-data revoke / expiry UX

## Files written
- `App/NPCChatDataView.swift`: `NPCChatDataConsentState`, `NPCChatDataConsentProbe`; view model gains optional `consent`, `refreshConsent()`, `revokeConsent()`, `consentNoticeKeys`, `canRevokeConsent`; view shows revoke button / ended notice, hides reload once ended. Clearing uses existing `coordinator.invalidate()`.
- `App/NPCChatDataReadSettingsEntry.swift`: optional `consentProbe` closure passed through the presentation to the view.
- `Tests/AppUnitTests/WP14NPCChatDataRevokeTests.swift`
- `docs/owner-plan/wp-14-new-strings.md`, this report.

## Tests written
`WP14NPCChatDataRevokeTests`: `testRevokeClearsLocalCopiesAndShowsRevokedState`, `testExpiredConsentShowsExpiredState`, `testRevokeDoesNotClaimServerDeletion`.

## Could NOT verify
- Nothing was compiled or run (no Swift toolchain in this cloud environment). Tests were not run red or green.
- Production wiring: the approval object is only reachable through `AppSession.composition` (private), and AppSession is off-limits. `SettingsView` passes no `consentProbe`, so in the shipped build the revoke/expiry UI is dormant (behavior unchanged). A follow-up needs an AppSession accessor that builds an `NPCChatDataConsentProbe` from `NPCChatDataReadApproval` (`revoked`, `expiresAt`, `revoke()`).
- The four new strings are not in xcstrings (keys render raw until added).
- Rendered UI / device behavior; the `Button(role:)` revoke label and `ForEach(id: \.self)` over strings were not compiled.
- Whether the 'NPCChatDataViewTests' and 'NPCChatDataIndependentHostTests' still pass (call sites were left source-compatible via default parameters).
