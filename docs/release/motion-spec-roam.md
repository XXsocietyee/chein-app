# Motion spec: Roam (hero)

Code: `App/DesignSystem/CYRoamKit.swift`, `CYSignature.swift` (`CYGoPressStyle`), `CYMapChrome.swift` (`CYGoLabel`, `cyRoamSheetSnap`).
Base tokens: `/Users/fanning/chengyin-refs/specs/motion-system.md` and `docs/release/motion-spec.md`. Lab: `--design-fixture roam-go | roam-walking | roam-reveal | roam-sheet-half | roam-paused` (DEBUG; add `--uitesting-reduce-motion` for the fallback).

## Phases
`RoamPhase` is a presentation enum mapped one-to-one from the controller's `RoamLivePhase`; views switch over it exhaustively.

| RoamPhase | from RoamLivePhase | fog edge | GO circle |
|---|---|---|---|
| idle | ready | static, scale 0.82 | "GO", idle breathing ring |
| starting | acquiring, recovering | static, 0.90 | glyph, no loop |
| walking | active | **animated drift**, 1.00 | walking glyph, slow breathing ring (3.2 s) |
| paused | paused | static, 0.94 | resume glyph |
| finishing / finished | finishing / finished | static, 1.08 | flag / check |
| blocked | recoveryRequired, locationDenied, unavailable | static, 0.82 | slashed location |

No controller call, gate or consent changed; the enum only reads `owner.phase`.

## 1. GO press and hold
| Moment | Motion | Haptic |
|---|---|---|
| Touch down (hold) | spring 0.22 / 0.5 to scale 0.90; a ring tightens inward (1.26 to 1.04, 0.18 s ease-out) | `.impactHeavy` (the roam starts) |
| Release | `CYRingPulse` burst: ring expands 1 to 1.9 and fades over 0.6 s ease-out | none (cooldown 120 ms) |
| Walking | slow breathing ring, 3.2 s ease-in-out, scale 1.04 to 1.30, opacity 0.5 to 0.08; the idle ring is switched off | none |
Budget: the walking ring is the single looping decoration on the GO control; the fog drift is a separate layer (see 2).
Reduce Motion: no scale, no tighten, no burst; walking shows a still ring; press dims via the system style.

## 2. Fog of war
Visual language: unexplored = dark cool fog (opacity 0.84) as a soft vignette; explored = clear. Revealed ground is a soft radial hole around the player (radius 0.30 to 0.46 of the short side, widening with the explored share) plus smaller holes along the trail; a 1 pt rim marks the boundary.
- One `Canvas` inside one `TimelineView(.animation(minimumInterval: 1/20))`: the only animated layer. Edge drift is a sine wobble of about 1.2 percent of the short side. Paused outside walking.
- Reveal tick: radius springs to 1.2x (0.35 / 0.7) then settles (0.6 / 0.85).
- Reduce Motion or any non-walking phase: the same frame drawn once, static fog edge; no timeline ticks.
- Hidden from VoiceOver and hit-testing; the explored share stays available as text.

## 3. "New area revealed" toast
Capsule with sparkle, label, and the explored percent. Enter: top move + fade, `entrance` spring (0.35 / 0.80). Hold 2.6 s. Exit: fade, `standard`. Percent counts up from the previous value to the target in 0.6 s ease-out; unknown shows an em dash and does not animate. Reduce Motion: fade only, count jumps to the value. The live view shows it when the accepted tile count grows (display only).
VoiceOver label: "New area revealed, N percent explored" or "... explored share unknown".

## 4. Nearby sheet
Detents: peek (grabber + one line, scaled 84 pt), half (50 percent), full (90 percent). Drag follows the finger; on release the sheet springs (`cyRoamSheetSnap`, 0.42 / 0.82) to the detent nearest the projected end of the flick. `.impactLight` on every detent change. Content stays mounted, hidden at peek. `CYMapScaffold` (the real roam screen's panel) now uses the same spring and haptic instead of `.snappy`.
Cards: scroll-driven (interactive `scrollTransition`): card rises up to 14 pt and from 0.96 scale / 0.5 opacity; the art glyph counter-offsets 10 pt for parallax. Selected card: accent outline and tint, `.selection` haptic, and its pin (`CYRoamPin`) grows to 1.28 with a one-shot ring. Reduce Motion: no parallax, no offset, 0.18 s cross-fades; the detent still changes.
Accessibility: the grabber row is an adjustable element (swipe up / down moves between detents); cards carry the selected trait.

## Budget check (motion-system 1.5)
Roam screen at walking: independent groups = fog drift + GO breathing ring + status dot ping (3, the cap). Toast, sheet snap and pin ring are one-shot and never run with all three plus a fourth loop; the player-dot ping is fixture-only.

## 5. Fog engine presentation stages (spec: roam-fog-engine.md stages 2 and 3, UI only)
Code: `App/DesignSystem/CYFogEngine.swift`. Fixtures `roam-fog-engine`, `roam-fog-unknown`. Switches stay OFF; no location, Core, or Info.plist change. Core types (`FogCellBitmap`, Core `FogCoverageReading`) are not touched, so the view-side stand-ins carry a `CY` prefix.
- `FogMaskRasterizer` (Core, `FogMask`): geohash bitmaps to an 8-bit alpha mask (255 confirmed, 128 pending, 0 hidden), one 3x3 soften pass, max side 512; `FogMaskImages` turns it into a premultiplied-black image for `destinationOut`, rebuilt only on a bitmap, window or level-of-detail change (`FogMaskCache`).
- `FogOverlayLayer`: one Canvas, scrim from the `fogOverlay` style token, soft-edged mask cut-out, hatch over unconfirmed cells (never colour-only), radial wipes from `RevealChoreographer` (over `CYRevealChoreographer`: 150 ms haptic throttle, Reduce Motion 200 ms crossfade); ticks (30 fps) only while wipes are in flight; hidden from VoiceOver; id `roam.fog.layer`. Mounted by `RoamFogMapView` only when `PersonalFogFeature.liveRevealEnabled` is true (false today).
- Fog look (`FogScrimStyle.reveal`): desaturated haze at 0.62 (lighter slate on night maps, darker on day maps), soft noise blobs and a vignette toward the screen edges; explored ground is a feathered union of rounded blobs (`FogFeather`: blur then smoothstep), fully clear inside, with a thin warm glow ring on the confirmed frontier; unconfirmed ground is clear too, outlined by crawling dashes (static under Reduce Motion or Low Power, never a hatch block); `FogPlayerDot` pulses at the fix (a still halo under Reduce Motion). The 0.35 grey `fogOverlay` token stays the candidate default for `FogScrimStyle.token`; the visible-fog values are pending owner confirmation.
- `CYRevealChoreographer`: 480 ms ease-out radial wipe from the fix point, 40 ms stagger, 6 animated max (rest bake at once), haptics >= 150 ms apart (first of the session `.success`, then `.impactLight`), Reduce Motion or Low Power: no wipe, the cells bake and `crossfadeRevision` bumps (host crossfade 200 ms). Injected clock, no timers.
- `CYFogCoverageReading` / `CYFogCoverageBadge`: unknown (any reason) prints an em dash, never 0; pending cells are counted apart as "N unconfirmed".
