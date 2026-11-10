# UI-CLOUD-04 design report

NOT COMPILED locally (no Swift toolchain on this machine). Presentation only. Player surfaces stay dark through `themeDomain(.player)` and `cyPalette`. `BundleReserveWindowView` does not force a scheme: its only host is the merchant stall form, so it inherits that screen.

## Benchmarks

Mobbin search was not available in this environment. Patterns taken from the coordinator brief:

- Insight Timer pinned primary: one solid pill, everything else secondary (`CYPillButton` primary once per state).
- Meetup date row: the reserve window keeps the system date picker and a single Continue.
- Luma action hierarchy: recover/check is primary; retry/submit-again is secondary and only when the model already allows it.
- Eventbrite photo card: reservation rows use generated `CYCoverArt` plus a kit list row, because the server row has no photo URL.

## Screens

| File | Mini-program / pattern | Theme | What changed | New copy |
|---|---|---|---|---|
| `App/BundleRenewalIntentView.swift` | Intent-only renewal form. Same three choices, note cap, submit / recover / retry gates. | Dark player | Hero title (`renewal.title`) via `CYHeroHeader` + `cyHeroScreen`. Choice rows, one primary pill, skeleton while busy, illustrated empty/error. | none (existing `BundleCommerce` keys) |
| `App/BundleReservationsView.swift` | Server-ordered reservation list. No cancel or reserve control. | Dark player | Hero, 16pt gutters, cover + `CYListRow`, id stays selectable. Blank status or time is an em dash; a real value including `0` stays. Unknown server status stays the server string, never a dotted key. | `cloud04.reservations.title` |
| `App/BundleReserveWindowView.swift` | Stall time clip. Still a `Section` for the parent form. Same `onChoose` guards. | Inherits host | One title (`window.header`). Continue is the only primary. Empty window keeps `bundleStall.noWindow`. | none |
| `App/BundleReviewComposeView.swift` | IWP-8a compose. Same states, rating 1...5, 500-character cap, same `W8Text` pairs. | Dark player | Hero, scaled editor (no fixed text height), one primary. Count starts at `0/500`. | `cloud04.review.title`, `cloud04.review.body`, `cloud04.review.loading` |
| `App/BundleTransferClaimView.swift` | IWP-8c claim. Code cleared before `claim` and on disappear. One rejection message. | Dark player | Hero, field, one primary, skeleton while claiming. | `cloud04.claim.title` |

New copy is rendered with `ChannelCopy` / `W8Text` (English and zh-Hans). The views do not display the `cloud04.*` keys, so a catalog miss cannot show a raw dotted key. Existing string keys are unchanged.

Skipped: none of the five names contain Merchant, Coupon, Ledger, or Settlement. `App/BundleMerchantStallView.swift` was not edited. No fixture file: every screen except the window needs a live model, and the window is already hosted by the stall. No `project.pbxproj` edit.

## Scores (1-10)

| Screen | Delight | Interaction | Inclusivity | Visuals | Innovation | Social impact |
|---|---|---|---|---|---|---|
| Renewal intent | 8 | 9 | 9 | 8 | 8 | 9 |
| Reservations | 8 | 8 | 9 | 8 | 8 | 9 |
| Reserve window | 8 | 9 | 9 | 8 | 8 | 9 |
| Review compose | 8 | 9 | 9 | 8 | 8 | 9 |
| Transfer claim | 8 | 9 | 9 | 8 | 8 | 9 |

Haptics use `CYHaptics` on the primary commit and on confirmed success. Motion uses `cyAnimation` (cross-fade when Reduce Motion is on). Choice rows already gate their symbol effect. No payout, withdrawal, or virtual-goods path was added.
