# Receipt — fix/r3-player-content-a (Claude F-agent, player-content, half a)

- **Brief:** `design/handoff-r2:docs/briefs/wave-x10.md`. **Base:** `origin/ui/combined-r7` @ 7fdfad1f1.
- **Pages (first half of the round-1 list, 15):** A1 index · A2 template · A3 search2 · A4 search2/result · A5 searchmap ·
  A6 templatedetail · A7 topic-preview · A8 topic-detail · B1 topic · B2 merchantinfo · B3 merchantapply · B4 pricing ·
  B5 pricing/partner · B6 catalog · C1 activity/detail.
- **Gap sources used:** `audit/parity-r7-player-content` (fix queue, Claude lines first), `review/r7-rev-b` (B-02, B-03, B-08),
  round-1 `audit/parity-player-content`.
- **Restyle merged first** (they touch files in this half): `restyle/r1-player-front`, `restyle/r2-club-social`,
  `restyle/r3-merchant-creator`, `restyle/r5-play-roam-city`. All merged clean.
- **Layer:** App only. No Core type changed. No compiler in the cloud: every API used was grepped on the branch.
- **Strings:** `docs/port/strings/fix-r3-player-content-a.json` (xcstrings format, 14 keys, all new; where the MP copy
  differs from an existing key a new `.mp` key is added and the call site moved, so no existing key value changes).
- **Acceptance routes:** `docs/port/accept/f-player-content-a.txt`.

## Fixed

| id | what | files |
|---|---|---|
| R7-PC-A1-1 | 首页 city menu is live: `onSelectCity` passed; a supported city moves `session.roamArea` to that city centre (全国 keeps the centre) | SessionHomeFeedView |
| R7-PC-A1-2 | 和朋友报名活动 opens the activity list (`OfficialEventsBrowserView`); 成为俱乐部 opens the `pages/club/apply/index` screen, not the club browser; HomeFeedView no longer also flips the feed tab | SessionHomeFeedView, HomeFeedView |
| R7-PC-A1-3 (part) | 编辑精选 slides show `Beta 试玩` | HomeFeedView |
| R7-PC-A1-4 (part) | Feed card eyebrow (主题 / 活动); long-press / VoiceOver action 在地图中打开 on cards with an address | HomeFeedView |
| R7-PC-A1-5 | 附近活动 `进行中` chip (`HomeFeedItem.isLive`) | HomeFeedView |
| R7-PC-A1-6 | Stream pages on reach-bottom (sentinel); the failure retry row stays | HomeFeedView |
| R7-PC-A5-1 | Hero map button opens the search map (`SessionLinkedSearchView(startsOnMap:)`), not the list | SessionHomeFeedView |
| R7-PC-A2-2 | One read-only search capsule pushes the global search (templates are a result type) on every session entry; fixtures keep the local fields | DiscoveryTemplateBrowserView, SessionHomeFeedView, PublishTabRootView, MPReviewedPageScreen |
| R7-PC-A2-4 | `previewOnly` topic rows toast 暂未开放 | DiscoveryTemplateBrowserView |
| R7-PC-A2-5 | Named failures 主题模板加载失败 / 玩法模板加载失败 | DiscoveryTemplateBrowserView |
| R7-PC-A4-2 | Topic / activity results are cover cards; club / merchant keep rows | SearchMapComponents |
| R7-PC-A5-5 | Result cards: 在地图中打开 (coordinate when valid, else address) | SearchMapResultsCapsule |
| R7-PC-A6-1 | `templatedetail?scope=my` opens the owned member template, never the public read | MPReviewedPageScreen |
| R7-PC-A6-2 | 应用 when signed out: toast + 我的 (sign-in home); resume after sign-in is not done | DiscoveryTemplateDetailView |
| R7-PC-A6-3 | Notice copy 「应用」… (new key) | DiscoveryTemplateDetailParitySections |
| R7-PC-A6-4 | 简介 / 规则 clamp to 4 lines with 更多 / 收起 | DiscoveryTemplateDetailView |
| R7-PC-A7-2 | Skeleton instead of the centred spinner | DiscoveryTemplateDetailView |
| R7-PC-A8-1 (part) | 能力 stat cards (节点 / 玩法 / 总时长) | DiscoveryTemplateDetailView |
| R7-PC-A8-4 | 采用条件 moved under 能力 | DiscoveryTemplateDetailView |
| R7-PC-B1-3 | Standing 补充姓名和手机号 row removed | TopicDetailView |
| R7-PC-B1-5 (part) | Prep sheet 开始游玩, enabled when every item is ticked; hands over to the ticket wallet | PlayRuntimeGapViews, TopicDetailView |
| R7-PC-B1-10 | Lineup cards open club detail / public merchant home | TopicXcxSections, TopicDetailView, PlatformConsumerSessionOwner |
| R7-PC-B1-14 | Duplicate start / end / merchants / duration rows dropped; 商家暂停营业 said once (bar) | TopicDetailView |
| R7-PC-B1-16 | Session note 场次内自由顺序，不带队 (new key) | TopicDetailView |
| R7-PC-B1-18 (part) | Route stops: image and 在地图中打开 | TopicXcxSections |
| R7-PC-B1-20 | 开局前准备 only for a joined viewer (`isSignUp`) | TopicDetailView |
| R7-PC-B1-23 | 去票夹 label override removed | TopicXcxSections |
| REV-B B-02 | 出发前 price uses `MoneyDisplay.yuan` | TopicXcxSections |
| REV-B B-08 | Chapter rows: X小时Y分钟 from seconds, plus 玩法 count | TopicDetailView |
| R7-PC-B3-5 | merchantapply `id` → registration edit; `topicId`+`nodeId` → registration create | MPReviewedPageScreen |
| R7-PC-B4-1 (App half) | Without the pricing grant the page says confirm is not open in the app (owner decision still pending) | PublisherLifecycleViews |
| R7-PC-B4-7 | Chapter-supply lineup rows open the merchant 承接 page | PublisherLifecycleViews, PlatformConsumerSessionOwner, MPReviewedPageScreen |
| **R7-PC-B5-1 (P0)** | Partner deep link has its own case and opens `PublisherPartnerView` | MPReviewedPageScreen |
| R7-PC-B5-2 | Partner page 查看 (club / merchant) and address → Maps | PublisherLifecycleViews, TopicXcxSections, PlatformConsumerSessionOwner, MPReviewedPageScreen |
| R7-PC-C1-4 | Host footer is destructive 取消活动并退款 (existing host-cancel sheet) | ActivityDetailView |
| R7-PC-C1-5 (part) | Ticket 场次时间 / 报名截止 / 集合点 rows | ActivityPresentationComponents |

## Left, with reasons

| id | reason |
|---|---|
| R7-PC-A1-1 重新定位 item | No app-side relocate API on the home consent model; needs a location request owner. |
| R7-PC-A1-3 rest, A1-4 tags | Category, status and club label are not on `HomeFeedItem` → **Cursor**: add them to `HomeFeedItem` / topic row decode. |
| R7-PC-A1-7 share | No canonical public URL for the 首页 / a feed card yet. |
| R7-PC-A1-8 `cyRootHeader` | Superseded by the owner's native-iOS ruling (system large title). |
| R7-PC-A2-3, A2-6 | Depend on Cursor R7-PC-A2-1 (paged `api/template/list`); MP `featGames`/`GROUPS` art tables not ported. |
| R7-PC-A2-7 | `SocialGuideTemplateSection` is D2 (half b); `DiscoveryHomeView` only holds a generic reader. |
| R7-PC-A3-4 | 0–1000 range control: M, left for the next pass. |
| R7-PC-A4-1 | Unified-search merge + post destination: M, touches result retention; next pass. |
| R7-PC-A5-6 | Offline banner needs real connectivity + cache time in the explorer; next pass. |
| R7-PC-A8-2, A8-5 | Image mosaic / gallery and moving 用这个模板 into the head row: M, next pass. |
| R7-PC-A8-3 | `isOfficial` is not decoded on `PublicTopicTemplateDetail` → **Cursor**. |
| R7-PC-B1-5 safety check | `/api/orient/safety/check` before play belongs in the play-start path → **Cursor**. |
| R7-PC-B1-9, B1-11 | Need Core decode first: R7-PC-B1-8 (publisher, review state) and `TopicDetail.castConfig` (REV-B B-03) → **Cursor**. |
| R7-PC-B1-13 | The session picker is activity-based; a ticket-preselected picker needs a new flow. |
| R7-PC-B1-17, B1-21 | No topic-list destination / per-chapter lock flag in the view; next pass. |
| R7-PC-B2-3, B3-3 | M: host commands on the project view, shop card + success view; next pass. |
| R7-PC-B2-4 | `MyProjectStateNavigation` is D1 (half b's file). Handed to `fix/r3-player-content-b`. |
| R7-PC-B3-4 | Per-field errors need `MerchantApplyXcx.allMissing` (Core only exposes `firstMissing`) → **Cursor**. |
| R7-PC-B4-4, B4-5 | Success toast / dismiss, and hiding 有人带/无人带 for productType 2 (the page has no topic read) — next pass. |
| R7-PC-C1-9 | `organizerShopLogo` not decoded → **Cursor**. |
| Cursor / Gemini / owner lines | Not this agent's layer (A2-1, A5-4, B1-8, B6-1/2, C1-2/3/8; A5-2, A7-1, B1-6/7/12, B2-2, B3-2, B4-3, C1-1/6; B1-2/4, B2-1, B3-1, B4-1 grant, A1-9, A2-8, C1-10). |

## Written, then reverted because a contract pin forbids the change (Cursor: re-pin, then these land)
The contract ratchet showed these as NEW failures, so the code was taken back out. Each fix is a few lines in the commit history
(`git log fix/r3-player-content-a`), ready to restore once the pin moves.

| id | pin that blocks it |
|---|---|
| R7-PC-A3-2 empty-search toast, R7-PC-A4-3 模板 tab + lane failures, R7-PC-A4-4 没有更多了 / 重新搜索 | `test_global_search_category_recovery` `CURRENT_VIEW_SHA256` (whole-file hash of `App/GlobalSearchView.swift`) |
| R7-PC-A3-3 inline date rows, R7-PC-A3-5 类别加载失败, R7-PC-A5-3 drop 最热 | same test, hashes of `App/SearchMapFilterSheet.swift` / `App/SearchMapExplorerView.swift`; also `tools/check_search_map_date_picker.py` |
| New `searchMap.*` keys in `App/*Search*.swift` | `check_search_map.py` + `test_search_map_contracts` require them in `docs/search-map-localizations.json` **and** `Localizable.xcstrings` (integrator-only). Kept new keys off the `searchMap.` prefix (`homeSearch.mapHint`). |
| **R7-PC-B1-1 (P0) 收藏** | `test_bk_backend_sync.test_topic_like_direction_factory_stays_unwired`: App must not reference `TopicLikeOperationFactory`. Needs an owner/Cursor decision to wire the like write (the version written used `TopicLikeHostController` + the composition-issued like transport, hidden while that is nil). |
| R7-PC-B2-5 状态 / 承接 copy | `test_merchant_station_submission_import` hash of `App/MerchantContentViews.swift` |
| R7-PC-C1-7 关于这场活动 above people | `test_activity_registration_parity_w2_06.test_meta_rows_follow_cancellation_and_precede_about` pins the old order |

## Requests for Cursor (Core)
1. `HomeFeedItem`: category name, status label, club label (A1-3 / A1-4).
2. `PublicTopicTemplateDetail.isOfficial` (A8-3).
3. `TopicDetail.castConfig` (REV-B B-03) and the R7-PC-B1-8 publisher / review-state fields.
4. `MerchantApplyXcx.allMissing(...)` returning every missing field (B3-4).
5. `ActivityDetail.organizerShopLogo` (C1-9).
6. Run `/api/orient/safety/check` in the topic play-start path (B1-5).

## Skipped because an in-flight branch covers it
- PC-A-5-6 inline title on the search map: `restyle/r1-player-front` (merged here).
- `gap/g1-player` deck-preview cover: parked MPGap UI (Gemini).

## Local gates (cloud, no compiler)
- `tools/check_typography_lint.py`: PASS.
- `tools/check_scaffold.py`: fails the source-list assertion, **same failure on the base** (`ui/combined-r7`, parked MPGap).
- `tools/check_search_map.py`: PASS.
- `tools/contract_ratchet.py --check`: 195 failing vs baseline 184 → 11 new, **all 11 already present at the restyle-merge commit
  a7a54e3bf** (restyle r1/r2/r3/r5); 0 come from this branch's fixes.

## Acceptance
Not run from the cloud (no compiler). Coordinator: please compile and send exact errors. Routes are in
`docs/port/accept/f-player-content-a.txt`.

---

## Round 2 (2026-11-24)

- **Brief:** `design/handoff-r2:docs/briefs/fix-r3-round2.md` (+ `wave-x10.md`, `owner-decisions-1124.md`).
- **Sync:** merged `origin/ui/combined-r7` (Core K1–K10, W1 wiring, C7 MP assets). One conflict, `tools/check_typography_lint.py`,
  taken from combined-r7 (newer). Typography lint passes after the merge.
- **Cursor wiring list:** there is no `cursor/wire-player-content` branch and `cursor-core-player-content.md` lists no
  reserved call sites, so no call site was skipped for that reason. The App callers that receipt asks for are done below
  where they fall in this half.
- **Strings:** 11 new keys in `docs/port/strings/fix-r3-player-content-a.json` (en + zh-Hans), 25 in total.
- **Acceptance routes:** appended a Round 2 block to `docs/port/accept/f-player-content-a.txt`.

### Fixed in round 2

| id | what | files |
|---|---|---|
| Owner #6 / #3 / #12 | Host cancellation with refunds is money, so it is now TEST/DEBUG-only: `AppSession.activityHostCancelAccess` returns nil unless `ReviewedAreaSwitch.moneyPayments(apiHost:)` is open. That switch is off in Release and on the production host. The C1-4 footer and host-cancel section disappear with it. | AppSession |
| Owner #9 | Two-decimal money through the shared `MoneyDisplay` on this half's pages: activity price chip, pinned summary, share card and ticket rows; topic bar price and paywall price; home feed card and VoiceOver prices (`HomeFeedMoney`). Pricing already used `TopicPricingXcx` two decimals. | ActivityDetailView, ActivityPresentationComponents, TopicXcxSections, TopicDetailView, HomeFeedView |
| R7-PC-C1-3 (App) | A missing or unknown `isSignUp` (`.unavailable`) is a disabled "—" pill. It is never the wallet button, and the tile action skips it. | ActivityDetailView |
| R7-PC-B1-9 | Publisher row under the hero (MP `cy-avatar` + name + 发布) and the owner-only review chip (审核中 / 未通过 / 已下架 from `TopicDetail.ownerReviewLabel`). | TopicXcxSections |
| R7-PC-B1-15 | `pages/topic/index/index?via=session` → `SessionTopicDetailView(prefersSessionPicker:)` → bar `TopicXcxFacts.action(_, preferSession:)`. | MPReviewedPageScreen, PlatformConsumerSessionOwner, TopicDetailView, TopicXcxSections |
| R7-PC-B1-19 | A free-explore owner in lifecycle 2 (`ownerSaleRoute == .editor`) gets 去设置票价, which pushes the topic editor (`pages/publish/fabu/index?id=` + `scope=MERCHANT`). Other owners keep the pricing route. | TopicXcxSections, TopicDetailView, PlatformConsumerSessionOwner |
| R7-PC-B6-1 / B6-2 (App) | `pages/topic/catalog/index`: a canonical `id` opens the topic; anything else hands off to the 首页 tab. | MPReviewedPageScreen |
| R7-PC-B1-17 | 路线配置中 now has 浏览其他主题. It switches to the 发布/模板 tab, which is the MP `goTopicList` → `pages/template/index`. | TopicXcxSections |
| R7-PC-B4-4 (rest) | On a confirmed price, a success toast shows the server message (default 终价已确认，请等待开售审核, never 已开售), then the page returns after 2.5 s. A 支付资质 message gets the 终价已确认 / 知道了 modal first. The reason confirm is disabled was already shown (`publisher.phaseBlocked`). | PublisherLifecycleViews |
| R7-PC-A8-5 | When the write is gated, the disabled 用这个模板 and share sit in one head row. With the live adoption flow, its section stays below because it carries plan and progress state. | DiscoveryTemplateDetailView |
| R7-PC-A8-2 (part) | Node images open the full-screen `NativeMediaGallery` over all node images (MP `previewNode`). The top mosaic is not done. | DiscoveryTemplateDetailView |
| REV-B B-03 | Already mounted on combined-r7 (`TopicDetailView` `TopicCastRow` from `TopicDetail.castConfig`). Display only, with no live cast backend call (owner #7). | — |
| REV-B B-04 | Chapter-card images drop `media-asset:N` references, and plain lists strip `[ ] " '`, so the route cover is the fallback, as in the MP. It is a logic-only Core change (no type change). **Cursor:** add the `media-asset:1,https://x/a.jpg` test. | Core/TopicChapterCards |
| REV-B B-05 | A chapter card with no chapter or route image shows the MP `route_city_cover.png` (`MPAsset.BannerCover.routeCityCover`). | TopicChapterCardsSection |
| REV-B B-06 | 出发前 「含 …」 says 「N 个章节」 (story + endings, no breakdown) and 「N 个节点」 (new `topic.depart.stops`). | TopicXcxSections |
| REV-B B-07 | Review header: average, then round(average) MP `star-filled` icons, then 「基于N条评论」. | TopicReviewsContent |
| REV-B B-09 | Receipt correction: 出发前 never lists seat products in the MP (`buildDepartNotes` gets no products); they belong to the buy sheet (commerce), not P3. | this receipt |
| Missing state | A signed-out topic detail now offers 登录 (→ 我的), like the activity detail. | PlatformConsumerSessionOwner |

### MP assets applied (mapping.md rows)

- [x] `MPAsset.FeatureIcon.iconMember`: 首页 player badge (`pages/index/index.wxml:46`)
- [x] `MPAsset.AvatarDefault.dProfile`: 首页 hero avatar default (`index.wxml:38`)
- [x] `MPAsset.BannerCover.homeBannerFriends` / `homeBannerClub` / `homeBannerMerchant`: 更多玩法 menu rows (`home-action-banner.js:21-35`)
- [x] `MPAsset.BannerCover.routeCityCover`: chapter-card fallback (REV-B B-05)
- [x] `MPAsset.FeatureIcon.iconStarFilled`: topic review stars (MP `star-filled`, REV-B B-07)
- [x] `MPAsset.FeatureIcon.book`, `interaction`, `magnifier`, `city`, `flashlight`, `star`, `explore`: template detail and topic-template section headers (`templatedetail.wxml:72-210`, `topic-detail/index.wxml:59,83`)
- [x] `MPAsset.FeatureIcon.pagesTemplatedetailArtCatCity`: topic-template head cover when there is no cover (`topic-detail/index.wxml:31`)
- [ ] `TabIcon.tplTabTopic` / `tplTabGame`: the shelf switch is a native segmented `Picker`, which can show text or an image but not both. Kept as text.
- [ ] Shelf / game cover art (`shelf/art.js`, `game-covers.js`, ~90 rows) and template category art (`templatedetail.js:103`): these need the MP name → art tables ported first (same blocker as R7-PC-A2-3/A2-6). Next pass.
- [ ] `FeatureIcon.iconViewers`, `iconStar`, `BannerCover.recoHero`, `homeRouteCityPlaceholder` (home cards): covers draw through the shared design-system `CYImageCard` / `CYCarouselSlide`, which have no fallback-image input. A design-system change was left to the owner of those components.
- [ ] `MapMarker.dSmapicon` / `iconMap6` (search map), `FeatureIcon.iconCat` (search): `SearchMapExplorerView` and `GlobalSearchView` are whole-file hash-pinned (see round 1).
- [ ] merchantinfo icons (`iconQa*`, `Other.clock/location/people/xjt`, `dWeihao`): `MerchantContentViews.swift` is hash-pinned (`test_merchant_station_submission_import`).
- [ ] `FeatureIcon.iconBm` / `iconBmOn` (收藏): the favourite control is still blocked (R7-PC-B1-1, the like factory pin).
- [ ] `iconStar1/2` (review composer), `iconPhoto2`, `iconTodoCheck`, `iconCreatorSpark`, `pagesTopicImagesIconCopy`: on the parked MPGap composer / project-join (Gemini).

### Owner decisions (11-24) in this half

- #2 platform-pass reads, #4 upload retry, #5 merchant approvals: nothing in this half.
- #3 / #6 / #12 money TEST-only: host cancel+refund now TEST/DEBUG-only (above). Pricing confirm stays behind its existing grant.
- #7 cast on fixtures: the topic `TopicCastRow` only displays `castConfig`; no voice or profile call is mounted from this half.
- #8 GPS arrival lock and #10 game-kit pilot gate: play runtime (play-roam / Cursor), not in this half's pages.
- #9 two decimals: done on this half's pages (above). `E1Money.yuan` and `QuestifyCardText.amount` (shared, used by other areas) still format 0–2 decimals. **Cursor / coordinator:** switch those two helpers to `MoneyDisplay` once, globally.

### Still left after round 2

| id | reason |
|---|---|
| R7-PC-C1-8 活动不存在 | Core folds `data:null` into `APIError.malformedResponse`, so the App cannot tell "not found" apart. **Cursor:** throw a distinct not-found error from `ActivityService.detail` when `data` is null. |
| R7-PC-C1-2 guest read | Core allows a nil token, but `AppSession.activityDetail` still requires an account. The guest-read policy is the open owner item (R7-PC-B1-4), so the signed-out activity and topic pages keep a sign-in state, now with a 登录 action. |
| R7-PC-B1-21 locked chapter rows | `TopicChapter` has no `locked` flag (MP `topic-motion.js:160` reads `c.locked`). **Cursor:** decode it. |
| R7-PC-B1-13, B2-3, B3-3, A3-4, A4-1, A5-6, A8-2 mosaic, A2-3/A2-6 | M-sized or blocked as in round 1 (hash pins for search; art tables for the shelf). |
| R7-PC-B3-4, A8-3, C1-9 | Still need Core: `MerchantApplyXcx.allMissing`, `PublicTopicTemplateDetail.isOfficial`, `organizerShopLogo` (none on combined-r7). |
| R7-PC-B4-5 | The pricing page still has no topic read to know productType 2. |
| Round-1 pin-blocked list | Unchanged on combined-r7 (no re-pin landed); still waiting on Cursor. |

### Written, then reverted because a pin forbids it (round 2)
| change | pin |
|---|---|
| Activity ticket-row price through `MoneyDisplay` | `test_activity_design_structure.test_nullable_ticket_values_do_not_gain_invented_availability_or_currency` requires `E1Money.yuan(ticket.price, locale: locale)`. Re-pin, then switch (or switch `E1Money` globally). |
| A separate VoiceOver label for the "—" CTA | `test_activity_design_structure` allows only catalog keys in `ActivityDetailView`; the pill speaks `activity.cta.unavailable`. |
| Comment lines on the host-cancel gate | The `AppSession.swift` ceiling is 8171 lines (`test_home_city_location_consent`, `test_ugc_1_2_completeness`); the gate is one line. |

### Local gates (round 2, cloud, no compiler)
- `tools/contract_ratchet.py --check`: **200 failing, the same 200 as the merge commit 24fa46cb7** (combined-r7 + this branch before round-2 edits). The 16 above baseline 184 all come from the combined-r7 merge; **0 are new from this branch**.
- `tools/check_typography_lint.py`: PASS.
- `tools/check_a11y_lint.py`: nothing new from this branch's lines. `HomeSearchTabParityViews.swift` `readAvailability` image is a baseline row that combined-r7 restyled (`.font` → `.cyText`).
- `tools/check_search_map.py`: fails `local filters and first-page scope` **on the merge base too** (combined-r7, Cursor A5-7 page size).
- Acceptance and compile: not run from the cloud. Coordinator, please compile and send back the exact errors.

---

## Round 3 (2026-11-24 evening)

- **Brief:** `design/handoff-r2:docs/briefs/fix-r3-round3.md` (+ `wave-x10.md`, `fix-r3-round2.md`, `owner-decisions-1124.md`).
- **Sync:** merged `origin/ui/combined-r7` @ `b0ac0108d`. No textual conflict. Before the final push it is merged again.
- **Strings:** 8 new keys (`discovery.shelf.group.shop/team/city`, `discovery.shelf.allTopics/withinTwoHours/scifi/cityMemory/solo`) in `docs/port/strings/fix-r3-player-content-a.json`, en + zh-Hans (32 keys in total). Integrator: add them to `Localizable.xcstrings`.
- **Acceptance routes:** Round 3 block appended to `docs/port/accept/f-player-content-a.txt`.

### Round 3 · re-applied

Each round-2 commit (`5be7191a3`, `6d471bc22`, `f5b96cf93`, `505f1174c`, `d2400b000`) was diffed against the new base. Only
`TopicXcxSections`, `PlatformConsumerSessionOwner` and `TopicDetailView` lost hunks. Everything else is present on the base
(the other "Cursor side" files in the brief are not in this half).

| id | how it was re-applied | file |
|---|---|---|
| R7-PC-B1-9 publisher row + owner review chip | Put back under the hero, unchanged (Core `publisher` / `ownerReviewLabel` are still there). | TopicXcxSections |
| Owner #9 bar price | `MoneyDisplay.yuan` again in `TopicXcxActionBar.priceText` (Cursor's side had the locale currency formatter, 0–2 decimals). | TopicXcxSections |
| R7-PC-B1-19 去设置票价 | Kept **Cursor's** route: `openEditor` + `\.topicEditorDestination` (sheet). Only the label went back to `topicXcx.cta.editPrice` (去设置票价, MP `index.js:1177`), not `topicXcx.cta.edit` (Edit topic), plus the `pageTemplateControl` label. | TopicXcxSections |
| R7-PC-B1-15 `via=session` | Covered by **Cursor's** `preferSession` (`MiniProgramPageLink.opensSessionPickerFirst`). My `prefersSessionPicker` and `ownerEditorDestination` / `showsOwnerEditor` push in `TopicDetailView` were left behind by the merge as a second implementation, so I removed them. | TopicDetailView |
| R7-PC-B1-17 浏览其他主题 | Put back in `TopicXcxRouteSection` (`rootTabSwitch(.publish)`). | TopicXcxSections |
| REV-B B-06 出发前 copy | 「N 个章节」(story + endings) and `topic.depart.stops` (「N 个节点」) again. | TopicXcxSections |
| Missing state: signed-out topic | 登录 pill (→ 我的) under the unauthorized message again. | PlatformConsumerSessionOwner |
| R7-PC-C1-2 guest read / C1-3 "—" | Not re-applied: **Cursor's** wiring supersedes mine. Guests read `api/activity/info` with a nil token and 立即报名 calls sign-in. The "—" pill is disabled, with id `activity.primaryAction` and a catalog label. | — |

### Fixed in round 3

| id | what | files |
|---|---|---|
| Flow gap PC-A-7-2 (flows-g1 `topic-preview`) | `pages/templatedetail/topic-preview/index` now mounts Gemini's `TopicTemplateDeckPreviewView` (card deck) through `DiscoveryTopicTemplateDeckHost`. The host re-projects the public `PublicTopicTemplateDetail` into `TopicTemplatePreviewData.fromWire`. 查看详情 pushes topic-detail. 用这个模板 shows only when the adoption write is live and `readonly≠1`; it also lands on the detail, which owns the adoption flow. `topic-detail/index` keeps the detail. It has its own loading (skeleton), error (retry) and session-changed states. | DiscoveryTemplateDetailView, MPReviewedPageScreen |
| Flow gap PC-B-1-5 (flows-g1 `topic/index`) | The 路线 tab mounts `TopicRouteMapAndTeamsSection` with one numbered pin per stop that has a valid coordinate, and a polyline for fixed routes. Tapping a pin opens Apple Maps (`TopicStopMapsLink`). Progress and teams stay off, because the detail has no play read. | TopicXcxSections |
| R7-PC-B1-13 | Free-explore session rows are buttons (MP `bindtap="bmClick"`) that open the in-page session picker. They are one combined button each, with id `topic.session.row`. The MP also preselects the tapped ticket **by name** in the picker. The app's preselect (`registrationPreselectedTicketID`) is by id and is set inside `ActivityDetailView`, so name preselect is a half-b change (`RegistrationSheetView`). | TopicDetailView |
| MP assets: shelf art | New `TemplateShelfArt`, a port of `shelf/art.js` THEMES (18 topic names, exact match then prefix match like `themeKey`) and `game-covers.js` GAMES (25 play titles), mapped to the bundled `MPAsset.BannerCover.*` covers. A known title always uses the bundled cover, as in the MP ("不依赖接口回来的 imgUrl"). Applied to the template shelf (hero card + row thumbs, topics and plays), the play-template detail head (MP `detailCover`) and the topic-template detail head (MP `topicArt`). | TemplateShelfArt (new), DiscoveryTemplateBrowserView, DiscoveryTemplateDetailView |
| MP asset: home card default | `HomeFeedShelfCard` uses `CYImageCard.fallbackArtwork(MPAsset.BannerCover.homeRouteCityPlaceholder)` (MP `index.wxml:216`). The design system added that input after round 2. | HomeFeedView |
| R7-PC-A2-3 / A2-6 | The default 玩法 view is now the MP `buildGames`: the 精选 paging rail (`FEATURED_GAMES` order, bundled covers, page dots) and one shelf each for 到店互动 / 小队协作 / 城市探索 (`GROUPS`, through Core `SearchDiscoveryFilterParity.games(_, matching: "shop"/"team"/"city")`). Both are built from the paged `api/template/list` rows (Core A2-1). `api/template/homeData` sections remain only as the fallback when the list has no shelf play, as in fixtures. While the list loads, the page shows a skeleton. | DiscoveryTemplateBrowserView, TemplateShelfArt |
| R7-PC-A2-3 (topic tab) | MP `buildTopics`: with no tag and no name search, the topic tab shows the 精选 paging rail (`FEATURED_TOPICS` order, then the rest, capped at 7), 全部主题, and the `TOPIC_SHELVES` rows that have content (两小时内玩完, 科幻异常, 城市记忆, 一个人也能玩). The shelves reuse Core `SearchDiscoveryFilterParity.topics(_, matching:)`. Secondary shelf cards get `discovery.topic.<shelf>.<id>`, so `discovery.topic.<id>` stays unique for the UI tests. A tag or a search keeps the single hero list. | DiscoveryTemplateBrowserView, TemplateShelfArt |
| R7-PC-A8-2 (rest) | Closed as obsolete. The current MP `topic-detail/index.wxml` has no image mosaic (the owner simplified it on 11-14). The node-image gallery is done (round 2). | — |

### MP assets (mapping.md), round 3

- [x] `BannerCover` topic covers (18) and game covers (25), from `shelf/art.js:15` and `shelf/game-covers.js:2`.
- [x] `BannerCover.homeRouteCityPlaceholder`: home shelf card default.
- [ ] `TabIcon.tplTabTopic` / `tplTabGame`: the shelf switch stays the native segmented `Picker`. Three UI tests (`PublicPlayTemplatePresentationFlowTests`, `TemplateTabStaffFlowTests`, `TopicTemplateNameSearchFlowTests`) find it as `segmentedControls["discovery.shelf"]`, and a segmented segment cannot show icon and label together. Switching to the MP icon tabs needs those tests moved first (coordinator).
- [ ] `BannerCover.recoHero` (编辑精选 carousel default): `CYCarouselSlide` has no fallback-image input (design-system owner).
- [ ] `FeatureIcon.iconViewers` / `iconStar`: the app's home cards have no distance or rating line to carry them.
- [ ] Leaderboard memojis and member-journey icons: not on this half's pages (official-detail is C4 = half b; journey is member).
- [ ] Search map / search / merchantinfo icons: still hash-pinned files (see round 1).

### Flow gaps (flows-g1 `[GAP-CLAUDE]`) in this half

| edge | status |
|---|---|
| `templatedetail/topic-preview` deck | **mounted** (above) |
| `topic/index` route map | **mounted** (map part); `RegistrationGapSections` belongs to baoming (C2, half b) |
| `templatedetail/shelf` → topic-preview / detail | The shelf opens the topic-template detail in place. The deck is reachable by the `topic-preview` link. |
| `search2` / `searchmap` → `SearchMapExplorerGapView` | Not mounted. `GlobalSearchView.swift` / `SearchMapExplorerView.swift` are whole-file hash-pinned (`test_global_search_category_recovery`). The app's own explorer already opens topics. |
| `topic/merchantapply` → `MerchantApplyPickerGapView`, `MerchantJoinContactHostButton`, success summary (R7-PC-B3-3) | Not mounted. The host is `MerchantContentEditView` in `MerchantContentViews.swift`, hash-pinned (`test_merchant_project_workspace_entry`, `test_merchant_station_submission_import`). The merchant writes stay owner-gated. |
| `topic/pricing` → `TopicPricingGapSection` | Not mounted. The pricing page has no topic or ticket read to fill per-ticket fields, sale status or fee rate. Core can now send `ticketPrices` (R7-PC-B4-2), but it is still behind the pricing grant. |
| flows-g2 (ops) | Not this area. |

### Review / audit rows

- REV-B B-02…B-09: all present after the re-apply (B-03 is Cursor's `TopicCastRow` mount).
- REV-B B-16 (FE-G5 perk line on the route detail): `TopicMerchant` has no perk name / 已含 / 需消费 / 需预约 fields. **Cursor:** decode them on topic nodes' merchants; the ticket-wallet half of B-16 is not this half's page.
- R7-PC-B4-5: free-explore owners now go to the editor (B1-19), not to pricing. The bare `pricing?topicId=` link still has no `productType`. **Cursor:** decode `productType` on `PublisherPricingPreview` (MP `pricing/index.js:144` reads it from the preview).

### Still left after round 3

| id | reason |
|---|---|
| R7-PC-B1-21 | `TopicChapter.locked` still not decoded (MP `topic-motion.js:160`). **Cursor.** |
| R7-PC-A8-3, C1-9, B3-4, C1-8 | Still need Core: `isOfficial`, `organizerShopLogo`, `MerchantApplyXcx.allMissing`, a distinct not-found error. None are on combined-r7 @ b0ac0108d. |
| R7-PC-A1-1 relocate, A1-7 share, A3-4, A4-1, A5-6, B2-3, B3-3 | Unchanged from round 2 (no API, or hash-pinned files). |
| Gemini MPGap copy | `TopicTemplatePreviewData.fromWire` builds Chinese-only strings in Core (「N 分钟」「N 章节」); the deck therefore shows Chinese under en. **Gemini:** move them to catalog keys. |

### Local gates (round 3, cloud, no compiler)
- `tools/check_typography_lint.py`: PASS.
- `tools/check_a11y_lint.py`: no row from this branch's files (17 new rows are all elsewhere, same as the base).
- `tools/contract_ratchet.py --check`: **217 failing, identical set to the base `ui/combined-r7` @ b0ac0108d (217, 33 above baseline 184)**. 0 new from this branch. (A first run caught one catalog-key failure from a new VoiceOver hint key; the hint was dropped.)

## Round 4 (2026-11-25)

- **Brief:** `design/handoff-r2:docs/briefs/fix-r3-round4.md` (+ `wave-x10.md`, `owner-decisions-1124.md`). **Base:** `origin/ui/combined-r7`
  (it already contains this branch's round 3; the merge fast-forwarded). Gemini is out of quota, so this round also takes the
  Gemini MP-alignment work (flows, images, copy) for the 15 pages of this half.
- **Layer:** App only; no Core type changed. Every API used was grepped on the branch (no compiler in the cloud).
- **Strings:** 18 new keys in `docs/port/strings/fix-r3-player-content-a.json` (en + zh-Hans); none collides with an existing key.

### 1. Flows (flows-g1 `[GAP-CLAUDE]` edges for this half)

| MP edge | status | files |
|---|---|---|
| topic-preview 「用这个模板」 → `topic-use-flow.adopt` → `publish/fabu?id=&scope=` | **Fixed.** The deck now runs the same adoption write (`TopicTemplateUseModel`, offline write opt-in, same requestId reuse) and pushes the copied draft into the topic editor. It used to open the detail page. Still shown only while the writer is live (`TopicTemplateUseFactory.isLive`); a refusal / unknown result is shown under the deck (MP toasts). | DiscoveryTemplateDetailView, MPReviewedPageScreen |
| topic-preview 「查看详情」 → `topic-detail?id=&scope=&readonly=` | **Fixed (scope).** `scope` is now carried from the link into the detail page and its adoption write. | DiscoveryTemplateDetailView, MPReviewedPageScreen |
| topic-detail 「应用」 success → `publish/fabu?id=` | **Fixed.** `topicTemplateCopiedDestination` was never set anywhere, so a confirmed copy went nowhere. With no host override the page now pushes the editor through `topicEditorDestination`, which the two MP routes set. `scope` is passed (was `nil`). | DiscoveryTemplateDetailView, MPReviewedPageScreen |
| template 🔔 → `subpackageB/pages/im/list/index` | **Fixed.** flows-g1 said OK, but the template tab had no inbox entry. Toolbar bell (MP `icon_bell.svg`) pushes `SessionMessagingHome` on all four session entries. | DiscoveryTemplateBrowserView, PublishTabRootView, SessionHomeFeedView, MPReviewedPageScreen |
| search2 → searchmap, searchmap pin → topic, back | **Already OK.** `GlobalSearchView` has the map pill (`search-actions__map`) and `SearchMapExplorerView` routes `.topic` to `SessionTopicDetailView`. `SearchMapExplorerGapView` duplicates that screen, so it stays unmounted. | — |
| topic/index → TopicRouteMapAndTeamsSection | Already mounted in round 3 (PC-B-1-5). `RegistrationGapSections` belongs to `RegistrationSheetView` (activity sign-up, half b). | — |
| merchantapply success → 查看承接进度 (`merchantinfo?topicId=&scope=MERCHANT`) | **Blocked.** It was written, then reverted: `App/MerchantContentEditor.swift` is whole-file hash-pinned by `test_merchant_station_submission_import.test_exact_single_editor_inverse_preserves_every_other_hunk`, and the edit added a new ratchet failure. Needs the pin re-recorded, then the follow-up below. | — |
| merchantapply `MerchantApplyPickerGapView` / `MerchantJoinContactHostButton` | **Not mounted.** The Gemini map picker is a stub (fixed Shanghai coordinates, no search), and the photo picker has no upload client. Mounting it would submit wrong coordinates. The host editor is hash-pinned too. **Gemini/Cursor:** a real place picker (the editor already takes `placeSearch: PublishingPlaceSearching`) and an upload client. | — |
| pricing save → topic/index | **OK.** Confirm toasts and dismisses back to the opener. A deep link opens over the previous page, the same as MP `redirectTo` from the user's point of view. | — |
| pricing `TopicPricingGapSection` (multi-ticket prices, sale status, fee rate) | **Not mounted.** Nothing produces `TopicPricingPerTicketField` / `TopicPricingExtraStatus`, and the pricing confirm still sends `ticketPrices: []`. **Cursor:** decode the MP `tickets`, `saleStatusText`, settlement-pending and fee-rate fields on the pricing read. Money stays TEST-only. | — |

### 2. Image parity (every MP image slot on the half's pages)

| MP page | MP slot (src) | app now | where |
|---|---|---|---|
| index | 编辑精选 default `index-figma/reco-hero.jpg` | `MPAsset.BannerCover.recoHero` (carousel + AX rows) | HomeFeedView, CYGlassCarousel (`CYCarouselFallback`) |
| index | 附近活动 / 即将上线 default `route_city_cover.png` | `MPAsset.BannerCover.routeCityCover` | HomeFeedView, CYGlassCarousel |
| index | stream default `home-route-city-placeholder.jpg` | `MPAsset.BannerCover.homeRouteCityPlaceholder` (shelf + stream cards) | HomeFeedView |
| index | `cy_logo_mark.png`, `d_profile.png` avatar | already MP (round 3 / shared header) | — |
| index | `icon-viewers.png` (distance), `icon-star.png` (rating) | **no slot:** `HomeFeedItem` has no distance or rating. **Cursor:** decode `distance` / `rating` / `remainingTime`. | — |
| template | `icon_bell.svg` | `MPAsset.FeatureIcon.iconBell` toolbar button | DiscoveryTemplateBrowserView |
| search2 | `icon_cat.png` (category grid in the search bar) | **blocked:** `GlobalSearchView` / `SearchMapFilterSheet` are hash-pinned (`test_global_search_category_recovery`, `test_category_roam_registration`) | — |
| search2/result | `item.cover` / `item.art` (URL) | URL images, unchanged | — |
| searchmap | topic pin `pages/searchmap/images/d_smapicon.png` | `MPAsset.MapMarker.pagesSearchmapImagesDSmapicon` (was `/images/d_smapicon.png`, the roam hangout fallback, a different drawing) | CYMapChrome, SearchMapExplorerGapView |
| searchmap | `d_location2.png`, `icon_map6.png` | already MP | CYMapChrome |
| templatedetail | cover fallback `sceneIcons[0] \|\| art/cat/other.png` | `TemplateSceneArt.icon(first scene)` (MP `SCENE_ICON_RULES`, 17 category arts + other) | DiscoveryTemplateDetailView, DiscoveryTemplateDetailParitySections |
| templatedetail | 分类与适用场景 per-chip `sceneIcons[i]` | icon row with one 3D art per chip (was a joined text line) | DiscoveryTemplateDetailParitySections |
| templatedetail | 创作者说 `art/3d/bulb.png` | `MPAsset.FeatureIcon.bulb` header | DiscoveryPlayTemplatePresentationView |
| templatedetail | book / magnifier / flashlight / star / interaction / explore / city | already MP (round 3) | — |
| topic-preview | `art/tab/check.svg`, `art/tab/clock.svg` | `pagesTemplatedetailArtTabCheck` / `…TabClock` (were SF `checkmark.circle.fill` / `clock`) | TopicTemplateDeckPreviewView |
| topic-preview | no-cover `cover-route.svg` | `MPAsset.BannerCover.coverRoute` (was the home placeholder photo) | TopicTemplateDeckPreviewView |
| topic-detail | `art/cat/city.png`, `book.png`, `explore.png`, star | already MP (round 3) | — |
| topic | favourite `icon_bm.svg` / `icon_bm_on.svg` | `MPAsset.FeatureIcon.iconBm` / `iconBmOn` (were SF bookmark) | TopicXcxSections |
| topic | no-cover `cover-route.svg` | `MPAsset.BannerCover.coverRoute` (was SF curve-path glyph) | TopicDetailView |
| topic | 评价路线 stars `icon_star1.png` / `icon_star2.png` | five MP star buttons (was a 1–5 Picker), VoiceOver 「评 N 星」, 44 pt | ContextualReviewComposer |
| topic | `icon_photo2.png` (review 添加图片) | **no slot:** the review composer has no photo upload | — |
| topic | buy-option `icon_one/two/team.svg` | **not in the asset catalog.** **Cursor (C7):** import `pages/topic/images/icon_{one,two,team}.svg`. | — |
| merchantinfo | `merchant-guide/{clock,location,people}.svg`, `xjt.png`, `d_weihao.png`, quick actions `icon_qa_*` | **no slot:** `MerchantContentDocumentView` has no chapter-guide cards or quick-action grid (the merchant-guide layout is not ported) | — |
| merchantapply | `shop.cover` | **no slot:** no shop card in the editor (hash-pinned) | — |
| pricing, partner, catalog | no images (catalog is a redirect shell) | — | — |
| activity/detail | avatars with empty fallback, `cy-icon image` | `cy-icon` is the MP UI glyph set (coolicons), so it stays SF Symbols as system glyphs | — |

### 3. Copy (MP text = app zh-Hans)

| MP | key | where |
|---|---|---|
| topic 评价路线 sheet title / 请输入您的评价内容... | `context.review.topicTitle`, `context.review.topicContents` (topic target only) | ContextualReviewComposer |
| topic aria 收藏主题 / 取消收藏 | `topic.favorite.add` / `topic.favorite.remove` (were 收藏 / 已收藏) | TopicXcxSections |
| topic aria 分享主题 | `topic.share.mp` (was 分享) | TopicXcxSections |
| 评 N 星 | `context.review.starLabel %lld` | ContextualReviewComposer |
| templatedetail 玩法没能打开 | `discovery.play.openFailed` (`DiscoveryErrorView.failureTitle`) | DiscoveryComponents, DiscoveryTemplateDetailView |
| topic-detail / topic-preview 主题模板没能打开 | `discovery.topicTemplate.openFailed` | DiscoveryTemplateDetailView |
| topic-preview 正在加载主题模板 | `discovery.topicPreview.loading` | DiscoveryTemplateDetailView |
| template 消息 (bell aria) | `discovery.templateTab.inbox` | DiscoveryTemplateBrowserView |
| merchantapply 商家报名 / 修改报名 / 提交成功 / 修改已保存, 放弃这次报名？… | **blocked** (written, then reverted: hash pin on MerchantContentEditor) | — |
| search2 类别加载失败, 最低/最高区间, result 没有更多了 / 重新搜索, searchmap 地图搜索 | **blocked** (hash pins on GlobalSearchView / SearchMapFilterSheet / SearchMapExplorerView, as in round 2) | — |
| the other ~120 merchantinfo / merchantapply / pricing rows in `copy-g1-player.md` | these MP features are not in the app (merchant-guide workflow, 分润 panel, supply ops) or are server messages. No app string to align. | — |

### 4. P2 / P1 (audit r7)
- Claude P2s of this half already closed in rounds 2–3: A1-5, A1-6, A2-4, A2-5, A2-6, A5-5, A6-3, A6-4, A7-2, A8-2 (gallery), A8-4, A8-5, B1-16, B1-17, B1-18, B1-19, B1-20, B1-23, B4-7.
- Still open, with reasons: A3-4, A3-5, A4-3, A4-4, A5-6 (hash-pinned search files); A1-7 (no public share URL); A1-8 (superseded by the
  native large-title ruling); A2-7 (`SocialGuideTemplateSection` is half b); A5-7, A8-3, B1-21, B4-5/B4-6, C1-9 (Core decode, Cursor);
  B1-22 share poster (`TopicSharePosterCardView` builds the QR from the URL only; the MP poster needs `wxacode`, so not mounted).
  The owner rows (A1-9, A2-8, C1-10) are unchanged.
- No open P1 in this half has an App-only fix left. The rest are Core or owner lines, listed in the round 3 table.

### 5. Accessibility lint
- `python3 -B tools/check_a11y_lint.py`: **1 row, not from this branch**: `App/ClubKit/ClubWorkbenchKit.swift:261` (club-a round 3, on the base).
  It is left to the club agent to avoid a merge conflict. Every image this round adds is `.accessibilityHidden(true)` placed after `.resizable()` / `.scaledToFit()`.
- `tools/check_typography_lint.py`: PASS.

### Requests
- **Cursor:** `HomeFeedItem` distance / rating; pricing read `tickets` + sale / settlement / fee fields; import `icon_one/two/team.svg`;
  re-record the `MerchantContentEditor.swift` pin so the merchantapply nav titles, discard copy and 查看承接进度 can land.
- **Gemini:** a real place picker plus an upload client for `MerchantApplyPickerGapView` before it is mounted.
