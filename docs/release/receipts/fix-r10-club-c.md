# fix-r10 · club-c receipt (2026-11-26)

Slice: `docs/audit/parity-r10/club.md` §3a, P1 rows, first half in queue order (12 rows: CLB-detail-09 … CLB-topic-story-04).
Base: `origin/ui/combined-r7` (d9832ac50). Branch: `fix/r10-club-c`. No compiler in the cloud: every type and member was grepped before use.

**Note on the audit:** 7 of the 12 rows were already closed on the base by `fix/r9-club-a` (receipt `fix-r9-club-a.md`). The r10 audit read the
dead `ClubGapManagedProjectsDirectorSection` (App/MPGap/Club/ClubGapRound4Views.swift) instead of the mounted `ClubManagedProjectsSection`.
They were re-checked on the tip and are listed as fixed with the original SHA.

| id | sev | status | SHA | app file:line |
|---|---|---|---|---|
| CLB-detail-09 | P1 | fixed (r9, verified on tip) | 892f6d4d3 | App/ClubManagedProjectsSection.swift:79-257 (cover, `timeText · N 人报名` / 还没有场次, row → topic, redacted loading, 重新加载, 暂无分配给你的项目, no cap); mounted App/ClubDetailView.swift:129 |
| CLB-r7-A-04 | P1 | fixed (r9, verified on tip) | 892f6d4d3 | App/ClubManagedProjectsSection.swift:325-352 (one session → open, several → 选择场次, none → footer notice, `permissions.tools`) |
| CLB-G06 | P1 | fixed (r9, verified on tip) | 76c7de342 / a25c7e159 | App/ClubDetailView.swift (toolbar gear `showsSettings`; 设置 via `ClubManageQuickActions(onSettings:)`) |
| CLB-detail-30 | P1 | fixed | ce3bb93c0 | Core/PublicContentShareLink.swift (`club`, `clubTicket`, `reviewedPage`); Core/NativeNavigationCompletion.swift:49-55; App/ClubMPAssetViews.swift:10-14; App/ClubEditionsShareSection.swift:78-85. Absorbs CLB-r10-detail-03. https universal link first (`www.chengyinhub.com`, read back by the existing parser), `chein://mp` fallback. |
| CLB-detail-14 | P1 | fixed | d0d2aa7a3 | App/ClubDetailView.swift:110-113 (`postsFeed`), `pageHeader` helper; App/ClubCommunityViews.swift (`leading:` sections, no pushed title when inline). Chat/IM/channel rows were already moved to 概览 in 0bcd0607d. |
| CLB-detail-35 | P1 | fixed (r9, verified on tip) | 6936b9f64 / a25c7e159 | App/ClubDetailView.swift (`groupCodeQuickAction`, `groupCodeCardAction`), App/ClubPublicActivityListView.swift. The issue write itself dispatches only once club-b lands CLB-r10-gate-05. |
| CLB-detail-34 | P1 | fixed (r9, verified on tip) | 666d94a69 | App/ClubHomeView.swift:134, 179 (actionCoordinator, management, community passed) |
| CLB-G13b | P1 | fixed (r9, verified on tip) | 9c917c011 | App/ClubGovernanceViews.swift:2113 (`directorActive` = director mounted), 结束活动 confirm + 更多 row. endTopic dispatch follows the money gate. |
| CLB-G13c | P1 | fixed (r9, verified on tip) | 5a2c5bee1 | App/ClubTopicDirectorMount.swift:124-150 (准备总览 only while preparing, 联系商家 on `merchantHoldBlocked`) |
| CLB-topic-detail-06 | P1 | blocked (Cursor Core) | — | Round 2: (1) CLB-r10-gate-05 has landed (club-b 193356907, `saveTopicSettings` in `ClubMPFirstGovernance.clubOps`). Still blocked on (2) `ClubGovernanceCoordinator.confirm` (Core/ClubGovernanceCoordinator.swift:171-221) to release or reconcile the journal lock after an acknowledged save; today a second toggle is refused as `outcomeLocked`. Not changed here: an uncompiled edit to the write journal is too risky. The sheet editor (App/ClubTopicSettingsReturn.swift) still works. |
| CLB-topic-detail-10 | P1 | partly | ea3f91375, 208903166 | App/ClubGovernanceViews.swift:1980-1996: the 定向广播 row stays visible (disabled) and the reason sits in the Section footer (MP wxml:621-624). Open: the NO_RECIPIENT sentence needs the director wire key for the broadcast blocker on `PlayDirectorProjection` (Core/PlayDirectorRuntime.swift:4); the MP source was not available in this run to confirm the key. |
| CLB-topic-story-04 | P1 | fixed | 87eb12b52, 701d5097e | Core/ClubStoryPresentation.swift (`ClubStoryStop.latitude/longitude`); App/ClubStoryViews.swift:213-215; App/MPGap/Club/ClubGapRound4Views.swift:135 (`club.story.openInMaps`) |

## Round 2: club.md §3a P2, first half in queue order (16 rows: CLB-r9-gate-04 … CLB-r9-native-05)

Each row was checked against the other lanes' receipts and re-verified on the tip (every r9 SHA below is an ancestor of HEAD).

| id | sev | status | SHA | app file:line |
|---|---|---|---|---|
| CLB-r9-gate-04 | P2 | fixed (other lane) | 097702ffb (acct-a receipt) | acct-a owns it: post/comment originals stay nil, MP post/comment paths are already in `clubCommunityPaths`. Not touched here. |
| CLB-detail-42 | P2 | fixed | 3ab7e881a | Core/ClubDetailTabs.swift:80-91 (`ClubDetailHeaderFact`, dead `ClubDetailOverviewFactsGrid` removed again); App/ClubDetailView.swift:709-714, 772-783 (`factsLine`: missing 主理人 / 城市 → `club.detail.factPending` 待补充); Tests/CoreTests/ClubDetailPageReadyTests.swift:32; Tests/ContractChecks/test_club_detail_page_ready.py:70-76 (pin moved to the key + live caller, MP citation). acct-a's 097702ffb deletion is not on any branch, so it was redone. |
| CLB-r9-detail-01 | P2 | fixed | b698382a1, 1b7c983ef | App/ClubDetailR8Mounts.swift (`ClubDetailStripMemberOpen`: owner/admin get the 公开资料 / 客户档案 `.confirmationDialog`, same strings as the contribution board, MP `goMemberProfile` js:2529-2534); App/ClubDetailView.swift:251, 452, 567-576. |
| CLB-r9-detail-03 | P2 | fixed (r9, verified on tip) | 0589d6682 | App/MPGap/Club/ClubGapManageExtensions.swift (settings rows → catalog keys) |
| CLB-r7-A-07 | P2 | fixed (r9, verified on tip) | cef838d90 | App/ClubMembersView.swift (`loadGovernGrant`: co-owner with club:member:manage) |
| CLB-r9-native-07 | P2 | fixed (r9, verified on tip) | 9bb9fff7c | App/MPGap/Club/ClubGapManageExtensions.swift, ClubGapRound4Views.swift (`common.close` / `common.cancel`) |
| CLB-G13d | P2 | fixed (r9, verified on tip) | 7eba5ec4f | App/ClubTopicDirectorMount.swift (`ClubTopicDirectorToolsSection`) |
| CLB-topic-detail-05 | P2 | fixed (r9, verified on tip) | 70cccab93 | App/ClubTopicDetail+Port.swift (台账), App/ClubGovernanceViews.swift (更多 rows) |
| CLB-r9-topic-detail-01 | P2 | fixed (r9, verified on tip) | b92b696e6 | App/ClubTopicMerchantContent.swift:48-56 (`club.topicMerchants.phoneCopied`) |
| CLB-r9-topic-detail-02 | P2 | fixed (r9, verified on tip) | ed97d12fe | App/ClubGovernanceViews.swift (one 更多) |
| CLB-topic-story-06 | P2 | fixed (r9, verified on tip) | b4d7d7052 | App/ClubGovernanceViews.swift:2394 (`club.story.noRoute`) |
| CLB-r9-topic-story-01 | P2 | fixed (r9, verified on tip) | 333115610 | App/MPReviewedPageScreen.swift:379-400 |
| CLB-r9-event-ops-01 | P2 | partly | 0f7ad2d13 | App/ClubOpsEventView.swift (`topicFacts` from the hub's eventTopics read, `topicPicker` Picker(.menu) above 添加日期 when >1 topic; the push opens with the picked topic first via `focusFirst`). Open: the series form still opens from the pushed topic list, because `seriesCreationReturn` lives in ClubGovernanceReadView; opening it straight from the hub needs that return source moved. |
| CLB-event-ops-05 | P2 | fixed (r9, verified on tip) | 96e188c2e | App/ClubOpsEventView.swift:47-61 |
| CLB-r9-native-02 | P2 | fixed (r9, verified on tip) | 269b8dac0 | App/MPGap/Club/ClubGapTopicDirectorViews.swift |
| CLB-r9-native-05 | P2 | fixed (r9, verified on tip) | 6baff7f92 | App/ClubStoryViews.swift, App/MPGap/Club/ClubGapRound4Views.swift |

### Round 2, continued

The queue spans §3a and §3b (club-d's P1 half included native rows; its P2 native slice starts at CLB-r10-nat-topic-detail-06).
So this lane's P2 half is all 32 §3a rows plus §3b CLB-r10-nat-detail-01 … nat-topic-detail-05. club-b's round 2 already
took §3a rows apply-01/02, roles-01, join-requests-01 and create-01 (receipt `fix-r10-club-b.md`); they are not redone here.

| id | sev | status | SHA | app file:line |
|---|---|---|---|---|
| CLB-r8-governance-01 | P2 | fixed | 00aab0078 | Core/MiniProgramPageLink.swift:79-82 (`clubId` no longer required); the screen's `.missingClub` → `MemberMissingLinkState` (App/MPReviewedPageScreen.swift:423) is now reachable. Tests: MiniProgramPageLinkTests (accepted `[:]`), MPParityDeepLinkRouteTests. |
| CLB-r9-create-01 | P2 | fixed (r9, verified on tip) | b4f4c4227 | App/ClubOperationsViews.swift (正在确认创建资格) |
| CLB-r9-create-02 | P2 | fixed | 4f90bc64b | App/ClubCreateHostApplicationLink.swift (`ClubCreateHostAutoOpen`: one push of the host-status read per visit, MP create js:114-118 redirect); App/ClubOperationsViews.swift (`hostAutoOpenActive`, modifier after `.interactiveDismissDisabled`). UI example Tests/AppUITests/ClubCreateHostApplicationFlowTests.swift updated (back from the auto-opened page, then 前往申请). |
| CLB-r9-create-03 | P2 | fixed (r9, verified on tip) | 69a8b248d | App/ClubOperationsViews.swift (「n / 4」) |
| CLB-r9-create-04 | P2 | blocked (owner) | — | HANDOFF-R1 MC-10 chose the city picker; the MP typed field reverses an owner decision. |
| CLB-enroll-08 | P2 | fixed (r9, verified on tip) | 42450ede4 | App/MPReviewedPageScreen.swift (ClubFirstOwnedEntry) |
| CLB-r9-enroll-01 | P2 | fixed (r9, verified on tip) | aa40ec35d | App/ClubEnrollmentView.swift |
| CLB-r9-edit-01 | P2 | fixed (r9, verified on tip) | 34fe2a021 | App/MPReviewedPageScreen.swift:327-329 |
| CLB-r8-badges-02 | P2 | fixed (r9, verified on tip) | 7f9b218c1 | App/ClubBadgeManagementView.swift |
| CLB-workbench-03 | P2 | fixed (r9, verified on tip) | 42450ede4 | App/MPReviewedPageScreen.swift (ClubSingleOwnedEntry .failed) |
| CLB-r9-payout-receiver-02 | P2 | fixed (r9, verified on tip) | f95ea5f56 | App/ClubPayoutReceiverView.swift |
| CLB-r10-apply-01, -apply-02, -roles-01, -join-requests-01, -create-01 | P2 | club-b | — | See `fix-r10-club-b.md` round 2. |
| CLB-r10-nat-detail-01 | P2 | fixed (pre-existing) | b47382ab8, d0d2aa7a3 | App/ClubCommunityViews.swift:330-431 (List sections, `.refreshable`, ProgressView/ContentUnavailableView; feed inline on 帖文) |
| CLB-r10-nat-detail-02 | P2 | fixed (pre-existing) | b47382ab8 | App/ClubCommunityViews.swift:908-960 (Form, limit in the footer, toolbar cancel/confirm) |
| CLB-r10-nat-detail-03 | P2 | fixed (pre-existing) | b47382ab8 | App/ClubCommunityViews.swift (post detail / comments / history are Lists with `.refreshable`) |
| CLB-r10-nat-detail-04 | P2 | fixed (pre-existing) | b47382ab8 | App/ClubCommunityViews.swift:1038-1110 (List sections, system confirm button, toolbar cancel). `cyDomainSheet` kept (role-themed sheet; theme work paused). |
| CLB-r10-nat-detail-05 | P2 | fixed (pre-existing) | b47382ab8 | App/ClubDetailTabBar.swift (system segmented Picker, menu at AX sizes, no ScrollView) |
| CLB-r10-nat-detail-06 | P2 | partly | ec4301e16 | App/ClubDetailView.swift:707, 740 (logo `@ScaledMetric`, no stroke). Held: `.tint(CYDomainPalette…)` and `cyPushedChrome` (CDV:502-503) are the domain theme; owner paused theme changes. |
| CLB-r10-nat-detail-07 | P2 | fixed (pre-existing) | 0bcd0607d | App/ClubDetailView.swift (no CYListRow / CYRowIcon / CYEmptyState / CYStatusChip left) |
| CLB-r10-nat-detail-08 | P2 | partly | ca477e884 | App/ClubActionPanel.swift:172 (page-end row uses the system cell), App/ClubKit/ClubMemberActionKit.swift (drawn grouped plate removed). Leave was already `role: .destructive`, confirm a `.confirmationDialog`. Open: join help/validation still sit as rows, not in the footer (the Section's header carries the F-08 lifecycle pinned by test_acceptance_r2_club_chat). |
| CLB-r10-nat-detail-09 | P2 | fixed | 34c79a0fd | App/ClubPublicActivityListView.swift:56 (出示团码 `.bordered` `.small`); plate, hero, banner, skeleton already gone. |
| CLB-r10-nat-detail-10 | P2 | fixed (pre-existing) | 892f6d4d3 | App/ClubDetailR8Mounts.swift:398-417, 495 (ProgressView, ContentUnavailableView, `.confirmationDialog` 公开主页 / 客户详情) |
| CLB-r10-nat-detail-11 | P2 | fixed (pre-existing) | 892f6d4d3 | App/ClubMembersView.swift (no CYSheetHeader / CYOptionSheet / CYEmptyState left) |
| CLB-r10-nat-detail-12 | P2 | fixed | ee1c2fc80 | App/MPGap/Club/ClubGapRound4Views.swift (`dateRow`: DatePicker, 未设置 → today); Core/MPGap/Club/ClubGapRound4.swift (`FEReferenceRangeFilter.date/text`, YYYY-MM-DD Asia/Shanghai). Pills were already `.bordered`. |
| CLB-r10-nat-detail-13 | P2 | fixed (pre-existing) | 35852c11d | App/MPGap/Club/ClubGapManageExtensions.swift:48-70 (apply field in a Form, toolbar actions, no CY empty/chip/pill) |
| CLB-r10-nat-detail-14 | P2 | fixed (pre-existing) | 35852c11d | App/MPGap/Club/ClubGapRemainingViews.swift:137-142 (`.bordered` / `.borderedProminent`); App/ClubEditionsShareSection.swift:62-67 (ShareLink `.bordered`) |
| CLB-r10-nat-topic-detail-01 | P2 | fixed | 1ae8bd9d8 | App/ClubTopicDetail+Port.swift (three `LabeledContent` rows, `.monospacedDigit()`) |
| CLB-r10-nat-topic-detail-02 | P2 | fixed (pre-existing) | bfea7b414 | App/ClubTopicDetailRows.swift:103-135 (system `.bordered` action buttons, no circles) |
| CLB-r10-nat-topic-detail-03 | P2 | fixed | 6af4ebda6 | App/ClubGovernanceViews.swift:2031-2045 (`.borderedProminent` primary in the safe-area inset on `.bar`; Divider overlay dropped) |
| CLB-r10-nat-topic-detail-04 | P2 | partly | 892f6d4d3 | App/ClubGovernanceViews.swift: system list background (no scrollContentBackground / cyDomainPageBackground / cyGroupedSurface). Held: `cyDomainSheet` (:92, :807, :1752) is the role-themed presentation; theme work paused. |
| CLB-r10-nat-topic-detail-05 | P2 | fixed (pre-existing) | bfea7b414 | App/ClubTopicDetailRows.swift:67-90 (plain coloured status text, no chip) |

Strings: `docs/port/strings/fix-r10-club-c.json` (3 keys: `club.story.openInMaps`, `club.detail.factPending` in `Resources/Localizable.xcstrings`; `clubOpsEvent.recurrence.topic` in `Resources/ClubOpsEvent.xcstrings`).
Tests: Tests/CoreTests/PublicContentShareLinkTests.swift (club + ticket universal links parse back), Tests/CoreTests/ClubStoryPresentationTests.swift (stop coordinates);
contract checks updated with MP citations: test_club_detail_tabs.py, test_community_media_integration.py, test_club_story_projection.py.

Gates at push (round 1): check_scaffold PASS structural checks; a11y lint PASS (0 new); contract_ratchet new 1 (`test_social_article_content…scoped_article_contents`), the same single new failure on the untouched base d9832ac50 — not from this lane.

Gates at push (round 2, after merging `origin/ui/combined-r7` @ 05caead53): check_scaffold PASS structural checks; a11y lint PASS (0 new); contract_ratchet `192 failing, baseline 192, new 0`. Not compiled (no Xcode in the cloud).

## Hand-offs
1. Cursor Core: release/reconcile the governance journal lock after an acknowledged `saveTopicSettings` (topic-detail-06; also unblocks CLB-customer-detail-04 for club-d).
2. Cursor Core: expose the broadcast blocker on `PlayDirectorProjection` (topic-detail-10).
3. `ClubCommunityEntry` (App/ClubCommunityViews.swift:273) is no longer mounted on the club page; delete it once no other caller needs it.
4. Coordinator: build-check `ClubDetailStripMemberOpen` (App/ClubDetailR8Mounts.swift), `ClubCreateHostAutoOpen` (`.onChange(of:initial:)` + `navigationDestination(isPresented:)`) and `dateRow` in ClubGapRound4Views.
5. Owner: CLB-r9-create-04 (typed 城市 vs MC-10 picker) and the held theme parts of nat-detail-06 / nat-topic-detail-04.
