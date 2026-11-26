# Club parity + native audit r10: mini-program `pages/club/*` vs `ui/combined-r7`

This is a reviewer report; no product code was edited. Briefs: `design/handoff-r2:docs/briefs/audit-parity-r9.md` (method), `native-r2.md` ("EVERYTHING native") and `owner-decisions-1124.md` (MP-first). Baseline: `audit/parity-r9-club:docs/audit/parity-r9/club.md`.

- **App:** `origin/ui/combined-r7` @ `82bcf2c2d`. r9 measured `ebf6c160c`, and 212 commits have landed since.
- **MP:** `hengyin/chengyinhub-xcx`. Nothing changed under `pages/club`, so all 574 denominator rows are the same as in r9.
- **Scope:** the player and club-manager side of every club page. Club owner/ops money (pay, refund, payout bind, withdraw, settle, host-cancel refund) stays gated, and those rows are marked **money, not a gap**.
- **Scoring:** same as r9. Only "present" counts. A view counts only if it is mounted from a reachable screen. A write counts in the **release** score only if it actually dispatches in a Release build.
- **Evidence:** every r9 row was checked in code, not in commit messages. Shas are cited where the fix landed.
- **Abbreviations:** `GV` = App/ClubGovernanceViews.swift, `CF` = App/ClubGovernanceCommandForm.swift, `OPS` = App/ClubOperationsViews.swift, `PRV` = App/ClubPayoutReceiverView.swift, `R8M` = App/ClubDetailR8Mounts.swift, `MPRPS` = App/MPReviewedPageScreen.swift, `CDV` = App/ClubDetailView.swift.

## 1. Parity

| MP page | r9 code | **r10 code** | Δ | r10 release | NATIVE | CY* uses | custom chrome sites |
|---|---|---|---|---|---|---|---|
| detail | 120/137 | **126/137** | +6 | 126 | partly | ~118 | 23 |
| topic-detail | 35/49 | **36/49** | +1 | ≈32 (gate-05) | partly | ~19 | ~12 |
| topic-story | 31/35 | 31/35 | 0 | 31 | partly (gameplay card is custom and forced dark) | ~13 | ~13 |
| event-ops | 34/43 | **36/43** | +2 | ≈32 (gate-05) | partly | ~19 | ~9 |
| governance | 25/27 | **26/27** | +1 | 26 | partly | 10 | 5 |
| roles | 24/24 | 24/24 | 0 | 24 | partly | 7 | 6 |
| apply | 22/24 | **23/24** | +1 | 23 | partly | 12 | 6 |
| create | 20/25 | **21/25** | +1 | 21 | partly | 17 | 9 |
| enroll | 21/24 | 21/24 | 0 | 21 | partly | 9 | 6 |
| edit (+scene-club-edit) | 23/25 | **24/25** | +1 | 24 | partly | 7 | 8 |
| badges | 24/25 | 24/25 | 0 | **0 (unreachable, badges-01)** | **custom** | 21 | 4 |
| notify | 20/21 | 20/21 | 0 | ≈18 (send/retry dead) | partly | 7 | 5 |
| settlement | 14/15 | **15/15** | +1 | **15** | partly | ~41 | ~16 |
| customer-detail | 19/20 | 19/20 | 0 | 18 (save dead) | partly | 8 | 4 |
| checkin-detail | 16/16 | 16/16 | 0 | 16 (refund = money) | partly | 8 | 4 |
| join-requests | 17/17 | 17/17 | 0 | 17 (not traced, join-requests-01) | partly | ~10 | ~12 |
| group-code | 11/13 | 11/13 | 0 | **≈3 (issue dead)** | partly (hex dark QR card) | 9 | 9 |
| customers | 15/15 | 15/15 | 0 | 15 | partly | 4 | 5 |
| payout-receiver | 12/14 | 12/14 | 0 | 12 (bind = money) | partly | 10 | 3 |
| workbench | 4/5 | 4/5 | 0 | 4 | partly | 4 | 5 |
| **total (20 pages)** | **507/574 (88.3%)** | **521/574 (90.8%)** | **+14** | **≈478/574 (≈83%)** | **0 native · 19 partly · 1 custom** | **515 CY\* call sites in 143 club files** | — |

### Area parity: 88.3% → 90.8% on code (+2.5 pts, +14 rows). Release is about 83%.

- **No scored row regressed.**
- **Code regression:** detail-42's dead Core type was restored in 202e62bb6 (folded into CLB-detail-42).
- **To verify:** 4df2d6204 removed the roles re-read failure toast (列表没刷新成功，下拉重试). This is CLB-r10-roles-01.

### Release score

- **r9 blockers now dispatch:** r9's release blockers gate-01, -02 and -03 are fixed in 097702ffb, so governance, roles, apply, create and edit now dispatch in Release (China).
- **Newly found dead writes:** r10 finds two Release blockers that r9 missed. Both were already present at `ebf6c160c`, so the lower release figure is a correction, not a regression.
  - **gate-05:** the MP-first governance approval covers only 7 mutations, so 10 non-money ops writes never send.
  - **badges-01:** the badge approval is never composed, so the page is unreachable.
- **Settlement:** 15/15 in Release. The reads are ungated by `readsOpen` (6fa970c48).

### Native %

The native rule is "EVERYTHING native".
- **Pages:** **0 / 20 pages are native (0%)**. 19 are *partly* (they sit on a system `List`/`Form`, but carry CY* components, custom page background or card chrome). 1 is *custom* (badges: `ScrollView` + `VStack` + CY cards). Weighted (native 1, partly ½, custom 0) the area is **47.5%**.
- **Area-wide element counts** (App/Club\*.swift, App/ClubKit, App/MPGap/Club):

  | element | count |
  |---|---|
  | CY\* component calls | 515 |
  | CYEmptyState | 88 |
  | CYStatusChip | 66 |
  | CYPillButton / CYPillButtonStyle | 115 |
  | CYRowIcon | 44 |
  | CYListRow | 43 |
  | CYSkeleton | 30 |
  | CYHeroHeader | 24 |
  | CYConfirmSheet / CYConfirmConsequence | 29 |
  | `RoundedRectangle` / `cornerRadius` | 78 |
  | `ScrollView` | 21 |
  | `ContentUnavailableView` | **5** |

- **Forced dark:**
  - App/ClubStoryViews.swift:281 `.environment(\.colorScheme, .dark)` (story gameplay card).
  - The `.preferredColorScheme` calls at App/ClubOwnerFundsView.swift:379 and 384 are in `#Preview` only, so they don't apply at runtime.
- **Hex and gradients:**
  - App/DesignSystem/CYClubGameCodeCard.swift:22, 62 use CYNight ink, which is CYRGB 0x0E0E16 / 0x171726.
  - App/ClubComponents.swift:288 uses `LinearGradient` + `Color(red:)`.
  - App/ClubComponents.swift:367 and App/ClubStoryViews.swift:303 use gradient scrims.
- **Already clean:** App/ClubDetailQuickActions.swift (new scan section), App/ClubOpsEventInlineRoster.swift and App/ClubPersonalFundsStagesSection.swift. The last one still has a hand-built failure row at :19-25.

**Contract coverage (from r9, not re-run):** club 109 matched / 6 missing endpoint / 14 missing test.

## 2. Findings

### Status of the r9 queue rows

The r9 queue has **70** non-money rows. Its footer says 78, which is a miscount.

| outcome | count | rows |
|---|---|---|
| Fixed in code | **18** | gate-01, gate-02, gate-03, detail-11, G02, G04, G05, G10, r9-detail-02, event-ops-02, event-ops-06, governance-01, apply-04, r8-create-01, G19, settlement-05, settlement-06, r9-settlement-01 |
| Partly | 10 | gate-04, G13a, detail-09, r7-A-04, detail-30, r9-native-07, topic-detail-05, r8-governance-01, enroll-08, r8-badges-02 |
| Open | 41 | see §3 |
| Dropped | 1 | r9-native-04: `.font(.footnote)` + `.secondary` is already the Apple form under native-r2 |
| Money, not a gap | 1 | payout-receiver-01 |

### r9 P0s

**8 of 9 are closed:** gate-01/02/03 (097702ffb), detail-11, G02 and G04 (bb689268e), G05 (d29934d68), and G10 (cc5370866).

**G13a is partly fixed.** 默认结局收尾 landed in bb689268e (App/ClubTopicDirectorOpsSections.swift:83-183). 通用玩法现场运营 is still a dead end: every action pushes PlayDirectorView, which has no generic-ops form.

### New P0s

| id | page | finding |
|---|---|---|
| CLB-r10-gate-05 | notify, group-code, event-ops, topic-detail, customer-detail | `ClubMPFirstGovernance.governance` (Core/ClubGovernanceProduction.swift:31) holds only ban, unban, transferOwner, report, appeal, hostApply and dissolve. Every other non-money club write the MP sends has `permits == false` in Release. The confirm stays disabled with 暂不可用 (CF:361-364) or returns silently (CF:842). The affected writes are sendNotification, retryNotification, issueGroupCode, saveCustomer, createSeries, updateSeries, correctAttendance, saveTopicSettings, chapterRecruit and chapterFinish. |
| CLB-r10-badges-01 | badges | `clubBadgeManagementApproval` defaults to `{ _ in nil }` (App/AppCompositionRoot.swift:453) and nothing in App sets it, so `clubBadgeHost` is nil (App/AppSession.swift:5684-5692). `pages/club/badges` renders `unavailable` (MPRPS:313-314), and the 勋章 entry on detail is hidden (CDV:284). A test pins the nil default (Tests/AppUnitTests/ClubBadgeHostDefaultTests.swift:19). |

### Money, not a gap

- cancelOccurrence and endTopic are `.financial` in Core/ClubGovernanceCommands.swift:52, because a host cancellation refunds (owner decision #6).
- reportHours and submitEvidence are club compensation.
- payout-receiver bind uses an MP-only `wx.login` jsCode.
- The FE settle POST, withdraw and the check-in refund panel dispatch.

These stay TEST-only and are not counted.

### Counts in the r10 queue

**P0 3 · P1 24 · P2 103** (130 rows).

| | P0 | P1 | P2 |
|---|---|---|---|
| parity | 3 | 18 | 32 |
| native | 0 | 6 | 71 |

Compared with r9 (P0 9 · P1 30 · P2 39), parity P0 went from 9 to 3 and parity P1 from 30 to 18. The new native column adds 77 rows.

## 3. Fix queue

Sorted P0 → P1 → P2, parity first and then native. r9 ids are kept for carried rows, and new rows are `CLB-r10-*`. Rows marked *superseded* point at the native row that replaces them. MP paths are relative to `chengyinhub-xcx/pages/club/<page>/`. Owners are **Claude App** (UI, mount, wiring) and **Cursor Core** (contracts, services, approvals, routes, links). There are no owner-decision rows.

### 3a. Parity rows

| id | sev | status r10 | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|---|
| CLB-r10-gate-05 | P0 | new | notify/index.js send+retry; group-code/index.js:93-135; event-ops/index.js series/attendance; topic-detail/index.js settings/chapter; customer-detail/index.js save | Core/ClubGovernanceProduction.swift:31; App/MPFirstClubApprovals.swift:72-77 | Add sendNotification, retryNotification, issueGroupCode, saveCustomer, createSeries, updateSeries, correctAttendance, saveTopicSettings, chapterRecruit and chapterFinish to the MP-first live set, and add their paths and review-read paths to `governancePaths`. Keep cancelOccurrence, endTopic, reportHours and submitEvidence out (money). Add a test that each of the 10 has `canDispatch == true` in a Release China composition. | Cursor Core |
| CLB-r10-badges-01 | P0 | new | badges/index.js (page) | App/AppCompositionRoot.swift:453, 601-609; App/AppSession.swift:5684-5692; Tests/AppUnitTests/ClubBadgeHostDefaultTests.swift:19 | Inside `grantPlayerWrites` (China), set `clubBadgeManagementApproval = { MPFirstClubApprovals.badges($0) }` for reads, create and grant (non-money), and add the badge paths to the firewall. Flip the test to assert non-nil in Release China. | Cursor Core |
| CLB-G13a | P0 | partly (bb689268e: 默认结局收尾 done) | topic-detail wxml:204-236 | App/ClubTopicDirectorOpsSections.swift:5-80 (tap → `openingTool = true`); App/ClubTopicDirectorMount.swift:54 | Open each 通用玩法 action in its own `.sheet { NavigationStack { Form } }` with the per-action fields, 时间为北京时间 and the ledger rows in the footer, and toolbar 取消 / 确认并提交. Submit through the shared-run write, and disable the rows while `writeLocked`. | Claude App (+ Cursor Core if the shared-run submit is missing) |
| CLB-detail-09 | P1 | partly (unchanged) | detail wxml:454-473 | App/MPGap/Club/ClubGapRound4Views.swift:26-57; R8M:22, 45-75 | Project row: cover, `timeText · N 人报名` / 还没有场次, tap → topic-detail. States: redacted loading, failure + 重新加载, and empty 暂无分配给你的项目. Drop the 12-item cap and the extra header. | Claude App |
| CLB-r7-A-04 | P1 | partly (unchanged) | detail js:1110-1210 | App/MPGap/Club/ClubGapRound4Views.swift:45-50, 89-104 | 场次工具: one session → open it directly. Several → 选择场次 `.confirmationDialog`. None → inline notice. Filter the tools by permission. | Claude App |
| CLB-G06 | P1 | open | detail wxml:11, 390-391 | CDV:428-430, 439 | Gear and a 设置 row on 管理 for `isOwner ‖ canUseManageTab`. Pass the real `canGovern`, not `true`. | Claude App |
| CLB-detail-30 | P1 | partly (the new ticket share also uses `chein://`) | detail js:3509-3545 | App/ClubKit/ClubWorkbenchKit.swift:223, 232-252; App/ClubEditionsShareSection.swift:77-90 | Use an https universal link for the invite (header and members) **and** the 带票分享 ShareLink (absorbs CLB-r10-detail-03). | Cursor Core (URL) + Claude App |
| CLB-detail-14 | P1 | open | detail wxml:96-158 | App/ClubCommunityViews.swift:280-288; CDV:149-176 | Put the feed inline on 帖文 instead of a pushed link, and move the chat, IM and channel rows off it. Do this together with nat-detail-01. | Claude App |
| CLB-detail-35 | P1 | open | detail wxml:192, js:3141 | App/ClubActivityListContent.swift; App/ClubKit/ClubGroupCodeSessionStep.swift:59 | Add 出示团码 to manager activity rows (as a swipe action or context menu) and 出示二维码 on 管理. Needs gate-05 for the issue. | Claude App |
| CLB-detail-34 | P1 | open | — | App/ClubHomeView.swift:135 | Pass actionCoordinator, management and community, as at :187. | Claude App |
| CLB-G13b | P1 | open | topic-detail wxml:340-345, 436-442 | GV:2001 (`directorActive: false`) | Set `directorActive: true` when mounted. Add the 结束活动 primary, the 结束这场活动？ `.confirmationDialog` and the 更多 → 结束活动 row. The endTopic dispatch is money (TEST-only). | Claude App |
| CLB-G13c | P1 | open | topic-detail wxml:244-261 | App/MPGap/Club/ClubGapTopicDirectorViews.swift:45-57 | Show 准备总览 only while preparing, with 节点状态 / 队伍进度 rows. Show 联系商家 when `merchantHoldBlocked`. | Claude App |
| CLB-topic-detail-06 | P1 | open | topic-detail wxml:503-530; js:1245-1274 | GV:1888 | Inline `Toggle`s that save on change and roll back on failure. Needs gate-05 (saveTopicSettings). | Claude App |
| CLB-topic-detail-10 | P1 | open | topic-detail wxml:608-625 | GV:1897-1906 | Add the 定向广播 entry in the 报名参与者 sheet. When disabled, show `broadcastDisabledText` in the footer. | Claude App |
| CLB-topic-story-04 | P1 | open | topic-story wxml:41; js:77-78 | Core/ClubStoryPresentation.swift:18-26; App/ClubStoryViews.swift:209; App/MPGap/Club/ClubGapRound4Views.swift:141 | Expose lat/lng on `ClubStoryStop` and pass them into `ClubStoryStopLocation`. Today the row is always disabled. | Cursor Core + Claude App |
| CLB-G15 | P1 | open | event-ops wxml:~120, ~200 | App/ClubOpsEventView.swift:114 | Feed `paymentNotice` and `windowWarning`, set `showsEmptyPublishCTA`, and wire 发布主题 (today it is `{}`). | Claude App |
| CLB-apply-05 | P1 | open | apply/index.wxml:149-152, js:278-357 | CF:172-177, 241; App/MPGap/Club/ClubGapRound4Views.swift:156 (0 refs) | Mount the cert-images section (`PhotosPicker` in the Form), upload, and send `certImages`. | Claude App |
| CLB-notify-05 | P1 | open | notify/index.wxml:76-78 | CF:452-453, 589-594 | Inline `Button("刷新")` with a `ProgressView` (刷新中…) on the campaign Section instead of the pushed status page. Absorbs nat-notify-04. | Claude App |
| CLB-customer-detail-04 | P1 | open | customer-detail/index.wxml:83-118 | GV:780-785; App/ClubOpsCustomerViews.swift:491-560 | Inline Section editor instead of a sheet. Tags are rows with swipe-to-delete, add uses a `TextField` + `.onSubmit`, the remark is `TextField(axis: .vertical)`, with 保存/取消. Absorbs nat-customer-detail-02. Needs gate-05 (saveCustomer). | Claude App |
| CLB-group-code-06 | P1 | open | group-code/index.js:44-56, 93-135 | CF:888-891 | Build `.issueGroupCode` without `scope.clubID` (`ClubGroupCodeIssueBody.command(activityID:)`) and validate by activityID. Land it with gate-05. | Claude App |
| CLB-group-code-05 | P1 | open | group-code/index.wxml:15-22, js:219 | MPRPS:339; App/ClubKit/ClubGroupCodeSessionStep.swift:61 | When neither id is present: `ContentUnavailableView` 缺少路线或场次信息 + 进入俱乐部管理. Wire `onOpenManage`. | Claude App |
| CLB-r9-gate-04 | P2 | partly (097702ffb: roster and welcome on) | detail wxml:96-158 | App/AppCompositionRoot.swift:377-378, 1010-1011, 3256-3281; App/ClubPostOriginalComposition.swift:14 | `clubPostOriginalApproval` / `clubCommentOriginalApproval` are never set. MP create and comment already send via `api/club/post/*`, so either delete the dead `post/operation/*` branch or default it on. (= CLB-r10-detail-01) | Cursor Core |
| CLB-detail-42 | P2 | open (reverted in 202e62bb6) | — | Core/ClubDetailTabs.swift:80-120; Tests/CoreTests/ClubDetailPageReadyTests.swift:33-39 | Move the 待补充/待定 fallback into the live header path (CDV:623-626) and delete `ClubDetailOverviewFactsGrid` again. | Cursor Core |
| CLB-r9-detail-01 | P2 | open | detail wxml:266-277 | App/MPGap/Club/ClubGapManageExtensions.swift:160-191 | Avatar strip: name and role under each avatar, tap → profile, and a plain `Text("+N")`. | Claude App |
| CLB-r9-detail-03 | P2 | open | detail wxml:690-860 | App/MPGap/Club/ClubGapManageExtensions.swift:238, 261, 263, 267; R8M:40, 44 | Literals → xcstrings keys. | Claude App |
| CLB-r7-A-07 | P2 | open | detail js:2451-2454 | App/ClubMembersView.swift:219 | 临时封禁 for the owner **or** a co-owner with `club:member:manage`. | Claude App |
| CLB-r9-native-07 | P2 | partly (d29934d68) | — | App/MPGap/Club/ClubGapRound4Views.swift:86; App/MPGap/Club/ClubGapManageExtensions.swift:61, 271 | `Button("关闭")` / `Button("取消")` → the `common.close` / `common.cancel` keys. | Claude App |
| CLB-G13d | P2 | open | topic-detail wxml:160-178, 288-295 | App/MPGap/Club/ClubGapTopicDirectorViews.swift:28-41, 72-84; App/ClubTopicDirectorMount.swift:62-74 | MP copy for the unknown-write and failure states, an empty state, leaderboard rows + 暂无榜单记录, and capability-gated tool rows. Do this together with nat-topic-detail-08. | Claude App |
| CLB-topic-detail-05 | P2 | partly (unchanged) | topic-detail wxml:97-100, 426-470 | App/ClubTopicDetail+Port.swift:27-31; GV:1675 | Add the 台账 link in the 核销 header, and make the 更多 rows match the MP. | Claude App |
| CLB-r9-topic-detail-01 | P2 | open | topic-detail js:1015 | App/ClubTopicMerchantContent.swift:46 | 手机号已复制 feedback (`.sensoryFeedback` + inline text). | Claude App |
| CLB-r9-topic-detail-02 | P2 | open | topic-detail wxml:426 | GV:1630-1641, 1663 | There are two 更多 entries. Keep one toolbar `Menu`. | Claude App |
| CLB-topic-story-06 | P2 | open | topic-story wxml:56 | GV:2250 | Use `club.story.noRoute` (暂无路线) as the title. | Claude App |
| CLB-r9-topic-story-01 | P2 | open | topic-story js:164-165, 205 | MPRPS:352-372 | Missing topicId → `ContentUnavailableView` 缺少主题信息… + 返回. | Claude App |
| CLB-r9-event-ops-01 | P2 | open | event-ops topic dropdown | App/ClubOpsEventView.swift:142 | Inline topic `Picker(.menu)`, not a push. | Claude App |
| CLB-event-ops-05 | P2 | open | event-ops wxml:11, 17-18 | App/ClubOpsEventView.swift:57; MPRPS:328 | Retry label 重新加载. No clubId → missing-param state + 返回. | Claude App |
| CLB-r9-native-02 | P2 | open | — | App/MPGap/Club/ClubGapTopicDirectorViews.swift:46, 48 | Director literals 站点准备 / 进行中队伍 → catalog keys. | Claude App |
| CLB-r9-native-05 | P2 | open | — | App/MPGap/Club/ClubGapRound4Views.swift:124-127; OPS:324 | Fixed pin and 56×56 mark → `@ScaledMetric`. The story dot and thumbnail move to nat-topic-story-02. | Claude App |
| CLB-r8-governance-01 | P2 | partly (unchanged) | governance/index.js:204-207 | Core/MiniProgramPageLink.swift:78-79; App/MPParityKit.swift:258-261 | Make `clubId` optional and route it to MemberMissingLinkState. | Cursor Core + Claude App |
| CLB-r9-create-01 | P2 | open | create/index.wxml:12-15 | OPS:186 | Use `ProgressView("正在确认创建资格")`. | Claude App |
| CLB-r9-create-02 | P2 | open | create/index.js:114-118, 192-200 | OPS:380-382 | A non-host auto-opens apply (正在前往主理人申请). | Claude App |
| CLB-r9-create-03 | P2 | open | create/index.wxml:6-8 | OPS:233-242 | Show the `n / 4` step in the toolbar (`ToolbarItem(.principal)`). | Claude App |
| CLB-r9-create-04 | P2 | open | create/index.wxml:119-121 | OPS:1261; App/ClubKit/ClubCreateKit.swift:163-250 | 城市 is a `TextField` (prompt 如 上海, max 20, rule in the footer), not a picker. Absorbs nat-create-02. | Claude App |
| CLB-enroll-08 | P2 | partly (unchanged) | enroll/index.js:200-215 | MPRPS:321-324 | No clubId → use the first owned club. With none, show `ContentUnavailableView` 还没有可管理的俱乐部. | Claude App |
| CLB-r9-enroll-01 | P2 | open | enroll/index.wxml:18 | App/ClubEnrollmentView.swift:190-199 | Refresh line 正在更新报名名册… (a `ProgressView` row while re-reading). | Claude App |
| CLB-r9-edit-01 | P2 | open | edit/index.wxml (missing-param) | MPRPS:309-310 | Missing id → MemberMissingLinkState. | Claude App |
| CLB-r8-badges-02 | P2 | partly (unchanged) | badges/index.wxml:56; js:264, 282 | App/ClubBadgeManagementView.swift:290-292 | Title 勋章没有创建. Sub = the server msg, else 勋章没有创建成功. | Claude App |
| CLB-workbench-03 | P2 | open | workbench/index.wxml:9-15 | MPRPS:1122-1123 | Replace `try?` with `ContentUnavailableView` 没能进入俱乐部管理 + 重试进入. Absorbs nat-workbench-01. | Claude App |
| CLB-r9-payout-receiver-02 | P2 | open | payout-receiver/index.js:106 | PRV:126-130, 178-179 | While `weChatCode == nil`, replace the always-failing bind button with a pointer to the MP (TEST builds). | Claude App |
| CLB-r10-apply-01 | P2 | new | apply/index.js:159-162 | GV:1471-1473 | 切换到商家端 replaces the stack (MP `reLaunch`) instead of pushing the merchant home on top. | Claude App |
| CLB-r10-apply-02 | P2 | new | apply/index.js:99-110 | GV:1461, 1465 | No read carries `merchantActive` (0 hits in Core), so the app assumes `true` and the 查看商家入驻 branch is dead. Add the merchant status to the hostStatus read. | Cursor Core + Claude App |
| CLB-r10-roles-01 | P2 | new (verify) | roles/index.js re-read toast | GV (4df2d6204; formerly :345, 1196, 1238-1243) | Check that `finishRoleManagementReturn` still shows 列表没刷新成功，下拉重试 and keeps the list when the re-read fails. | Claude App |
| CLB-r10-join-requests-01 | P2 | new (verify) | join-requests approve/reject | App/AppSession.swift:6083 | Confirm that `ClubManagementSessionAccess` approve/reject dispatches in Release (not traced). | Cursor Core |
| CLB-r10-create-01 | P2 | new (housekeeping) | — | OPS:527-528 | Fix the stale comment ("already sends the wizard back"). | Claude App |
| CLB-payout-receiver-01 | — | money, not a gap | payout-receiver/index.js:106-112 | App/PayoutReceiverBridge.swift:13-17 | The bind needs an MP-only `wx.login` jsCode. TEST-only. | — |
| CLB-r10-money-01 | — | money, not a gap | event-ops cancel; topic-detail end; compensation | Core/ClubGovernanceCommands.swift:52 | cancelOccurrence, endTopic, reportHours and submitEvidence are `.financial`. They stay TEST-only until the owner turns money on. | — |

*Superseded by native rows (not counted twice):*
- r9-native-01 → nat-topic-detail-01
- r9-native-03 → nat-event-ops-01 and nat-settlement-01/03
- r9-native-06 → nat-badges-01
- topic-story-08 → nat-topic-story-02
- event-ops-09 → nat-event-ops-02

*Dropped:* r9-native-04.

### 3b. Native rows (EVERYTHING native)

**What to use instead:**

| custom | Apple component |
|---|---|
| `CYEmptyState` | `ContentUnavailableView` |
| `CYSkeleton` / `CYLoadingStateView` | `.redacted(reason: .placeholder)` or `ProgressView` |
| `CYPillButton` | `.borderedProminent` / `.bordered` / `.borderless` |
| `CYStatusChip` | `.secondary` Text, `Label` or `.badge` |
| `CYListRow` / `CYRowIcon` | `NavigationLink` + `Label` |
| `CYHeroHeader` | `.navigationTitle` |
| `CYConfirmSheet` | `.confirmationDialog` / `.alert` |
| `.cyDomainCard` / RoundedRectangle chrome | plain rows |
| `scrollContentBackground(.hidden)` + `cyDomainPageBackground` + `cyGroupedSurface` | system `.insetGrouped` |

**Rules:** keep the `accessibilityIdentifier`s and the MP images via `MPAsset`. One file per row where possible.

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| CLB-r10-nat-topic-story-01 | P1 | topic-story gameplay card | App/ClubStoryViews.swift:245-306 (forced `.colorScheme(.dark)` :281, `LinearGradient` :303, `.white` text, a 248 pt rounded card) | Make it a plain List row: thumbnail + title + `LabeledContent` meta, with system colours in Light and Dark. | Claude App |
| CLB-r10-nat-badges-01 | P1 | badges/index.wxml | App/ClubBadgeManagementView.swift:17-42 (`ScrollView{VStack}`, `.cyDomainScreen`) | Use `List` + `Section`s. Loading → `ProgressView`. Load error → `ContentUnavailableView` + 重新加载. | Claude App |
| CLB-r10-nat-badges-02 | P1 | badges create sheet | App/ClubBadgeManagementView.swift:344-420 (custom field box with its own background, RoundedRectangle and `n/limit` counter at :396-420; CYSheetContainer :345) | Use `NavigationStack { Form { TextField(axis: .vertical) } }` with toolbar 取消 / 创建 and the limit and validation in the footer. | Claude App |
| CLB-r10-nat-badges-03 | P1 | badges list | App/ClubBadgeManagementView.swift:73-170 (CYImageCard :133, CYCoverArt :139, clipShape :142, CYPillButton :97, 111, 165) | Each badge is a `Label` row with an image thumbnail. 颁发 is a row button or swipe action, 刷新 and 创建 go in the toolbar, and empty uses `ContentUnavailableView`. | Claude App |
| CLB-r10-nat-badges-04 | P1 | badges 颁给谁？ | App/ClubBadgeManagementView.swift:178-299 (CYSheetContainer :178, CYConfirmSheet :243, CYConfirmConsequence :250-252, CYPillButton :197, 285) | Member picker → a `NavigationStack { List }` sheet. Confirm → `.confirmationDialog` with a message. | Claude App |
| CLB-r10-nat-group-code-01 | P1 | group-code code sheet | App/DesignSystem/CYClubGameCodeCard.swift:19-63 (hex CYNight ink :22, 62; RoundedRectangle :22, 30, 62; stroke :63; CYPillButton :40) | Show the QR `Image` in a plain Section row, with the session name as the header, `ProgressView` while generating and a system retry `Button`. | Claude App |
| CLB-r10-nat-detail-01 | P2 | detail wxml:96-158 | App/ClubCommunityViews.swift:327-415 (ScrollView :328, CYHeroHeader :331, CYSkeleton :332, CYEmptyState :338-344, `.cyDomainCard` :362, 505) | Feed → `List(.insetGrouped)` with one section per post, `.refreshable`, `ContentUnavailableView` and redacted loading. | Claude App |
| CLB-r10-nat-detail-02 | P2 | detail wxml:666-686 | App/ClubCommunityViews.swift:902-950 (custom TextEditor box :906-911, hand-drawn placeholder :914-918, `n/300` counter :920, CYPillButton :939) | Composer: `Form` + `TextField(axis: .vertical)`, the limit in the footer, and toolbar `.confirmationAction` / `.cancellationAction`. | Claude App |
| CLB-r10-nat-detail-03 | P2 | — | App/ClubCommunityViews.swift:769-851, 1153-1234, 1255-1297 | Post detail, comments and history → `List`. Remove `.cyDomainCard` (810, 1181, 1217, 1290). Comment field (1222-1225) → `.safeAreaInset` with a system TextField. Pill refresh → `.refreshable`. | Claude App |
| CLB-r10-nat-detail-04 | P2 | — | App/ClubCommunityViews.swift:1030, 1080-1092 | Review sheet: CYCard and the offline plate → Form sections with a footer, and a toolbar confirm. | Claude App |
| CLB-r10-nat-detail-05 | P2 | detail tab bar | App/ClubDetailTabBar.swift:9-40 (hand-drawn segmented track) | `Picker(.segmented)`. Drop the AX `ScrollView` (:13). | Claude App |
| CLB-r10-nat-detail-06 | P2 | — | CDV:110-113, 406-408, 504-506, 653-655 | Drop the custom page surface, `CYDomainPalette` tint and the logo stroke overlay. Size the logo with `@ScaledMetric`. | Claude App |
| CLB-r10-nat-detail-07 | P2 | — | CDV:152, 156, 197, 216, 706-710 | CYListRow/CYRowIcon → `NavigationLink` + `Label`. CYEmptyState → `ContentUnavailableView`. CYStatusChip → secondary text. | Claude App |
| CLB-r10-nat-detail-08 | P2 | — | App/ClubActionPanel.swift:78-92, 137, 162-189 | System rows. Leave → `Button(role: .destructive)`. CYConfirmSheet → `.confirmationDialog`. Join help goes in the footer. | Claude App |
| CLB-r10-nat-detail-09 | P2 | detail wxml:163-216 | App/ClubActivityListContent.swift:60-95; App/ClubPublicActivityListView.swift:73-125, 156, 215-250 | Activity rows are plain List rows (no `bgRaised` plate :92-93). Remove CYHeroHeader :107 and the CYCoverArt banner :240-252, and replace the pills with system buttons. | Claude App |
| CLB-r10-nat-detail-10 | P2 | — | R8M:402-415, 449, 505-510 | Leaderboard: redacted rows and `ContentUnavailableView`. The CYOptionSheet choice becomes a `.confirmationDialog`. | Claude App |
| CLB-r10-nat-detail-11 | P2 | — | App/ClubMembersView.swift:58-59, 78, 117, 147-159, 268-269, 323-324 | Members sheet: `navigationTitle` + toolbar close. CYOptionSheet → `Menu`. CYEmptyState → `ContentUnavailableView`. Avatar sized with `@ScaledMetric`. | Claude App |
| CLB-r10-nat-detail-12 | P2 | — | App/MPGap/Club/ClubGapRound4Views.swift:43, 49, 62, 127, 181, 223-232, 272-281 | Pills → `.bordered`. CYEmptyState → `ContentUnavailableView`. Date-range TextFields → `DatePicker`. | Claude App |
| CLB-r10-nat-detail-13 | P2 | — | App/MPGap/Club/ClubGapManageExtensions.swift:53, 87-132, 181 | Coop pool: CYEmptyState, CYStatusChip and pills → system equivalents. The apply TextField goes in a Form. | Claude App |
| CLB-r10-nat-detail-14 | P2 | — | App/MPGap/Club/ClubGapRemainingViews.swift:139-160, 208; App/ClubEditionsShareSection.swift:66 | Follow pill → `.bordered` `.buttonBorderShape(.capsule)` `.controlSize(.small)`. CYEmptyState → `ContentUnavailableView`. | Claude App |
| CLB-r10-nat-topic-detail-01 | P2 | topic-detail 核销 tiles | App/ClubTopicDetail+Port.swift:10-26 | Three `LabeledContent` rows (`.monospacedDigit()`). No tile chrome and no `minimumScaleFactor`. | Claude App |
| CLB-r10-nat-topic-detail-02 | P2 | topic-detail round actions | App/ClubTopicDetailRows.swift:93-131; GV:1647-1664 | Replace the circle buttons with a `ControlGroup` or Section Buttons with `Label`. | Claude App |
| CLB-r10-nat-topic-detail-03 | P2 | topic-detail footer | GV:1942-1956, 2019-2051 | Bottom bar → `ToolbarItem(placement: .bottomBar)` with `.borderedProminent`. Drop the Divider overlay and the CYPillButtonStyle. | Claude App |
| CLB-r10-nat-topic-detail-04 | P2 | — | GV:765-771, 1681 | `.insetGrouped` with the system background. `.presentationDetents` instead of `cyDomainSheet`. | Claude App |
| CLB-r10-nat-topic-detail-05 | P2 | — | GV:1588, 1615-1616, 1731; App/ClubTopicDetailRows.swift:71, 177 | CYStatusChip → secondary `Text`/`Label` or `.badge`. | Claude App |
| CLB-r10-nat-topic-detail-06 | P2 | — | GV:1577-1578; App/ClubTopicDetailRows.swift:36-37, 164-165 | No custom clips or circle avatars. Use system row images or `person.crop.circle`. | Claude App |
| CLB-r10-nat-topic-detail-07 | P2 | — | App/ClubTopicDirectorOpsSections.swift:36-41, 129 | `NavigationLink` rows (system chevron). The length rule goes in the footer (drop the `n/500` counter). | Claude App |
| CLB-r10-nat-topic-detail-08 | P2 | — | App/MPGap/Club/ClubGapTopicDirectorViews.swift:28-41; App/ClubTopicDirectorMount.swift:62-74 | Loading → `ProgressView`. Failure → `ContentUnavailableView` + 重新加载. Plain buttons. | Claude App |
| CLB-r10-nat-topic-story-02 | P2 | topic-story stops | App/ClubStoryViews.swift:158-243 (card bg :223, circle dot :180-182, 117×80 thumbnail :237) | Plain List rows with an `"\(n).circle"` symbol and a system-size thumbnail. | Claude App |
| CLB-r10-nat-topic-story-03 | P2 | topic-story chapters | GV:2353-2381 | Chapter chips → `Picker(.menu)` at all sizes. | Claude App |
| CLB-r10-nat-topic-story-04 | P2 | — | GV:2240-2247, 2274-2276 | AIGC capsule → plain `Label`. `.insetGrouped` with the system background. | Claude App |
| CLB-r10-nat-topic-story-05 | P2 | — | App/ClubStoryViews.swift:76, 317-327; GV:2222-2228, 2523-2527; App/ClubStoryHostAnswer.swift:66 | CYEmptyState, CYStatusChip, CYPill/Destructive styles and CYSkeleton → system equivalents. | Claude App |
| CLB-r10-nat-event-ops-01 | P2 | event-ops states | App/ClubOpsEventView.swift:41-61, 76-88 | Loading → `ProgressView`. Failure and denied → `ContentUnavailableView` (with 重新加载). | Claude App |
| CLB-r10-nat-event-ops-02 | P2 | event-ops hub | App/ClubOpsEventView.swift:107-148, 214 | CYListRow/CYRowIcon → `NavigationLink { } label: { Label }`. | Claude App |
| CLB-r10-nat-event-ops-03 | P2 | — | App/ClubOpsEventView.swift:66, 74, 111, 139, 149, 420-442 | System background. Plain `Section` header and footer (drop ClubOpsTableHeading/Note). | Claude App |
| CLB-r10-nat-event-ops-04 | P2 | event-ops form | App/ClubOpsEventFormFields.swift:13-36, 72-87 | Split into `Section { TextField } header: footer:` with the notes and validation in the footer. Drop the duplicate label. | Claude App |
| CLB-r10-nat-event-ops-05 | P2 | — | App/ClubOpsEventView.swift:222-224, 284-288, 359 | CYStatusChip → text or `.badge`. CYPillButton → `.bordered`. | Claude App |
| CLB-r10-nat-shared-01 | P2 | — | GV:766-767, 773; CF:484-485; OPS:221-222; App/ClubEnrollmentView.swift:161-162; App/ClubOperationsReviewView.swift:59-69 | Drop `scrollContentBackground(.hidden)`, `cyDomainPageBackground`, `cyGroupedSurface` and `cyDomainScreen`, and let List/Form draw the system background. Split by file. | Claude App |
| CLB-r10-nat-shared-02 | P2 | — | GV:2518-2545 (ClubGovActionChrome) | CYPill/Destructive styles → `.borderedProminent` / `.bordered` / `role: .destructive`. | Claude App |
| CLB-r10-nat-shared-03 | P2 | — | CF:526-531; App/ClubKit/ClubMemberActionKit.swift:78-130; App/ClubKit/ClubGovernanceConsequence.swift:41-75 | Discard and consequence sheets → `.confirmationDialog` / `.alert` with the consequence lines as the message. | Claude App |
| CLB-r10-nat-governance-01 | P2 | governance no-permission | App/ClubOpsGovernanceSections.swift:364-381 | `ContentUnavailableView(…, systemImage: "lock")` + 返回. | Claude App |
| CLB-r10-nat-governance-02 | P2 | — | GV:629, 679-691 | Loading → `.redacted` / `ProgressView`. Failure → `ContentUnavailableView` + 重试. | Claude App |
| CLB-r10-nat-governance-03 | P2 | — | App/ClubOpsMemberActionCard.swift:41, 51, 54-56; App/ClubOpsGovernanceSections.swift:77-91, 129-130, 206-239 | CYColor tokens → `.secondary` / `.tertiary` / `.red`. | Claude App |
| CLB-r10-nat-roles-01 | P2 | roles/index.wxml:84-91 | App/ClubRoleAssignmentPicker.swift:129-178 | DisclosureGroup lists → `Picker(.navigationLink)` for the member and the role. | Claude App |
| CLB-r10-nat-roles-02 | P2 | — | App/ClubOpsGovernanceSections.swift:46-55, 306, 315 | `ClubOpsTag` capsule → secondary `Text` / `LabeledContent`. | Claude App |
| CLB-r10-nat-apply-01 | P2 | apply/index.wxml:28-33 | GV:649, 1466-1481 | Signed-out and merchant states → `ContentUnavailableView` + system buttons. | Claude App |
| CLB-r10-nat-apply-02 | P2 | apply intro | GV:1485, 1499-1506 | 已生效 → `LabeledContent`. Title → a normal row (drop `CYTypography.pageTitle` and the clear rows). | Claude App |
| CLB-r10-nat-apply-03 | P2 | apply steps | CF:299-319, 315, 376, 712, 740-754 | System-labelled `TextField` rows with required-ness in the footer. Error in the footer. 上一步 / 下一步 → system buttons. | Claude App |
| CLB-r10-nat-create-01 | P2 | create type/direction | App/ClubKit/ClubCreateKit.swift:7-127; OPS:1195-1241 | Option cards → `Picker(.inline)`. Chips → multi-select checkmark rows. Field error in the footer. | Claude App |
| CLB-r10-nat-create-03 | P2 | create bottom bar | OPS:1150-1160, 1276-1283, 1630-1660 | Drop CYFooterBar. Toolbar `.confirmationAction` 下一步/创建 + back. | Claude App |
| CLB-r10-nat-create-04 | P2 | create states | OPS:186, 190, 360-378, 518-541, 620 | Bootstrap, signed-out, limit and failed → `ContentUnavailableView`. Submitting → `ProgressView`. | Claude App |
| CLB-r10-nat-create-05 | P2 | — | OPS:1444-1466 | Shared field helper (create and edit): `TextField(label, text:, prompt:)`, required note in the footer. | Claude App |
| CLB-r10-nat-create-06 | P2 | — | App/ClubOperationsReviewView.swift:13, 45 | Review sheet: `.navigationTitle` + toolbar confirm. | Claude App |
| CLB-r10-nat-enroll-01 | P2 | enroll/index.wxml | App/ClubEnrollmentView.swift:92, 106, 117, 125, 142, 320 | CYSkeleton, CYNoteBanner, CYPillButton and CYEmptyState → system equivalents (the notes go in the footer). | Claude App |
| CLB-r10-nat-enroll-02 | P2 | enroll/index.wxml:37 | App/ClubEnrollmentView.swift:274-285, 310, 343, 452-458, 470, 510 | Drop `.cyPressTracking`, the min-heights, the custom insets, CYStatusChip and the cover radius. 20 × `palette.*` → semantic colours. | Claude App |
| CLB-r10-nat-edit-01 | P2 | edit header | OPS:318-353 | `clubIdentityHero` and `QuestifyImageEntityCard(progressiveBlur:)` → a plain Section row (`Label` / `LabeledContent` + a system-size image). | Claude App |
| CLB-r10-nat-edit-02 | P2 | scene-club-edit/index.wxml:161-170, 206 | OPS:199, 230, 332, 451-461, 476-490, 509 | Save → toolbar `.confirmationAction`. Save failure → `.alert`. 解散 → `Button(role: .destructive)`. No permission → `ContentUnavailableView`. | Claude App |
| CLB-r10-nat-notify-01 | P2 | notify/index.wxml | CF:357-360, 427 | Send → `.borderedProminent` in its Section (drop `.questifyPrimary` and the clear row). | Claude App |
| CLB-r10-nat-notify-02 | P2 | notify audience | App/ClubNotificationAudienceView.swift:140, 190, 200 | `ProgressView`, `.bordered` and `Label` instead of the CY* components. | Claude App |
| CLB-r10-nat-notify-03 | P2 | notify denied/error | App/ClubOpsJoinNotifyViews.swift:32-112 | `ContentUnavailableView`, and drop `.e1ActionRow` and CYPillButton. | Claude App |
| CLB-r10-nat-settlement-01 | P2 | settlement/index.wxml:20-21 | PRV:209-216, 228, 233, 275-292 | `ProgressView` and `ContentUnavailableView` + 重新加载. Drop the custom background. | Claude App |
| CLB-r10-nat-settlement-02 | P2 | settlement settled card | PRV:311-327, 341-355 | `LabeledContent` (amount `.monospacedDigit()`). CYStatusChip → text. | Claude App |
| CLB-r10-nat-settlement-03 | P2 | settlement funds/FE | App/ClubFEReferenceSettlementHost.swift:87-96; App/ClubPersonalFundsStagesSection.swift:17-25 | `ProgressView`, and `ContentUnavailableView` or a 重试 row. | Claude App |
| CLB-r10-nat-settlement-04 | P2 | cy/fe-reference-settlement | App/MPGap/Club/ClubGapRound4Views.swift:222-232; App/MPGap/Club/ClubGapReferenceSettlementView.swift:33, 42, 59, 65 | System buttons, `ContentUnavailableView`, and `DatePicker` ranges. | Claude App |
| CLB-r10-nat-settlement-05 | P2 | settlement club funds | App/ClubOwnerFundsView.swift:223-342 | Delete CYBalanceHeroLocal, CYMoneyRowLocal and CYSkeletonLocal, and use `LabeledContent` and `ProgressView`. UI only; money writes stay gated. | Claude App |
| CLB-r10-nat-settlement-06 | P2 | settlement summary | App/ClubOpsSettlementViews.swift:15-45; App/ClubSettlementDetail.swift:250-252 | `.cyDomainCard` hero → `LabeledContent`. CYStatusChip → text. | Claude App |
| CLB-r10-nat-payout-receiver-01 | P2 | payout-receiver | PRV:46-78 | CYConfirmSheet × 2 → `.confirmationDialog` (unbind uses `role: .destructive`). TEST-only flow. | Claude App |
| CLB-r10-nat-payout-receiver-02 | P2 | payout-receiver | PRV:86-143 | `ContentUnavailableView`, `LabeledContent` and system button rows. | Claude App |
| CLB-r10-nat-customer-detail-01 | P2 | customer-detail head/metrics | App/ClubOpsCustomerViews.swift:242-331, 386-404 | Section head with system insets. Metric tiles → three `LabeledContent` rows. Empty → `ContentUnavailableView`. | Claude App |
| CLB-r10-nat-customers-01 | P2 | customers/index.wxml:15-23 | GV:699-726 | Capsule chip ScrollView → `Picker(.segmented)`. Hand-built search → `.searchable`. | Claude App |
| CLB-r10-nat-customers-02 | P2 | customers empty/row | App/ClubOpsCustomerViews.swift:3-55, 109-125, 189 | `ContentUnavailableView` (`.search` when filtered). Chip → secondary text. | Claude App |
| CLB-r10-nat-checkin-01 | P2 | checkin-detail | App/ClubCheckinRailView.swift:19-33, 148-157, 238 | `ContentUnavailableView`. No RoundedRectangle placeholder. Chip → `Label`. | Claude App |
| CLB-r10-nat-checkin-02 | P2 | checkin-detail refund | App/ClubOwnerRefundPanel.swift:59-115 | `NavigationStack { Form }` sheet, notes in the footer, system destructive button. UI only; refund stays money-gated. | Claude App |
| CLB-r10-nat-join-requests-01 | P2 | join-requests/index.wxml | App/ClubManagementView.swift:60-130, 196-197, 315-350 | Standard rows (drop the clear background, hidden separators, custom insets and `.cyPressable`). Small `.bordered` / `.borderedProminent` buttons. `ContentUnavailableView` and `ProgressView`. | Claude App |
| CLB-r10-nat-group-code-02 | P2 | group-code/index.wxml | CF:277, 292, 322-328, 398-404; App/ClubGroupCodePresentation.swift:50 | `ProgressView("生成中")` and system buttons (no clear row). | Claude App |
| CLB-r10-nat-group-code-03 | P2 | group-code 选择场次 | App/ClubKit/ClubGroupCodeSessionStep.swift:43-59; App/MPGap/Club/ClubGapRound4Views.swift:257-281 | `ProgressView`, `ContentUnavailableView`, and `NavigationLink` rows (drop the hand-drawn chevron). | Claude App |
| CLB-r10-nat-workbench-02 | P2 | detail manage tab | App/ClubKit/ClubWorkbenchKit.swift:36-90, 150-205 | RoundedRectangle now-card and tiles → a Section with `LabeledContent` / `NavigationLink` rows. | Claude App |

*Folded:*
- nat-create-02 → r9-create-04
- nat-customer-detail-02 → customer-detail-04
- nat-notify-04 → notify-05
- nat-workbench-01 → workbench-03
- nat-gov-shared-01 → nat-shared-01 + nat-governance-02

## 4. Go-live blockers (P0 only)

| id | page | blocker | owner |
|---|---|---|---|
| CLB-r10-gate-05 | notify, group-code, event-ops, topic-detail, customer-detail | 10 non-money ops writes the MP sends are not in `ClubMPFirstGovernance.governance` (Core/ClubGovernanceProduction.swift:31), so they never dispatch in Release. | Cursor Core |
| CLB-r10-badges-01 | badges (+ the detail 勋章 entry) | `clubBadgeManagementApproval` is never composed (App/AppCompositionRoot.swift:453), so the page is unreachable in every build. | Cursor Core |
| CLB-G13a | topic-detail | 通用玩法现场运营 actions have no form, and tapping one goes nowhere. | Claude App |

**Quickest path:**
1. gate-05 and badges-01 are two small Core wiring changes in the same file family as 097702ffb. Together they restore about 40 Release rows (release ≈83% → ≈90%).
2. G13a is one App sheet.
3. For native, the fastest gain is the badges page (4 P1 rows: the only `custom` page) and the two P1 single-card fixes (story gameplay card forced dark, group-code hex card). After that, `nat-shared-01`, split per file, removes the custom page background from about 12 pages at once.

## 5. Verdict

1. **Code parity is 90.8% (521/574), up 2.5 pts from r9, with no scored regressions.** 18 of the 70 r9 rows are fixed and 10 more are partly fixed, including 8 of the 9 r9 P0s and all three write gates.
2. **Release parity is about 83%.** r9's 85% missed two pre-existing Release blockers: the narrow MP-first governance set (gate-05) and the never-composed badge approval (badges-01). Both are Cursor Core wiring and are not owner decisions.
3. **Native: 0 of 20 club pages are Apple-native.** Every page except badges sits on a system List/Form, but the area still has 515 CY\* calls and only 5 `ContentUnavailableView`s. 77 native rows (6 P1, 71 P2) are queued, each sized for about one agent-hour.

## Appendices

The sub-audit work notes follow. They contain the full citation lists behind §1, and the evidence for each row is in §3.

---

# Appendix A

## out-A · club r10 · pages/club/detail + gate rows

App @ app checkout 82bcf2c2d (diffed against r9's ebf6c160c). Reviewer only; nothing edited.

## 1. r9 row status

| id | r9 sev | status | evidence |
|---|---|---|---|
| CLB-r9-gate-01 | P0 | **fixed** (097702ffb App/ReviewedPlayerWriteLeases.swift:1452) | `clubGovernanceApproval: playerWritesEnabled ? MPFirstClubApprovals.governance(context) : nil`. App/MPFirstClubApprovals.swift:9-16 issues `ClubGovernanceProductionApproval(mpFirstMarket:)` for ban, unban, transferOwner, report, appeal, hostApply and dissolve (Core/ClubGovernanceProduction.swift:31, 59-63, 73: live ops `permits` without per-command grants). Release sets `playerWritesEnabled: true` (App/RegionalLaunchConfiguration.swift:90 → AppCompositionRoot.swift:595-600 `notePlayerWrites`). Firewall admits the POSTs (App/MPFirstClubApprovals.swift:72-77; AppCompositionRoot.swift:3591). China only. |
| CLB-r9-gate-02 | P0 | **fixed** (097702ffb App/AppCompositionRoot.swift:607) | `clubRoleAssignmentApproval = { MPFirstClubApprovals.roleAssignment($0) }; clubRoleRevocationApproval = …roleRevocation` inside `if grantPlayerWrites` (:601). The 380-381 / 1013-1014 `{ _ in nil }` defaults are now overwritten in Release China. |
| CLB-r9-gate-03 | P0 | **fixed** (097702ffb App/AppSession.swift:6072; Core/ClubOperationsService.swift:223-229) | `ClubOperationsSessionAccess(…, approvalSource: { … MPFirstClubApprovals.operations(context) }, journal: composition.storage.operationJournal(), …)`, so `writeAvailability` is `.approved` when `playerWritesEnabled` + China + same account. The operation paths (create, update-mine, set-member-role, open-settings/*) are on the firewall list (MPFirstClubApprovals.swift:68-71). |
| CLB-r9-gate-04 | P1 | **partly** (097702ffb App/AppCompositionRoot.swift:608-609) | Fixed: `clubPublicRosterApproval` and `clubWelcomeNoteWrite/ReceiptApproval` now default on (+ journal dir). Still nil: `clubPostOriginalApproval` and `clubCommentOriginalApproval` (AppCompositionRoot.swift:377-378, 1010-1011; no setter anywhere in App). As a result, `resolvedClubPostOriginalService()` / `resolvedClubCommentOriginalService()` return nil (App/ClubPostOriginalComposition.swift:14), and the `api/club/post/operation/*` original path is fenced with `notConfigured` (AppCompositionRoot.swift:3262, 3275). The ordinary post and comment writes use `api/club/post/<create…>` through `clubCommunityWriteService` (AppCompositionRoot.swift:615-618, granted in Release China), so the MP create/comment does dispatch. Residual: decide whether the original-operation path is needed. If it is, default it on. If not, delete the dead branch (new row CLB-r10-detail-01). |
| CLB-detail-11 | P0 | **fixed** (bb689268e App/ClubEditionsShareSection.swift:6-113; App/ClubDetailView.swift:146-148; App/MPReviewedPageScreen.swift:838-847; App/GlobalSearchLinksAndTemplates.swift:535) | 自由探索期次 is a DisclosureGroup on 管理 for the owner. It reads `ClubGovernanceRead.editions` and keeps rows whose `executingClubId` is this club, with loading, failure+重新加载 and empty states. 带票分享 is a `ShareLink` with `sourceClubId` + `clubCode=club-<id>-t<topic>`. The topic link parses `ticketSource`, and registration now sends `sourceChannelCode: intent.sourceChannelCode`. Caveat: the share URL is `chein://mp/...` (ClubEditionsShareSection.swift:82), not https. That stays under detail-30. |
| CLB-G02 | P0 | **fixed** (bb689268e App/ClubDetailQuickActions.swift:5-99; App/ClubDetailView.swift:132-137; App/MPReviewedPageScreen.swift:289-292; App/ClubPostRefFollowSession.swift:59-74) | 扫码核销 Section on 管理 for `canGovern \|\| canManageActivities`. It opens `NativeQRScanner` → `ClubScanRoute.resolve` → `ClubScanClient.submit`, with wrong-entry, success and failure alerts. `scan=1` forces 管理 and auto-starts the scanner once (`autoScan`/`consumedAutoScan`). Hidden if `showsRoute` is off for the matched path. `ClubPublicActivityListView.swift:90 showsScanVerify: false` is unchanged but is no longer needed. |
| CLB-G04 | P0 | **fixed** (bb689268e App/ClubDetailR8Mounts.swift:133, 137-157, 222-224; App/ClubPostRefFollowSession.swift:42-56) | `canApply: ClubCoopPoolApplyClient.canApply(state:)`, and `onApply` calls `applyCoopPool` → `/api/coop/pool/apply` (gated on `showsRoute`), then re-reads the pool, with applied/failed/unknown notices. Owner only (CDV:143), same as r9 scoped. |
| CLB-G05 | P0 | **fixed** (d29934d68 App/ClubCommunityViews.swift:930-933; App/ClubPostRefFollowSession.swift:7-23) | `ClubGapPlayRecordPickerRow(selected: $postRef, load: loadPostRefs)` in the composer, for new posts only. `.create(…, ref: postRef)` at :941. Reads `/api/registration/my-joined`, which is on the reviewed read list (ReviewedPlayerWriteLeases.swift:509). |
| CLB-G10 | P0 | **fixed** (cc5370866 App/ClubCommunityViews.swift:612-618; App/ClubPostRefFollowSession.swift:25-39) | `ClubGapFollowAuthorButton` on post cards for `followableAuthor`. Sends `/api/user/follow/action`. Mounted in `ClubCommunityFeedView`, which is reachable via ClubCommunityEntry (CDV:203). |
| CLB-detail-09 | P1 | **partly** (no change since r9) | ClubGapRound4Views.swift and the R8Mounts projects code are untouched. Still missing: cover, the `timeText · N 人报名` / 还没有场次 meta, row tap → topic-detail, skeleton/failure/empty states, the 12 cap and the extra 管理中的项目 header. |
| CLB-r7-A-04 | P1 | **partly** (no change) | App/MPGap/Club/ClubGapRound4Views.swift:45-50, 89-104 still uses `sessions.first`. No 选择场次 sheet, no zero-session toast, no permission filter. |
| CLB-G06 | P1 | **open** | Gear is still `if club.isOwner, management?.operations != nil` (App/ClubDetailView.swift:428-430). The sheet still passes `canGovern: true` (:439). There is no 设置 quick action on 管理 (ClubDetailQuickActions has scan only). |
| CLB-detail-30 | P1 | **partly** (no change) | ClubKit/ClubWorkbenchKit.swift is unchanged and still `chein://`. The new editions share (ClubEditionsShareSection.swift:82) also uses `CheinDeepLink.scheme`. |
| CLB-detail-14 | P1 | **open** | The feed is still a pushed `NavigationLink` (App/ClubCommunityViews.swift:280-288). Chat, IM and channel rows are still on 帖文 (App/ClubDetailView.swift:149-176). |
| CLB-detail-35 | P1 | **open** | No group-code action in App/ClubActivityListContent.swift or ClubPublicActivityListView.swift (grep `groupCode` = 0). No 出示二维码 on 管理. |
| CLB-detail-34 | P1 | **open** | App/ClubHomeView.swift:135 is still `ClubDetailView(id:reader:onSignIn:publicRoster:)` with no actionCoordinator, management or community. |
| CLB-r9-detail-01 | P2 | **open** | ClubGapManageExtensions.swift has no changes since r9. The avatar strip (:160-191) is still one button, with no name or role and no per-member tap. |
| CLB-r9-detail-02 | P2 | **fixed** (15e0d6628 + d21fc10f1 App/ClubDetailR8Mounts.swift:428-436, 459-520) | A leaderboard row opens 公开资料. Owner and admins get a choice sheet (公开资料 / 客户档案). |
| CLB-r9-detail-03 | P2 | **open** | Still verbatim zh in ClubGapManageExtensions.swift:238, 261, 263, 267 (客户与项目, 危险操作, …, 俱乐部设置) and ClubDetailR8Mounts.swift:40, 44 (`"\(total) 人"`, `"暂时读不到"`). |
| CLB-r7-A-07 | P2 | **open** | App/ClubMembersView.swift:219 `canTempBan: directory.club.isOwner`. Co-owners with `club:member:manage` still lack it. |
| CLB-detail-42 | P2 | **open (reverted)** | Deleted in 097702ffb, re-added in 202e62bb6 at Core/ClubDetailTabs.swift:80-120 (`ClubDetailOverviewFactsGrid`), with tests at Tests/CoreTests/ClubDetailPageReadyTests.swift:33-39. There are still 0 references in App, so it is dead code again. |
| CLB-r9-native-07 | P2 | **partly** (d29934d68 App/MPGap/Club/ClubGapRemainingViews.swift:54-55) | Remaining uses `.cancellationAction` + `"common.close"`. Still literal: ClubGapRound4Views.swift:86 `Button("关闭")`, ClubGapManageExtensions.swift:61 `Button("取消")` and :271 `Button("关闭")`. These are already in `.cancellationAction`; only the key is wrong. |

Money: none of these rows are money. G04 pool apply, the scan verify and the editions share do not pay or refund.

## 2. Page score

| page | r9 | r10 code | Δ | notes |
|---|---|---|---|---|
| pages/club/detail/index | 120/137 (88%) | **126/137 (92%)** | +6 | Now present: A11 + E2 (G02 scan, `scan=1`), B4 (G05), B14 (G10), E15 (detail-11 editions fold + ticket share), E18 (G04 申请带队). Still absent (11): A15, B15, E4, F7 (detail-30), B5 (detail-14), C11, E3 (detail-35), E6 (G06), E11 (detail-09), E13 (A-04), N1 (A-07). |

Regressions: no scored-row regression. One code regression: CLB-detail-42's dead type came back (202e62bb6). Also, the new editions share link copies the `chein://` scheme, which widens detail-30 rather than closing it.

## 3. Native: pages/club/detail

| page | grade | List/Form? | CY* count | chrome count | citations |
|---|---|---|---|---|---|
| pages/club/detail/index | **partly** | Main page: yes, a `List` (ClubDetailView.swift:107). Posts feed, post detail, composer, comments and history: **no**, they use `ScrollView` + `VStack` (ClubCommunityViews.swift:328, 769, 902, 1153, 1255). | ~118 CY component/modifier usages across 13 files (largest: ClubCommunityViews 40, ClubGapRound4Views 9, ClubPublicActivityListView 14, ClubDetailView 17) | 23 custom chrome sites | listed below |

### Citations by group

**Custom card or chrome (RoundedRectangle, `.background` + corner radius, overlay stroke, cyDomainCard)**
- App/ClubDetailView.swift:653-655: logo `clipShape(RoundedRectangle)` + `.overlay(… .stroke(CYNight.glassEdgeTop))`.
- App/ClubDetailView.swift:110-113, App/ClubActionPanel.swift:78, 162, 177, 189: `listRowBackground(Color.clear)` with a free-floating header and panel instead of system rows.
- App/ClubDetailView.swift:406-408, 504-506: `.cyGroupedSurface()`, `.scrollContentBackground(.hidden)`, `.cyDomainPageBackground()`, `.tint(CYDomainPalette(...).brand)`. These are a custom page surface and tint.
- App/ClubDetailTabBar.swift:11-14, 26: a hand-drawn segmented control (RoundedRectangle track + selected plate, `HStack(spacing: 2)`). At AX sizes it becomes a `ScrollView(.horizontal)` (:13).
- App/ClubActivityListContent.swift:92-93: activity card `.background(CYColor.bgRaised)` + `clipShape(RoundedRectangle)`. The stats use hard spacing 20 and 8 (:84-85).
- App/ClubPublicActivityListView.swift:249-250: `ClubCloud14Banner` uses `overlay{CYCoverArt}` + `clipShape(RoundedRectangle)`.
- App/ClubCommunityViews.swift:362, 505, 721, 810, 1181, 1217, 1290: `.cyDomainCard(radius:padding:)` on the pinned notice, post card, comment, history and review cards.
- App/ClubCommunityViews.swift:1085: offline note `.background(CYColor.bgSurface, in: .rect(cornerRadius:))`. :1345: cover `clipShape(RoundedRectangle)`.
- App/ClubActionPanel.swift:180: `.buttonStyle(.cyDomainSecondary)` + `.clipShape(Capsule())` on the leave button.
- App/MPGap/Club/ClubGapManageExtensions.swift:181: avatar-strip +N `Capsule().fill(...)`.
- App/ClubMembersView.swift:323-324: 40×40 avatar plate `Circle().fill(palette.bgElevated)`.
- App/ClubHomeView.swift:410-414: `ClubNightGlass`, a RoundedRectangle plate (hub, not detail, but it shares the club tab).

**Gradient, glow or material decoration**
- App/ClubDetailView.swift:598, ClubCommunityViews.swift:1339, 1342, ClubPublicActivityListView.swift:249: generated `CYIMCoverArt` / `CYCoverArt` artwork used as placeholders.
- App/ClubDetailView.swift:409, 663: `.cyTracksHeroScroll`, `.cyHeroTitleRise`. These are custom hero motion.

**CY\* components**
- CYListRow + CYRowIcon: ClubDetailView.swift:152, 156 (`card: true`), 216.
- CYStatusChip: ClubDetailView.swift:706-710; ClubDetailR8Mounts.swift:449; ClubMembersView.swift:268-269; ClubActivityListContent.swift:67; ClubPublicActivityListView.swift:121, 223; ClubGapManageExtensions.swift:101.
- CYEmptyState instead of ContentUnavailableView: ClubDetailView.swift:197; ClubDetailR8Mounts.swift:412, 415; ClubCommunityViews.swift:338, 341, 344, 822, 1184, 1266; ClubPublicActivityListView.swift:73, 80, 125; ClubMembersView.swift:78; ClubGapRound4Views.swift:62, 272, 274, 281; ClubGapManageExtensions.swift:87, 89, 92; ClubGapRemainingViews.swift:208.
- CYSkeleton instead of `.redacted(reason: .placeholder)`: ClubDetailR8Mounts.swift:410; ClubCommunityViews.swift:332, 813, 1156, 1258; ClubPublicActivityListView.swift:215.
- CYPillButton / CYPillButtonStyle: ClubCommunityViews.swift:387, 391, 844, 939, 1090, 1227, 1229, 1292; ClubPublicActivityListView.swift:156, 233, 235; ClubEditionsShareSection.swift:66; ClubGapRound4Views.swift:43, 49, 181, 228, 232; ClubGapManageExtensions.swift:126, 132; ClubGapRemainingViews.swift:139, 143, 160 (follow pill).
- CYHeroHeader instead of `navigationTitle`: ClubCommunityViews.swift:331, 771, 904-905, 1155, 1257; ClubPublicActivityListView.swift:107.
- CYSectionHeader: ClubCommunityViews.swift:812. CYCard: ClubCommunityViews.swift:1030. CYConfirmSheet: ClubActionPanel.swift:137.
- CYOptionSheet / CYSheetHeader instead of `confirmationDialog` / `Menu`: ClubDetailR8Mounts.swift:505-510; ClubMembersView.swift:58-59, 147.
- `.cyDomainSheet` / `.cySheet`: ClubDetailR8Mounts.swift:402; ClubMembersView.swift:117, 159.

**Custom input box (outside a Form)**
- App/ClubCommunityViews.swift:906-911: `TextEditor` with `.scrollContentBackground(.hidden)` + `.background(palette.bgRaised, in: RoundedRectangle)`. :913-916: :914-918 hand-drawn placeholder 有什么新鲜好玩的分享吗？ (verbatim `locale.pick`). :920: hand-drawn counter `"\(content.count)/300"`.
- App/ClubCommunityViews.swift:1222-1225: comment `TextField` with `.background(CYColor.bgRaised, in: RoundedRectangle)` in a ScrollView.
- App/ClubActionPanel.swift:84: join-message TextField inside a List section. Acceptable, but the help/validation text sits in rows (:89-92) instead of the section footer.

**ScrollView + VStack where a List is expected**
- App/ClubCommunityViews.swift:328 (feed), 769 (post detail), 902 (composer), 1153 (comments), 1255 (history).

**Fixed sizes**
- ClubDetailView.swift:653 logo 56×56 (not `@ScaledMetric`); ClubGapRound4Views.swift:127 16×16 pin; ClubMembersView.swift:323 40×40.

**Hand-built empty or failure states**
- Covered by the CYEmptyState list above. Only ClubEditionsShareSection.swift:29 and ClubGapRemainingViews.swift:69, 78 use `ContentUnavailableView`.

Clean (0 non-Apple elements): App/ClubDetailQuickActions.swift (Section + Label + `.sheet` + `.alert`).
Not found: `.preferredColorScheme`, CYRGB, `Color(red:)`, hex, `.system(size:)` in the detail files.

## 4. New rows

| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| CLB-r10-nat-detail-01 | P2 | detail wxml:96-158 | App/ClubCommunityViews.swift:327-415 | Feed: replace `ScrollView`+`VStack`+`.cyDomainCard` (362, 505) with `List(.insetGrouped)` sections, one per post. Use `.refreshable`, `ContentUnavailableView` for empty (338-344) and `.redacted(reason: .placeholder)` for loading (332). Drop `CYHeroHeader` (331) for `navigationTitle`. Pairs with detail-14. | Claude App |
| CLB-r10-nat-detail-02 | P2 | detail wxml:666-686 (compose) | App/ClubCommunityViews.swift:902-950 | Composer: put a `Form` with `TextField(axis: .vertical)` / `TextEditor` in a Section. Drop the custom background (911), placeholder (914-918) and the `n/300` counter (920; put limit text in the section footer). Replace `CYPillButton("club.community.review")` (939) with a toolbar `.confirmationAction`, and use `.cancellationAction`. | Claude App |
| CLB-r10-nat-detail-03 | P2 | — | App/ClubCommunityViews.swift:769-851, 1153-1234, 1255-1297 | Post detail, comments and history: switch to `List` sections. Replace `.cyDomainCard` (810, 1181, 1217, 1290). Put the comment `TextField` (1222-1225) in `.safeAreaInset(edge: .bottom)` with the system rounded-border style or in a Form. Replace the CYPillButton refresh (844, 1229, 1292) with `.refreshable`. Use `ContentUnavailableView` (822, 1184, 1266). | Claude App |
| CLB-r10-nat-detail-04 | P2 | — | App/ClubCommunityViews.swift:1030, 1080-1092 | Review sheet: `CYCard` and the offline plate → Form sections with a footer. Replace `CYPillButton("club.community.confirm")` with a toolbar `.confirmationAction`. | Claude App |
| CLB-r10-nat-detail-05 | P2 | detail wxml tab bar | App/ClubDetailTabBar.swift:9-40 | Replace the hand-drawn segmented control with `Picker(selection:) { … }.pickerStyle(.segmented)`. Keep the per-tab identifiers via `.accessibilityIdentifier` on each `Text` tag, or test by label. Drop the AX `ScrollView` (:13). | Claude App |
| CLB-r10-nat-detail-06 | P2 | — | App/ClubDetailView.swift:110-113, 406-408, 504-506, 653-655 | Drop `.cyGroupedSurface` / `.scrollContentBackground(.hidden)` / `.cyDomainPageBackground()` / `CYDomainPalette` tint, and use the system `.insetGrouped` background and accent. Logo: no stroke overlay; size with `@ScaledMetric`. | Claude App |
| CLB-r10-nat-detail-07 | P2 | — | App/ClubDetailView.swift:152, 156, 197, 216, 706-710 | `CYListRow(card:)`+`CYRowIcon` → `NavigationLink { } label: { Label(_, systemImage:) }`. `CYEmptyState` → `ContentUnavailableView`. `CYStatusChip` role tags → a `Text` in the header with `.foregroundStyle(.secondary)`, or `.badge`. | Claude App |
| CLB-r10-nat-detail-08 | P2 | — | App/ClubActionPanel.swift:78-92, 137, 162-189 | Action panel: system rows (no `listRowBackground(.clear)`). Leave → `Button(role: .destructive)` without the Capsule clip (180). `CYConfirmSheet` → `.confirmationDialog`. Put the join-message help/validation in the section footer. | Claude App |
| CLB-r10-nat-detail-09 | P2 | detail wxml:163-216 | App/ClubActivityListContent.swift:60-95; App/ClubPublicActivityListView.swift:73-125, 156, 215-250 | Activity cards: drop the `bgRaised`+RoundedRectangle plate (92-93), so each is a plain List row with an `MPAsset`/AsyncImage thumbnail. Replace `CYHeroHeader` (107), `ClubCloud14Banner` (240-252), CYSkeleton (215) → redacted, CYEmptyState → `ContentUnavailableView`, and CYPillButton (156, 233-235) → `Button` with `.borderedProminent`/`.bordered`. | Claude App |
| CLB-r10-nat-detail-10 | P2 | — | App/ClubDetailR8Mounts.swift:402-415, 449, 505-510 | Leaderboard: CYSkeleton → redacted rows. CYEmptyState → `ContentUnavailableView`. `CYOptionSheet` choice → `.confirmationDialog` with 公开资料 / 客户档案. 我 chip → `.badge` or a secondary Text. | Claude App |
| CLB-r10-nat-detail-11 | P2 | — | App/ClubMembersView.swift:58-59, 78, 117, 147-159, 268-269, 323-324 | Members sheet: `CYSheetHeader` → `navigationTitle` + toolbar close. `CYOptionSheet` → `Menu` / `.confirmationDialog`. `CYEmptyState` → `ContentUnavailableView`. Role chips → secondary text. Avatar plate → system `Circle().fill(.fill.tertiary)` sized by `@ScaledMetric`. | Claude App |
| CLB-r10-nat-detail-12 | P2 | — | App/MPGap/Club/ClubGapRound4Views.swift:43, 49, 62, 86, 127, 181, 223-232, 272-281 | Projects and group-code views: CYPillButtonStyle → `.bordered`/`.borderedProminent` (`.controlSize(.small)`). CYEmptyState → `ContentUnavailableView`. Date-range TextFields (223-224) → `DatePicker` in a Form. 16 pt pin → `@ScaledMetric`. `Button("关闭")` → `"common.close"`. | Claude App |
| CLB-r10-nat-detail-13 | P2 | — | App/MPGap/Club/ClubGapManageExtensions.swift:53, 61, 87-132, 181, 238-271 | Coop pool + settings: CYEmptyState (87-92) → `ContentUnavailableView`. CYStatusChip (101) → secondary text. CYPillButtonStyle (126, 132) → `.bordered`. +N capsule (181) → plain `Text("+N")`. Apply TextField (53) inside a Form. Literal 取消/关闭 (61, 271) → catalog keys. Pairs with r9-detail-03. | Claude App |
| CLB-r10-nat-detail-14 | P2 | — | App/MPGap/Club/ClubGapRemainingViews.swift:139-160, 208; App/ClubEditionsShareSection.swift:66 | Follow pill and play-record picker: CYPillButtonStyle → `.bordered`/`.borderedProminent` `.buttonBorderShape(.capsule)` `.controlSize(.small)`. CYEmptyState (208) → `ContentUnavailableView`. Editions ShareLink → default ShareLink style (`.bordered`). | Claude App |
| CLB-r10-detail-01 | P2 | — | App/AppCompositionRoot.swift:377-378, 1010-1011, 3256-3281; App/ClubPostOriginalComposition.swift:14 | gate-04 residue: `clubPostOriginalApproval` / `clubCommentOriginalApproval` are never set, so `api/club/post/operation/*` is unreachable. The MP create/comment go via `api/club/post/*` and do work. Either delete the dead original path or default it on like gate-01..03. | Cursor Core |
| CLB-r10-detail-02 | P2 | — | Core/ClubDetailTabs.swift:80-120; Tests/CoreTests/ClubDetailPageReadyTests.swift:33-39 | detail-42 regressed: 202e62bb6 restored `ClubDetailOverviewFactsGrid` (0 App refs) for a page-ready test. Move the 待补充/待定 fallback into the header's live code path (ClubDetailView.swift:623-626 `known()`) and delete the type again. | Cursor Core |
| CLB-r10-detail-03 | P2 | detail js:3509-3545 | App/ClubEditionsShareSection.swift:77-90 | The new 带票分享 builds `chein://mp/...`. Fold it into the detail-30 universal-link change so the ticket share opens for recipients who do not have the app. | Cursor Core (URL) + Claude App |

---

# Appendix B

## out-B: topic-detail / topic-story / event-ops (r10)

App = app checkout @ 82bcf2c2d. GV = App/ClubGovernanceViews.swift. Only these slice files changed since ebf6c160c: GV (+40/-31, none in the topic/story ranges except shifted line numbers), ClubOpsEventFormFields, ClubOpsEventView, new ClubOpsEventInlineRoster, ClubTopicDirectorMount (+2), new ClubTopicDirectorOpsSections, ClubTopicMerchantContent (1 line), ClubSeriesScheduleEditor (+6), ClubGovernanceCommandForm (+4). These are unchanged: ClubStoryViews, ClubStoryPresentation (Core), ClubGapTopicDirectorViews, ClubGapTopicDirector (Core), ClubTopicDetail+Port, ClubTopicDetailRows, ClubGapRound4Views, ClubGapRemainingViews (event-ops extras).

**Release-dispatch finding (affects every write in this slice).** `ClubMPFirstGovernance.governance` is `[.ban, .unban, .transferOwner, .report, .appeal, .hostApply, .dissolve]` (Core/ClubGovernanceProduction.swift:31). It is the only club governance approval built in Release (App/ReviewedPlayerWriteLeases.swift:1452 → App/MPFirstClubApprovals.swift:15; App/AppSession.swift:5983). The approval has `grants = []`, so `permits` returns false for any operation outside that set (ClubGovernanceProduction.swift:73-74). As a result, none of these writes dispatch in Release:
- event-ops: `createSeries`, `updateSeries`, `cancelOccurrence`, `correctAttendance`
- topic: `saveTopicSettings`, `endTopic`, `chapterRecruit`, `chapterFinish`, `sendNotification`, `issueGroupCode`

The forms render, but submitting them fails as `.notConfigured`. The director writes use a separate path and do dispatch: plan fallback goes through App/AppSession+PopupsClose.swift:126-142, and the director commands go through PlayDirectorCoordinator.

## 1. r9 row status

| id | r9 sev | status | evidence |
|---|---|---|---|
| CLB-G13a | P0 | **partly** | bb689268e. **默认结局收尾 is fixed:** App/ClubTopicDirectorOpsSections.swift:83-183 (reason sheet in a Form, 1–500 validation, alert confirm, PLAN_FALLBACK submit, result rows), mounted at App/ClubTopicDirectorMount.swift:55. It dispatches through AppSession+PopupsClose.swift:132-142. **通用玩法现场运营 is only a listing:** ClubTopicDirectorOpsSections.swift:5-80 (status line, teams line, ordered action rows), mounted at ClubTopicDirectorMount.swift:54. Every action calls `{ _ in openingTool = true }`, which pushes PlayDirectorView. No App or Core file other than this one handles ACT_UNLOCK/STAFF_MANUAL_SIGN, so the per-action half-sheet form (MP wxml:212-236: fields, 时间为北京时间, ledger rows, 确认并提交) is missing. The tap is a dead end. The rows are also not disabled under `writeLocked`. |
| CLB-G13b | P1 | **open** | GV:2001 still passes `directorActive: false`. There is no 结束活动 primary, no 结束这场活动？ confirm, and no 更多 → 结束活动 row (GV:1675). |
| CLB-G13c | P1 | **open** | ClubGapTopicDirectorViews.swift:45-57 is unchanged: ungated 站点准备 / 进行中队伍 counts, no station or team rows, no 联系商家. |
| CLB-G13d | P2 | **open** | ClubGapTopicDirectorViews.swift:28-41 and :72-84, plus ClubTopicDirectorMount.swift:62-74, are unchanged: 导演台加载失败 + action.retry, no empty state, no leaderboard rows, ungated tool rows. |
| CLB-topic-detail-06 | P1 | **open** | GV:1888 still calls `edit(.saveTopicSettings, seed:…)`. The write also does not dispatch in Release (see the finding above). |
| CLB-topic-detail-10 | P1 | **open** | GV:1897-1906 (topicCustomers) has no 定向广播 entry and no `broadcastDisabledText`. |
| CLB-topic-detail-05 | P2 | **partly** (unchanged) | ClubTopicDetail+Port.swift:27-31: the header has no 台账 link. The 更多 sheet at GV:1675 still holds only stats, settings and enrollment links. |
| CLB-r9-topic-detail-01 | P2 | **open** | 9e825a287 only changed the copy to `LocalPasteboard.copy(phone)` (ClubTopicMerchantContent.swift:46). There is still no 手机号已复制 toast. |
| CLB-r9-topic-detail-02 | P2 | **open** | There are still two 更多 entries: the toolbar `ClubGapTopicMoreMenu` (GV:1630-1641) and the round action `more` (GV:1663). |
| CLB-topic-story-04 | P1 | **open** | Core/ClubStoryPresentation.swift and App/ClubStoryViews.swift are unchanged since r9. There are still no coordinates, so `.disabled(!stop.hasCoordinates)` stays on (ClubGapRound4Views.swift:141). |
| CLB-topic-story-06 | P2 | **open** | GV:2250 still uses `ClubStoryEmptyState(title: "club.story.noChapters", detail: "club.story.noRoute")`. |
| CLB-topic-story-08 | P2 | **open** | ClubStoryViews.swift:176-184 is unchanged and has no connector line. |
| CLB-r9-topic-story-01 | P2 | **open** | App/MPReviewedPageScreen.swift:352-372: no topicId falls to the generic `unavailable` (:372). |
| CLB-G15 | P1 | **open** | ClubOpsEventView.swift:114 still calls `ClubGapEventOpsExtrasSection(onTapPublishTopic: {})`. There is no paymentNotice, no windowWarning and no showsEmptyPublishCTA. |
| CLB-event-ops-02 | P1 | **fixed** | f3ea153c7: App/ClubOpsEventInlineRoster.swift:7-71 (segmented bucket Picker, member rows, `tel:` Link, 标记到场/更正未到 → full roster), mounted at ClubOpsEventView.swift:126-130 and fed by :193-197. Caveat: the attendance correction behind it (`correctAttendance`) does not dispatch in Release. |
| CLB-event-ops-05 | P2 | **open** | ClubOpsEventView.swift:57 still uses `action.retry`. A missing clubId still gives `unavailable` (MPReviewedPageScreen.swift:328), or `.invalidRequest` (ClubOpsEventView.swift:174). |
| CLB-r9-event-ops-01 | P2 | **open** | ClubOpsEventView.swift:142 still pushes `.eventTopics`. |
| CLB-event-ops-09 | P2 | **open (visual only)** | ClubOpsEventView.swift:107-148: rows are still `CYListRow(trailing: .none)` inside NavigationLink. Not checked visually. |
| CLB-r9-native-01 | P2 | **open** | ClubTopicDetail+Port.swift:14 still has `.lineLimit(1).minimumScaleFactor(0.6)`. |
| CLB-r9-native-02 | P2 | **open** | ClubGapTopicDirectorViews.swift:46 and :48 still have the literals "站点准备" and "进行中队伍". Core ClubGapTopicDirector is unchanged. |
| CLB-r9-native-05 | P2 | **open** | ClubGapRound4Views.swift:124-127 (16 pt pin), ClubStoryViews.swift:180 (28 pt dot), :215 (16 pt pin) and :237 (117×80) are unchanged. |
| CLB-event-ops-06 (not in my list, but in the r9 queue for this page) | P1 | **fixed (display)** | 7522186c1: ClubOpsEventFormFields.swift:24-37 is gated on `topicFact?.showsCapacity`. The fact is fed from ClubSeriesScheduleEditor.swift:491-513 through the environment into ClubGovernanceCommandForm.swift:75 and :225. The offerWindowText readout is at ClubOpsEventFormFields.swift:47-58. Caveat: `createSeries` does not dispatch in Release. |

No row in this slice is a money row.

## 2. Page scores (r10 code)

| page | r9 | r10 | Δ | notes |
|---|---|---|---|---|
| topic-detail | 35/49 | **36/49** | +1 | 默认结局收尾 (wxml:238-243) is now present. 通用玩法 is not counted, because it has no action form and the tap is a dead end. No regressions; the topic ranges in GV only had their line numbers shifted. |
| topic-story | 31/35 | **31/35** | 0 | No code changed. |
| event-ops | 34/43 | **36/43** | +2 | Two rows are now present: the inline roster tabs and member cards (wxml:79-113), and the capacity hide plus 候补认领时长 readout (wxml:253-264). Both writes behind them are dead in Release. |

Regression outside this slice: 4df2d6204 removed the roles-list `keepingOnFailure` and the 列表没刷新成功，下拉重试 toast (formerly GV:345, 1196, 1238-1243). The new comment says this behaviour moved into finishRoleManagementReturn. The roles-page owner should verify that.

## 3. Native grading

| page | grade | List/Form? | CY* count | chrome count | citations |
|---|---|---|---|---|---|
| topic-detail | **partly** | List (`.listStyle(.plain)`), GV:617, 765 | ~19 | ~12 | see A |
| topic-story | **partly** (the gameplay card is custom) | List (`.plain`), GV:2217, 2274 | ~13 | ~13 | see B |
| event-ops | **partly** | List hub (ClubOpsEventView.swift:39); Form for the forms (ClubGovernanceCommandForm.swift:129) | ~19 | ~9 | see C |

**A. topic-detail**
- **Chrome and background:**
  - GV:766 and :771: `.scrollContentBackground(.hidden).cyDomainPageBackground()` and `.cyGroupedSurface()` on a plain List.
  - GV:1577-1578: logo `frame(44)` plus `clipShape(RoundedRectangle(cornerRadius: CYRadius.card))`.
  - GV:1681: `.cyDomainSheet(detents:)`.
  - GV:1947-1955: hand-built bottom bar (`Divider().overlay(CYColor.borderSubtle)` + `.background(.bar)` in safeAreaInset).
  - ClubTopicDetail+Port.swift:10-26: 核销 tiles drawn with `.background(RoundedRectangle(cornerRadius: CYRadius.card).fill(CYColor.bgRaised))` (:20) and `.listRowBackground(Color.clear)`, plus `minimumScaleFactor(0.6)` (:14).
  - ClubTopicDetailRows.swift:36-37: avatar `Circle().fill(bgSurfaceStrong)`.
  - ClubTopicDetailRows.swift:112-131: round quick actions are `Circle().fill(bgRaised)` buttons with `.buttonStyle(.plain)` and a clear row background (:115, :129).
  - ClubTopicDetailRows.swift:164-165: story cover clipped with a RoundedRectangle.
  - ClubTopicDirectorOpsSections.swift:36-41: hand-drawn `chevron.right` in a Button.
  - ClubTopicDirectorOpsSections.swift:129: hand-drawn `n/500` counter inside the Form.
- **CY components:**
  - CYStatusChip: GV:1588, 1615, 1616, 1731; Rows:71, 177.
  - CYEmptyState: GV:1702; DirectorMount:31, 71.
  - CYSkeleton: DirectorMount:64.
  - CYPillButtonStyle: GV:2019, 2023, 2028, 2033, 2039, 2043, 2051; ClubGapTopicDirectorViews.swift:36, 38.
- **Section headers:** `.cyText(.sectionTitle)` everywhere (GV:1694; DirectorOps:46, 111; GapDirector:56, 69, 83).

**B. topic-story**
- **Chrome and background:**
  - GV:2245: AIGC label as `.background(CYColor.bgElevated, in: Capsule())`.
  - GV:2275-2276: hidden scroll background plus cyDomainPageBackground and cyGroupedSurface.
  - GV:2357-2381: chapter chips in a horizontal `ScrollView` of `.bordered` buttons with custom padding and font (a segmented Picker or Menu is the native choice).
  - ClubStoryViews.swift:142: cover clipShape RoundedRectangle.
  - ClubStoryViews.swift:180-182: seq dot `Circle().fill` + `.overlay(Circle().strokeBorder)`.
  - ClubStoryViews.swift:223: stop card `.background(RoundedRectangle(cornerRadius: CYRadius.md).fill(bgRaised))`.
  - ClubStoryViews.swift:237-238: thumbnail 117×80 clip.
  - ClubStoryViews.swift:259: number `Circle().fill(bgOverlay)`.
  - ClubStoryViews.swift:274-281: gameplay card with `.foregroundStyle(.white)`, a 248 pt minimum height, a RoundedRectangle clip, and forced dark via **`.environment(\.colorScheme, .dark)` (:281)**.
  - ClubStoryViews.swift:303-306: `LinearGradient` black scrim.
  - ClubGapRound4Views.swift:124-127: fixed 16 pt pin.
- **CY components:**
  - CYEmptyState: ClubStoryViews:76; GV:2228; ClubStoryHostAnswer.swift:66.
  - CYCoverArt: ClubStoryViews:151, 300.
  - CYStatusChip: ClubStoryViews:317, 323, 325, 327.
  - CYSkeleton: GV:2222.
  - CYPillButtonStyle: GV:2523, 2525.
  - CYDestructiveButtonStyle: GV:2527.

**C. event-ops**
- **Chrome and background:**
  - ClubOpsEventView.swift:44-46: skeleton row with `.e1HeroRow()`.
  - ClubOpsEventView.swift:50-61: hand-built failure VStack plus `CYPillButton` (not ContentUnavailableView).
  - ClubOpsEventView.swift:66 and :74: cyGroupedSurface + hidden background + cyDomainPageBackground.
  - ClubOpsEventView.swift:77-87: denied state as CYEmptyState plus a hand-built body Text in a VStack.
  - ClubOpsEventView.swift:420-442: custom `ClubOpsTableHeading` / `ClubOpsTableNote` header and footer text styling.
  - ClubOpsEventFormFields.swift:13-36: Form row is a VStack holding a section title (`.cardTitle`), notes, a duplicate `Text("club.gov.field.capacity")` label, the TextField and the inline validation. These belong in a Section with a header and a footer.
  - ClubOpsEventFormFields.swift:72-87: reason TextField with the validation and subtitle stacked in the same row.
- **CY components:**
  - CYSkeleton: :42.
  - CYPillButton: :57, 359.
  - CYEmptyState: :78, 260; ClubGapRemainingViews.swift:208.
  - CYListRow: :109, 119, 135, 143.
  - CYRowIcon: :109, 121, 136, 147, 214.
  - CYStatusChip: :222, 224, 284, 288.
- **Already native:** ClubOpsEventInlineRoster.swift (segmented Picker, Link, NavigationLink, no chrome).

## 4. New fix rows

| id | sev | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| CLB-r10-topic-detail-01 | P1 | topic-detail wxml:204-236 | App/ClubTopicDirectorOpsSections.swift:35-43; App/ClubTopicDirectorMount.swift:54 | 通用玩法 action → its own sheet: a `NavigationStack { Form }` with Picker/Toggle/TextField fields per action, 时间为北京时间 and the ledger rows in the footer, toolbar 取消 / 确认并提交. Submit through the shared-run write. Disable the rows while `writeLocked`. Today it pushes PlayDirectorView, which has no generic ops. | Claude App (+ Cursor Core if the shared-run submit is missing) |
| CLB-r10-club-writes-01 | P1 | event-ops / topic-detail writes | Core/ClubGovernanceProduction.swift:31; App/MPFirstClubApprovals.swift:15 | Add createSeries, updateSeries, cancelOccurrence, correctAttendance, saveTopicSettings, endTopic, chapterRecruit, chapterFinish, sendNotification and issueGroupCode (all non-money, all sent by the MP) to `ClubMPFirstGovernance.governance` and its paths. Without them these forms never dispatch in Release. | Cursor Core |
| CLB-r10-nat-topic-detail-01 | P2 | — | App/ClubTopicDetail+Port.swift:10-26 | Remove the tile chrome. Use three `LabeledContent` rows (value `.monospacedDigit()`) in a normal inset Section, and drop minimumScaleFactor. This also closes CLB-r9-native-01. | Claude App |
| CLB-r10-nat-topic-detail-02 | P2 | — | App/ClubTopicDetailRows.swift:93-131; GV:1647-1664 | Replace the circle round actions with a `ControlGroup` or a Section of Buttons with `Label(_, systemImage:)`. No Circle background and no `.plain` style. | Claude App |
| CLB-r10-nat-topic-detail-03 | P2 | — | GV:1942-1956 | Primary footer → `.toolbar { ToolbarItem(placement: .bottomBar) }` or `.safeAreaInset` with `.borderedProminent`. Drop the Divider overlay, `.background(.bar)` and the CYPillButtonStyle uses at GV:2019-2051. | Claude App |
| CLB-r10-nat-topic-detail-04 | P2 | — | GV:765-771, 1681 | Topic overview → `.listStyle(.insetGrouped)` with the system background. Remove scrollContentBackground/cyDomainPageBackground/cyGroupedSurface. `.presentationDetents([.medium, .large])` instead of `cyDomainSheet`. | Claude App |
| CLB-r10-nat-topic-detail-05 | P2 | — | GV:1588, 1615-1616, 1731; ClubTopicDetailRows.swift:71, 177 | CYStatusChip → plain `Text` or `Label` in `.secondary`, or `.badge` on the row. | Claude App |
| CLB-r10-nat-topic-detail-06 | P2 | — | GV:1577-1578; ClubTopicDetailRows.swift:36-37, 164-165 | Remove the custom clips and circle avatars. Use system list row images (no RoundedRectangle clip) and an SF Symbol `person.crop.circle` for the avatar initial. | Claude App |
| CLB-r10-nat-topic-detail-07 | P2 | — | App/ClubTopicDirectorOpsSections.swift:36-41, 129 | Generic ops rows → `NavigationLink` (system chevron). Drop the hand-drawn `n/500` counter and put the length rule in the Section footer. | Claude App |
| CLB-r10-nat-topic-detail-08 | P2 | — | App/MPGap/Club/ClubGapTopicDirectorViews.swift:28-41; App/ClubTopicDirectorMount.swift:62-74 | Unknown-write buttons → plain Buttons in the Section (`.borderless`) or `.confirmationDialog`. Loading → `ProgressView`. Failure → `ContentUnavailableView` + 重新加载. | Claude App |
| CLB-r10-nat-topic-story-01 | P1 | — | App/ClubStoryViews.swift:245-306 | The gameplay card is fully custom: forced `.colorScheme(.dark)` (:281), `.white` text, a LinearGradient scrim and a 248 pt rounded card. Replace it with a List row: thumbnail image + title + `LabeledContent` meta, system colours, Light and Dark. | Claude App |
| CLB-r10-nat-topic-story-02 | P2 | — | App/ClubStoryViews.swift:158-243 | Stop card → plain List row (no `.background(RoundedRectangle)` at :223, no circle dot at :180-182). Use a numbered `Label` or `Image(systemName: "\(n).circle")`, with the thumbnail at system size. This also closes CLB-r9-native-05 for the story page and makes CLB-topic-story-08 moot. | Claude App |
| CLB-r10-nat-topic-story-03 | P2 | — | GV:2353-2381 | Chapter chips → `Picker(.menu)`. The `Menu` path exists at :2350; use it at all sizes and drop the horizontal ScrollView of `.bordered` buttons. | Claude App |
| CLB-r10-nat-topic-story-04 | P2 | — | GV:2240-2247, 2274-2276 | AIGC label → plain `Label` (no Capsule background). List → `.insetGrouped` with the system background. | Claude App |
| CLB-r10-nat-topic-story-05 | P2 | — | App/ClubStoryViews.swift:76, 317-327; GV:2222-2228, 2523-2527; App/ClubStoryHostAnswer.swift:66 | CYEmptyState → `ContentUnavailableView`. CYStatusChip → `Label` in `.secondary`. CYPill/Destructive button styles → `.borderedProminent` / `role: .destructive`. CYSkeleton → `.redacted(reason: .placeholder)`. | Claude App |
| CLB-r10-nat-event-ops-01 | P2 | — | App/ClubOpsEventView.swift:41-61, 76-88 | Loading → `ProgressView` or redacted rows (drop `e1HeroRow`). Failure → `ContentUnavailableView { } actions: { Button("重新加载") }` (also closes CLB-event-ops-05a). Denied → `ContentUnavailableView` with description. | Claude App |
| CLB-r10-nat-event-ops-02 | P2 | — | App/ClubOpsEventView.swift:107-148, 214 | CYListRow/CYRowIcon → `NavigationLink { } label: { Label(title, systemImage:) }`. Meta goes in the Label subtitle or a `.secondary` Text. | Claude App |
| CLB-r10-nat-event-ops-03 | P2 | — | App/ClubOpsEventView.swift:66, 74, 111, 139, 149, 420-442 | System `.insetGrouped` background. `Section("…")` / `footer: Text(…)` without the ClubOpsTableHeading/Note styling. | Claude App |
| CLB-r10-nat-event-ops-04 | P2 | — | App/ClubOpsEventFormFields.swift:13-36, 72-87 | Split the VStack rows into `Section { TextField } header: { Text(容量) } footer: { notes + validation }`. Remove the duplicate label Text. | Claude App |
| CLB-r10-nat-event-ops-05 | P2 | — | App/ClubOpsEventView.swift:222-224, 284-288, 359 | CYStatusChip → `.secondary` Text or `.badge`. CYPillButton → `Button(…).buttonStyle(.bordered)`. | Claude App |

---

# Appendix C

## out-C — r10 club sub-audit: governance / roles / apply / create / enroll / edit (+scene-club-edit)

App: app checkout @ 82bcf2c2d (r9 measured ebf6c160c). Paths are relative to app checkout. `GV` = App/ClubGovernanceViews.swift, `OPS` = App/ClubOperationsViews.swift, `CF` = App/ClubGovernanceCommandForm.swift, `GS` = App/ClubOpsGovernanceSections.swift. MP paths are relative to chengyinhub-xcx/pages/club/.

## 0. Gate re-check (gate-01/02/03): all three now dispatch in Release (China)
Commit 097702ffb ("发行态默认打开非资金俱乐部写入") made these changes:
- **Release default on.** `RegionalLaunchConfiguration.reviewedDeployment` sets `playerWritesEnabled: true` and `productionGatesEnabled: true` (App/RegionalLaunchConfiguration.swift:89-90).
- **gate-01 (governance).** App/ReviewedPlayerWriteLeases.swift:1452 passes `clubGovernanceApproval: playerWritesEnabled ? MPFirstClubApprovals.governance(context) : nil`. That builds `ClubGovernanceProductionApproval(mpFirstMarket:)` for ban, unban, transferOwner, report, appeal, hostApply and dissolve (App/MPFirstClubApprovals.swift:9-15; Core/ClubGovernanceProduction.swift:31, 58-63, 73).
- **gate-02 (roles).** App/AppCompositionRoot.swift:607 sets `clubRoleAssignmentApproval` / `clubRoleRevocationApproval` from `MPFirstClubApprovals.roleAssignment/roleRevocation`. This runs under `grantPlayerWrites` (reviewed + playerWritesEnabled + China, :595-601).
- **gate-03 (create/edit).** App/AppSession.swift:6072 now passes `approvalSource:` (→ `MPFirstClubApprovals.operations`) and `journal: composition.storage.operationJournal()`. As a result `writeAvailability == .approved` (Core/ClubOperationsService.swift:223-225, 261).
- **Firewall.** The composition firewall admits these POSTs (App/AppCompositionRoot.swift:3591 → `MPFirstClubWriteRoute.accepts`, App/MPFirstClubApprovals.swift:66-105). It blocks pay, refund, payout, withdraw, quote, registration, pricing and settlement paths and money keys.
- **Caveat.** These approvals exist only when `market == .china`. Other markets keep the gates closed, which is correct for an MP port.
- **Effect.** The release score now equals the code score for every page in this slice. Another agent owns the gate rows' status.

## 1. r9 row status
| id | r9 sev | status | evidence |
|---|---|---|---|
| CLB-governance-01 | P1 | **fixed** (ea8d9eaec App/ClubOpsMemberActionCard.swift:8-66, mounted at GV:1528-1535) | The manage link (`mode=manage` → `clubRead(.bans)`, App/MPReviewedPageScreen.swift:378-382) now shows the ban records (`ClubOpsBanSection`, GV:1526) and then the 对成员执行 card on the same page. The card has a member `Picker` (:28-34), the 期限 `ClubOpsBanDurationPicker` (:36, GS:428-438; the seed's `banDays` is honoured at Core/ClubGovernanceFormDraft.swift:43-47), 封禁 (:37-45) and the owner-only 转让主理人 (:46-60). If the members read fails, it falls back to the 成员 link (:63-64). `memberId` preselects the member (:90). Dispatch is live now that gate-01 is on. |
| CLB-apply-04 | P1 | **fixed** (5f10414e2 GV:1461-1481) | A `merchantActive` account gets the 切换到商家端继续经营 sub and the 切换到商家端 button → `MPReviewedPageScreen("pages/merchant/index/index")` (GV:1465-1477). The other branch still goes to 查看商家入驻. Remaining differences, logged as CLB-r10-apply-01/02: (a) the app pushes instead of the MP's `reLaunch`; (b) no read carries `merchantActive`, so the app defaults it to `true` (GV:1465), and a player account with an inactive merchant row is not detected (MP apply/index.js:99-110). |
| CLB-apply-05 | P1 | **open** | CF:172-177: step 4 still shows only `flagRow("hasGuideCert")`, with the comment "picker stays hidden". `ClubGapApplyCertImagesSection` (App/MPGap/Club/ClubGapRound4Views.swift:156) still has 0 call sites, and `certImages` is still excluded at CF:241. |
| CLB-r8-create-01 | P1 | **fixed** (762635dd5 OPS:526-541, 1173-1181, 1287-1288) | When the name is taken, the page shows the inline 创建没有完成 block, the reason and 去改名称 (`club.ops.create.editName`, 1 xcstrings key). The button calls `createStepBar.editName()` → `setCreateStep(3)`. The auto-jump is removed: `onChange(createNameTaken)` / `onAppear` only set the error. The comment at OPS:527-528 is now stale ("already sends the wizard back"). |
| CLB-G19 | P1 | **fixed** (b6a23277e OPS:454-461) | 改为转让主理人 (key present in xcstrings) is a `NavigationLink` in the edit 危险操作 section, next to 解散. It opens `ClubGovernanceReadView(operation: .bans, …)`, which is now the governance manage page with the transfer card (see governance-01). |
| CLB-r8-governance-01 | P2 | **partly** (unchanged) | Core/MiniProgramPageLink.swift:78-79 still has `required: ["clubId"]`. A link without `clubId` is rejected before the screen (App/MPParityKit.swift:258-261), so it never reaches `MemberMissingLinkState` (App/MPReviewedPageScreen.swift:393). |
| CLB-r9-create-01 | P2 | **open** | OPS:186: still a bare `ProgressView()`. The xcstrings file has no 正在确认创建资格 key. |
| CLB-r9-create-02 | P2 | **open** | OPS:380-382: a non-host still sees the `ClubCreateHostApplicationLink` row. There is no auto-open and no 正在前往主理人申请 key. |
| CLB-r9-create-03 | P2 | **open** | OPS:233-242: the toolbar holds only the ✕ `cancellationAction`. There is no `n / 4` item. |
| CLB-r9-create-04 | P2 | **open** | OPS:1261 still uses the `ClubCreateCityRow` picker (App/ClubKit/ClubCreateKit.swift:163-250), not a typed field (如 上海, max 20). |
| CLB-enroll-08 | P2 | **partly** (unchanged) | App/MPReviewedPageScreen.swift:321-324: without `clubId` the page still falls to `unavailable`. There is no owned-club fallback and no 还没有可管理的俱乐部 key. |
| CLB-r9-enroll-01 | P2 | **open** | App/ClubEnrollmentView.swift is unchanged since ebf6c160c. Refresh is only `.refreshable` (:190, 196-199). There is no 正在更新报名名册… line or key. |
| CLB-r9-edit-01 | P2 | **open** | App/MPReviewedPageScreen.swift:309-310: `if let id … else { unavailable }`. |
| CLB-r9-native-04 | P2 | **open, superseded — drop** | GV:737 `Text(...).font(.footnote).foregroundStyle(.secondary)` is unchanged. Under native-r2's "EVERYTHING native" rule this is already the Apple-correct form (Dynamic Type style plus a system semantic colour). The r9 action (→ `.cyText(.meta)`) would move it away from native, so retire the row. GV:737 belongs to topic customers, not to a page in this slice. |
| CLB-r9-gate-01/02/03 | P0 | (owned elsewhere) | All three dispatch in Release/China; see §0. |

Money rows: none in this slice.

## 2. Page scores (r10)
| page | r9 code | **r10 code** | r9 release | **r10 release** | rows newly present | still open | regression |
|---|---|---|---|---|---|---|---|
| governance | 25/27 | **26/27** | 19 | **26** | row 12 (governance-01) | row 3 (r8-governance-01) | none |
| roles | 24/24 | **24/24** | 22 | **24** | — | — | none |
| apply | 22/24 | **23/24** | 18 | **23** | row 7 (apply-04) | row 16 (apply-05) | none |
| create | 20/25 | **21/25** | 17 | **21** | row 21 (r8-create-01) | rows 1, 2, 8, 17 (create-01..04) | none |
| enroll | 21/24 | **21/24** | 21 | **21** | — | rows 1, 7, 9 (enroll-08, enroll-01, +1) | none |
| edit (+scene-club-edit) | 23/25 | **24/25** | 20 | **24** | row 19 (G19) | row 4 (edit-01) | none |
| **slice total** | 135/149 | **139/149 (93.3%)** | 117 | **139** | +4 | 10 | none |

- **How rows were mapped.** Open rows were matched to fix rows by the r9 appendix C counts: governance has 2 open rows and 2 fix rows; create has 5 and 5; edit has 2 and 2.
- **Release score.** Release equals code because gates 01/02/03 are on (§0).
- **Regressions.** None found. The r9-present files on these pages (ClubEnrollmentView, GS, ClubRole*) have no commits since ebf6c160c. The GV, OPS and CF commits are additive: 4df2d6204 only touches the topic-settings load, and 7522186c1 only touches event-ops capacity.

## 3. Native column
Legend:
- **CY\*** counts CY component, style and sheet usages on the page's render path.
- **chrome** counts custom background, radius, stroke, blur, card, custom-label and custom-insets sites.
- Not counted per line: `.cyText(...)`, which maps to Dynamic Type styles (App/DesignSystem/CYDesignTokens.swift:316-330), and `CYColor.*` / `palette.*` colour tokens. Both are custom tokens and should become system semantic colours in one sweep; counts are given per file.

| page | grade | List/Form? | CY\* | chrome | citations |
|---|---|---|---|---|---|
| governance | partly | List (GV:617 `List`, `.listStyle(.plain)` GV:766); forms are `Form` (CF:129) | 10 | 5 | **Page ground:** GV:767 + GV:773 (`scrollContentBackground(.hidden).cyDomainPageBackground()` + `cyGroupedSurface()`); CF:484-485 (same on the ban/transfer/unban/report forms). **CY:** GV:629 CYSkeleton (loading); GV:689 CYPillButtonStyle (generic retry); GS:376 CYPillButton (denied 返回); GV:2523/2525/2527 ClubGovActionChrome CYPillButtonStyle/CYDestructiveButtonStyle (the `edit()` primary/secondary/destructive buttons); CF:526-531 CYConfirmSheet (discard); App/ClubKit/ClubGovernanceConsequence.swift:52-53, 63-65 CYConfirmConsequence → App/ClubKit/ClubMemberActionKit.swift:92 CYResizableSheet, :122 CYPillButtonStyle, :128 CYDestructiveButtonStyle (ban/transfer consequence sheet). **Card chrome:** ClubMemberActionKit.swift:115 `RoundedRectangle(...).fill(palette.bgElevated)`. **Hand-built state:** GS:364-381 denied note (VStack + lock image + pill) instead of `ContentUnavailableView`. **Tokens:** App/ClubOpsMemberActionCard.swift:41, 51, 54, 56 (CYColor, CYSpacing); GS:77-91 (CYColor ×5). |
| roles | partly | List (GV), assign/revoke `Form` (CF:129) | 7 | 6 | **Page ground:** GV:767/773; CF:484-485. **CY:** GV:629 CYSkeleton; GV:689 CYPillButtonStyle; GS:376 CYPillButton (roles denied); CF:526 CYConfirmSheet; revoke consequence via ClubGovernanceConsequence.swift:73-74 → ClubMemberActionKit.swift:92/122/128. **Chrome:** GS:46-55 `ClubOpsTag` capsule tag (`.background(..., in: Capsule())` :53), used at GS:306, 315; ClubMemberActionKit.swift:115 card fill. **Hand-built picker:** App/ClubRoleAssignmentPicker.swift:129-178 uses two `DisclosureGroup`s with check-mark buttons and a hand-made 取消 row (:144-146, 168-170) instead of `Picker` (`.navigationLink`). **Hand-built state:** GS:364-381 denied note. Recovery sections (App/ClubRoleAssignmentRecoverySection.swift, App/ClubRoleRevocationRecoverySection.swift) are system rows apart from cyText. |
| apply | partly | List (GV hostStatus) + `Form` (CF hostApply wizard) | 12 | 6 | **Page ground:** GV:767/773; CF:484-485. **CY:** GV:649 CYEmptyState (signed out); GV:1466 CYEmptyState (merchant); GV:1476, 1479 CYPillButtonStyle; GV:1485 CYStatusChip (已生效); GV:2523 ClubGovActionChrome primary pill (成为主理人, GV:1505); CF:315 CYPillButtonStyle (retry submit); CF:376 CYPillButtonStyle (上一步); CF:712 CYPillButtonStyle (下一步); CF:526 CYConfirmSheet. **Custom type/rows:** GV:1501 `.font(CYTypography.pageTitle)` hero text + `.listRowBackground(Color.clear)` (GV:1468, 1481, 1497, 1503, 1506). **Custom input labels:** CF:740-754 own label + red `*` above each `TextField` (not system-drawn). **Hand-built error:** CF:299-319 VStack error block. |
| create | partly | `Form` (OPS:185) | 17 | 9 | **Page ground:** OPS:221-222. **CY:** OPS:190 CYEmptyState (signed out); OPS:360 CYEmptyState (limit/leader); OPS:377, 508, 535, 541, 620, 1158, 1281, 1643, 1653 CYPillButtonStyle; OPS:518 CYSkeleton (submitting); OPS:1649 CYFooterBar (step bar); OPS:1056 CYHeroHeader (flat/UI-test path only); App/ClubOperationsReviewView.swift:13 CYHeroHeader, :45 CYPillButtonStyle; App/ClubKit/ClubCreateKit.swift:212 CYResizableSheet (city), :250 CYListRowButtonStyle. **Card/chip chrome:** ClubCreateKit.swift:7-58 `ClubR1OptionCard` (RoundedRectangle fill :24, :46, stroke overlay :48, :51) used for 类型 at OPS:1195; :60-90 `ClubR1Chip` capsule (:82) + :92 `ClubR1WrapLayout` used for 方向 at OPS:1221-1224; :129 `ClubR1FieldError`; :163-198 `ClubCreateCityRow`; :213-225 city search box with own RoundedRectangle background (:225). **Custom input labels:** OPS:1453-1465 own label + `*` above `TextField`. **Review sheet ground:** ClubOperationsReviewView.swift:59-60, 69 (`cyDomainPageBackground`, `cyDomainScreen`). **Tokens:** CYColor ×17 (OPS), ×15 (ClubCreateKit). |
| enroll | partly | List (App/ClubEnrollmentView.swift:89) | 9 | 6 | **Page ground:** :161-162. **CY:** :92 CYSkeleton; :106, :117 CYNoteBanner; :125, :320 CYPillButton; :142 CYEmptyState; :343, :470 CYStatusChip. **Chrome:** :276 `.cyPressTracking()` custom press effect; :285 `clipShape(RoundedRectangle(cornerRadius: CYRadius.inner))` on covers; :274/:310/:452/:458 forced `minHeight` row frames; :510 custom `listRowInsets` (pageHorizontal) instead of system insets. **Tokens:** `palette.*` ×20. |
| edit (+scene-club-edit) | partly | `Form` (OPS:185) | 7 | 8 | **Page ground:** OPS:221-222. **CY:** OPS:199 CYEmptyState (no permission); OPS:230 CYFooterBar (save bar); OPS:332 CYStatusChip; OPS:484 CYPillButtonStyle; OPS:509 `.questifyPrimary`; ClubOperationsReviewView.swift:13 CYHeroHeader, :45 CYPillButtonStyle. **Card chrome:** OPS:318-342 `clubIdentityHero`: 56×56 fixed frame + RoundedRectangle bg (:324-325), card bg + stroke overlay (:338-339), `.questifyCardListRow()` (:341); OPS:349-353 `QuestifyImageEntityCard(... progressiveBlur: .cover)` + `.questifyCardListRow()`. **Custom input labels:** OPS:1453-1465. **Hand-built save-failed block:** OPS:476-490 VStack + pill buttons in the footer. **Danger row:** OPS:451 `Label(...).foregroundStyle(CYColor.dangerText)` instead of `Button(role: .destructive)`. |

No page in this slice uses `.preferredColorScheme`, hex, `CYRGB`, `Color(red:)`, `.system(size:)` or gradients. Every page uses a system `List` or `Form` skeleton, so nothing grades `custom`.

## 4. New fix rows
| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| CLB-r10-nat-shared-01 | P2 | — | GV:766-767, 773; CF:484-485; OPS:221-222; App/ClubEnrollmentView.swift:161-162; App/ClubOperationsReviewView.swift:59-60, 69 | Drop `scrollContentBackground(.hidden)` + `cyDomainPageBackground()` + `cyGroupedSurface()`/`cyDomainScreen`. Let `List`/`Form` draw `systemGroupedBackground`. Split by file. | Claude App |
| CLB-r10-nat-shared-02 | P2 | — | GV:2518-2545 (ClubGovActionChrome) | Replace CYPillButtonStyle/CYDestructiveButtonStyle with `.borderedProminent` / `.bordered` / `Button(role: .destructive)`. Inline roles: keep `.borderless`, but use `role: .destructive` instead of the CYColor tint. | Claude App |
| CLB-r10-nat-shared-03 | P2 | — | CF:526-531; App/ClubKit/ClubMemberActionKit.swift:78-130; App/ClubKit/ClubGovernanceConsequence.swift:41-75 | Discard → `.confirmationDialog`. Ban/transfer/revoke consequence → `.alert` or `.confirmationDialog` with the consequence lines as the message. Remove CYResizableSheet, the card fill (:115) and the pill styles. | Claude App |
| CLB-r10-nat-governance-01 | P2 | governance/index.wxml (no-permission) | GS:364-381 | Denied note → `ContentUnavailableView("…", systemImage: "lock", description:)` with a system `Button("返回")` in `actions`. Replace CYPillButton :376. | Claude App |
| CLB-r10-nat-governance-02 | P2 | — | GV:629, 689 | Loading → `.redacted(reason: .placeholder)` rows or a `ProgressView`. Generic retry → plain `Button` in its Section. Remove CYSkeleton / CYPillButtonStyle. | Claude App |
| CLB-r10-nat-governance-03 | P2 | — | App/ClubOpsMemberActionCard.swift:41, 51, 54-56; GS:77-91, 129-130, 206-239 | Swap the CYColor tokens for `.secondary` / `.tertiary` / `.red`. Swap the `.cyText` tokens for `.font(.footnote)` etc. | Claude App |
| CLB-r10-nat-roles-01 | P2 | roles/index.wxml:84-91 | App/ClubRoleAssignmentPicker.swift:129-178 | Replace the two hand-built DisclosureGroup lists with `Picker(selection:) { … }.pickerStyle(.navigationLink)` for member (avatar label via `MPAsset`) and role (name + summary). | Claude App |
| CLB-r10-nat-roles-02 | P2 | — | GS:46-55, 306, 315 | `ClubOpsTag` capsule → plain secondary `Text` or `LabeledContent` trailing value. Remove the Capsule background. | Claude App |
| CLB-r10-nat-apply-01 | P2 | apply/index.wxml:28-33 | GV:649, 1466-1481 | Signed-out and merchant states → `ContentUnavailableView` + `actions:` system buttons. Remove CYEmptyState, CYPillButtonStyle and `listRowBackground(.clear)`. | Claude App |
| CLB-r10-nat-apply-02 | P2 | apply/index.wxml (intro, done) | GV:1485, 1499-1506 | 已生效 → `LabeledContent` value or `.badge`, not CYStatusChip. Intro title → `.font(.largeTitle.bold())` in a normal row, not `CYTypography.pageTitle` + clear row. | Claude App |
| CLB-r10-nat-apply-03 | P2 | apply/index.wxml (steps 1-4) | CF:740-754, 299-319, 315, 376, 712 | Use the system `TextField("label", text:, prompt:)` row with required-ness in the section footer (drop the own label + `*`). Error → Section footer text + a plain `Button`. 上一步 / 下一步 → `.bordered` / `.borderedProminent` or toolbar items. | Claude App |
| CLB-r10-nat-create-01 | P2 | create/index.wxml (type/direction) | App/ClubKit/ClubCreateKit.swift:7-127; OPS:1195-1241 | 类型 option cards → `Picker(.inline)` with check marks. 方向 chips + wrap layout → multi-select `List` rows with `checkmark` (or `Toggle`s). `ClubR1FieldError` → section footer. | Claude App |
| CLB-r10-nat-create-02 | P2 | create/index.wxml:119-121 | App/ClubKit/ClubCreateKit.swift:163-250; OPS:1261 | Fold into CLB-r9-create-04: a typed `TextField` (prompt 如 上海), which removes CYResizableSheet, the custom search box (:213-225) and CYListRowButtonStyle. | Claude App |
| CLB-r10-nat-create-03 | P2 | create/index.wxml (bottom bar) | OPS:1630-1660, 1276-1283, 1150-1160 | Step bar: drop CYFooterBar + pills. Use toolbar `ToolbarItem(.confirmationAction)` 下一步/创建 and a 上一步 back button (or a `.safeAreaInset` with `.borderedProminent`). | Claude App |
| CLB-r10-nat-create-04 | P2 | create/index.wxml:12-28, 134-136 | OPS:186, 190, 360-378, 518-541, 620 | Bootstrap, signed-out, limit and failed states → `ContentUnavailableView` (do with CLB-r9-create-01). Submitting → `ProgressView`. Retry / 去改名称 / 进入管理 → system `Button` styles. | Claude App |
| CLB-r10-nat-create-05 | P2 | — | OPS:1444-1466 | Shared field helper (create + edit): remove the own label/`*` VStack. Use `TextField(labelKey, text:, prompt:)` in a labelled `Section` header and put the required note in the footer. | Claude App |
| CLB-r10-nat-create-06 | P2 | — | App/ClubOperationsReviewView.swift:13, 45, 59-69 | Review sheet: remove CYHeroHeader (use `.navigationTitle`) and the pill CTA (toolbar `.confirmationAction`). | Claude App |
| CLB-r10-nat-enroll-01 | P2 | enroll/index.wxml | App/ClubEnrollmentView.swift:92, 106, 117, 125, 142, 320 | CYSkeleton → redacted rows. CYNoteBanner → Section footer or `Label` row. CYPillButton retry → plain `Button`. CYEmptyState → `ContentUnavailableView`. | Claude App |
| CLB-r10-nat-enroll-02 | P2 | enroll/index.wxml:37 | App/ClubEnrollmentView.swift:274-285, 310, 343, 452-458, 470, 510 | Remove `.cyPressTracking()`, forced row min-heights, custom `listRowInsets` and CYStatusChip (→ secondary text or `.badge`). Keep the `MPAsset` cover but drop the custom radius (or use a system default thumbnail). Swap the 20 `palette.*` colours for semantic ones. | Claude App |
| CLB-r10-nat-edit-01 | P2 | edit/index.wxml (header) | OPS:318-342, 344-353 | Replace `clubIdentityHero` (fixed 56×56 tile, card fill + stroke, `questifyCardListRow`) and `QuestifyImageEntityCard(progressiveBlur:)` with a plain `Section` row: `LabeledContent` / `Label` with name, city and role, plus the `MPAsset`/remote cover as a system-sized image. Supersedes CLB-r9-edit-02. | Claude App |
| CLB-r10-nat-edit-02 | P2 | scene-club-edit/index.wxml:161-170, 206 | OPS:199, 230, 451-461, 476-490, 484, 509 | Save bar: toolbar `.confirmationAction` 保存修改 instead of CYFooterBar + pills. Save-failed → `.alert` with 重新保存 / 继续编辑. 解散 → `Button(role: .destructive)`. No-permission → `ContentUnavailableView`. Role chip (:332) → text. | Claude App |
| CLB-r10-apply-01 | P2 | apply/index.js:159-162 | GV:1471-1473 | 切换到商家端 should replace the stack (MP `reLaunch`): dismiss the club stack and switch to the merchant root instead of pushing `pages/merchant/index/index` on top. | Claude App |
| CLB-r10-apply-02 | P2 | apply/index.js:99-110 | GV:1461, 1465; Core hostStatus read | No read carries `merchantActive` (0 hits in Core), so the app always treats it as true and never takes the 查看商家入驻 branch. A player account with a merchant row is also not shown the merchant state. Add the merchant-row probe (MP `api/merchant/…` status) to the hostStatus read and pass `merchantActive`. | Cursor Core + Claude App |
| CLB-r10-create-01 | P2 | — | OPS:527-528 | The stale comment says a taken name "already sends the wizard back"; it no longer does. Update the comment only (housekeeping, not parity). | Claude App |

---

# Appendix D

## out-D: club r10 slice D (ops pages): parity and native

App = app checkout @ 82bcf2c2d (r9 measured ebf6c160c). MP = chengyinhub-xcx/pages/club/<page>/. All lines were read in code. I did not rely on commit messages.

Since r9, only three of the slice's view files changed for slice rows: ClubPayoutReceiverView, ClubFEReferenceSettlementHost and the new ClubPersonalFundsStagesSection. The other r9 target files (ClubBadgeManagementView, ClubKit/ClubGroupCodeSessionStep, ClubOpsCustomerViews, ClubCheckinRailView, ClubManagementView, ClubNotificationAudienceView) have no commits in ebf6c160c..HEAD. ClubGovernanceCommandForm, ClubGovernanceViews and MPReviewedPageScreen did change, but only for rows outside this slice.

## 1. Row status

| id | r9 sev | status | evidence |
|---|---|---|---|
| CLB-settlement-05 | P1 | **fixed** (6fa970c48 App/PayoutReceiverBridge.swift:13; App/ClubPayoutReceiverView.swift:205,236,271,383,448,521; App/ClubFEReferenceSettlementHost.swift:17-19,47,61) | New `readsOpen` = API configured. Mine, personal, ledger and the FE payer list/export now gate on it. The transport lease still gates only bind/unbind (`isPayout`, Core/PayoutReceiverClient.swift:31). FE settle POST still needs `settleOpen` = payoutOpen plus `ClubFEReferenceMoneyWriteGate` (money, correct). The reads are now open in Release. |
| CLB-settlement-06 | P1 | **fixed** (df48d6588 App/ClubPayoutReceiverView.swift:366,368-378) | `.disabled(!fundsAvailability.allowsWithdraw)`. Footer shows 客诉期结束后可提现 when `.zero && complaintWaiting` (xcstrings value exists) and 仅主理人可发起提现 for a non-owner club view. No write; it hands off to support. The governance club path was already gated (App/ClubOwnerFundsView.swift:260 `availability != .positive`). |
| CLB-r9-settlement-01 | P1 | **fixed** (1b44740cc App/ClubPayoutReceiverView.swift:299-302; App/ClubPersonalFundsStagesSection.swift) | Funds stages are mounted for isOwner‖personal and feed settlement-06. Reachable via MPParityKit.swift:320 and ClubSettlementMineView:220. |
| CLB-notify-05 | P1 | **open** | Still a pushed `NavigationLink` to the `.notificationStatus` read (App/ClubGovernanceCommandForm.swift:452-453). No inline 刷新/刷新中…. `campaignRefresh` is only the silent re-read (:589-594). |
| CLB-customer-detail-04 | P1 | **open** | Still `.sheet(item: $editor)` (App/ClubGovernanceViews.swift:780-785). |
| CLB-group-code-06 | P1 | **open** | `guard let clubID = review.command.scope.clubID ... else { throw .staleReview }` after the server issued the code (App/ClubGovernanceCommandForm.swift:888-891). The MP link still has no clubId (MPReviewedPageScreen.swift:333). The session step passes an optional `clubID` (ClubKit/ClubGroupCodeSessionStep.swift:68). **Moot in Release** until CLB-r10-group-code-01 is fixed. |
| CLB-group-code-05 | P1 | **open** | Neither id → `unavailable` (App/MPReviewedPageScreen.swift:339). `onOpenManage: {}` is still a no-op (App/ClubKit/ClubGroupCodeSessionStep.swift:61). |
| CLB-r8-badges-02 | P2 | **partly** (unchanged) | The title is still `clubR8b.badges.createFailed` = 勋章没有创建成功 (App/ClubBadgeManagementView.swift:290-292; xcstrings zh 勋章没有创建成功). MP title is 勋章没有创建. |
| CLB-workbench-03 | P2 | **open** | `let rows = try? await reader.clubOwned()` silently falls back to the list (App/MPReviewedPageScreen.swift:1122-1123). |
| CLB-r9-payout-receiver-02 | P2 | **open** | The bind pill is still shown while `weChatCode == nil` (App/ClubPayoutReceiverView.swift:126-130,178-179; PayoutReceiverBridge.swift:17). |
| CLB-payout-receiver-01 | — | **money, not a gap** | `weChatCode` is never assigned (PayoutReceiverBridge.swift:17). Bind is TEST-only (:126). |
| CLB-r9-native-03 | P2 | **open** | Hand-built failure VStack plus CYPillButton (App/ClubOpsEventView.swift:49-60). PRV:212-216, 277-281, 99-108. FE host now at App/ClubFEReferenceSettlementHost.swift:88-97. The new ClubPersonalFundsStagesSection.swift:19-25 repeats the pattern. |
| CLB-r9-native-06 | P2 | **open** | `ScrollView { VStack` (App/ClubBadgeManagementView.swift:17-40). The load error is bare text with no retry (:31-35). |

**Release-dispatch check (brief rule): NEW, not in r9.**
- `MPFirstClubApprovals.governance` issues a live approval only for `ClubMPFirstGovernance.governance = [.ban, .unban, .transferOwner, .report, .appeal, .hostApply, .dissolve]` (Core/ClubGovernanceProduction.swift:31). `permits` returns false for other operations (:73-74). The endpoint paths and `MPFirstClubWriteRoute.governancePaths` (App/MPFirstClubApprovals.swift:70-75) do not include them either.
- So **sendNotification / retryNotification, saveCustomer and issueGroupCode never dispatch in Release**. `coordinator.canDispatch` is false: the confirm button is disabled and shows 暂不可用 (ClubGovernanceCommandForm.swift:361-364), and `confirm()` returns silently (:842). That covers 出示团码 and the group-code auto-issue on open.
- **Badges is unreachable in every build.** `clubBadgeManagementApproval` defaults to `{ _ in nil }` (App/AppCompositionRoot.swift:453) and nothing in App passes it (grep: only :173/225/226/453/523). `AppSession.clubBadgeHost` therefore returns nil (App/AppSession.swift:5684-5687). `pages/club/badges?clubId=` renders `unavailable` (MPReviewedPageScreen.swift:313-314), and the club-detail 勋章 entry is hidden (ClubDetailView.swift:284). A unit test asserts the nil default (Tests/AppUnitTests/ClubBadgeHostDefaultTests.swift:19). This was the same at ebf6c160c, so it is not a regression but was missed by r9.
- Join-requests approve/reject goes through `ClubManagementSessionAccess` (AppSession.swift:6083). I did not trace its Release gate (time).

## 2. Page scores (r10 code; Release caveats separate)

| page | r9 | r10 code | Release-reachable | notes |
|---|---|---|---|---|
| badges | 24/25 | 24/25 | **0/25: page unreachable** | badges-02 partly. Badge host never composed (CLB-r10-badges-01). |
| notify | 20/21 | 20/21 | send/retry rows dead in Release | notify-05 open. CLB-r10-notify-01. |
| settlement | 14/15 (Release 12) | **15/15** | **15/15** | Row 7 (funds stages, personal) present. Reads open in Release. Settle write is money. |
| customer-detail | 19/20 | 19/20 | save row dead in Release | customer-detail-04 open. CLB-r10-customer-detail-01. |
| checkin-detail | 16/16 | 16/16 | 16/16 (refund = money) | no change |
| join-requests | 17/17 | 17/17 | not traced | no change |
| group-code | 11/13 | 11/13 | **issue dead in Release** (≈3/13: only the session picker, empty and error states work) | group-code-05/06 open. CLB-r10-group-code-01. |
| customers | 15/15 | 15/15 | 15/15 | reads only |
| payout-receiver | 12/14 | 12/14 | 12/14 (rows 10/11 money) | — |
| workbench | 4/5 | 4/5 | 4/5 | workbench-03 open |
| **total** | 152/161 | **153/161** | — | No code regressions. The Release gaps above are pre-existing and newly surfaced. |

## 3. Native

The shared governance read container (ClubGovernanceViews.swift, used by customers, customer-detail, checkin-detail and the club settlement path) has these custom elements:
- `List` with `.listStyle(.plain)`, `.scrollContentBackground(.hidden)`, `.cyDomainPageBackground()` (:766-767) and `.cyGroupedSurface()` (:773), which overrides the system insetGrouped look;
- CYSkeleton for loading (:629);
- a hand-built failure VStack with CYPillButtonStyle (:679-691);
- `.cyDomainSheet` (:784).

The `.cyDomainScreen(.player)` calls below paint a custom page bg and tint (DesignSystem/CYScreenStyle.swift:48-53). They are not forced dark (`.player.forcedColorScheme == nil`, Theme/Theme.swift:21-24).

**ClubOwnerFundsView `preferredColorScheme`:** only inside `#Preview` (App/ClubOwnerFundsView.swift:379 `.dark`, :384 `.light`). It is not runtime forced dark. Its `CYConfirmSheetLocal` (:344-368) is used only by the preview.

| page | grade | List/Form? | CY* count | chrome count | citations |
|---|---|---|---|---|---|
| badges | **custom** | no (ScrollView+VStack) | 21 | 4 | **Chrome:** ScrollView/VStack App/ClubBadgeManagementView.swift:17-40; `.clipShape(RoundedRectangle)` :142; custom input box (own bg, RoundedRectangle, padding, `n/limit` counter) :396-420; `.cyDomainScreen` :42. **CY\*:** CYSkeleton :30,:73,:191; CYEmptyState :77,:79; CYPillButton :97,:111,:165,:197,:285,:362,:367; CYImageCard :133; CYCoverArt :139; CYSheetContainer :178,:345; CYConfirmSheet :243; CYConfirmConsequence :250-252. **Failure:** bare text, no ContentUnavailableView (:31-35). |
| notify | **partly** | Form (ClubGovernanceCommandForm.swift:129) | 7 | 5 | **CommandForm:** `.questifyPrimary` + `.listRowBackground(Color.clear)` send button :357-360; page bg `.scrollContentBackground(.hidden).cyDomainPageBackground()` + `.cyGroupedSurface()` :484-485; CYConfirmSheet :488,:526. **ClubNotificationAudienceView.swift:** CYSkeleton :140; CYPillButtonStyle :190; CYRowIcon :200. **ClubOpsJoinNotifyViews.swift:** denied CYEmptyState :57; page failure CYEmptyState/CYPillButton + `.e1ActionRow` :87-112. **ClubOpsNotifySections.swift:** clean. Inputs: TextField in Form (CommandForm:763), native. |
| settlement | **partly** | List (PRV:270, :204) / governance List | 19 (PRV share) + 14 (OwnerFunds) + 8 other | 7 + 6 + 3 | **PRV personal/mine:** CYLoadingStateView :209,:275,:455; hand-built failure + CYPillButton :212-216,:277-281; custom 已结算 card (data2XL VStack) :311-327; CYStatusChip :321,:353; `.scrollContentBackground(.hidden)` :228,:287; `.cyDomainScreen` :233,:292. **FE host:** CYLoadingStateView ClubFEReferenceSettlementHost.swift:87; hand-built failure :89-96; ClubGapRound4Views.swift:228,232 CYPillButtonStyle; ClubGapReferenceSettlementView.swift:33 CYEmptyState, :42 CYStatusChip, :59,:65 CYPillButtonStyle. **Funds stages:** ClubPersonalFundsStagesSection.swift:17 CYLoadingStateView, :19-25 hand-built failure. **Governance club path:** ClubOwnerFundsView.swift:226 CYSkeletonLocal (RoundedRectangle bars :330-338), :231 CYBalanceHeroLocal (Capsule bg :296), :237-243 CYMoneyRowLocal, :259 `.cyPrimary`, :268 `.cySecondary`; ClubOpsSettlementViews.swift:27 `.cyDomainCard(radius: .hero)` + :29 clear row, :22,:40 CYStatusChip; ClubSettlementDetail.swift:250,252 CYStatusChip. |
| customer-detail | **partly** | List (shared) + Form editor | 8 | 4 | ClubOpsCustomerViews.swift: CYAvatarView :242; header/metrics HStack with custom insets + clear bg :315-326; ClubOpsCustomerMetricTile `.cyDomainCard` :404; CYEmptyState :330 (+ clear row :331); CYStatusChip :449,:500,:507 (tag chips with xmark as remove control); editor CYPillButton :541; ClubOpsFailureSection CYEmptyState/CYPillButton + `.e1ActionRow` :3-55. The editor is in a `.sheet` with `.cyDomainSheet` (ClubGovernanceViews.swift:780-785). Shared container chrome as above. |
| checkin-detail | **partly** | List (shared) | 3 + 5 (refund panel) | 4 | ClubCheckinRailView.swift: CYEmptyState full-page state :20-33 (clear row :33); cover `.clipShape(RoundedRectangle)` :150 and RoundedRectangle placeholder fill :154-157; CYStatusChip :238. ClubOwnerRefundPanel.swift: CYSheetContainer :59, CYNoteBanner :88,:90, CYDestructiveButtonStyle :107, CYSecondaryButtonStyle :115. |
| join-requests | **partly** | List (ClubManagementView.swift:60) | 18 (file) / ~10 on this path | ~12 on this path | ClubManagementView.swift: CYEmptyState :63,:67,:96 (+ clear rows :64,:68,:97); CYSkeleton :72; `.cyPressable` row button :105; rows `.listRowBackground(Color.clear)` + `.listRowSeparator(.hidden)` + custom insets :127-130; CYPillButtonStyle compact :324,:342,:347; `.scrollContentBackground(.hidden)` :196; `.cyDomainScreen` :197. Swipe actions are native (:113-126). |
| group-code | **partly** | Form (CommandForm) / List (picker) | 9 | 9 | **CYClubGameCodeCard.swift:** hex dark `CYNight.ink1/ink2` (CYRGB 0x0E0E16/0x171726, DesignSystem/CYNight.swift:8-9) :22,:62; RoundedRectangle bg :22,:30,:62; overlay stroke :63; CYPillButton :40. **ClubGroupCodePresentation.swift:** CYClubGameCodeCard :27; CYPillButton reissue :50. **CommandForm:** generating placeholder RoundedRectangle bg :322-328; `.questifyPrimary` + clear row 出示团码 :398-404; CYPillButtonStyle retry :277,:292. **ClubGroupCodeSessionStep.swift:** CYSkeleton :43; CYEmptyState :49. **ClubGapRound4Views.swift:** picker rows Button + hand-drawn chevron instead of NavigationLink :261-267; CYEmptyState :272-281. Save is ShareLink (native). |
| customers | **partly** | List (shared) | 4 | 5 | ClubGovernanceViews.swift: custom capsule chip row in `ScrollView(.horizontal)` with `.background(Capsule().fill…)` :699-716; hand-built search field (HStack + magnifyingglass + TextField) :720-726 instead of `.searchable`. ClubOpsCustomerViews.swift: CYEmptyState filtered-empty :109 + clear row :125; CYStatusChip :189. Shared container chrome. |
| payout-receiver | **partly** | List (ClubPayoutReceiverView.swift:36) | 10 | 3 | CYConfirmSheet :47,:63 (+ `.cyDomainSheet` :60,:77); CYLoadingStateView :86; CYEmptyState :96; hand-built failure VStack + CYPillButton :100-107; CYStatusChip :112,:136; CYPillButton bind/unbind :128,:132; `.listRowBackground(Color.clear)` :143; `.scrollContentBackground(.hidden)` :42; `.cyDomainScreen` :80. ClubMPEmptyState :91 wraps ContentUnavailableView + MP asset (OK). |
| workbench | **partly** | List (ClubDetailView.swift:107) | 4 | 5 | Entry: CYSkeleton (MPReviewedPageScreen.swift:1118). The manage tab it lands on has: ClubDetailTabBar.swift:37-39 hand-drawn segmented track (RoundedRectangle bg); ClubKit/ClubWorkbenchKit.swift:161,201-202 RoundedRectangle card bg; tiles :36-60; clear rows :73,:89. The detail page is mostly another slice's. |

No `.system(size:)`, `Color(red:)` or runtime `preferredColorScheme` in these files. The only hex colour is CYNight in CYClubGameCodeCard.

## 4. New rows

### Parity / Release (new)

| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| CLB-r10-badges-01 | P0 | badges/index.js (whole page) | App/AppCompositionRoot.swift:453 (default `{ _ in nil }`, never passed); App/AppSession.swift:5684-5687; App/MPReviewedPageScreen.swift:313-314; App/ClubDetailView.swift:284 | Issue an MP-first `ClubBadgeManagementApproval` (reads + create + grant, non-money, China market) in the production composition, the same way `MPFirstClubApprovals` does. Today every badges link shows `unavailable` and the detail entry is hidden. Update ClubBadgeHostDefaultTests:19. | Cursor Core |
| CLB-r10-notify-01 | P0 | notify/index.js send / retry | Core/ClubGovernanceProduction.swift:31; App/MPFirstClubApprovals.swift:70-75; App/ClubGovernanceCommandForm.swift:361-364 | Add `.sendNotification` and `.retryNotification` to the MP-first live set, plus their paths (and review-read paths) to `governancePaths`. Today 发送给 N 人 is disabled with 暂不可用 in Release. | Cursor Core |
| CLB-r10-group-code-01 | P0 | group-code/index.js:93-135 | Core/ClubGovernanceProduction.swift:31; App/ClubGovernanceCommandForm.swift:842 | Add `.issueGroupCode` to the MP-first live set and paths. Today the auto-issue and 出示团码 return silently in Release. Land it together with CLB-group-code-06. | Cursor Core |
| CLB-r10-customer-detail-01 | P1 | customer-detail/index.js save | Core/ClubGovernanceProduction.swift:31; App/ClubGovernanceCommandForm.swift:396-404,842 | Add `.saveCustomer` (tags/remark) to the MP-first live set and paths. | Cursor Core |
| CLB-r10-join-requests-01 | P2 (verify) | join-requests approve/reject | App/AppSession.swift:6083 | Not traced: confirm that `ClubManagementSessionAccess` approve/reject dispatches in Release. | Cursor Core |

### Native (each ≤ 1 agent-hour, one file each)

| id | severity | MP file:line | app file:line | what to do | owner |
|---|---|---|---|---|---|
| CLB-r10-nat-badges-01 | P1 | badges/index.wxml | App/ClubBadgeManagementView.swift:17-40 | Replace ScrollView/VStack with `List` and Sections. Subtitle goes to a section header. Loading → `ProgressView`. `listError` → `ContentUnavailableView` + 重新加载 (supersedes r9-native-06). | Claude App |
| CLB-r10-nat-badges-02 | P1 | badges/index.wxml (create sheet) | App/ClubBadgeManagementView.swift:344-420 | Create sheet → `NavigationStack { Form { TextField(axis:) } }` with toolbar 取消 / 创建. Counter and validation go in the section footer. Remove the custom field box (:396-420) and CYSheetContainer/CYPillButton. | Claude App |
| CLB-r10-nat-badges-03 | P1 | badges/index.wxml (list) | App/ClubBadgeManagementView.swift:73-170 | Badge rows: CYImageCard/CYCoverArt → `Label`/`LabeledContent` row with `AsyncImage` thumbnail (no clipShape card). 颁发 → row `Button`/swipe action. 刷新/创建 pills → toolbar `Button`. CYEmptyState → `ContentUnavailableView`. | Claude App |
| CLB-r10-nat-badges-04 | P1 | badges 颁给谁？ | App/ClubBadgeManagementView.swift:178-260,280-299 | Member picker CYSheetContainer → `NavigationStack { List }` sheet. CYConfirmSheet + CYConfirmConsequence → `.confirmationDialog` with message. Failure blocks → plain Text + `Button`. | Claude App |
| CLB-r10-nat-gov-shared-01 | P2 | — | App/ClubGovernanceViews.swift:629,679-691,766-767,773,784 | Shared read container: drop `.listStyle(.plain)`, `scrollContentBackground(.hidden)`, `cyDomainPageBackground` and `cyGroupedSurface` (use the system insetGrouped default). CYSkeleton → `ProgressView`/`.redacted`. Generic failure → `ContentUnavailableView` + 重试. `.cyDomainSheet` → `.presentationDetents`. | Claude App |
| CLB-r10-nat-notify-01 | P2 | notify/index.wxml | App/ClubGovernanceCommandForm.swift:357-360,427,484-485 | Send/preview: `Button` row in its Section (or `.borderedProminent`) instead of `.questifyPrimary` + clear row. Drop the custom page bg. | Claude App |
| CLB-r10-nat-notify-02 | P2 | notify/index.wxml audience | App/ClubNotificationAudienceView.swift:140,190,200 | CYSkeleton → `ProgressView`. CYPillButtonStyle → `.bordered`. CYRowIcon → `Label(…, systemImage:)`. | Claude App |
| CLB-r10-nat-notify-03 | P2 | notify denied/error | App/ClubOpsJoinNotifyViews.swift:32-112 | Load-issue, denied and page-failure states → `ContentUnavailableView` (label, description, actions). Remove `.e1ActionRow` and CYPillButton. | Claude App |
| CLB-r10-nat-notify-04 | P2 | notify/index.wxml:76-78 | App/ClubGovernanceCommandForm.swift:452-453 | Implements CLB-notify-05 natively: an inline `Button("刷新")` with `ProgressView` while re-reading, in the campaign Section. No pushed page. | Claude App |
| CLB-r10-nat-settlement-01 | P2 | settlement/index.wxml:20-21 | App/ClubPayoutReceiverView.swift:209-216,228,233,275-292 | Mine/personal: loading → `ProgressView`. Failure → `ContentUnavailableView` + 重新加载. Remove `scrollContentBackground(.hidden)`/`cyDomainScreen`. | Claude App |
| CLB-r10-nat-settlement-02 | P2 | settlement/index.wxml (settled card, topics) | App/ClubPayoutReceiverView.swift:311-327,341-355 | 已结算 card → `LabeledContent` (amount `.monospacedDigit()`). CYStatusChip → secondary Text / `.badge`. Topic rows as standard NavigationLink rows. | Claude App |
| CLB-r10-nat-settlement-03 | P2 | settlement funds/FE | App/ClubFEReferenceSettlementHost.swift:87-96; App/ClubPersonalFundsStagesSection.swift:17-25 | CYLoadingStateView → `ProgressView`. Hand-built failure HStack → `ContentUnavailableView` in section, or a plain `Button("重试")` row (closes the r9-native-03 parts). | Claude App |
| CLB-r10-nat-settlement-04 | P2 | cy/fe-reference-settlement | App/MPGap/Club/ClubGapRound4Views.swift:222-232; App/MPGap/Club/ClubGapReferenceSettlementView.swift:33,42,59,65 | Range bar and payer rows: CYPillButtonStyle → `.bordered`/`.borderedProminent`. CYEmptyState → `ContentUnavailableView`. CYStatusChip → Text. Range pickers → `DatePicker` in Section. | Claude App |
| CLB-r10-nat-settlement-05 | P2 | settlement cy-funds-stages (club view) | App/ClubOwnerFundsView.swift:223-342 | Delete CYBalanceHeroLocal/CYMoneyRowLocal/CYSkeletonLocal. Use `LabeledContent` rows (as ClubPersonalFundsStagesSection already does) and `ProgressView`. `.cyPrimary`/`.cySecondary` → `.borderedProminent`/`.bordered`. | Claude App |
| CLB-r10-nat-settlement-06 | P2 | settlement summary (club view) | App/ClubOpsSettlementViews.swift:15-45; App/ClubSettlementDetail.swift:250-252 | Hero `.cyDomainCard` + clear row → `LabeledContent` in Section. CYStatusChip → Text/`.badge`. | Claude App |
| CLB-r10-nat-payout-receiver-01 | P2 | payout-receiver/index.wxml | App/ClubPayoutReceiverView.swift:46-78 | CYConfirmSheet ×2 → `.confirmationDialog` (unbind `role: .destructive`). | Claude App |
| CLB-r10-nat-payout-receiver-02 | P2 | payout-receiver/index.wxml | App/ClubPayoutReceiverView.swift:86-143 | CYEmptyState / hand-built failure → `ContentUnavailableView`. CYStatusChip → `LabeledContent` text. Bind/unbind pills + clear row → `Button` rows in Section (TEST-only; pair with CLB-r9-payout-receiver-02). | Claude App |
| CLB-r10-nat-customer-detail-01 | P2 | customer-detail/index.wxml head/metrics | App/ClubOpsCustomerViews.swift:242-331,386-404 | Head → Section with avatar + name, system insets. Metric tiles (`.cyDomainCard`) → three `LabeledContent` rows (or `Grid` without card). Records-empty → `ContentUnavailableView`. | Claude App |
| CLB-r10-nat-customer-detail-02 | P2 | customer-detail/index.wxml:83-118 | App/ClubOpsCustomerViews.swift:491-560; App/ClubGovernanceViews.swift:780-785 | Implements CLB-customer-detail-04 natively: inline Form-style Section on the page. Tags as rows with `.onDelete`/swipe, add via TextField `.onSubmit` + `Button`, remark `TextField(axis: .vertical)`, 保存/取消 toolbar or Section buttons. Drop CYStatusChip/CYPillButton. | Claude App |
| CLB-r10-nat-customers-01 | P2 | customers/index.wxml:15-23 | App/ClubGovernanceViews.swift:699-726 | Capsule chip ScrollView → `Picker(.segmented)` (4 filters fit) or toolbar `Menu`. Hand-built search → `.searchable`. | Claude App |
| CLB-r10-nat-customers-02 | P2 | customers empty/row | App/ClubOpsCustomerViews.swift:3-55,109-125,189 | ClubOpsFailureSection and filtered-empty → `ContentUnavailableView` (`.search` for filtered). Row CYStatusChip → secondary Text. | Claude App |
| CLB-r10-nat-checkin-01 | P2 | checkin-detail/index.wxml | App/ClubCheckinRailView.swift:19-33,148-157,238 | Full-page states → `ContentUnavailableView`. Cover placeholder RoundedRectangle → omit or SF Symbol `photo`. CYStatusChip → Text/`Label`. | Claude App |
| CLB-r10-nat-checkin-02 | P2 | checkin-detail refund | App/ClubOwnerRefundPanel.swift:59-115 | CYSheetContainer → `NavigationStack { Form }` sheet. CYNoteBanner → section footer. Custom button styles → `.borderedProminent` with `role: .destructive`. UI only; refund dispatch stays money-gated. | Claude App |
| CLB-r10-nat-join-requests-01 | P2 | join-requests/index.wxml | App/ClubManagementView.swift:60-130,196-197,315-350 | Standard List rows (remove clear bg, hidden separators and custom insets). `.cyPressable` → NavigationLink/Button row. Row 拒绝/通过 → `.bordered`/`.borderedProminent` controlSize small (swipe stays). Empty/sign-in/offline → `ContentUnavailableView`. CYSkeleton → `ProgressView`. Drop the custom page bg. | Claude App |
| CLB-r10-nat-group-code-01 | P1 (dark hex card) | group-code club-game-code-sheet | App/DesignSystem/CYClubGameCodeCard.swift:19-63 | Remove the hex CYNight ink card and overlay stroke. Show the QR `Image` on white in a plain Section row, with the session name as Section header and ProgressView for generating. Retry → `Button`. | Claude App |
| CLB-r10-nat-group-code-02 | P2 | group-code/index.wxml | App/ClubGovernanceCommandForm.swift:277,292,322-328,398-404; App/ClubGroupCodePresentation.swift:50 | Generating RoundedRectangle → `ProgressView("生成中")`. 出示团码 / 重试 / 重新生成 → system `Button` rows / `.borderedProminent` (no clear row). | Claude App |
| CLB-r10-nat-group-code-03 | P2 | group-code/index.wxml:15-22 选择场次 | App/ClubKit/ClubGroupCodeSessionStep.swift:43-59; App/MPGap/Club/ClubGapRound4Views.swift:257-281 | CYSkeleton → `ProgressView`. CYEmptyState → `ContentUnavailableView`. Session rows Button + hand-drawn chevron → `NavigationLink`. Wire 进入俱乐部管理 (group-code-05). | Claude App |
| CLB-r10-nat-workbench-01 | P2 | workbench/index.wxml:9-15 | App/MPReviewedPageScreen.swift:1105-1125 | Entry CYSkeleton → `ProgressView`. On read failure use `ContentUnavailableView` 没能进入俱乐部管理 + 重试进入 / 返回俱乐部 (implements CLB-workbench-03). | Claude App |
| CLB-r10-nat-workbench-02 | P2 | detail manage tab | App/ClubKit/ClubWorkbenchKit.swift:36-90,150-205; App/ClubDetailTabBar.swift:24-45 | Workbench now-card/tiles RoundedRectangle cards → Section with `LabeledContent`/NavigationLink rows. Tab track → `Picker(.segmented)` (coordinate with the detail slice owner). | Claude App |
