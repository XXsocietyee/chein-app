# Receipt: fix/r9-player-content (Claude App rows)

Source: `origin/audit/parity-r9-player-content:docs/audit/parity-r9/player-content.md` and, from round 3, `origin/audit/parity-r10-player-content:docs/audit/parity-r10/player-content-groups/{B-topic,C-activity,D-subpackages}.md` (rows owned by Claude App).
Round 3 native rule: `origin/design/handoff-r2:docs/briefs/native-r2.md` (Apple components only).
Base: merged `origin/ui/combined-r7` up to `2446657fb` (native-r2 tokens 82bcf2c2d and the native-r2 sweeps).
Gate: `python3 tools/check_scaffold.py` → `PASS structural checks` at every commit. No compiler in the cloud: Swift build, XCUITest, VoiceOver: NOT_RUN.
Strings: `Resources/Localizable.xcstrings` + `docs/port/strings/fix-r9-player-content.json`.

## P0

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R7-PC-B3-2 | fixed | 8ee92d70d | App/MPGap/PlayerContent/PlayerContentRound4Views.swift | map picker pins a real tap/search point; 保存 disabled until chosen |

## P1

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R7-PC-A1-3 | fixed | 218f41033 | App/HomeFeedView.swift | slides show club/status/category; stream cards show feedTags (≤2) |
| R7-PC-A3-2 | fixed | 95b32bc16 | App/GlobalSearchView.swift | empty submit toast; kept beside the tip's PC-A-3-3 prompt at the merge |
| R7-PC-A3-3 | fixed | bb343b6ca, a41e7b7d3 | App/SearchMapFilterSheet.swift (dates section) | Toggle + inline compact `DatePicker` per bound; nested wheel sheet removed; `tools/check_search_map_date_picker.py` and `test_search_map_date_presets.py` re-pinned |
| R7-PC-A4-1 | fixed | c5978f778 | App/SocialRoamMounts.swift (`UnifiedSearchEntry`); App/GlobalSearchView.swift (`showsRow`, `unifiedKeywordOnly`) | bare keyword + signed in: `/api/search/unified` rows inline, topic/activity lanes hide while shown; post rows open `pages/square/detail/index` |
| R7-PC-A5-2 | open | — | App/SearchMapExplorerView.swift | map-first explorer + auto-locate not started this round |
| R7-PC-A5-3 | fixed | 41b9b9c4d | App/SearchMapFilterSheet.swift | 最近 only |
| R7-PC-A8-1b | blocked | — | App/DiscoveryTemplateDetailView.swift | waits on Cursor Core A8-1a |
| R7-PC-B1-5 | fixed | 0ab79f407 | App/TopicDetailView.swift | 开始游玩 opens the play runtime |
| R7-PC-B1-6 | fixed | 002dfb536 | App/TopicXcxSections.swift | route progress from `/api/play/nodes` (bought only) |
| R7-PC-B1-7 | fixed | ef6471025 | App/ContextualReviewComposer.swift | ≤9 photo row → `img_arr` |
| R7-PC-B1-12 | fixed | 858262b40 | App/SessionTopicSelfPlayView.swift | pass reveal after a completed order |
| R7-PC-B3-3 | fixed | 062388650 | App/MerchantContentEditor.swift (`applyShopSection`, `applySuccessSection`); App/MPGap/PlayerContent/PlayerContentRound2Views.swift (`MerchantApplySuccessSummaryView`, `MerchantApplyShop`) | 你的门店 Section from `/api/merchant/info` (cover, hours, name, address → Maps); after create/save the form becomes the success summary (报名已提交 / 修改已保存, route lines, 查看承接进度 → merchantinfo project; 返回商家首页 after an edit only) |
| R9-PC-B3-1 | fixed | 1a64faf06 | App/MerchantContentEditor.swift | photos upload and append to `picUrl` |
| R7-PC-B4-3 | partly | 36c849a9f | App/PublisherLifecycleViews.swift (`loadPricingExtra`, `TopicPricingGapSection` mount) | 开售状态 + 结算待处理 shown (read only). Per-ticket prices need Core to decode preview `tickets` and the pricing grant (R7-PC-B4-1, Cursor Core) |
| R9-PC-C1-2 | fixed | 579750de3 | App/ActivityDetailView.swift | host sees disabled 取消活动并退款 while refunds are off (money stays TEST-only) |
| R7-PC-C2-1 | blocked | — | App/RegistrationSheetView.swift | needs Cursor Core: ticket `childCount/childAgeMin/childAgeMax`, quote `delivery` rows and `mkt.coveredByPass`, `childAge` in quote/create, activity `merchantClosed` (MP baoming.js:760-764, 1463, 1871) |
| R9-PC-C2-1 | fixed | 4478e3472 | App/RegistrationSheetView.swift | 主持预约 section |
| R7-PC-C1-6 | fixed (picker) | ef6471025 | App/ContextualReviewComposer.swift | Core cap/`img_arr` half is Cursor's |
| R7-PC-D1-4 | fixed | 7d71f2209 | App/CreatorContentViews.swift (body); App/TemplateAuthoringMineView.swift (`embeddedHeader`, `TemplateMineChrome`); App/MyProjectTabViews.swift | 模板 tab shows the own-shelf rows and their ⋯ actions in place under the segmented picker; the shelf's forced dark scheme is gone |
| R10-PC-C6-2 | fixed | 695cd746c | App/OfficialPrivateViews.swift (`OfficialBroadcastInlineStatsRow`); App/GlobalSearchLinksAndTemplates.swift (`PlayerContentOfficialReader.recoverBroadcast`) | 安全恢复原投递 `.bordered` button → confirmationDialog → one POST `/api/official/broadcast/{id}/recover` (Core `PlayerContentMPContract.broadcastRecover`), refusal inline, stats re-read |
| R10-PC-D-N13 | fixed | b8e2c23a8 | App/VideoBountyView.swift (`VideoBountyAppealSheet`) | Form + section footer validation; no CYNight ink |

## P2

| id | status | SHA | app file:line | note |
|---|---|---|---|---|
| R9-PC-B3-2 | fixed | 1ca7768fe | App/MPGap/PlayerContent/PlayerContentRound4Views.swift | `showsSubmit` |
| R7-PC-A3-5 | fixed | ee11fd38a | Resources/Localizable.xcstrings; docs/search-map-localizations.json | 类别加载失败 / 在地图上找 / 搜索主题、活动、俱乐部、商家 |
| R7-PC-A4-4 | fixed | a57e659e2 | same catalogs | 没有更多了 / 重新搜索 |
| R8-PC-A7-1 | fixed | 988a73d50 | Resources/Localizable.xcstrings | 5 keys + nodes/oneGame/miniGames/medal; about/firstAbout/chapterNames keep the Chinese fallback (args already Chinese or variadic) |
| R9-PC-A-N1 | fixed | 1b14f0207 | App/DiscoveryTemplateBrowserView.swift (`bellSide`); App/MPGap/PlayerContent/TopicTemplateDeckPreviewView.swift (`checkIconSide`, `clockIconSide`) | `@ScaledMetric` |
| R9-PC-BN-3 | fixed | e6e9e8f5e | App/ContextualReviewComposer.swift (`starSide`) | `@ScaledMetric` |
| R9-PC-CN-3 | fixed | e6e9e8f5e | App/ActivityPeopleSection.swift (`PeopleMark.side`) + star above | `@ScaledMetric` |
| R9-PC-BN-4 | fixed | a1824d03d | App/TopicDetailView.swift (topic.comments section) | empty-review card is a `Button`; 写评价 is a system `.bordered` button |
| R9-PC-BN-5 | no change needed | — | App/PlatformConsumerSessionOwner.swift | the signed-out gate is gone on the tip (guests read the detail; sign-in on action) |
| R9-PC-CN-1 | fixed | a22c8c50d | App/ActivityDetailView.swift (failed phase) | `ContentUnavailableView` + 重试 / 返回 |
| R9-PC-CN-2 | fixed | 0aef2aedf | App/OfficialEventComponents.swift (`OfficialIssueView`) | `ContentUnavailableView` (label, description, action) |
| R7-PC-C3-3 | fixed | 0d781059d | Resources/Localizable.xcstrings `official.bucket.upcoming` | 即将上线 |
| R9-PC-C3-1 | fixed | 4c6684d08 | `official.bucket.mine` | 我的 |
| R7-PC-C4-5 | fixed | b3c239088 | `official.detail` | 活动详情 |
| R9-PC-C4-1 | fixed | ec64ed4ef | App/OfficialEventDetailView.swift | leaderboard after 我的活动任务; `official.leaderboard.provisional/.final` |
| R9-PC-C6-1 | fixed | 1f06c015d | App/OfficialPrivateViews.swift | 还没发过通知 only |
| R9-PC-D7-1 | fixed | 9e02e49a6 | App/VideoBountyView.swift (body, `form`) | inset-grouped List; platform Picker + TextFields in a Section; footer validation; per-chip ids become `videoBounty.platform` / `videoBounty.tab` |
| R9-PC-D9-2 | fixed | d87b7f6ec | App/CommunityMemberReportSheet.swift (body, `content`, `form`, `result`) | Form; counter in footer; 提交 in toolbar; ContentUnavailableView for load-failed and results |
| R7-PC-B1-13 | partly | 4cc1461c6 | App/TopicDetailView.swift (`sessionPreferName`); App/TopicSessionSelectionView.swift (`preferredTicketName`) | the picker marks the tapped ticket; the activity hand-off takes only an activity id, so the ticket is not preselected on the activity page yet |
| R7-PC-A5-6 | fixed | 8691792a4 | App/SearchMapExplorerView.swift (`offlineBanner`, `retryConnection`) | `SearchMapOfflineBannerView` from `SearchMapConnectivity`; reconnect refreshes once; the offline-example caption stays for example data |
| R9-PC-C1-1 | fixed | c22e01bc5 | App/ActivityDetailView.swift (`showsOwnOrders`); App/MPGap/PlayerContent/PlayerContentRound2Views.swift (`ActivityCancelledStateView`) | pushes 我的订单 (`SubscribeMessageTapEntry(.playerOrderList)`); one CTA 返回活动列表 otherwise |
| R10-PC-B-N9/N10/N11 | partly | b1e2db839 | App/MerchantContentViews.swift | CYSkeleton → ProgressView, CYEmptyState → ContentUnavailableView, CYConfirmSheet → confirmationDialog, review confirm → .borderedProminent. ScrollView/LazyVStack page body and `MerchantContentRowLinkStyle` still open |
| R10-PC-B-N12 | fixed | 81e15fa3d | App/MPGap/PlayerContent/PlayerContentRound4Views.swift | photo rows with swipe-to-delete; @ScaledMetric thumbnail, no corner clip |
| R9-PC-D7-2 | fixed | 188bb4a39 | App/VideoBountyView.swift; App/DesignFixtures/CurFixtures3/5.swift | attribution sheet, state and callbacks removed (session loaders left in place) |
| R9-PC-D5-1 | fixed | 7c2ae8e91, 50983036e | App/WalletCommerceViews.swift (`WalletWithdrawPermissionGate`); App/QuestifyApp.swift (`walletWithdrawPermission`) | role/info `permission.withdrawable` false → 暂无提现权限; true or unreadable → CS contact view |
| R9-PC-D1-1 | fixed | a38979df5 | App/PublishingModesViews.swift (`makeProjects`); App/PublishRootContent.swift; App/SessionPublishingModesView.swift | post-publish 我的项目 opens `SessionCreatorProjectsView`; `PublishingProjectsView` stays only as fallback (not retired yet) |
| R7-PC-D2-4 | fixed | 243d3223a | App/SocialGuideViews.swift | doc detail in a `.sheet` (medium/large) with 完成 |
| r10 rows already fixed on this branch | fixed | — | — | R7-PC-B1-5/6/7/12, R9-PC-C1-2, R9-PC-C2-1, R9-PC-C1-1, R9-PC-C3/C4/C6 copy, R9-PC-D7-1, R9-PC-D9-2 (r10 audited the tip before this branch merged) |
| other P2 rows | open | — | — | A1-1, A1-7, A2-6, A3-4, A4-3, B2-5, R8-B6-1, C4-4, D9-1, D4-1, D3-1; r10 native rows B-N1…N8, B-N13/N14 (tip already native for pricing), C-N1…N18, D-N1…N12, D-N14…N20 |

## Merge notes
- `98585f77c`: `App/GlobalSearchView.swift` kept both empty-search prompts (`emptySearchToast` R7-PC-A3-2 and the tip's `emptySearchNotice` PC-A-3-3).
- `98585f77c`, `a4650453b`: `Localizable.xcstrings` key union (tip order, ours on overlap, appended).
- Pre-existing contract-test failures (same before and after these commits): `test_category_roam_registration`, `test_global_search_category_recovery`, `test_search_map_contracts` byte pins; `test_official_event_contracts` (2); `tools/check_contextual_flows.py`.

## Round 3 (2026-11-26)
- `b9047b2e1` merged `origin/ui/combined-r7` (native-r2 tip): tip's native components and flows kept in all 9 conflicts; r9 behaviour kept (HomeFeed 编辑精选 caption as secondary text, inline unified search rows, offline bar, 最近-only sort). CYGlassCarousel club/chips additions dropped; leftover CYColor uses in r9 additions → system styles.
- `1a3548a98` contract pins: en for `official.detail` / `official.bucket.upcoming` restored (only zh was in scope); release string specs and search-map fragment synced to the catalog; topic review/session pins follow BN-4 / B1-13.
- Contract suite (per-file unittest) vs `origin/ui/combined-r7`: only remaining extra failure is `test_global_search_category_recovery` (feature-batch byte pin on App/SearchMapFilterSheet.swift from A3-3), pre-existing on this branch.
- Still blocked on Cursor Core: R7-PC-B4-3 per-ticket prices, R7-PC-C2-1, R7-PC-A8-1b.
