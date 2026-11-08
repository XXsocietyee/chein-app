# WP-10 report (cloud builder)

## Files written
- `Core/ClientOperationID.swift` (new): `ClientOperationID` (value/subject/object/bodyHash, SHA-256 body hash), `ClientOperationIDStore` protocol, `InMemoryClientOperationIDStore`, `FileClientOperationIDStore` (write-through JSON journal), `ClientOperationIDError`.
- `Core/OfflinePackOperation.swift` (edit): `inspect` forbidden keys now include `codeHash` and `code_hash`. Nothing else changed.
- `Tests/CoreTests/WP10ClientOperationIDTests.swift`, `Tests/CoreTests/WP10OfflinePackHashRejectionTests.swift`.
- `docs/owner-plan/wp-10-new-strings.md` (no strings needed), this report.

## Tests written
- WP10ClientOperationIDTests: testIDBoundToSubjectObjectAndBodyHash, testResumeReusesOriginalID, testDifferentBodyYieldsDifferentID, testAccountSwitchNeverReusesID, plus extra testFileJournalSurvivesReload.
- WP10OfflinePackHashRejectionTests: testCodeHashFieldRejected, testSnakeCaseCodeHashRejected, testAnswersStillRejected.

## NOT verified
- Nothing compiled or run: no Swift toolchain in the cloud container. Syntax and API use are by inspection only.
- Tests were not run red-first, so "fails for the right reason" is unconfirmed.
- `git diff --stat` shows `docs/owner-plan/*` files, which the builder prompt says docs are off limits, but the task prompt explicitly requested them.
- Hash rejection matches exact keys only (as the existing list does); case variants like `CodeHash` are not rejected.
- No feature is migrated onto ClientOperationID (per WP scope).
