# Receipt: fix-parity-player-content (parity r1)

- Branch: `fix/parity-player-content`, cut from `origin/ui/combined-r4` at `0443305c8` (base unchanged at last fetch).
- Brief: `docs/briefs/fix-parity-r1.md` (design/handoff-r2). Findings: `docs/audit/parity/player-content.md` (audit/parity-player-content).
- Swift is not installed in the cloud: nothing here was compiled or run. Every row's "verify" column is the local step.
- Gates on the last commit: `tools/check_scaffold.py` PASS, `tools/check_design_lint.py` PASS (typography: hidden back 15 → 14,
  every other count unchanged), `tools/contract_ratchet.py --check`: no new failures against the base run
  (the base itself reports 11 failures not in its baseline; this branch adds none). Contract checks touching the changed files were
  re-run one by one (`python3 -m unittest …` in `Tests/ContractChecks`).

## What changed, in one paragraph

首页 now asks for the same activity/topic lists as the MP. MP links for 12 pages land on the named screen with their query
instead of the template shelf, 我的资产 or a "not available" page. Topic owner rows are shown only to the owner and only when their
grant is issued. Registration ends on 报名成功 + 查看订单 instead of engineering output. Official signup waits for the 安全须知
checkbox when the event has one. Global search finds 主题模板 and 玩法模板. 我的项目 offers 取消主题并退款 through the existing
cancel-with-refund-preview flow (refund write still behind its grant). The merchant content editor uses the one exit guard.

## Byte-pinned files (read before touching search)

`Core/SearchMapContracts.swift`, `Core/SearchMapReading.swift`, `Core/SearchMapService.swift` and `App/SessionGlobalSearchView.swift`
are SHA-256 pinned by `Tests/ContractChecks/test_global_search_category_recovery.py`. They are unchanged. The template lanes and the
MP search-link host live in the new `App/GlobalSearchLinksAndTemplates.swift` (registered by `tools/generate_project.py`; only
`project.pbxproj` changed, test plans untouched). `TopicLikeOperationFactory` is pinned as unwired by `test_bk_backend_sync.py`, so the
topic 收藏 write was built and then removed (see PC-B-1-2).

## Shared DesignSystem changes

None.

## P0

| id | status | files | verify (local) |
|---|---|---|---|
| PC-A-1-1 | fixed | `Core/HomeFeedService.swift`, `Core/HomeFeedContracts.swift`, `Tests/CoreTests/HomeFeedTests.swift` | Unit: `HomeFeedTests`. Proxy a TEST account on 首页: 活动 stream form has `status=1 sort_type=1 pageSize=20`; 即将上线 `is_my=2 status=2 sort_type=2 pageSize=4`; 附近活动 `pageSize=4` |
| PC-A-4-1 | fixed | `App/GlobalSearchLinksAndTemplates.swift` (new), `App/GlobalSearchView.swift`, `App/SearchMapComponents.swift`, `App/SessionHomeFeedView.swift`, `docs/search-map-localizations.json`, xcstrings | 首页 → search "城": under 全部 a 模板 section lists matching 主题模板 (name/subtitle) and 玩法模板 (`api/template/list keyword`); tap opens the template preview / 玩法详情; a `previewOnly` row is disabled with 暂未开放. Kind chips and counts unchanged |
| PC-A-7-1 | fixed | `App/MPReviewedPageScreen.swift`, `Core/MiniProgramPageLink.swift` | `chein://mp/pages/templatedetail/topic-preview/index?id=<TEST template id>` opens that template; bare path → unavailable state. `MiniProgramPageLinkTests.testParityPlayerContentPagesKeepTheirQuery` |
| PC-A-8-1 | fixed | same | `chein://mp/pages/templatedetail/topic-detail/index?id=<id>&tab=details` opens the template |
| PC-B-1-1 | fixed | `App/TopicDetailView.swift`, `App/AppSession+PopupsClose.swift` | Non-owner TEST account on any topic: no 转为正式主题 / 移交给俱乐部承接 rows. Owner on a Beta topic: rows appear only if the build issues the graduation / ownership grants (production does not: rows hidden, not failing) |
| PC-B-1-2 | blocked (owner decision) | — (built in `33f351847`, removed in `08b3f0409`) | 收藏 needs `POST api/topic/like {id,type:1}` + `like_list`. The route is live in production, but `test_bk_backend_sync.test_topic_like_direction_factory_stays_unwired` pins BK-LIKE as unwired. Owner: approve wiring `TopicLikeOperationFactory` through the player-write lease, then the toolbar bookmark (`TopicXcxToolbarActions.onToggleFavorite`, already present) is a small change |
| PC-B-2-1 | fixed | `App/MPReviewedPageScreen.swift`, `Core/MiniProgramPageLink.swift` | `…/pages/topic/merchantinfo/merchantinfo?topicId=5&id=9` → merchant project view for topic 5; `?id=5` → topic 5 chapters (brand-square browse) |
| PC-B-2-2 | blocked (owner decision) | — | Merchant writes need `MerchantContentWriteApproval` grants. Production gating through the reviewed route gate stays as it is (brief). Owner: decide whether merchant content writes ship |
| PC-B-2-3 | deferred | — | Host functions (open recruitment / finish chapter / confirm club candidates / contact host / self supply / circle supply) need new `MerchantContentCommand`s; they are writes behind the same un-issued grant as PC-B-2-2, so they wait for that decision |
| PC-B-3-1 | blocked (owner decision) | — | Same grant as PC-B-2-2 (`.register` / `.updateRegistration`) |
| PC-B-3-2 | deferred | — | Map picker + PhotosPicker upload for the merchant application form; large UI work and only useful once PC-B-3-1 ships |
| PC-B-4-1 | blocked (owner decision) | — | Pricing confirm needs `PublisherLifecycleGrants.pricing` (production issues `reads` only) |
| PC-B-4-2 | deferred | — | Backend already accepts `ticketPrices: [{ticketId, price}]` (`PricingServiceImpl`, `ApiPricingTicketPricesParseTest`). App needs the preview's ticket list and one field per ticket in `PublisherPricingView`; confirm is grant-gated (PC-B-4-1), so it waits with it |
| PC-B-4-3 | fixed | `App/MPReviewedPageScreen.swift`, `Core/MiniProgramPageLink.swift`, `App/PlatformConsumerSessionOwner.swift` | `…/pages/topic/pricing/index?topicId=<owned topic>` opens 定价; every `SessionTopicDetailView` now injects `topicPricingDestination` (owner of a lifecycle-2 topic sees the pricing entry from any entry point, not only the browser sheet) |
| PC-C-2-1 | fixed | `App/RegistrationSheetView.swift`, `App/RegistrationPaySection.swift`, xcstrings | TEST account, free activity → 报名成功 + 票已放入票夹… + 查看订单 (opens order detail of the registration id). Paid → 报名已提交 + amount + pay section. Release build shows no 报名编号 / 状态码 / 支付通道参数 lines (DEBUG keeps them for UI tests) |
| PC-C-4-1 | fixed (client); backend needed | `Core/OfficialEventContracts.swift`, `App/OfficialActionViews.swift`, `App/PlayerGapViews.swift`, xcstrings | Fixture: official event JSON with `"safetyNotice":{"title":"活动安全须知"}` → unchecked 我已阅读并同意《活动安全须知》; 立即报名 disabled with 请先勾选安全须知 until checked. Without `safetyNotice` nothing changes |
| PC-D-1-2 | fixed (entry) | `App/MyProjectTabViews.swift`, `App/OrphanScreenMounts.swift`, `App/ProjectOwnedContentViews.swift` | 我的项目, long-press a cancellable topic → 取消并退款 → publisher host → 取消并退款 (reason → 查看退款影响 → confirm). Refund write stays behind `cancellationRefunds` (TEST-only) |
| PC-D-4-1 | fixed | `App/MPReviewedPageScreen.swift` | `…/assetcenter/income-detail/income-detail` has no 主办分润 button |
| PC-D-6-1 | fixed | `App/MPReviewedPageScreen.swift` | `…/assetcenter/analysis/index` opens 收益分析, not 我的资产 |

## P1 / chrome done

| id | status | files | verify (local) |
|---|---|---|---|
| PC-A-1-2 | fixed | `Core/TopicService.swift` (`TopicQuery.sortType`), `Core/HomeFeedService.swift` | 主题 stream sends `sort_type=1 pageSize=20`; 编辑精选 `pageSize=5` |
| PC-A-1-4 | fixed | `App/HomeSearchTabParityViews.swift` | Tap the 首页 avatar → 我的 tab; VoiceOver reads 我的, button |
| PC-A-2-4 | fixed | xcstrings `discovery.games` | Template shelf segment reads 主题 / 玩法 |
| PC-A-3-2 | fixed | `App/GlobalSearchLinksAndTemplates.swift`, `App/GlobalSearchView.swift`, `App/MPReviewedPageScreen.swift` | `…/pages/search2/index?keyword=城` and `…/search2/result/index?keyword=城&categoryId=3` show results at once; `…/pages/searchmap/index?params=%7B%22keyword%22%3A%22城%22%7D` opens the map explorer with the keyword |
| PC-B-1-3 | partial | `App/PlatformConsumerSessionOwner.swift` | `playRuntimeTopicClient` now injected for every topic entry (prep row / 开始游玩 reachable beyond the browser sheet). 已截止 bar state not done |
| PC-C-3-1 | fixed | `App/MPReviewedPageScreen.swift` | Official list deep link: 关闭 dismisses, 登录 goes to 我的 (no `{}`) |
| PC-C-4-5 | fixed | `App/MPReviewedPageScreen.swift` | Official detail deep link as guest shows 登录; THEME missions open the topic |
| PC-D-9-2 | fixed | `App/MPReviewedPageScreen.swift`, `Core/MiniProgramPageLink.swift` | `…/subpackageB/pages/im/chat/index?conversationId=<TEST conv>` opens that chat; without the id → 消息 list |
| C-2 routing (X1) | fixed | `App/ActivityDetailView.swift`, `App/MPReviewedPageScreen.swift` | `…/pages/activity/baoming/baoming?activityId=<id>` opens the activity with the registration sheet once it can sign up |
| C-7 routing (X1) | fixed | same | `…/pages/activity/official-organizer/index?id=88` opens the organizer console when the session has organizer access |
| chrome: `MerchantContentEditor` hidden back | fixed | `App/MerchantContentEditor.swift` | Edit a merchant content form: system back while clean; after typing, the guarded back asks 放弃修改? and swipe-back is blocked. Typography lint hidden back 15 → 14 |

## Not done in this pass (deferred, in fix-plan order)

- Chrome: `TopicDetailView` / `ActivityDetailView` still use `cyHeroPushedChrome`. Moving to `cyHeroChrome` hides the bar over the hero,
  which also hides their trailing share / safety (举报) items until the hero scrolls away. Needs a design call: trailing glass actions on
  the hero, or keep them in a transparent bar.
- PC-A-1-3 city picker: the menu exists but has no city → coordinate data; wiring it now would be an inert control.
- PC-D-9-1 mark read on open: IM follows the Flutter app (owner rule); check Flutter's read-on-open before adding a silent `api/im/read`.
- Everything else in the audit's P1 / P2 lists (A-1-5…8, A-2-1/2/3/5/6, A-3-1/3/4, A-4-2/3, A-5-*, A-6-*, A-7-2/3, A-8-2/3, B-1-4…15,
  B-2-4/5, B-3-3…5, B-4-4…7, B-5-*, B-6-*, C-1-*, C-2-2…7, C-3-2/3, C-4-2…4, C-5-*, C-6-*, C-7-*, D-1-1, D-1-3…9, D-2-*, D-3-*,
  D-4-2…5, D-5-*, D-6-2…5, D-7-*, D-8-*, D-9-3/4, and all P2) is untouched.

## Backend needed

- `GET /api/official/events/{id}` (and v2 detail): return `safetyNotice: { title: string, version: string }` when an event has a safety
  notice (MP official-detail js:482-483 already reads it). Without it the consent step never shows (same as the MP today).

## Owner decisions needed

1. Wire topic 收藏 (`api/topic/like` type 1/0 + `like_list`) through the player-write lease, lifting the BK-LIKE "stays unwired" pin.
2. Issue (or keep dormant) the publisher grants `pricing`, `graduation`, `ownership` and the merchant content write approvals. While
   dormant, owner rows stay hidden (B-1-1) and pricing stays read-only.
3. Hero chrome on topic / activity detail (see above).
