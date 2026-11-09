# App icon and launch screen spec (e5c)

Status: concepts only. The repo has no asset catalog (`find . -name '*.xcassets'` is empty) and the build setting
`INFOPLIST_KEY_UILaunchScreen_Generation = YES` lives in `Config/Base.xcconfig` (Cursor-owned), so the UI side did not write a
1024 PNG into a catalog. Pick one concept; the UI side can render it with a SwiftUI `ImageRenderer` script on request.

## Constraints (all concepts)
- 1024x1024 opaque PNG, no alpha, no rounded corners (the system masks), single focal mark, no text (the wordmark is too small at 60pt).
- Neutral first: near-black ground and an off-white mark. Violet `#7A5CFF` is reserved for the selected tab, so it is NOT used as the icon accent.
  One warm accent (amber `#F2A33A` or coral `#FF6B4A`) at most, taken from the generated cover-art family.
- Must hold at 60pt, 40pt (Spotlight), and in iOS 18+ dark / tinted variants (mark on transparent for tinted; ground `#000000` for dark).
- Reads as "collecting places", not "map app" and not "gambling".

## Concept A: Seal on a fog map (recommended)
Ground: `#0B0B0C` with a soft radial fog (`#1C1C1E` to `#000000`). Mark: a round passport stamp ring (off-white `#F8F8F8`, 14% stroke, 7 notches)
with a single map-pin notch cut at the top; inside, one amber dot where the pin lands. Ties the fog-of-war roam map to the stamp collectible.
Dark variant: identical. Tinted variant: ring only.

## Concept B: Lantern-gate city window
Ground: deep warm black `#120D0A`. Mark: a stylised lantern gate (two columns + lintel) cut as negative space in an off-white rounded square,
a thin coral `#FF6B4A` glow behind the opening. Echoes the "Lantern Gate" stamp name used in fixtures and the zh wordmark 城瘾 (a gate = 城).
Risk: finer details at 40pt; keep to 3 shapes.

## Concept C: C-ring stamp (monogram)
Ground: `#000000`. Mark: a bold off-white "C" drawn as an open stamp ring (gap at 2 o'clock) with one small filled circle completing the ring (the
"one more place"). Pure geometry, strongest at small sizes, least narrative. Works as the launch mark as well.

## Launch screen
- Background `#000000` (matches the player page, avoids a white flash in dark mode), centered mark from the chosen concept at 96pt, no text, no progress.
- Static only (the system requires it); the welcome screen then animates the same mark into its card stack, so the hand-off feels continuous.
- Needs: asset catalog with `AppIcon` (1024 + dark + tinted), color set `LaunchBackground`, image set `LaunchMark`, and Info.plist `UILaunchScreen` with `UIColorName` / `UIImageName`
  replacing `UILaunchScreen_Generation`. Requested in `docs/release/view-requests.md`.
