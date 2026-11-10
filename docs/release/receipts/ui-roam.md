# Receipt: Roam hero (DES-e2)

Spec: `docs/release/motion-spec-roam.md`. Base merged: `origin/ui/main` (conflicts in Localizable.xcstrings, TicketWalletView.swift, project.pbxproj resolved by union).

## Delivered
- `RoamPhase` enum (idle, starting, walking, paused, finishing, finished, blocked) mapped from `RoamLivePhase`; exhaustive switches in `RoamLiveSessionView.fogEdge` and the fixture GO button. No behaviour change.
- GO: hold ring, 0.90 spring, heavy haptic on touch-down, expanding fading burst, slow breathing ring while walking (`CYGoPressStyle(walking:)`, `CYGoLabel(symbol:)`). Already used by `RoamBrowserView` and `CYGoButton`.
- Fog: `CYFogLayer` (Canvas + one TimelineView, radial reveal mask, trail holes, Reduce Motion = static edge), placed behind the live roam HUD. Toast `CYRevealToast` with count-up percent (em dash when unknown), shown when the tile count grows.
- Nearby sheet kit: `CYRoamNearbySheet` (peek / half / full, spring snap, haptic), `CYRoamNearbyCard` (parallax, selected highlight), `CYRoamPin`. `CYMapScaffold` snap now uses `cyRoamSheetSnap` plus a light haptic.
- DEBUG fixtures: `roam-go`, `roam-walking`, `roam-reveal`, `roam-sheet-half`, `roam-paused` (`App/DesignFixtures/RoamFixtures.swift`).
- Strings (EN + zh-Hans): `docs/release/ui-strings-roam.json`, merged into the catalog. Project regenerated.
- No Core / Tests / Config edits; location and roam logic unchanged.

## Cloud evidence
See commit check-runs (filled in below).

## Not verified
Nothing run on a device or simulator. Fog look at real map scale, 120 Hz canvas cost, haptic feel and VoiceOver paging need a device pass. `CYRoamNearbySheet` and `CYRoamNearbyCard` are in the fixtures only; the real roam list rows are unchanged.
