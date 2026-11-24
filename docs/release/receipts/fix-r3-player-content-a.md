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
