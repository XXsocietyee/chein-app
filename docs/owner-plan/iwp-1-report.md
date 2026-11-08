# IWP-1 report — Cancel quote/confirm (T-11)

Branch `cloud/iwp-1` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer reached: *source written and desk-checked* only.

## Files (all new; no existing file touched)
- `App/BundleCancelTransport.swift`, `App/BundleCancelCanceler.swift`, `App/BundleCancelView.swift`
- `Tests/AppUnitTests/BNDCancelTransportTests.swift` (`@testable import Questify`, no `QuestifyCore` import)
- `Tests/CoreTests/BNDCancelCancelerTests.swift`
- `docs/owner-plan/iwp-1-new-strings.md`, this report

## Public types
- `BundleCancelTransport: HTTPTransport` (`@MainActor`, internal) — `init(context:underlying:current:writeAllowed:denied:) throws`, `isCurrent`, `retire()`. Allows only `GET …/reservation/{positive id}/cancel-quote?useWaiver=true|false` and `POST …/reservation/{id}/cancel` with body keys exactly `useWaiver` (Bool) + `expectedOutcome` (non-empty, ≤64). Checks: Authorization == session token, exact rebuilt URL string, no body stream, JSON content type, Content-Length, body ≤4096. POST needs `writeAllowed()` before and after the network call (after → `.outcomeUnknown`). 403 retires + calls `denied`. Refusals: GET → `APIError.notConfigured`, POST → `FreeExploreLaunchFailure.disabled`.
- `BundleCancelCanceler: FreeExploreReservationCanceling` (`@MainActor`, internal) — `init(client:policy:)`; `quote`/`cancel`; `confirm(on: FreeExploreCancelModel)` (on `BUNDLE_CANCEL_QUOTE_CHANGED` dismisses and fetches a NEW quote, stops at the confirmation step); `readBack(model:service:registrationID:reservationID:)` (reads `service.order`, calls `resolveAfterReadback`; never POSTs); `quoteChangedPending`.
  Mapping: quote `expectedOutcome` verbatim; a `WAIVED*` quote when the user did not toggle the waiver → `.failed`; success with status `BOOKED` → `.unconfirmed`; business codes → `.rejected` with text; `outcomeUnknown`/transport error/5xx → `.unconfirmed` (no resend); `.disabled`/`.staleSession` → `.unavailable`.
- `BundleCancelView` (SwiftUI, unmounted) renders every `FreeExploreCancelState`; manual waiver toggle only (no EP-16 suggestion).

## Tests
`Tests/AppUnitTests/BNDCancelTransportTests.swift`: testTransportRejectsAnyOtherPathOrMethod, testPostRefusedWhenWriteNotAllowed, testQuoteUsesServerExpectedOutcomeVerbatim, testCancelBodyAlwaysContainsExpectedOutcome, testQuoteChangedForcesReQuoteAndNeverAutoConfirms, testLateCancelledOutcomeShownAsPenaltyNotFree, testUnknownPostOutcomeReadsBackWithoutResend, testGatedFactoryStillUnavailableByDefault, testNoLocalTwelveHourCalculation (regex source scan of the three new App files).
`Tests/CoreTests/BNDCancelCancelerTests.swift`: testQuoteUsesServerExpectedOutcomeVerbatim, testCancelBodyAlwaysContainsExpectedOutcome, testUnknownPostOutcomeReadsBackWithoutResend, testGatedCancelerStillUnavailable.
All eight spec-named tests exist (the three shared names exist in both files: Core half uses the model/client with a double; App half uses the real canceler through the real transport).

## Deviations
1. The spec puts `BNDCancelCancelerTests` in `Tests/CoreTests`, but `BundleCancelCanceler`/`FreeExploreCancelFactory` live in `App/`, which the SwiftPM `QuestifyCore` target cannot see. Tests that need App types are therefore in the AppUnitTests file; the CoreTests file only covers Core types.
2. Strings are inline `W8Text.t` (no catalog edits); see `iwp-1-new-strings.md`.
3. `testNoLocalTwelveHourCalculation` also rejects `Calendar.`, `Date(`, `timeIntervalSince` and 3600/43200 in the new App files.
4. Nothing wired: no route, no AppSession/AppCompositionRoot change, `FreeExploreCancelFactory.makeCanceler` untouched, gates off, `writeAllowed` defaults false.

## NOT verified
- **Nothing compiled, nothing run.** Risks: `catch let error as APIError where error == .unauthorized` ordering after `catch let failure as FreeExploreLaunchFailure`; `@MainActor` closure captures of `var step` in tests; `PlayExperienceSession.token` is internal (tests use the public init only); `W8Text.t` interpolation; `ObservedObject` over `FreeExploreCancelModel` in the view.
- `W8Text.isChinese` is forced to Chinese under XCTest; the late-cancel assertion accepts either language.
- Transport tests assume `URLComponents` keeps `useWaiver=true` byte-identical to the request URL string.
- Red-first was not performed. Not added to the `.xcodeproj`.
