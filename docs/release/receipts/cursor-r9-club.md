# cursor/r9-club

Base `d9115273d70e5b88343b2a14f81d111bf515c561`. Audit `origin/audit/parity-r9-club` `docs/audit/parity-r9/club.md`. Mini-program `liboyang42-cpu/hengyin` `chengyinhub-xcx` at `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.

Owned rows are the fix-queue rows whose owner is exactly Cursor Core. Money stays off. Settlement stays POST. Mine body stays `{}`. Summary stays `POST {clubId}`; `personal: true` only for `personal=1`. Pay, refund execution, payout, withdrawal, paid orders, quote, registration create, and pricing confirm are not built or sent. `swiftc` was not run. Ratchet ceilings were not raised (`App/AppSession.swift` 7994, `App/AppCompositionRoot.swift` 4177).

Code SHA for every row below: `097702ffb13c571372fcf8fa742805f3e984aadf`.

## Rows

| Row | Status | SHA | file:line |
|---|---|---|---|
| CLB-r9-gate-01 | done | `097702ffb13c571372fcf8fa742805f3e984aadf` | `App/ReviewedPlayerWriteLeases.swift:1426`, `Core/ClubGovernanceProduction.swift:29`, `Core/ClubGovernanceProduction.swift:58`, `App/MPFirstClubApprovals.swift:9`, `App/AppCompositionRoot.swift:3593` |
| CLB-r9-gate-02 | done | `097702ffb13c571372fcf8fa742805f3e984aadf` | `App/AppCompositionRoot.swift:607`, `Core/ClubRoleAssignmentOriginal.swift:27`, `Core/ClubRoleRevocationOriginal.swift:27`, `Core/ClubRoleAssignmentOriginal.swift:84` |
| CLB-r9-gate-03 | done | `097702ffb13c571372fcf8fa742805f3e984aadf` | `App/AppSession.swift:6072`, `Core/ClubOperationsService.swift:223`, `App/MPFirstClubApprovals.swift:68` |
| CLB-r9-gate-04 | done | `097702ffb13c571372fcf8fa742805f3e984aadf` | `App/AppCompositionRoot.swift:377`, `App/AppCompositionRoot.swift:608`, `App/AppCompositionRoot.swift:609`, `App/MPFirstClubApprovals.swift:46` |
| CLB-detail-42 | done | `097702ffb13c571372fcf8fa742805f3e984aadf` | `Core/ClubDetailTabs.swift:84`, `Tests/CoreTests/ClubDetailTabTests.swift:58` |

## What each row does

- **CLB-r9-gate-01.** A signed-in China player session with player writes gets a live `ClubGovernanceProductionApproval` for ban, unban, transferOwner, report, appeal, hostApply, and dissolve. `canDispatch` is true without a pre-bound member. Exact target grants are unchanged (`liveOperations` stays empty). `reportHours`, `cancelOccurrence`, `endTopic`, and `submitEvidence` are not in the set. The firewall admits those seven POSTs and their review reads. `api/club/dissolve` is the governance POST, not a payment.
- **CLB-r9-gate-02.** The same session gets `clubRoleAssignmentApproval` and `clubRoleRevocationApproval` for any positive club. The server checks the role. A valid assign body, including `customerPhoneVisible` only for `EVENT_CHECKIN`, matches `ClubRoleAssignmentRoute`. `{"id":1}` still does not. Unconfigured roots keep the nil closures.
- **CLB-r9-gate-03.** `ClubOperationsSessionAccess` reads a live approval and the existing operation journal. `writeAvailability` is `.approved` only when the signed-in China player-write session matches the club session, so edit no longer stops on `暂时无法保存修改`. Create, update-mine, the three open-settings, and set-member-role are the admitted POSTs.
- **CLB-r9-gate-04.** `clubPostOriginalApproval` and `clubCommentOriginalApproval` stay nil. The mini-program post and comment paths are already in `clubCommunityPaths`. `clubPublicRosterApproval` is on, so `POST api/club/leaderboard` is not blocked; the revision is cached so the read fence stays stable. Welcome-note write and receipt approvals are on, and the original journal directory is set only when the caller did not set one. Badges are not one of these four closures and were not turned on.
- **CLB-detail-42.** `ClubDetailOverviewFactsGrid` is deleted. The App view is already gone. Enrollment header assertions stay in `testEnrollmentHeaderFormatting`.

## Left off

Pay, refund execution, payout, withdrawal, paid orders, quote, registration create, and pricing confirm do not build or send. No owned row needed a money send, so none is marked blocked. Settlement mine and summary were not changed. Claude-owned rows were not taken.
