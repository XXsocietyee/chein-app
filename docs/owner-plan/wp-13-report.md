# WP-13 report (cloud builder, branch cloud/wp-13)

## Files written
- `Core/ChannelRevokeIsolation.swift`: added `ChannelRevokePurgeHook` protocol and `ChannelRevokePurgeDispatcher` (at most once per channel/identity/generation, lock-protected). Core hook only; no App use.
- `Core/ChannelRulesAdmission.swift`: added `ChannelRulesAdmission.firstPostGate(consentedVersion:catalog:)` plus a doc note on integer rules version vs hash.
- `Core/NativeChannelOnboarding.swift`: doc comment only (onboarding is not the rules gate; `configuration_hash` is unrelated to the rules version). No behaviour change.
- `Tests/CoreTests/WP13RulesAgreementGateTests.swift`, `Tests/CoreTests/WP13RevokePurgeHookTests.swift`.
- `docs/owner-plan/wp-13-new-strings.md` (none needed), this report.

## Tests written
- WP13RulesAgreementGateTests: testFirstPostRefusedUntilRulesAgreed, testAgreeOnceThenPostAllowed, testRulesUpgradeRequiresSeparateReconsent, testStaleCASConflictKeepsPending
- WP13RevokePurgeHookTests: testRevokeInvokesPurgeCallbackForChannelCaches, testPurgeRunsExactlyOncePerRevoke

## NOT verified
- Nothing compiled or run: no Swift toolchain here. Not built, tests not executed, so not confirmed red-then-green.
- Symbols were checked by grep/reading only (ChannelGovernanceProjection, ChannelMemberAuthorizationProjection).
- Existing tests untouched; I did not re-run them. Xcode project not regenerated for the new test files.
- The purge hook is not wired to any real cache (WP-11 owns cache keys).
- Doc comments in Core files were added within the three listed files; the "hash-vs-integer" note is recorded as a comment and in the gate doc, not as a separate assertion.
