# cursor/1128-k40-club

Club directory, club detail, membership and governance behaviour only. No restyle. Pin `a7c956335` on `ui/combined-r7`. Handoff `origin/design/handoff-r2` `249148af0` (`docs/briefs/round3-1127.md`) does not name a K40 lane. Club rows are from `origin/audit/1128-plan` `56629ac8b`, `origin/audit/1128-functions` `b51766f9c`, and `origin/audit/1128-ada` `88849410d`.

`swiftc` and `xcodebuild` are not on this machine. The new tests were not executed. `App/AppSession.swift` was not edited (7977 lines; `tools/check_appsession_ratchet.py` passes). No `String(localized:)`. Play init order stays devices, sensors, artworkHosts. `PlayerLaunch.merchantCenterEnabled` stays false in Release and true under DEBUG/TEST. `ReleaseMoneyWriteSwitch` and `ReviewedAreaSwitch.moneyPayments` were not edited. `api/club/lead/settle` still opens only where `moneyPayments` opens. No secrets, deploys, or SQL.

Backend `XXsocietyee/hengyin` `us/r3-functional` `482f7cdbc036aa84328b76015fe3d656b11a7bf8`. `ApiClubController` `POST /name-check` (line 560) reads `Club.name` and returns `{available, reason}`. `POST /post/like` (line 2409, P1-023) treats a present `liked` as the target state and toggles only when `liked` is absent. `POST /post/operation/comment/{create,receipt}` exists (line 2649). No backend branch.

The player path is `RegionalLaunchConfiguration.reviewedDeployment` / `reviewedComposition`: China host `https://www.chengyinhub.com/prod-api/`, `productionGatesEnabled` and `playerWritesEnabled` true. `api/club/name-check` is on `clubAndMerchantCoopOwnerGrant`, outside `marks` and `wiredPatterns`, so `callSiteCount` stays 996 and `wiredPatternCount` stays 680.

## Fixed this run (2)

| Row | What closed | Test |
|---|---|---|
| P2-4 / C-16 name check | `POST api/club/name-check` `{name}` (trimmed, 1...30, the create-draft cap). A blank, untrimmed, over-long, or extra-key body is refused and does not leave the device. A firewall miss, a transport error, or a non-answer stays `.unchecked` and does not block create. | `ClubPlayerFlowTests.testChinaNameCheckIsOfferedAndSendsTheTrimmedName`; `Fix1128bClubReadRouteTests.testReviewedDeploymentSendsCreateNameCheck` |
| P2-4 like | `POST api/club/post/like` sends `{postId, liked}` with the target opposite the post the player is looking at, so a retry does not flip the like again. An empty body stays refused. | `ClubCommunityTests.testWireContracts`; the same reviewed-deployment test admits `{"liked":false,"postId":20}` and refuses an empty body |

## Already fixed (17)

| Row | SHA |
|---|---|
| P1-10 / C-02 pin `api/club/post/pin` | `b43ea6ed4` |
| P1-11 / C-04 remove member `api/club/remove-member` | `b43ea6ed4` |
| P1-12 统计概览 `api/stats/club` | `b43ea6ed4` |
| P1-12 / C-05 / C-12a settlement summary (withdraw stays refused) | `b43ea6ed4` |
| P1-12 / C-13 customers list | `b43ea6ed4` |
| P1-12 / C-07a series list | `b43ea6ed4` |
| P1-12 / C-06 audience counts | `b43ea6ed4` |
| P1-13 / C-02 post images | `b43ea6ed4` |
| C-13 customers count | `943bb9ac5` |
| C-08 director reads (`topic-manage-stats`, `recruit/overview`, `topic-customers`) | `c39eec637` |
| C-09 查看答案 `api/club/topic-node-answer` | `c39eec637` |
| C-19 报名名册 `api/club/topic-registrations` | `c39eec637` |
| C-07a occurrences `api/club/event-ops/series/occurrences` | `c39eec637` |
| C-07b cancel confirm is a system alert (MP `cy-modal compact` copy) | `9e0847026` |
| C-01b / C-15 merchant sections and the 邀请商家 stage stay behind `merchantCenterEnabled` | `0af9f6208` |
| J-18 / P2-4 club-lead start, arrive, broadcast, edit-ops, unlock, release-station, team-progress. Settle stays on `moneyPayments` | `4a96d2701` |
| ADA d4-detail “Apply again” reason (`myJoinReviewReason` when `myJoinStatus == 2`) | `5d9aa3e46` |

Directory, detail, join, apply, quit, approve, reject, roles, topics, and club chat were already Works in the function audit. They were re-read and not changed.

## Owner-only (15)

| Row | Why it stays |
|---|---|
| P2-4 `api/club/post/operation/comment/{create,receipt}` | The route exists. The player comment button already uses `api/club/post/comment/create`, which the function audit marks Works. `ClubCommentOriginalService.allowsWrites` stays off. A second write path was not opened. |
| C-07c waitlist | `mp-activity`. `registrationWaitlistService` is not a club-directory or governance send. |
| C-18 calendar | `ClubDetailEventsSection` is unmounted. The MP calendar util is also unmounted. Not mounted here. |
| C-12b member discount | Superseded. The MP retired `memberDiscountPrice` on 2026-08-12. |
| C-01b manage-tab IA and gear member rows | Restyle. Member management, roles, and the customer count read already exist. |
| ADA d4-directory alignment and Your clubs / Discover | Restyle. |
| ADA d4-detail baked cover “一起玩 打卡·组队·通关” | K15 `cursor/1128-l10n-art`. |
| ADA d4-detail default tab | Owner ruling 2026-10-22: `ClubDetailTabPolicy.defaultTab` is `.overview` (`e4a32384b`). Not changed. |
| ADA d4-tab-posts invite, icon tint, next-event card | Restyle. |
| ADA d4-members role vocabulary, search, swipe | Restyle. |
| ADA d4-badges refresh and wall chrome | Restyle. |
| ADA d4-stamps personal album on the club page | Restyle. |
| ADA d4-enroll capsule | Restyle. |
| ADA d4-channels row styles | Restyle. |
| ADA d4-channel-chat double header and footer width | Restyle. |
