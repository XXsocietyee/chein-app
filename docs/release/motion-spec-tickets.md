# Motion and haptics spec: ticket holder (E1)

Code: `App/DesignSystem/CYTicketPass.swift` (kit), `App/E1TicketCard.swift` (detail pass), `App/TicketWalletView.swift` (wallet stack), `App/TicketPassPresentView.swift` (present mode). Base tokens and principles: `docs/release/motion-spec.md` (`CYMotion`, `CYHaptics`). Lab: `--design-fixture e1-ticket-holder | e1-ticket-holder-valid | e1-ticket-holder-pending | e1-ticket-holder-used | e1-ticket-holder-expired | e1-ticket-holder-present` (DEBUG), add `--uitesting-reduce-motion` for the fallbacks.

## Intent
The wallet should feel like a pass holder, not a list: cards have weight (stack, shadow), react to the hand (tilt, sheen) and the pass is presented, not just displayed (full-screen, brightness up, code lands with a reveal). Every effect answers a touch or a scroll; nothing loops idle. Honesty rule: no decorative or fake QR; the only code drawn is the approval-gated `VerificationCodeView` payload. Without a code factory, present mode shows the registration number large for staff.

## System
| Layer | Piece | API | Timing | Reduce Motion |
|---|---|---|---|---|
| Shape | notches + perforation holes | `CYTicketPassShape` (even-odd clip, `animatableData` = tear line) | static | same |
| Depth | two sleeves behind the top pass | `.cyPassStack(depth: 2)` | static | same |
| Depth | key + ambient shadow | `.shadow(0.40-0.45, r 14-18, y 8-10)` + `.shadow(0.25, r 3, y 1)` | static | same |
| Scroll | highlight band slides across each pass as the list scrolls | `.cyScrollSheen()` (`visualEffect`, scroll frame) | scroll-driven, no clock | no band |
| Entrance | first screen of passes rises in | `.cyStaggeredAppear(index:gate:)` | `entrance` 0.35 / 0.80, 50 ms apart, max 6, once | appear at once |
| Press | card scale 0.97 | `QuestifyCardButtonStyle` (NavigationLink) | `press` 0.12 / 0.90, `release` 0.25 / 0.70 | dim 0.7 |
| Tilt | hold 140 ms then drag; up to 7 deg on both axes, scale 1.02, specular highlight moves against the tilt | `.cyPassTilt()` (`LongPressGesture.sequenced(DragGesture)`) | follows the finger on `press`, settles on `release` | no tilt, no highlight; hold still ticks |
| Sheen | diagonal silver band sweeps the pass | `.cyFoilSheen(trigger:)` on tap of the detail pass | easeInOut 0.60 s, band 70 % of width at 22 deg | 0.18 s glow in, 0.18 s out |
| Ribbon | corner state ribbon (valid, pending, used, expired, cancelled, unknown) | `CYStatusRibbon(state:text:)` | static | same; becomes a flat chip at AX sizes |
| Zoom | wallet pass to detail | `cyHeroSource(rowIndex)` + `CYOptionalHeroDestination` (iOS 18 `matchedTransitionSource` / `.zoom`) | system (about 0.35 s) | default push |
| Zoom | detail pass to present mode | `cyHeroSource("present")` on the card + `cyHeroDestination` on the `fullScreenCover` | system | default cover |
| Present | screen to full brightness, restored on close, disappear or background | `.cyBrightnessBoost()` | 14 steps over 0.35 s | instant |
| Reveal | code / number tile lands: fade, scale 0.92 to 1, blur 10 to 0, then one sheen sweep | `.cyCodeReveal()` (also on the real QR in `VerificationCodeView`) | `entrance` 0.35 / 0.80, sweep at +0.38 s | 0.18 s fade, no sweep |

## Springs and durations used
| Token | Value | Where |
|---|---|---|
| `CYMotion.press` | 0.12 / 0.90 | tilt follow, card press |
| `CYMotion.release` | 0.25 / 0.70 | tilt settle, card release, grab scale |
| `CYMotion.entrance` | 0.35 / 0.80 | stagger, code reveal |
| sheen sweep | easeInOut 0.60 s | foil band (the one piece longer than 0.35 s: it is decorative light on a tap, interruptible, and skipped under Reduce Motion) |
| brightness ramp | linear 0.35 s (14 x 25 ms) | present mode |
| `CYMotion.reduced` | easeInOut 0.18 s | every Reduce Motion replacement |

## Haptics (`CYHaptics`)
| Case | Trigger |
|---|---|
| `.selection` | tap on the detail pass (sheen) |
| `.impactLight` | pass grabbed (hold registered before tilt) |
| `.impactMedium` | present mode opened |
| `.success` | code / number tile lands (reveal) |
One haptic per user-visible outcome; the 120 ms cooldown in `CYHaptics.play` still applies to imperative calls.

## What Reduce Motion changes (summary)
Gated: tilt, specular highlight, sheen sweep, scroll band, stagger, press scale, zoom transitions, reveal blur/scale, brightness ramp.
Not gated (not motion): stack depth, shadows, ribbon, notches and holes, brightness boost itself (instant), haptics.

## Accessibility
- Ribbon: text + symbol, never colour alone; combined into one VoiceOver element; flat chip at accessibility sizes.
- Detail pass is a container; the title carries `.isHeader`; the card hint explains tap and hold-drag.
- Present mode: 44 pt close button labelled Close; number tile reads as "Ticket number" with the value; the brightness note is spoken; `privacySensitive`.
- Dynamic Type: no fixed font sizes in views (`@ScaledMetric` for glyphs); AX sizes stack the title under the art and hide the code glyph in rows.

## Benchmarks (Mobbin stills; motion itself is not capturable)
- Luma ticket QR sheet (dark backdrop, white code tile, one pill): https://mobbin.com/screens/fd60dbd4-6f2f-43e8-a2a8-dbf6954b3f59
- Fly Delta boarding pass (code on the pass, big seat/zone type, header band): https://mobbin.com/screens/8eddb26c-f76b-4aff-ac16-12e734aa78fe
- Fresha vouchers (dark gradient passes with side notches, stacked): https://mobbin.com/screens/69616e9f-0d13-4ce1-961b-6e5201ec6231
- Trainline tickets (tear line between header and itinerary): https://mobbin.com/screens/57e53ad4-d677-47a4-a8b2-6ad795714605
- X Money card (cards peeking behind the top one, light streaks as material): https://mobbin.com/screens/924e3b0f-d877-45a2-8725-871c0c02addb

## Verification
Cloud build only for this pass (no local simulator run). Stills cannot show motion; judge with the fixtures above on a device recording. With `--uitesting-reduce-motion` the wallet shows no band or stagger, the detail pass does not tilt and the present tile fades in.
