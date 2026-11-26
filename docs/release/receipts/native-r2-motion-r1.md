# Receipt: native r2 motion r1

Brief: `docs/briefs/native-r2-motion-r1.md` (design/handoff-r2), M1–M3. Branch `native-r2/motion-r1` from `origin/ui/combined-r7`.

- **Flag:** `NativeR2Flags.motion` = `isEnabled("nativeR2.motion")` (App/NativeR2/Motion/NativeR2Motion.swift:5). With the flag off, every helper passes the view through unchanged and routes appear fully drawn.
- **Reduce Motion:** every helper reads `accessibilityReduceMotion`. With it on, there is no draw-on (progress jumps to 1), numbers are set instantly, there is no blur (the wash stays), and there are no symbol effects. Haptics stay.
- **No compiler in the cloud:** every API below was checked against existing repo usage or the iOS 17 SDK surface. It has not been built yet. The coordinator's `build_sim` is the first real compile.

## Helpers (new, `App/NativeR2/Motion/`)
| Helper | File:line | What |
|---|---|---|
| `NativeR2DrawOn` | NativeR2Motion.swift:13 | `@Observable` 0…1 progress, eased, ~60 fps for 1.6 s. MapContent can't be interpolated by `withAnimation`, so polylines read this value each frame. |
| `NativeR2RoutePath.leg / prefix / legFraction` | NativeR2Motion.swift:47-71 | Trims a leg or a polyline to the drawing head. |
| `NativeR2RoutePath.teamColor` | NativeR2Motion.swift:78 | Team colour from the server `colorIndex`, using system colours. |
| `nativeR2RollingNumber` | NativeR2Motion.swift:86 | `.contentTransition(.numericText(value:))` + `.animation(.smooth, value:)` |
| `nativeR2Bounce(value)` | NativeR2Motion.swift:102 | `.symbolEffect(.bounce, value:)` |
| `nativeR2BounceOnAppear()` | NativeR2Motion.swift:116 | A bounce once when a success symbol is inserted |
| `nativeR2SymbolReplace()` | NativeR2Motion.swift:132 | `.contentTransition(.symbolEffect(.replace))` |
| `NativeR2RouteLeg.walked` | NativeR2RouteReplay.swift:14 | Legs where both control points are done, in route order |
| `NativeR2RouteReplayView` | NativeR2RouteReplay.swift:35 | M1 replay screen (below) |
| `NativeR2Chip` | NativeR2RouteReplay.swift:259 | `Label` on `.fill.tertiary` `Capsule` |
| `NativeR2ArrivalMark` | NativeR2RouteReplay.swift:274 | `flag.checkered.circle.fill` bounce + `circle.dashed` pulse ×2 + `.sensoryFeedback(.success)` |
| `nativeR2SheetBackdrop` / `nativeR2SheetBackdropSource` | NativeR2SheetBackdrop.swift:25 / :71 | M2 backdrop. **The sheets-r1 lane (M5) should reuse this, not fork it.** |

## M1 Route draw-on + rolling counters
- **Finish replay entry:** a "回放路线" row under the route thumbnail (CityOrientationFinishSummaryView.swift:72, :140). It shows only when there is at least one walked leg.
- **Replay view** (NativeR2RouteReplay.swift):
  - Draw-on: dashed preview of upcoming legs, and a solid tinted line trimmed to the head (:134-141).
  - Camera follows the head with `MapCamera` + `withAnimation(.smooth)` (:115) and ends on the finish (:106-109).
  - Top `.regularMaterial` card (12 pt `RoundedRectangle`): time and distance, `.monospacedDigit()` + numericText rolling as legs complete (:161-184).
  - Finish `Annotation` with `NativeR2ArrivalMark` (:147).
  - Inline title "第 n 段 / 共 m 段" (:95). Prev/next toolbar buttons (:187-196).
  - Result bottom sheet (`.height(200)/.medium/.large`, background interaction up to medium):
    - `.largeTitle.bold()` total distance, a `.secondary` sentence and two chips;
    - all legs with distance `.badge` (:200-255, rows at :222); tapping a leg focuses it;
    - "再放一遍" replays.
- **Live run** (CityOrientationRunView.swift):
  - Route segments draw on when the map appears (:44, :100-102, :149). Done legs stay solid and upcoming legs dashed, as before.
  - Team trails draw on with per-team colours (:119-129).
  - Banner distance rolls (:209). Peek metrics roll: distance at :315 and points at :320.
- **Free explore** (NativeFreeExploreMapView.swift): the store path draws on (:38, :120, :133).

## M2 Sheet backdrop (our overlays only)
- Blur `2 + 14 × detent fraction` pt (fraction = the sheet's reported height ÷ the presenter's height via `onGeometryChange`) under a top→bottom wash: light white 0.92→0.15, dark black 0.6→0.1. Animated with `.smooth`.
- City punch sheet: PlayExperienceView.swift:749 (source), :751 (backdrop).
- Story stage result: PlayExperienceView.swift:1268, :1270.
- Game result sheet: NativeGameShell.swift:140, :142 (the hint sheet keeps the system dimming).
- All other sheets are untouched.
- Simplification: SwiftUI has no variable-radius blur. The blur is uniform and its radius ramps with the detent, while the wash makes the top read heaviest.

## M3 Small motion
| Motion | File:line |
|---|---|
| Free-explore pin state symbol replace | NativeFreeExploreMapView.swift:149 |
| Run banner symbol replace + bounce on entering 50 m | CityOrientationRunView.swift:197-198 |
| Punch done bounce | CityOrientationPunchSheet.swift:95 |
| Punch arrival-refused error haptic | CityOrientationPunchSheet.swift:54 |
| Free-explore unlock bounce | NativeFreeExploreArrivalSheet.swift:39 |
| Stamp created bounce | NativeStampCaptureView.swift:131 |
| Story stage result check bounce | NR2StageResultSheet.swift:51 (score already had numericText and success haptic) |

The game kits already had numericText, symbol replace and success/error haptics, so they are unchanged. Lists keep the default `List` insert/remove animations.

## Also fixed
`check_a11y_lint` was failing on the base (9 decorative placeholder images). Each now has `.accessibilityHidden(true)`. In ChoiceKits, the share image is `Image(decorative:scale:)`.

## Not done / notes
- Spec "avatars" in the meeting annotation: the replay is single-player (no peer location history is read), so the mark is the finish flag only. Team avatars stay on the live run map.
- No new requests; Core untouched.

## Gates
- `python3 tools/generate_project.py`: regenerated.
- `python3 tools/check_scaffold.py`: `PASS structural checks`.
- `python3 -B tools/check_a11y_lint.py`: `PASS accessibility lint: 0 new`.
- Strings: `docs/port/strings/native-r2-motion-r1.json` (15 keys) merged into `Resources/Localizable.xcstrings`.
