# Native r2 motion r1 (owner 11-26: "mainly the animation effects")

References (owner-shared X posts, studied as frame sheets): route playback map ("did you two almost meet") and a sheet backdrop that blurs progressively instead of a flat black dim. Apple components only; no custom chrome. Respect Reduce Motion (`@Environment(\.accessibilityReduceMotion)`: no draw-on, numbers set instantly, no blur ramp). Everything behind `NativeR2Flags.isEnabled("nativeR2.motion")`.

## M1 Route draw-on + rolling counters (MapKit)
- City orientation finish **replay** and live run, free-explore next-stop path, team trails:
  - `MapPolyline` of the route revealed over time (trim the coordinate array by a progress value driven by `TimelineView(.animation)` or `withAnimation(.smooth(duration: 1.6))`), user/team colour per route, done legs solid, upcoming dashed (`StrokeStyle(dash:)`).
  - Top overlay card (system `.regularMaterial`, `RoundedRectangle` 12 pt): two `LabeledContent`-style columns, time + distance, with `.contentTransition(.numericText())` and `.monospacedDigit()` so they roll as the route draws.
  - Arrival/meeting point: `Annotation` with avatars + an SF Symbol badge using `.symbolEffect(.bounce)` and a pulse ring (`.symbolEffect(.pulse)` on `circle.dashed` or a scaled circle with `.repeatCount(2)`), plus `.sensoryFeedback(.success, trigger:)`.
  - Camera follows the drawing head with `MapCamera` + `withAnimation(.smooth)`; ends on the meeting point.
  - Result in the system bottom sheet: big `.largeTitle.bold()` value ("12 米之内"), one-line `.secondary` sentence, chips as `Label` in `.background(.fill.tertiary, in: Capsule())`.
  - Header: inline title "第 n 段 / 共 m 段" with prev/next toolbar buttons; a list sheet of all legs with distance badges (system tints).
## M2 Sheet backdrop for OUR overlays only
- Punch sheet, game result sheet, story stage result: when presented, the content behind gets a vertical gradient of white 0.92→0.15 (dark: black 0.6→0.1) over a blur that ramps 2→16 pt toward the top (`.blur` on the backing view driven by the sheet detent fraction via `.presentationBackground` + `onGeometryChange`). System sheets elsewhere keep Apple's default dimming.
## M3 Small, everywhere in the native flows
- List row insert/remove: default `List` animations; state chips `.contentTransition(.symbolEffect(.replace))`; scores `.numericText()`; successful punch/stamp: `.symbolEffect(.bounce)` + `.sensoryFeedback(.success)`; errors `.sensoryFeedback(.error)`.

Branch `native-r2/motion-r1` from `ui/combined-r7`. Files under `App/NativeR2/Motion/` plus minimal hooks in the flow files. Gate: `python3 tools/check_scaffold.py` PASS, `python3 -B tools/check_a11y_lint.py` PASS. Receipt `docs/release/receipts/native-r2-motion-r1.md` listing each motion with file:line.

## Owner 11-26 09:05: "All our pop-ups should have this kind of animation, and a design like the Dynamic Island at the top (a top pop-up). We absolutely must have them: invitations, messages, hints in games and stories, or similar videos."

## M4 In-app Island (top pop-up) → branch `native-r2/island-r1`, folder `App/NativeR2/Island/`
- One `IslandCenter` (`@Observable`, `@MainActor`, injected at the app root) and one overlay at the top of the root window, anchored on the safe-area top so on Dynamic Island iPhones it grows **out of the island** (black capsule, continuous corners, 37 pt tall at rest) and on other iPhones drops from under the status bar.
- Morph: compact capsule (icon + one line) → expanded card (avatar/thumbnail, title, subtitle, up to 2 actions) with `.spring(response: 0.42, dampingFraction: 0.78)`, content cross-fades with `.blurReplace` / `.opacity`; tap expands, swipe up dismisses (drag follows the finger, rubber-band), auto-dismiss after 4 s unless interacting; queue several items; `.sensoryFeedback(.impact(weight: .light))` on appear; VoiceOver: posts an announcement and the island is a focusable element with actions; Reduce Motion: fade only.
- Kinds (enum): `.invitation` (team/club/game invite: Accept / Decline), `.message` (IM/club message: avatar, preview, Reply opens the chat), `.hint` (game & story hint ladder: lightbulb icon, hint text, "下一条提示"), `.media` (story audio / video: artwork, title, play/pause, progress ring; tap opens the full player), `.status` (replaces every `.cyToast`: success/warn/error tones as SF Symbols), `.arrival` (orientation punch available / stamp unlocked).
- Wire real sources, no new requests: existing invite/IM/club notification handlers and push foreground presentation (`UNUserNotificationCenter` willPresent → island instead of the system banner while the app is open), game hint ladder (NativeGameShell hint button), story audio player, all 75 `.cyToast` call sites → `IslandCenter.show(.status…)` (keep `cyToast` as a thin shim so nothing breaks).
- **Real Dynamic Island / Live Activity** (ActivityKit, existing `LiveActivityWidget`): compact leading/trailing, minimal and expanded regions for (a) a city-orientation run (elapsed timer `Text(timerInterval:)`, next control point, distance), (b) free-explore next stop, (c) story audio playing. Start/update/end from the existing `QuestLiveActivityCenter`. Same visual language as the in-app island.
- Flag `NativeR2Flags.isEnabled("nativeR2.island")`.

## M5 Every sheet gets the backdrop motion → branch `native-r2/sheets-r1`
- A shared `cySheet(...)` / `cyFullScreenCover(...)` with the exact same signatures as `.sheet(isPresented:)`, `.sheet(item:)`, `.fullScreenCover(...)`, that registers the presentation with a root `PresentationBackdrop` model; the root content then applies the M2 backdrop (white→clear gradient 0.92→0.15 over a 2→16 pt blur ramp, dark-mode variant), animated with the sheet's own spring; sheets keep system detents/grabber. Codemod all 638 `.sheet(` and 22 `.fullScreenCover(` call sites (mechanical, keep arguments). System `.alert` / `.confirmationDialog` stay Apple's. If `native-r2/motion-r1` already has a backdrop helper, reuse it (fetch it first); never two implementations.
- Flag `NativeR2Flags.isEnabled("nativeR2.sheetBackdrop")`.
