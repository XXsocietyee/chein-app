# Wave 3 B2: CYWave + CYTouchRipple + anticipation press

Code-only; not compiled or recorded by the author. The integrator builds and records.

## What is mounted where
| Piece | File | Mounted on |
|---|---|---|
| `cyWave` stitchable distortion shader | `App/DesignSystem/CYWave.metal` | live `HomeTodayCard` |
| `CYWave` constants, `CYPressWaveModel`, `cyPressWave`, `CYTouchRipple`, `CYPressWaveStyle` | `App/DesignSystem/CYWave.swift` | `HomeTodayCard` (`App/HomeFeedView.swift`) only |
| `WaveTodayFixture` | `App/DesignFixtures/WaveFixtures.swift` | DEBUG only |

Files are flat in `App/DesignSystem/` (the project generator globs `*.swift` / `*.metal` with no subfolders), not `Shaders/` or `CYLight/`.

Behaviour on the Today card (live Explore tab):
- Finger down anywhere on the card: scale 0.985 on `CYMotion.press` (120 ms), impactLight.
- Finger up inside a 10 pt slop: impactMedium, card springs 1.02 to 1.0 (`CYMotion.release`), a Metal ring wave ripples out from the finger for 0.8 s (hard stop 0.85 s, amp 10 pt, one active at a time), plus a thin lantern ring and a short bloom at the touch point (lantern is allowed on the press ripple).
- The action (pill target) starts 240 ms after release so the ripple reads before the push. Taps on the pill (`homeFeed.today.action`, identifier unchanged) take the same path; taps elsewhere on the card now also activate it.
- Drag past 10 pt (scrolling) cancels with no wave and no action.
- Reduce Motion (`QuestifyReduceMotion`): dip only (scale 0.985, cross-fade timing), no distortion, no ring, action immediate.
- Low Power / thermal serious: dip and spring, no shader, no ring, action immediate (`CYLightBudget.shadersAllowed`).

Deviation from the spec shader: same stitchable signature, but the wave front travels 520 pt (not 900) so the ring crosses a card-sized area inside the 800 ms; zero-vector guard added.

## Fixtures to record
`xcrun simctl launch 25316F87-058C-46CE-8825-617906638207 invalid.example.questify.ios --design-fixture <name> [--uitesting-reduce-motion]`
- `d2-home` (real finger; tap the Today card both on the pill and off it). Records the acceptance video.
- `wave-today-roam`, `wave-today-ticket`, `wave-today-club`: synthetic finger taps at (280, 70) card-space at 1.0 s and every 2.6 s; no touch injection needed. Add `--uitesting-reduce-motion` for the RM take.

## Expected video beats (0.25x)
t0 down: card dips to 0.985 over about 120 ms. t0+120 up: card overshoots to 1.02 and settles; a ring ripples from the finger across the card, distorting text and art by up to 10 pt, fading out by about 800 ms; thin warm ring and small bloom at the finger. t0+240 `d2-home`: the push begins. RM: dip and return only, nothing distorts.

## Instruments
Target frame time at most 8 ms on `d2-home` during the 850 ms window (one `distortionEffect`, Canvas ring). Not measured here.

## Checks run
`swiftc -parse` on the new/changed Swift files, `tools/generate_project.py`, `tools/check_scaffold.py`, `tools/check_design_lint.py`, `tools/contract_ratchet.py --check`.

## Update: non-shader fallback carries the effect (ui/w2b)
- Metal distortion is now behind `#if CY_METAL_SHADERS` (defined for Debug and Release in `tools/generate_project.py`; behaviour unchanged when defined).
- `CYTouchRipple` is the fallback and also draws over the shader: blurred (6) radial lanternHot 35 % to clear pulse, radius 0 to 280 pt over 600 ms; two 3 pt rings at 40 % fading (second 90 ms behind); 0.04 white card brightness lift (peak 80 ms, gone by 400 ms); dip/spring unchanged.
- Low Power / thermal serious now shows this light pulse (shader still off); Reduce Motion stays dip only, no light, action immediate.
- Re-record `wave-today-roam` (default and RM) to compare against `sheet-wave-today-roam-default.png`.
