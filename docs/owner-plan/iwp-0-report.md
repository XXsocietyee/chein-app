# IWP-0 report — Bundle contracts + API client

Branch `cloud/iwp-0` (from `origin/wip/port-loc`). Cloud builder: **nothing was compiled or run** (no Swift toolchain). Evidence layer reached: *source written and desk-checked* only.

Files created (all new, no existing file touched): `Core/BundleContracts.swift`, `Core/BundleAPIClient.swift`, `Tests/CoreTests/BNDContractsDecodingTests.swift`, `Tests/CoreTests/BNDAPIClientTests.swift`, this report, `iwp-0-new-strings.md` (no strings).

## Public types — `Core/BundleContracts.swift`
All `Decodable, Equatable`. **Initialisers are the synthesised `init(from:)` only; there are no public memberwise inits** (tests/other WPs build values by decoding JSON, or via `@testable`). Ids are `FreeExploreLaunchID`, money/ratios `FreeExploreLaunchDecimal`.

- `BundleTimestamp { raw: String; epochMs: Int64? }` — decodes string / integer / double; parsed with `MoneyParityTime.timestamp` (bare strings = Asia/Shanghai). Unparseable → `epochMs == nil`, `raw` kept.
- `BundleStatusCatalog` — `knownUnitStatuses`, `knownReservationStatuses`, `knownCancelOutcomes` (`Set<String>`).
- `BundlePolicy { version, freeCancelHours: Int, partialRefundMinRatio: Decimal, monthlyVoluntaryWaivers: Int }`
- `BundleUnit { id, grantId, registrationId, holderMemberId, chapterId, unitSeq: Int, unitCode, unitValue, status: String, redemptionId?, reservationId?, statusReason?, version: Int, grantNo: Int, validFrom, validTo: BundleTimestamp; isKnown: Bool }`
- `BundleBalance { grantId, chapterId, grantNo, grantType, unitsTotal, counts: [String: Int], validFrom, validTo, expired }`
- `BundleExitCase { id, unitId, registrationId, holderMemberId, exitedOfferId, reservationId?, decision: String, targetOfferId?, idempotencyKey, requestFingerprint }`
- `BundleRefundHold { registrationId?, refundId?: String, refundNo?, cashAmount?, state: String, version?: Int }` (parked branch; shape unverified)
- `BundleFulfilledMerchant { merchantId, registrationId, holderMemberId }` (parked)
- `BundleOrderHeader { id, registrationId, holderMemberId, topicId, activityId?, productVersion, quotaVersion, policyVersion, contractVersion, settlementRuleVersion, paidAmount, validFrom, validTo, idempotencyKey }` (`snapshotJson` deliberately not decoded)
- `BundleOrderView { registrationId, registrationNo?, parentOrderNo?, paymentStatus?, registrationStatus?, bundle: Bundle? }`, nested `Bundle { order: BundleOrderHeader, balances, units, reservations: [FreeExploreLaunchReservation], exitCases, policy, refundHold?, fulfilledMerchants? }`
- `BundleOrderReceipt { requestId, receipt: Kind(.found | .notFound), order: BundleOrderView?, outcome: String?; provesNoWrite: Bool /* always false */ }` — unknown `receipt` value fails decoding (fail closed).
- `BundleCancelQuote { reservationId, registrationId, holderMemberId, version, status, asOf: BundleTimestamp, useWaiver, outcome, expectedOutcome, canCancel, waiverMonth? }`
- `BundleExitOptions { registrationId, unitId, holderMemberId, merchantExited, targets: [Target{offerId, merchantName?, validEnd: BundleTimestamp?}], refundSubmissionAvailable }`

## Public API — `Core/BundleAPIClient.swift`
- `BundleExitDecision: String, Codable` — `.swapConsented = "SWAP_CONSENTED"`, `.refundUnfulfilled = "REFUND_UNFULFILLED"`
- `BundleExitDecisionCommand: Encodable, Equatable` — `init(unitId:decision:targetOfferId:idempotencyKey:) throws` (swap needs target, refund forbids one; key 1–64 of `[A-Za-z0-9_-]`; else `.invalid`)
- `@MainActor BundleAPIClient`
  - `init(session: FreeExploreLaunchSession, authorization: String, transport: any HTTPTransport, currentSession: @escaping () -> FreeExploreLaunchSession?, writeAllowed: @escaping () -> Bool = { false }, onUnauthorized: @escaping (FreeExploreLaunchSession) -> Void = { _ in }) throws`
  - `session`, `isCurrent`, `permitsWrites`
  - reads: `orderReceipt(requestId:) -> BundleOrderReceipt`, `cancelQuote(reservationID:useWaiver:) -> BundleCancelQuote`, `exitOptions(registrationID:unitID:) -> BundleExitOptions`
  - writes (throw `.disabled` unless `writeAllowed()`): `cancel(reservationID:useWaiver:expectedOutcome:) -> FreeExploreLaunchReservation`, `exitDecision(_:) -> BundleExitCase`
- Behaviour: URLs `…/api/free-explore/bundle/{order/receipt | reservation/{id}/cancel-quote | exit-options | reservation/{id}/cancel | exit-decision}`; 1 MiB cap; `Cache-Control: no-store`; envelope `code==200`; HTTP 401 or envelope 401 → `onUnauthorized` + `APIError.unauthorized`; business 409 `LOGIN_REQUIRED` → `.response(status:200, code:409, businessCode:"LOGIN_REQUIRED")` (no callback). Responses are checked to echo the requested ids and the session's account. Write transport error / 5xx / unparseable / oversize / session or permission change in flight → `.outcomeUnknown` (caller reads back with the same key). `cancel` requires a non-empty `expectedOutcome` (`[A-Za-z0-9_:-]`, ≤64).

## Deviations from the spec text (please review)
1. **`authorization: String` parameter.** `FreeExploreLaunchSession.credential` is `fileprivate` in a protected file, so a new file cannot read the token. The caller (IWP-1's allow-listing transport / IWP-9 composition, which already hold `context.session.token`) passes the captured token. "Never sends without authorization match" is implemented as: non-header-safe token cannot construct the client; request only if `currentSession() == session`; re-checked after the network call. The *token-equals-captured-token* check is the App transport's job (same as `FreeExploreBundleReservationTransport`).
2. **Fixtures are Swift string literals inside the test files**, not `Tests/Fixtures/*.json`: the WP file list is the four files only, and `Package.swift` declares no resources for `Tests/CoreTests`.
3. Extra fields decoded beyond the spec list: `BundleCancelQuote.registrationId/holderMemberId`, `BundleOrderHeader` version strings; `BundleCancelQuote.waiverMonth` is optional (not proven always present). Reservations reuse `FreeExploreLaunchReservation` (no `closedAt`/`version`).
4. Extra tests beyond the ten required: `testDecodesExitOptions`, `testReadsUseGETWithExactPathQueryAndHeaders`, `testWriteSendsExactBodyWhenAllowedAndRequiresExpectedOutcome`, `testWriteTransportErrorIsOutcomeUnknownNotFailure`, `testResponseForAnotherReservationOrHolderIsMalformed`, `testReceiptValidatesEchoAndOwner`.

## Required tests (names)
`BNDContractsDecodingTests`: testDecodesOrderViewWithAllUnitFields, testDecodesLegacyOrderBundleNull, testDecodesParkedStringIdsAndPrimaryNumericIds, testUnknownUnitStatusDecodes, testDecodesCancelQuoteWaivedExpectedOutcome, testReceiptNotFoundIsNotProofOfNoWrite.
`BNDAPIClientTests`: testBusiness409LoginRequiredIsNotUnauthorized401, testClientRefusesPostWhenWriteNotAllowed, testClientNeverSendsWithoutAuthorizationMatch, testOversizeResponseMalformed.
(Spec lists `testReceiptNotFoundIsNotProofOfNoWrite` among the ten; placed in the decoding file because it asserts the contract; client-level echo/NOT_FOUND handling is in `testReceiptValidatesEchoAndOwner`.)

## NOT verified
- **Nothing compiled, nothing run** — no Swift toolchain in the cloud container. Possible compile risks: autoclosure-free `try` placement, `[self]` captures in `@MainActor` test closures, raw-string fixtures with `\#()` interpolation.
- Decimal text for non-integer JSON *numbers* (e.g. `0.20`) is not asserted (Foundation's Decimal-from-Double text is platform-dependent); `49.75` and `199.00`→`"199"` are asserted and may need adjusting.
- `URLComponents` percent-encoding of `requestId` containing `:` asserted as unescaped.
- Real backend shapes only from `bundle-gap.md §4` (primary + parked); parked `refundHold` / `fulfilledMerchants` shape is a guess.
- Tests were written together with the implementation; the red-first step was not performed.
- Not added to `.xcodeproj` (orchestrator regenerates); `Tests/AppUnitTests` untouched.
