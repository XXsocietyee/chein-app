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
| `map-weather` (wxml:251) | — | Decoration only (`aria-hidden`, no gesture, nothing shown on failure/clear/reduced motion); needs a new `/api/map/weather` read. | Superseded: ported to the live map in continue (25). |
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
| `pages/roam/index` 首次发现商家 ritual sheet: title 首次发现 → `dr-cover` (`poi.imgUrl`) → name → 选一份见面礼 → 领优惠券 · 做微任务 · (explore day: title or 看看自由探索, `N m · 自由探索`) → 先继续走 | `App/RoamFirstDiscoverySheet.swift` (`.sheet` from `RoamLiveSessionView`) | No cover: the sheet started at the name. Explore-day candidate with an empty title: MP shows it as 看看自由探索; Core `RoamService.exploreDay` drops it (`isDisplayable` needs a title). MP reads the candidate only after the shop visit is recorded; native reads it on open. | **Fixed:** cover section first (`RoamEntryCover`, 160 pt, only for a safe https `RoamPlace.coverImage`, id `roam.discover.cover`), then name / 选一份见面礼 / options / 先继续走 unchanged (already MP order, inline title + medium/large detents per OWNER RULE 2). Empty-title explore day + visit gate: done in continue (17). |
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

## Round 3 continue (13) — live 地点卡 remaining fields + sweep 18:54 (build 1300a48db)

Base re-merged with `origin/ui/combined-r7` (xcstrings conflict at the file end: both sides' keys kept).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` 地标 · 地点卡 (`paceCard`, wxml:397–408), Not done from continue (12) | `App/RoamLiveSessionView.swift` `RoamLivePlaceCardFacts` (tapped place row) | Row lacked `catLabel · distText`, the 推荐理由 quote, 资料来源 and the place-note tags. | **Fixed:** after the cover: kind (商家 / 城市节点, shared map-home keys) · `N m` (straight-line from the current GCJ-02 fix, hidden without a fix), id `roam.live.place.meta` → address → body → `RoamPlaceNoteRows` (catalog reason + folded 资料来源, same as the map-home card) → visible tags (`roam.live.place.tags`, seed tag hidden). No new strings. 开始挑战 + 导航: done in continue (17). |
| Sweep 18:54 `zh-Hans-e2-stamp-album.jpg` | `RoamExperienceFixtureReader.album` / `shopBadge` (`App/RoamExperienceFixtureSupport.swift`) | Stamp captions "Synthetic city stamp" / "Synthetic reviewed stamp" in English in the Chinese UI (same issue the coordinator flagged on the badge wall). | **Fixed:** fixture captions and the shop-badge name follow the UI language (示例城市邮票 / 示例已审核邮票 / 示例探店徽章 when the preferred language is zh); en values unchanged (UI tests pin them). |
| Sweep 18:54 `*-d2-roam.jpg` | — | Shows the launch logo only (black). Coordinator note: tiles under machine load. Same fixture caveat as continue (11). | Not changed (no app finding). |
| Sweep 18:54 `*-d6-roam.jpg`, `*-e5b-stamp.jpg` | live start / 盖章成功 | Large 漫游 title top-left, one primary 走起, 完成 `.borderedProminent`; nothing wrong vs MP. | No change. |

Gates: generate_project OK · check_scaffold PASS (20774 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (14) — sweep 19:50 (build 3568fe51b): one title style on the 漫游 tab root

Base re-merged with `origin/ui/combined-r7` (xcstrings conflict at the file end: both sides' keys kept, 20848 keys).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| Sweep 19:50 `zh-Hans-d2-roam.jpg` vs `zh-Hans-d6-roam.jpg` (`pages/roam/index`, MP nav title 漫游) | `RoamBrowserView` `RoamBrowserHeader` / `RoamMapBarMaterial` (d2) and `DesignFixtures/D6Fixtures.swift` `roam` (d6) | d2 shows the system inline 漫游 on a material bar with one ⋯; d6 hand-drew a large white `cyText(.pageTitle)` 漫游 plus a glass capsule (护照 + ⋯) over the map — two title styles for the same tab root. | **Fixed (OWNER RULE 2):** d6 roam now sits in a `NavigationStack` with the inline 漫游 on the `.bar` material and one ⋯ toolbar item (`roam.toolbar.more`), map placeholder as the page background; the shipping roam root's over-map bar moved from `.regularMaterial` to `.bar` so both read the same. MP content under the bar (走到哪，雾散到哪 → 规则 · 走起 · 附近) unchanged. |
| Sweep 19:50 `*-d6-roam.jpg` floating row | `DesignFixtures/D6Fixtures.swift` `roamBody` vs `RoamBrowserView` floating controls | The mock drew a white italic GO circle (`CYGoButton`, used by no shipping screen) between black glass circles; the shipping root uses material circles (`RoamMapGlassControl`) and one `.borderedProminent` capsule 走起 with `figure.walk`. | **Fixed:** the mock uses the shipping row (same keys `roam.preflightRules.availability` / `roam.w208.intro.start` / `nearby.title`); `RoamMapGlassControl` made internal so the fixture shares it. |

Gates: generate_project OK · check_scaffold PASS (20848 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (15) — sweep 20:11 (build a250afd77): stamp album header

Base re-merged with `origin/ui/combined-r7` (clean). The d6-roam tile in this sweep still shows the old large title + GO circle: build a250afd77 predates continue (14) (`0e4192951` not yet in `ui/combined-r7`), so nothing to redo.

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| Sweep 20:11 `*-e2-stamp-album.jpg` vs `scene-roam-stamp-album` `album-sub` (`共 N 枚`, alone under the tabs) | `App/NativeR2/FreeExplore/NativeStampAlbumView.swift` header | Native repeated the nav title as a row label: 集邮册 … 3 枚 / Stamp album … Stamps: 3, under an inline title that already says 集邮册. | **Fixed:** the header is the MP line only, `roam.album.sub %lld` 共 N 枚 / "N stamp(s) in total" (en plural), `.subheadline` secondary, same id `roam.experience.album.total`. UI pin `GrowthBadgeStampParityFlowTests` accepts the new text (legacy album keeps `stampAlbum.total`). |
| Continue (11) Not done: `e2-stamp-album` quits after launch | — | Fixed by the coordinator in `1300a48db` (palette `.accentColor` recursion); the 20:11 shot opens the album. | **Resolved** (not by this lane). |
| Sweep 20:11 tile count 2 vs 共 3 枚 | `RoamExperienceSyntheticFixtures.album` | Fixture row 903 is `checkState 2` (moderation-hidden); native hides it on purpose while the server total says 3. MP shows every row the server returns (the server filters). | Not changed: safety rule pinned by tests; noted. |

Gates: generate_project OK · check_scaffold PASS (20849 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (16) — sweep 20:45 (build bb76e327c): d6-roam vs d2-roam

Base: `origin/mp/r3-roam` (already contains `origin/ui/combined-r7`). Build bb76e327c has continue (14) but not (15); the e2-stamp-album tile still shows the old 集邮册 … 3 枚 header, (15) fixes it.

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| Sweep 20:45 `*-d6-roam.jpg` vs `*-d2-roam.jpg` (`pages/roam/index` entry map) | `DesignFixtures/D6Fixtures.swift` `D6MapFixture(.roam)` | d6 forced `.preferredColorScheme(.dark)` (dark bar + dark circles) while d2 renders in the system scheme with light material circles; d6 also drew a tagline 走到哪，雾散到哪。 above the floating row — the MP entry map has no such line (only a file comment), and the shipping root (d2) does not show it. | **Fixed:** the roam kind follows the system scheme (no forced dark, no black page fill; play / search / live mocks unchanged — other lanes); tagline removed, so d6 = d2 = MP: inline 漫游 on `.bar` → map → 规则 · 走起 · 附近. |
| Sweep 20:45 `en-d2-roam.jpg` collapsed panel | `CYMapScaffold` panel (`cyMapPanelColor = .black`) + `RoamBrowserView.peekLine` | Black panel under a light material peek line in light mode. Shared map scaffold (also play, teams, live) — not a roam-only change. | **For other lanes (ds-consistency):** consider a scheme-following panel fill in `App/DesignSystem/CYMapChrome.swift`; not changed here. |
| Not done (entry peek `.login`): `pages/roam/index` `entry-peek` (`cy-error load-failure` + `retryEntryRead`, wxml comment 2026-11-14 公开附近内容游客直接读,失败只重试,不以登录替代读取) | `Core/RoamEntryNearby.swift` `RoamEntryPeekState(error:)` → `RoamEntryPeekView` / `RoamMapHomeSheet` | A 401 on the entry read became the `.login` state (sign-in prompt + 登录 button) instead of the MP retry error. Guests already read the public endpoint (`allowsPublicEntry` when a deployment exists). | **Fixed:** `.unauthorized` → `.failed` (MP cy-error + 重试); 403 stays `.denied` (MP `no-permission` 当前内容无法查看). Core pin `RoamEntryNearbyTests.testPeekStatesFollowSourceOrder` updated. The `.login` visible state remains only for builds with no deployment (offline fixture `login`, UI test `roam.home.peek.login`) — no player reaches it. |
| Sweep 20:45 `*-e5b-stamp.jpg` | `CYCelebrationMoment(kind: .stamp)` | Dark full-screen celebration; copy localized in both languages (灯笼门 / Lantern Gate). | No change: the moment is a full-screen overlay by design. |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (17) — 首次发现 explore-day + live 地点卡 开始挑战 / 导航 (Not done from 11 / 13) + sweep 21:09 (build 405948d58)

Base re-merged with `origin/ui/combined-r7` (clean, 79 commits). Sweep 21:09 roam tiles: d6-roam still shows the tagline (build predates `076f19c85`, continue 16); zh d2-roam tile is the launch screen (timing); e2-stamp-album zh now reads 示例城市邮票 / 共 3 枚 (fixture copy follows the UI language ✓); e5b-stamp localized ✓. Nothing new to redo.

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` 首次发现 sheet explore-day option (wxml:983–986 `discoverReward.exploreDay.title \|\| '看看自由探索'`; index.js `_attachExploreDayCandidate` keeps any positive `activityId`) — Not done from continue (11) | `Core/RoamContracts.swift` `RoamExploreDay.isDisplayable` → `RoamService.exploreDay` → `App/RoamFirstDiscoverySheet.swift` | Core dropped a candidate with an empty title, so the MP 看看自由探索 option never showed. | **Fixed:** `isDisplayable` = `id > 0` only; the row title falls back to new key `roam.discover.exploreDayFallback` (en "See free exploration" / zh 看看自由探索); `N m · 自由探索` hint unchanged. Core pin `RoamContractTests.testExploreDayRequiresIdentityAndNamePreservesUnknownDistance` updated (blank title is now displayable, with the MP reason). |
| Same sheet, visit-recorded gate (MP reads the candidate only when `/api/roam/shop/visit` returned `recorded`) — Not done from continue (11) | `Core/RoamLiveSessionController.swift` `firstShopDiscovery` | Re-read: native raises the card only after `receipt.recorded` (`guard receipt.recorded … firstShopDiscovery = place`), so the sheet's `.task` read already runs after a recorded visit. | **Resolved by reading** — no change needed. |
| `pages/roam/index` 地标 · 地点卡 `paceCard` actions (wxml:412–413: 开始挑战 when `challengeId` = city node, → `pages/play/poi-challenge/index?poiId=`; 导航 when the card has lat/lng, `navPaceCard` → open-address) — Still not done from continue (13) | `App/RoamLiveSessionView.swift` `placeCardActions` (selected place row) + `App/RoamFirstDiscoverySheet.swift` `RoamDiscoverDestinations` | The live row ended at 确认到点 / 已到达: no 开始挑战 and no 导航. | **Fixed:** after the arrival buttons, in MP order: 开始挑战 `NavigationLink` (type 1 city nodes only, reuses `nativeR2.mapHome.card.challenge`, id `roam.live.place.challenge`) → the shared `PlatformExternalMapHost` (review dialog + copy-address fallback, id `roam.live.place.navigate`) when the place has a coordinate. Both come through the existing `roamDiscoverDestinations` environment (new optional `challenge`, `makeExternalMaps`, `mapsScope`, filled from `AppSession` = `MPReviewedPageScreen` poi-challenge + `platformConsumers.mapsFactory`), so the three live construction sites need no change and fixtures (no destinations) hide both rows. No new strings. |

Gates: generate_project OK · check_scaffold PASS (20875 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (18) — re-scan: live 官方活动 · 到达验证 overlay (no row yet)

Base re-merged with `origin/ui/combined-r7`. Sweep unchanged (build 405948d58, reviewed in continue 17). Every MP roam page already has a row; re-scan of roam files for OWNER RULE 2: no `.font(.system(size:))` / `.tracking` / custom fonts / `.large` on pushed pages; one section-level bare spinner left (below). Inline spinners in buttons / image placeholders stay (they sit in a labelled control).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` event-overlay (wxml:335–350: 官方活动 · 到达验证 · title · ✕ → 活动暂停：{{pausedReason\|\|'等待运营处理'}} / 报名后的到达才计入活动 → missions (title · sub · 验证到达 / 先移动建立会话 / 已验证 / 自动同步) → feedback) | `App/RoamOfficialArrivalSection.swift` (section in `RoamLiveSessionView`) | 1. The paused line always said 等待运营处理; MP shows the server `pausedReason` and falls back to that text only when it is empty. 2. While the event read ran the section showed a bare `ProgressView` (P10). Rest (header + close, signup hint, mission rows and states, feedback, V1 report) already MP order. | **Fixed:** `OfficialEvent.pausedReason` (trimmed, non-empty) → new key `roam.official.pausedReason %@` (活动暂停：%@ / "Event paused: %@"), else the existing `roam.official.paused`; loading = `ProgressView("roam.official.loading")` (正在读取活动… / "Loading the event…", id `roam.official.loading`). |

New strings (en + zh-Hans, also `docs/port/strings/mp-r3-roam.json`): `roam.official.pausedReason %@`, `roam.official.loading`.

Gates: generate_project OK · check_scaffold PASS (20893 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (19) — sweep 22:20 (build 8fa84e4d3): one map style + stamp album art

Base re-merged with `origin/ui/combined-r7` (xcstrings: both sides' keys kept, base order). Screens read: `docs/sweeps/latest/mp-roam/sheet-en.jpg` (d2-roam, d6-roam, e2-stamp-album, e5b-stamp).

| MP page / screenshot | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` map · `mp-roam/en-d2-roam.jpg` vs `en-d6-roam.jpg` | `App/RoamBrowserView.swift` offline map (`results`) | d2-roam drew the always-dark `CYMapStreetGrid`, d6-roam the appearance-following `CYMapPlaceholder`: two map styles for one tab (OWNER RULE 2). Live maps already use `.standard` (follows the system). | **Fixed:** the offline example uses `CYMapPlaceholder()` too, so both states follow the system appearance. |
| `subpackageRoam/components/cy/scene-roam-stamp-album` `stkcell__img` (`picUrl`, aspectFill) · `mp-roam/en-e2-stamp-album.jpg` | `App/NativeR2/FreeExplore/NativeStampAlbumView.swift` `NativeStampAlbumTile` + `App/RoamStampViews.swift` stamp detail | Offline example tiles were grey discs with a generic glyph (P24); the detail showed a large SF Symbol. MP cells are the stamp photo. | **Fixed:** offline example shows bundled MP city photos (`MPAsset.BannerCover.event` / `.cityCamera`, by stamp id) cropped to the circle; the detail shows the same photo (labelled 示例插图). Real stamps unchanged (remote `picUrl`). No new strings. |

Gates: generate_project OK · check_scaffold PASS (20911 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (20) — 结算 finish record vs MP settle order + P30 result screen

Base re-merged with `origin/ui/combined-r7` (xcstrings: two pure-addition conflicts, both sides kept, 20929 keys). Sweep unchanged (build 8fa84e4d3, reviewed in continue 19); new design principle P30 (result screen) names the roam finish record.

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` 结算 `screen=='arrive'` (wxml:893–948: `settle__meta` date → `zone · 自由漫游` + ✕ → rule → `settle__big` 处到达 → six `sgc` cells → 这段足迹 → `finish-stamps` → errors → `settle__map` with 查看漫游数据 → bottom `settle__cta` 分享 + `settle__minor` 漫游记录) | `App/RoamFinishReportView.swift` | 1. Route map was the first block (MP: last, after the stamps). 2. Title above the date line (MP: date first). 3. Stamp strip and medals came before 这段足迹 (MP: story then stamps). 4. Share + Done sat in the nav bar, 漫游记录 at the end of the scroll (MP: bottom CTA bar). 5. No success haptic (P30). | **Fixed:** MP order date → title → rule → 处到达 → six cells → 这段足迹 → stamps → (native P8 medal tiles) → map with 查看漫游数据; P30 bottom bar on `.bar`: 分享 `.bordered` capsule beside the primary 完成 `.borderedProminent` capsule, 漫游记录 / 勋章收藏 `.borderless` under them; `.sensoryFeedback(.success)` once when the hero reveals; the existing hero roll-up and medal `symbolEffect(.bounce)` stay (Reduce Motion: no roll). Ids unchanged. `settle__places` (reached place names, done + not demo, MP index.js:4861) added before the map from `RoamHistoryRecord.pois` (demo entries and repeats skipped), id `roam.finishReport.places`. MP `roamPrompt` fallback (漫游提示 when no route story) not added: Core settlement has no `roamPrompt` field. No new strings. |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (21) — live map bottom strip P-32 (Not done) + sweep 23:07 (build b3b03703a)

Base re-merged with `origin/ui/combined-r7` (xcstrings: one pure-addition conflict, base keys kept). Screens read: `docs/sweeps/latest/mp-roam/sheet-zh-Hans.jpg`, `sheet-en.jpg` — d6-roam both languages and e2-stamp-album now show one appearance-following map and the MP stamp photos (keep); `zh-Hans-d2-roam.jpg` is the black launch tile (machine load per the 17:3x note); `en-d2-roam.jpg` still shows the black `cyMapPanelColor` panel (shared scaffold, already listed for ds-consistency in continue 16). Every MP roam page / component already has a row.

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` live map `live-peek` (P-32, wxml:535–545; index.js `_syncEntryMap` `liveCards` = entry activity cards + `entryMap.teamView` teams, same read; `onLiveCardTap` → topic / activity detail, team → `_openEntryTeamById`; shown on `screen=='map'` while no shop strip is open, hidden when empty) — Not done since continue (10) | New `App/RoamLiveCardsStrip.swift` (`RoamLiveCardsFeed`, environment `\.roamLiveCards`, `RoamLiveCardsSection`) → `App/RoamLiveSessionView.swift` `sessionList`; fed from `App/NativeR2/MapHome/RoamMapHomeSheet.swift` live cover | The live session had no nearby-activity / team cards. | **Fixed:** the map home passes its already-loaded entry read (`model.cards(reader:)` + `model.teams`, no new request) and its `eventDestination` / `nearbyTeamDestination` into the live cover through the environment, so the three `RoamLiveSessionView(...)` construction sites stay unchanged and fixtures / the legacy browser (no feed) show nothing. Section right under the HUD (the HUD stays the sheet's peek hero) while ready / acquiring / active / paused and no topic sheet is open: horizontal snap row of cards — cover (MP `home-route-city-placeholder` fallback) → tag (城市定向 / 自由探索 / 队伍) → title (未命名活动 / 玩家队伍 fallback) → meta (activity: MP `activityView.meta` via `RoamEntryMetaLine`; team: activity name · `N/M 人` · 距你 X km); rows without a point dropped as `entryMap.build`. Tap = `NavigationLink` to the topic / activity detail or the nearby-teams page focused on the team. Ids `roam.live.cards`, `roam.live.card.<id>`, `roam.live.team.<id>`. Card width `@ScaledMetric`, text under the cover (Dynamic Type). New key `roam.live.cards.teamPeople %lld %lld` (en `%1$lld/%2$lld people`, zh `%1$lld/%2$lld 人`). |

Gates: generate_project OK · check_scaffold PASS (20942 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (22) — live merchant layer drops 城市定向 topic shops (Not done) + sweep 23:37 (build 793c3190b)

Base re-merged with `origin/ui/combined-r7` (xcstrings: one pure-addition conflict, both sides' keys kept). Screens read: `docs/sweeps/latest/mp-roam/sheet-zh-Hans.jpg`, `sheet-en.jpg` — d6-roam, e2-stamp-album (MP photos, 共 3 枚 / 示例城市邮票), e5b-stamp unchanged and correct (keep); `zh-Hans-d2-roam.jpg` is the launch tile again (timing); `en-d2-roam.jpg` still shows the black `cyMapPanelColor` panel (shared `App/DesignSystem/CYMapChrome.swift:391`, ds-consistency — listed for ds-consistency in continue 16). Re-scan of `App/Roam*.swift`, `NativeR2/MapHome`, `NativeR2/FreeExplore`: no `.font(.system(size:))`, `.tracking`, `.kerning` or `Color(red:)`.

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` merchant layer `_fetchNearbyMerchants` (index.js:1394 `if (n.topicId && Number(n.productType) !== 2) return null`) — Not done since continue (13) | `Core/RoamContracts.swift` `RoamRouteNode.isLiveMerchantLayerShop` → `Core/RoamLiveService.swift` `registeredShops` → live 附近 shop rows / `RoamLiveTopicSheet` | Native kept shops attached to a 城市定向 topic and labelled them 城市定向 in the topic half-screen; the MP never shows them on the live map. | **Fixed:** `registeredShops` keeps a shop only when it has no topic (`topicId` nil / 0) or its topic is 自由探索 (`productType == 2`), exactly the MP test. Core test `RoamLiveSessionTests.testLiveMerchantLayerDropsCityTopicShopsLikeMP`. Search map (`SearchMapService`, other lane) unchanged. No new strings. |

Gates: generate_project OK · check_scaffold PASS (20969 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (23) — live map merchant-pin layer (Not done) + sweep 00:10 (build 283dd3b52)

Base re-merged with `origin/ui/combined-r7` (xcstrings: one pure-addition conflict, both sides' keys kept, 20986 keys). Screens read: `docs/sweeps/latest/mp-roam/sheet-zh-Hans.jpg`, `sheet-en.jpg` — d6-roam (inline 漫游 on `.bar`, appearance-following map, 规则 · 走起 · 附近), e2-stamp-album (MP photos, 共 3 枚), e5b-stamp localized: keep. `zh-Hans-d2-roam.jpg` is the launch tile (timing); `en-d2-roam.jpg` still has the black `cyMapPanelColor` panel (shared `App/DesignSystem/CYMapChrome.swift:391`, ds-consistency; not picked up in their receipt yet — listed again under For other lanes).

| MP page / scene | Native view | Differences | Status |
|---|---|---|---|
| `pages/roam/index` merchant layer on the live map (index.js `_fetchNearbyMerchants` 1393–1430: shops with a coordinate become grey `cat: 'merchant'` pins, name or 商家; `onMarkerTap` 4209–4239 → shop strip on that shop, `_openPlaceDetail` 4306 → topic half-screen when the pin has a topic) — Not done since continue (8) | `App/RoamLiveSessionView.swift` `liveMapGround` (MapKit `Map`) | Native drew only the roam place pins; registered shops were list rows only, so the topic half-screen could only be opened from the row. | **Fixed:** shop pins (`Marker` `storefront.fill`, `.tint(.gray)`, name or `nativeR2.mapHome.kind.merchant` 商家 / Shop) for every registered shop with a coordinate (already MP-filtered in continue 22). One map selection `RoamLiveMapPick` (`.place` / `.shop`, ids of the two layers may collide) replaces the Int tag; a place pin keeps the old behaviour (`selectedPlaceID` → 地点卡 facts), a shop pin with a topic opens `RoamLiveTopicSheet`, every pin opens the 附近 list (shop rows = MP shop strip) and lifts the sheet from 0.3 to medium. Deselecting clears `selectedPlaceID` as before. No new strings. |
| Same merchant layer, photo pins (index.js:1400–1414 `photo: n.picUrl ? imgUrl : ''`, photo-pins.js `pinPhoto`) | `Core/RoamContracts.swift` `RoamRouteNode` + `RoamLivePhotoPin.url(for: RoamRouteNode)` | `RoamRouteNode` did not decode `picUrl`, so every shop was a symbol pin. | **Fixed:** `picUrl` decoded (trimmed, blank → nil, malformed value → nil without failing the row); a shop with an allowlisted absolute photo URL is a 40 pt photo pin (same `RoamLivePhotoPin` as place shops, grey ring), others keep the grey `storefront.fill` marker (MP: no placeholder photo). Relative MP paths (`baseImgUrl + picUrl`) stay symbol pins (no app-side base). Core test `RoamLiveSessionTests.testLiveMerchantPinKeepsMPShopPhotoAndToleratesMalformedPicUrl`. |

Gates: generate_project OK · check_scaffold PASS (20986 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (24) — coordinator 00:50 finding: black 附近活动 panel (build f8574edab)

Base re-merged with `origin/ui/combined-r7` (clean). Screens read: `docs/sweeps/latest/a11y-dt/zh-Hans-a11y-roam-ax5.jpg` (black panel under the light map, 附近活动 2 on its own grey pill) and `mp-roam/zh-Hans-d2-roam.jpg` (launch tile, timing).

| MP page → native | Finding | Fix |
|---|---|---|
| `pages/roam/index` entry map 附近活动 sheet → `App/RoamBrowserView.swift` map mode (`CYMapScaffold` panel) + `App/DesignSystem/CYMapChrome.swift` | Coordinator 00:50: the 附近活动 sheet is solid black over the light map (`cyMapPanelColor = .black`); rows and peek use semantic text colours, so light mode drew black-on-black, patched only by a material pill behind the peek line. | **Fixed:** new environment flag `cyMapPanelFollowsAppearance` (default off — play / nearby-teams / play-session scaffolds keep their look, their lanes decide); when on, the panel fill is the system `.regularMaterial` (follows light / dark like the map), lighter shadow (0.15), grabber `.tertiary`. The roam browser sets it on its scaffold, its list background in map mode is clear (was black), and the peek line drops its own material pill (the panel is the material now). No new strings; same MP content and order (peek 附近活动 · count → rows). |

Gates: generate_project OK · check_scaffold PASS (21016 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (25) — live-map weather layer (MP `cy-map-weather`) + sweep 01:10 (build 907570051)

Base re-merged with `origin/ui/combined-r7`: two conflicts with ds-consistency's map-panel change (`cyMapPanelColor` is now
`CYColor.bgElevated`, grabber `tertiaryLabel`). Kept both: the default panel is ds-consistency's elevated surface; roam keeps its
`cyMapPanelFollowsAppearance` opt-in (regular material); the grabber is theirs for every scaffold. Screens read:
`docs/sweeps/latest/mp-roam/sheet-zh-Hans.jpg`, `sheet-en.jpg` (d2-roam, d6-roam, e2-stamp-album, e5b-stamp).

| MP page → native | Difference | Fix |
|---|---|---|
| `pages/roam/index` live map `cy-map-weather` (wxml:251, `active = roamPageShown && screen == 'map'`; `subpackageRoam/components/map-weather`, `weather-core.js` cell cache) → `App/RoamLiveSessionView.swift` `sessionContent` | Earlier row (continue 2) said "not ported, needs a new endpoint". The read already exists (`MapSearchPlayerService.weather`, `MapWeatherModel`, `MapWeatherOverlay`) but was mounted only on the legacy `RoamBrowserView` search map, not on the live map where the MP shows it. | **Fixed:** new `RoamLiveMapWeather` modifier (`App/SocialRoamMounts.swift`) on the live map: player GCJ-02 fix → 20-per-degree cell, only the cell centre is sent, re-read only when the cell (or account) changes, 10 min cache. Nothing drawn without a fix, signed out (no `socialRoamCapabilities`), clear, reduced motion or any failure — as the MP. Overlay is hit-test-off and VoiceOver-hidden. No new strings. |
| `subpackageRoam/components/cy/scene-roam-stamp-album` → `NativeStampAlbumView` (`e2-stamp-album`, both languages) | Design fixture showed the offline note 示例内容 / Example content above 共 N 枚, and stamps named 示例城市邮票 / "Synthetic city stamp" (coordinator 19:50 asked for real fixture names). | **Fixed:** the note hides under `--design-fixture` (same rule as Search / Square; offline still keeps the album local); design-fixture stamp names 外滩夜色 / The Bund at night and 老街霓虹 / Old street neon (match the bundled photos). UI tests (no flag) keep the pinned captions. |
| `roam-atmos-entry` (wxml:1076) | First-entry cloud video over the map. | Still not ported: decoration only, and the 16:53 rule says no overlay may dim a tab root. |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**.

## Round 3 continue (26) — P29 map sheet on the shipping map home (01:40 "next round" list)

No open coordinator finding for mp-roam (01:50 sweep, build a32387e9b: "Roam Nearby activities sheet follows the appearance" kept). Every
roam MP page already has a row, so this run applies the new principles. Screens read: `docs/sweeps/latest/mp-roam/sheet-en.jpg`
(d2-roam / d6-roam / e2-stamp-album / e5b-stamp; the album still shows the pre-continue-25 names, fixed there).

| MP page → native | Principle → change | Fixture |
|---|---|---|
| `pages/roam/index` entry-peek 附近活动 (wxml:143–174) → `App/NativeR2/MapHome/RoamMapHomeSheet.swift` `nearbySection` header + `RoamMapHomePinRow` | **P29** — the header now states the count of loaded rows trailing the 附近活动 title (combined VoiceOver element, header trait, id `roam.mapHome.nearby.count`; hidden while empty / loading). Each row's kind · distance gains `· N min walk` / `· 步行 N 分钟` (80 m/min, rounded up, only ≤ 3 km; `RoamMapHomePinRow.walkMinutes`), stacked at AX sizes like the distance. MP sections / order unchanged (the MP card meta is kept; no chips added: the MP tabs 附近活动 / 本城推荐 already are the segmented header). Distances stay `Measurement` `.road` (locale units). New key `nativeR2.mapHome.walkMinutes %lld`. | Shipping map home (no map-home fixture yet, see continue 11 Not done) |
| `e5b-stamp` (`CYCelebrationMoment(kind: .stamp)`, generic pin glyph) | Read only: the component is not mounted by any shipping roam screen (grep: fixture-only), so it is a design-system preview, not a roam page. | For ds-consistency (below). |

## Round 3 continue (27) — motion and feedback on roam subpages (01:40 "next round" item 2) + sweep 02:10 (build 41374363f)

Base re-merged with `origin/ui/combined-r7` (clean). No open coordinator finding for mp-roam (02:20: none; map panel settled 02:05 — this run
does not touch `CYMapChrome.swift` or the `RoamBrowserView` panel). Screens read: `docs/sweeps/latest/mp-roam/sheet-zh-Hans.jpg`,
`sheet-en.jpg` (d2-roam, d6-roam: same inline title + light map; e2-stamp-album: 外滩夜色 / 老街霓虹 + 还没收到 cell; e5b-stamp): keep.
MP content and order unchanged on every page below; only feedback and state-change motion were added (shared `cyHaptic` →
`HapticsService`, shared `cyAnimation` → `CYMotion` springs, which cross-fade under Reduce Motion).

| MP page → native | Action / state change | Feedback + motion |
|---|---|---|
| `subpackageRoam/citystamp` write step → `App/RoamSubpageParityViews.swift` `RoamCityStampFlowView` | 投进信箱 sends (button or drag-drop) | `.success` when the receipt lands (false → true only), `.warning` when a send fails, `.selection` when the dragged note arms the mailbox; the mailbox lift animates with `CYMotion.release`; write step → slip swaps with `CYMotion.standard`. |
| `subpackageRoam/citystamp` slip (`sgslip`) → `RoamStampSlipView` | tear 撕下 / scratch 刮开 | `.impactMedium` on tear, `.success` on reveal; the hint/next-control swaps animate with `CYMotion.standard` (cross-fade under Reduce Motion; VoiceOver and Reduce Motion keep the plain buttons). |
| `subpackageRoam/components/cy/scene-roam-stamp-album` 我的 / 收到的 → `NativeStampAlbumView` | segmented tab change | `.selection` + `CYMotion.standard` pane swap. |
| `subpackageRoam/components/cy/scene-roam-task-list` 进行中 / 即将 / 我的 → `RoamOfficialTasksView` | segmented tab change | `.selection` + `CYMotion.standard` list change. |

Gates: generate_project OK · check_scaffold PASS (21152 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

No new strings. Fixtures: e2-stamp-album (tab), shipping citystamp flow (fixture receipt path `fixtureReceipt` also fires `.success`).

## Round 3 continue (28) — 漫游记录 states as design fixtures (01:40 "next round" item 3) + sweep 02:10 (build 41374363f)

No open coordinator finding for mp-roam (sweep index still build 41374363f, sheets as in continue 27; map panel settled — not touched).
Every MP roam page already has a row, so this run adds the missing state fixtures for `subpackageRoam/history`.

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/history` (`scene-roam-history` `cy-error load-failure title="漫游记录加载失败" retry="重试"`) → `App/RoamHistoryViews.swift` `RoamHistoryView` | Error state used the generic 加载失败，请重试。 title. | `RoamExperienceIssue(failureTitle: "roam.history.loadFailed")` — new key en "Couldn't load your roam history" / zh 漫游记录加载失败; retry stays 重试. Contract pin `test_roam_history_live_entry` updated (MP title). | `r3-roam-history-error` |
| same page, content + empty states | No `--design-fixture` mounted the history page (only the `--roam-subpage-fixture` host), so the sweep never showed it; the fixture rows read "Sample district" / "Sample record…" in both languages and the 示例内容 note sat above the list. | New fixtures `r3-roam-history` (records + 那年今日 / 月度回顾 tools), `r3-roam-history-empty` (MP 还没有漫游记录 + 出发第一次漫游). Under `--design-fixture` the history rows carry place names in the UI language (外滩 / The Bund, 老街夜走 / Old street evening walk, 外滩源庭院) and `RoamExperienceNotice` hides (same rule as the stamp album, continue 25); UI tests without the flag keep their pins. UI test `Fixture_r3_roamHistoryTests` checks all three resolve (record / empty / error ids). | `r3-roam-history`, `r3-roam-history-empty` |

**For the coordinator:** please add `r3-roam-history`, `r3-roam-history-empty`, `r3-roam-history-error` to the mp-roam sweep row.

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (29) — 集邮册 states follow the MP (01:40 "next round" item 3) + sweep 03:04 (build ad55acd94)

Base re-merged with `origin/ui/combined-r7` (xcstrings conflict: both sides' keys kept). No open coordinator finding for mp-roam
(sweep 03:04 `mp-roam/sheet-en.jpg`, `sheet-zh-Hans.jpg`: d2-roam / d6-roam same inline title + light map, e2-stamp-album art + 还没收到 cell,
e5b-stamp — keep). Map panel settled (02:05) — not touched.

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/components/cy/scene-roam-stamp-album` 我的 `cy-error load-failure title="集邮册无法打开" retry="重试"` → `App/NativeR2/FreeExplore/NativeStampAlbumView.swift` `content(read:)` | Whole-page error used the generic 加载失败，请重试。 | Title = existing key `stampAlbum.openFailed` (集邮册无法打开 / Couldn't open the stamp album); retry stays 重试 (`action.retry`), `ContentUnavailableView` + `.bordered`. | `r3-roam-stamp-album-error` (new) |
| same component, 收到的 tab (`title="收到的邮票无法打开"` with no rows; `album-more--error` 这一页没读到 · 点此重试 below rows; `album-empty` 还没有收到的邮票) → `App/RoamReceivedStampMetadataView.swift` | Error used the generic title in both cases; empty read 还没有收到交换的城市签. | `RoamExperienceIssue(failureTitle:)` = `roam.receivedStamp.openFailed` when no rows, `stampAlbum.continuationRetry` below rows (both existing keys). `roam.receivedMetadata.empty` value → 还没有收到的邮票 / No received stamps yet (MP copy). | inline 收到的 tab (needs a received reader; not in a fixture) |
| same component, 我的 empty (`还没有邮票` + 打开集邮相机) | Already MP (`roam.experience.albumEmpty` + `stampAlbum.openCamera`). | Sweep alias so the roam row shows it. | `r3-roam-stamp-album-empty` (= `d4-stamps-empty`) |

UI test `Fixture_r3_roamStampAlbumStatesTests` (empty id; error id + MP title + app stays foreground).
**For the coordinator:** please add `r3-roam-stamp-album-empty`, `r3-roam-stamp-album-error` (and the 28 history trio) to the mp-roam sweep row.

Gates: generate_project OK · check_scaffold PASS (21174 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (30) — 官方线路 states as design fixtures (01:40 "next round" item 3) + sweep 03:49 (build 733bfb368)

Base re-merged with `origin/ui/combined-r7` (xcstrings conflict: both sides' keys kept). No open coordinator finding for mp-roam
(sweep 03:49 `mp-roam/sheet-en.jpg`: d2-roam / d6-roam same inline title + light map, e2-stamp-album art + Not received yet cell,
e5b-stamp — keep). Map panel settled (02:05) — not touched.

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/official-routes` (`cy-skeleton` → `cy-error title="线路加载失败" retry="重试"` → `cy-empty title="还没有上架的官方线路"` → `.orl-card` cover · name · metaText) → `App/NativeR2/MapHome/RoamMapHomeRoutes.swift` `RoamMapHomeRoutesList` (shipping map-home push) | Content and MP copy already match (`nativeR2.mapHome.routes.failed` / `.empty`). The sweep never showed the shipping list: only the legacy `OfficialRouteListView` had fixtures (`e1-routes`, English "(offline example)" names in both languages). Empty / error had no identifiers. | New `App/DesignFixtures/RoamR3RoutesFixture.swift` mounts the real `RoamMapHomeRoutesList` on an offline reader with route names in the UI language (外滩夜色步行线 / Bund night walk …); ids `officialRoute.list.empty`, `officialRoute.list.error` on the two `ContentUnavailableView`s. UI test `Fixture_r3_roamRoutesStatesTests` (row / empty id / error id + 重试 + foreground). | `r3-roam-routes`, `r3-roam-routes-empty`, `r3-roam-routes-error` |
| `subpackageRoam/official-route` (`cy-skeleton` → `cy-error 线路加载失败 + 重试` → `cy-empty 这条线路不存在或已下架` → title · metaText · cover → 节点（N） rows / `cy-empty 这条线路还没有节点`) → `RoamMapHomeRouteCard` (shipping route card) | Content, order and MP copy already match (continue 2). No fixture showed the shipping card or its error / not-found states; no ids on them. | Same fixture file: `RoamR3RouteDetailFixtureHost` mounts the real card on route 1 with three stops in the UI language (外滩源庭院 · 外白渡桥 · 滨江步道, 参考停留 on two); error = transport failure, not-found = `OfficialRouteReader.Failure.notFound`. Ids `officialRoute.detail.error`, `.notFound`, `.noStops`. UI tests in `Fixture_r3_roamRoutesStatesTests`. | `r3-roam-route`, `r3-roam-route-error`, `r3-roam-route-notfound` |

**For the coordinator:** please add `r3-roam-routes`, `r3-roam-routes-empty`, `r3-roam-routes-error`, `r3-roam-route`, `r3-roam-route-error`, `r3-roam-route-notfound` to the mp-roam sweep row (with the history and stamp-album state fixtures from 28/29).

Gates: generate_project OK · check_scaffold PASS (21210 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here. No new strings.

## Round 3 continue (31) — 本次漫游 states as design fixtures (01:40 "next round" item 3) + sweep 03:49 (build 733bfb368)

Base re-merged with `origin/ui/combined-r7` (clean). No open coordinator finding for mp-roam; the sweep index is still build 733bfb368
(sheets as in continue 30 — keep). Map panel settled (02:05) — not touched. Every MP roam page already has a row.

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/session` (`scene-roam-session`: loading 正在读取本次漫游 → `cy-error 这次漫游无法打开 + 重试` → `cy-empty 找不到这次漫游 + 返回漫游历史` → 本次路线 replay → kv 总距离 / 时长 / 探店 / 到达 / 探索度 → 解锁奖励 → 点亮地点 → 分享足迹卡) → `App/RoamHistoryViews.swift` `RoamHistoryDetailView` | Content, order and MP copy already match (continue 1 + 2, mp-states error title). No `--design-fixture` mounted the page, so the sweep never showed it or its not-found / error states. | New fixtures in `DesignFixtureRegistry` mount the real detail view on `RoamExperienceFixtureReader`: record `ts 1700000000000` (外滩 / The Bund, 外滩源庭院 lit — UI-language names from continue 28), a timestamp with no record (MP 找不到这次漫游 + 返回漫游历史), and the failure scenario (这次漫游无法打开 + 重试). UI test `Fixture_r3_roamSessionTests` (share id / missing id / error id + foreground). | `r3-roam-session`, `r3-roam-session-missing`, `r3-roam-session-error` |

**For the coordinator:** please add `r3-roam-session`, `r3-roam-session-missing`, `r3-roam-session-error` to the mp-roam sweep row
(with the history, stamp-album and route state fixtures from 28–30). No new strings.

## Round 3 continue (32) — 地点详情 states as design fixtures (01:40 "next round" item 3) + sweep 04:46 (build 13a6690eb)

Base re-merged with `origin/ui/combined-r7`. No open coordinator finding for mp-roam (sweep 04:46 `mp-roam/sheet-en.jpg`,
`sheet-zh-Hans.jpg`: d2-roam / d6-roam same inline title + light map, e2-stamp-album art + 还没收到 cell, e5b-stamp — keep). Map panel
settled (02:05) — not touched. No contract-cleanup row for mp-roam.

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/poi-detail` → `cy-scene-roam-poi-detail` (`cy-skeleton` → `cy-error load-failure 节点无法打开 + 重试` → `cy-empty 节点未开放或已下线 + 返回地图` → `cy-empty missing-param 找不到这个节点 + 返回地图` → node card) → `App/RoamItemDetailView.swift` | Content, order and MP copy already match (continue 1, mp-states r3). No `--design-fixture` mounted the page, so the sweep never showed it or its three non-content states. | New `App/DesignFixtures/RoamR3PoiFixture.swift`: own offline `RoamReading` (`RoamR3PoiFixtureReader`) serving one city node in the UI language (外滩源庭院 / Bund Origin courtyard, 中山东一路33号, tags 历史 · 建筑, ★ 4.6 from 38) and mounting the real detail view; `isOfflineExample` false so no 示例内容 note renders. Error = HTTP 503 (节点无法打开 + 重试, `roam.error`), unavailable = `RoamReadFailure.nodeUnavailable` (`roamSub.w208.poi.unavailable`), missing = `.nodeNotFound` (`roamSub.w208.poi.missing`). UI test `Fixture_r3_roamPoiTests` (four ids + foreground). | `r3-roam-poi`, `r3-roam-poi-error`, `r3-roam-poi-unavailable`, `r3-roam-poi-missing` |

**For the coordinator:** please add `r3-roam-poi`, `r3-roam-poi-error`, `r3-roam-poi-unavailable`, `r3-roam-poi-missing` to the mp-roam
sweep row (with the history / stamp-album / route / session state fixtures from 28–31). No new strings. No Swift build here.

## Round 3 continue (33) — 附近 states as design fixtures (01:40 "next round" item 3)

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/nearby` (`cy-error load-failure 附近信息获取失败 / 当前内容无法查看 + 重试` wxml:62 → `cy-empty 附近暂无节点` wxml:71 → team rows) → `App/NearbyTeamViews.swift` `NearbyTeamsView` tab 0 | Content, order and MP copy already match (continue 1, mp-states r3 `NearbyLoadIssueCard`). The only fixtures (`nearby-empty`, `--nearby-team-fixture`) are English-only demo rows ("Your demo team", "Demo meeting point") in San Francisco and never show the list error; the list empty state had no id. | New `App/DesignFixtures/RoamR3NearbyFixture.swift`: the real `NearbyTeamsView` on `NearbyTeamFakeTransport` around the Bund with two teams in the UI language (周六外滩探索小队 · 阿川 · 外滩源庭院 650 m; 老街夜走搭子 · 小军 · 方浜中路路口 1.8 km); empty = `[]`; error = no `/api/team/nearby` response (transport failure → `nearby.loadFailed` → MP 附近信息获取失败 + 重试). Empty state gains id `nearby.list.empty` (`messageIdentifier`, no visual change). UI test `Fixture_r3_roamNearbyTests`. | `r3-roam-nearby`, `r3-roam-nearby-empty`, `r3-roam-nearby-error` |

**For the coordinator:** please add `r3-roam-nearby`, `r3-roam-nearby-empty`, `r3-roam-nearby-error` to the mp-roam sweep row. No new strings. No Swift build here.

## Round 3 continue (34) — 我的队伍 states as design fixtures + guest gate fix (01:40 "next round" item 3) + sweep 05:15 (build a4142df0d)

Base re-merged with `origin/ui/combined-r7`. No open coordinator finding for mp-roam (05:35 sweep: "nothing new"; `mp-roam/sheet-zh-Hans.jpg`:
d2-roam / d6-roam same inline title + light map, e2-stamp-album art + 还没收到 cell, e5b-stamp — keep). Map panel settled (02:05) — not touched.

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/my-teams` guest (`tab==='mine' && guest` → only `cy-empty no-permission 登录后查看 + 登录`, PG-004; the 附近在招募 block needs `!guest`) → `App/NearbyTeamViews.swift` `loadMine` / `mineSection` | **Bug:** for a guest the tab-1 `.task` still ran `loadMine`; the coordinator's `begin()` set `nearby.signIn`, so `mine.failed` turned true and the page drew 队伍没能读到 + 重试 under the sign-in gate. | `loadMine` returns before any read when `!coordinator.authenticated` (loading / failed cleared): the guest sees only the gate. | `r3-roam-my-teams-signedout` |
| same page, `mt-err` 队伍获取失败 · 轻点重试 | Native title 队伍没能读到. | `nearby.w208.mine.failedTitle` zh → 队伍获取失败 (MP copy; en "Couldn't load your teams" unchanged); 重试 stays the `.bordered` action. | `r3-roam-my-teams-error` (my-applications read fails) |
| same page: `.mt-stats` → 我的 / 附近招募 → groups 带队 / 已通过 / 审核中 / 未通过 (card: faces · name · badge, members, N 条入队申请) → `mt-empty 还没有队伍 + 去地图找队伍` → 附近在招募 rows | Content and order already match (continue 1). No fixture showed the shipping tab 1. | `App/DesignFixtures/RoamR3NearbyFixture.swift` gains `.mine`, `.mineEmpty`, `.mineFailure`, `.mineSignedOut` on the real `NearbyTeamsView` (`initialTab: 1`): led team 外滩夜色寻迹队 (1 applicant → N 条入队申请), joined 滨江拍照散步队, pending 老街夜走搭子, rejected 豫园寻灯小队 — all `name(en, zh)`. UI test `Fixture_r3_roamMyTeamsTests` (group ids, 去地图找队伍, retry id, guest gate without retry). | `r3-roam-my-teams`, `r3-roam-my-teams-empty` |

**For the coordinator:** please add `r3-roam-my-teams`, `-empty`, `-error`, `-signedout` to the mp-roam sweep row.

Gates: generate_project OK · check_scaffold PASS (21251 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (35) — 官方活动 task list states (01:40 "next round" item 3)

Base re-merged with `origin/ui/combined-r7` (clean). No open coordinator finding for mp-roam (05:35 sweep "nothing new"; build 7a7d2708a
`mp-roam/sheet-*.jpg` unchanged). Map panel settled (02:05) — not touched.

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/components/cy/scene-roam-task-list` (`cy-skeleton` → `cy-error 活动列表没能打开 + 重试` → stale → list / `cy-empty size="lg" title="{{emptyTitle}}" sub="{{emptySub}}"`; js `_filter`: tab titles 暂无进行中的活动 / 暂无即将开始的活动 / 还没有参与的活动, sub only while searching 没有找到相关活动 · 换个关键词试试) → `App/RoamOfficialTasksView.swift` | Empty was one plain text row with the generic `official.empty` (这个分类暂时没有官方活动) for every tab; first-load spinner was a bare `ProgressView` row, not the shared loading state. No fixture showed the page. | Empty → `ContentUnavailableView` with `query.emptyTitleKey` (per tab, shared keys `official.empty.live/upcoming/mine`, search `official.empty.search`) and the description only while searching (`official.searchEmptyDetail`); id `roam.tasks.empty` kept. Loading → `CYLoadingStateView(label: "official.loading")`, id `roam.tasks.loading` kept. New fixtures on the real view with `OfficialFixtureReader` (content / empty / failure); UI test `Fixture_r3_roamTasksTests`. No new strings. | `r3-roam-tasks`, `r3-roam-tasks-empty`, `r3-roam-tasks-error` |

**For the coordinator:** please add `r3-roam-tasks`, `-empty`, `-error` to the mp-roam sweep row.
**For mp-activity:** shared key `official.empty.upcoming` zh reads 暂无即将上线的活动; the roam MP says 暂无即将开始的活动 — left as is (shared with the activity list).

Gates: generate_project OK · check_scaffold PASS (21268 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (36) — function audit P1-17 (漫游 home uses the device location), P1-21 (导航 → Apple Maps), P1-20 (coupon code), P1-19 (扫海报码 stub removed), P1-23 (five roam read leases), P2-7 (guest 走起 sign-in, status re-read)

Base re-merged with `origin/ui/combined-r7` (fast-forward). No open coordinator finding for mp-roam; the function audit (11-28) puts P1/P2
before design work, P0-8 (team writes) is on `fix/1128-team`, not here. Map panel settled (02:05) — not touched.

| Audit id | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| **P1-17** | `pages/roam/index` `enableEntryLocation` (index.js ~6105: `wx.getLocation gcj02` → `center`, `entryLocated`, `_loadEntryMap`; `_syncRoamPermission` locates automatically when `scope.userLocation` is already granted; a tapped 开启定位 that fails opens 需要定位权限 → 去设置) → `App/NativeR2/MapHome/RoamMapHomeSheet.swift` `areaSection` / `syncLocation` / `locate`, `App/AppSessionRoamLocate.swift`, `App/QuestifyApp.swift` `roamMapHomeDependencies` | The area came only from the manual picker (typed lat/lng), so a first run always showed 先选择漫游区域 and the device location was never used (audit evidence `App/QuestifyApp.swift:858`, `App/RoamAreaPicker.swift:3-13`). | New `RoamMapHomeDependencies.locateArea` (nil in fixtures) → `AppSession.locateRoamArea()`: one foreground fix via `RoamDeviceFixGCJ.currentGCJ02Fix(RuntimeNativeLocationProvider)` (permission primer → system prompt, GCJ-02 once — the same path the nearby-teams 定位 uses) sets `session.roamArea`; the map recentres and the entry / places reads reload through the existing area change. Sheet: `.borderedProminent` 开启定位 (`nativeR2.city.enableLocation`, `CYBusyLabel` while locating, id `roam.mapHome.locate`) above the kept 选择区域; when location is already allowed it locates silently on open (MP automatic, no error); a tapped failure shows 没有取到定位，请重试 (`nearby.locationFailed`, id `roam.mapHome.locate.failed`); denied re-reads the status so the MP 需要定位 · 去设置 section takes over. No new strings. | B · shipping map home (no map-home fixture, continue 11) |
| **P1-21** | `subpackageRoam/components/roam-place-card` 导航 + `utils/open-address.js` (`wx.openLocation` on the place / address tap) → `App/PlatformConsumerSessionOwner.swift` `appleMaps()`, `App/AppSession.swift` `platformConsumers`, `App/PlatformConsumerViews.swift` `PlatformExternalMapButton` | The session built `PlatformConsumerSessionOwner()` with no maps builder, so `mapsFactory` was always nil: 导航 / 路线 was hidden on the map-home place card, the live 地点卡 (continue 17), the place page and every other `PlatformExternalMapHost` (audit evidence `App/AppSession.swift:657`, `App/PlatformConsumerSessionOwner.swift:3-4`). | The session now injects `PlatformExternalMaps(opener: NativePlatformMapOpener(), copier: NativePlatformAddressCopier(), enabled: true)`: the existing confirm dialog (将此目的地发送到 Apple 地图？) → `MKMapItem.openInMaps` for the selected place only (no live origin, no permission prompt), copy-address on failure; the owner still invalidates every model on account change. The resting caption 仅打开所选目的地 is hidden (only result states show), so the live button adds no clutter. Contract check `Tests/ContractChecks/test_roam_audit_p1_location_maps.py` (P1-17 + P1-21 wiring). **Not done:** AMap / Baidu choices need `LSApplicationQueriesSchemes` in Info.plist, which `fix/1128-wechat-login` is editing now — after it lands. | B · place card / C · utility row |
| **P1-20** + P2-7 (raw key part) | MP coupon page (my coupons: 券码 shown on the coupon) → `App/SessionRoamCouponWalletView.swift` (wallet pushed from the roam place page / featured coupon) | The roam-opened wallet set `.environment(\.couponCodeFactory, nil)`, so a coupon opened from roam could not show its code (the Me wallet can, `QuestifyApp.swift` root factory). The stale-guard branch rendered a bare `Text("roamEvent.unavailable")` on an empty page. | Same factory as the root: `{ session.makeCouponCodeCoordinator(historyID: $0) }` inside the unchanged freshness guard + `.privacySensitive()`; stale branch → `ContentUnavailableView("roamEvent.unavailable", systemImage: "ticket")`. Contract pin `test_roam_featured_coupon_wallet.py` re-pinned with a one-line reason. No new strings. | C · wallet |
| **P1-19** | `subpackageRoam/poi-detail` → `scene-roam-poi-detail` `poi-node__actions` (wxml:47–53: 收藏 · 导航 / 暂无导航 · 投一张 — no poster scan anywhere in the MP roam pages) → `App/RoamItemDetailView.swift` `placeHeader` | The place header showed a 扫海报码 capsule on every place; it opened `RoamPosterScanView(cameraEnabled: false)` with a disabled location provider and an executor built `enabled: false` (stub). | Removed the capsule (OWNER RULE: no section the MP does not have; OWNER RULE 2 / P27: no dead controls). Header keeps 开始挑战 (prominent) → 投一张 (stamp camera) → share. `SessionRoamPosterView` / the `posterDestination` parameter stay for callers but nothing opens them. No new strings. | B · place page |
| **P1-23** | MP reads: `subpackageRoam/nearby` `GET /api/roam/hangout/nearby` (地点玩法 layer), `scene-roam-stamp-album` `/api/roam/stamp/list` (我的) + `/api/roam/stamp/received` (收到的), history fog `/api/roam/tiles/page`, `subpackageRoam/session` `GET /api/roam/session` → `App/ReviewedPlayerWriteLeases.swift` (`roamNearbyEvents`, `roamReceivedStamp`, `roamAlbumMetadata`, `roamTileMemory`, `roamSessionFact`), `App/AppCompositionRoot.swift` init | The five readers existed but their access closures defaulted to `{ _ in nil }` with no production-gate fallback, so in Release the roam browser 活动 layer, received stamps, album metadata, tile memory and session facts all read "not configured" (audit evidence `App/AppCompositionRoot.swift:472-476,537-551`). | Each gets a lease in the same shape as `roamNearbyPlayers`: signed-in China player / club / merchant, one exact path, cached per context and revoked on change; the composition uses `injected(context) ?? (productionGatesEnabled ? gates.x(context) : nil)` like the other roam reads. Unit tests with `productionGatesEnabled == false` (default-nil cases) are unchanged. Contract check in `test_roam_audit_p1_location_maps.py`. | — |
| P2-7 (guest 走起) | `pages/roam/index` `goStart` (index.js:2951–2975: no session → `app.requireLogin({ reason: 'roam' })`; signed in → `_loadEntryMap` + `goStart()` again; 暂不登录 → stay as is) → `App/NativeR2/MapHome/RoamMapHomeSheet.swift` `startRoam`, `RoamMapHomeDependencies.signInToStart`, `App/QuestifyApp.swift` | A guest tapping 走起 opened the live cover on "此账号暂不可使用实时漫游" with no way to sign in. | `signInToStart` is non-nil only while `session.account == nil` and calls the root `requestSignIn(then:)` (existing sign-in sheet, resume after success), so the walk starts right after sign-in; dismissing leaves the map home unchanged. Contract check added to `test_roam_audit_p1_location_maps.py`. No new strings. | A · roam start |
| P2-7 (city link titles) | — → `App/CityPlayerView.swift` | Audit: titles hard-coded zh. | **Resolved by reading:** the four titles are Chinese-literal catalog keys with en values (City map snapshot / City map update / City team participation / City action budget), so they localize; the page is Release-off with P1-22 (region). Left to en-layout (audit row owner). | — |
| P2-7 (part) | same page, `_syncRoamPermission` on `onShow` | The status was read once in `.task` and never after returning from Settings. | `scenePhase == .active` re-reads the status (and locates when it is now allowed and no area is set). Guest 走起, city titles and the raw key are in the rows above; `/api/roam/checkin` stays open. | — |

Gates: generate_project OK · check_scaffold PASS (21277 keys) · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (37) — coordinator 07:05 finding (`r3-roam-routes-empty` next step), P1-18 presence heartbeat, P1-24 location-share entries

(P1-19 and P2-7 guest 走起 / city titles landed from the twin run in continue 36 — not repeated here.)

| MP page → native | Difference | Fix | Fixture |
|---|---|---|---|
| `subpackageRoam/official-routes` (`cy-empty 还没有上架的官方线路`; page `goBack` → `navigateBack` / `switchTab pages/roam/index`) → `App/NativeR2/MapHome/RoamMapHomeRoutes.swift` `.empty` | The empty `ContentUnavailableView` had title + icon only (coordinator 07:05, P2). | `ContentUnavailableView` actions gain `.bordered` 返回地图 / Back to map (existing key `roamSub.w208.poi.backToMap`) → `dismiss()` pops the routes list back to the map sheet (the MP `goBack` target). Id `officialRoute.list.empty.backToMap`; UI test `Fixture_r3_roamRoutesStatesTests.testRoutesEmptyShowsMPEmptyState` checks the button. No new strings. | `r3-roam-routes-empty` |
| **P1-18** — `pages/roam/index` `_reportPresence` (index.js 2796: every 30 s on a real fix, `POST /api/roam/presence {sessionId, lat, lng, explorePct}`, sharing off by default, only the separate consent endpoint turns it on) → `App/ReviewedPlayerWriteLeases.swift` `roamLive` | The live lease was `presence: false` without the path, so `presenceAvailable` was always false: the 附近的人位置分享 toggle hid and no heartbeat was ever sent (audit `ReviewedPlayerWriteLeases.swift:1172`). | Lease now carries `api/roam/presence` and `presence: true`. Unchanged guards: reports start only when the player accepted presence (`presenceAccepted` default false) or the server confirmed the tools-sheet toggle (`setPresenceSharing`, `/api/roam/presence-visibility`), 30 s throttle, GCJ-02 ≤ 80 m fixes, pause stops. Field names match the MP. Contract check `test_live_lease_carries_presence_like_mp_report_presence`. | A · live map |
| **P1-24** — no MP page (no `location-share` anywhere in the MP; MP shezhi 隐私与定位 has no 位置共享 row) → `App/SettingsView.swift` 位置共享 row, `App/SocialPublicProfileView.swift` 共享我的位置 row | Both rows showed although `installReviewedPersonalLocationShareApprovals` has no caller, so every request was refused (audit `AppSession.swift:1033`, `SettingsView.swift:234`). | New `PersonalLocationShareOfferedLink` (`App/PersonalLocationShareHost.swift`) renders the row only when the host has a read approval and a base URL (`PersonalLocationShareHost.isOffered`); both call sites use it with their old ids and keys. Today: hidden in Release (OWNER RULE: no section the MP lacks; OWNER RULE 2: no dead controls). Contract check `test_personal_location_share_entries_hide_while_off`. No new strings. | C · settings / profile |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. Contract checks `test_roam_audit_p1_location_maps.py` OK (7). No Swift build here.

## Round 3 continue (38) — function audit P1-21 rest (导航 offers AMap / Baidu Maps)

Base re-merged with `origin/ui/combined-r7` (clean; `fix/1128-wechat-login` landed, so Info.plist `LSApplicationQueriesSchemes` is free to extend). No open coordinator finding for mp-roam. Map panel settled (02:05) — not touched.

| Audit id | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| **P1-21** (rest, Not done since continue 36) | `subpackageRoam/components/roam-place-card` 导航 + `utils/open-address.js` (`wx.openLocation`: WeChat's map page lets the player pick Apple Maps / 高德 / 百度) → `Core/PlatformExternalMaps.swift` (`PlatformMapApp`, `PlatformMapDestination.launchURL(in:)`), `App/NativePlatformAdapters.swift` `NativePlatformMapOpener`, `App/PlatformConsumerViews.swift` `PlatformExternalMapButton`, `App/NativeR2/MapHome/RoamMapHomePlaceCard.swift` `directionsActions`, `Config/Info.plist` | 导航 could only send the place to Apple Maps. | The opener lists Apple Maps plus AMap / Baidu Maps when `canOpenURL` finds them (`iosamap`, `baidumap` added to `LSApplicationQueriesSchemes`); the review dialog shows one system button per installed app (高德地图 / 百度地图 / Apple 地图, title 用哪个地图打开这个目的地？) and keeps the old single "在 Apple 地图中打开" button when only Apple Maps is there. Walking directions, GCJ-02 coordinates as-is (`dev=0`, `coord_type=gcj02`, like the MP `gcj02` fixes). Same result states / copy-address fallback. Protocol additions have defaults, so the other callers (free explore, coupons, meeting point) keep Apple Maps unchanged. Core test `PlatformConsumerTests.testMapAppChoiceOpensChosenAppWithGCJWalkingLink`; contract pin `test_universal_link_associated_domains.py` re-pinned (one-line reason). New keys `platform.map.app.apple/amap/baidu`, `platform.map.choose` (en + zh-Hans). | B · place card / A · live 地点卡 |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. Contract checks `test_universal_link_associated_domains.py` + `test_roam_audit_p1_location_maps.py` OK (11). No Swift build here.

## Round 3 continue (39) — function audit P1-25 (US roam)

Rebased onto `origin/mp/r3-roam` (twin run). No open coordinator finding for mp-roam (07:45 sweep: none). Map panel settled (02:05) — not touched.

| Audit id | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| **P1-25** | `pages/roam/index` 走起 / live roam, `subpackageRoam/nearby` teams (MP has one backend, no market split) → `App/RegionalLaunchConfiguration.swift` `shippedComposition`, `App/ReviewedPlayerWriteLeases.swift` `roamLive` / `roamLiveWrite` / `nearbyTeamRead` / `nearbyTeamWrite`, `Core/RoamLiveContracts.swift` `RoamLiveApproval.allows`, `App/AppSession.swift` `currentRoamExperienceSession` | The audit read the literal China-only checks (`market == "cn"`, `context.market == .china`). Since US launch r1 (11-27) the shipped US build is pinned to the shared reviewed backend (`BuildMetadata(market: CN …)`), so `regionalConfiguration.market`, the runtime context and the roam identity scope are all CN for US players; only `storefrontMarket` stays US for presentation. The leases are therefore issued in the US build; nothing in roam reads `storefrontMarket`. | **Resolved by reading + proved in Release:** no gate widened (a US-market context is never built by the shipped app, so widening would only open an unreachable path). New `Tests/AppUnitTests/RoamUnitedStatesReleaseCompositionTests.swift` builds `RegionalLaunchConfiguration.shippedComposition` for a US build on the reviewed host and asserts: production gates on; `roamLiveApproval` non-nil with every `RoamLiveApproval.requiredPaths` + `api/roam/presence`; `approval.allows` the identity AppSession builds (`regional.market.rawValue`); `roamLiveWriteApproval` non-nil; nearby-team read + the three write paths for player / club / merchant; guest gets none. No new strings. | A · live roam |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (40) — planning audit R-02f+ (finish uploads the track)

| Audit id | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| **R-02f+** (planning audit "next after the 30") | `pages/roam/index.js` `sendFinish` (2026-10-31 P-7: `track` = `JSON.stringify([[lat,lng],…])`, every `ceil(n/600)`-th point + the last, `''` when ≤1 point; history card `utils/roam-passport-read.js` draws it) → `Core/RoamExperienceMutationContracts.swift` `.finish(…, track:)` + `finishTrack`, `Core/RoamLiveContracts.swift` `RoamLiveServing.finish(…, track:)` (default forwards to the old call, so fixtures / test doubles are unchanged), `Core/RoamLiveService.swift`, `Core/RoamLiveSessionController.swift` finish | The finish sent only `sessionId` / `poiIds` / `distanceM`, so iOS walks had no server track and the passport history card on another device / after reinstall had no route. | **Fixed:** the controller passes its in-memory accepted track (GCJ-02 fixes, same datum as the MP) to the finish; the request adds `track` in the MP JSON shape when ≥2 points remain after the MP thinning. The track stays in memory only (the durable `RoamLiveRecord` still keeps no fixes), so a finish replayed after recovery sends none, like an MP finish with an empty `_track`. Core test `RoamExperienceMutationTests.testFinishCarriesTheThinnedTrackLikeTheMP`; the exact-fields pin for a trackless finish is unchanged. No new strings. | A · live roam |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (41) — OWNER RULE 3 celebration: stamp collected (owner mp-roam)

Base re-merged with `origin/ui/combined-r7` (clean). No open coordinator finding for mp-roam (07:45 sweep: none). Map panel settled (02:05) — not touched; fog / lit trail are on `fix/1128b-maps` (#24), not here.

| MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|
| `subpackageRoam/citystamp` ③ 换票 (wxml:68–135: tear the slip, scratch 六成 → 解锁「收下，出发」) → `App/RoamSubpageParityViews.swift` `RoamStampSlipView.paper` | The reveal (the moment the exchanged stamp is collected) had only the success haptic; OWNER RULE 3 lists "stamp collected" as a Level A celebration. MP sections / order unchanged. | New `App/RoamStampRevealCelebration.swift` (`roamStampCollectedBurst(_:)`, name matches the gate's `*Celebration*` surface): one `CYBurst` dust burst over the slip when `revealed` turns true (it never turns back), on top of the existing `.success` haptic and `CYMotion.standard` transition. Reduce Motion / Low Power / thermal → nothing drawn (`CYLightBudget.particlesAllowed`); no hit testing; hidden from VoiceOver. | A · celebration / citystamp slip (live route only; not in a fixture) |
| P3 存入集邮册 → 已入册 (`scene-roam-stamp-album` landing) → `App/RoamCreatedStampView.swift` `.found` match card | The created stamp slammed in (`cyStampSlam`) with a heavy tap but no light. | Same burst once on the match card, after the slam (same gating). | A · celebration / created stamp |

No new strings. Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS (effect on clean page: 0) · contract_ratchet **new 0**. No Swift build here.

## Round 3 continue (42) — ADA audit `e2-stamp-album` (P0): 共 N 枚 matches the grid, grouped ground

(The stamp-collected burst landed from the twin run in continue 41; not repeated.)

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| ADA `e2-stamp-album` (P0, "3 stamps in total while showing 2"; white background) | `subpackageRoam/components/cy/scene-roam-stamp-album` (`album-sub` 共 `total` 枚 = server total; the live list never carries `check_state 2` rows, index.js:82 comment) → `App/RoamExperienceFixtureSupport.swift` `album`, `App/NativeR2/FreeExplore/NativeStampAlbumView.swift` | The design fixture carried a moderation-hidden row (903, `checkState 2`) counted in `total: 3`; the pager drops it (the MP server-count rule is pinned in `RoamReceivedStampMetadataScopeTests.testOriginalModerationFilterKeepsServerCountAndNoOtherReadOpens`, so Core is unchanged). Page ground was plain white. | Design-fixture mode drops row 903 and sets `total: 2` (UI tests without `--design-fixture` keep the pinned rows). Album ground → `cyGroupedBackground()` (system grouped) like the other pushed collection pages. MP sections / order unchanged (no named locked silhouettes or dates added: the MP grid has one 还没收到 cell and captions only). No new strings. | B · `e2-stamp-album` |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (43) — ADA audit `d6-roam` (P1): the 附近活动 peek never disappears

Base re-merged with `origin/ui/combined-r7` (62 commits, no conflict). Screens read: `docs/sweeps/latest/mp-roam/en-d6-roam.jpg`, `en-d2-roam.jpg`.

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| ADA `d6-roam` (P1, "blank map with three buttons and no status words"; cross-screen "d6 duplicates d2") | `pages/roam/index.wxml` entry-peek (owner P-26 2026-10-27: 附近活动 always shows; empty → `entry-peek__state` 附近暂无活动 · 打开地图寻找附近活动 → `openNearbyMap`) → `App/DesignFixtures/D6Fixtures.swift` `roamEmptyPeek` (shipping twin: `RoamMapHomeSheet.nearbyRows` empty branch) | The fixture drew the map + 规则 / 走起 / 附近 with no sheet at all, which the MP never shows; it also read as a copy of d2-roam. | d6-roam now keeps the collapsed map sheet (`cyMapSheet`, detents 236 pt / medium) holding the 附近活动 section with the MP empty state: `ContentUnavailableView` 附近暂无活动 + `.bordered` 打开地图寻找附近活动 (same keys, glyph and id as the shipping map home). The fixture now shows a distinct state (nothing nearby) instead of duplicating d2-roam. No new strings. | A · `d6-roam` |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (44) — 据点核销码 error state follows the MP `qr-voucher` error card (page with only a shallow row)

| MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|
| `subpackageRoam/citynode-code` → `components/cy/scene-qr-citynode` → `components/cy/qr-voucher` `qr__error` (icon + `errorText` 暂时无法生成核销码，请稍后重试 / 网络异常 / 核销码二维码没能生成 + 重试; desc and countdown hidden) → `App/RoamSubpageParityViews.swift` `RoamCityVoucherCodeView` → `App/VerificationCodeView.swift` `content` (city voucher, `autoIssue`) | Sections re-checked in MP order: missing-param shell + 返回 ✓, guest gate (登录) ✓, loading (P10 words) ✓, code + 「Ns 后自动刷新」 + 出示给商家扫码领券 ✓, auto re-issue at 0 and on return to foreground ✓. Only the error differed: a bare centred line plus a `.borderedProminent` 重试, while the entry-code error on the same view already uses the shared `ContentUnavailableView` pattern. | Failed / invalid city-voucher codes now render `ContentUnavailableView` (qrcode glyph, the MP error line as the title, `.bordered` 重试). Same ids (`verificationCode.phase`, `verificationCode.show`) and same copy keys (network vs issue line unchanged), so UI tests and Core pins are untouched. Other code kinds unchanged. No new strings. | C · utility (no fixture; live route) |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 52 / baseline 52, **new 0**. No Swift build here.

## Round 3 continue (45) — ADA audit `e5b-stamp` (P1): the sweep shows the real stamp-collected moment

Base re-merged with `origin/ui/combined-r7` (clean). No new coordinator finding for mp-roam since 07:45; the latest sweep is still build 3348aa51f.

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| ADA `e5b-stamp` (P1: "generic pin glyph, not the stamp"; "Lantern Gate is not in the album"; coral/purple colours used nowhere else; no visible celebration) | `subpackageRoam/citystamp` ③ 换票 (wxml:68–135: 出发 · place · time / 签号 → 留签人 / 留于 → the stamp photo → 留给你的一句 (scratch) → 保存到相册 · 收下，出发) → `App/RoamSubpageParityViews.swift` `RoamStampSlipView`; fixture `App/DesignFixtures/RoamStampCollectedFixture.swift`, `DesignFixtureRegistry.swift` | `e5b-stamp` mounted `CYCelebrationMoment(kind: .stamp)`, a DesignSystem demo that no player screen uses (no production caller), so the sweep judged a screen players never see. The real moment (MP 换票 slip, with the continue-41 burst and success haptic) had no fixture. | `e5b-stamp` now mounts the real slip, collected: new optional `revealedAtStart` (opens torn + revealed on appear, so the burst and `.success` haptic play once, Reduce Motion → no burst) and `sampleArt` (bundled MP art instead of the remote photo) on `RoamStampSlipView` / `RoamStampSlipPhotoView`, both default off so the two live call sites are unchanged. The fixture uses stamp 902 with the same caption (老街霓虹 / Old street neon) and art (`MPAsset.BannerCover.cityCamera`) as the `e2-stamp-album` tile, on the grouped ground, inline title 城市贴纸 like the flow. MP actions kept as the MP has them (保存到相册 + 收下，出发); the ADA "See my stamps" / Share additions are not in the MP 换票 step, so not added (OWNER RULE). No new strings. | A · celebration / `e5b-stamp` |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet **new 0**. No Swift build here.

## Round 3 continue (46) — ADA audit `d2-roam` (P0 "roam is not shown"): the sweep mounts the shipping map home

Base re-merged with `origin/ui/combined-r7` (clean). Sweep build 0446d1c4f read: `mp-roam/sheet-zh-Hans.jpg` (d2-roam / d6-roam = legacy browser: drawn grid, inline 漫游, i · 走起 · map), `a11y-dt/zh-Hans-a11y-roam-ax5.jpg`. No new coordinator finding for mp-roam since 07:45.

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| ADA `d2-roam` (P0: drawn grid, no tiles / position, inline title vs AX5 large) + `d6-roam` (P1); Not done since continue (11) | `pages/roam/index` → shipping tab root `App/NativeR2/MapHome/RoamMapHomeView.swift` (`QuestifyApp.roamTab`, `NativeR2Flags.mapHome` default on); fixtures `App/DesignFixtures/RoamMapHomeFixture.swift` (new), `DesignFixtureRegistry.swift` | Both roam shots mounted the legacy `RoamBrowserView` (players only see it as the 漫游护照与工具 sheet) or a D6 mock of it, so the sweep, the ADA review and the App Store harness (`roam` → `d2-roam`) judged a screen that is not the tab root: no MapKit tiles, no Apple-Maps panel, a title style the real root does not have. | `d2-roam` → `RoamMapHomeFixture()` and `d6-roam` → `RoamMapHomeFixture(nearbyEmpty: true)`: the real `RoamMapHomeView` with synthetic readers only (no session, location, network, write). Places (灯笼门 / 老街霓虹 / 转角咖啡) and the entry 附近活动 rows (外滩夜色寻线 / 老街自由探索) sit around People's Square (GCJ-02) and follow the UI language; the empty variant shows the MP P-26 empty peek. Offline-example footer off (the shot shows what players see). Legacy `RoamHomeFixtureHostView` (`--uitesting-roam-home` UI tests) unchanged; `D6MapFixture(.roam)` mock is now unused. No new strings. | A · map home / `d2-roam`, `d6-roam` |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet **new 0**. No Swift build here.

## Round 3 continue (47) — ADA audit "Inclusivity": forced `.accessibility3` on the 结算 big number

No new coordinator finding for mp-roam since 07:45; latest sweep still build 0446d1c4f (`mp-roam/sheet-zh-Hans.jpg` read in continue 46). No B-lane receipt on origin yet (`origin/mp/r3-roam-b` absent).

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| ADA `1128-ada.md` Inclusivity row ("a forced `.accessibility3` at `RoamFinishReportView.swift:192`") | `pages/roam/index` settle__big 处到达 (wxml:900–901) → `App/RoamFinishReportView.swift` `bigNumber` | The hero count was pinned to AX3 whatever the reader's setting, so at AX4/AX5 it stopped scaling while the caption under it kept growing. | `.dynamicTypeSize(max(dynamicTypeSize, DynamicTypeSize.accessibility3))`: the number keeps its MP hero size at default sizes and now follows the reader at AX4/AX5. MP section, order and copy unchanged. No new strings. | A · finish / `t5-settle`-style roam result |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet **new 0**. No Swift build here.

## Round 3 continue (48) — pages without a row: roam components; official-route share on the shipping route card

Base re-merged with `origin/ui/combined-r7` (clean). Latest sweep still build 0446d1c4f (no new mp-roam finding). B lane (`mp/r3-roam-b`) finished "team-recovery per-command rows on my-teams / nearby" (marked below).
Pages in the area with no row until now, read this run: `components/roam-photo` (decorative event photo / 3D icon, `aria-hidden`; native rows use SF Symbols — no content), `components/roam-place-note` (tag → 推荐理由 + 资料来源 lookup; already rendered on the place card, row `pages/roam/index` 地标 · 地点卡), `components/cy/share-card` (roam page never sets `shareCard.show`, dead in the MP roam page), `components/cy/scene-qr-citynode` (covered by the `citynode-code` rows), `components/cy/route-thumb` / `scene-roam-history` (covered by `history` rows), `components/cy/slide-confirm` (used by `pages/play`, mp-journey), `components/roam-atmos-entry` (weather/atmosphere: `fix/1128c-ai-weather`), `utils/team-recovery-panel` (B lane).

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| MP `subpackageRoam/official-route/index.js` `SHARE_PATH` + `onShareAppMessage` / `onShareTimeline` (title = route name, else 城瘾官方线路; path `?id=`) | `subpackageRoam/official-route` → shipping `App/NativeR2/MapHome/RoamMapHomeRoutes.swift` `RoamMapHomeRouteCard` | The legacy `OfficialRouteDetailView` had a share card, but the route card players reach from the map home had no share at all, and no https link existed for the route page. | `Core/PublicContentShareLink.officialRoute(id:)` (MP path, kept only when `UniversalLinkParser` reads it back as the same `MiniProgramPageLink`); the route card's toolbar gets a system `ShareLink` (subject + preview = route name, fallback `officialRoute.share.fallbackTitle` 城瘾官方线路 / Chein official route) once the route is loaded. Test `PublicContentShareLinkTests.testOfficialRouteShareIsTheMiniProgramRoutePageThatParsesBack`. | B · `r3-roam-routes` → route card |
| A row "team-recovery per-command rows on my-teams / nearby" | `subpackageRoam/my-teams`, `nearby` | — | Done (B lane, `817059d4c`). | — |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 46 / baseline 46, **new 0**. No Swift build here.

## Round 3 continue (49) — live map 输入地址 (MP `cy-map-address-search`, no row yet); B-lane P2-7 slice noted

Base: `origin/mp/r3-roam` (contains `origin/ui/combined-r7`). No new coordinator finding for mp-roam (latest sweep still build 0446d1c4f). B lane landed the P2-7 Core outcome slice (`f3b61106d`, `nothingToRecord`); the MapKit POI tap stays open (compiled pass).
ADA #2 "fog / explored area on the Roam tab root": the MP draws the fog only on `screen=='opening'|'map'|'arrive'` (wxml:229–250), never on `entry-map`; the live walk fog is on (`3a60af988`, gap #24). Map home stays without fog (OWNER RULE: MP decides content).

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| `pages/roam/index.wxml:297` `cy-map-address-search` (`screen=='map'`, `places = _searchPlaces()` = `_pois` with lat/lng; `components/cy/map-address-search`: 输入地址 bar → field 路名、门牌号或店名 + 取消 → ≤ 5 rows pin · name · address → 这附近没有搜到; `onSearchPick` moves the map, no page change) | `App/RoamLiveSessionView.swift` (toolbar + `Map(position:)`) + new `App/RoamLiveAddressSearch.swift` | The live map had no address search at all. | **Fixed:** a `magnifyingglass` toolbar item 输入地址 (id `roam.live.addressSearch`) opens a system sheet (medium / large) with `.searchable` (prompt 路名、门牌号或店名), 取消 as the cancellation action, and up to five of the session's located places matching name or address (MP `matchPlaces` ①), row = node-level glyph · name · address/description; empty = `ContentUnavailableView` 这附近没有搜到. Pick = camera to a 600 m region on the place (animated; Reduce Motion → no animation) and the pin selected, which opens its 地点卡 facts in 附近 and lifts the sheet (existing `mapPick` path). The live map now holds a `MapCameraPosition` (starts at `.userLocation(fallback: .automatic)` as before). New keys `roam.live.addressSearch.title/.prompt/.none` (en + zh-Hans, also in `docs/port/strings/mp-r3-roam.json`). **Not done:** MP remote fallback (Tencent place search, then `/api/city/nodes?keyword=`, 联网搜索暂时不可用…) and the per-row 导航 — next run. | A · live map / no fixture shot |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 46 / baseline 46, **new 0**. No Swift build here.

## Round 3 continue (50) — live 输入地址 remote leg + per-row 导航 (Not done since continue 49)

Base re-merged with `origin/ui/combined-r7` (xcstrings conflict: both sides' keys kept). No new coordinator finding for mp-roam (brief sweeps through 13:15 list none for roam). B lane receipt read: nothing on this row. Map panel settled (02:05) — not touched.

| Source | MP page → native | Difference | Fix | Level / fixture |
|---|---|---|---|---|
| `components/cy/map-address-search` `_searchRemote` / `_searchNodes` / `onNavigate` / wxml `addrrow__nav` + `addrlist__none` (正在搜索… / 这附近没有搜到 / 联网搜索暂时不可用，先显示附近的地点); `utils/map-address-search.js#cityNodesToPlaces` — Not done since continue (49) | `App/RoamLiveAddressSearch.swift` (`RoamLiveAddressMatch.rows`, `RoamLiveAddressRow`, `RoamLiveRemotePlaceModel`, sheet), `App/RoamLiveSessionView.swift` (`addressSearchCenter`, `pickAddress`), `Core/MapSearchPlayerService.swift` `cityNodePlaces` | The live 输入地址 sheet only filtered the session's own places: no remote search (owner 10-28: 「海星市场」 must be findable), no node-library fallback, no 正在搜索… / remote-error line, and no 导航 on a row. | **Fixed:** keyword ≥ 2 characters → 350 ms debounce, last keystroke wins → `POST api/map/place-search {keyword, longitude, latitude}` around the map centre (live map follows the player: the GCJ-02 fix, else the first located place); empty (Tencent off) → `GET api/city/nodes {lat, lng, radius: 20000, keyword}` (new Core `cityNodePlaces`: `name` else `merchantName`, point required, same-name dropped, `node-<poiId>`); place-search failure → MP line 联网搜索暂时不可用，先显示附近的地点 and the node rows still join. Rows = local matches first, then remote, same-name dropped, five at most (MP `_refresh`). Remote rows use a neutral `mappin` (MP `kind: 'place'` grey pin); picking one moves the camera only, a session place also selects its pin (地点卡) as before. Keyboard 搜索 picks the first row (MP `onConfirm`). Empty while searching = 正在搜索… (`search.r3.loading.results`), otherwise 这附近没有搜到. Each row gets a trailing `.borderless` 导航 (`nativeR2.mapHome.card.navigate`, VoiceOver 导航到<name>) → the P1-21 map-app choice (Apple / 高德 / 百度) via the session `makeExternalMaps`; hidden when maps are not configured (fixtures). Remote leg only with `socialRoamCapabilities` (signed in). Test `PlayerCapabilityRoutesTests.testAddressSearchCityNodeFallbackMatchesMP`. New keys `roam.live.addressSearch.remoteError`, `roam.live.addressSearch.navigateTo %@` (en + zh-Hans, also in `docs/port/strings/mp-r3-roam.json`). | A · live map / no fixture shot |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 46 / baseline 46, **new 0**. No Swift build here.

## Round 3 continue (51) — A half (collision rule 15:45): P2-7 toasts slice; coordinator 15:50 `d2-roam` black tile

A-half rows this run (open rows in file order ①–⑥, B lane took ④–⑥ and "B half done"): ① P1-22 / P2-7 rest, ② citystamp write step, ③ P21 mini bar.

| MP page → native | Difference | Fix | Level / evidence |
|---|---|---|---|
| Coordinator 15:50 P2: first roam fixture is the black launch screen | `zh-Hans-d2-roam.jpg` / `en-d2-roam.jpg` (build c4e43841a) show the system launch screen (`UILaunchScreen` `LaunchMark`); `d6-roam` mounts the same `RoamMapHomeFixture` (only `nearbyEmpty` differs) and renders map + sheet. `RoamMapHomeView` has no synchronous location / `CLLocationManager` work and no app overlay; the fixture readers are synchronous synthetic data. | **Not app-side:** the first fixture of the lane is the cold launch after install (MapKit first use), so the shot is taken before the first frame. The sweep needs a first-content wait for `d2-roam` (e.g. wait for `roam.mapHome` / any hittable element, as `Tests/AppUITests/Fixture_d2_roamTests.swift` does with 20 s) or a warm-up launch — sweep script (coordinator). | `d2-roam` |
| `pages/roam/index.js` `onPoiTap` toasts (开启实时定位后才能点亮 / 离得有点远，走近点 / +xp 探索值 · 点亮<name> / 已点亮过 / 这个地点暂时没有可记录的信息 / 网络异常，请重试 / 登录后才能点亮 / 服务暂不可用) — ① P2-7 rest | new `Core/RoamCheckinFeedback.swift` | B's Core slice gave the disposition, but no MP toast copy or error mapping existed, so the map tap (compiled pass) would have had to invent copy. | **Fixed (slice):** `RoamCheckinFeedback(disposition:placeName:)` / `(error:)` → one MP toast key each (`openPlace` = the MP `roam-poi-detail` scene, no toast); 8 new keys `roam.checkin.*` en + zh-Hans (also in `docs/port/strings/mp-r3-roam.json`). Test `Tests/CoreTests/RoamCheckinFeedbackTests.swift`. **Still open (compiled pass):** MapKit POI feature selection (iOS 18 branch), live fix as `curLat/curLng`, `.checkin` capability on + Release-composition test. | C · contract / no fixture shot |
| ② citystamp write step, ③ P21 mini bar | — | Both need a Swift build (wide session wiring) or the nav lane; unchanged. ① P1-22 waits on the owner's city-game region list. | — |

Gates: generate_project OK · check_scaffold PASS · a11y lint 0 new · design consistency PASS · contract_ratchet 46 / baseline 46, **new 0**. No Swift build here.

**A half done** for this run: every remaining A-half row needs a compiled pass or an owner value.

## Round 3 continue (52) — merge `ui/combined-r7`; A half still done

- Merged `origin/ui/combined-r7`. No `cursor-k50-p*` receipts exist yet (K50 posted 16:34), so no `lane-layout` rows for roam to take; the next run reads them.
- Sweep unchanged (build c4e43841a, handled in continue 51). Every `pages/roam` / `subpackageRoam` page and component has a row (see the "no row until now" line).
- A-half open rows (P2-7 MapKit POI tap, citystamp write-step coordinator, P21 mini bar) still need a compiled pass; P1-22 waits on the owner's region list. **A half done** — stopped per the 15:45 collision rule.

## Not done / next

- Planning audit R-02f+ (finish track): done (continue 40). R-04c nearby 活动/主题 layer = P1-23 lease (done continue 36/P1-23).
- Function audit (mp-roam, not on a fix worker): P1-21 done (continue 38), P1-22 city-game region (owner value), P1-25 done (continue 39, shared backend),
  P2-7 rest (MP toast copy + error mapping done continue 51; `/api/roam/checkin` from 点亮: the MP posts it when the player taps a *built-in* map POI (`bindpoitap`); native needs MapKit feature
  selection (`MapSelection<MapFeature>`, iOS 18) beside the existing pin selection plus a `.checkin` capability (`productionEnabled` false today) — compiled pass).

- citystamp end-to-end MP flow (camera only shoots → write step note → mailbox send creates + exchanges): the live write step still has no
  `RoamStampExchangeCoordinator` (never instantiated), so the citystamp camera (`showsCaption: true`) keeps its caption + exchange. Needs an
  upload-only camera mode returning the picture URL and session wiring for the coordinator — left for a compiled pass.
- team-recovery per-command rows on my-teams / nearby: done (B lane, `817059d4c`).
- Live 输入地址 (continue 49): remote place search fallback and per-row 导航: done (continue 50).
- P2-7 Core outcome slice: done (B lane, `f3b61106d`); map POI tap still open.
- P21 mini bar for a running roam: the live session is a full-screen cover owning its own controller (`makeRoamLiveSessionController()` per presentation); a cross-tab bar needs the controller lifted to the session and a root-tab accessory (nav lane) — compiled pass.
- Topic half-screen from merchant pins + shop photo pins: done in continue (23).
- For other lanes (ds-consistency, mp-journey, mp-activity): the default panel is now ds-consistency's elevated surface (follows the appearance); roam additionally opts into `.environment(\.cyMapPanelFollowsAppearance, true)` (continue 24). The other `CYMapScaffold` users (`PlayExperienceView`, `PlaySessionView`, `NearbyTeamViews`) and `CYRoamNearbySheet` (fixture only) still use the black `cyMapPanelColor`; opt in once their panel content is checked for semantic colours.
- For a11y-dt: `a11y-roam-ax5` is a hand-built mock of the legacy browser (large title, filled ⋯ circle); now that `d2-roam` mounts the real map home (continue 46), mount `RoamMapHomeFixture()` with `.environment(\.dynamicTypeSize, .accessibility5)` instead.
- Entry peek `.login`: 401 part done in continue (16); the no-deployment `.login` fixture state stays (not reachable by players).
- Live map bottom strip P-32: done in continue (21) for the map home (shipping tab root); the legacy `RoamBrowserView` live cover (flag off) gets no feed.
- No Swift build ran here; integrator compiles.
- For ds-consistency: `CYCelebrationMoment` `.stamp` (generic `mappin.and.ellipse`, hard-coded coral ink) has no production caller; `e5b-stamp` now shows the roam slip instead (continue 45). Remove the `.stamp` kind or give it the stamp art if a screen starts using it.
