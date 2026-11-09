# CB37 — persistence versioning

Base `origin/rc/20261108` `67053ccb33c0e1ad35a7508f8546ae9076fd82e5`. Branch `cursor/cb37`.

This note is the schema and the account-switch rule. It is not a test run.

## Schemas

Two account-scoped UserDefaults records, both under the current `RegionalSessionStorageScope.service` namespace:

| Store | Current schema | Older schema | Key |
|---|---:|---:|---|
| Play continuation index | 2 | 1 | `play.continuation.<namespace>.<accountID>.<role>.scopes` and `.titles` (schema 1). Schema 2 adds `.envelope`. |
| Persistence ledger | 1 | none | `questify.persistence.ledger.v1.` + base64 of the length-prefixed namespace and account id |

Roles are `player`, `club`, and `merchant`, the same three as `PlayRecoveryAccountRole`. Schema 2 envelope is sorted-key JSON: `schemaVersion`, `scopes`, `titles`. The ledger records `schemaVersion: 1` and `playContinuation: 2`.

Schema 1 keys stay after migration. `AppSession.loadPausedContinueRuns` still reads them. A write through `persistPlayContinuationScope` refreshes the schema 2 envelope from those keys. A schema 2 envelope that is already present is not replaced by older schema 1 bytes during login or recovery.

A schema newer than the one above is not rewritten and not deleted.

## Migration

`AccountScopedPersistence.apply` on first login or the same account:

- Copies a schema 1 slot into a schema 2 envelope when the scopes array is a string array and the titles dictionary is missing or a string map.
- Writes the ledger once a slot is at schema 2.
- Does not remove schema 1 keys, other accounts, `preferences.language`, or `questify.operations.pending.v1.*`.
- Leaves a corrupt slot in place. A second apply that sees the same schema 2 bytes writes nothing.

## Account switch

Deletion is authorized only for `AccountPersistenceTransition.accountSwitch` where the two positive account ids differ. `authorizesDeletion` is false for logout, first login, the same account, and `from == to`.

`AppSession` remembers the last positive account id across logout. The next positive id is classified there:

- Logout (`account` becomes nil) does not delete.
- The same id again migrates and does not delete.
- A different id deletes the previous account's schema 1 keys, schema 2 envelopes, and ledger, then migrates the incoming account (recovery). An incoming account with no continuation index gets no new keys.
- A future ledger on the previous account blocks that wipe. A future envelope on one role is left in place; understood roles of that account are still removed.

The remembered id is not a credential. No other call site deletes these keys.

## Left in place

Not wiped on an account switch, and not given a new wipe path:

- Operation journals and original receipts (`questify.operations.pending.v1.*` and the other journal keys).
- Durable play-recovery files (the continuation index is only the UserDefaults list; a paused run can be read back from recovery after the index is gone).
- Keychain session vault. Logout still clears that vault the way it already did. This change does not clear it.
- Device preferences (`preferences.language`, sound, hidden stamps).
- Any other account's keys, and any other namespace.

Password login, bank-card withdrawal, and virtual goods are unchanged. `Config/Base.xcconfig` is still `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`, with an empty `QUESTIFY_API_BASE_URL` and an empty `QUESTIFY_SESSION_REALM`. No US API URL and no legal copy were added. `tools/current_ci_manifest.json` was not refreshed. CB26–CB31 view migrations were not done.

## What was not run

This machine has no `swift`, `swiftc`, `xcodebuild`, or `xcrun`. Not run:

- `swift test`
- `swift test --disable-sandbox`
- `xcodebuild` / `xcodebuild test`
- `xcrun`
- an iOS simulator or device
- Flutter `analyze` / `test`
- any deploy, and no request to `47.103.124.64`

`AccountScopedPersistenceTests` was added and not executed. No test was deleted, renamed, or weakened.
