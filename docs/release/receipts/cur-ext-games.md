# cur-ext-games (2026-11-13)

App side of handover 18, plus the 2026-11-13 owner correction. Rebased onto `a9d609a610d61e74e76d814f0453b880798cd657` (`origin/ui/main`). Backend was read only: hengyin `feature/game-import-review` `e10a8e98f22b07f490a82d207d40692caaa67402`, `docs/delivery/game-import-review/HANDOVER.md`. This package does not turn money on.

## Switch

`App/ReviewedAreaSwitch.swift` stays the `ui/main` file. This branch does not declare a second enum. `productionAPIHost` and `productionHost` are the same string. Money calls (`moneyPayments`, `payout`, `merchantWrites`, `passwordLogin`) exist as both `(apiHost:testOrDebug:)` and `(host:testOrDebug:)`; this change does not call them. The backpack and the launch read use `externalGames(host:testOrDebug:)`, which also needs TEST/DEBUG. `externalGames(apiHost:)` is host-only and is not the mount. `PlayExperienceView` passes `ExternalGameSessionRead.externalGamesOpen(baseURL:)`. Callers that omit the flag still hide the library.

## What the player sees

In a test/debug build that is not pointed at the production host, the backpack game tab shows:

- An in-app index of the approved catalog: name, version, rating, author or an em dash, summary or an em dash, permissions, domains, sha256, monetization `NONE`. Copy states HTML/JavaScript only, no native code, bridge `1.0` limited to `getMetadata`, `loadProgress`, `saveProgress`, `haptic`.
- Download and install from the approved catalog. The client follows the server's signed expiring `downloadPath` and will not accept a path outside `/api/external-game/catalog/.../package`.
- My submissions: status, reject reason or an em dash, resubmit, cancel.
- Report (`/api/external-game/reports`) and the existing on-device block.
- An age-rating confirmation per game id and rating, before launch.
- The existing per-game permission sheet. Acceptance is remembered per id and version.
- A kill switch: the next launch reads the approved catalog and removes installed games whose ids are absent. A failed catalog read does not remove anything.

Removal copy follows the backend and does not invent a shorter SLA: a submission still `PENDING` is escalated after the server review window (default 3 days, reason `REVIEW_TIMEOUT`); a report stays open until the server marks it resolved; an unpublished game leaves the device on the next successful catalog read.

## Contract

- The hard-coded HMAC secret and `signManifest` are gone. Install and launch verify the server Ed25519 signature (128 hex chars, 32-byte `publicKeyRaw` from `GET /api/external-game/signing-key`). No key, or a bad signature, fails closed.
- An author package is hashed and structure-checked, then posted as multipart `archive` with `monetization=NONE`. The server ignores a client signature.
- A `.qmod` / ZIP (`PK`) blob is refused and is not submitted. The separate workshop package is not implemented. `importQmod` still returns waiting for the original.
- Workshop `markReviewPending` is unchanged. An external-game submission records its request id on the gate. `PENDING` and `ESCALATED` stay `reviewPending` and store the server status. `APPROVED`, `REJECTED`, and `CANCELLED` move to `externalGameReviewed`. Any other status returns false and leaves the saved request id.
- A lost response (`unknown`) keeps the request id and the archive body and is not shown as success. A confirmed 4xx is a refusal, not a success. The status line uses an em dash until the server confirms one.

## Routes

Appended in `App/ReviewedPlayerWriteLeases.swift` (`playPaths`, `externalGamePaths`, `reportPaths`) and `Core/ChinaReviewedRouteCapability.swift` (`externalGameOwnerGrant`, `externalGameGrantKey` for non-numeric catalog ids). A body that carries `"price"`, `"iap"`, or `StoreKit` is refused. Reports and cancel are JSON. Submit and resubmit are multipart and must say `monetization` `NONE`.

`App/AppCompositionRoot.swift` did not gain a line (still 4169, the same count as `ui/main`). The existing early query return now also keeps `api/external-game/` so the catalog cursor and the signed download query are not dropped before the lease. `App/AppSession.swift` was not edited. `App/RegionalLaunchConfiguration.swift` was not edited. `docs/release/contract-failing-baseline.txt` was not raised.

## Checks

`python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` passed on this tree. Swift/Xcode was not run here (no Apple SDK on this machine). CryptoKit Ed25519 verification is covered by `ExternalGameImportTests` for a machine that can compile it.
