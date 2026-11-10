# QR scan + success choreography: what was built vs the advisor spec

Source spec: `chengyin-refs/specs/qr-scan.md` (advice). Kit: `App/DesignSystem/CYScan.swift`. Fixtures: `App/DesignFixtures/QRScanFixtures.swift` (`--design-fixture qr-scanning|qr-detected|qr-success|qr-used|qr-expired|qr-offline`). Strings: `docs/release/ui-strings-qr.json` (Localizable, EN + zh-Hans; to be merged by the strings owner).

## Kit pieces
| Piece | Notes |
|---|---|
| `CYScanState` / `CYScanEvent` / `CYScanMachine` | Pure value-type reducer; host view model feeds events from its existing results (network and verification calls unchanged). |
| `CYScanSweep` | TimelineView + Canvas, 1.6 s ping-pong, paused when inactive, absent under Reduce Motion. |
| `CYViewfinder` | 240 pt (200 at accessibility sizes) frame, corner brackets, failure flash (danger, 120 in / 240 out) + 7 pt spring nudge. |
| `CYScanMark` | pending arc, success ring + check strokes + bloom, failure cross. Reduce Motion: drawn complete. |
| `CYOrbitDots` | 3 dots, 0.6 s, radius/spread parameters so it also fits the club medal. |
| `CYCountUp` | `Animatable` value, 0.6 s ease-out, lands on exactly `to`, two `.selection` ticks. |
| `CYScanResultCard` | Sequencer: pending arc held >= 700 ms, then +0 mark, +200 dots, +300 title, +400 count, +1200 CTA. Announces via `AccessibilityNotification`. |
| `CYScanFailureBanner` | EN/zh copy per failure kind, CTAs per spec table. |
| `CYScanStage` | Viewfinder <-> card with a shared `matchedGeometryEffect("code")`; cross-fade only under Reduce Motion; detect/failure/start haptics. |

## Wiring
- `VerificationCodeView` (ticket present / city voucher): one 1.4 s reveal sweep over a freshly presented code.
- `RoamStampCameraView`: on `.created`, `CYScanMark` + `CYOrbitDots` + VoiceOver announcement.
- `ClubMemberWelcomeSheet` (join success): orbit dots around the medal.

## Changes vs the spec, and why
1. **No camera scanner was added.** The app has no `AVCaptureMetadataOutput` QR scanner today (the stamp camera is a photo capture, `VerificationCodeView` only *presents* a code, and club join is link/code driven). Adding one needs Core verify plumbing and an Info.plist/permission review, outside the UI-owned scope. `CYScanStage` takes the preview as a slot so the scanner can drop in later; the machine already models its events.
2. **`CYResultMark`, `CYAnimatedPrice`, `cyCodeReveal`, `CYTicketPass`, `TicketPassPresentView` do not exist on this base** (the purchase motion kit lives on `ui/e4` and is not merged into `ui/main`). `CYScanMark`/`CYCountUp` are self-contained with the same timings, so there is no cross-branch dependency; fold them into the purchase kit when e4 lands.
3. **State carries no `Date`s.** `verifying(startedAt:)` and `cooldown(until:)` became payload-free cases so the state stays `Equatable` and deterministic; timing lives in the host (`detectSettled` +120 ms, `failureSettled` +600 ms, `cooldownElapsed` +1.2 s, `verifyTimeout` 8 s).
4. **Extra events** (`detectSettled`, `failureSettled`, `verifyTimeout`) replace the spec's "(auto)" rows so every transition is an explicit, testable event.
5. **Min verifying time** is enforced visually inside the card (700 ms of pending arc), not in the network layer, so the request is never delayed.
6. **CoreHaptics pattern, sound and `CYScanQueue`** (offline stamp queue) are not built: no engine/sound assets, and the queue is a Core concern. The machine already yields `success(.queued)` for offline stamps and the copy keys exist.
7. **Reveal sweep on the presented QR** is thin (2 pt) and runs 1.4 s only, so staff scanners are not blocked for long; it is skipped under Reduce Motion.
8. Count-up uses `Animatable` only; `.numericText` is dropped because the interpolated value already rolls the digits.

## Accessibility
Reduce Motion: no sweep (brackets breathe in opacity), no morph, no dots, mark drawn complete, one swap for the count, haptics kept. VoiceOver: camera preview hidden, result announced once and focus moved to the title, failure banner is a header + buttons. Dynamic Type: viewfinder shrinks to 200 pt at accessibility sizes, copy sits below it, counter scales down to 0.7.
