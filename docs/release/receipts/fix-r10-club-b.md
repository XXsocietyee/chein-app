# fix-r10 · lane club-b receipt (2026-11-26)

Branch `fix/r10-club-b` from `origin/ui/combined-r7` (d9832ac50). Slice: club.md P0 second half (CLB-G13a), then the
release-dead rows gate-05 / badges-01 / group-code-01 / notify-01. No compiler in the cloud: every type and member was
grepped before use. Not built on a simulator.

| Row | Status | SHA | App / Core file:line |
|---|---|---|---|
| CLB-r10-gate-05 | **fixed** | 193356907, a22f25659 | Core/ClubGovernanceProduction.swift:31-40 (`clubOps`: sendNotification, retryNotification, issueGroupCode, saveCustomer, createSeries, updateSeries, correctAttendance, saveTopicSettings, chapterRecruit, chapterFinish joined to `governance`); App/MPFirstClubApprovals.swift:89-127 (write + review-read paths on `governancePaths`; multipart `formPaths` for chapter recruit/finish). cancelOccurrence, endTopic, reportHours, submitEvidence stay out (money). Tests: Tests/CoreTests/ClubGovernanceProductionTests.swift `testMPFirstClubOpsDispatchInChina` (each of the 10 has a production service in China); Tests/AppUnitTests/ReviewedChinaLaunchCompositionTests.swift (Release China composition's `clubGovernanceApproval.liveOperations ⊇ clubOps`). Contract pin re-hashed with a comment: Tests/ContractChecks/test_club_customer_permissions.py:114-118. |
| CLB-r10-badges-01 | **fixed** | 704e52991 | Core/ClubBadgeManagementModels.swift:66-87 (`init(mpFirstEndpoints:)`, `anyClub`; reads + create + grant); App/MPFirstClubApprovals.swift:38-49 (`badges(_:)`, one approval per session identity so the revision is stable); App/AppCompositionRoot.swift:173 (`private(set) var`), :609 (set inside `grantPlayerWrites`); firewall App/MPFirstClubApprovals.swift:100, 126. Tests: ClubBadgeHostDefaultTests `testMPFirstBadgeApprovalInChina`; ReviewedChinaLaunchCompositionTests asserts non-nil in Release China. The unconfigured-composition nil test is kept (still true). |
| CLB-r10-group-code-01 | **fixed** | 193356907, 7c201f047 | issueGroupCode is in `clubOps` (gate-05); its multipart review read `api/topic/info-to-user` joins `formPaths` (App/MPFirstClubApprovals.swift:103). CLB-group-code-06 (receipt checked by activityId, no clubId) was already on the base: App/ClubGovernanceCommandForm.swift:892-899. |
| CLB-r10-notify-01 | **fixed** | 193356907, fabccf0a7 | send/retry in `clubOps`; paths + preview/status reads on the firewall. Firewall test: Tests/AppUnitTests/MPFirstClubWriteRouteR10Tests.swift (admits the r10 club POSTs, chapter multipart, badges; refuses cancel/end/hours and money keys). |
| CLB-G13a | **partly** | 6428e0c58 | App/ClubTopicDirectorOpsSections.swift:10, 48; App/ClubTopicDirectorMount.swift:56-57: 通用玩法 rows are disabled while the director phase is not `ready`. **Blocked:** the per-action sheet (fields, 时间为北京时间, ledger rows, 确认并提交). MP `pages/club/topic-detail/index.wxml:204-236` and its JS are not in this repo and `chengyinhub-xcx` is not reachable from this session, so the per-action payloads for `api/game/session/command` can't be ported MP-first. parity-b receipt also notes the director manual actions are outside the player grant. Needs the MP source (or a Core payload spec) before an App sheet. |

## Round 2 (2026-11-26)

Merged `origin/ui/combined-r7` @ 49af0d3ad (coordinator's two compile fixes on the tip). `chengyinhub-xcx` is still not
reachable (`add_repo` → no access), so CLB-G13a stays **partly / blocked** as above.

| Row | Status | SHA | App / Core file:line |
|---|---|---|---|
| Coordinator: exact-body reads | **fixed** | a87621f5d | The `api/club/members` exact-body check the brief describes was not on the tip, so it lands here. App/MPFirstClubApprovals.swift `accepts`: badge paths (incl. `api/club/detail` `{"id"}` and `api/club/members` `{"clubId"}`) pass only when `ClubBadgeManagementRoute(request:baseURL:)` parses them (exact keys); every other review read on the route has a `ReadShape` (exact key set, ids positive non-bool integers) taken from `ClubGovernanceRead.fields`. Tests: MPFirstClubWriteRouteR10Tests `testReadsAdmitOnlyTheirExactBody` (extra `amount`, 0, string, bool, missing, fractional ids all refused). The write paths still use the money-key rule only. |
| CLB-r10-join-requests-01 | **fixed** (was a real gap) | 03d5694d0 | Traced: `ClubManagementSessionAccess` sends `api/club/join-requests` and `api/club/join-request/approve|reject` (Core/ClubManagementService.swift:20, 41-48, Core/ClubManagementContracts.swift:32-33) and **no** branch of the Release China firewall admitted them (only `api/join-request/*` for channels and `api/club/join-requests/apply`). Added to `MPFirstClubWriteRoute.governancePaths` with exact shapes: list `{clubId}`, approve `{clubId, memberId}`, reject `{clubId, memberId, reviewReason?: String}`. Test `testAdmitsJoinRequestReviewOnItsExactBody`. `api/club/remove-member` is still not admitted (not in this row; flag for the coordinator). |
| CLB-r10-create-01 | **fixed** | 03d5694d0 | App/ClubOperationsViews.swift:545-547, 800-801: comments now say a taken name shows 去改名称 and the wizard goes back only on tap (no auto-jump). |
| CLB-r10-roles-01 | **verified, no change** | — | App/ClubGovernanceViews.swift:945-961: a failed re-read after the roles sheet restores the kept snapshot and sets `roleRereadToast = "club.roles.rereadFailed"` (列表没刷新成功，下拉重试), shown by `.clubIslandStatus` at :382. |
| CLB-r10-apply-01 | **fixed** | (this push) | App/ClubGovernanceViews.swift hostStatus merchant branch: 切换到商家端 is a Button that presents the merchant home as a new root (`cyFullScreenCover` + NavigationStack, 关闭) instead of a push; 查看商家入驻 stays a push (MP navigateTo). Still behind `PlayerLaunch.merchantCenterEnabled` (hidden in Release). |
| CLB-r10-apply-02 | **blocked** | — | Needs the merchant-status read the MP apply page uses (apply/index.js:99-110); the MP source isn't reachable and Core has no `merchantActive` producer. App keeps `?? true`. |
| Older P2 rows | already landed | — | gate-04, detail-42, r9-detail-01/03, r7-A-07, r9-native-02/05/07, G13d, topic-detail-05, r9-topic-detail-01/02, topic-story-06, r9-topic-story-01, event-ops-05, r8-governance-01, r9-create-01/03, enroll-08, r9-enroll-01, r9-edit-01, r8-badges-02, workbench-03, r9-payout-receiver-02 carry row-id comments in code from fix-r8/r9 (checked the r9-create-01, topic-story-06, r7-A-07, native-07 lines). Not re-done. |
| CLB-r9-event-ops-01, r9-create-02, r9-create-04 | **not done** | — | Same reasons as fix-r9-club-a: create-04 reverses owner MC-10 (needs an owner call); create-02 and event-ops-01 need the host-status hand-over / series-create return machinery. |

## Round 3 (2026-11-26)

Merged `origin/ui/combined-r7` @ ae477be47 (one comment-only conflict in App/ClubOperationsViews.swift, took the tip's
wording). Re-checked the coordinator items on the tip: `ClubMPFirstGovernance.governance` is typed
(Core/ClubGovernanceProduction.swift:32), AppCompositionRoot assigns via `self.clubBadgeManagementApproval` (:609), and
`MPFirstClubWriteRoute` admits `api/club/detail` only as `{"id": positive}` and `api/club/members` only as
`{"clubId": positive}` through `ClubBadgeManagementRoute` (Core/ClubBadgeManagementModels.swift:112, 125), with every other
read on the route held to its `ReadShape` (App/MPFirstClubApprovals.swift:139-179). No change needed. CLB-G13a stays
**partly / blocked** (MP topic-detail director source still not reachable).

P2 rows not claimed by club-a/c/d receipts:

| Row | Status | SHA | App file:line |
|---|---|---|---|
| CLB-r10-nat-settlement-05 | **fixed** | 377be9f17 | App/ClubOwnerFundsView.swift:231-245, 278-286: CYBalanceHeroLocal / CYMoneyRowLocal and their preview deleted; one `moneyRow` `LabeledContent` (monospaced) for 可提现 / 待结算 / 投诉期 / 争议; no numericText motion. |
| CLB-r10-nat-checkin-02 | **fixed** | a9a540084 | App/ClubOwnerRefundPanel.swift:30-58: `.cyText` → system `.headline` / `.subheadline`. The review sheet was already `NavigationStack { List }` with toolbar 取消 / destructive 确认. Refund dispatch unchanged (money-gated by the coordinator). |
| CLB-r10-nat-join-requests-01 | **fixed** | 497afb251 | App/ClubManagementView.swift:312-317: row 通过 is `.borderedProminent` `.small` (拒绝 stays `.bordered`; swipe kept). Rows, empty/sign-in states and loading were already system. |
| CLB-r10-nat-checkin-01 | **fixed** | d24ab1c1c | App/ClubCheckinRailView.swift:155-160: no-cover placeholder is `Image(systemName: "photo")` in the same footprint. Full-page states were already `ContentUnavailableView`. |
| CLB-r9-native-01 | already closed | 1ae8bd9d8 (club-c) | App/ClubTopicDetail+Port.swift:26-36 (no `minimumScaleFactor`). |
| CLB-r9-native-03 | already closed | — | App/ClubOpsEventView.swift:57-69 and ClubPayoutReceiverView:84-99 use `ContentUnavailableView` + 重新加载. |
| CLB-r9-native-06 | already closed | — | App/ClubBadgeManagementView.swift:16-31 (List + ContentUnavailableView + 重新加载). |
| CLB-r9-native-04 | dropped | — | Audit marks it superseded (system font + secondary is already native). |
| CLB-r10-nat-settlement-01 | **held** | — | Remaining item is `.cyDomainScreen(.player)` (App/ClubPayoutReceiverView.swift:68, 238, 300). Removing it changes the page ground and tint, which the owner's no-theme-change rule forbids this round. Loading/failure are already system. |

Still open for any lane: nat-topic-story-02..05, nat-event-ops-*, nat-shared-*, nat-governance-*, nat-roles-*, nat-apply-*,
nat-create-*, nat-enroll-*, nat-edit-*, nat-notify-*, nat-settlement-02/03/04/06, nat-payout-receiver-*, nat-customer*,
nat-group-code-02/03, nat-workbench-*, topic-story-08, event-ops-09, r10-detail-01/02 (Core).

## Gates (last run before push)

- Round 3: check_scaffold PASS, a11y lint PASS (0 new); contract ratchet see below.

- Round 2 (after merging combined-r7 @ 05caead53): check_scaffold PASS, a11y lint PASS (0 new), appsession ratchet PASS, contract ratchet `192 failing, baseline 192, new 0`. Not compiled (no Xcode in the cloud); merge conflict in App/MPFirstClubApprovals.swift resolved to this lane's ReadShape/badge-route check, which covers the coordinator's members `{clubId}` rule (60488e930).

Round 1:

- `python3 tools/check_scaffold.py`: PASS structural checks.
- `python3 -B tools/check_a11y_lint.py`: PASS (0 new).
- `python3 tools/check_appsession_ratchet.py`: PASS (AppCompositionRoot kept at 4175 lines).
- `python3 -B tools/contract_ratchet.py --check`: the only new failure is `test_social_article_content…test_renderer_is_wired_only_to_existing_scoped_article_contents`. It fails the same way on the untouched base `origin/ui/combined-r7` (d9832ac50), so this lane didn't cause it.
- New file → `python3 tools/generate_project.py` run.

## Notes for the coordinator

- club-a's slice ("P0 first half") also names gate-05/badges-01. If club-a pushed the same rows, keep one side. These hunks are small: Core/ClubGovernanceProduction.swift:31-40, App/MPFirstClubApprovals.swift, AppCompositionRoot.swift:173/609.
- `MPFirstClubWriteRoute.accepts` now checks Content-Type per path (JSON for the existing paths, multipart only for the three `formPaths`). The JSON paths behave as before.
