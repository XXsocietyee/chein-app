# Wave 3 B6: ticket pass, sheet-from-card, foil, verified edge glow and tear

Code-only receipt (no Xcode build or simulator run in this brief; the integrator compiles and records the videos).
Spec: `chengyin-refs/specs/design-wave3.md` section 3.2 (CYEdgeGlow), recipe 2, choreography D, brief B6.

## What is mounted where

| Piece | File | Mounted in |
|---|---|---|
| `CYEdgeGlow` + `.cyEdgeGlow(trigger:)` (comet sweep 0-450 ms, ring fades 450-900 ms, haptics 0/130/260 ms) | `App/DesignSystem/CYEdgeGlow.swift` | `TicketPassSheet` root (live Passport > tickets sheet), `TicketPassPresentView` root (full-screen present cover, hugs the display corners) |
| `CYPassFromCard` (card grows into the pass; drag down > 120 pt or backdrop tap returns it along the same path; one progress value drives scale, offset and clip rect) | `App/DesignSystem/CYPassFromCard.swift` | `ui-pass-card` fixture (wallet `E1TicketCard` -> `TicketPassCard`) |
| `CYPassFlip`, `CYPassTear`, `CYPassVerifiedFace`, `cyPassFoilEdge` | `App/DesignSystem/CYPassVerified.swift` | `TicketPassCard` (live in `TicketPassSheet`), `E1TicketCard` foil edge |
| Verified choreography (tile dims 60 %, flip 300-800 ms, tear 800 ms, stub drop 1700 ms) | `App/TicketPassSheet.swift` `TicketPassCard.runVerified()` | fires when the ticket status changes to `.verified` while the card is on screen |
| Pass entrance (scale .94, rise 28 pt, foil sheen at 450 ms) and live tilt | `TicketPassCard` | live sheet |
| Ink ground (`ink0`, not pure black), checked-in line + dim + glow on status flip | `App/TicketPassPresentView.swift` | live present cover |
| Foil edge (foilA/B/C stroke, 9 s drift) on ready passes, one sheen at 500 ms | `App/E1TicketCard.swift` | wallet detail header (live) |

Behaviour notes
- `TicketPassSheet.load()` no longer swaps a loaded pass for the skeleton on refresh (`if phase.value == nil`), so the card
  survives the refresh that delivers "verified" and the flip can animate.
- `VerificationCodeView` is unchanged: its readback (`registrationStatus == 2`) means "active", and Core documents that
  a readback never claims a completed scan. The glow is therefore driven only by the ticket's `.verified` status, never by readback.
- The glow lives at the sheet root. A sheet is inset from the display, so on a real device in the sheet the ring follows the
  sheet; in the fixtures and in the full-screen present cover it hugs the display corners (radius 55 on Face ID phones, 0 otherwise).
- Foil here uses the existing `cyFoilSheen` and the new foil-edge stroke; swapping to B1's gyro `CYFoil` is a one-line change once B1 merges.
- Live host: the Passport tab opens the pass from the `passport.action.tickets` action through `AccountView`'s `.sheet`.
  `CYPassFromCard` is ready to replace that sheet (wrap the action's card as `card`, `TicketPassCard` as `pass`); AccountView is outside B6's file list, so that swap is left for the integrator.
- Reduce Motion (`QuestifyReduceMotion`): glow = ring fades in/out, single success haptic, no sweep; host = 0.2 s crossfade, no travel;
  verified = faces crossfade, no flip, no tear; foil edge static. Low Power / thermal: comet kept, blur copies off, foil edge static.
  Reduce Transparency: solid 2 pt ring.
- Unknown values stay an em dash. Copy through `CoreLoopCopy.t` (EN + zh-Hans).

## Fixtures to record (simulator `25316F87-058C-46CE-8825-617906638207`)

```
xcrun simctl launch 25316F87-058C-46CE-8825-617906638207 invalid.example.questify.ios --design-fixture ui-pass-card
xcrun simctl launch 25316F87-058C-46CE-8825-617906638207 invalid.example.questify.ios --design-fixture ui-pass-card-verify
# reduce motion: append  --uitesting-reduce-motion
# unchanged sheet-direct lab (old ui-pass-card): --design-fixture ui-pass-card-sheet  (also -pending -used -expired -empty -error)
```

## Expected beats

`ui-pass-card` (autoplays): 0.9 s the pass grows out of the wallet card (about 0.5 s spring, card dissolves in the first third,
backdrop ink0 to 70 %); rests 3.3 s; returns along the same path. Tap the card to reopen, drag the pass down past 120 pt to return.
RM: crossfade only.

`ui-pass-card-verify` (ms after the 1.5 s flip): 0 tile dims to 60 %, green comet sweeps the display edge once (450), ring fades by 900;
120 and 260 haptics; 300-800 pass flips to the green "You're in / Have fun." face; 800 perforation tears (3 pt gap, 24 pt slide, impactLight);
1700-2200 the stub drops away downward. RM: ring fades, crossfade to the green face, no flip, no tear.
