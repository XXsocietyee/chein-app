# IWP-8c report — Transfer (T-15 / EP-BND-24)

Branch `cloud/iwp-8c` (from `origin/cloud/iwp-0`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer: *source written and desk-checked* only. Tests were written with the implementation; red-first was not performed.

## Files (all new; IWP-0 files, hot files, Resources untouched)
`Core/BundleTransferModel.swift`, `Core/BundleTransferClient.swift`, `Core/BundleTransferPendingStore.swift`, `App/BundleTransferSendView.swift`, `App/BundleTransferClaimView.swift`, `App/BundleTransferTransport.swift`, `Tests/CoreTests/BNDTransferModelTests.swift`, `docs/owner-plan/iwp-8c-new-strings.md`, this report.
(Spec lists the Model/Client/PendingStore/Views/Transport/test; contracts live in the Model file because the WP allows no separate contracts file.)

## Public types
- `BundleTransferServing` (@MainActor protocol: preview, send, receipt, transfers, revoke, claim) with default `BundleTransferUnavailableClient` (every call throws `.disabled`, never returns data).
- `BundleTransferHTTPClient` (real client over `HTTPTransport`; same envelope rules as `BundleAPIClient`; writes disabled unless `writeAllowed()`; write transport error/5xx/odd 200 = `.outcomeUnknown`; business 409 LOGIN_REQUIRED stays a `.response`, not 401).
- `BundleTransferOneTimeCode` (redacted description/debug/mirror, not Codable/Equatable), `BundleTransferSendCommand`, `BundleTransferClaimCommand`, `BundleTransferChannel`, `BundleTransferState`/`BundleTransferDisplayState` (sent/pending/claimed/expired/revoked/unknown), `BundleTransferRecord`, `BundleTransferPreview`, `BundleTransferSendResult`, `BundleTransferClaimResult`, `BundleTransferReceipt`, `BundleTransferBusinessCode`.
- `BundleTransferPendingOperation`, `BundleTransferPendingStore` (owner-bound; stores kind, order id, channel, idempotency key ONLY: no code, no phone, no hash of either).
- `BundleTransferSendModel`, `BundleTransferClaimModel`, `BundleTransferPayerRefundQuoteModel`.
- App: `BundleTransferTransport` (exact method+URL allow-list, token match, 4 KiB body cap, Content-Length, persisted-key match for send/claim, post-call re-check, 403/LOGIN_REQUIRED calls `denied`; `permitsWrites` defaults false; no approval/lease created), `BundleTransferSendView`, `BundleTransferClaimView` (unmounted).

## Tests (`BNDTransferModelTests`)
Required: testCodeNeverWrittenToStorageOrLogs, testClaimErrorsAreIndistinguishable, testTransferUnavailableWhenAnyUnitUsedPerServerEligibility, testPayerStillSeesRefundQuoteAfterTransferIsServerDriven, testNoReuseOfInviteOrCouponTypes.
Extra: testPendingSendRecordHoldsNoCodeOrPhoneAndUnknownOutcomeReadsBackBySameKey, testSMSOnlyWhenServerAdvertisesAndLoginLossKeepsPending, testHTTPClientRefusesWritesByDefaultAndSendsExactBodyWhenAllowed, testSendCommandRejectsBadPhoneAndKey.
Placed in `Tests/CoreTests` (spec file list); it reuses `BNDTransport` from `BNDAPIClientTests.swift`. Fixtures are inline strings.

## Could NOT verify / assumptions
- **Nothing compiled or run.** Risks: `Mirror(self, children: [:])`, implicit-member resolution on `BundleTransferPendingOperation.send/claim` static funcs vs `Kind` cases, `ObservableObject` with only Foundation (same as `FreeExploreCancelModel`), SwiftUI modifiers (`textInputAutocapitalization`, `confirmationDialog` on Form).
- **Backend EP-BND-24 absent.** Paths/shapes come from `bundle-backend-spec.md` B-24 only; `transfer/receipt` and `GET transfer` response shapes are guesses.
- **Preview route `GET transfer/preview` is not in the backend spec** (spec asks for a server impact preview). Owner/backend question: add it to B-24 or tell me which field carries eligibility/impact/offered channels.
- A claim whose outcome is unknown has no receipt endpoint in B-24; recovery is "user re-enters the code, same key is reused" (server replay returns the same result). Needs backend confirmation.
- Receiver-side states (pending/expired for the receiver before claiming) cannot be shown: the spec gives the claimer only one generic error.
- Source-scan tests assume the repo layout (`#filePath` three levels up) and skip trailing-comment text.
- Not added to `.xcodeproj`; no AppUnitTests added; view layout never rendered.
