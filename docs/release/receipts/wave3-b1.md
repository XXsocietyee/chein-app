# Wave 3 B1: tokens, materials, budget (code-only; integrator compiles and records)

Base: `ui/night-base` (CYNight tokens + `CYLightBudget` live in `App/DesignSystem/CYNight.swift`; project generator globs `App/DesignSystem/*.swift|*.metal` flat, so new files use the `CY` prefix instead of a `CYLight/` folder).

## Added
- `CYTilt.swift`: shared `@Observable` tilt source (CMMotionManager 30 Hz, ref-counted `acquire/release`, `.cyTiltHold(_:)`). DEBUG `--uitesting-fake-tilt`: roll triangle-sweeps -0.5 to 0.5 in 3 s and back, pitch +-0.12 slow sine. Stops under Low Power / thermal serious (`CYLightBudget.gyroAllowed`).
- `CYFoil.swift`: `cyFoil(in:active:)` / `cyFoil(cornerRadius:active:)`. Three hue stops (violet/lantern/cyan) + lantern-hot spot + diagonal specular band, screen-blended, clipped to the shape (host is not clipped). Reduce Motion / Low Power: the same layers frozen at top-left, 25 % strength, no gyro.
- `CYNightGlass.swift`: `cyNightGlass(in:)` (glassFill over ultraThinMaterial, 14 %/4 % 1 pt edge, 12 pt shadow at 40 % ink0). Reduce Transparency: solid `ink2`.
- Fixture: "NIGHT LIGHT" section at the top of `kit` (player domain only): 3 foil seals (`kit.nightlight.seal.0-2`), foil pass (`kit.nightlight.pass`), night glass over a lantern glow (`kit.nightlight.glass`).

## Mounted in live screens
`cyFoilSheen(active:trigger:cornerRadius:)` in `CYAlbum.swift` now layers `CYFoil` under its one-shot arrival sweep (RM: static foil highlight replaces the old corner gradient). That one modifier is what the live screens already call, so foil is live on: Passport pass + stamp tiles (`PassportView.swift:240,261`), stamp detail + grid (`RoamStampViews.swift:188,312`), badge wall/detail (`ObjectBadgeViews.swift:222,282`), object cards (`ObjectCardViews.swift:106,202`), album fixtures. Ticket wallet card foil (`CYTicketPass.cyFoilSheen(trigger:)`, `E1TicketCard`) is B6's file and is untouched.

## Videos to record
Default: `--design-fixture kit --uitesting-fake-tilt` (5 s). Reduce Motion: add `--uitesting-reduce-motion`.
`xcrun simctl launch 25316F87-058C-46CE-8825-617906638207 invalid.example.questify.ios --design-fixture kit --uitesting-fake-tilt`
Also useful: `--design-fixture album-stamps --uitesting-fake-tilt`, `--design-fixture ia-passport --uitesting-fake-tilt`.

## Expected beats
- 0 to 3 s: sheen band and hot spot travel left to right across all three seals and the pass; hue wheel shifts with it; at 3 s it returns (ping-pong, no snap).
- RM video: sheen frozen top-left at low strength, nothing moves; glass strip identical.
- Night glass sits over the lantern glow with a visible 1 pt top-lit edge; no gold on chrome (glow is the background light source).
