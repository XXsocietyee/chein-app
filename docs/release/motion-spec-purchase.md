# Motion spec: purchase flow (bundle detail, order summary, pay result)

Branch `ui/e4`, hero task "Theme Pass purchase page, specifically the motion design". Extends `docs/release/motion-spec.md` (E1 tokens, `CYMotion` / `CYHaptics`); nothing here invents a new duration or spring.

Code: `App/DesignSystem/CYPurchaseMotion.swift` (kit), `App/BundleDetailView.swift`, `App/BundleOrderSummarySheet.swift`, `App/BundlePayResultView.swift`, `App/BundleOrderStatusView.swift`, `App/BundleRedeemResultView.swift`, `App/DesignFixtures/E4PurchaseFixtures.swift`.

Money-moving writes stay OFF. The detail view still exposes only `onPurchase: (() -> Void)?`; the DEBUG hosts animate the UI states on a timer (`E4PurchaseFixtures.moneyMovingWrites == false`) and never call a checkout client. Pay result is a pure presentation (`BundlePayResultPresentation`) fed by whoever owns the real order write later.

## Flow and the one memorable moment per step
| Step | Motion | Haptic | Reduce Motion |
|---|---|---|---|
| Land on bundle detail | Hero art stretches on pull-down and parallaxes at half speed (`cyHeroParallax`); hero title sits on the art, one visible title (`cyHeroScreen`) | none | static art |
| Read the price | Digits roll when the amount changes (`CYAnimatedPrice`, `contentTransition(.numericText)`) | none | 0.18 s cross-fade |
| Scan what is included | Rows rise in 50 ms apart, first six only, once per screen (`cyStaggeredAppear`) | none | rows present at once |
| Pinned buy bar | Collapsed price pill + one primary CTA. The pill is a button: chevron flips, pill fill lifts, and the order summary sheet rises with detents `[.height(summaryHeight), .large]` and a drag indicator. The compact detent shows name, rows and the pay button; dragging to `.large` reveals the included items (the "expanded summary" is the same sheet, so it reads as one morph) | `.impactLight` on detent snap | pill toggles without rotation; sheet is the system sheet |
| Pay button | 56 pt capsule, scale 0.96 on the press spring, label swaps to a spinner while processing (`CYPayButton`) | `.impactMedium` on touch-down (primary commit) | dim to 0.7 instead of scale |
| Pay result: success | Ring draws on (0.35 s), check strokes in with `Path.trim` (0.4 s, 0.2 s delay), soft bloom behind, restrained confetti (`CYConfettiBurst`, 30 pieces, 1.9 s), title and rows enter with 0.3 to 0.5 s delays | `.success` once the check lands | mark shown complete, no confetti, no delays |
| Pay result: failure | Same ring, an X strokes in, then one short horizontal nudge (spring 0.3 / 0.35). Reason text is the server's, never invented. Primary "try again", tertiary "back to bundle" | `.warning` once | mark shown complete, no nudge |
| Pay result: processing | Ring arc rotates (indeterminate), skeleton rows, honest copy ("waiting for the payment provider") | none | static three-quarter arc |
| Order status (receipt polling) | Banner swaps with the row transition (scale 0.96 + fade in, fade out) | `.success` when the receipt is found | fade only |
| Redeem result | Success and rejected states get the shared result mark above the status chip | existing `.success` | mark shown complete |

## Tokens used (from `CYMotion`)
| Piece | Token |
|---|---|
| Price roll, bar pill state, banner swap | `CYMotion.standard` (spring 0.30 / 0.85) |
| Pay button press / release | `CYMotion.press` / `CYMotion.release` (through `cyPressEffect`) |
| Stagger, entrances | `CYMotion.entrance` (+ 50 ms per row) |
| Result mark ring / stroke | `easeOut 0.35`, `easeInOut 0.40` (within the 0.18 to 0.35 s band plus the 0.2 s stagger between ring and stroke) |
| Failure nudge | spring 0.30 / 0.35, one cycle |
| Any Reduce Motion fallback | `CYMotion.reduced` (0.18 s ease) or instant |

## Components added to the kit (`CYPurchaseMotion.swift`)
| Component | Purpose | A11y |
|---|---|---|
| `CYAnimatedPrice` | numeric text roll, monospaced digits, min scale 0.7, one line | plain text, read as the amount |
| `CYResultMark` | ring + trimmed check / cross / pending arc | hidden (the title carries the meaning) |
| `CYPayButton` | primary pay CTA with amount, press haptic, processing spinner | label "Pay ¥199", value "processing" while busy; disabled while busy |
| `CYBuyBar` | pinned bar: price pill (toggle) + CTA; material background, solid under Reduce Transparency; stacks at accessibility sizes | pill label "Total ¥199, order summary", trait button, `isSelected` while open |

## Screens
- `BundleDetailView`: parallax hero (260 pt, 320 pt at accessibility sizes), `CYAnimatedPrice`, staggered included rows, `CYBuyBar` + summary sheet, `paying` input to mirror an in-flight purchase. API otherwise unchanged (`content`, `onPurchase`).
- `BundleOrderSummarySheet`: name + "N items", bundle price, validity, total (`CYAnimatedPrice`), first compliance line verbatim, `CYPayButton`, included items (staggered, below the fold at the compact detent). Unknown amounts are a dash, never 0.
- `BundlePayResultView`: `.processing | .success | .failed`, player dark, radial glow tinted by state, one visible title (header trait), order number with text selection, one primary pill (+ tertiary on failure).

## Benchmarks (Mobbin, iOS)
- Airbnb price breakdown sheet (rows then bold total; sheet over the dimmed page): https://mobbin.com/screens/ef0e240d-a5d2-465c-bf1c-c34833b1a0c8. Borrowed: row order and the bold total as the last row.
- Venmo "Review and buy" sheet (medium detent over a dimmed amount, one green CTA): https://mobbin.com/screens/5edcefbf-7675-4cc9-938b-6f705cb8858f. Borrowed: compact detent that carries exactly what is needed to decide, CTA inside the sheet.
- Swiggy booking review with pinned "Pay ₹1538" bar and payment pill (dark): https://mobbin.com/screens/04972635-b301-49c0-b49c-d1e86dcf1743. Borrowed: pinned bar = secondary pill + primary pay CTA with the amount in the CTA.
- Wolt store with pinned "View order €1,99" pill over content: https://mobbin.com/screens/fc643297-dc54-45fb-b9c2-e923d19ceef0. Borrowed: tapping the price pill opens the summary.
- Discord bundle detail ("Bundle includes 4 items" + Buy Bundle): https://mobbin.com/screens/cc2965c1-19ef-4abb-855e-f8ece973e052. Borrowed: item count line under the name.
- WHOOP "Payment saved" (dark, thin green ring + check, two lines): https://mobbin.com/screens/4a1a4ed2-f270-4ff2-be08-df45f1674e05 and Fresha "Payment successful" (single stroke check on a glow): https://mobbin.com/screens/cb1ddfe7-d12b-4f9b-b3e3-014e55eafbaa. Borrowed: ring + stroke mark, radial glow, title under the mark.

## Fixtures (DEBUG, `--design-fixture <name>`)
| Name | Shows |
|---|---|
| `e4-purchase` | detail -> pill -> summary sheet -> pay (1.2 s processing) -> success result |
| `e4-purchase-fail` | same flow, failure result with a server-style reason |
| `e4-purchase-summary` | detail with the summary sheet already open (compact detent) |
| `e4-pay-success` / `e4-pay-failed` / `e4-pay-processing` | result page alone, each state |
Add `--uitesting-reduce-motion` to see the fallbacks.

## Verification
Cloud-verified only (no local builds in this lane): `python3 tools/check_scaffold.py` and `python3 tools/check_design_lint.py` before every push, then `gh api repos/liboyang42-cpu/chengyin-app/commits/<sha>/check-runs`. Stills cannot show motion; judge from the fixtures above on a simulator when a build is available.

## Self-score (six ADA lenses, 1 to 10)
Bundle detail 8 (delight: parallax + roll + stagger; interaction: real detents, one primary CTA; inclusivity: stacked bar at AX, labels, Reduce Motion), order summary sheet 8, pay result 8 (checkmark draw, honest failure copy, no fake numbers), order status 7 (banner polish only; data-sparse), redeem result 7 (mark added, otherwise unchanged).
