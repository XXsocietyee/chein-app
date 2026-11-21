# Receipt · ui/r4-play-flow · cloud agent, screens r4 (the play experience)

Branched from `origin/ui/h-code-r3-ops` (c239789ec), pushed to `origin/ui/r4-play-flow`. Brief:
`design/handoff-r2:docs/briefs/screens-r4.md`. **Swift is not installed in the cloud: nothing here was compiled, run or
shot.** Every type, initializer and modifier was checked against code on the base branch; the integrator builds,
runs and shoots (checklist at the end).

Design sources used (read-only): `revise/skill-r2/js/_handoff.json` (frame → view), `revise/skill-r2/js/10-p.js`
(SR2-04 hud, SR2-07 report, SR2-08 share), `24-pat.js` (motion + haptic table), `review/skill-r2.md` §2.1 SR2-04,
SR2-07, SR2-08, SR2-11, SR2-49, SR2-50, `review/xrefs-1.md` (B.0, §2 Adopt, §3 Reject), `revise/xrefs-1/js/PAT.js`
(per-flow choreography), `review/full-player.md` PL-45, `revise/player.md` PL-06 / PL-12 / PL-22.

Status words: **done (code)** = built to the frame, not yet seen on a device; **partial** = what is left is named;
**left** = not started, with the reason.

## Frames

| Frame | Status | What changed | Files |
|---|---|---|---|
| `401:4731` play HUD (`PlayHUDView`) | **done (code)** | New HUD in the play map's floating slot while one stop is current and the run is live. 下一站 card: label, place name (`cardTitle`, 2 lines), one caption `用时 23:10 · 线索 3 / 6`, a 44 pt arrow that turns to the stop's bearing relative to the compass in **15° steps** (`.rotationEffect`, `CYMotion.standard`, the short way round; Reduce Motion snaps), the distance **once** (`180 m` / `1.2 km`, `sheetTitle` 22 tabular; the 1.2 km tile is gone). Then the run's one primary (start / pause / resume, unchanged), then the bar: **提示** Secondary pill that fills the row, **队伍** (the existing in-game channel entry with its unread badge, dressed as a 44 pt glass circle by `PlayHUDCircleButtonStyle`, full 44 pt hit area) and **背包** (44 pt glass circle → theme or team backpack). Tapping the card opens the stop; 提示 opens the stop with the hint ladder sheet already up. The channel leaves the toolbar while the HUD shows (it is in the bar). Distance comes from the play session's own foreground location hold (`SessionBackgroundLocationTracker.freshFix`, WGS-84 → GCJ-02 via `RuntimeLocationProjection`), read every 2 s; a coarse (>100 m) or stale fix shows no distance rather than a wrong one. Heading: `CLLocationManager` heading only while on screen and only if When-In-Use is already granted (no new prompt). Unknown → the piece is left out (no arrow, no distance, never 0). The 96 pt top shade is the map scaffold's existing top scrim. | `App/PlayHUD.swift` (new), `App/PlayExperienceView.swift` |
| `204:15044` 战报 (`MatchReportView` = `JourneyReportView`) | **done (code)** | 本局不计分 is said once, as the subtitle under the result; the stat row shows only numbers the report can read (no — tile, no 本局不计分 tile), 1–3 stats with hairlines. Rows already end in chevrons (C1). Push stays the system push. | `App/JourneyReportViews.swift` |
| `204:15096` 结算 (`SettlementView` = `JourneySettleView`) | **done (code)** | The seal (C1's `CYMomentSeal`, 96 pt) over 6 / 6 with **no glow** behind it (AGENTS 删减 "发光"). Beats from `CYMotion` only: seal from 0 on `seal` with its heavy impact, **success haptic 150 ms after contact** (SR2-49 "Seal lands"), text on `moment` from +950 ms with 0 / 50 / 90 ms follow-on. The score **counts up** with `cyNumericRoll` after the text beat (tabular, one roll; nothing redraws). **Tap skips** to the settled frame. Rating: `CYMorphButton` + the centred 谢谢 card with a glowing star are replaced by `CYResultButton` **提交 → 正在提交 → 已提交 in place** (success haptic, announcement), then the flow moves to 分享 after `Delay.sheetDismiss`. The custom back chevron and the hidden system back are removed (consist-1: system back only); steps go forward and back leaves 结算. Step change uses `CYMotion.standard`. | `App/JourneyReportViews.swift` |
| `210:10082` share badge (`ShareBadgeView`) | **done (code)** | Badge art **144 pt** on the story poster; the medal share and the celebration badge share open on the **navy field** (`ocean`) instead of mustard/ink; the swatch row offers `CYShareCardTint.pickable` (**no mustard**, `gold` is never offered); the 带上路线 switch uses the **neutral tint** (ink at 32 %, white knob). | `App/DesignSystem/CYShareCard.swift`, `CYShareComposer.swift`, `CYCelebrationShare.swift`, `App/RoamMedalShareView.swift`, `App/DesignFixtures/E3ShareFixtures.swift` (fixture swatch list) |
| `210:10045` new badge (`NewBadgeView` = `CYBadgeUnlockCover`) | **done (code)** | Full-screen moment kept (a big one). The two particle bursts are removed (xrefs-1 §3 row 13 rejects sparkle particles; the badge is the one object). **Tap skips** to the end; buttons land by **1.5 s** (SR2-49 ceiling) and are hit-testable from then. Haptics unchanged (engine: success on unlock). Reduce Motion unchanged (cross-fade). | `App/DesignSystem/CYCelebrationViews.swift` |
| `396:4404` 提示 sheet | **done (code)** | `CYSheetKind.hint` → `.medium, .large` (was fit / medium), the hand-off detents; same kit sheet (`sheetGlass`, rows `bgRaised`), system dimming below the largest detent. `DesignR1FoundationTests` updated. | `App/DesignSystem/CYPlayerKit.swift`, `Tests/AppUnitTests/DesignR1FoundationTests.swift` |
| `396:4449` 队伍聊天 sheet | **partial** | Reached from the HUD's 队伍 circle (done). The sheet itself is presented by `InGameChannelToolbarButton` → the IM host (`inGameChannelHost`), which the brief reserves for the continuity branch (IM views); not edited. `CYSheetKind.teamChat` is already medium / large. Left for the IM owner: present it with `.teamChat` detents and raise to `.large` when the keyboard shows (full-player sheet table). | `App/PlayHUD.swift` (entry only) |
| `396:4369` 选择票种 sheet | **done (on base, verified, no change)** | Checked against the hand-off (`detent fit`, sheet spring, system scrim; full-player sheet table: `fit`, commits on tap). `RegistrationSheetView.ticketSheetContent` is already `CYOptionSheet` + `.cyFitSheetDetent()`: one row per ticket (name, gated price, `ticket` glyph), the selected row marked by a **neutral ink checkmark** (no purple), tap selects and closes (no 完成 / 选这张), then the quote is re-read. `CYSheetKind.ticketType` is `fit`. Nothing to change; the registration sheet belongs to the 活动报名 / sheets continuity work, so it was not edited. | — (read: `App/RegistrationSheetView.swift`, `App/DesignSystem/CYSheetModal.swift`) |
| `166:3280` R1 error (首页) | **done (code)** | When every rail and the first feed page failed and nothing is on screen, the home shows **one inline error** under the header (`首页加载失败`, one 重试 that re-reads the three rails and the feed) and **no section titles with nothing under them, no 主题 / 活动 tabs, no banner error**. Partial failures keep the per-rail retry rows. The header is untouched (global-search owner). | `App/HomeFeedView.swift` |
| `169:4754` R1 error (我的) | **done (code)** | The member card's failed state now reads like the 首页 R1 error (166:3280): one line with the warning glyph (`exclamationmark.triangle`, `bodyCompact`, secondary text) and one **secondary** 重新加载 button (`.cySecondary`, 44 pt min), full width, instead of a 12 pt caption and a bare tinted text button. Signed out is not an error: no glyph, no retry. Offline keeps `CYOfflineBanner`. 积分 / 等级 still show "—" (`CYUnknownValue`), never 0. Identifiers `member.card.failed` / `member.card.retry` unchanged (UI test `MemberHomeFlowTests`). PL-30 (N67 header, 积分 first) is the 我的 root, not this error frame; not touched. | `App/MemberHomeHeader.swift` |

Not in scope and not touched: TopicDetail bottom-bar presenters, the City kit, global search, CYTabs, IM views.

## Shared DesignSystem changes (minimal)

- `CYShareCardTint.pickable` (new static, filters `gold`); composer swatches use it. Poster medal size 170 → 144 (story).
- `CYCelebrationShareSheet.style` is computed: medal → `ocean`, walk → `ink`; route `Toggle` tint neutral.
- `CYBadgeUnlockCover`: bursts removed, `static let settled = 1.5`, tap-to-skip.
- `CYSheetKind.hint` sizes.

Other files (not DesignSystem): `App/MemberHomeHeader.swift` failed state only (169:4754).

## Strings

`tools/add_r4_play_flow_localizations.py` (idempotent, en + zh-Hans): `playHUD.next` 下一站, `playHUD.hint` 提示,
`playHUD.backpack` 背包, `mp.settle.rate.submitting` 正在提交, `mp.settle.rate.submitted` 已提交, `homeFeed.feedFailed`
首页加载失败. `mp.settle.thanks*`, `mp.settle.toShare` and `mp.settle.back` are no longer read (left in the catalog).

## Skill rules applied

- apple-design-interaction: "Design every state" (HUD hides unknown pieces; home R1 error with recovery); "Respond in
  <100 ms" (rating result in the pressed button); 44 pt targets (glass circles via button style, full hit area).
- apple-design-os: "Anchor primary controls in reach" (HUD bar at the bottom over the panel); sheets use detents
  (提示 medium / large).
- apple-design-motion: springs over easing (`CYMotion` only, no local springs left in 结算); interruptible (tap
  skips on 结算 and the new badge; the arrow retargets mid-turn); Reduce Motion fallbacks (arrow snaps, text fades in
  place, count-up lands, badge cross-fades).
- emil choreograph: one lead and its followers (seal → text +950 → stats), stagger 0 / 50 / 90 not uniform, Hard Rule
  4 "choreography never blocks interaction" (badge buttons hit-testable at 1.5 s, tap skips); gestures: tap to skip
  has a visible fallback (buttons); break-ui: no fix / no compass / unscored / missing time produce shorter UI, not
  0 or — (fixtures below); write-swift: pure geometry split out and unit-tested.
- make-interfaces-feel-better #9 tabular numbers (distance, caption, score), #12 scale on press (glass circles 0.97),
  #16 minimum hit area, #19 motion restraint (live counters never roll: xrefs-1 §3 row 14).
- AGENTS 删减: glow behind the seal removed; particle bursts removed; thank-you card removed.

## Gates (cloud)

| Gate | Result |
|---|---|
| `python3 -B tools/check_scaffold.py` | PASS |
| `python3 -B tools/check_design_lint.py` | PASS (0 violations) |
| `python3 -B tools/contract_ratchet.py --check` | 185 failing vs baseline 184; the one "new" id is `test_workshop_paid_professional…bounded_paging`, the same id already red on the base (named in the r3-player receipt). No id from this branch. |
| Build / AppUnit / Core | **not run** (no Swift here). New `R4PlayFlowTests` (shard 04): 15° steps, short-way unwrap, bearing and distance, one distance text, 战报 stats without unknowns, palette without mustard. |

## LOCAL VERIFICATION CHECKLIST (integrator)

Build: Questify Debug; then AppUnit shard 04 (`R4PlayFlowTests`, `DesignR1FoundationTests`).

Watch for compile issues first in: `App/PlayHUD.swift` (`@Observable` + `NSObject` + `CLLocationManagerDelegate`,
`PlayHUDCircleButtonStyle` with `@ScaledMetric`), `PlayExperienceView.swift` (`hudStop` tuple, `runFloating`,
toolbar `if let …, hudStop == nil`), `JourneyReportViews.swift` (`static func stats` tuple array with
`LocalizedStringKey`, `.task(id: rate)`), `CYCelebrationViews.swift` (`onTapGesture` inside the `TimelineView`).

Screens to shoot (dark player theme):

1. `--design-fixture r4-play-hud` — HUD: card (老麦咖啡馆, arrow 45°, 180 m, 用时 23:10 · 线索 3 / 6), primary, 提示
   pill + two 44 pt circles. Tap 转向 +15° several times: the arrow turns 15° each time on the spring; past 345° → 0°
   it goes the short way. Repeat with Reduce Motion on (`--uitesting-reduce-motion`): it snaps. VoiceOver on the card:
   "下一站 老麦咖啡馆, 180 m, 在 2 点钟方向, 用时 …".
2. `--design-fixture r4-play-hud-unknown` — no arrow, no distance, caption only; nothing reads 0.
3. AX5 Dynamic Type on (1): name wraps to 2 lines, the bar still fits (提示 may truncate, circles stay 56 max).
4. `--design-fixture r4-report-unscored` — 战报: 本局不计分 once under the result, one stat (6/6), no — tile.
5. `--design-fixture t5-settle` — 结算: seal lands with a heavy impact, success ~150 ms later, title and rank at
   ~0.95 s, score rolls 0 → 960 after that; no glow; system back in the nav bar. Tap during the beats: everything
   lands at once. Reduce Motion: fades only, score appears without a roll.
6. 结算 rate step (same fixture, 看排行榜 → 去评价, pick stars): 提交 → 正在提交 → 已提交 in the same capsule (needs a
   binding that flips `rate` busy → thanks; on TEST a real submit), then 分享 after 0.6 s. Error: the button returns to
   提交 and the line shows under the field.
7. New badge: `--design-fixture` for the celebration (E4CelebrationFixtures, badge) — no particles; buttons by 1.5 s;
   a tap at ~0.5 s jumps to the end; swipe down still keeps.
8. Share badge: 分享徽章 from (7) — 144 pt badge on the navy field, route switch (walk) neutral; `RoamMedalShareView`
   (漫游 → 徽章 → 分享): default swatch navy, five swatches, no mustard.
9. Play run on TEST (signed in, location granted, a city-orientation topic with one current stop): the HUD appears over
   the map, the distance updates every ~2 s while walking (simulated route), 提示 opens the stop with the hint ladder at
   medium (drag to large), 队伍 opens the channel sheet (unread badge visible), 背包 pushes the backpack. Toolbar shows
   no channel button while the HUD is up; after the run ends the HUD goes and the channel returns to the toolbar.
10. Home error: a reader that fails all three rails and the first page (TEST offline after launch, or a failing
    fixture reader) — one 首页加载失败 card with 重试 under the header, no titles, no tabs; 重试 reloads all.
11. 我的 error: `MemberHomeFlowTests` failing-reader path (or TEST offline → online flip so it is a server failure, not
    the offline banner) — the card shows the warning line and one secondary 重新加载 (same look as the home error); signed
    out shows only the sign-in line; 积分 and Lv show "—". AX5: the line wraps, the button stays 44 pt.
12. 选择票种 (no change, regression only): 活动报名 → 票种 row: fit sheet, neutral check on the selected ticket, tap closes.

Edge data: a stop with no coordinates (no distance); a run with branches (`currentNodeID == nil`: no HUD, the old
primary); a run with no backpack models (no 背包 circle); a team run (背包 → team backpack, 队伍 → team channel);
`accuracyMeters > 100` (no distance).

Left for the owner / other branches: the 队伍聊天 sheet surface (IM continuity: `.teamChat` detents, keyboard → large), chapter covers on the HUD (no per-chapter cover read in the play view), the 排行榜 podium third seat and its
count-up-on-every-visit hero (not in this area's frame list).
