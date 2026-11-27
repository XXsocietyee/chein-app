# mp-roam — round 3 (2026-11-27)

Branch `mp/r3-roam` from `origin/ui/combined-r7`. Scope: tab 漫游 (`pages/roam/index`) and `subpackageRoam/*`.
Source of truth: `origin/mp-source:chengyinhub-xcx`. For each MP page the `.wxml` sections were listed top to bottom and
compared with the native screen that ships today (the 漫游 tab root is `NativeR2/MapHome`, `NativeR2Flags.mapHome` on).
No Swift compiler here: edits mirror existing patterns; nothing deployed; merchant and story-flow untouched.

## MP page → native view → differences → fixed / not

| MP page | Native view | Differences found (MP order / fields / states / targets) | Status |
|---|---|---|---|
| `pages/roam/index` 开始 (intro) | `NativeR2/MapHome/RoamMapHomeSheet.swift` | 1. MP shows `需要定位才能开始漫游 · 去设置` at the top of the page, above the tickets; native showed it inside the 附近 list (below the 漫游 actions). 2. MP `cy-error 上次漫游需要确认 · 确认漫游记录` above the tickets; native map home had no recovery read. 3. MP ticket NO.01 says `继续漫游` when a walk is unfinished; native always said Start roaming. 4. MP ticket NO.01 / NO.03 carry a sub line (走到哪，雾散到哪 / 查看已加入和申请中的队伍); native rows had none. | Fixed: location section moved to the top (also offers 选择区域); recovery read wired (`RoamHomeRecoveryEntry`, same as the roam browser) → `roam.w208.recovery.needsCheck` + `确认漫游记录` → `RoamRecoveryView`; start row title `继续漫游` when `.recovered`; sub lines added. New dependency `RoamMapHomeDependencies.experienceReader` passed from `QuestifyApp` (`session.roamExperienceReader`). |
| `pages/roam/index` 开始 · `entry-peek` | `RoamMapHomeSheet` 附近 section | MP tabs 附近活动 / 本城推荐 + fold; native uses the Maps-style category picker (all/activities/places/routes/teams) — map-home adaptation already approved in native r2. MP has no refresh in the header; native map home has none either (retry only on failure). | Not changed (structure is the native map-home pattern). |
| `pages/roam/index` 开始 · `entry-peek` (legacy browser) | `RoamHomeTabsView.swift` `RoamEntryPeekView` | Loading said "Loading map results…" (`roam.loading`); MP aria 正在读取附近活动. Header refresh button is extra vs MP, but `RoamNearbyEventsRestoredDetailTests` taps it, so it stays. | Fixed loading words (`roam.w208.entry.loading`). Refresh kept (test-pinned). |
| `pages/roam/index` 漫游护照 | `RoamHomePassportView` (in roam browser sheet, opens on 护照 tab) | Order matches: 4 stats (漫游 / 探店 / 活跃日 / 公里, `—` while loading) → tiles → plays (官方路线 after 官方活动). | No change needed. |
| `pages/roam/index` B1 live map / pcard / pbar | `RoamLiveSessionView.swift` | pcard 用时 / 地盘 / 距离 and 更多 · 暂停 · 拍照 already mirrored (design pass roam, ROAM-4). | No change this round. |
| `pages/roam/index` 结算 (`screen=='arrive'`) | `RoamFinishReportView.swift` | Date line, `zone · 自由漫游`, hero 处到达, six cells 公里 · 用时 · 探索度 · 邮票 · 探索值 · 勋章, stamp strip, route story, 漫游记录 exit already mirrored (design-r2-roam P16). MP 查看漫游数据 map button maps to the 漫游记录 exit. | No change this round. |
| `subpackageRoam/official-routes` | `RoamMapHomeRoutesList` (map home push) and `OfficialRouteListView` | Map-home list row lacked the MP cover and used its own meta; MP `metaText` = city · 公里 · 分钟. Legacy list: bare spinner while loading. | Fixed: row shows the route cover when `previewImg` exists and `OfficialRouteMeta.text` (MP metaText); legacy list loading says `officialRoute.list.loading`. Large title kept inline (house rule: pushed pages use inline titles; lint rejects `.large`). |
| `subpackageRoam/official-route` | `RoamMapHomeRouteCard` and `OfficialRouteDetailView` | Map-home card: subtitle was city only (MP metaText has distance + duration), no cover, header "Stops" without count (MP 节点（N）), stop rows lacked address and the 参考停留 label; empty stops sat outside the stops section. Legacy detail: bare spinner; empty stops as plain text (MP cy-empty). | Fixed all listed: meta line, cover, `节点（N）` header (shared key), address + `参考停留 N 分钟` per stop, empty state inside the section; legacy detail loading words + `ContentUnavailableView` for no stops. |
| `subpackageRoam/history` (`scene-roam-history`) | `RoamHistoryView` | MP loading `正在读取漫游记录…` in words; native bare spinner with a hidden label. Order (total km → 次漫游/家店/用时 → tools → month heads + run cards → empty / in-progress / load more) already matched. | Fixed loading words; en value now "Loading your roam history…". |
| `subpackageRoam/session` (`scene-roam-session`) | `RoamHistoryDetailView` + `RoamRecordedStats` | MP kv rows 总距离 / 时长 / 探店 / **到达 N 处** / 探索度; native lacked 到达. Loading said "Loading map results…"; MP 正在读取本次漫游. | Fixed: 到达 row from `RoamHistoryRecord.footprintCount`; `roam.session.loading`. The extra P8 "see collection" link stays (design-principles P8). |
| `subpackageRoam/poi-detail` (`scene-roam-poi-detail`) | `RoamItemDetailView` | MP order: node card + 收藏/导航/投一张 → 基本信息/地点详情 → 玩家评价 → footer. Native showed the extras block (which holds 玩家评价) before 你的状态 and 地点详情. Loading said "Loading map results…" (place and merchant retry). | Fixed: extras mount moved after 地点详情; `roam.place.loading` / `roam.merchant.loading`. |
| `subpackageRoam/citynode-code` (`scene-qr-citynode`) | `RoamCityVoucherCodeView` → `VerificationCodeView` | missing-param shell + 返回, voucher title/desc/countdown already mirrored. | No change needed. |
| `subpackageRoam/citystamp` | `RoamCityStampFlowView` / `RoamStampSlipView` | Write step order (note header + counter, text, photo, mailbox, 投进信箱) matches. MP opens the camera first (cam → write) and puts the photo square inside the note header; native starts at the write step with a 拍一张 row. Drag-into-mailbox gesture not ported. | Not changed (interaction, not order; writes stay behind `stampExchange`). |
| `subpackageRoam/my-teams` | `NearbyTeamsView` (tab 1) | MP `.mt-stats` sit under the title, above the 我的 / 附近招募 segment; native drew them inside the 我的 list below the picker. Rest (sign-in gate, skeleton, groups, 还没有队伍 + 去地图找队伍, 附近在招募) matched. | Fixed: stats moved above the picker on the 我的 tab (same identifiers, same zero-hides rule). |
| `subpackageRoam/nearby` | `NearbyTeamsView` (tab 0) / `NearbyTeamMapViews` | Filter row, list/map toggle, 附近暂无节点 empty, range/style sheets already mirrored (RNEAR-*). | No change this round. |

## Other roam loading lines (P10)

`roam.loading` ("Loading map results…") was shown on non-map screens. Replaced with what is loading:
`RoamPassportHistoryView` (×2, history), `RoamReceivedStampSectionView` and `RoamStampViews` album lifetime (`roam.stamps.loading`),
`RoamLocationSettingsDestination` (`roam.locationSettings.loading`), `RoamPassportPrivateToolsViews` (visible `roam.private.loading`);
the per-image placeholder in `RoamStampImage` is now a bare `ProgressView()` (the image has its own a11y label).

## Strings

New keys (en + zh-Hans) in `Resources/Localizable.xcstrings` and `docs/port/strings/mp-r3-roam.json`:
`officialRoute.list.loading`, `officialRoute.detail.loading`, `roam.session.loading`, `roam.place.loading`, `roam.merchant.loading`,
`roam.w208.entry.loading`, `roam.locationSettings.loading`, `roam.stamps.loading`, `roam.session.arrived`, `roam.session.arrivedValue %lld`;
updated en of `roamSub.w208.history.loading`.

## Gates (last run)

- `python3 tools/generate_project.py` — OK
- `python3 tools/check_scaffold.py` — PASS (20097 bilingual keys)
- `python3 -B tools/check_a11y_lint.py` — PASS, 0 new
- `python3 -B tools/contract_ratchet.py --check` — 104 failing, baseline 104, **new 0**

## Not done / next

- citystamp camera-first flow and photo-in-note header (interaction port).
- Map-home 附近 picker vs MP 附近活动 / 本城推荐 tabs (kept the native r2 structure).
- The legacy peek's header refresh button (extra vs MP) stays because a unit test taps it.
- No Swift build ran here; integrator compiles.
