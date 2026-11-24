# MP Gap Inventory — `player-content`

- **Base:** `origin/ui/combined-r6` vs MP `hengyin/chengyinhub-xcx`
- **Excluded:**
  - **Port packages P1–P5** (`port/plan-r1:docs/port/ios-port-plan.md` §2.2): cast/roles/story reading (P1), arrival/free-explore story locks/offline archive/visit-config (P2), route-detail chapter cards & 出发前 checklist & 0/empty hiding (P3), game kits/pool/wrong-reply/stage header (P4), OR-023/PG-006/MC-055/FE-G5/FE-G6/MoneyDisplay/V-23 (P5).
  - **Restyle (visual only):** `.cyText` typography roll-ups, `cyPageTitle` / `CYSheetHeader` chrome-only swaps, spacing/radius/color token swaps, pure copy tweaks.
  - **Cursor C2:** `backend-needed` §2 items.
- **Owner-gated items** (translated UI only, action stays gated): `PC-B-1-2` (topic like), `PC-B-2-2`/`B-2-3` (merchant content writes), `PC-B-3-1` (merchant apply write), `PC-B-4-1` (pricing confirm), `PC-D-5-1` (withdrawal payout).

---

## Functional Gaps (ordered largest-first for translation)

### 1. `PC-B-1-5` — Topic route tab: map, node progress, team summary & free-explore merchant/perk cards
- **MP page & file:line:** `pages/topic/index/index` (`index.wxml:190-193, 301-315, 413-429`, `index.js:749`)
- **What it does:** Renders an interactive route map with polyline and numbered stop pins over chapter nodes, node completion progress, a nearby team summary block for the topic, and free-explore merchant/perk cards.
- **API calls:** `GET /api/play/nodes` (`{topicId}`), `POST /api/team/nearby` (`{topicId, pageNum, pageSize}`), `POST /api/free-explore/bundle/catalog` (`{topicId}`)
- **App screen:** `TopicXcxSections` / `TopicDetailView`
- **Type:** `NEW-SECTION`
- **Size:** `L`

### 2. `PC-A-5-1` / `PC-A-5-2` / `PC-A-5-3` — Map-first search explorer (`pages/searchmap/index`)
- **MP page & file:line:** `pages/searchmap/index` (`searchmap/index.wxml:39-94`, `searchmap/index.js:275, 578, 1190`)
- **What it does:** Full-bleed map-first search with auto-locate on open, floating top search bar, bottom result capsule/sheet, merchant category sheet (`MERC` categories), `sort_type: 1` only, and place card sheet with open-in-Maps.
- **API calls:** `POST /api/activity/list` (`{keyword, categoryId, sort_type: 1, lat, lng, pageNum, pageSize}`), `POST /api/city/nodes` (`{keyword, categoryId, lat, lng}`), `GET /api/category/list`
- **App screen:** `SearchMapExplorerView` (plus `MPReviewedPageScreen` route `pages/searchmap/index`)
- **Type:** `NEW-SCREEN`
- **Size:** `L`

### 3. `PC-A-7-2` — Topic template card deck preview (`pages/templatedetail/topic-preview/index`)
- **MP page & file:line:** `pages/templatedetail/topic-preview/index` (`topic-preview/index.wxml:14-58`, `topic-preview/index.js:109, 240`)
- **What it does:** Paged card deck of template chapters/stops with tap-to-flip showing step details, adoption checklist, and bottom `查看详情` / `用这个模板` actions.
- **API calls:** `GET /api/template/topic-template/info` (`{id}`)
- **App screen:** `DiscoveryTemplateBrowserView` → new `TopicTemplateDeckPreview`
- **Type:** `NEW-SCREEN`
- **Size:** `L`

### 4. `PC-C-2-2` / `PC-C-2-3` / `PC-C-2-4` / `PC-C-2-6` — Activity registration (`baoming`) host reservation, child age picker & delivery/pass rows
- **MP page & file:line:** `pages/activity/baoming/baoming` (`baoming.wxml:155-241, 321`, `baoming.js:692, 921, 1038, 1065, 1876`)
- **What it does:** Preselects `ticketId` from deep link; adds 主持预约 status + `请求主持` action; adds 亲子票 `儿童年龄` picker; shows delivery contents, 商家暂停营业 banner, 俱乐部优先报名 notice, and 通行证 covered row.
- **API calls:** `POST /api/club/event-ops/host/request` (`{activityId, ticketId}`), `GET /api/club/event-ops/waitlist/status` (`{activityId}`), `POST /api/club/event-ops/waitlist/join` (`{activityId}`)
- **App screen:** `RegistrationSheetView` (and `ActivityDetailView` auto-open)
- **Type:** `NEW-SECTION`
- **Size:** `L`

### 5. `PC-B-2-2` / `PC-B-2-3` / `PC-B-2-4` / `PC-B-2-5` — Topic merchant host workbench (owner-gated writes)
- **MP page & file:line:** `pages/topic/merchantinfo/merchantinfo` (`merchantinfo.wxml:120-372`, `merchantinfo.js:660, 734, 809, 835, 862, 1523, 2667, 2858, 3949, 4095`)
- **What it does:** Host workbench cards and commands: open recruitment / finish chapter, confirm club candidates, contact host from join, self supply, circle supply pause/reconfirm. UI translated; writes remain behind `MerchantContentWriteApproval` (owner-gated).
- **API calls:** `GET /api/topic/info-to-merchant` (`{topicId}`), `GET /api/topic/merchant-recruitment-chapters` (`{topicId}`), `POST /api/coop/offer/withdraw`, `POST /api/coop/offer/quota`
- **App screen:** `MerchantContentProjectView`
- **Type:** `NEW-SECTION`
- **Size:** `L` *(owner-gated writes)*

### 6. `PC-B-3-1` / `PC-B-3-2` / `PC-B-3-3` — Topic merchant application map/photo pickers & success state (owner-gated write)
- **MP page & file:line:** `pages/topic/merchantapply/index` (`index.wxml:56-131, 173-216`, `index.js:235, 321, 673`)
- **What it does:** Prefills shop info from `/api/merchant/info`, provides map coordinate/address picker and `PhotosPicker` image upload instead of raw text fields, and shows a success summary card with `查看承接进度` / `返回商家首页`. Write stays behind `MerchantContentWriteApproval`.
- **API calls:** `GET /api/merchant/info`, `GET /api/registration/merchant/info` (`{topicId}`), `POST /api/registration/merchant/create`, `POST /api/registration/merchant/update`
- **App screen:** `MerchantContentEditor`
- **Type:** `NEW-SECTION`
- **Size:** `L` *(owner-gated write)*

### 7. `PC-A-2-1` / `PC-A-2-5` — Play template shelf full pagination & grouped shelves
- **MP page & file:line:** `pages/template/index` (`shelf/index.wxml:102-148`, `shelf/index.js:9, 201-240`)
- **What it does:** Pages `POST /api/template/list` (`pageNum`, `pageSize: 50`) until `total`, and groups play templates into the MP art/category shelf rails instead of only `homeData`.
- **API calls:** `POST /api/template/list` (`{pageNum, pageSize: 50, keyword?}`)
- **App screen:** `DiscoveryTemplateBrowserView`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 8. `PC-A-4-2` — Unified content search (posts, ranking, pagination & post navigation)
- **MP page & file:line:** `pages/search2/result/index` (`index.js:89-115, 240-300`)
- **What it does:** Merges `POST /api/search/unified` results (including community posts) into main keyword-only search results when signed in, with infinite pagination and tap-to-open square post detail.
- **API calls:** `POST /api/search/unified` (`{keyword, pageNum, pageSize}`)
- **App screen:** `GlobalSearchView`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 9. `PC-A-6-2` / `PC-A-6-3` — Template detail `scope=my` / `readonly` & sign-in gate on `应用`
- **MP page & file:line:** `pages/templatedetail/templatedetail` (`templatedetail.js:358-363, 497-528`)
- **What it does:** Honours `scope=my`, `operationScope=MERCHANT`, `readonly=1` query params for owned drafts, and shows `应用` to signed-out users with a sign-in gate that resumes adoption after login.
- **API calls:** `GET /api/template/info` (`{id}`), `GET /api/template/my/info` (`{id, operationScope}`)
- **App screen:** `DiscoveryTemplateDetailView` / `MPReviewedPageScreen`
- **Type:** `NEW-ACTION`
- **Size:** `M`

### 10. `PC-A-8-3` / `PC-A-8-6` — Topic template detail stat cards, stop durations & full-screen node image gallery
- **MP page & file:line:** `pages/templatedetail/topic-detail/index` (`topic-detail/index.wxml:37, 55-63, 125-155`)
- **What it does:** Replaces capability chip row with stat cards (duration, stops, distance), adds duration & game icon to stop rows, and opens full-screen gallery when tapping node/mosaic images.
- **API calls:** `GET /api/template/topic-template/info` (`{id}`)
- **App screen:** `DiscoveryTemplateDetailView`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 11. `PC-B-1-4` — Topic detail 开局前准备 & 开始游玩 with safety check
- **MP page & file:line:** `pages/topic/index/index` (`index.wxml:467-474`, `index.js:722-788`)
- **What it does:** Ensures `playRuntimeTopicClient` is available on all topic detail entries and adds primary `开始游玩` action that runs `/api/orient/safety/check` before entering play.
- **API calls:** `POST /api/orient/safety/check` (`{topicId}`)
- **App screen:** `TopicDetailView` / `PlayRuntimeGapViews`
- **Type:** `NEW-ACTION`
- **Size:** `M`

### 12. `PC-B-1-6` / `PC-C-1-7` — Contextual review composer: 5-star control & up to 9 photos
- **MP page & file:line:** `pages/topic/index/index` (`index.wxml:477-515`) & `pages/activity/detail/index` (`detail/index.wxml:137-141`, `detail/index.js:615-623`)
- **What it does:** Replaces numeric star picker with interactive 5-star control, enforces 300-char limit, and adds `PhotosPicker` (max 9) uploading via `uploadOSS` and joining `img_arr` with `;`.
- **API calls:** `POST /api/common/uploadOSS` (multipart), `POST /api/comment/add` (`{targetId, targetType, score, content, img_arr}`)
- **App screen:** `ContextualReviewComposer`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 13. `PC-B-1-11` — Topic detail publisher row, owner review-state chip, tappable lineup & points link
- **MP page & file:line:** `pages/topic/index/index` (`index.wxml:109-112, 121, 262, 288-291, 353`)
- **What it does:** Shows publisher avatar + name row, decodes `userStatus`/`status`/`rejectReason` into an owner status chip (`审核中`/`未通过`/`已下架`), makes lineup cards navigate to Club/Merchant detail, and links points rule to Growth Center.
- **API calls:** `GET /api/topic/info-to-user` (`{id}`)
- **App screen:** `TopicDetailView` / `TopicXcxSections`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 14. `PC-B-4-1` / `PC-B-4-2` / `PC-B-4-4` — Topic pricing per-ticket fields, fee/take-home, settlement pending & sale status
- **MP page & file:line:** `pages/topic/pricing/index` (`index.wxml:52-55, 70-86, 104-109`, `index.js:331, 351, 416-460`)
- **What it does:** Adds per-ticket `ticketPrices` input fields, fee/take-home calculation row, `sale-status` and `settlement-pending` sections. Confirm action stays behind `PublisherLifecycleGrants.pricing` (owner-gated).
- **API calls:** `GET /api/topic/pricing/preview` (`{topicId}`), `GET /api/topic/pricing/sale-status` (`{topicId}`), `GET /api/topic/pricing/settlement-pending` (`{topicId}`), `POST /api/topic/pricing/confirm` (`{topicId, price, ticketPrices}`)
- **App screen:** `PublisherLifecycleViews`
- **Type:** `NEW-SECTION`
- **Size:** `M` *(confirm owner-gated)*

### 15. `PC-C-1-1` / `PC-C-1-2` / `PC-C-1-5` / `PC-C-1-6` — Activity detail cancelled state, guest read, owner cancel CTA & ticket window/lineup
- **MP page & file:line:** `pages/activity/detail/index` (`detail/index.wxml:5-6, 85-97, 150`, `detail/index.js:174, 331-338`)
- **What it does:** Maps `ACTIVITY_CANCELLED` to dedicated empty/action state (`活动已取消` + `查看我的订单`), supports guest read of `api/activity/info`, shows destructive `取消活动并退款` in pinned footer for host, and adds `startTime`/`endTime`/`deadline`/lineup disclosure on ticket cards.
- **API calls:** `GET /api/activity/info` (`{id}`)
- **App screen:** `ActivityDetailView` / `ActivityPresentationComponents`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 16. `PC-C-4-2` / `PC-C-4-4` — Official event detail 赛事榜单 & pinned footer bar
- **MP page & file:line:** `pages/activity/official-detail/index` (`official-detail/index.wxml:143-153, 207-215`, `index.js:470-481`)
- **What it does:** Decodes and renders `leaderboard` section with `暂列第 N 名` viewer rank chip, and pins share + primary CTA in `.safeAreaInset(edge: .bottom)`.
- **API calls:** `GET /api/official/events/{id}`
- **App screen:** `OfficialEventDetailView`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 17. `PC-D-1-3` / `PC-D-1-6` / `PC-D-1-8` — My Projects cancel preview count, merchant joined/invited merge & inline template tab
- **MP page & file:line:** `subpackageA/pages/myproject/index` (`index.wxml:68-114`, `index.js:343-369, 596-603`)
- **What it does:** Calls `ActivityHostCancel` preview before confirming activity cancel to show paid-player/refund counts; merges `/api/registration/merchant/list` + `/api/merchant/chapter-application/mine` in merchant scope; renders template shelf rows inline in the 模板 tab.
- **API calls:** `GET /api/registration/merchant/list`, `GET /api/merchant/chapter-application/mine`, `POST /api/activity/cancel_preview`
- **App screen:** `MyProjectTabViews` / `CreatorContentViews`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 18. `PC-D-4-2` / `PC-D-4-5` — Asset center income detail 主办分润 filter & 收益/分佣 tabs
- **MP page & file:line:** `subpackageA/pages/assetcenter/income-detail/income-detail` (`income-detail.wxml:14-18`, `index.js:34-37`)
- **What it does:** Adds `.club` (`主办分润`) filter backed by `api/coop/finance` when grant exists, and promotes 分佣 (`G6RevenueAllocationsModel`) to a top-level `收益`/`分佣` segmented tab.
- **API calls:** `GET /api/coop/finance` (`{pageNum, pageSize}`)
- **App screen:** `WalletCommerceViews`
- **Type:** `NEW-SECTION`
- **Size:** `M`

### 19. `PC-D-5-1` / `PC-D-5-2` — Asset center earnings non-payout 提现 CS sheet & 更多 settlement/payout links
- **MP page & file:line:** `subpackageA/pages/assetcenter/earnings/index` (`earnings/index.wxml:16, 28-37`, `earnings/index.js:61-76`)
- **What it does:** Shows `提现` quick action opening platform customer-service contact sheet when payout switch is off, and replaces duplicate items in `更多` with `本人俱乐部结算` (`ClubSettlementMineView`) and `个人收款` (`ClubPayoutReceiverView`).
- **API calls:** `GET /api/club/settlement/mine`, `GET /api/club/payout-receiver/mine`
- **App screen:** `WalletCommerceViews`
- **Type:** `NEW-ACTION`
- **Size:** `M` *(money payout stays TEST-only)*

### 20. `PC-D-9-1` / `PC-D-9-3` / `PC-D-9-4` — IM chat mark-read, 举报对方 & `+` composer menu
- **MP page & file:line:** `subpackageB/pages/im/chat/index` (`chat/index.wxml:196, 250`, `chat/index.js:45, 49, 288-297, 858-876`)
- **What it does:** Marks conversation read on appear (`POST /api/im/read` with `read_to`), adds `举报对方` (`MEMBER` report), and turns composer `+` into a menu `{图片, 位置, 路线, 投票}`.
- **API calls:** `POST /api/im/read` (`{conversation_id, read_to}`), `POST /api/report/create` (`{targetType: "MEMBER", targetId, reason}`)
- **App screen:** `MessagingHistoryView` / `MessageActionComposer`
- **Type:** `NEW-ACTION`
- **Size:** `M`

### 21. `PC-A-1-5` — Home action banners routing (`成为俱乐部` / `成为商家` / `和朋友报名活动`)
- **MP page & file:line:** `pages/index/index` (`index.wxml:19-32`, `utils/index/home-action-banner.js:4-8, 62-68`)
- **What it does:** Routes `activity_list` banner to an activity list destination and `club_apply` banner to the club application form rather than only switching feed tab or opening club browser.
- **API calls:** None (navigation)
- **App screen:** `HomeFeedView` / `SessionHomeFeedView`
- **Type:** `NEW-ACTION`
- **Size:** `M`

### 22. Small (`S`) items
| ID | MP page & file:line | Function | API calls | App screen | Type |
|---|---|---|---|---|---|
| `PC-A-1-3` | `pages/index/index` (`index.wxml:50-63`, `index.js:1657-1668`) | Wire `onSelectCity` callback on 首页 city menu | None (local roam area) | `SessionHomeFeedView` | `NEW-ACTION` |
| `PC-A-1-6` | `pages/index/index` (`index.wxml:107-123`) | Show `Beta 试玩`, category tag, status, club label on 编辑精选 cards | `POST /api/topic/list` | `HomeFeedView` | `NEW-SECTION` |
| `PC-A-1-7` | `pages/index/index` (`index.wxml:219-239, 272`, `index.js:1669-1674`) | Tap 地点 on feed card opens walking-nav / map sheet + eyebrow/tags | None | `HomeFeedView` | `NEW-ACTION` |
| `PC-A-2-2` | `pages/template/index` (`index.js:169-170`) | Replace local search pills with one search capsule → `SessionGlobalSearchView` | None | `DiscoveryTemplateBrowserView` | `NEW-ACTION` |
| `PC-A-3-1` | `pages/search2/index` (`index.wxml:13`) | Show 商家 lane in player search (pending owner confirmation) | `POST /api/search/unified` | `GlobalSearchView` | `NEW-SECTION` |
| `PC-A-3-3` | `pages/search2/index` (`index.js:117-120`) | Empty search submit validation toast `请输入关键词或选择类别` | None | `GlobalSearchView` | `NEW-ACTION` |
| `PC-B-1-2` | `pages/topic/index/index` (`index.js:642-686, 727`) | Topic 收藏 bookmark button (owner-gated `TopicLikeOperationFactory`) | `POST /api/topic/like`, `GET /api/topic/like_list` | `TopicDetailView` | `NEW-ACTION` |
| `PC-B-1-14` | `pages/topic/index/index` (`index.js:668`) | Guest read of public topics; gate only writes | `GET /api/topic/info-to-user` | `SessionTopicDetailView` | `NEW-ACTION` |
| `PC-B-5-2` / `B-5-4` | `pages/topic/pricing/partner/index` (`index.wxml:28-44`) | Partner club/merchant link + address map link + deep link | `GET /api/club/detail`, `GET /api/merchant/public-detail` | `PublisherLifecycleViews` | `NEW-ACTION` |
| `PC-B-6-1` | `pages/topic/catalog/index` (`catalog/index.js:1-17`) | Deep-link redirect `?id=` → topic, else home | None | `MPReviewedPageScreen` | `NEW-ACTION` |
| `PC-C-6-2` | `pages/activity/official-mine/index` (`wxml:30`, `js:185-190`) | 安全恢复原投递 (`recover` command) on broadcast row | `POST /api/official/broadcast/recover` | `OfficialPublishedView` | `NEW-ACTION` |
| `PC-C-7-1` | `pages/activity/official-organizer/index` | Deep-link route for organizer console | `GET /api/official/events/{id}` | `MPReviewedPageScreen` | `NEW-ACTION` |
| `PC-D-3-2` | `subpackageA/pages/infomationdetail/infomationdetail` (`js:118, 123`) | Render CMS `img` blocks and clickable `href` links in guide articles | None | `SocialArticleContentView` | `NEW-SECTION` |
| `PC-D-6-2` | `subpackageA/pages/assetcenter/analysis/index` (`js:51-68`) | Page 200 rows/call for full 6-month analysis totals | `GET /api/wallet/income/list` | `WalletIncomeAnalysisReader` | `NEW-ACTION` |
