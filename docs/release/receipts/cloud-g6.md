# cloud-g6 — capability gap G6: NPC/AI, creator/publishing, marketing/products (player)

Branch `ui/cloud-g6`. Parent `origin/ui/main` `ec2e42ba8`. Source list: `ui/capgraph` `c2202dbe3`
`docs/release/capability-graph.md` §(1) MP-ONLY "npc/ai (player) — 7", "creator/publishing (player) — 5",
"marketing/products (player) — 5". Mini program: hengyin `chengyinhub-xcx` `92eda912`.

Code only. No xcodebuild was run. `App/AppSession.swift` (8176 lines) and `App/AppCompositionRoot.swift` (4307 lines)
are unchanged; accessors live in `App/AppSessionG6.swift`. Money stays off: no path here buys, pays, redeems, sells
virtual goods, or claims attribution. `ReleaseMoneyWriteSwitch` is untouched. `wiredPatternCount` stays 672.

## Sibling branches checked

`origin/ui/cloud-g-editor` (`aafba56c9`), `origin/ui/cloud-g-social-roam` (`2d32e97f6`), `origin/ui/cloud-h2-claude`
(`969ea25ca`): none adds or touches any of the 17 paths. `origin/ui/cloud-g-club-misc` does not exist on origin
(also checked `ui/cloud-club`, `ui/cloud-clubops`: no overlap). No type from those branches is redeclared.
All new types use a `G6` prefix.

## Path → native file → entry screen → status

| Path | Native file | Entry screen (MP page) | Status |
|---|---|---|---|
| `GET /api/ai/npc/profile` (scope=global) | `Core/G6CapabilitySource.swift` `npcGlobalProfile`, `Core/G6NPCPresence.swift` `G6RoamNPCCoordinator` | Roam live session top prompt slot, `App/RoamLiveSessionView.swift` via `G6RoamNPCPromptModifier` (`pages/roam/index`) | DONE |
| `GET /api/ai/npc/profile` (scope=node) | `npcNodeProfiles`, `G6StoryCharacters` | Topic detail 主要角色 section, `App/TopicDetailView.swift` via `G6TopicCharactersSection` (`pages/topic/index/index`) | DONE |
| `GET /api/ai/npc/event` | `npcEventLine`, `G6RoamNPCCoordinator`, `G6RoamNPCGate` | Roam live session bubble + finish line (`pages/roam/index`) | PARTIAL — start / tile milestones 25·80 / end are dispatched; `roam_poi_first_light` is ported in Core but the native roam controller exposes no first-visit POI receipt, so it is never dispatched |
| `POST /api/ai/npc/chat` | `npcChat`, `G6NPCChat.reply` (Core only) | none | HIDDEN — the MP mounts `cy-npc-chat` only with `scope="merchant"` (member/userinfo profile → `/api/ai/npc/merchant-chat`); the roam track is never mounted and `roamNpcChat` is off. Not granted |
| `GET /api/ai/npc/chat/request` | `npcChatRequest` (Core only) | none | HIDDEN — its only mounted caller is the merchant track, whose send path `/api/ai/npc/merchant-chat` is outside G6 and not granted. Not granted |
| `POST /api/ai/theme/draft/prepare` | `aiDraftPrepare`, `Core/G6AIThemeDraft.swift` `G6AIThemeDraftFlow` | Publish AI draft sheet, `App/PublishingAIDraftSheet.swift` via `G6AIThemeDraftAdapter` (`pages/publish/simple/index`) | DONE (see note) |
| `POST /api/ai/theme/draft/execute` | `aiDraftExecute`, `G6AIThemeDraftFlow` | same sheet | DONE (see note) |
| `GET /api/ai/theme/draft/recovery` | `aiDraftRecovery`, `G6AIThemeDraftRecoveryPage` | same sheet, 起草记录 section `G6AIThemeDraftRecoverySection` | PARTIAL — history is listed read only with paging; selecting a row to adopt it into the journal (MP `onAiHistorySelect`) is not ported |
| `GET /api/author-write/receipt` | `authorWriteReceipt`, `Core/G6AuthorWrite.swift` (Core only) | none | PARTIAL — Core port of `author-write-recovery.js` (intent save, receipt FOUND/UNKNOWN/other, settle rules) with tests. No native consumer: the app's NPC chat-log delete deliberately sends `{}` without a request id, and the publish editors keep their own journals. Not granted (route is `missing` on the reviewed production backend; `ChinaReviewedRouteCapabilityTests` pins it closed) |
| `GET /api/video-bounty/accrual/mine` | `Core/VideoBountySource.swift` (already on `ui/main`) | Account → 视频激励 | DONE earlier (`cloud-stubs-bounty`), not re-implemented |
| `POST /api/video-bounty/submission` | same | same | DONE earlier |
| `GET /api/video-bounty/submission/mine` | same | same | DONE earlier |
| `GET /api/video-bounty/submission/{}` | — | — | NOT A ROUTE — capgraph artifact: the CSV maps it to `ApiVideoBountyController.listMine`; the MP only calls `submission/{id}/appeal` and `/cancel` (POST), both already shipped |
| `POST /api/marketing/attribution/claim` | — | — | HIDDEN — marketing write (attribution); players read only |
| `GET /api/marketing/product/{}` | `marketingProduct`, `G6MarketingProduct` | Pass detail, `App/MPParityPassSession.swift` `MPParityPassDetailModel` (`subpackageMember/market/pass/index`) | DONE — reads the one product instead of scanning the list; quote/order/pay stay off and pay modes stay facts, not buttons |
| `GET /api/marketing/promotions/catalog` | `promotionCatalog`, `G6PromotionCatalog` | Registration sheet 优惠 section after the ticket, `App/RegistrationSheetView.swift` via `G6PromotionCatalogSection` (`pages/activity/baoming/baoming`) | DONE |
| `GET /api/marketing/revenue/author/mine` | `authorRevenue`, `G6RevenueAllocations` | Wallet income 分佣 row → list, `App/WalletCommerceViews.swift` via `G6RevenueAllocationsEntry` (`subpackageA/pages/assetcenter/income-detail`) | DONE — MP shows it as a tab; native shows a row on the same income screen that opens the list |
| `GET /api/platform-pass/orders/{}` | — | — | HIDDEN — the MP reads it only after `wx.requestPayment` (`platform-pass-pay.js`); with payment off there is no order to read |

AI draft note: the existing AI sheet keeps its quota/session client; only generation switches to the V2 protocol
(`SessionPublishingModesView` now passes `session.g6PublishingAIDraftFactory`, which is nil wherever the old factory
was nil, so the entry stays hidden in the same places). Ported: `prepareKey` UUID, strict 10-key view check, server id
`td2_…`, durable member-scoped journal (`allowsUpdate`, `beginConfirmedNewAction`), PREPARED → execute only inside
`executeBefore` with `contextAvailable`, UNKNOWN/PROCESSING/unconfirmed are read back by `GET /request` and never
re-prepared, "start a new draft" needs an explicit confirmation dialog. Simplification: a read-back that finds
PREPARED continues to execute in the same tap (the MP needs a second "continue" tap).

## Rules applied

- Unknown values: revenue lines without a readable amount say 金额待确认 / "Amount pending"; a failed revenue read says
  收益暂不可用 and never 0; a non-participant or empty list hides the entry; an empty or failed promotion catalog draws
  nothing; promotion remaining time is `windowEndsAt − serverNow` only. Booleans are never read as numbers (the MP's
  `Number(true)` quirk is not copied).
- Nil reader/capability ⇒ hidden: every entry reads `\.g6Capabilities` (installed once at the player root in
  `MPParityPassEnvironment`); outside a signed-in China runtime context the source is nil and nothing is requested or drawn.
- Roam NPC lines appear only when `POST /api/config/features` returns `roamNpcEvent` exactly true, and only reviewed lines
  (`cacheOnly=true`).
- `npc_route_egg` (dropped 2026-09-07): no egg code was added; nothing here exposes it.

## Grants (both places)

- `Core/ChinaReviewedRouteCapability.swift` `g6OwnerGrant`: `/api/ai/npc/profile`, `/api/ai/npc/event`,
  `/api/ai/theme/draft/prepare`, `/api/ai/theme/draft/execute`, `/api/ai/theme/draft/recovery`,
  `/api/marketing/promotions/catalog`, `/api/marketing/revenue/author/mine`, `/api/marketing/product/{}`.
  (`/api/ai/theme/draft/request` and `/api/config/features` were already wired.)
- `App/ReviewedPlayerWriteLeases.swift`: `playPaths` += `api/ai/theme/draft/prepare`, `api/ai/theme/draft/execute`;
  new `capabilityReadPaths` (the six reads) admitted on the GET branch of `acceptsPlayerWrite`.
- Not granted: attribution claim, platform-pass order reads, NPC chat + chat request, author-write receipt, every quote,
  order, pay, and gift-claim path.

## Tests

- `Tests/CoreTests/G6CapabilitySourceTests.swift`: a stub transport per route (paths, queries, bodies), projections
  (catalog, revenue, product, characters, NPC chat reply), roam gate quotas/gaps and coordinator queue/give-up, AI draft
  view/recovery/journal validation, V2 flow (prepare→execute→result; UNKNOWN read back, not re-prepared; confirmed new),
  author-write decision/settle, and the China gate (admits the grant, refuses hidden and money routes, NPC chat and
  receipt refused on the China host).
- `Tests/AppUnitTests/G6CapabilityGrantTests.swift`: the shipped China composition sends the two AI writes and six
  reads through `composition.transport()` and still refuses attribution, platform-pass orders, quote, order, gift claim,
  registration pay, and pay create.

## Strings

75 keys under `g6.*` in `Resources/Localizable.xcstrings`, English and Simplified Chinese (MP copy).

## Gates

`python3 tools/generate_project.py` (new files), `python3 tools/check_scaffold.py`, `python3 tools/check_design_lint.py`,
and `swiftc -parse` on every changed Swift file pass. The five new Core files and `G6CapabilitySourceTests` (compiled in-module
with XCTest) were type-checked with `swiftc -typecheck` against the ~145 Core files they transitively use: zero errors or
warnings in any G6 file (the remaining errors were unresolved symbols inside unrelated dependency files outside that
subset). App files were only `-parse`d. No test suite was executed here; the integrator compiles and runs them.

Load note: hidden sections cannot load themselves (an empty SwiftUI section never appears), so the promotion catalog and
topic characters load through `G6PromotionCatalogLoader` / `G6TopicCharactersLoader` attached to the always-drawn form/list,
and the sections read `G6SectionStore`.

## Files

- Added: `Core/G6CapabilitySource.swift`, `Core/G6NPCPresence.swift`, `Core/G6AIThemeDraft.swift`, `Core/G6AuthorWrite.swift`,
  `Core/G6MarketingReads.swift`, `App/AppSessionG6.swift`, `App/G6CapabilityViews.swift`,
  `Tests/CoreTests/G6CapabilitySourceTests.swift`, `Tests/AppUnitTests/G6CapabilityGrantTests.swift`.
- Changed (one line each unless noted): `App/MPParityPassSession.swift` (environment install + product detail read),
  `App/RegistrationSheetView.swift` (section + loader), `App/TopicDetailView.swift` (section + loader), `App/WalletCommerceViews.swift`,
  `App/RoamLiveSessionView.swift`, `App/PublishingAIDraftSheet.swift`, `App/SessionPublishingModesView.swift`,
  `App/ReviewedPlayerWriteLeases.swift`, `Core/ChinaReviewedRouteCapability.swift`, `Resources/Localizable.xcstrings`,
  `Questify.xcodeproj` (regenerated).

## 中文

G6 能力缺口（NPC/AI、创作发布、营销商品，玩家侧）。已做：漫游 NPC 提示层（global profile + event，仅 `roamNpcEvent` 为真且只用已审话术）、主题页「主要角色」（scope=node）、AI 起草 V2（prepare/execute + 本机身份日志 + 结果待确认只回读不重起 + 另起需明确确认）、起草记录只读列表、通行证详情改读 `/api/marketing/product/{id}`、报名页「优惠」促销目录、收益页「分佣」只读明细。隐藏：漫游轨 NPC 对话与回读（小程序未挂载）、归因认领（营销写）、通行证订单读（只在付款后出现，付款关闭）。作者写回执只做了 Core 移植，没有原生调用方，未授权。视频激励三条已在 ui/main 完成；`submission/{}` GET 是能力图误判。未知金额显示「金额待确认」，读取失败显示「收益暂不可用」，从不显示 0。`AppSession.swift` 与 `AppCompositionRoot.swift` 行数不变。

---

# Earlier receipt: cloud-g6 side-quest player entry


Base `origin/ui/main` `72d2eb9ec498de21ded7cf9215f2638d7195786f`. Branch `ui/cloud-g6-sidequest`. Money stays off. No production payload was added.

## Source

hengyin `chengyinhub-xcx` at `1c80c5aea8f721ca8575e6108048495b100f5576`. `app.json` at that commit registers `pages/searchmap/index` and does not register a side-quest page. The tree has no side-quest page path. `city_sidequest_observation` is a merchant-game template seed, not a player page. No page, route, or `/api/side-quests` client was added to stand in for a page that is not there.

## Shipped

| File | Role |
|---|---|
| `Core/SideQuestPlayerFlow.swift` | Closed production snapshot, unrestricted discovery filter, start/answer/cancel gate |
| `App/SideQuestPlayerEntry.swift` | Player entry rendered from that snapshot |
| `App/SearchMapExplorerView.swift` | Places the entry beside the search map once an area is selected |
| `Tests/CoreTests/SideQuestPlayerFlowTests.swift` | Core tests for the snapshot, filter, em dash, and gate |

`SideQuestPlayerFlow.sourcePagePresent`, `routeInstalled`, and `routeMarkedLive` are false. The search map passes `SideQuestPlayerFlow.production`, which is `sourceAbsent`: total and player status are an em dash (`—`, U+2014), rows are empty, and accept/start/answer/cancel stay hidden. A supplied read is not shown on that production snapshot.

When a caller explicitly presents a supplied read, only `UNRESTRICTED` instances inside the existing discoverable window are listed. `ONCE`, blank, lowercase, and other tokens (including `COUPON`) are omitted. A loaded read that lists nothing uses total `0`. Loading, failed, and unknown reads use an em dash. Missing capacity is an em dash. A literal capacity `0` stays `0`. Reward text is always an em dash. `addsMarkerLayer` is false. No new map pin is added.

`ReleaseMoneyWriteSwitch.paymentEnabled`, `payoutEnabled`, `withdrawalEnabled`, and `virtualGoodsEnabled` stay false. `SideQuestFeature.acceptEnabled` stays false. `perform` returns the same attempt book and does not record a choice. The recorded choice text is an em dash. A passing gate still returns `noAuthoritativeReadback` and writes nothing.

The existing map-core hub route for merchant side quests stays blocked. This entry does not open it.

## Checks

`python3 tools/generate_project.py` after the new Swift files. `python3 tools/check_scaffold.py` before push. Swift is not installed in this environment, so `swift test` was not run.
