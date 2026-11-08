# Bundle iOS spec — work packages for `T-01..T-17`

Docs-only. Companion to `bundle-gap.md` (what exists) and `bundle-backend-spec.md` (what the backend must add; endpoint ids `B-xx` refer to its sections). Nothing here was built or run.

## 0. Ground rules (inherited from `docs/owner-plan/work-packages.md`)

- **Safe mode.** Shipped composition stays `makeComposition(reviewed: nil, …)` (`App/RegionalLaunchConfiguration.swift:10`). No WP flips a gate, issues a production approval/lease, enables reservation dispatch (`permitsReservationDispatch` stays default `false`, `Core/FreeExploreLaunchService.swift:38-41`), or swaps `FreeExploreCancelFactory.makeCanceler` away from `GatedFreeExploreReservationCanceler` (`App/FreeExploreCancelFactory.swift:8`).
- **No mock data in the production path.** Test doubles and golden JSON live only under `Tests/`. A feature whose backend endpoint is missing ships a *typed client protocol + an `unavailable` default implementation* (same pattern as `GatedFreeExploreReservationCanceler`), never a canned response.
- **Server is the authority.** No client-side price/refund/threshold math (`Core/FreeExploreLaunchService.swift:75`; guard planned in `work-packages.md` WP-04). 12 h / 20 % / waiver numbers are displayed from server fields only. Cancel always carries the server's `expectedOutcome`.
- **Writes are allow-listed at the transport.** Each WP that adds a write adds an exact-method + exact-URL allow-listing transport (pattern: `App/FreeExploreBundleReservationTransport.swift:60-72`, `App/FreeExploreBundleReadHost.swift:140-168`): `Authorization` must equal the captured session token, body size capped, `Content-Length` checked, re-check of approval *after* the network call, 403 retires the permission, matching 401 calls the session-expiry callback.
- **Unknown outcome = read back, never resend blindly.** Persist the original command before dispatch (pattern: `Core/FreeExploreLaunchPendingStore.swift`, owner-bound by `FreeExploreLaunchSession.ownerKey`), recover via the receipt endpoint with the **same** idempotency key (`Core/FreeExploreLaunchCoordinator.swift`). Login loss arrives as business 409 + `LOGIN_REQUIRED`; it must not clear the pending command.
- **Ids** decode through `FreeExploreLaunchID` (accepts number or string, rejects ≤0), money/ratios through `FreeExploreLaunchDecimal` (`Core/FreeExploreLaunchContracts.swift:11,35`). Never `Double`.
- **Builder boundaries:** only `Core/*.swift`, `App/*.swift`, `Tests/**`. Do not edit `Resources/`, `Config/`, `tools/`, `.xcodeproj`, `docs/`. Hot files (`App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/QuestifyApp.swift`, `App/RegionalLaunchConfiguration.swift`) belong to **IWP-9 only** (orchestrator, serial, last). New localization keys are requested (see §3), not added. Do not loosen or edit existing tests; new tests go in new `BND`-prefixed files.
- **Protected existing files** (no WP edits them): `Core/FreeExploreLaunchContracts.swift`, `Core/FreeExploreLaunchService.swift`, `Core/FreeExploreLaunchCoordinator.swift`, `Core/FreeExploreLaunchPendingStore.swift`, `Core/FreeExploreCancelFlow.swift`, `App/FreeExploreBundleLaunchModel.swift`, `App/FreeExploreBundleLaunchView.swift`, `App/FreeExploreBundleReservationTransport.swift`. They are pinned by tests (`Tests/CoreTests/FreeExploreLaunchServiceTests.swift:98` and `FreeExploreLaunchCoordinatorTests.swift:220` assert `cancellationQuoteUnavailable`). New behaviour goes in **new types beside them** that reuse their public types.

### Reusable existing types (build on these, don't re-invent)

| Need | Reuse |
|---|---|
| Session/auth/owner key | `FreeExploreLaunchSession` (`Core/FreeExploreLaunchService.swift:6`) |
| Failure taxonomy | `FreeExploreLaunchFailure` (`Core/FreeExploreLaunchContracts.swift:4`) incl. `.response(status:code:businessCode:)`, `.outcomeUnknown`, `.disabled` |
| Ids / decimals | `FreeExploreLaunchID`, `FreeExploreLaunchDecimal` |
| Catalog / order / reservation / refund-quote decode | `FreeExploreLaunchCatalog`, `FreeExploreLaunchOrder`, `FreeExploreLaunchReservation`, `FreeExploreLaunchRefundQuote` (`Core/FreeExploreLaunchContracts.swift:48-136`) |
| Reserve + recovery | `FreeExploreLaunchService.reserve/receipt`, `FreeExploreLaunchCoordinator`, `FreeExploreBundleLaunchModel` |
| Cancel UI state machine | `FreeExploreCancelModel`, protocol `FreeExploreReservationCanceling`, `FreeExploreCancelQuote(expectedOutcome:canCancel:message:)` (`Core/FreeExploreCancelFlow.swift:11,39,61`) |
| Read-only gated entry | `FreeExploreBundleReadApproval/Host/Transport`, `FreeExploreBundleReadEntry`, mount at `App/ProfileOrdersView.swift:271` |
| Registration order create + consents | `Core/RegistrationProduction.swift:19` (`api/registration/quote|create`, `api/compliance/consents/latest`) |
| Merchant scan paths (not player) | `Core/OrderPassContracts.swift:64`, `Core/MerchantVerificationHTTPTransport.swift:9-11` |
| Native purchase precedent (only if IAP is chosen) | `Core/WorkshopStoreKitLauncher.swift` |

## 1. Work packages

`NOW` = backend exists today (listed in `bundle-gap.md`). `BLOCKED-BACKEND(B-xx)` = needs that backend section first. `BLOCKED-PAYMENT` = needs the IAP-vs-WeChat decision.

| WP | T anchors | Gate | Depends on |
|---|---|---|---|
| **IWP-0** Contracts + API client (foundation, wires nothing) | all | NOW | — |
| **IWP-1** Cancel quote/confirm transport + view | T-11 | NOW | IWP-0 |
| **IWP-2** Order status / wallet (per order) / reservations screens | T-05, T-06, T-10 | NOW | IWP-0 |
| **IWP-3** Refund quote screen (read-only) | T-16 (quote) | NOW | IWP-0 |
| **IWP-4** Shelf + detail | T-01, T-02 | detail NOW; shelf BLOCKED-BACKEND(B-01, B-02) | IWP-0 |
| **IWP-5** Voucher + redeem result | T-07, T-08 | BLOCKED-BACKEND(B-09/10/17) | IWP-0 |
| **IWP-6** Merchant stall + reserve window | T-03, T-09 | window NOW (clip only); stall/slots BLOCKED-BACKEND(B-03) | IWP-0 |
| **IWP-7** Appeal | T-12 | BLOCKED-BACKEND(B-19) | IWP-0 |
| **IWP-8a** Reviews | T-13 | BLOCKED-BACKEND(B-20/21/22) | IWP-0 |
| **IWP-8b** Renewal intent | T-14 | BLOCKED-BACKEND(B-23) | IWP-0 |
| **IWP-8c** Transfer | T-15 | BLOCKED-BACKEND(B-24 + BWP-1) | IWP-0 |
| **IWP-R** Refund apply + progress | T-16 (apply), T-17 | BLOCKED-BACKEND(R) + BLOCKED-PAYMENT | IWP-3 |
| **IWP-C** Checkout confirm | T-04 | BLOCKED-PAYMENT (also B-05) | IWP-0 |
| **IWP-9** Mount + composition (orchestrator, serial, last) | all | after the WPs it mounts | all mounted WPs |
| **IWP-L** Localization table `BundleCommerce.xcstrings` (orchestrator-owned `Resources/`) | all | with each WP | — |

Order: **IWP-0 first, then IWP-1 ∥ IWP-2 ∥ IWP-3** (disjoint), then IWP-4/6 as backend lands. Backend-blocked WPs may be started early *only* as Core model + client protocol + `unavailable` default + Tests (no view), which keeps them compile-safe and mock-free.

### IWP-0 — Contracts + API client
- **Create:** `Core/BundleContracts.swift`, `Core/BundleAPIClient.swift`, `Tests/CoreTests/BNDContractsDecodingTests.swift`, `Tests/CoreTests/BNDAPIClientTests.swift`.
- **Contracts** (all `Decodable`, `Equatable`, ids `FreeExploreLaunchID`, money `FreeExploreLaunchDecimal`; every field not guaranteed optional in `bundle-gap.md §4`):
  `BundleUnit` (id, grantId, registrationId, holderMemberId, chapterId, unitSeq, unitCode, unitValue, status, redemptionId?, reservationId?, statusReason?, version, grantNo, validFrom, validTo), `BundleBalance` (grantId, chapterId, grantNo, grantType, unitsTotal, counts[String:Int], validFrom, validTo, expired), `BundlePolicy` (version, freeCancelHours, partialRefundMinRatio, monthlyVoluntaryWaivers), `BundleExitCase`, `BundleCancelQuote` (reservationId, version, status, asOf, useWaiver, outcome, expectedOutcome, canCancel, waiverMonth), `BundleExitOptions`, `BundleOrderReceipt` (`receipt: FOUND|NOT_FOUND`, `order?`, parked `outcome?`), `BundleRefundHold?` (parked; optional so the primary branch still decodes).
  Dates: backend mixes `"yyyy-MM-dd HH:mm:ss"` (Asia/Shanghai, domain objects), epoch-ms numbers (`asOf`, `contract.validEnd`) and raw `Date` (catalog `validEnd`, grant `validFrom/validTo`). Reuse `Core/MoneyParityRules.swift` `timestamp(_:)`/`timestamp(number:)` (`:50,:65`) for parsing; do not write a new date parser. Unknown `status` strings must decode (stored as `String`, with a helper `isKnown`) so a new server state never crashes a screen.
- **Client** `BundleAPIClient` (`@MainActor`, takes `FreeExploreLaunchSession` + `any HTTPTransport` + current/unauthorized closures, same envelope handling as `FreeExploreLaunchService.executeOptional` `:125-147`: `code==200`, `businessCode`, 401 callback, 1 MiB cap, `Cache-Control: no-store`). GET methods: `orderReceipt(requestId:)`, `cancelQuote(reservationID:useWaiver:)`, `exitOptions(registrationID:unitID:)`. POST methods (each takes a persisted command; **disabled unless an injected `writeAllowed()` is true**, default `false`): `cancel(reservationID:useWaiver:expectedOutcome:)`, `exitDecision(…)`. Future endpoints are added by their own WP in their own files via `extension`, not here.
- **Why not extend `FreeExploreLaunchService`:** it is protected and pinned by tests; its envelope code is private. Duplicating ~25 lines of envelope handling in one new file is cheaper than reopening it.
- **Tests:** `testDecodesOrderViewWithAllUnitFields`, `testDecodesLegacyOrderBundleNull`, `testDecodesParkedStringIdsAndPrimaryNumericIds`, `testUnknownUnitStatusDecodes`, `testDecodesCancelQuoteWaivedExpectedOutcome` (`"WAIVED:2026-11"`), `testReceiptNotFoundIsNotProofOfNoWrite`, `testBusiness409LoginRequiredIsNotUnauthorized401`, `testClientRefusesPostWhenWriteNotAllowed`, `testClientNeverSendsWithoutAuthorizationMatch`, `testOversizeResponseMalformed`. Golden JSON in `Tests/Fixtures/` copied from `bundle-gap.md §4` (not from production code).
- **Must NOT touch:** every existing file.

### IWP-1 — Cancel quote/confirm (T-11, EP-BND-14/15/16)
- **Create:** `App/BundleCancelTransport.swift` (allow-listing transport for exactly `GET …/reservation/{id}/cancel-quote?useWaiver=` and `POST …/reservation/{id}/cancel`, body `{"useWaiver":Bool,"expectedOutcome":String}` — **`expectedOutcome` mandatory in this client** even though the server tolerates omission, `CTL:99-101`), `App/BundleCancelCanceler.swift` (implements `FreeExploreReservationCanceling` over `BundleAPIClient`), `App/BundleCancelView.swift` (renders `FreeExploreCancelModel`), `Tests/AppUnitTests/BNDCancelTransportTests.swift`, `Tests/CoreTests/BNDCancelCancelerTests.swift`.
- **Behaviour:** quote → show `outcome`/`canCancel`/free-cancel hours from `BundlePolicy` (server value) → user confirms → POST with the quote's `expectedOutcome`. `BUNDLE_CANCEL_QUOTE_CHANGED` ⇒ re-quote and ask again (never auto-confirm). `WAIVED:yyyy-MM` is shown as "use this month's waiver" only when the user toggled it. After success **read back** the order (`FreeExploreLaunchService.order`) and call `FreeExploreCancelModel.resolveAfterReadback(reservationStatus:)` (`Core/FreeExploreCancelFlow.swift:106`). Unknown POST outcome ⇒ "awaiting confirmation" + read-back, never retry with a new quote.
- **Gate:** the canceler is constructed only by IWP-9 under the same approval object that gates reads; default factory untouched ⇒ production still returns `.unavailable`.
- **Waiver suggestion (EP-16):** until B-16 exists, show no suggestion; the toggle is manual. After B-16, `BundleWaiverStatus` decode lives in an IWP-1 follow-up file (`Core/BundleWaiverStatus.swift`).
- **Tests:** `testQuoteUsesServerExpectedOutcomeVerbatim`, `testCancelBodyAlwaysContainsExpectedOutcome`, `testQuoteChangedForcesReQuoteAndNeverAutoConfirms`, `testLateCancelledOutcomeShownAsPenaltyNotFree`, `testUnknownPostOutcomeReadsBackWithoutResend`, `testGatedFactoryStillUnavailableByDefault`, `testTransportRejectsAnyOtherPathOrMethod`, `testNoLocalTwelveHourCalculation` (source-text scan: no `12`/`43200` arithmetic in the new files).
- **Must NOT touch:** `Core/FreeExploreCancelFlow.swift`, `Core/FreeExploreLaunchService.swift` (its `cancellationQuote` stays throwing; the stale comment at `:95` "frozen controller has no cancel-quote" is documentation drift to be fixed by the owner of that file later, not here).

### IWP-2 — Order status / wallet / reservations (T-05, T-06, T-10; EP-06/04/13)
- **Create:** `Core/BundleOrderReadModel.swift` (view-model over `FreeExploreLaunchOrder` + IWP-0 richer decode: activation state from `paymentStatus/registrationStatus`, per-chapter balance rows, reservation rows), `App/BundleOrderStatusView.swift` (T-05: pending/active/expired/refunded; **UNKNOWN create** ⇒ poll `order/receipt` with the original `requestId`, backoff, stop on `FOUND`), `App/BundleWalletView.swift` (T-06: balances + valid window + entry rows), `App/BundleReservationsView.swift` (T-10), tests `Tests/CoreTests/BNDOrderReadModelTests.swift`, `Tests/AppUnitTests/BNDOrderStatusViewTests.swift`.
- **Wallet scope today:** per order only (backend `GET /order`); the cross-order list needs B-04. The view takes an injected `loadWallet` that, until B-04, is satisfied by the existing single-order host entry (`App/ProfileOrdersView.swift:271`). **Do not** fake a list by looping `api/registration/list` (that is a generic registration list, `Core/TicketWalletService.swift:11`, not bundle ownership).
- **Transport:** receipt polling needs `order/receipt` added to a read allow-list; do this in a **new** `App/BundleReadTransport.swift` (copy of the read-host allow-list idea with the extra route) instead of editing `App/FreeExploreBundleReadHost.swift` (IWP-9 swaps it in).
- **Display rules:** never show "paid" from the client; `paymentStatus==2 && registrationStatus==2` is shown only as the server's value. A legacy order (`bundle:null`) renders the existing non-bundle path (`legacy` flag, `App/FreeExploreBundleReadHost.swift:93`).
- **Tests:** `testActivationDerivedOnlyFromServerStatusInts`, `testLegacyOrderRoutesToLegacy`, `testReceiptPollStopsOnFoundAndNeverCreatesOrder`, `testNotFoundReceiptIsNotShownAsFailed`, `testBalancesRenderCountsFromServerOnly`, `testExpiredFlagComesFromServer`, `testReservationRowsSortedByStartAtAsServerOrder`.

### IWP-3 — Refund quote screen (T-16 quote half; read-only)
- **Create:** `App/BundleRefundQuoteView.swift`, `Core/BundleRefundQuotePresentation.swift` (maps `route` enum → copy key; unknown route ⇒ neutral "see support"), `Tests/CoreTests/BNDRefundQuotePresentationTests.swift`.
- Uses existing `FreeExploreLaunchService.refundQuote` (`:74`). Shows `route`, `amount`, `remainingRatio` **as returned** (display formatting only), `afterSalesForMerchantBreach` ⇒ pointer to after-sales, never a "Refund" button (apply is IWP-R). Explicit copy: "quote only — no money moves".
- **Tests:** `testRouteNotRefundableShowsAfterSalesPointerWhenBreachFlag`, `testNoApplyButtonExists`, `testNoClientSideRatioOrAmountComputation` (source-text scan), `testUnknownRouteFallsBack`.

### IWP-4 — Shelf + detail (T-01, T-02; EP-01/02)
- **Create:** `Core/BundleShelfModel.swift`, `Core/BundleShelfClient.swift` (protocol + `UnavailableBundleShelfClient` default; real impl added when B-01 lands), `App/BundleShelfView.swift`, `App/BundleDetailView.swift`, `Tests/CoreTests/BNDShelfModelTests.swift`.
- Detail renders `FreeExploreLaunchCatalog` (exists) + B-02 additive fields as optionals. `saleEnabled == false` ⇒ "not on sale" state, no purchase affordance. Compliance text comes from the server field only (no bundled legal copy in the app).
- **Tests:** `testShelfUnavailableDefaultShowsNothingNotMockCards`, `testDetailHidesPurchaseWhenSaleDisabled`, `testDetailToleratesMissingComplianceFields`, `testShelfPaginationCursorStopsOnNil`.

### IWP-5 — Voucher + redeem result (T-07, T-08; EP-09/10/17)
- **Create:** `Core/BundleVoucherClient.swift` (protocol + unavailable default), `Core/BundleVoucherModel.swift` (version poll with injected `Clock`/sleeper; poll only while `visible`; cancel on disappear; refetch full voucher only when `voucherVersion` changes; ≥5 s interval from server hint if any), `App/BundleVoucherView.swift` (main code + sub codes), `App/BundleRedeemResultView.swift` (**three states**: success / review / rejected + `NONE`), tests `Tests/CoreTests/BNDVoucherModelTests.swift`.
- **Security:** voucher code is **not** logged, not written to `UserDefaults`/pasteboard/screenshots-cache, view applies the app's existing screen-capture/privacy convention if one exists (grep `isCaptured` before deciding — I did not check). QR payload = whatever the server returns; do not generate codes client-side.
- **Result semantics:** `REVIEW`/`REJECTED` are reserved until the verification domain exists (`bundle-backend-spec.md B-17`); view must render unknown `outcome` as neutral "processing".
- **Tests:** `testPollStopsWhenViewDisappears`, `testRefetchOnlyOnVersionChange`, `testCodeNeverPersisted`, `testUnknownOutcomeRendersNeutral`, `testVersionPollBackoffOnFailure`.

### IWP-6 — Merchant stall + reserve window (T-03, T-09; EP-03/12)
- **Create:** `Core/BundleReserveWindow.swift` (pure: given server `validFrom/validTo`, server `now`, produce up to 14 selectable days; **UX clipping only** — the server remains the authority on `startAt > now` and validity, `SVC:~447-449`), `App/BundleReserveWindowView.swift`, `Core/BundleOfferClient.swift` (protocol + unavailable default for B-03), `App/BundleMerchantStallView.swift`, tests `Tests/CoreTests/BNDReserveWindowTests.swift`.
- Hands the chosen `startAt` to the **existing** `FreeExploreBundleLaunchModel.prepare(unitID:offerID:startAt:)` (`App/FreeExploreBundleLaunchModel.swift:65`) — IWP-6 does not reimplement reserve or recovery. Slots grid renders only when the server returns a non-empty `slots` (B-03/EP-PRD); until then it shows the free-time picker already present, constrained to the window.
- `unavailableReasons[]` are rendered one-to-one from the server enum; unknown reason ⇒ generic copy.
- **Tests:** `testWindowIsAtMostFourteenDaysAndNeverBeforeNow`, `testWindowClippedToUnitValidity`, `testNoSelectableDayWhenExpired`, `testWindowUsesServerNowNotDeviceClockWhenProvided`, `testStallRendersEveryReasonEnum`.
- **Must NOT touch:** `App/FreeExploreBundleLaunchModel.swift`, `App/FreeExploreBundleLaunchView.swift`.

### IWP-7 — Appeal (T-12; EP-19)
- **Create:** `Core/BundleAppealClient.swift`, `Core/BundleAppealModel.swift`, `Core/BundleAppealPendingStore.swift` (owner-bound durable command, modelled on `FreeExploreLaunchPendingStore`), `App/BundleAppealView.swift`, `App/BundleAppealTransport.swift` (allow-list: `POST …/voucher/appeal`, `GET …/voucher/appeal/receipt`, `GET …/voucher/appeal`), `Tests/CoreTests/BNDAppealModelTests.swift`.
- Evidence uploads reuse the existing own-media upload path (find it: `Core/OwnMedia*`, `Core/ProjectTopicImageUpload.swift`); do not add a new uploader. Max 6 refs, note ≤500 (limits displayed from the spec, validated again by the server).
- Copy must say "submitted for review", never "refunded/consumed" (first backend slice does not apply the decision, `bundle-backend-spec.md B-19`).
- **Tests:** `testSubmitPersistsCommandBeforeDispatch`, `testUnknownOutcomeReadsBackBySameKey`, `testSecondAppealForSameUnitBlockedByServerCodeShown`, `testApprovedAppealDoesNotShowUnitAsRedeemedUntilServerSaysSo`.

### IWP-8a — Reviews (T-13; EP-20/22)  /  IWP-8b — Renewal intent (T-14; EP-23)
- **8a create:** `Core/BundleReviewClient.swift`, `Core/BundleReviewModel.swift`, `App/BundleReviewComposeView.swift`, `App/BundleReviewListView.swift`, `Tests/CoreTests/BNDReviewModelTests.swift`. Rating 1–5, ≤500 chars; show `PENDING` state to the author ("under review"); list shows server-approved items only. Merchant reply (EP-21/T-55) is a **merchant** surface — out of the player build.
- **8b create:** `Core/BundleRenewalClient.swift`, `Core/BundleRenewalModel.swift`, `App/BundleRenewalIntentView.swift`, `Tests/CoreTests/BNDRenewalModelTests.swift`. Copy states clearly: **intent only — no price held, no charge**. Intent options `WILL_RENEW|MAYBE|NO`.
- Both: durable pending command + same-key read-back; unavailable defaults; nothing mounted.
- **Tests (8a):** `testComposeBlockedWhenServerSaysNotEligible`, `testPendingReviewShownAsUnderReview`, `testDuplicateReviewShowsServerCode`; **(8b):** `testRenewalNeverShowsPriceOrPaymentUI`, `testLatestIntentWins`.

### IWP-8c — Transfer (T-15; EP-24)
- **Create:** `Core/BundleTransferClient.swift`, `Core/BundleTransferModel.swift`, `Core/BundleTransferPendingStore.swift`, `App/BundleTransferSendView.swift`, `App/BundleTransferClaimView.swift`, `App/BundleTransferTransport.swift`, `Tests/CoreTests/BNDTransferModelTests.swift`.
- **Sender:** phone + channel (`IN_APP`; `SMS` only if the server advertises it) → **impact preview** from the server ("whole unused bundle, you lose all rights, cannot be withdrawn after claim") → explicit confirm → show the one-time code **once**; code is held in memory only, never persisted, never logged, excluded from restoration/snapshots; leaving the screen discards it (sender can revoke while `PENDING`).
- **Receiver:** enter code → server answers one generic error for wrong/expired/used. States shown separately: sent / pending / claimed / expired / revoked.
- **Scope guard:** must not reuse the club invite (P118) or reward coupons (S16) or qmod licence (W18) models; add a source-scan test for those symbols.
- **Tests:** `testCodeNeverWrittenToStorageOrLogs`, `testClaimErrorsAreIndistinguishable`, `testTransferUnavailableWhenAnyUnitUsedPerServerEligibility`, `testPayerStillSeesRefundQuoteAfterTransferIsServerDriven`, `testNoReuseOfInviteOrCouponTypes`.

### IWP-R — Refund apply + progress (T-16 apply, T-17)  — BLOCKED
- Waits for backend section **R** (`POST /order/refund`, `GET /order/refund`) **and** the payment decision (cash leg). Skeleton allowed only as Core model + unavailable client: `Core/BundleRefundClient.swift`, `Core/BundleRefundProgressModel.swift`, `App/BundleRefundApplyView.swift`, `App/BundleRefundProgressView.swift`, tests `Tests/CoreTests/BNDRefundProgressModelTests.swift`.
- Rules that must be encoded when built: apply carries the server quote's `route` and `amount` as `expectedRoute/expectedAmount`; "processing/UNKNOWN/manual payout" is **never** shown as "refunded" (parked `IFreeExploreBundleRefundService` rule: approval ≠ cash arrival); unit multi-select only if the owner confirms partial refunds (otherwise whole order).
- If **IAP** is chosen the refund UI may have to defer to Apple's refund flow (`Core/StoreKit2SubscriptionAndRefundLifecycleAudit.swift` is an audit helper, not a flow) — do not pre-build either branch.

### IWP-C — Checkout confirm (T-04; EP-05, EP-CMP-01)  — BLOCKED-PAYMENT
- Do not start. What is already decided and may be pre-specified: compliance declaration + agreement checkboxes come from `api/compliance/consents/latest` (`Core/RegistrationProduction.swift:19`); order is created through the **existing** registration create path with a client request-id so `order/receipt` can recover an UNKNOWN create; the pay step and its provider are the open decision. No "Pay" button is shipped before that decision.

### IWP-9 — Mount + composition (orchestrator, serial, last)
- Only WP allowed to edit `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/FreeExploreBundleReadHost.swift`/`ReadEntry.swift`/`ProfileOrdersView.swift` (mount points) and `App/RegionalLaunchConfiguration.swift` (never to flip a default). Wires finished screens behind the **existing** `FreeExploreBundleReadApproval` (24 h max, role `player|club|merchant`, `context.market == .china`, `App/FreeExploreBundleReadHost.swift:15-21`) or a sibling approval class with the same shape per feature; production default for every new provider is `nil`.
- Acceptance: `testShippedCompositionStillUnconfigured`, `testNoBundleProviderNonNilInShippedBuild`, `testReservationDispatchStillOffByDefault`, `testCancelFactoryStillGatedByDefault`.

### IWP-L — Localization (orchestrator)
- New table `Resources/BundleCommerce.xcstrings` (zh-Hans + en). Keys requested by WPs (builders list in their PR description, orchestrator adds): shelf/detail titles, `activation.{pending,active,expired,refunded,unknown}`, `reservation.status.{BOOKED,CANCELLED,WAIVED,LATE_CANCELLED,NO_SHOW,FULFILLED,MERCHANT_EXITED}`, `unit.status.{AVAILABLE,RESERVED,REDEEMED,FORFEITED,HELD,REFUND_PENDING,REFUNDED}`, `cancel.outcome.{CANCELLED,WAIVED,LATE_CANCELLED}`, `refund.route.{ORIGINAL_METHOD,PLATFORM_BALANCE,NOT_REFUNDABLE}`, `bundle.error.<businessCode>` for every code in `bundle-gap.md §4` + `bundle-backend-spec.md`, transfer/appeal/review/renewal copy. Existing table `Resources/FreeExploreBundleLaunch.xcstrings` is reused unchanged by code that already uses it.

## 2. T-01..T-17 coverage

| T | WP | State after WP |
|---|---|---|
| T-01 | IWP-4 | shelf needs B-01 |
| T-02 | IWP-4 | detail works on `catalog` |
| T-03 | IWP-6 | needs B-03 (slots also EP-PRD) |
| T-04 | IWP-C | blocked on payment |
| T-05 | IWP-2 | works: order + receipt poll |
| T-06 | IWP-2 | per order now; list needs B-04 |
| T-07 | IWP-5 | needs B-09/10 |
| T-08 | IWP-5 | needs B-17 (+EP-VRF-04 for review/reject) |
| T-09 | IWP-6 | window clip now; slot grid needs B-03 |
| T-10 | IWP-2 | works from order view |
| T-11 | IWP-1 | works (transport + view), still gated until IWP-9 |
| T-12 | IWP-7 | needs B-19 |
| T-13 | IWP-8a | needs B-20/22 |
| T-14 | IWP-8b | needs B-23 |
| T-15 | IWP-8c | needs B-24 + BWP-1 |
| T-16 | IWP-3 (quote) + IWP-R (apply) | quote works now; apply blocked |
| T-17 | IWP-R | blocked |

## 3. Disjoint file matrix (create-only; "—" = nothing shared)

| WP | New files |
|---|---|
| IWP-0 | `Core/BundleContracts.swift`, `Core/BundleAPIClient.swift`, `Tests/CoreTests/BNDContractsDecodingTests.swift`, `Tests/CoreTests/BNDAPIClientTests.swift` |
| IWP-1 | `App/BundleCancelTransport.swift`, `App/BundleCancelCanceler.swift`, `App/BundleCancelView.swift`, `Tests/AppUnitTests/BNDCancelTransportTests.swift`, `Tests/CoreTests/BNDCancelCancelerTests.swift` |
| IWP-2 | `Core/BundleOrderReadModel.swift`, `App/BundleReadTransport.swift`, `App/BundleOrderStatusView.swift`, `App/BundleWalletView.swift`, `App/BundleReservationsView.swift`, `Tests/CoreTests/BNDOrderReadModelTests.swift`, `Tests/AppUnitTests/BNDOrderStatusViewTests.swift` |
| IWP-3 | `Core/BundleRefundQuotePresentation.swift`, `App/BundleRefundQuoteView.swift`, `Tests/CoreTests/BNDRefundQuotePresentationTests.swift` |
| IWP-4 | `Core/BundleShelfModel.swift`, `Core/BundleShelfClient.swift`, `App/BundleShelfView.swift`, `App/BundleDetailView.swift`, `Tests/CoreTests/BNDShelfModelTests.swift` |
| IWP-5 | `Core/BundleVoucherClient.swift`, `Core/BundleVoucherModel.swift`, `App/BundleVoucherView.swift`, `App/BundleRedeemResultView.swift`, `Tests/CoreTests/BNDVoucherModelTests.swift` |
| IWP-6 | `Core/BundleReserveWindow.swift`, `Core/BundleOfferClient.swift`, `App/BundleReserveWindowView.swift`, `App/BundleMerchantStallView.swift`, `Tests/CoreTests/BNDReserveWindowTests.swift` |
| IWP-7 | `Core/BundleAppealClient.swift`, `Core/BundleAppealModel.swift`, `Core/BundleAppealPendingStore.swift`, `App/BundleAppealView.swift`, `App/BundleAppealTransport.swift`, `Tests/CoreTests/BNDAppealModelTests.swift` |
| IWP-8a | `Core/BundleReviewClient.swift`, `Core/BundleReviewModel.swift`, `App/BundleReviewComposeView.swift`, `App/BundleReviewListView.swift`, `Tests/CoreTests/BNDReviewModelTests.swift` |
| IWP-8b | `Core/BundleRenewalClient.swift`, `Core/BundleRenewalModel.swift`, `App/BundleRenewalIntentView.swift`, `Tests/CoreTests/BNDRenewalModelTests.swift` |
| IWP-8c | `Core/BundleTransferClient.swift`, `Core/BundleTransferModel.swift`, `Core/BundleTransferPendingStore.swift`, `App/BundleTransferSendView.swift`, `App/BundleTransferClaimView.swift`, `App/BundleTransferTransport.swift`, `Tests/CoreTests/BNDTransferModelTests.swift` |
| IWP-R | `Core/BundleRefundClient.swift`, `Core/BundleRefundProgressModel.swift`, `App/BundleRefundApplyView.swift`, `App/BundleRefundProgressView.swift`, `Tests/CoreTests/BNDRefundProgressModelTests.swift` |
| IWP-C | (none until unblocked) |
| IWP-9 | edits only: `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/FreeExploreBundleReadHost.swift`, `App/FreeExploreBundleReadEntry.swift`, `App/ProfileOrdersView.swift`; new `Tests/AppUnitTests/BNDMountGuardTests.swift` |
| IWP-L | `Resources/BundleCommerce.xcstrings` |

Cross-check: no file name appears twice; every WP depends on IWP-0 only through its public types (IWP-0 files are not edited by later WPs — later endpoints are added via `extension` in the later WP's own client file). The 8 "Bundle…Client/Model" families share no type names (each prefixed by feature). New `.swift` files are picked up by `python3 tools/generate_project.py`, run by the orchestrator.

## 4. Safety checklist every WP's PR must answer

1. Does the shipped build still resolve `reviewed: nil` → unconfigured? (`App/RegionalLaunchConfiguration.swift:10` untouched.)
2. Is every new network write behind an injected `writeAllowed`/approval that is `false` by default, and an exact-URL allow-listing transport?
3. Is there any literal price, refund amount, threshold, or sample voucher in `Core/` or `App/`? (must be none; `grep` in CI as source-scan tests.)
4. Does an UNKNOWN write outcome persist-then-read-back with the same idempotency key?
5. Does the unavailable default render an honest "not available yet" state rather than empty/fake content?
6. Are any secrets, tokens, codes, phone numbers written to logs, storage, pasteboard or analytics? (must be none.)
7. Were only the files in the matrix touched, and did the full `Tests/CoreTests` and `Tests/AppUnitTests` suites show **no new failures vs `docs/parity/full-suite-triage.md` baseline**? (Note the baseline already has failing hosted tests; do not claim green.)

## 5. Recommended first three iOS WPs

1. **IWP-0** — contracts + API client (foundation; no UI; everything else compiles against it).
2. **IWP-1** — cancel quote/confirm (T-11): backend fully exists, iOS only has a gated stub, highest-value reachable loop.
3. **IWP-2** — order status / wallet (per order) / reservations (T-05, T-06, T-10), with `order/receipt` recovery that the iOS side does not call today.

(IWP-3, the read-only refund quote screen, is the cheapest fourth and is disjoint from 1 and 2.)
