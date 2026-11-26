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
