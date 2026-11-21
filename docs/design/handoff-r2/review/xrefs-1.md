# xrefs-1 · Four reference videos, why they work, and where 城瘾 falls short

Reviewer: Fable 5.2 · 2026-11-19 · review only (no Figma call, no code edit).

**What this is.** A frame-by-frame study of the owner's four X videos, the craft principles behind them, a
screen-by-screen critique of our current UI against those principles, and a ranked Adopt / Reject list.

**Order of the report** (new sections first, as asked):

- [A · Why these videos feel so well done](#a--why-these-videos-feel-so-well-done)
- [B · Our UI against those principles, screen by screen](#b--our-ui-against-those-principles-screen-by-screen)
- [C · Animation opportunities (the gate run over our screens)](#c--animation-opportunities-the-gate-run-over-our-screens)
- [1 · The four videos, frame by frame](#1--the-four-videos-frame-by-frame)
- [2 · Adopt, ranked by impact](#2--adopt-ranked-by-impact)
- [3 · Reject, with reasons](#3--reject-with-reasons)
- [Method and limits](#method-and-limits)

**The short version.**

1. None of the four videos is impressive because of an effect. Each one changes **one object in place**, starts the
   change **at the thing the finger touched**, keeps **one moving lead**, and finishes the readable part in **0.4 to
   0.6 s**. The shaders and gradients are a coat of paint on that structure.
2. Our City Monopoly build already has the right skeleton: the 圈下了 beats, the seal spring and the heavy impact are
   in code (`CityMomentView.swift` on `ui/h-code-city`). What is missing is **continuity** and **content**: the deed's
   photo slot is an empty grey box in every app shot and in the Figma hand-off frames N22 and N38, the claim photo
   never travels into the deed, most numbers swap instead of rolling (the ledger totals are the exception), and
   confirm buttons swap screens instead of changing in place.
3. Seven changes are worth making (section C). The largest is the claim photo flying into the deed. Reject the
   rainbow wave, the purple flood, every 3D ring carousel and every hover effect (section 3).

---

## A · Why these videos feel so well done

Nine principles. Each row gives what the videos do (with the frame or the measurement), the skill rule it follows,
and the name of the pattern from `animation-vocabulary`. Timings come from a per-frame motion-energy measurement on
the 60 fps sources (30 fps for lucass0x); spring values are my estimates from those curves, not published values.

| # | Principle | What the videos do | Evidence | Skill rule |
|---|---|---|---|---|
| 1 | **Timing: the readable part is short, the afterglow is long** | Wallet reveal: body of the move 1.50 → 2.15 s (≈ 0.6 s), settle tail to 2.40 s. Payment card: tap 0.18 s, wave 0.63 → 1.07 s (≈ 440 ms), text sharp by 1.35 s, rim glow fades until ≈ 2.4 s. Arc carousel: one step ≈ 380 ms. Folder hover ≈ 450 ms, bookmark hover ≈ 300 ms. Streak flame fill ≈ 220 ms. Nothing the user must read is hidden for more than about 0.5 s. | sumitXbravo f007 to f009; Jakubantalik f002 to f006 | `apple-design-motion › motion-animation.md §2.3` (micro < 250 ms, full-screen < 500 ms) and `§4.9` (smaller and more frequent = faster); `improve-animations › AUDIT §2` (UI under 300 ms; modals, sheets, toasts up to 500 ms) |
| 2 | **Easing and springs: fast start, soft landing, one small overshoot** | Every energy curve peaks in the first third and decays. The wallet card overshoots once (the "jelly" corners in f007 and f016); the folder image and the arc cards show one secondary bump about 250 ms after the start. No linear moves, no slow starts. My estimates: wallet card `spring(response: 0.55, dampingFraction: 0.8)`; folder reveal `spring(response: 0.35, dampingFraction: 0.7)`; carousel step `spring(response: 0.38, dampingFraction: 0.85)`; flame pop `spring(response: 0.3, dampingFraction: 0.6)`. | sumitXbravo f007, f016; lucass0x f004 | `apple-design-motion` core rule "Springs over fixed easing"; `AUDIT §2` ("ease-in on UI is always a finding"); `choreograph › Step 4` (smaller elements need more bounce) |
| 3 | **Choreography: one lead, followers hooked to it** | Wallet: the eye button is the cause, the card is the lead, digits and card number are followers that resolve inside the card's move, not after it. Payment card: the wave front is the lead; text swaps exactly as the front passes over it. Carousel: cards are the lead, the title swaps at the step start and fades in over ≈ 300 ms, the small button follows the title. Digits resolve with a stagger of roughly 40 to 50 ms each; the whole group lands inside 300 ms. | sumitXbravo f008 (`●584,418` mid-roll); Jakubantalik f003 to f005; lucass0x f008 to f010 | `choreograph › Step 1` (cast lead / support / decoration), `Step 3` ("sync to the cause", "land the accents with the lead"), stagger budget 30 to 80 ms and total under ≈ 300 ms; `motion-animation.md §4.10.1` (followers never overtake the lead) |
| 4 | **Continuity and morphing: the object stays, its state changes** | No video navigates. "Confirm" becomes "Done" on the same button; "Sending to Maya Chen" becomes "Sent to", "Arrives In seconds" becomes "Arrived 9:41 AM", the avatar becomes a check, all in the same card frame. "Buy $20 tokens" becomes "Processing…" and then "Done". The toast's spinner becomes a check and a "View" button grows in last. Masked dots become digits in place. | Jakubantalik f000 vs f006, f012 to f016; sumitXbravo f006 vs f009 | `animation-vocabulary`: Continuity transition, Morph, Text morph, Number ticker; `apple-design-interaction` core rule "optimistic UI … never block input behind a spinner"; `motion-animation.md §2.4` hero and continuity |
| 5 | **Origin: the change starts where the cause is** | Wallet: the purple light is born under the eye button (f007) and spreads across the card; digits appear and disappear from the button's side. Payment card: the wave rises from the pressed Confirm button. The credits card finishes asynchronously, so its wave starts at the status icon instead of the button. Toast: the sweep starts at the icon. | sumitXbravo f007, f026; Jakubantalik f002, f003, f008, f011 | `animation-vocabulary`: Origin-aware animation; `AUDIT §3` (popovers scale from their trigger); `gestures › Spatial consistency` |
| 6 | **Restraint: one effect per surface, everything else still** | In the wallet video the nav, title, buttons, avatars, list and tab bar do not move at all while the card changes. In the payment video the three other cards stay still until it is their turn. Each surface has exactly one entrance. The streak row, the stats and the sheet never animate once built. | sumitXbravo all frames (only the card region has non-zero energy); Jakubantalik f002 to f006 | `choreograph › Hard Rule 1` (one entrance per container); `make-interfaces-feel-better #19` Motion Restraint; `find-animation-opportunities › The Gate` (frequency, purpose); `AUDIT §1` |
| 7 | **Interruptible: you can reverse it mid-flight** | From 8.25 s the wallet is toggled four times in under two seconds. The card, glow and digits reverse from wherever they are (f034 to f039: `$584,4`, `●●84,418`, `$58●●●`), with no snap and no queue. | sumitXbravo f033 to f040 | `gestures › Interruptibility is non-negotiable`; `make-interfaces-feel-better #4`; `AUDIT §4`; `apple-design-motion` core rule "Interruptible + velocity handoff" |
| 8 | **Optical detail: nested radii, tabular digits, one icon weight** | Payment card: outer radius ≈ 32, inner list ≈ 20, padding ≈ 12 (32 = 20 + 12). Wallet: the page card, the inner chips and the capsule buttons share one family. Balance digits are fixed width, so `$584,418` does not shift while rolling. Icons are one stroke weight; the eye swaps to eye-slash with a cross-blur, not a cut. Buttons dip slightly on press (f001: the Confirm button narrows by about 3%). | Jakubantalik f000, f001; sumitXbravo f009, f016 | `make-interfaces-feel-better #1` Concentric Border Radius, `#9` Tabular Numbers, `#7` Contextual Icon Animations (scale 0.25 → 1, opacity 0 → 1, blur 4 → 0), `#12` Scale on Press (0.96), `#17` icon stroke matches text weight |
| 9 | **Depth, material, type rhythm, feedback** | Depth comes from three flat steps (page, card, inset) plus one soft shadow, never from borders. Material is used once: the wallet tab bar is one floating glass capsule with a separate search circle; nothing glass sits on glass. Type has three sizes per surface: a big number (28 to 34 pt, bold), a 15 to 17 pt label, an 11 to 13 pt grey caption, and the number always wins. Every press has a visible answer within one frame (dim, dip, or the spinner in the same control), and the end state has a static cue (check, "Done", "Sent") so motion is never the only signal. | sumitXbravo f000; rehanxahmed f048; Jakubantalik f002, f006 | `make-interfaces-feel-better #3` (shadows for elevation, borders for structure), `#19` ("motion is never the only feedback channel"); `apple-design-materials` core rules ("glass is a layer", "never stack glass"); `apple-design-interaction` ("respond in < 100 ms", "design every state"); `apple-design-os` (primary controls in reach) |

Two things the videos get wrong, so we do not copy them: the wallet's hide takes as long as its reveal (≈ 0.9 s
both ways; `motion-animation.md §4.9.2` says exits are shorter), and the payment wave keeps a coloured rim alive for
a full second after the content is done, which is fine for a demo and too much for a control used daily.

---

## B · Our UI against those principles, screen by screen

Sources: app shots in `/Users/fanning/chengyin-refs/code-final-shots/city/app/`, `/Users/fanning/chengyin-refs/code-final-shots/app-B/`
and `/Users/fanning/chengyin-refs/r2-shots/` (all 2026-11-16), Figma renders in `/Users/fanning/chengyin-refs/code-final-shots/city/figma/`
and `/Users/fanning/chengyin-refs/redesign-backup-1116/revise/skill-r2/shots/`. Stills cannot show motion, so for City
Monopoly I also read the motion-related lines of `App/CityKit/*.swift` on branch `ui/h-code-city` (read-only, via
`git show`). Where I say "in code", that is the source. Frame ids are from `skill-r2.md §3.2`.

### B.0 · Four system-wide gaps (fix once, every screen benefits)

| Gap | Seen in | Principle | Figma change | SwiftUI change |
|---|---|---|---|---|
| **Empty hero.** The deed photo slot is a grey box with a map glyph in every app shot and in the Figma hand-off frames N22 `204:26968` and N38 `204:34407`. The kit sheet (`b2-deed.png`) has photos; the moments do not. | `fixture-city-moment-claimed.png`, `fixture-city-dice-won.png`, `fixture-city-property-open.png`, `figma/204-26968-N22-claimed.png` | A.4, A.9 (the references always put a rich object at the centre) | Set the `Photo` swap on the deeds in N22, N38, N40, N41 and N08 to N12 to the place photos from `Media/Cover` (老麦咖啡馆 `435:4517`, 梧桐书店 `382:1063`). For "no photo yet", draw the district colour at 24% with the district name in t-title, not a glyph on grey. | Give every `city-*` design fixture a bundled photo. In `CityDeedCard`, when the photo is nil, fill with `palette.band.opacity(0.24)` plus the district name; keep the glyph only for the unlit state. |
| **Two motion token sets.** `CYMotion` (press 0.12 / 0.9, release 0.25 / 0.7, standard 0.3 / 0.85, entrance 0.35 / 0.8) and `CityTokens` (press 0.30 / 0.80, sheet 0.38 / 0.86, deed 0.42 / 0.80, seal 0.40 / 0.55, hero 0.45 / 0.86) both exist. The same button press differs between City and the rest of the app. | `App/DesignSystem/CYMotion.swift:77-85`; `App/CityKit/CityTokens.swift:27-33` on `ui/h-code-city` | A.2; `AUDIT §7` cohesion and tokens | On the Motion & Haptics board `402:647`, mark the five springs as the single source and name them (`press`, `release`, `standard`, `entrance`, `sheet`, `moment`, `seal`, `hero`). | Move the City springs into `CYMotion` as `sheet`, `moment`, `seal`, `hero`; make `CityTokens.pressSpring` an alias of `CYMotion.release`; route every City call through `CYMotion.resolve(_:reduceMotion:)`. |
| **Most numbers swap instead of rolling.** 积分余额 is drawn as the text `1286 → 1166`; the dice total, the board stat row and the 我的 tiles change by replacement. The ledger totals are already right (`CityBoardScreens.swift:299-301` uses `.monospacedDigit()` and `numericText`); the rest of the app should match them. | `fixture-city-claim.png`, `fixture-city-dice-won.png`, `fixture-city-board.png`, `05-tab-me-TEST.png` | A.3, A.8; `make-interfaces-feel-better #9` | Add "tabular figures" to the number text styles (t-num and the stat styles) and note "rolls on change" on the 积分 rows of N18, N47, N48 and the total of N38. | `.monospacedDigit()` on every numeric `Text`; `.contentTransition(.numericText(value: Double(points)))` with `withAnimation(.snappy(duration: 0.3))` when the value changes. In the City kit only the ledger totals (`CityBoardScreens.swift:301`) and the die face (`CityDiceKit.swift:70`) do this today. |
| **Tab bar icons are all filled in the app; Figma has outline with the selected one filled.** The selected state is carried only by the darker pill. | `01-home-TEST.png`, `test-roam-root.png` vs `figma/210-8239-home.png` | A.8; `make-interfaces-feel-better #18` (outline default, fill marks active) | None: Figma (`12:129`) is right. | Use the outline symbol for unselected tabs and `.symbolVariant(.fill)` for the selected one, with `.contentTransition(.symbolEffect(.replace))`. No custom animation on tab change (100+ uses a day). |

### B.1 · City Monopoly

| Screen (frame) | Shot | Where we fall short | Figma change | SwiftUI implementation |
|---|---|---|---|---|
| **圈下了 moment** N22 `204:26968` | `city/app/fixture-city-moment-claimed.png`, `fixture-city-claim-ok.png` | **A.4 continuity.** The photo the player just took is the story, and it is not on screen. The beats exist in code (deed 350 ms, seal 600 ms, text 950 ms, actions 1,250 ms; `CityMomentView.swift:87-96`), but beat 1 of SR2-49 (claim thumbnail 58 × 58 → deed photo slot) is not built: `CityClaimFlow.swift` and `CityDeedCard.swift` contain no transition, the City kit has no `matchedGeometryEffect` or zoom transition, and `CityTokens.heroSpring` (`CityTokens.swift:31`) is defined and used nowhere. The deed is 60% dead grey between the +5 line and the holder row. **A.3:** chips stagger at a uniform 60 ms × index (`CityMomentView.swift:124`). | Put the claim photo in the deed (B.0). Shorten the Full deed on moments so it hugs its content (the holder row sits directly under the rent line, as in the kit's Sheet size). Redraw strip beat 1 from N21 with the thumbnail highlighted as the source. | In the claim sheet: `.matchedTransitionSource(id: place.id, in: ns)` on the 58 pt thumbnail; present the moment with `.navigationTransition(.zoom(sourceID: place.id, in: ns))` (iOS 18+), or a shared `matchedGeometryEffect(id:in:)` inside one `ZStack` using `CityTokens.heroSpring` (0.45 / 0.86). Start the deed band 250 ms after the photo starts, not after it ends. Chips: delays `[0, 0.05, 0.09]` instead of `index × 0.06`. Reduce Motion: cross-fade 200 ms (already the pattern). |
| **Claim sheet** N18 `204:26708`, errors N23 to N25 | `fixture-city-claim.png`, `test-claim-sheet.png`, `fixture-city-claim-rejected.png` | **A.4, A.9 feedback.** The primary reads 打开相机拍照 in a disabled-looking dark capsule, then the flow swaps to another screen. There is no in-place "working" state, so the 0.5 to 2 s the server takes has no home. **A.3:** the balance row is static text `1286 → 1166`. The four checks change state with no bridge (spinner to green tick is a cut in the stills' structure; `CityClaimFlow.swift` has no animation call). | Add a `Loading` and a `Done` state of `Player/Button` to N18's primary (the kit has Loading with its label since batch 2). Draw the balance row as one number with a small `−120` chip that fades once the roll ends. | Reuse `CYMorphButton` for the confirm: label → orbit dots + "正在确认" → check, in the same capsule. Balance: `Text(balance, format: .number).monospacedDigit().contentTransition(.numericText(value: Double(balance)))`, change wrapped in `withAnimation(.snappy(duration: 0.3))`, then `.sensoryFeedback(.success, trigger: confirmed)`. Each check row: `Image(systemName:).contentTransition(.symbolEffect(.replace))` so the spinner becomes the tick in place. |
| **Dice: ready, won, lost** N36 `204:34340`, N38 `204:34407`, N39 `204:34440` | `fixture-city-dice-ready.png`, `fixture-city-dice-won.png`, `fixture-city-dice-lost.png` | **A.9 type rhythm.** On N38 and N39 the headline is a bare `17` or `8` at title size with the sentence under it; the number does not win the page the way `$1,250.00` or `6,482` do. **A.4:** the die jumps from the centre of N36 to the corner of the deed in N38. **A.6:** N36 is half empty black between the chip and the button. | N38 / N39: set the total in the large numeric style (48 pt bold, tabular) with `14 + 3` as a caption above it, so the modifier maths is visible. N36: move the odds bar and the headline down to sit above the button (thumb zone), leaving the die alone in the top half. | The die is one view across the three stages: `matchedGeometryEffect(id: "die", in: ns)` inside the `stage` switch that already animates with `CityTokens.deedSpring` (`CityChallengeFlow.swift:332`). Total: `.contentTransition(.numericText(value:))` counting 14 → 17 over 300 ms, 400 ms after the die lands (the SR2-49 row). Lost: no extra motion; the grey die and one `.impact(flexibility: .soft)` are enough. |
| **Challenge sheet** N34 `204:34263` | `fixture-city-challenge.png` | **A.9 depth.** Sheet → grouped card → rows → chips is four surfaces deep, each a slightly different grey. The disabled primary (开始挑战 · 90 积分) is nearly the same grey as the sheet, so the reason it is disabled (距离) is two cards away from it. | Flatten: the odds bar sits directly on the sheet surface (no card); keep one card for the three checks. Put the blocking reason as a caption directly above the disabled button (再走近 235 m). | Layout only. When the distance check passes, animate the button's fill from `surface-3` to `cta` with `.animation(CYMotion.standard, value: canStart)` and fire `.sensoryFeedback(.selection, trigger: canStart)` once. |
| **漫游 root and property sheets** `210:8322`, N08 to N12 (`204:23400` …) | `test-roam-root.png`, `fixture-city-roam.png`, `fixture-city-property-open.png`, `fixture-city-property-mine.png` | **A.9 material.** The sheet over the live map is an opaque block (`presentationBackground(palette.bgElevated)`, `CityPropertySheet.swift:55`), so the map, which is the product, is simply cut off. **A.5 origin:** nothing ties the tapped pin to the sheet. **A.8:** the deed inside the sheet has its own dashed outline inside the sheet's own edge (box in a box). | Draw the 420 pt detent of N08 to N12 with the system sheet material (note: "system glass at the partial detent, opaque at large"), and the deed inside as a plain fill with no outline. Keep the dashed outline only for the claimable state on lists. | At the partial detent, drop the opaque background and let the system sheet material show (iOS 26+: the default sheet is Liquid Glass at partial height and turns opaque at `.large`; on older systems `.presentationBackground(.regularMaterial)`). Never put another material on the deed inside it. Pin: scale 1 → 1.15 with `CYMotion.release` on select (SR2-49 row), `.sensoryFeedback(.selection, trigger: selectedPin)`. Reduce Transparency is handled by the system material. |
| **City board** N01 `204:21814`, **my places** N46 `205:8376`, **ledger** N28 `204:33843` | `fixture-city-board.png`, `fixture-city-mine.png`, `fixture-city-ledger.png` | **A.9 depth and rhythm.** The three stats sit in a bordered tile; the reference stat rows (rehanxahmed f048) need no box, only hairline dividers, and read faster. Every row thumbnail is the same grey map glyph, so three different places look identical. (The ledger totals already roll in tabular digits; keep that.) | Stats: remove the tile fill, keep two 1 pt `sep` dividers, raise the numbers to 22 pt bold tabular. Rows: real thumbnails (B.0). | `HStack` with `Divider().frame(height: 28)` between three `VStack`s; give the N01 stat row the same `.monospacedDigit()` + `numericText` the ledger totals have. Roll only when a value really changes, never on every visit (`AUDIT §1`: tens of times a day gets no animation). |
| **Shield and upgrade sheets** N47 `205:8475`, N48 `205:8580` | `fixture-city-shield.png`, `fixture-city-upgrade.png` | **A.4.** Same as the claim sheet: the capsule should become the result in place, and the sheet should close on success with the row behind it already updated. The shield sheet leaves 40% of its height empty under the button. | N47: one detent that hugs its content (SR2-49 already says "height = content"). Add Loading and Done states to both primaries. | `.presentationDetents([.height(measuredHeight)])` from a `GeometryReader` preference; `CYMorphButton` for the primary; on success dismiss after 600 ms and let the row's protection tag change with `.contentTransition(.numericText())` on the time. |
| **Home rail 我的地盘** `210:8239` | `fixture-city-home-rail.png`, `test-home-rail.png` vs `figma/210-8239-home.png` | **A.4, A.9.** In Figma the rail is three photographed deeds under a photo hero; in the app it is two grey Minis on black. Tapping a Mini has no connection to the sheet it opens. | None beyond B.0. | Rail: `ScrollView(.horizontal)` with `.scrollTargetBehavior(.viewAligned)` and `.scrollTargetLayout()`. Each Mini is a `matchedTransitionSource`; the property sheet uses the zoom transition from it. |

### B.2 · Player, club, merchant, editor

| Screen (frame) | Shot | Where we fall short | Figma change | SwiftUI implementation |
|---|---|---|---|---|
| **首页** `210:8239` | `r2-shots/01-home-TEST.png` vs `figma/210-8239-home.png` | **A.9.** The first screen is 45% empty black above the fold, and the one card in 编辑精选 is dimmed under the bar fade with its title cut. The Figma frame leads with a full-width photo and the rail. **A.6:** the fade under the tab bar is doing the work of a layout. | None: build to the frame (title + subtitle, hero photo, rail). | Hero rail: `scrollTransition { content, phase in content.scaleEffect(phase.isIdentity ? 1 : 0.94).opacity(phase.isIdentity ? 1 : 0.7) }` with `.viewAligned` snapping. This is scroll-linked, so it costs the user no time. Title under the hero changes with `.transition(.blurReplace)` in 200 ms when the focused card changes. |
| **我的** `210:8603` | `r2-shots/05-tab-me-TEST.png` | **A.9 depth, A.8 radii.** Profile card → three stat tiles → a white 票夹 button → two more tiles, then a row of three circles: five container shapes and three radii in one viewport. The purple ring on the avatar is the only purple on the page and it marks nothing. 连续探索 3 天 is a caption, where the reference gives a streak its own row. | Stats as a divider row (as N01). Replace the avatar ring with the level ring in `ink` or remove it. Add a 7-day streak row under the name: seven 24 pt dots with weekday letters, lit days in `ink`, today's letter bold (neutral, per the selected-state rule). | Streak: `HStack` of seven symbols; when today lights up, `.symbolEffect(.bounce, value: litToday)` once and `.sensoryFeedback(.impact(weight: .light), trigger: litToday)`. Balance and 积分: `.monospacedDigit()`. If 账户余额 gets a hide toggle, use the reveal in section 2 item 5. |
| **开局大厅** `204:15032` | `app-B/03b-204-15032-lobby-FIXTURE-t5-seats.png` | **A.5, A.9 feedback.** Good structure. Two gaps: a seat changing from 可邀请 to a person has no arrival, and the hold button's end state (what the button becomes when the hold completes) is not drawn. | Add the `Done` state of `Player/Hold Button` to the frame set next to `436:11032`. | Seat: new avatar enters with `.transition(.scale(scale: 0.9).combined(with: .opacity))` under `CYMotion.entrance` and `.sensoryFeedback(.impact(weight: .light), trigger: seats.count)`. Hold: ring `.linear(duration: 0.8)`, release snaps back with `CYMotion.release` (asymmetric, per `gestures › Hold gestures`), `.impact(weight: .medium)` at completion (already the SR2-49 row). |
| **俱乐部 root** `210:8452` and **club create** `204:24591` | `app-B/07-210-8452-clubs-root-TEST.png`, `app-B/05-204-24591-club-create-step1-FIXTURE-d4-ops-create.png` | **A.8.** List thumbnails have no edge on the dark surface, so dark photos melt into the card (沪上实景推理局). 梧桐摄影漫步社 wraps with two characters orphaned. **A.3:** wizard steps need direction. | Add a 1 pt white 10% inner stroke to `Club/List Card` thumbnails. Allow the name two balanced lines or truncate at one. | `.overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.white.opacity(0.1), lineWidth: 1))`. Wizard: `.transition(.asymmetric(insertion: .move(edge: forward ? .trailing : .leading), removal: .move(edge: forward ? .leading : .trailing)).combined(with: .opacity))` with `CYMotion.standard`; the selected option's check uses `.contentTransition(.symbolEffect(.replace))`. |
| **活动详情** and **报名 sheet** | `r2-shots/08-activity-detail-FIXTURE-e1.png`, `r2-shots/09-registration-sheet-FIXTURE-e1-registration.png` | **A.8.** The fact strip clips its third column at the screen edge (`11月21日 14:`). The pinned 立即报名 bar is right (it matches the reference's floating CTA). On the sheet, 合计 shows a dash where a number will be. | Fact strip: three equal columns that wrap to two lines, or a horizontal scroller with a visible fade. | `ViewThatFits` between a 3-column `Grid` and a 2 + 1 layout; total: `numericText` when a ticket is chosen. |
| **商家工作台** `182:7328` and **身份信息** `182:7628` / `406:9580` | `r2-shots/18-merchant-workbench-FIXTURE-merchant-home.png`, `app-B/01c-406-9580-identity-checked-FIXTURE-MOF.png` | Closest to the references already: one big number (待处理 3), two supporting numbers, quiet rows. **A.9 feedback:** when the consent box is ticked, 下一步 jumps from grey to black. | None. | `.animation(CYMotion.standard, value: consent)` on the button fill and label colour; checkbox tick drawn with the existing `CYResultMark` in 200 ms. Digits `.monospacedDigit()` so ¥2110.50 and ¥301.50 align. |
| **编辑玩法模板** `237:43689` | `app-B/04-237-43689-template-editor-FIXTURE-t11.png` | Calm and finished. The cover is a grey placeholder with three stacked text actions under it (选择封面 / 预览当前封面 / 移除封面), which reads as a form, not a cover. | Put 选择封面 on the cover itself (centre glyph + label); move the other two into a menu on the pencil. | `Menu` on the pencil; cover change uses `.transition(.blurReplace)`. |
| **Welcome** | `r2-shots/00-welcome-TEST.png` | Fine. This is the one place the delight budget allows a longer beat. | None. | Keep `CYOnboardingWave`. Do not add more. |

### B.3 · Worst-case data seen in the shots (`break-ui`, from stills only)

I did not build a toggle (review only). These are breaks already visible:

| Severity | Where | Value | What happens | Fix |
|---|---|---|---|---|
| Broken | 活动详情 fact strip, `08-activity-detail-FIXTURE-e1.png` | `11月21日 14:…` | Third column runs off the right edge | Columns with `minWidth: 0` behaviour (`ViewThatFits`), see B.2 |
| Ugly | 俱乐部 root, `07-210-8452-clubs-root-TEST.png` | 梧桐摄影漫步社 | Wraps with a two-character orphan | `.lineLimit(2)` with balanced wrapping, or one line with tail truncation |
| Ugly | Deed Row in the Figma kit, `b2-deed.png` | 武康路街区 据点 Lv2 | Meta line clips at `Lv:` in two variants | Let the level pips yield before the text; `.layoutPriority(1)` on the name and level |
| Fragile | Every deed | photo = nil | Grey placeholder everywhere | B.0 |

---

## C · Animation opportunities (the gate run over our screens)

`find-animation-opportunities`, run from the shots and the City code lines. Every candidate went through the four
questions (frequency, purpose, speed, function). Seven survived; that is the cap.

### Part 1 · Opportunities

| # | Location | Today | Purpose | Frequency | Suggested motion |
|---|---|---|---|---|---|
| 1 | Claim sheet → 圈下了, N21 → N22 `204:26968` (`CityClaimFlow.swift`, `CityMomentView.swift`) | The moment replaces the sheet; the photo is not carried | Spatial consistency | Rare (a few claims a week) | Zoom the 58 pt claim thumbnail into the deed photo slot: `matchedTransitionSource` + `.navigationTransition(.zoom)`, or `matchedGeometryEffect` with `spring(response: 0.45, dampingFraction: 0.86)`. Deed band starts at +250 ms. Reduce Motion: 200 ms cross-fade. |
| 2 | Confirm buttons on N18, N34, N47, N48 | Button → new screen | State indication, feedback | Occasional | `CYMorphButton`: label → progress → check in the same capsule; press dip to 0.97 with `CYMotion.press`, release `CYMotion.release`. Total visible change under 300 ms once the server answers. |
| 3 | 积分 balances and totals (N18 balance row, N38 total, N01 stat row, 我的 积分; N28 already does it) | Text swap | State indication | Occasional | `.monospacedDigit()` + `.contentTransition(.numericText(value:))`, `withAnimation(.snappy(duration: 0.3))`. |
| 4 | One success wave on 圈下了 and 拿下 (N22, N38) | Seal lands with a heavy impact; nothing else marks the win | Delight (rare tier only) | Rare | Reuse `CYWave` once, from the confirm button's last position, 450 ms, amplitude 6 pt, white at 12% (no colour). Starts with the seal's contact at ≈ 780 ms. Off under Reduce Motion and Low Power. |
| 5 | Lobby seat fills, `204:15032` | Seat state cuts | Preventing a jarring change | Occasional | Avatar scale 0.9 → 1 + opacity, `spring(response: 0.35, dampingFraction: 0.8)`, light impact. |
| 6 | Club create wizard steps, `204:24591` | Steps replace each other | Spatial consistency | Rare | Direction-aware slide + fade, 0.3 / 0.85 spring; back reverses the direction. |
| 7 | Pin → property sheet, `210:8322`, N08 | Sheet rises with no link to the pin | Spatial consistency | Tens a day while playing, so keep it near-imperceptible | Pin scale 1 → 1.15, `spring(response: 0.25, dampingFraction: 0.7)`; nothing else. The sheet itself keeps the system's motion. |

### Part 2 · Rejected candidates

- **Tab changes** (`12:129`). Rejected: 100+ a day. System behaviour only; the symbol fill change is the feedback.
- **Stat count-up every time the board or 我的 opens.** Rejected: tens of times a day on data the player is reading. Roll only when the value actually changes.
- **Idle pulse on map pins.** Rejected: function. Pins are data on a map the player is navigating; pulsing competes with the location dot and costs battery.
- **Staggered rows inside sheets** (claim checks, challenge checks, 附近 list). Rejected: `choreograph › Hard Rule 1`. The sheet is the entrance; its content is already there.
- **The wave on every confirm, chip or toggle.** Rejected: frequency. It is a rare-tier effect; on a daily control it becomes a delay.

### Part 3 · Verdict

The interface needs **less new motion than the videos suggest and more connection**. The moment choreography, the
hold button, the dice and the Reduce Motion fallbacks are already in the build. What reads as "flat" next to the
references is the missing photo, the missing photo-to-deed continuity, and results that arrive as a new screen
instead of a changed control. Item 1 has the highest leverage, and it depends on B.0's photo fix. Hand any row to
`improve-animations plan <row>` for a self-contained implementation plan.

---

## 1 · The four videos, frame by frame

Frames are in `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/<video>/`, one every 0.25 s,
named `fNNN_SS.SSs.jpg`. I read all 233 in order (52 + 84 + 49 + 48).

### 1.1 · Jakubantalik (13.0 s, 1600 × 1080, 60 fps): a state-change wave on dark cards

A web component demo on a near-black page: four dark cards, each of which changes state in place under a shader
wave. It then replays two of them in a tilted 3D close-up.

| Time | What happens |
|---|---|
| 0.00 | Rest. Four cards: **payment** ("Sending to Maya Chen", `$1,250.00`, a 4-row inset list From / Arrives / Fee / Note, white capsule Confirm), **credits** ("Add credits", balance caption, three check rows, "Buy $20 tokens"), a **toast** pill ("Sending 11.054 USDC", spinner), a **document** card ("Q3 at a glance"). Cursor on Confirm. |
| 0.18 to 0.25 | Press. Confirm dims and narrows about 3%. A few white specks appear over the bottom rows (anticipation). The other cursor presses Buy. |
| 0.50 | The lower rows smear vertically and split into red / blue fringes (chromatic offset). Buy has become a grey "Processing…" with a spinner in the same capsule. |
| 0.63 to 1.07 | The wave: a soft arc of pink, blue and orange rises from the button to the top of the card in ≈ 440 ms. Everything behind the front is blurred beyond reading; the Confirm capsule stays sharp the whole time. |
| 1.25 | Content resolves under the retreating blur: a green blob where the avatar was, "Sent to Maya Chen", "Arrived 9:41 AM", the button now says "Done". |
| 1.50 | Sharp. Green check disc. A coloured rim (yellow left, violet right) hugs the card's inner edge. |
| 1.50 to 2.40 | The rim fades (≈ 1 s). Nothing else moves. |
| 1.75 to 2.50 | Credits card: its rows jitter, a green wave starts at the top icon and runs downward; title becomes "Credits added", balance `$65.73` → `$85.73`, the button label crosses from blank to "Done". Green rim fades by 3.0. |
| 2.50 to 3.50 | Toast: specks around the coin icon, a blue sweep left to right; the icon becomes a check disc, "Sending" becomes "Sent". Document card: a blur sweep rewrites the title to "A strong third quarter" and the paragraph, left to right, line by line. |
| 3.75 | A "View" button blurs in at the toast's trailing edge, last. |
| 4.00 to 8.25 | Cut to a tilted close-up of the payment card; slow upward camera drift (4.25 to 5.75), then the same sequence: specks 6.00, fringes 6.25, wave 6.50 to 6.75, resolve 7.00, check draws at 7.25, rim fades to 8.25. |
| 8.50 to 11.50 | Close-up of the toast: speck ring around the icon 8.75, blue sweep 9.00, the check draws on (a chevron mid-stroke at 9.25), text resolves left to right 9.50 to 10.00, "View" blurs in 10.25 to 10.50. |
| 11.75 to 12.75 | Back to the overview; cursors return to the buttons (loop). |

**Parts and components.** Card radius ≈ 32 with an inner list at ≈ 20 and ≈ 12 padding (concentric). Page `#0A0A0A`,
card ≈ `#1C1C1C`, inset ≈ `#232323`, hairline dividers. Type: grotesk sans; amount ≈ 28 pt semibold; labels 13 pt
grey on the left, values 13 pt white on the right; caption 12 pt grey. Buttons: white capsules, 44 pt, black 15 pt
medium label. Status: 36 pt green disc with a white check. Toast: full capsule, 40 pt leading icon disc, two text
lines, trailing ghost button.

**Motion details.** Three phases: anticipation ≈ 400 ms (specks, fringes), sweep ≈ 440 ms, resolve ≈ 280 ms, then a
≈ 1 s afterglow. The content swap is hidden under the blur front, so old and new text never overlap (`AUDIT §7`: a
double-exposed crossfade masked by blur). The pressed control never blurs. The wave's origin is the cause: the
button when the user caused it, the status icon when the server did. Tint follows meaning: neutral iridescent for
the transfer, green for success, blue for the coin's brand.
**Haptic-worthy moments:** press (none needed), the moment the content resolves (success), not the afterglow.

**In SwiftUI terms.** `.layerEffect(ShaderLibrary.…, maxSampleOffset:)` driven by a `keyframeAnimator` or a
`TimelineView(.animation)` progress; text changes under `.transition(.blurReplace)`; the check as a drawn path (our
`CYResultMark`) or `.symbolEffect(.drawOn)` on iOS 26; "View" entering with `.transition(.blurReplace)`;
`.sensoryFeedback(.success, trigger:)` at the resolve.

**Key frames.**
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/Jakubantalik/f000_00.00s.jpg` (rest)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/Jakubantalik/f002_00.50s.jpg` (fringes; "Processing…" in place)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/Jakubantalik/f003_00.75s.jpg` (wave front, button still sharp)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/Jakubantalik/f006_01.50s.jpg` (new state, rim glow)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/Jakubantalik/f013_03.25s.jpg` (toast and text rewrite mid-sweep)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/Jakubantalik/f042_10.50s.jpg` (toast end state with "View")

### 1.2 · lucass0x (20.8 s, 1080 × 1080, 30 fps): six card and carousel components

A 2 × 3 montage of six separate screen recordings of a web component kit. Each cell has the demo on the left and a
dark parameter panel on the right. All six run at once for the whole video, so the timeline is by cell.

| Cell | What it is | What happens over the video |
|---|---|---|
| Top left · **Card · Folder** | Three cards shaped like file folders (a tab notch at the top right), numbered 01 / 02 / 03, in indigo, white and near-black | Hover lifts a glossy image up from behind the folder front while the number slides down to make room (0.25 hover 01; 1.00 hover 02; 1.50 hover 03). Each reveal ≈ 450 ms with one small overshoot; leaving reverses it. From 5.00 a "Preset" menu recolours all three at once (indigo 6.25, coral 7.25, graphite 8.50). 10.50 to 13.50 the hovers repeat. |
| Top right · **Card · Bookmark** | Three dark cards with a notched top and a bottom tab, each with a glowing wave image, a caption and a big thin headline ("Let's Talk.", "+190%", "One Call.") | Hover raises the card about 8 pt and floods it with its accent colour (blue 0.25, red 1.00, violet 1.50) in ≈ 300 ms, ease-out. Only the hovered card changes. |
| Middle left · **Arc Focus Carousel** | Seven beige rounded cards on an arc; the centre one is larger and upright; a title with ‹ › under it ("Warm Neutrals", "Shaped by Hand", …) | Steps every ≈ 0.4 s at the start; each step ≈ 380 ms. The title is cut at the step start and the new one fades in over ≈ 300 ms, then a small black button. From 6.50 the panel sliders change radius, spacing and arc height live (cards fan out, drop below the title, bunch into a stack at 10.50, spread again at 12.00). |
| Middle right · **Circular UI Slider** | A ring of about 14 testimonial and feature cards on a 3D cylinder against terracotta; the front card is a tinted translucent one | Rotates continuously. 6.00 to 8.25: the tilt slider tips the ring until it is seen from above, then back. 10.50 to 11.25: card width grows until cards overlap. 12.00 to 13.00: cards shrink to thumbnails. 16.00 to 17.75: perspective is pushed until the cards tower. |
| Bottom left · **Spotlight Carousel** | A row of portrait photo cards; the centre card is taller, has a title ("Quiet Confidence") and a white capsule button; the edges fade out | Steps left and right in ≈ 0.4 s (0.00 to 1.25). Neighbours keep a dim, blurred copy of their title during the move. 15.00 to 16.75: card size drops to tiny; 17.50 to 18.50: grows until the centre card fills the cell. |
| Bottom right · **Image Carousel Ring** | Thirty or more small image cards standing like a fanned deck around a tilted ellipse on white | Slow rotation. Sliders flatten it to a thin ring (6.00), open it into a wide fan (7.00), shrink it to a bracelet (15.25), turn it face-on into a clock of ticks (19.25), and at 19.50 it leaves the frame. |

**Parts and components.** Cards have large radii (≈ 20) and no borders; depth is one soft shadow. The folder and
bookmark cards get their character from a silhouette (the notch), not from an effect. Type: bold numerals 28 pt,
thin display headlines 28 to 32 pt next to 11 pt captions.

**Motion details.** Every step is ease-out with a small overshoot and is retargeted mid-flight when the next step
arrives (the arc cell steps four times in 1.6 s without stutter). The title never slides with the cards: it is
decoration that swaps at the step start (`choreograph › Step 1`). The rings are driven by continuous rotation plus
perspective; they are showpieces for a marketing page.
**Gestures:** hover, click on a card, drag on the carousels (per the cell captions). No haptics (web).

**In SwiftUI terms.** The spotlight and arc carousels map to `ScrollView(.horizontal)` +
`.scrollTargetBehavior(.viewAligned)` + `scrollTransition` (scale, opacity, a small rotation); the title swap to
`.transition(.blurReplace)` or `.contentTransition(.opacity)`; the rings to `rotation3DEffect` in a custom `Layout`,
which I recommend against (section 3).

**Key frames.**
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/lucass0x/f000_00.00s.jpg` (all six at rest)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/lucass0x/f004_01.00s.jpg` (folder 02 open, bookmark red lifted)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/lucass0x/f013_03.25s.jpg` (arc title mid-swap: cards moved, title still fading)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/lucass0x/f027_06.75s.jpg` (ring tipped; arc cards below the title)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/lucass0x/f071_17.75s.jpg` (spotlight at its largest)

### 1.3 · rehanxahmed (12.05 s, 1440 × 1800, 60 fps): a light habit screen assembled by cursors

One iPhone on a white ground. Four coloured design-tool cursors (one labelled "Rehan") build a walking-habit screen
piece by piece; a 3D character walks on a treadmill in a loop from the moment it appears.

| Time | What happens |
|---|---|
| 0.00 | Black screen. |
| 0.25 | Empty light screen (pale mint to white gradient), status bar 09:41. |
| 0.50 to 1.00 | Cursors arrive; a red margin guide appears on the left. |
| 1.00 to 2.00 | "17 Nov" is typed in a small text box, then scaled up to a 28 pt title. Two round icon buttons are placed top right (calendar, people). Right margin guide appears. |
| 1.75 to 2.25 | Subtitle typed: lock glyph + "Apps locked until 9 PM". |
| 2.25 to 5.50 | The streak row: a grey flame with a weekday letter is stamped about every 0.5 s (W, T, F, S, S, M, T). From 4.00 a second cursor follows and fills flames orange one by one; each fill pops in ≈ 220 ms with a small overshoot. Today's "T" stays unlit, its letter bold. |
| 2.50 to 3.25 | A grey rectangle is dragged out (239 × 243, then 268 × 272); at 3.00 the walking character replaces it; at 3.25 its frame disappears and it sits directly on the page. |
| 3.50 to 5.25 | Stats: "6,482 / steps" is typed, duplicated to the right, retyped as "4.9 / km walked", duplicated again as "81% / of daily goal". Thin vertical dividers appear between them at 5.25. |
| 4.25 to 5.00 | A rectangle is dragged out below (360 × 185) and becomes a white rounded sheet. |
| 5.25 to 6.25 | "Locked apps" is typed small, scaled to a 20 pt title; "4 apps" at the right; a dashed divider. |
| 6.25 to 7.75 | First row: a 48 pt icon tile becomes the Instagram icon; "Instagram", "1h 12m", "14 opens" are typed. The row is duplicated and becomes TikTok, 54m, 9 opens. |
| 7.50 to 10.25 | A grey bar (370 × 56) is drawn at the bottom, turns black, becomes a capsule; a walking glyph and "Start a walk" are typed (with one correction at 9.50). Guides vanish at 10.25. |
| 10.50 to 12.00 | Cursors leave. Final screen holds; the character keeps walking. |

**Parts and components (final frame).** Header: day number 28 pt bold with the month lighter beside it; 13 pt grey
subtitle with a lock glyph; two 40 pt round buttons. Streak row: seven 24 pt flames with 11 pt letters, lit =
orange, unlit = grey, today's letter black and bold. Hero: an unframed 3D figure on the page gradient, about 40% of
the height. Stats: three columns, 20 pt bold number over an 11 pt grey label, separated by 1 pt dividers, no box.
Sheet card: white, radius ≈ 28, 20 pt title with a lock glyph, count at the right, dashed divider, rows of 44 pt app
icon + bold name + grey duration + right-aligned "14 opens". CTA: black capsule, 52 pt, glyph + label, floating over
the list, which fades under it.

**Motion details.** The build is a presentation device, not product motion. The product motion is small: the flame
fill (pop in, ≈ 220 ms, overshoot) and the hero's idle loop (one stride ≈ 1 s, never stops). The screen works because
of layout: one hero, one row of three numbers, one list, one button.
**Haptic-worthy moments in a real app:** the day's flame lighting (light impact), the hold or tap on "Start a walk".

**In SwiftUI terms.** Streak: `Image(systemName: "flame.fill").symbolEffect(.bounce, value: lit)`; stats: `HStack`
with `Divider()`; sheet card: a plain `RoundedRectangle(cornerRadius: 28, style: .continuous)`; CTA in
`.safeAreaInset(edge: .bottom)`; hero loop: a `TimelineView(.animation)` sprite or a short looping video, paused
under Reduce Motion.

**Key frames.**
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/rehanxahmed/f007_01.75s.jpg` (title scaled, guides, cursors)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/rehanxahmed/f016_04.00s.jpg` (first flame fills; stat being typed)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/rehanxahmed/f020_05.00s.jpg` (three stats, sheet drawn)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/rehanxahmed/f031_07.75s.jpg` (rows done, CTA bar being drawn)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/rehanxahmed/f048_12.00s.jpg` (final screen)

### 1.4 · sumitXbravo (11.95 s, 2160 × 2160, 60 fps): a balance reveal on a wallet card

One iPhone, a light wallet home. The only thing that ever moves is the dark card, when its eye button is tapped.

| Time | What happens |
|---|---|
| 0.00 to 1.35 | Rest. "Wallet" title; a black card (logo, "Everyday / Debit card", eye button top right, "Total balance", six grey dots, `•••• •••• •••• 7984`, CVV `•••`); Transfer and Add money capsules; a "Recent" avatar row; a "Transactions" list; a floating tab bar capsule with a separate search circle. |
| 1.38 to 1.45 | Tap on the eye. The button flashes for about 70 ms. |
| 1.55 to 1.82 | The eye glyph cross-blurs to eye-slash (≈ 270 ms). |
| 1.75 | A violet light is born under the button and reaches about a third of the card. The card's outline warps: the top edge bows and the right side lifts, like a sheet of gel being pushed. |
| 2.00 | Violet covers the upper right half. Digits roll up into place from the right: `●584,418` (the leftmost is still a dot). Card number groups resolve; CVV shows `382`. The card is still slightly skewed. |
| 2.25 | Settled: `$584,418`, `5412 7534 9021 7984`, CVV 382, a violet-to-black diagonal gradient. Motion energy is back to zero by ≈ 2.40. |
| 2.25 to 3.80 | Hold. Nothing moves. |
| 3.85 to 4.75 | Tap again. Eye ripples (concentric rings at 4.00), the violet drains toward the button, the card warps the other way, digits drop out from the right (`$584,418` with the last digits dim at 4.25; `$●●●●●` at 4.50), back to dots by 4.75. |
| 4.75 to 6.40 | Hold, masked. |
| 6.50 to 7.25 | Reveal again (same as 1.38 to 2.25). |
| 7.25 to 8.20 | Hold, revealed. |
| 8.25 to 10.00 | Rapid toggling: hide starts (8.50 `$584,4`), reversed into reveal (8.75 glow, 9.00 `●584,418`), reversed again (9.25 `$584,41`, 9.50 `●●84,418`, 9.75 `$58●●●`), masked by 10.00. No snap at any reversal. |
| 10.00 to 11.75 | Rest, masked. |

**Parts and components.** Page ≈ `#EEF0F2`; white cards radius ≈ 24; the wallet card radius ≈ 24, black with two
faint concentric rings as its only decoration. Balance 34 pt bold with a small raised `$`; labels 11 pt at 60%
white; card number in spaced tabular digits. Accent violet used four times on the page: the badge, the active tab,
"View all", and the revealed card. Tab bar: one glass capsule with four icons (active one tinted, on a lighter
pill) plus a detached search circle.

**Motion details.** One spring drives everything: my estimate is `spring(response: 0.55, dampingFraction: 0.8)`.
The body of the move is ≈ 0.6 s and the tail ≈ 0.25 s. The warp is squash and stretch on the card's shape (a mesh
or a distortion shader), with one overshoot. Digits are a number ticker with a blur, staggered roughly 40 to 50 ms
each from the button's side. Everything is interruptible (8.25 to 10.00). The hide is as long as the reveal, which
I would shorten.
**Haptic-worthy moments:** the tap (selection), and nothing else; the reveal is its own feedback.

**In SwiftUI terms.** `Image(systemName: hidden ? "eye" : "eye.slash").contentTransition(.symbolEffect(.replace))`;
digits with `.contentTransition(.numericText())` and `.monospacedDigit()`; the light as a `RadialGradient` (or
`MeshGradient`, iOS 18) whose radius animates from the button's anchor; the warp as a `.distortionEffect` or a
`keyframeAnimator` on a small `rotation3DEffect` + `scaleEffect`; `.sensoryFeedback(.selection, trigger: hidden)`.

**Key frames.**
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/sumitXbravo/f000_00.00s.jpg` (masked)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/sumitXbravo/f007_01.75s.jpg` (light born at the eye; card warps)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/sumitXbravo/f008_02.00s.jpg` (digits mid-roll)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/sumitXbravo/f009_02.25s.jpg` (revealed)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/sumitXbravo/f017_04.25s.jpg` (hiding)
- `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/sumitXbravo/f037_09.25s.jpg` (reversed mid-flight)

---

## 2 · Adopt, ranked by impact

Thirteen patterns. "Figma" is the change to file `0YyoybGnU1KG0657wdGCPX` (not made; the call allowance is
reserved). Reduce Motion for every row: the move becomes `CYMotion.reduced` (a 200 ms cross-fade); haptics stay.

Availability: the app's deployment target is iOS 17.0. `numericText`, `sensoryFeedback`, `symbolEffect`,
`.blurReplace`, `scrollTransition`, `keyframeAnimator` and `layerEffect` are all iOS 17. The zoom navigation
transition and `MeshGradient` need `if #available(iOS 18, *)` (fall back to `matchedGeometryEffect` and a
`RadialGradient`); the glass sheet default and `.symbolEffect(.drawOn)` need iOS 26 (fall back to
`.regularMaterial` and `CYResultMark`).

| # | Pattern (source) | Where in 城瘾 | SwiftUI implementation | Figma change |
|---|---|---|---|---|
| 1 | **The object carries over: photo → deed** (Jakubantalik: the card never leaves; sumitXbravo: one object, two states) | Claim N21 → 圈下了 N22 `204:26968`; home rail Mini → property sheet N11; 我的地盘 row N46 `205:8376` → sheet | `matchedTransitionSource(id:in:)` on the source, `.navigationTransition(.zoom(sourceID:in:))` on the destination (iOS 18+); inside one screen, `matchedGeometryEffect` with `spring(response: 0.45, dampingFraction: 0.86)` | Photos in the moment deeds (B.0); claim strip beat 1 redrawn from the thumbnail |
| 2 | **Confirm in place** ("Confirm" → "Done"; "Buy" → "Processing…" → "Done") | Primaries of N18 `204:26708`, N34 `204:34263`, N47 `205:8475`, N48 `205:8580`, 活动报名 | `CYMorphButton` (exists): label → dots → `CYResultMark`; press 0.97 `CYMotion.press`, release `CYMotion.release`; `.sensoryFeedback(.success, trigger: done)` | Loading and Done states of `Player/Button` placed on those four frames |
| 3 | **Numbers roll, in fixed-width digits** (wallet balance; `$65.73` → `$85.73`) | 积分余额 on N18, N47, N48; the total on N38 `204:34407`; the N01 `204:21814` stat row; 我的 `210:8603`; merchant workbench `182:7328`. The ledger N28 `204:33843` already does it and is the model. | `.monospacedDigit()`; `.contentTransition(.numericText(value:))`; `withAnimation(.snappy(duration: 0.3))`; roll only on a real change | Tabular figures on the numeric text styles; note "rolls on change" |
| 4 | **Stats without a box** (rehanxahmed: three numbers, two dividers) | N01 `204:21814` stat row, N28 header, 我的 `210:8603` tiles | `HStack { stat; Divider().frame(height: 28); stat; Divider().frame(height: 28); stat }`, number 22 pt bold, label 11 pt `ink-3` | Remove tile fills on those three rows; `Player/Stat Tile` gets a `Plain` emphasis |
| 5 | **Origin-aware reveal of a hidden value** (sumitXbravo) | 我的 `210:8603` 账户余额 and 积分, if the owner wants a hide toggle; ticket codes in 票夹 `204:29927` | Eye button: `.contentTransition(.symbolEffect(.replace))`; digits `numericText`, 250 ms; a white 8% `RadialGradient` growing from the button's anchor with `spring(response: 0.4, dampingFraction: 0.85)`; hide in 200 ms (shorter than the reveal); `.sensoryFeedback(.selection, trigger: hidden)`. No colour flood, no warp. | A masked and a revealed state of the balance tile |
| 6 | **A streak row** (rehanxahmed) | 我的 `210:8603` (连续探索 3 天) and the 漫游 header subtitle on `210:8322` | Seven 24 pt symbols + weekday letters; lit = `ink`, unlit = `ink-3`, today's letter bold; `.symbolEffect(.bounce, value: litToday)` once; `.impact(weight: .light)` | New `Player/Streak Row` in the kit, neutral colours |
| 7 | **One success wave, once** (Jakubantalik, reduced) | 圈下了 N22 and 拿下 N38 only | Reuse `CYWave` (`App/DesignSystem/CYWave.metal`): single pass, 450 ms, amplitude 6 pt, white at 12%, origin = the confirm button's last frame, starting at the seal's contact (≈ 780 ms). Off under Reduce Motion and Low Power Mode. | One annotation on the two frames; no new artwork |
| 8 | **Toast that changes state and grows its action last** (Jakubantalik toast) | `Player/Toast`: 租金到账, 报名成功, 已保存 | Leading icon `.contentTransition(.symbolEffect(.replace))` (progress → check); title `.contentTransition(.opacity)`; trailing 查看 enters 300 ms later with `.transition(.blurReplace)`; whole toast enters and leaves from the same edge with `spring(response: 0.38, dampingFraction: 0.86)` | `Player/Toast` gets a `Progress` and a `Done + action` variant |
| 9 | **Focused card in a rail** (lucass0x Spotlight, flat version) | 首页 编辑精选 and 我的地盘 rail `210:8239`; 收集册 `204:30158` | `.scrollTargetBehavior(.viewAligned)`; `scrollTransition { c, p in c.scaleEffect(p.isIdentity ? 1 : 0.94).opacity(p.isIdentity ? 1 : 0.7) }`; caption under the rail swaps with `.transition(.blurReplace)` in 200 ms | Show the neighbour cards at 94% and 70% in the home frame |
| 10 | **Floating primary over a fading list** (rehanxahmed CTA) | Already in 活动详情 and 主题详情. Extend to N36 (掷骰), N01 (when a claim is possible nearby) | `.safeAreaInset(edge: .bottom)` with the existing scroll-edge fade | None |
| 11 | **Sheet material over a live surface** (sumitXbravo's single glass bar; `apple-design-materials`) | Property sheets N08 to N12 at the 420 pt detent; 附近 sheet on `210:8322` | System sheet material at partial detents (iOS 26+ default; earlier `.presentationBackground(.regularMaterial)`); plain fills inside; never a second material | Sheet variant "partial detent = material" in `Player/Sheet` |
| 12 | **AI text arrives as a rewrite, not a pop** (Jakubantalik document card) | Editor AI 快速创建 `239:24018` (light theme) | Generated fields change with `.transition(.blurReplace)`, 250 ms, delays `[0, 0.04, 0.07, 0.09]` from the top; `.sensoryFeedback(.success, trigger: generated)` once | One annotation on the frame |
| 13 | **An idle loop on one hero** (rehanxahmed's walker) | The die on N36 `204:34340` while waiting; the puck on the roam "running" state | `TimelineView(.animation(minimumInterval: 1/30))` driving ±3° rotation and 2 pt float, period 3 s; stops on touch; off under Reduce Motion and Low Power | None |

## 3 · Reject, with reasons

| # | Pattern (source) | Why not |
|---|---|---|
| 1 | The **iridescent rainbow wave** with chromatic fringes and specks (Jakubantalik) | Our player theme is dark and neutral; a rainbow is the loudest thing on any screen it touches, and its violet edge breaks "purple only rarely". Text is unreadable for ≈ 0.5 s, which `AUDIT §1` allows only on rare moments. Kept as Adopt 7 in a white, single-pass form. |
| 2 | The **purple flood** as the "revealed" state (sumitXbravo) | Selected and active states are neutral in our rules; purple would become a state colour. The reveal works without it (Adopt 5). |
| 3 | The **warping card** (sumitXbravo) | Squash and stretch on a surface that carries a place name, a level and a price makes text skew. A deed is a document; it should feel rigid. The seal already carries the playful spring. |
| 4 | A **one-second coloured rim** after success (Jakubantalik) | Afterglow on a control used every day becomes noise (`make-interfaces-feel-better #19`). Our end-state cue is the seal or the check. |
| 5 | **3D ring and cylinder carousels** (lucass0x Circular UI Slider, Image Carousel Ring) | Most cards are edge-on or behind the ring, so content is hidden by design; VoiceOver order is undefined; perspective motion is a Reduce Motion trigger with no meaningful fallback; no HIG pattern backs it. Marketing-page furniture. |
| 6 | The **arc carousel** as navigation (lucass0x) | Rotated cards tilt their text; the arc wastes a third of a 393 pt screen. A flat focused rail (Adopt 9) keeps the same hierarchy. |
| 7 | **Hover reveals** (lucass0x Folder and Bookmark cards) | No hover on iPhone. Moving them to long-press would hide content behind a gesture with no visible affordance (`apple-design-interaction`: every gesture needs a visible fallback). The notched silhouettes are fine as artwork; the deed already has its band. |
| 8 | **Auto-advancing carousels** (lucass0x, first seconds) | Content that moves by itself under the thumb; fails "choreography never blocks interaction" and is a Reduce Motion issue. |
| 9 | The **cursor-built screen** as a loading or onboarding idea (rehanxahmed) | It is a ten-second presentation device. In product, content should appear together within one entrance (`choreograph › Hard Rule 1`), with content-shaped skeletons for waits over 1 s. |
| 10 | The **light mint theme and orange lit state** for player pages (rehanxahmed) | Player pages are dark; lit and selected states are neutral. Adopt 6 takes the row, not the colours. |
| 11 | **Bank-card and cash metaphors** in the game (sumitXbravo: card number, CVV, "Add money", `$` amounts) | City Monopoly is 积分 only. A deed that looks like a payment card invites the wrong reading. |
| 12 | A **symmetric 0.9 s hide** (sumitXbravo) | Exits should be shorter than entrances (`motion-animation.md §4.9.2`). We hide in 200 ms. |
| 13 | **Sparkle particles** as anticipation (Jakubantalik) | Decoration that delays the answer by ≈ 400 ms. Our answer to a press is the in-place button change within one frame (`apple-design-interaction`: respond in < 100 ms). |
| 14 | **Per-digit blur rolls on live counters** | Fine on a value that changes once (Adopt 3). On the play HUD timer or distance, which change every second, any transition is noise: use plain tabular digits. |
| 15 | **Wave, stagger or bounce on chips, segments, tabs and list rows** | High-frequency controls get the press dip and the selection haptic, nothing more (`find-animation-opportunities › Gate 1`). |

---

## Method and limits

- **Frames.** The supplied `extract` tool could not decode inside this session's sandbox (AVFoundation error
  −11821 "Cannot Decode"; the system decoder service is not reachable from the sandbox). I decoded with a software
  decoder instead (PyAV in a scratchpad virtual environment), same 0.25 s step, 720 px long side: 52 + 84 + 49 + 48 =
  **233 frames**, all read in order. Frames live in
  `/Users/fanning/chengyin-refs/redesign-backup-1116/review/xrefs-1-frames/` and were not copied anywhere else.
- **Timing.** Measured from the full-rate sources as mean frame-to-frame difference inside a region (the wallet
  card, the payment card, a carousel cell). Durations are good to about ± 20 ms at 60 fps and ± 35 ms at 30 fps.
  Spring `response` and `dampingFraction` values are my estimates from the shape of those curves.
- **Not seen.** No audio was analysed. The lucass0x cells are 540 × 360 px each in the source, so small text there
  is read from layout, not letter by letter. The fifth link (CY160909) has no file and is not covered.
- **Skills.** Used: `apple-design-motion`, `apple-design-materials`, `apple-design-interaction`, `apple-design-os`,
  `choreograph`, `gestures`, `animation-vocabulary`, `find-animation-opportunities`, `improve-animations` (its audit
  rules; no plans written), `make-interfaces-feel-better`, `break-ui` (catalogue only; no toggle built, review
  only). `review-animations` is locked to owner invocation and could not be run from this session; run
  `/review-animations` yourself if you want its verdict format on the City motion code.
- **Our side.** The critique is from still shots dated 2026-11-16 plus a read of motion-related lines on
  `ui/h-code-city` and `App/DesignSystem/CYMotion.swift`. I did not run the app, so statements about how our motion
  feels are limited to what the code lines say. No Figma call was made; frame ids are from `skill-r2.md §3.2` and
  `revise/skill-r2/LOG.md`.
- **Counts.** 4 videos · 233 frames · 9 craft principles · 4 system gaps + 16 screens critiqued · 7 animation
  opportunities (5 rejected candidates) · 13 Adopt · 15 Reject.
