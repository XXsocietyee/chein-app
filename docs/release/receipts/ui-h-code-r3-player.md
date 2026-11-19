# Receipt · ui/h-code-r3-player · code worker C1 (player pages, City follow-ups, the motion system)

Opus 5.5, Orca task `task_468e8058380e`. Branched from `origin/ui/main` 6ceb69fc7 and pushed to
`origin/ui/h-code-r3-player`; `ui/main` was not touched. **Figma calls: 0** (Figma access is down; everything was built
from the local copies: `revise/skill-r2/js/_handoff.json` and the build scripts, `review/xrefs-1.md`,
`revise/xrefs-1/LOG.md` and `js/L1.js`, `js/PAT.js` (the per-flow choreography board), `review/skill-r2.md` §2–§4,
`revise/skill-r2/shots/b1-p-roots.png`, `code-final-shots/app-B/figma/`, `code-final-shots/city/figma/`).

Screenshots (local only): `/Users/fanning/chengyin-refs/code-final-shots/r3-player/` with `index.md`. Every shot is the
**shipped view**; `-FIXTURE` = the DEBUG `--design-fixture` host with synthetic data (City success states cannot be
reached on TEST from a simulator: App Attest), `-TEST` = the app on be-int 8120.

Status words: **done** (a screenshot is named), **partial** (what is left is named), **left**.

## 1 · One motion token set and the in-place result pattern (shared, for C2 too)

| Item | Status | Where / evidence |
|---|---|---|
| One token set (xrefs-1 B.0) | **done** | `App/DesignSystem/CYMotion.swift`: eight springs `press 0.12/0.90`, `release 0.25/0.70`, `standard 0.30/0.85`, `entrance 0.35/0.80`, `sheet 0.38/0.86`, `moment 0.42/0.80`, `seal 0.40/0.55`, `hero 0.45/0.86`, `reduced` (200 ms cross-fade), `numericRoll` (snappy 300 ms), `hide` (200 ms); `Duration` (+ numericRoll, hide, hold, successWave, countUp), `Delay` (heroBand 250, successWave 780, sheetDismiss 600, moment beats 350/600/950/1250, toastAction 300, totalRoll 400), `Stagger` (chips 0/50/90, digit 45, rewrite 0/40/70/90), `Scale` (press 0.97, pinSelected 1.15). `CityTokens.*Spring` are aliases only (`pressSpring` = `release`, as the LOG says). AppUnit `R3PlayerMotionTests` pins the aliases and staggers. |
| Player/Button Done (in place) | **done** | `CYResultButton` in `App/DesignSystem/CYInPlaceResult.swift`: one capsule carries idle → loading (spinner + 正在…) → done (check entering 0.25 → 1 with blur-replace + 已…), width on `standard`, success haptic at Done, VoiceOver announcement, second tap ignored while loading, failure returns to idle on `release`, Reduce Motion keeps the widest label's width and cross-fades. `CYResultRunner.run($phase) { … }` drives it (300 ms spinner floor). Shot: `r3-kit-inplace-FIXTURE.png`. |
| Player/Toast Progress and Done | **done** | `CYResultToast` + `.cyResultToast($state, onAction:)`: the leading icon swaps in place, title cross-fades, 查看 enters +300 ms with blur-replace, enter/exit on `sheet` from the bottom edge, exit 200 ms, success / error haptic, announcement. Shot: `r3-kit-inplace-FIXTURE.png`. |
| Numbers roll | **done** | `.cyNumericRoll(value)` (tabular + numericText + 300 ms snappy; cross-fade under Reduce Motion); `CYDeltaNumber` (one number + −N chip that fades 200 ms after the roll). |
| Other shared pieces | **done** | `CYPlainStatRow` (Stat Tile Emphasis=Plain: hairlines, no box, stacks at AX sizes), `CYStreakRow` (Player/Streak Row), `CYMomentSeal` (Moment/Art seal 96 pt, lands on `seal`, heavy impact), `.cyHeroNumberFont()` (t-hero 48 tabular, Dynamic Type), `CYDesignedCover` (designed default cover for photo-less heroes). |

## 2 · City Monopoly follow-ups

| Item (xrefs-1 / brief) | Status | Evidence |
|---|---|---|
| No-photo deed cover (district colour 24 %, place name, camera glyph; glyph-on-grey only for unlit) | **done** | `CityNoPhotoCover` in `CityDeedCard.swift`; `204-26968-N22-claimed-no-photo-cover-FIXTURE.png`, `204-23400-N08-property-drawer-FIXTURE.png`, row thumbs in `204-21814-N01-board-plain-stats-FIXTURE.png` |
| Photo → deed continuity K0–K3 (`CYMotion.hero`) | **done** | The claim sheet shows the photo as a 64 pt thumbnail (K0). On success the button goes Done in place, then 圈下了 opens over the sheet with no slide and a clear ground; the photo flies from the thumbnail's window frame into the deed's photo slot (matched geometry, `hero`), the band and body rise from +250 ms, seal +600 (heavy at contact, success +150 ms), text +950, chips 0/50/90, actions +1250; tap skips; Reduce Motion = 200 ms cross-fade with the photo already in the slot. `204-26968-N22-claimed-photo-K3-FIXTURE.png` (K3), `204-26968-N22-photo-to-deed-K1-K3-strip-FIXTURE.jpg` (frames ≈ 0.3 s apart: launch, the photo mid-flight before the band, K2 deed around it, K3 text, actions). |
| In-place results on claim, challenge, shield, upgrade | **done** | Claim: `CYResultButton` 确认圈地 → 正在确认 → 已圈下, balance rolls. Shield: 开护盾 → 正在开启 → 已开护盾, sheet closes after 600 ms with the row behind already updated. Upgrade: 升级 → 正在升级 → 已升到 Lv… then the level-up moment (the only full-screen result besides a first claim, per the owner's continuity pass). Challenge: the start button fills in place when the last check passes (`standard`, selection haptic); its result is the roll inside the dice moment. `204-27271-N25-claim-short-balance-FIXTURE.png`, `205-8475-N47-shield-hug-FIXTURE.png` |
| Overlapping pins: cluster or offset | **done** | `CityPinGroup.make` groups pins closer than one 44 pt pin at the current zoom into a count bubble (tap zooms in); below a 0.006° span the same group fans out on a ring so each pin can be tapped. Tested in `R3PlayerMotionTests`. No shot of a bubble: the fixture's places do not overlap at the fixture zoom. |
| First 附近 row peeking | **done** | The resting detent is measured (grabber + hold button + heading + 44 pt of the first row); the medium detent is at least two rows. `210-8322-roam-root-nearby-peek-FIXTURE.png` |
| B.1 dice total 48 pt with the sum above | **done** | `CityMomentView(kicker:numericHeadline:)`; `204-34407-N38-won-48pt-kicker-FIXTURE.png`, `204-34440-N39-lost-48pt-kicker-FIXTURE.png` |
| B.1 one balance number with a −N chip | **done** | `CityFactTable.Row(number:delta:)` → `CYDeltaNumber`; claim sheet. `204-27271-N25-claim-short-balance-FIXTURE.png` shows the short case (number + 还差); the chip case is in `r3-kit-inplace-FIXTURE.png`. |
| B.1 odds bar directly on the sheet | **done** | `204-34263-N34-challenge-flat-odds-reason-FIXTURE.png` |
| B.1 blocking reason above disabled buttons | **done** | `CityBlockingReason` (再走近 N m 就能开始挑战 / 定位还不够准… / 在现场停留满 60 秒…) on challenge, upgrade and claim; `204-34263-…png` shows 再走近 235 m 就能开始挑战, `204-27271-…png` shows 积分还差 80 |
| B.1 die alone in the top half | **done** | `204-34340-N36-ready-die-top-FIXTURE.png`; the die is one matched-geometry object across ready → rolling → result |
| B.1 stats without a box | **done** | N01 `204-21814-N01-board-plain-stats-FIXTURE.png` |
| B.1 material sheets | **done** | Property: the new drawer over the map uses `.regularMaterial` at the compact detent, opaque expanded or under Reduce Transparency; the deed inside is a plain fill with no dashed outline (outline kept only on list rows for claimable). 附近 drawer: material at peek / medium. `204-23400-…`, `204-23832-N11-property-drawer-mine-FIXTURE.png` |
| Pin → property continuity (owner continuity pass 4) | **done** | `CityPropertyDrawer` replaces the system sheet for `.property`: the pin's tile (the deed photo or the no-photo cover) grows from the pin's window point into the deed photo slot on `hero` while the drawer rises on `sheet`; text fades in after ~50 % of the move; ✕, a drag down past 120 pt or Escape runs it back to the pin; the grabber tracks the finger 1:1; the camera keeps the pin above the drawer; the 附近 drawer slides away; Reduce Motion = 180 ms cross-fade. `204-23400-N08-pin-to-deed-drawer-strip-FIXTURE.jpg` (end of the move; the 0.45 s flight is shorter than the capture interval). |
| Claim deed: Full hugs content | **done** | spacer removed; `204-26968-…K3` |
| Chips stagger 0 / 50 / 90 ms | **done** | `CYMotion.Stagger.chips` |
| District names and deed serial | **hook** | `CityTerritoryProperty.districtName` / `deedSerial` → `CityPlace.districtName` / `deedSerial` (Core); the band shows the name instead of 街区 N, and 地契 · No. N in place of the tier, only when the server sends them (fix/city-gaps-r3). Fallbacks unchanged today. Core test `testDistrictNameAndDeedSerialHookPassesThroughTheMerge`. |
| Hold to start → live controls over the SAME map (continuity pass 5) | **left** | `RoamLiveSessionView` is a separate pushed page with its own map; rendering it as a layer over the City map needs the live session's controls split from its map. Not started. |

## 3 · Player hand-off frames (docs/release/receipts/ui-h-code-app.md leftovers)

| Frame | Status | Evidence / what is left |
|---|---|---|
| `210:8603` 我的 root | **partial** | `210-8603-me-root-TEST.png` (TEST, signed in): the 7-day `CYStreakRow` under the name (0 days today: all unlit, today's 四 bold), counters as a plain row with hairlines (no tiles), the avatar ring in ink instead of the reserved purple. `210-8603-me-streak-plain-stats-FIXTURE.png` is the same card in the fixture host. The 积分 tile and its ledger link were left alone (owned by the cloud continuity agents). Left: the attributes card from the frame (`23 探索 …`) has no read in this view. |
| `204:15044` 战报 | **partial** | Stats are a plain row with hairlines (no tile); rows already end in chevrons; 本局不计分 appears once (as the score value). No TEST run reaches a finished report for the signed-out simulator; not shot. |
| `204:15096` 结算 | **done** | The trophy + sparkles are replaced by `CYMomentSeal` (96 pt, 已完成) landing on `seal` with a heavy impact, over the stop count. `204-15096-settle-seal-FIXTURE.png` |
| play answer / check-in submit (continuity pass 2) | **done (code)** | `PlayExperienceNodeView`: the answer button is a `CYResultButton` (提交 → 正在提交 → 已完成); a completed stop no longer opens the full-screen verdict (the task card updates where it is, check-in keeps its haptic); a wrong answer shows the server's reason above the button with the error haptic. Not shot (needs a live play run). |
| `210:8239` 首页 | **left** | Not changed this round. The editorial rail already uses the focused-card scroll transition; the header (search field, greeting) belongs to the global-search owner. |
| `210:8374` 发布 root | **left** | The tab hosts the editor's `SessionPublishingModesView`; the frame's 主题 / 玩法 tabs, draft card and template rails need reads this view does not have. |
| `401:4731` play HUD | **left** | No shipped view matches the frame (下一站 card with one distance, heading arrow, 提示 + 队伍 / 背包 circles); building it means a new HUD over `PlayExperienceView`. No render exists either. |
| `210:10082` share badge, `210:10045` new badge | **left** | |
| `396:4369` 选择票种, `396:4404` 提示, `396:4449` 队伍聊天 | **partial** | Unchanged shared sheets (fit / resizable, sheet glass + sheet-card rows, the sheet-header rule). Not individually shot. |
| `166:3280`, `169:4754` R1 error states; `204:30158` 收集册 | **left** | No render and no spec beyond the frame id in the hand-off table. |

## 4 · Coordinator review fixes

| Item | Status | Evidence |
|---|---|---|
| Topic detail: designed cover instead of 图片暂不可用 | **done** | When photos cannot load (`RetainedPublicImageReader().enabled == false`, the TEST case) the hero is `CYDesignedCover` (gradient, watermark initial, dashed route mark, route disc). `169-6954-topic-detail-designed-cover-TEST.png` (topic 993006 on TEST) |
| Topic detail: hide 路线总站点 0 | **done** | The row shows only for a count > 0; same shot (no 路线总站点 row under the tabs). 参与商家 0 in the facts section was left as it is (not in the review). |
| Topic detail: one pinned container for 详情 / 故事 / 路线 | **done** | One `TopicXcxTabs` value with a shared selection: inline under the stats, and pinned under the navigation bar (page ground behind it) once it scrolls above the list top. An overlay, not a safe-area inset, so the list never shifts. `169-6954-topic-detail-tabs-pinned-TEST.png` |
| Topic detail: consistent dividers | **done** | One `listRowSeparatorTint(border-subtle)` for the page, rows inset to the text; the hero block keeps none. `169-6954-topic-detail-tabs-pinned-TEST.png` |
| Status bar on pushed LIGHT pages (app-wide, theme code) | **done** | `CYScreenChrome.syncStatusBar(for:)` runs whenever the shell's arbitrated scheme changes (and when the role root appears): it sets the window style and each navigation controller's bar style (the navigation controller, not the page, owns the status bar while its bar is shown, and its bar kept the dark shell style) and asks every controller to re-read its status bar style. Sheets keep their own scheme. `statusbar-light-page-pushed-from-player-TEST.png`: the light 模板 page pushed from the dark 发布 tab has a dark status bar; back on the dark tab it is white again (`210-8603-me-root-TEST.png`). |

## Gates

| Gate | Result |
|---|---|
| Build (Questify, Debug, Lane2, `OTHER_SWIFT_FLAGS=$(inherited) -disable-sandbox`, DerivedData `ui-h-code-r3-player`, under `lockf /private/tmp/design-build.lock`) | BUILD SUCCEEDED (final tree); build-for-testing of the four shard schemes TEST BUILD SUCCEEDED |
| `tools/check_scaffold.py` | PASS |
| `tools/contract_ratchet.py --check` | 185 failing vs baseline 184; the one "new" id is `test_workshop_paid_professional…bounded_paging`, red on `ui/main` already (named in the app and city receipts). The four ids this branch first broke (topic call shapes, a localization argument name, a raw colour in a fixture) were fixed. |
| design lint / strings / a11y / design-r1 localizations | PASS (0 violations) / missing 0 / PASS / CHECKED |
| Core `swift test --disable-sandbox` | 16983 tests (+1 new, passes), **27 unique failing = baseline 27**; none in City or motion code |
| AppUnit, 4 shards (`test_sim`, shard xctestruns) | 6 / 15 / 31 / 25 failing = **77 names**, the same count as the city branch after its rebase (7 / 15 / 31 / 24 = 77). `R3PlayerMotionTests` (new) passes. Every failing class is a hosted lifetime / owner / roam-host test that this branch does not touch, with one I cannot clear: `RegistrationUncertainEvidenceCacheTests` (6 tests) fails again when run alone (XCTUnwrap of the evidence scope after `confirmAndReadBack`); it drives `RegistrationUIFlow` + `RegistrationCoordinator`, which this branch does not change, and I did not run it on a clean base build. Flagged for the integrator. |

Disk: free space dropped to 3.9 GB once during another worker's build; this worker's SPM scratch (3.1 GB) was deleted
right after the Core run, and the branch DerivedData `ui-h-code-r3-player` is deleted at the end.

## For C2

Use `CYResultButton` for any primary whose result belongs on the page (publish, save, accept), `cyResultToast` for a
result that finishes after the page moved on, `CYMotion.*` for every spring (no new local springs), `.cyNumericRoll`
for a number that changes, `CYDesignedCover` where a hero has no photo. Fixture: `--design-fixture r3-inplace`
(`r3-inplace-light` for the editor domain).
