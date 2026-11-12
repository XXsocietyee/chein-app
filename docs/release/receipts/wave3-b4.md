# Wave 3 / B4: GO hold, pill to puck, lantern fog edge

Code-only; the integrator compiles and records. Branch `ui/w4`.

## What is mounted where
| Piece | File | Live mount |
|---|---|---|
| `CYGoHoldPill` (72 pt pill, 600 ms hold, 3-segment lantern ring, ticks at 200/400 ms, commit 600 ms) | `App/DesignSystem/CYGoHold.swift` | `RoamLiveSessionView.actionBar` replaces `Button("roam.live.start")`; identifier `roam.live.start` kept, disabled until consent as before |
| `CYGoPuck` (44 pt, bottom-right, halo breathes 2.2 s) | same | actionBar: shown while committing and while `.active` (next to `roam.live.pause`); id `roam.live.puck` |
| `CYGoWave` (lantern Canvas ring, <= 850 ms) | same | overlay on the actionBar, centred on the puck, crosses the map on commit |
| Pill to puck | `matchedGeometryEffect(id: "go")` | actionBar, optimistic: shrinks at commit, returns if `owner.start` does not reach `.active` |
| Lantern fog edge | `App/FogOverlayLayer.swift` (live frontier glow: `warm` is now `CYNight.lantern`, breath 2.2 s); `App/DesignSystem/CYRoamKit.swift` (`CYFogLayer` rim: 2 pt lantern stroke + 14 pt blur copy) | live `RoamFogMapView` and the roam fixtures |

Deviations from the brief: the live edge is drawn in `FogOverlayLayer`, not `RoamFogMapView`, so that file changed instead (`RoamFogMapView.swift` untouched). The wave is a Canvas ring, not the `cyWave` distortion shader: B2 owns that shader and this keeps B4 independent of it.

Fallbacks: Reduce Motion (`QuestifyReduceMotion`) = tap pill, confirmation dialog, no ring, no wave, static fog edge, still puck halo. Low Power/thermal = no wave. VoiceOver activation commits directly (hold is not an accessible gesture). Haptics: impactLight at 200 and 400 ms, impactHeavy at 600 ms.

Strings (EN + zh-Hans): `roam.go.hint.hold`, `roam.go.hint.tap`, `roam.go.confirm.{title,action,cancel}`, `roam.go.puck.a11y`.

## Fixtures to record
`xcrun simctl launch 25316F87-058C-46CE-8825-617906638207 invalid.example.questify.ios --design-fixture <name>`
| Name | Beats |
|---|---|
| `roam-go-demo` | 1.4 s idle; 330 ms scripted hold then release (ring fills ~half and drains, no commit); 1.2 s; full hold: ring segments at 0.2/0.4/0.6 s, pill shrinks into the bottom-right puck, lantern wave crosses the map, fog edge flares; walking 5 s; loops |
| `roam-go` | same, by hand (hold with the pointer; release early to cancel) |
| `roam-walking` | puck bottom-right, fog edge glows lantern and breathes every 2.2 s |
Add `--uitesting-reduce-motion` for the RM takes: `roam-go` tap, confirm, puck; `roam-walking` static edge. `roam-go-demo` under RM commits at ~2.2 s without the dialog.
