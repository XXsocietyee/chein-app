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

Strings: `docs/port/strings/fix-r10-club-c.json` (3 keys: `club.story.openInMaps`, `club.detail.factPending` in `Resources/Localizable.xcstrings`; `clubOpsEvent.recurrence.topic` in `Resources/ClubOpsEvent.xcstrings`).
Tests: Tests/CoreTests/PublicContentShareLinkTests.swift (club + ticket universal links parse back), Tests/CoreTests/ClubStoryPresentationTests.swift (stop coordinates);
contract checks updated with MP citations: test_club_detail_tabs.py, test_community_media_integration.py, test_club_story_projection.py.

Gates at push: check_scaffold PASS structural checks; a11y lint PASS (0 new); contract_ratchet new 1 (`test_social_article_content…scoped_article_contents`), the same single new failure on the untouched base d9832ac50 — not from this lane.

## Hand-offs
1. Cursor Core: release/reconcile the governance journal lock after an acknowledged `saveTopicSettings` (topic-detail-06; also unblocks CLB-customer-detail-04 for club-d).
2. Cursor Core: expose the broadcast blocker on `PlayDirectorProjection` (topic-detail-10).
3. `ClubCommunityEntry` (App/ClubCommunityViews.swift:273) is no longer mounted on the club page; delete it once no other caller needs it.
