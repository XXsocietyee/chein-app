# IWP-3 report — Refund quote screen (read-only)

Branch `cloud/iwp-3` (from `origin/cloud/iwp-0`). Cloud builder: **nothing compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked* only.

## Files (all new)
- `Core/BundleRefundQuotePresentation.swift`
- `App/BundleRefundQuoteView.swift`
- `Tests/CoreTests/BNDRefundQuotePresentationTests.swift`
- `docs/owner-plan/iwp-3-new-strings.md`, this report
No existing file touched; nothing wired into AppSession/AppCompositionRoot; no routes, gates, leases, Resources or xcstrings edits.

## Public types
- `BundleRefundRoute` (`originalMethod | platformBalance | notRefundable | unknown(String)`), `init(serverValue:)`.
- `BundleRefundQuotePresentation` (`init(quote: FreeExploreLaunchRefundQuote)`): route, route title/body keys, verbatim `amountText`, `remainingRatioText`, `remainingValueText`, `totalValueText`, `serverReason`, `policyVersion`, `showsAfterSalesPointer`/`afterSalesPointerKey`, `quoteOnlyNoticeKey`, static `tableName` (`BundleRefundQuote`) and `allKeys`.
- `BundleRefundQuoteView(quote:)` (internal SwiftUI `List`; no Button/link/gesture; not mounted). Uses the existing `FreeExploreLaunchRefundQuote` decoded by `FreeExploreLaunchService.refundQuote`; no new request.

## Behaviour
- Unknown route → neutral "contact support" keys. `afterSalesForMerchantBreach == true` → after-sales pointer (shown for any route, not only NOT_REFUNDABLE, so a flagged quote is never silent).
- Amounts/ratio are the server's text; no arithmetic or formatting. "Quote only — no money moves" always shown.

## Tests (`BNDRefundQuotePresentationTests`)
testRouteNotRefundableShowsAfterSalesPointerWhenBreachFlag, testNoApplyButtonExists, testNoClientSideRatioOrAmountComputation, testUnknownRouteFallsBack.

## NOT verified
- Nothing compiled/run. Source-text scans locate files via `#filePath` (3 levels up to repo root) — fails if tests run from a relocated copy.
- The scan token list is crude (e.g. ` - `, ` + `) and could false-positive if the sources are edited; I grepped the two files by hand for the same tokens.
- Tests were written with the implementation; red-first not performed.
- View never rendered; localization table `BundleRefundQuote` does not exist yet (strings in `iwp-3-new-strings.md`), so keys show raw until added. The after-sales destination is not linked.
- Not added to `.xcodeproj`.
