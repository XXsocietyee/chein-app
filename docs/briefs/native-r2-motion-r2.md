# Native r2 motion r2 — owner's 20 X references (11-26 11:30 UTC)

Owner keeps sending motion references; these moments are approved as the "delight" layer on top of the Apple-native base.
Rules: only at a moment of meaning (reward, arrival, success, first-run), never on plain lists; system springs; every one has a
Reduce Motion version (fade or static) and works with VoiceOver (announcement + label). Behind `NativeR2Flags.isEnabled("nativeR2.motion2")`.
Files under `App/NativeR2/Motion/` + minimal hooks; merge the tip first (9 design-P1 lanes just landed in the same flows).

| # | Reference (author) | What it does | Chengyin moment | Build with |
|---|---|---|---|---|
| R1 | Orbee passport (@AdityaKalsaria) | Stamp lands on the passport page with an ink press; the country's contour map is drawn on the page | Free-explore stamp capture → stamp album page: stamp presses in, district/city outline draws under it | `.scaleEffect` press spring + `.sensoryFeedback(.impact)`; outline = MapKit snapshot or MKPolygon path trimmed |
| R2 | Spin to reveal reward (@suriadesign) | Spin a blob, it reveals a holographic card that tilts with the phone | Badge / reward / rare-stamp unlock | Card with `rotation3DEffect` from CoreMotion attitude (clamped ±12°), sheen via a moving `LinearGradient` mask; Reduce Motion = static |
| R3 | Scratch-to-win (@0lgaKo) | Scratch three tiles to reveal a prize | Scratch-card game kit (G-004) and chance rewards | `Canvas` mask erased by `DragGesture`, `.sensoryFeedback(.selection)` per tile, auto-complete at 60% |
| R4 | Snow globe + App Clip gift (@AlexWeichart) | Shake the globe; send it as a gift that opens without installing the app | Ball-shake kit; gifting a postcard/stamp; **App Clip for team invites and venue check-in (QR at a stop)** | CoreMotion shake → particle settle (SpriteKit-free: `TimelineView` + `Canvas`); App Clip = separate target (plan only, owner decision) |
| R5 | Animated tab icons (@MiruDaws) | Tab icon animates when selected | 5 root tabs | `.symbolEffect(.bounce, value: selection)` on tab symbols |
| R6 | Gift box with stickers (@joshm via @60fpsdesign) | Box wobbles, stickers appear on it | Team/club gift, passport gift | `.symbolEffect(.wiggle)` / keyframe animator |
| R7 | Resizing sheet (@_Kavsoft) | One sheet resizes between steps (welcome → notifications) | Permission priming (location, notifications, camera) and onboarding | One `.cySheet` with `presentationDetents` switched by step + `.contentTransition(.opacity)` |
| R8 | Edge glow (@sucodeee via @insporadesign; @Jakubantalik waves) | The screen edge glows in a colour on success | Punch success, payment success, finish line | Overlay `RoundedRectangle` stroke with blurred gradient along the display corner radius, 0.8 s; Reduce Motion = none |
| R9 | Payment → pill (@ktiays) | Sheet confirms, then collapses into a top pill "Sent ✓" | Pay / register / send invite done → collapses into the top island | `matchedGeometryEffect` from sheet card to `IslandCenter` `.status` |
| R10 | Onboarding checklist (@dev_ya) | Checklist with progress ring; done items collapse | New-player checklist: play a story chapter, punch a control point, collect a stamp, join a club | `List` + `Gauge(.accessoryCircular)` + row insert/remove animations |
| R11 | Gradients with feelings (@alyx_so) | Huge number over a mood gradient per metric | Finish summary / monthly recap / passport stats | `MeshGradient` (iOS 18, fallback LinearGradient) + `.numericText` |
| R12 | Calorie flame (@Anuar_DesignX) | Fill rises with the number | Run intensity / distance progress | `Canvas` fill level + `.numericText` |
| R13 | Tilt to rotate (@monoradio102) | Image turns with phone tilt | Stamp and badge detail | CoreMotion attitude → `rotation3DEffect` (same helper as R2) |
| R14 | Travel leaderboard (@nicoledevs Bintu) | Friends ranked by places visited | Club / friends leaderboard on passport | `List` with rank change `.numericText` + row move animation |
| R15 | Tap–ripple–reveal, magazine stack (@sumitXbravo) | Tap sends a ripple that reveals; covers fan in a stack | Story chapter covers carousel; unlocking the next chapter | `ScrollView` + `.scrollTransition` rotation/scale; ripple = expanding `Circle` mask |
| R16 | Quick capture menu (@rybinandy) | Bottom bar expands into a capture menu | Punch sheet: camera / scan / album / note | `Menu`-like expanding panel with `.transition(.move+opacity)` |
| R17 | Clean list load (@nikkbadlani) | Content fades in from skeleton, chart draws | All list loads | `.redacted(.placeholder)` → content with `.transition(.opacity)`; Swift Charts `.chartXScale` animation |
| R18 | Cocktail paywall (@aliicorak) | Plan icon morphs as the plan changes | Membership / pass purchase screen | `.contentTransition(.symbolEffect(.replace))` on the plan symbol |
