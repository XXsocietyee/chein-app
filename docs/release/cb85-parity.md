# CB85 — pre-merge parity audit

Base: `origin/rc/20261108` `89dcba807e7e5439182ff8852d6600d1fa9fdd49` (2026-11-09 02:57 PT).
Branch: `cursor/cb85`. This pass is the pre-merge audit only.

The post-merge audit is waiting. The UI merge queue is not in this RC. No `docs/parity/page-map.csv` row was marked changed because an unmerged cursor branch exists. Unmerged branch contents were not read and are not evidence. No view was edited. `docs/parity/page-map.csv` was not edited.

Version stays **0.1.0 (1)**. `Config/Base.xcconfig` has `MARKETING_VERSION = 0.1.0` and `CURRENT_PROJECT_VERSION = 1`. This commit does not change those lines.

This RC already contains the `origin/ui/d2`, `origin/ui/d3`, and `origin/ui/d4` merges (`3c312f5d9fe7ccbe8e22235c7a9fea336f20d6ec`, `c1261a40451eab0a8b1cc2eb4f431c90897f83de`, `8be6ba6c44b60052afb6d35734f9f176a0288a5a`). Those commits are not the UI merge queue.

## What was read

`docs/parity/page-map.csv` on this RC: 163 data rows, one header, six columns on every row, no duplicate `mini_path`. Compared with `docs/parity/gap-wave-audit.md` and `docs/parity/exists-audit.md`, which are already in this RC. Each `target_native_screen` path was checked on disk. Cited Swift types were checked against sources in this RC.

Nothing was compiled or run. There is no Swift toolchain here. Pass counts that the notes attribute to `/private/tmp/*.log` are not files in this RC, so they are not new evidence and no row was flipped from them.

## Census (unchanged)

| status | rows |
|---|---:|
| exists | 98 |
| gated | 14 |
| partial | 36 |
| merged-into | 14 |
| dropped | 1 |
| total | 163 |

98 `exists` + 14 `gated` = 112, and `partial` = 36. That matches the post-revert census in `docs/parity/gap-wave-audit.md` (`exists` 112, `partial` 36) when that note's 112 is read together with the separate `gated` status. Each `merged-into:` target names a row in this file. All 163 target files exist.

## Status corrections

None. Files already in this RC do not prove a status change.

- Every GM-AUD `REVERT` row in `docs/parity/gap-wave-audit.md` is already `partial`.
- Every GM-AUD `KEEP` row still has the status that audit left (`exists` or `gated`).
- In `docs/parity/exists-audit.md`, rows marked `SET BACK TO partial` that gap-wave later marked `KEEP` are `exists`. The other set-back rows are `partial`.

## Inspected, not a status change

- `pages/play/poi-challenge/index` is `exists`. Its note still says "the row stays partial". `docs/parity/gap-wave-audit.md` already keeps the status and flags the note text for cleanup. `Tests/CoreTests/ChallengePOISubmissionTests.swift` declares `ChallengePOISubmissionTests`. `App/ChallengePOIView.swift` declares `ChallengePOIHostView`. The note was not rewritten.
- `pages/play/merchant/index` is `gated`. No class `PlayStoreDayCoordinatorTests` exists in this tree. The same note and `docs/parity/gap-wave-audit.md` already say that. `Tests/CoreTests/PlayStoreDayTests.swift` declares `PlayStoreDayServiceTests` with `testRequestsMatchMiniProgram` and `testUnknownCheckinIsResolvedByReadbackNotResent`. `Core/PlayStoreDayCoordinator.swift` exists. Status stays `gated`.
- `pages/club/join-requests/index` is `gated`. The note names `ClubManagementTests` and `ClubOpsJoinNotifyTests`. The methods are present under the classes in those files: `ClubManagementServiceTests.testAllThreeExactJSONRoutesAndNoRetries` in `Tests/CoreTests/ClubManagementTests.swift`, and `ClubOpsJoinReviewReasonTests.testRejectSendsReviewReasonOnlyWhenPresent` plus `testConfirmationFreezesReasonForRejectOnly` in `Tests/CoreTests/ClubOpsJoinNotifyTests.swift`. Status stays `gated`.
