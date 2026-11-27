# Design pass · roam + orientation — receipt

Lane `design/pass-roam` from `origin/ui/combined-r7` (`fc95e6a19`). `origin/comp/r1-kit` and `origin/comp/r1-nav` were
already merged into that base (checked with `git merge-base --is-ancestor`), so this lane builds on their run HUD
(`CityOrientationNavComponents.swift`: ETA, paused tag, team progress, arrival card) and kit (`CYRing`, `CYLiveCounter`)
and adds none of its own copies.

Read first: `origin/design/handoff-r2:docs/briefs/design-principles.md` (P1–P12) and `docs/briefs/components-r1.md`.
`COORDINATOR-HANDOVER.md` is not in any branch of the repo (checked every `origin/*` ref), so §4 was taken from the
traps quoted in `components-r1.md` and the comp-r1 receipts: grep every API, type set literals, `self.` when init
params shadow, split long modifier chains, iOS 18 behind `#available`. **Not compiled (no Swift toolchain in the cloud);
needs a coordinator `build_sim`.**

MP source: `origin/mp-source:chengyinhub-xcx/` — `pages/roam/index.wxml` (pcard 用时/地盘/距离, pbar, settle),
`subpackageRoam/session/index.wxml`, `pages/play/index.wxml` (orientation run), `subpackageRoam/nearby`.
No locate-me button anywhere (MP `show-location="{{false}}"`, fix-r11 N-r11-2).

## Screens: failed principles → fix

| Screen | Failed before | Fix (native) | file:line |
|---|---|---|---|
| Roam home / map (`RoamMapHomeView`) | P9 map controls not minimal: `MapUserLocationButton` (MP has none) | Removed; compass, pitch, scale stay. Panel (Find My style detents, search, 开始漫游 prominent, teams count) already met P9/P3/P6 | App/NativeR2/MapHome/RoamMapHomeView.swift:118 |
| Free walk live (`RoamLiveSessionView`) | P1: 用时/地盘/距离 were three equal `LabeledContent` rows, no hero. P9: locate-me on the map | Hero distance (`data2XL`, monospaced, unit on the baseline, `numericText` roll, pulsing `figure.walk.motion` while walking, Reduce Motion off) + quiet row 用时 / 地盘 (`ViewThatFits` row → stack). Identifiers `roam.live.distance/foregroundElapsed/localCoverage` kept. Locate-me removed. P3 already met (Pause prominent, 结束 secondary in the sheet bar) | App/RoamLiveSessionView.swift:590, :903, :942, :278 |
| Free explore map (`NativeFreeExploreMapView`) | P1: next-store distance was a subheadline line. P3: 步行前往 / 跳过 / primary all `.large`, primary last. P4: every store in one flat list. P9: locate-me | Distance to the next store is the hero (`dataXL`, rolling). Primary (我已到达 / 打开) first, 步行前往 · 跳过 under it at regular size. Done stores fold into `DisclosureGroup` 已完成 (n). Locate-me removed | NativeFreeExploreMapView.swift:318, :344, :417, :51 |
| City orientation run (`CityOrientationRunView`) | P4: stops as a flat list, no "N of M". P6: teams only in the large detent | Legs section: header 打卡点 · N / M with a small `CYRing`; on the live run punched stops fold into 已完成 (n), open stops stay first (identifiers `playx.node.<id>` kept; read-only finish list unchanged). Team stack (initials in trail colours + "N 队在路上") beside the map controls. P2 deadline: **MP run has no deadline countdown** (`pages/play/index.wxml` shows only the elapsed clock and ETA, see :587-604), so nothing invented; the clock already ticks (`TimelineView`) | CityOrientationRunView.swift:466, :501, :308, :569 |
| City orientation result (`CityOrientationFinishSummaryView`) | P8: medals were plain `Label` rows — no number, no share, no collection | Each medal is a tile (44 pt, tint circle, bounce once on reveal, Reduce Motion off) with name + subtitle and its own `ShareLink`; one 查看全部勋章 link to the badge collection via the same `rewardCollectionDestination` the reward rows use | CityOrientationFinishSummaryView.swift:98, :135; App/PlayExperienceView.swift:871 |
| Roam result (`RoamFinishReportView`) | P1/MP parity: hero was 家探店 while the MP settle hero is 处到达 (`finish.footprints`); grid had 4 of the MP's 6 cells (no 公里 / 用时). P2/P7: hero static. P8: medals only as a count | Hero = `record.footprintCount` 处到达, rolls up from 0 once. Grid = MP six cells (公里 · 用时 · 探索度 · 邮票 · 探索值 · 勋章) in a 3-column `LazyVGrid`. Medal tiles (bounce on reveal) open `RoamMedalShareView`; 漫游记录 stays as the collection exit | App/RoamFinishReportView.swift:142, :161, :173 |
| History / passport stamps (`RoamHistoryDetailView`) | P8: medal had share but no collection exit | 查看全部勋章 → `RoamBadgeWallDestination` under the medals | App/RoamHistoryViews.swift:346 |
| Passport overview (`RoamPassportOverviewView`, local) | P1: four equal rows | 次漫游 is the hero (`CYLiveCounter` `.data2XL`), shops/days/km in a quiet row (`ViewThatFits`). Identifiers kept | App/RoamPassportOverviewView.swift:50 |
| Nearby teams list (`NearbyTeamListRow`) | P6: list mode showed `j/m` only; faces only in 招募中 | `NearbyTeamFaces` above the rolling `j/m` count (MP `avatarsOf`, default faces, nothing fetched) | App/NearbyTeamMapViews.swift:135 |

Every screen, P12: new text wraps or uses `ViewThatFits`; no fixed text widths. Reduce Motion: every new roll / bounce /
pulse is off with it. VoiceOver: hero values are one element (label + value); decorative symbols hidden.

## Not done here / for the coordinator

- P5 (same run in widget + island) is C1/C2 (`comp/r1-live`, `comp/r1-widgets`); untouched.
- The finish report cannot link the badge wall: `RoamBadgeWallDestination` only accepts the session's own roam reader
  and the report holds the finished-history reader; the 漫游记录 link is the collection exit there.
- Finish-report photo stamps strip (MP `finish-stamps`): `RoamHistoryRecord.photos` are MP-style local paths and no
  native view renders them yet; left out rather than show broken images.
- UI tests that tap a **completed** city stop by `playx.node.<id>` in the live run would now need to open 已完成 first
  (none found by grep; `PlayExperienceFlowTests` use the generic play list).

## Merge notes

- Merged `origin/ui/combined-r7` at `77c566c6c` (i18n r1). Conflict in `RoamLiveSessionView` HUD: the hero keeps the
  i18n unit switch (`LocaleDisplay.usesMiles` → `unit.mile.abbr` / `roam.live.stat.distance`) as its `unit:`.
  The roam result's new 公里 cell uses `LocaleDisplay.roadNumber` + the same unit switch.
- `check_l10n.py` currently FAILS on `App/E1CommerceComponents.swift` (3 CJK literals, baseline 2). That is upstream
  (file unchanged by this lane); this lane adds no CJK string literals.

## Strings

Fragment `docs/port/strings/design-pass-roam.json` (8 keys, en + zh-Hans) merged into `Resources/Localizable.xcstrings`.

## References (self-found, added to the principles' reference log by this lane)

- Apple Fitness workout summary (hero metric + small grid) → P1 for the roam result and passport.
- Apple Maps / Find My (no locate button needed when the map opens on you; minimal controls) → P9.
- Strava / Nike Run Club live screen (one big distance, small time/pace under it) → P1/P2 live roam HUD.

## Gates (last push)

`check_scaffold.py` PASS · `check_a11y_lint.py` PASS (0 new) · `contract_ratchet.py --check` 104 failing, baseline 104, new 0.
