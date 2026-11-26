# Receipt: fix/r9-player-content (Claude App rows)

Source: `origin/audit/parity-r9-player-content:docs/audit/parity-r9/player-content.md` (rows owned by Claude App).
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
| R7-PC-B3-3 | open | — | App/MerchantContentEditor.swift | shop card + success view not started |
| R9-PC-B3-1 | fixed | 1a64faf06 | App/MerchantContentEditor.swift | photos upload and append to `picUrl` |
| R7-PC-B4-3 | partly | 36c849a9f | App/PublisherLifecycleViews.swift (`loadPricingExtra`, `TopicPricingGapSection` mount) | 开售状态 + 结算待处理 shown (read only). Per-ticket prices need Core to decode preview `tickets` and the pricing grant (R7-PC-B4-1, Cursor Core) |
| R9-PC-C1-2 | fixed | 579750de3 | App/ActivityDetailView.swift | host sees disabled 取消活动并退款 while refunds are off (money stays TEST-only) |
| R7-PC-C2-1 | blocked | — | App/RegistrationSheetView.swift | needs Cursor Core: ticket `childCount/childAgeMin/childAgeMax`, quote `delivery` rows and `mkt.coveredByPass`, `childAge` in quote/create, activity `merchantClosed` (MP baoming.js:760-764, 1463, 1871) |
| R9-PC-C2-1 | fixed | 4478e3472 | App/RegistrationSheetView.swift | 主持预约 section |
| R7-PC-C1-6 | fixed (picker) | ef6471025 | App/ContextualReviewComposer.swift | Core cap/`img_arr` half is Cursor's |
| R7-PC-D1-4 | open | — | App/MyProjectTabViews.swift | not started |

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
| other P2 rows | open | — | — | A1-1, A1-7, A2-6, A3-4, A4-3, A5-6, B1-13, B2-5, R8-B6-1, C1-1, C4-4, C5-2, D9-1, D4-1, D5-1, D1-1, D3-1, D2-4, D9-2, D7-1 |

## Merge notes
- `98585f77c`: `App/GlobalSearchView.swift` kept both empty-search prompts (`emptySearchToast` R7-PC-A3-2 and the tip's `emptySearchNotice` PC-A-3-3).
- `98585f77c`, `a4650453b`: `Localizable.xcstrings` key union (tip order, ours on overlap, appended).
- Pre-existing contract-test failures (same before and after these commits): `test_category_roam_registration`, `test_global_search_category_recovery`, `test_search_map_contracts` byte pins; `test_official_event_contracts` (2); `tools/check_contextual_flows.py`.
