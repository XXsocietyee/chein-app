# IWP-6 report — Merchant stall + reserve window

Branch `cloud/iwp-6` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked* only. Tests were written with the implementation; red-first was not performed.

## Files (all new; no existing file touched)
`Core/BundleReserveWindow.swift`, `Core/BundleOfferClient.swift`, `App/BundleReserveWindowView.swift`, `App/BundleMerchantStallView.swift`, `Tests/CoreTests/BNDReserveWindowTests.swift`, `docs/owner-plan/iwp-6-new-strings.md`, this report.
(Spec lists `Tests/CoreTests` with `import QuestifyCore`; it is a Core test file, so it uses `@testable import QuestifyCore`.)

## Public types
- `BundleReserveWindow` — `maxDays = 14`; `make(validFromMs:validToMs:serverNowMs:deviceNowMs:calendar:)`; `days: [Day{dayStartMs, earliestMs, latestMs}]`, `isEmpty`, `earliestMs`, `latestMs`, `contains(_:)`. Lower bound = max(now+1, validFrom); server `now` wins over device clock; days stop at validTo; max 14 calendar days from the first selectable day. UX clipping only.
- `BundleOfferUnavailableReason` — 8 server enum cases + `.unknown(String)`; `copyKey` (unknown → `reason.generic`); `knownServerValues`.
- `BundleOfferDetail` (Decodable; `unavailableReasons`/`slots` default to `[]`), `protocol BundleOfferClient`, `UnavailableBundleOfferClient` (throws `.disabled`, never returns data).
- Views (not mounted, not wired): `BundleReserveWindowView(window:onChoose:)`, `BundleMerchantStallView(content:onChooseStart:)`. The host passes the chosen `startAt` to the existing `FreeExploreBundleLaunchModel.prepare(unitID:offerID:startAt:)`; that file is untouched. Slot grid shows only when the server returns non-empty `slots`; otherwise the window-constrained picker (only when there are no unavailable reasons).

## Tests (`BNDReserveWindowTests`)
testWindowIsAtMostFourteenDaysAndNeverBeforeNow, testWindowClippedToUnitValidity, testNoSelectableDayWhenExpired, testWindowUsesServerNowNotDeviceClockWhenProvided, testStallRendersEveryReasonEnum (the stall view's reason→copy mapping is tested at the Core level), plus extra testUnavailableOfferClientNeverReturnsData.

## NOT verified
- Nothing compiled or run (Swift unavailable); possible compile risks: `Section` used directly in `BundleReserveWindowView` (assumes Form parent), `Text(_:format:)` in the stall view.
- No real `BundleOfferClient` exists (B-03 BLOCKED-BACKEND); `BundleOfferDetail` shape is from `bundle-backend-spec.md` only, not a live response. `now` for the window is injected by the caller; no server-`now` field is defined in the spec.
- Strings are not in any xcstrings; the `BundleStall` table must be created by the orchestrator (see iwp-6-new-strings.md). Views not rendered/snapshotted; not added to .xcodeproj.
