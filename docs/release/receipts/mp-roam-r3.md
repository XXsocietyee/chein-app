# mp-roam — round 3 (2026-11-27)

Branch `mp/r3-roam` from `origin/ui/combined-r7` (re-merged 11-27, clean). Scope: tab 漫游 (`pages/roam/index`) and `subpackageRoam/*`.
Source of truth: `origin/mp-source:chengyinhub-xcx`. For each MP page the `.wxml` sections were listed top to bottom and
compared with the native screen that ships today (the 漫游 tab root is `NativeR2/MapHome`, `NativeR2Flags.mapHome` on).
No Swift compiler here: edits mirror existing patterns; nothing deployed; merchant and story-flow untouched.

## MP page → native view → differences → fixed / not

| MP page | Native view | Differences found (MP order / fields / states / targets) | Status |
|---|---|---|---|
| `pages/roam/index` 开始 (intro) | `NativeR2/MapHome/RoamMapHomeSheet.swift` | 1. MP shows `需要定位才能开始漫游 · 去设置` at the top of the page, above the tickets; native showed it inside the 附近 list (below the 漫游 actions). 2. MP `cy-error 上次漫游需要确认 · 确认漫游记录` above the tickets; native map home had no recovery read. 3. MP ticket NO.01 says `继续漫游` when a walk is unfinished; native always said Start roaming. 4. MP ticket NO.01 / NO.03 carry a sub line (走到哪，雾散到哪 / 查看已加入和申请中的队伍); native rows had none. | Fixed: location section moved to the top (also offers 选择区域); recovery read wired (`RoamHomeRecoveryEntry`, same as the roam browser) → `roam.w208.recovery.needsCheck` + `确认漫游记录` → `RoamRecoveryView`; start row title `继续漫游` when `.recovered`; sub lines added. New dependency `RoamMapHomeDependencies.experienceReader` passed from `QuestifyApp` (`session.roamExperienceReader`). |
| `pages/roam/index` 开始 · `entry-peek` | `RoamMapHomeSheet` 附近 section | MP head has tabs 附近活动 / 本城推荐 (`entryCityLabel` = `<城市> · N 处推荐` in a catalog city) and the strip lists the entry read's activities + places; native r2 used a Maps-style all/activities/places/routes/teams picker and listed teams and route stops too. | **Fixed (round 3 continue):** the picker is replaced by the MP tabs (segmented, `city.roam.nearby`; a plain 附近活动 header when no city strip); 本城推荐 shows the shared `RoamCityGuideCards`, a tap opens the loaded place carrying the card's seed tag (else `roam.cityGuide.openFailed`, MP toast); the 附近活动 list shows activities + places only. 找队伍 still narrows the map to teams, with a 全部 row to return (`roam.mapHome.nearby.showAll`). Failed-state retry stays (MP cy-error). |
| `pages/roam/index` 开始 · `entry-peek` (legacy browser) | `RoamHomeTabsView.swift` `RoamEntryPeekView` | Loading said "Loading map results…" (`roam.loading`); MP aria 正在读取附近活动. Header refresh button is extra vs MP. | Fixed loading words (`roam.w208.entry.loading`). **Refresh removed (continue):** reloads come from the MP 重试 rows and `.task(id:)`. Unit test `RoamNearbyEventsRestoredDetailTests.testCurrentHTTPFailureRetiresCardThenOriginalRetryRecoversWithoutGrantExpansion` edited to reload via `roam.home.peek.teamsRetry` (same `refresh` action, same scope). |
| `pages/roam/index` 漫游护照 | `RoamHomePassportView` (in roam browser sheet, opens on 护照 tab) | Order matches: 4 stats (漫游 / 探店 / 活跃日 / 公里, `—` while loading) → tiles → plays (官方路线 after 官方活动). | No change needed. |
| `pages/roam/index` B1 live map / pcard / pbar | `RoamLiveSessionView.swift` | pcard 用时 / 地盘 / 距离 and 更多 · 暂停 · 拍照 already mirrored (design pass roam, ROAM-4). | No change this round. |
| `pages/roam/index` 结算 (`screen=='arrive'`) | `RoamFinishReportView.swift` | Date line, `zone · 自由漫游`, hero 处到达, six cells 公里 · 用时 · 探索度 · 邮票 · 探索值 · 勋章, stamp strip, route story, 漫游记录 exit already mirrored (design-r2-roam P16). MP 查看漫游数据 map button maps to the 漫游记录 exit. | No change this round. |
| `subpackageRoam/official-routes` | `RoamMapHomeRoutesList` (map home push) and `OfficialRouteListView` | Map-home list row lacked the MP cover and used its own meta; MP `metaText` = city · 公里 · 分钟. Legacy list: bare spinner while loading. | Fixed: row shows the route cover when `previewImg` exists and `OfficialRouteMeta.text` (MP metaText); legacy list loading says `officialRoute.list.loading`. Large title kept inline (house rule: pushed pages use inline titles; lint rejects `.large`). |
| `subpackageRoam/official-route` | `RoamMapHomeRouteCard` and `OfficialRouteDetailView` | Map-home card: subtitle was city only (MP metaText has distance + duration), no cover, header "Stops" without count (MP 节点（N）), stop rows lacked address and the 参考停留 label; empty stops sat outside the stops section. Legacy detail: bare spinner; empty stops as plain text (MP cy-empty). | Fixed all listed: meta line, cover, `节点（N）` header (shared key), address + `参考停留 N 分钟` per stop, empty state inside the section; legacy detail loading words + `ContentUnavailableView` for no stops. |
| `subpackageRoam/history` (`scene-roam-history`) | `RoamHistoryView` | MP loading `正在读取漫游记录…` in words; native bare spinner with a hidden label. Order (total km → 次漫游/家店/用时 → tools → month heads + run cards → empty / in-progress / load more) already matched. | Fixed loading words; en value now "Loading your roam history…". |
| `subpackageRoam/session` (`scene-roam-session`) | `RoamHistoryDetailView` + `RoamRecordedStats` | MP kv rows 总距离 / 时长 / 探店 / **到达 N 处** / 探索度; native lacked 到达. Loading said "Loading map results…"; MP 正在读取本次漫游. | Fixed: 到达 row from `RoamHistoryRecord.footprintCount`; `roam.session.loading`. The extra P8 "see collection" link stays (design-principles P8). |
| `subpackageRoam/poi-detail` (`scene-roam-poi-detail`) | `RoamItemDetailView` | MP order: node card + 收藏/导航/投一张 → 基本信息/地点详情 → 玩家评价 → footer. Native showed the extras block (which holds 玩家评价) before 你的状态 and 地点详情. Loading said "Loading map results…" (place and merchant retry). | Fixed: extras mount moved after 地点详情; `roam.place.loading` / `roam.merchant.loading`. |
| `subpackageRoam/citynode-code` (`scene-qr-citynode`) | `RoamCityVoucherCodeView` → `VerificationCodeView` | missing-param shell + 返回, voucher title/desc/countdown already mirrored. | No change needed. |
| `subpackageRoam/citystamp` | `RoamCityStampFlowView` / `RoamStampSlipView` | MP opens the camera first (cam → write) and puts the photo square inside the note header (`sgnote__h`: title + counter left, shot right; tap = 拍一张 / 重拍); native started at the write step with a 拍一张 row under the text. Drag-into-mailbox gesture not ported. | **Fixed (continue):** live routes (with a camera destination) push the camera once on open; the write step header is title + counter on the left and a 64 pt square on the right (the draft picture, else a dashed camera square) that reopens the camera, label 拍一张 / 重拍 (`roamSub.w208.stamp.retake`). Fixtures/tests have no camera destination, so they still open on the write step. Drag gesture still not ported (button send stays). |
| `subpackageRoam/my-teams` | `NearbyTeamsView` (tab 1) | MP `.mt-stats` sit under the title, above the 我的 / 附近招募 segment; native drew them inside the 我的 list below the picker. Rest (sign-in gate, skeleton, groups, 还没有队伍 + 去地图找队伍, 附近在招募) matched. | Fixed: stats moved above the picker on the 我的 tab (same identifiers, same zero-hides rule). |
| `subpackageRoam/nearby` | `NearbyTeamsView` (tab 0) / `NearbyTeamMapViews` | Filter row, list/map toggle, 附近暂无节点 empty, range/style sheets already mirrored (RNEAR-*). | No change this round. |

| `subpackageRoam/components/cy/scene-roam-stamp-album` (also `pages/play` scene) | `NativeR2/FreeExplore/NativeStampAlbumView` | MP order: 我的 / 收到的 tabs → 共 N 枚 → 3-col grid ending in a dashed 还没收到 cell (我的, read to the end) → error/skeleton/empty → `album-mini` 每投一张换来的那张，就落在这儿。 → paging → camera. Native: 共 N 枚 first, then a native-only 全部 / 邮票 / 照片 kind filter, then the 换来的邮票 row; no 还没收到 cell, no mini line; first-page loading said "Loading map results…". | **Fixed:** kind filter removed (MP has none); 收到的 entry row first, then 共 N 枚; dashed `NativeStampAlbumLockTile` (还没收到) ends the grid; mini line under the grid; first-page loading `roam.stamps.loading`. Received list kept as its own push (its own reader/scope lifetime) instead of an inline tab. Circle tiles and toolbar camera kept (native optimization). |
| `subpackageRoam/components/cy/scene-roam-task-list` | `RoamOfficialTasksView` | MP: search → tabs 进行中 / 即将 / 我的 → summary `<tab> · 共 N 个活动` → skeleton / error → stale banner or 正在更新活动列表… → list / empty. Native: menu picker with 4 buckets (extra 已结束), "Events N" row placed after the stale section, refreshing shown as a bottom spinner. | **Fixed:** segmented 进行中 / 即将 / 我的 (`tabTitleKey`), summary line (`official.summary.*`, search variant) above the stale section, `official.refreshing` line while a loaded list re-reads, spinner only before the first snapshot. UI test `RoamOfficialTasksFlowTests` edited: `select` taps the segment; the 已结束 step dropped; "Joined" → "Mine" (test name kept; it is pinned in CI manifests). |
| `subpackageRoam/components/cy/scene-qr-group-code` | club group-code page (`ClubGovernanceCommandForm`) | Owned by the club lane (`mp-club-r3.md` club/group-code row). | Not touched here. |

## Other roam loading lines (P10)

`roam.loading` ("Loading map results…") was shown on non-map screens. Replaced with what is loading:
`RoamPassportHistoryView` (×2, history), `RoamReceivedStampSectionView` and `RoamStampViews` album lifetime (`roam.stamps.loading`),
`RoamLocationSettingsDestination` (`roam.locationSettings.loading`), `RoamPassportPrivateToolsViews` (visible `roam.private.loading`);
the per-image placeholder in `RoamStampImage` is now a bare `ProgressView()` (the image has its own a11y label).

## Strings

New keys (en + zh-Hans) in `Resources/Localizable.xcstrings` and `docs/port/strings/mp-r3-roam.json`:
`officialRoute.list.loading`, `officialRoute.detail.loading`, `roam.session.loading`, `roam.place.loading`, `roam.merchant.loading`,
`roam.w208.entry.loading`, `roam.locationSettings.loading`, `roam.stamps.loading`, `roam.session.arrived`, `roam.session.arrivedValue %lld`,
`roamSub.w208.stamp.retake`, `roam.album.lockCell`, `roam.album.mini`;
updated en of `roamSub.w208.history.loading`.

## Gates (last run)

- `python3 tools/generate_project.py` — OK
- `python3 tools/check_scaffold.py` — PASS (20436 bilingual keys)
- `python3 -B tools/check_a11y_lint.py` — PASS, 0 new
- `python3 -B tools/contract_ratchet.py --check` — 52 failing, baseline 52, **new 0**

## Test files edited (MP-driven)

- `Tests/AppUnitTests/RoamNearbyEventsRestoredDetailTests.swift` — the removed peek refresh → MP team 重试 row.
- `Tests/AppUITests/RoamOfficialTasksFlowTests.swift` — segmented MP tabs, no 已结束.

## Round 3 continue (2) — MP roam components

| MP component (where MP mounts it) | Native view | Differences | Status |
|---|---|---|---|
| `roam-place-card` (pages/roam/index.wxml:615, pin tap) | `NativeR2/MapHome/RoamMapHomePlaceCard.swift` | MP order hero photo + name → address → rating · distance → 导航 / 分享. Native put the action row before the photo and had no 分享. | **Fixed:** photo section moved right after the title, before the action row; `ShareLink` 分享 for server POIs (`PublicContentShareLink.poi`, MP `shareKind` poi). Rating cell not added: the card reads nothing itself (rating would need a second `/api/city/nodes/{id}` read; it stays on 据点详情). |
| `roam-place-note` (wxml:50 entry place, :407 pace card) | new `NativeR2/MapHome/RoamMapHomePlaceNote.swift` (`RoamPlaceNote`, `RoamPlaceNoteRows`, `RoamCityGuideSources`) | Native showed neither the catalog 推荐理由 nor 资料来源, and printed the `roam:seed:v1:` import tag as a visible tag. | **Fixed:** seed tag → catalog reason (italic quote, selectable) → visible tags (seed hidden) → `DisclosureGroup` 资料来源 with 来源 N rows that copy the link (MP `copyEntrySource`). Sources generated from `subpackageRoam/data/roam-city-catalog.js` (33 places). |
| `roam-photo` (passport tiles / plays) | `RoamHomeTabsView.swift:613` | Already mapped (MP 3D icons for 历史 / 印章 / 目标, symbol fallback). | No change. |
| `route-thumb` (scene-roam-history run card) | `RoamRouteThumbView.swift` | Already mapped (real basemap with coordinates, sketch otherwise); no type/tracking violations. | No change. |
| `share-card` (pages/roam/index.wxml:1059) | — | MP roam mounts it but never sets `shareCard.show = true` (only the close handler writes it); roam sharing is the C2 share sheet (`RoamHistoryShareView`). | No change (nothing to show). |
| `slide-confirm` | — | Only MP use is `pages/play` 勋章颁发 Woo! (play flow, not the roam tab). Native one-off confirms use `CYGoHoldPill` / `confirmationDialog`. | Not in roam scope; noted for the play lane. |
| `map-weather` (wxml:251) | — | Decoration only (`aria-hidden`, no gesture, nothing shown on failure/clear/reduced motion); needs a new `/api/map/weather` read. | Not ported (no content; new endpoint would need review). |
| `roam-atmos-entry` (wxml:1076) | — | First-entry video transition, decoration only, skipped on slow net / reduced motion. | Not ported (no content). |
| `team-recovery-panel` (my-teams wxml:16, nearby:271) | `NearbyTeamViews.swift` `notice` | MP panel sits under the title, above `.mt-stats` and the segment; native notice (unknown-outcome chip + read messages) sat under the segment. Per-command 查询结果 / 原请求重试 / 终止未执行请求 rows exist on the team page (`TeamHomeView` C-D12); the list page has no persisted command store to list. | **Fixed position:** notice moved above stats and segment. Per-row list not added (needs a persisted team-command store; `TeamCommandWriter` keeps ids in memory per page). |
| citystamp drag note → mailbox | `RoamSubpageParityViews.swift` `RoamCityStampFlowView` | Not ported. | **Fixed:** the note (header + field) is one card with `DragGesture` (tilt ±6°, scale .88 while held); finger over the mailbox (MP `_overBox`: ±34 pt sides, 24 pt above) lifts the box and switches the hint to 松手，投进去; dropping there sends, else it springs back (no animation under Reduce Motion). MP `sghint` line added; 投进信箱 button kept for accessibility. |
| stamp album 收到的 | `NativeR2/FreeExplore/NativeStampAlbumView.swift` + `RoamReceivedStampMetadataDestination(inline:)` | Was a pushed page from a row. | **Fixed:** segmented `Picker` 我的 / 收到的 at the top (MP `cy-tabs`); 收到的 mounts the same received destination inline (reads only once chosen; same scope lifetime and privacy), title stays 集邮册. Legacy (flag off) path untouched. |
| P3 stamp camera after 存入集邮册 | `NativeStampCaptureView.swift`, `RoamStampCameraView.swift` | MP P3: 存入集邮册 → 已入册 → album. Native also showed a 投一张换一张 exchange section on the album camera. Caption was already citystamp-only (SCAM-2). | **Fixed:** exchange section only when `showsCaption` (citystamp route). |
| Re-scan: design system (OWNER RULE 2) | `RoamFinishReportView.swift`, `RoamNearbyParityExtras.swift` | Finish report hid the nav bar and drew its own share / 完成 bar in the content; nearby place-play eyebrow used `.tracking(0.6)`. | **Fixed:** share = `topBarTrailing`, 完成 = `confirmationAction`, inline nav bar, system back kept (typography lint); `.tracking` removed. |

New strings: `roam.placeNote.sources`, `roam.placeNote.source %lld`, `roam.placeNote.copyHint`, `roam.placeNote.copied`,
`roamSub.w208.stamp.releaseHint`, `roam.album.tabs`, `roam.album.tab.mine`, `roam.album.tab.received` (en + zh-Hans, also in `docs/port/strings/mp-r3-roam.json`).

Gates (after these commits): generate_project OK · check_scaffold PASS (20527 keys) · a11y lint 0 new · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (3) — remaining MP roam components + 附近活动 states

Base re-merged with `origin/ui/combined-r7` (clean).

| MP page / component | Native view | Differences | Status |
|---|---|---|---|
| `subpackageRoam/components/roam-city-strip` (pages/roam/index.wxml:144) | `App/RoamCityGuide.swift` `RoamCityGuideStrip.resolve` | Renders nothing; emits `stripFor(nearestCity ≤ 60 km || defaultCity())` + `inCity`. Native resolves the same way (first catalog city as default; tab label `<城市> · N 处推荐` only when `inCity`). | No change needed. |
| `pages/roam/index` entry-peek empty / loading | `NativeR2/MapHome/RoamMapHomeSheet.swift` `nearbyRows` | MP empty = `附近暂无活动` + `打开地图寻找附近活动`, the tap opens `subpackageRoam/nearby`; native said 拖动地图或扩大范围看看 with no action. MP skeleton aria 正在读取附近活动; native skeleton read 正在加载. | **Fixed:** `ContentUnavailableView` 附近暂无活动 (`roam.w208.entry.empty`) with a `.bordered` 打开地图寻找附近活动 action (`roam.w208.entry.emptyHint`, same keys as the legacy peek) → `.nearbyTeams` push (MP nearby page); skeleton rows carry `roam.w208.entry.loading`. |
| `subpackageRoam/components/cy/proto-cam` (roam :612, citystamp :15, nearby :258) | `RoamStampCameraView` / `NativeStampCaptureView` (system camera) | MP card: ✕ · 全屏 · 翻转 · 快门, `正在打开相机` / error text. The system camera gives close, flip and shutter in their standard places and is full screen; permission-denied state already offers 去设置 + 返回. | No change (native optimization: system camera instead of a custom panel). |

Gates: generate_project OK · check_scaffold PASS (20586 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

Every `subpackageRoam/*` and `pages/roam/*` wxml now has a row in this receipt.

## Round 3 continue (4) — live-roam 更多 / 设置 / 怎么玩 (pages/roam/index.wxml:674–802)

Base re-merged with `origin/ui/combined-r7` (clean).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` roam-more (更多 drawer, owner P-31) | `App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift` (opened from `RoamLiveSessionView` toolbar) | MP drawer = three rows 附近正在走的人 / 玩法说明 / 设置. Native showed one flat form (runners, presence, map, clear) titled 更多工具, and 玩法说明 was a second toolbar button with its own sheet. | **Fixed:** sheet root is a `List` with the three MP rows (`NavigationLink` pushes: runners list with a count, 怎么玩, 设置), title 更多; the live toolbar has one `ellipsis.circle` 更多 button (top-right, `roam.live.tools`); the separate rules button + sheet are gone (the rules are the 玩法说明 row, id `roam.live.rules` kept on it). Runners empty = `ContentUnavailableView`. |
| `pages/roam/index` roam-settings (设置) | `RoamSessionToolsSheetView.settingsForm` | MP rows in order 迷雾 → 地图样式 → 减少动态效果 → 附近的人位置分享 → 位置权限 / 后台持续定位 / 到点提醒 (开/关, tap opens system setting) → 清空本机缓存. Native: presence above map rows, no 位置权限 / 后台持续定位 / 到点提醒 rows (location row was never wired), clear-confirm copy differed from MP. | **Fixed:** MP order; three `LabeledContent` value rows read `CLLocationManager.authorizationStatus` (re-read on foreground) and open Settings; clear confirm uses the MP copy (迷雾、足迹、漫游记录、找回记录、分享链接失效) with 清空 / 先不清. |
| `pages/roam/index` roam-rules (怎么玩, 原型 howtoScreen) | new `RoamLiveHowToView` (same file) | MP: title 怎么玩, lede 走近就点亮，别的都不用管, three rows (走近店铺 55 米 / 点亮过的地方能拍照 / 别人点亮的地盘贴他自己的颜色, each with its sub line), footnote 关掉定位就不记录…. Native showed four different sections (自由探索 / 主动确认到点 / 结束与记录 / 定位由你控制). | **Fixed:** MP copy and order in one inset section (lede, three `Label` rows with tinted SF Symbols, footer = MP mini). 55 m = MP `REVEAL_M` = the reveal grid radius in `RoamLiveSessionController`. The presence privacy line still shows in the live sheet when presence is available and in the preflight rules (unchanged). |
| `pages/roam/index` roam-runner (原型 otherSheet, wxml:803) | `App/MPGap/PlayRoam/RoamRunnerDetailView.swift` | MP order: head (avatar ring · nickname · 正在附近漫游 · since) → g3 地盘 % / 探店 / 在走 → TA 点亮的店 photo strip → 打个招呼 / 看 TA 的漫游. Native: a `LabeledContent` 昵称 / 已走 list plus a loose 地盘 line; no head, no 探店, no shop photos (all already in `RoamNearbyRunner`). | **Fixed:** head row (initial/avatar circle, `.headline` name, `正在附近漫游 · since`), three stat cells only when present (`.title3` monospaced value, `.caption` label), horizontal 88 pt shop photos with the shop name as a11y label, then the existing actions. New keys `roamTools.runner.nearby`, `roamTools.runner.nearbySince %@`, `roamTools.runner.stat.territory/shops/walking`, `roamTools.runner.shops`. |
| `subpackageRoam/components/cy/scene-roam-session` 点亮地点 rows | `App/RoamHistoryViews.swift` `RoamHistoryDetailView` | MP `rw__row`: icon by `cat` (shop / park / landmark) + name + `catLabel || 点亮` line. Native: name only, park drawn as a pin. | **Fixed:** `leaf` for park, `点亮` caption under the name (existing key `roamSub.w208.share.lit`; local records carry no catLabel, so MP shows 点亮 too), row combined for VoiceOver. |
| `pages/roam/index` 打卡之后 (原型 f-checkin, wxml:649) | `RoamCheckinSheet` + `RoamCheckinStampRows` | name title, sub line, 城市贴纸 / 今日城市签 rows. | No change needed. |
| `pages/roam/index` 主题半屏 (原型 f-topic / f-city, wxml:618) | — (live map pins open the 附近 list) | MP: a pin with `topicId` reads `/api/topic/info-to-user` and shows tag 自由探索/城市定向 · title · desc · 场次 / 走法 / 距你 · 查看详情 → `pages/topic/index/index`. Native `RoamPlace` does not decode `topicId`/`productType`. | **Fixed (continue 8):** see the continue (8) row. |
| `subpackageRoam/components/roam-place-card` rating cell (was Not done) | `RoamMapHomePlaceCard` + `Core/RoamContracts.swift` `RoamNodeDetail` | MP `_loadRating`: server POIs read `/api/city/nodes/{id}` and show `averageRating` to one decimal (hidden when ≤ 0 or `ratingCount` ≤ 0), `—` when the read fails, before the distance. | **Fixed:** `RoamNodeDetail` decodes `averageRating` / `ratingCount` leniently (`try?`, string or int count) and exposes `ratingText` (MP `ratingText`); the card reads it with the existing `roamReader.roamNodeDetail` in `.task(id: pin.id)` for `type == 1` places only, shows ★ rating · kind · distance in the header, `—` on failure. New key `nativeR2.mapHome.card.rating %@`. |

New strings (en + zh-Hans, also `docs/port/strings/mp-r3-roam.json`): `roamTools.more.title`, `roamTools.more.howto`, `roamTools.more.settings`,
`roamTools.location.permission`, `roamTools.location.background`, `roamTools.location.arrival`, `roamTools.value.on`, `roamTools.value.off`,
`roamTools.clearCache.keep`, `roam.howto.title`, `roam.howto.lede`, `roam.howto.reveal %lld`, `roam.howto.revealDetail`, `roam.howto.photo`,
`roam.howto.photoDetail`, `roam.howto.colors`, `roam.howto.colorsDetail`, `roam.howto.mini`; updated `roamTools.clearCache.confirmMessage` (MP copy).
No motion added. No tests pin the removed rules sheet or the old tools layout.

Gates: generate_project OK · check_scaffold PASS (20669 keys, after merging the parallel lane) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (5) — live map maptip stack (pages/roam/index.wxml:465–490)

Base re-merged with `origin/ui/combined-r7` (xcstrings: both sides' keys kept; `playerGap.trail.share` from base, `roamTools.clearCache.confirmMessage` ours).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` maptip BL-02 `原地停留中` (`utils/roam-idle.js`) | `App/RoamLiveSessionView.swift` HUD header status tag | MP shows a status-only tip while walking (not paused) when the player moved < 3 m for 60 s; never changes time, distance or reveal. Native had no stationary state. | **Fixed:** `RoamLiveIdleDetector` (same 3 m / 60 s rule, fed by `owner.lastFix`, reset when the phase leaves `.active`); the HUD status tag reads 原地停留中 with a `mappin` symbol instead of 漫游中 while idle. The hold is measured against the clock (a `TimelineView` every 5 s, paused unless walking) because iOS may stop sending fixes while standing still. Same identifier `roam.live.statusTag`. |
| maptip 地图没加载出来 · 重试 / 据点 recovery / BL-03 sync offline | `RoamLiveSessionView` (`roam.live.recoveryHint`, `CYStatusOfflineBanner`) | Recovery confirm and the sync-offline banner already mirrored. Map-load watchdog: MapKit draws its own tiles, no black-frame state to explain. | No change. |

New string: `roam.live.idle` (Staying in place / 原地停留中), also in `docs/port/strings/mp-r3-roam.json`. No motion added (symbol swap only).

Gates: generate_project OK · check_scaffold PASS (20668 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (6) — intro tickets NO.01–03 on the map home (pages/roam/index.wxml:156–205)

Base re-merged with `origin/ui/combined-r7` (xcstrings: both sides' keys kept, ours for `roam*`).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` intro tickets (`introCards`: 开始漫游 / 打开地图·寻找组队 / 我的队伍, `introTeamsLive`) | `NativeR2/MapHome/RoamMapHomeSheet.swift` `roamSection` | MP has three tickets; native had four rows: an extra native 找队伍 row (narrowed the map/list to teams, with a count) before 打开地图·寻找组队, and the NO.02 row had no live line. | **Fixed:** the 找队伍 row and its 全部 return row are removed; NO.02 = 打开地图 with sub 寻找组队 (`roam.w208.intro.map` / `.sub`, same keys as the legacy tickets) → `subpackageRoam/nearby` push, plus `附近 N 支队伍在组队` (`roam.w208.intro.live %lld`) only when the team read returned rows (MP: empty string hides it). Teams stay as map pins. No new strings. |
| `pages/roam/index` entry-sheet `activity` (pin tap: cover · title · meta → 报名/查看 → attendees → 一起参加 · N 队正在招募 → 发起组队 → 现场动态) | map home `.event` push → event detail (`eventDestination`) | Native opens the full activity page (pushed in the panel) instead of the MP half-sheet summary. | Done in continue (7): the pin opens the map-home card, now in MP entry-sheet order. |

Gates: generate_project OK · check_scaffold PASS (20680 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0** (after rebasing onto the parallel run and re-merging the base).

## Round 3 continue (7) — map-home activity card vs MP entry-sheet activity (pages/roam/index.wxml:26–47)

Base re-merged with `origin/ui/combined-r7` (xcstrings: base values kept for shared keys, our new keys added).
Sweep `docs/sweeps/latest/mp-roam` (build 070117595) was taken under load (coordinator note: ignore); d6-roam is a synthetic fixture.

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` entry-sheet `activity` main view (pin tap: cover · title · meta → 去报名/查看详情 → N 人参加 → 一起参加 · N 队正在招募 → 发起组队 → 现场动态) | `NativeR2/MapHome/RoamMapHomePlaceCard.swift` (`.activity` pin; pushed in the map-home panel) | 1. No cover when the activity has none (MP uses the route illustration). 2. Registered + open showed 查看详情 as primary; MP shows no primary there and a 发起组队 row after the teams. 3. Participants sat inside the 时间 section. 4. Team header was a generic 队伍; rows showed only `n/max` without 队长审核 and the 申请加入 / 报名后申请 state; every row opened the team page (MP: canApply → team, else 去报名 → activity). 5. No 现场动态 section (Core dropped `postImages`). | **Fixed:** `RoamEntryCover` hero (route-city fallback); primary only when `primaryKey` exists; `N 人参加` row; header `一起参加 · N 队正在招募` (`roam.w208.entry.teams`), MP team rows (same keys as the legacy sheet) with MP targets; `发起组队` row (registered, not ended) → activity; 现场动态 section with up to 3 photos and the count, else 还没有现场动态. Core `RoamEntryActivity.postImageURLs` decodes MP `postImages || imageUrls || images` leniently; `liveMomentFeedState` resolves them (https only). The full event page itself stays mp-activity's. |

New strings (en + zh-Hans, also `docs/port/strings/mp-r3-roam.json`): `roam.w208.entry.momentsTitle`, `roam.w208.entry.moments %lld`, `roam.w208.entry.noMoments`.

Gates: generate_project OK · check_scaffold PASS (20692 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (8) — live-map 主题半屏 (pages/roam/index.wxml:618–645, index.js `openTopicView` 552–604)

Base re-merged with `origin/ui/combined-r7` (xcstrings: base values kept, our keys appended).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` 主题半屏 (原型 f-topic / f-city): a merchant pin with `topicId` reads `/api/topic/info-to-user` → cover strip → tag 自由探索 / 城市定向 · eyebrow `距离 · 不限顺序/按顺序` → title → desc → 场次 / 走法 / 距你 → 查看详情 (`pages/topic/index/index`); read fails or no name → plain shop card | `App/RoamLiveSessionView.swift` 附近 registered-shop rows (`/api/map/nearby`) → new `App/RoamLiveTopicSheet.swift` | Native shops never showed their topic: `RoamRouteNode` did not decode `productType`, no topic read, no 查看详情 target. | **Fixed:** Core `RoamRouteNode.productType` (lenient int/string, nil otherwise). Shop rows with `topicId > 0` get a `查看主题` borderless row (`roam.live.topic.entry`; the visit button is borderless too so the two taps stay separate in the List). `.sheet` with medium/large detents (OWNER RULE 2), inline title 主题 + 关闭; content in MP order with `RoamEntryCover` (only when the topic has a cover), tag capsule + eyebrow, `.sheetTitle` name, description, three stat cells (场次 = `activityList.count`, 走法, 距你 `N m` or `—`), then 查看详情 → `MPReviewedPageScreen(pages/topic/index/index)` via new optional `RoamDiscoverDestinations.topic`. Loading says 正在读取主题… (P10). Failure / no name closes the sheet, leaving the shop row (MP `_fallbackToShopCard`). Uses the existing `playRoamGapService.fetchTopicInfo` (`JSETTLE-3`). |

New strings (en + zh-Hans, also `docs/port/strings/mp-r3-roam.json`): `roam.live.topic.title/entry/loading/tagFree/tagCity/anyOrder/inOrder/sessions/walk/distance/open`, `roam.live.topic.meters %lld`.

Gates: generate_project OK · check_scaffold PASS (20724 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (9) — 附近正在走的人 = 原型 f-multi (pages/roam/index.wxml:309–328, index.js `openNearestRunner` / `openMultiView` 645–656)

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` 更多 → 附近正在走的人 → f-multi card: kicker 附近正在走的人 → `这片街区有 N 个人在点亮` (N counts the walker) → rows 你 (own 地盘 %, first) then each runner (avatar · name · pct); not sharing → settings; nobody → toast | `App/MPGap/PlayRoam/RoamSessionToolsSheetView.swift` `runnersList` (pushed from the 更多 sheet), fed by `RoamLiveSessionView` | Native listed runners only: no `这片街区有 N 个人在点亮` line and no 你 row with the walker's own 地盘 %. | **Fixed:** section header `roamTools.runners.lighting %lld` (runners + you), then a 你 row (`person.fill` tile, `地盘 N%` reusing `roamTools.runners.explore %lld`, clamped 0…99 like the MP) from `RoamLiveSessionController.explorationPercent` via new optional `ownExplorePercent` (nil in fixtures hides it); runner rows unchanged (still open the f-other runner page). Not-sharing and empty states unchanged (native text / `ContentUnavailableView` instead of MP toast). |

New strings: `roamTools.runners.lighting %lld` (Lighting up this block: N / 这片街区有 N 个人在点亮), `roamTools.runners.you`.

Gates: generate_project OK · check_scaffold PASS (20726 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (10) — live 附近商家 rows vs MP 商家横滑卡 (原型 f-fun / f-discover, pages/roam/index.wxml:500–532, index.js `openShopStrip` 497–530)

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` shop strip: per merchant name → distance (`dist`) → 去这儿 + BL-70 `N 人打过卡` face pile (`/api/roam/shop/visitors`, sourceType 2 = `regId`, first 8 shops) → photo; layer failure = one cy-error | `App/RoamLiveSessionView.swift` 附近 registered-shop rows (`/api/map/nearby`) | Native rows had the name and the 探店 action only: no distance, no visitor pile. Shared `RoamShopVisitorsStack` printed the Core label `N 人打过卡` verbatim (Chinese in the English UI). Layer failure row already mirrored (`roam.liveRead.shopsFailed`). | **Fixed:** distance meta (`N m`, from the server `distance`, hidden when unknown) and the visitor stack (sourceType 2, shop id = registration row, loaded once for the first 8 shops via the existing `RoamShopVisitorsModel` with `socialRoamCapabilities`; failure draws nothing like the MP). Stack label is now `roam.shop.visitors %lld` (N checked in here / N 人打过卡) everywhere it is used. 去这儿 stays the 探店 / 查看主题 actions (MP 去这儿 opens the poi detail or recentres the map; native rows have no map pin layer yet). Photo not shown (rows, not cards). |

Gates: generate_project OK · check_scaffold PASS (20727 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (11) — 首次发现 sheet (pages/roam/index.wxml:960–990, index.js 4643–4733) + 11-27 18:06 sweep

Base re-merged with `origin/ui/combined-r7` (xcstrings: base values kept, our 15 keys appended).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` 首次发现商家 ritual sheet: title 首次发现 → `dr-cover` (`poi.imgUrl`) → name → 选一份见面礼 → 领优惠券 · 做微任务 · (explore day: title or 看看自由探索, `N m · 自由探索`) → 先继续走 | `App/RoamFirstDiscoverySheet.swift` (`.sheet` from `RoamLiveSessionView`) | No cover: the sheet started at the name. Explore-day candidate with an empty title: MP shows it as 看看自由探索; Core `RoamService.exploreDay` drops it (`isDisplayable` needs a title). MP reads the candidate only after the shop visit is recorded; native reads it on open. | **Fixed:** cover section first (`RoamEntryCover`, 160 pt, only for a safe https `RoamPlace.coverImage`, id `roam.discover.cover`), then name / 选一份见面礼 / options / 先继续走 unchanged (already MP order, inline title + medium/large detents per OWNER RULE 2). **Not done:** empty-title explore day (Core + tests) and the visit-recorded gate (needs the visit result passed into the sheet) — compiled pass. |
| Sweep 18:06 `mp-roam/*-d2-roam.jpg` | `RoamHomeFixtureHostView` → legacy `RoamBrowserView` | The d2-roam fixture renders the legacy roam browser (inline 漫游 + ⋯), not the shipping tab root `NativeR2/MapHome/RoamMapHomeView` (full-screen map, allowed chrome in `check_design_consistency` TAB_ROOTS note). The shot does not show what players see. | **Not done:** a map-home design fixture needs `RoamMapHomeDependencies` fixture readers — for the coordinator / mp-nav (fixture router). |
| Sweep 18:06 `mp-roam/*-e2-stamp-album.jpg` | `D4MeFixture(.stamps)` → `RoamStampAlbumView` → `NativeStampAlbumView` | The app quits to the home screen (same as mp-club `d4-stamps`, `d4-badges` — all three go through `D4MeFixture`). Build 070117595 predates mp-home's 17:23 "fixtures skip the production session" change, so that is not the cause. Ruled out by reading: duplicate grid ids (synthetic stamps 901–903 unique), `try!` scope in `RoamExperienceFixtureReader` (valid market/account), `cyAlbumChildTitle`, `GrowthCenterFixtureReader` init. | **Not done:** needs a simulator run (`xcrun simctl launch … --design-fixture e2-stamp-album`) to read the crash log; flagged to coordinator. |

Gates: generate_project OK · check_scaffold PASS (20731 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (12) — C2 分享 sheet (wxml:996–1055) + live 地标 · 地点卡 (wxml:387–425)

Base re-merged with `origin/ui/combined-r7` (xcstrings conflict: both sides' keys kept).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` C2 分享 sheet (`roam-share`, 业主 P-8): title → one card (route map or 今日足迹 · stats 处到达 / km / 探索度 · watermark 城瘾 · date) → 4 底色 swatches → 谁能看到 公开 / 仅好友 / 仅自己 (real gate) → channels 微信好友 · 朋友圈 · 小红书 · 保存图片 · 发到广场 · 更多 | `App/RoamHistoryShareView.swift` (sheet from `RoamFinishReportView` + `RoamHistoryViews`) over the shared `CYShareComposer` | Card stats were 总距离 · 用时 · 探店 · 探索度 (two extra, 处到达 missing, MP order lost). Rest maps: card preview = export, tint swatches, 谁能看到 segmented gate before the channels, 朋友圈 / 小红书 album guides, 发到广场 only when community write is open and 公开, 更多 = system share sheet; 微信好友 has no native counterpart (system sheet covers it). Route sketch stays opt-in (privacy gate, native) where the MP draws the route by default. | **Fixed:** card stats are the MP three in MP order: 处到达 (`RoamHistoryRecord.footprintCount`, new key `roam.share.card.footprints` en "Places reached") → distance → 探索度. Composer template carousel / ratio / caption are the shared design-system composer (OWNER RULE 2), not touched. |
| `pages/roam/index` 地标 · 地点卡 half-screen (`paceCard`, wxml:387–425): title → cover / gallery → 演示点 note → category · distance → address (tap = map) → body → reason → 资料来源 → place-note tags → 靠近后可确认地点 → 确认到点 / 已到达 → 开始挑战 → 导航 → 地点记忆 → error + 重试 | `RoamLiveSessionView` pin tap → 附近 list row (`nearbySection`) | Native pin tap only expanded the 附近 list; the tapped place's row showed name → merchant description → 确认到点, no cover, address or body. 地点记忆 is a separate section (`RoamPlaceMemorySection`), already present. | **Fixed:** the selected place's row (`selectedPlaceID`) now carries `RoamLivePlaceCardFacts` under the name in MP order: cover (safe https, 140 pt, ids `roam.live.place.cover`) → address (`roam.live.place.address`) → body (`place.description`, only when no merchant description, `roam.live.place.body`), then the existing arrival buttons. **Not done:** category · distance, reason / 资料来源 / place-note tags, 开始挑战 and 导航 on the live row (导航 needs the reviewed `externalMaps` model wired into the live session) — compiled pass. |

Gates: generate_project OK · check_scaffold PASS (20764 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Not done / next

- citystamp end-to-end MP flow (camera only shoots → write step note → mailbox send creates + exchanges): the live write step still has no
  `RoamStampExchangeCoordinator` (never instantiated), so the citystamp camera (`showsCaption: true`) keeps its caption + exchange. Needs an
  upload-only camera mode returning the picture URL and session wiring for the coordinator — left for a compiled pass.
- team-recovery per-command rows on my-teams / nearby (needs a persisted team-command store).
- P21 mini bar for a running roam: the live session is a full-screen cover owning its own controller (`makeRoamLiveSessionController()` per presentation); a cross-tab bar needs the controller lifted to the session and a root-tab accessory (nav lane) — compiled pass.
- Topic half-screen: MP pins on the live **map** itself (merchant pins) — native has no merchant-pin layer on the live map yet (shops are list rows); the sheet hangs off the row until a pin layer exists. MP also drops `topicId` shops whose `productType != 2` from the merchant layer; native keeps them and labels them 城市定向.
- Entry peek `.login` state (map home + legacy peek): MP 11-14 reads public nearby content as a guest and maps 401 to the cy-error retry, never a sign-in prompt. Native shows sign-in when `!isSignedIn && !allowsPublicEntry` (Core `RoamNearbyEventsEntryState`) and on 401; changing it touches Core tests and `RoamHomeTabsFlowTests` (`roam.home.peek.login`) — left for a compiled pass.
- Live map bottom strip P-32 (`pages/roam/index.wxml:534–541`, `liveCards` = the entry read's nearby activity cards + nearby team cards, shown while no shop strip is open; tap → topic / activity detail or the team): `RoamLiveSessionView` has no nearby-events / teams reader. Needs `roamNearbyEventsReader` + teams passed into the three `RoamLiveSessionView(...)` construction sites (QuestifyApp ×2, MPReviewedPageScreen) — compiled pass.
- No Swift build ran here; integrator compiles.
