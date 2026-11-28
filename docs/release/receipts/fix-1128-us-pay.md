# Receipt: fix/1128-us-pay (audit P0-3, P1-3)

Base: `origin/ui/combined-r7`. Backend contract: hengyin `origin/us/r3-functional`
(`chengyinhub-admin/.../api/ApiStripePayController.java`, `chengyinhub-system/.../stripe/StripePaymentService.java`,
`StripeHttpGateway.java`, `RegistrationCheckoutServiceImpl.java`, `ApiRegistrationController.java`).
No Swift compiler in this environment: nothing was built or run on a simulator. Only the Swift-free gates ran (below).

## P0-3: Stripe cards and Apple Pay match `ApiStripePayController`

| Loop step | Before | Now | Evidence |
|---|---|---|---|
| Wire format | JSON `{registrationId, orderNo, bizType}`; controller binds form params, so `id` was null → "Invalid order" | `application/x-www-form-urlencoded; charset=utf-8`, body `id=<registrationId>` on `/intent` and `/checkout` | `Core/StripePayContracts.swift` `StripePayService.makeRequest`, `StripeIntentRequest.formFields`; controller `intent(String id)`, `checkout(String id)` |
| Apple Pay token | `pkToken`, `pkTokenBase64`, `pkTokenInstrumentName`, `pkTokenPaymentNetwork`, `pkTokenTransactionId` | `id`, `paymentData` (PKPaymentToken.paymentData UTF-8 JSON), `transactionIdentifier`, `paymentNetwork`, `paymentMethodDisplayName`. `tokenId` is never sent (backend wants exactly one of the two) | `StripeApplePayConfirmRequest`, `StripePayWire.Field`; `applePay(String id, String tokenId, String paymentData, String transactionIdentifier, String paymentNetwork, String paymentMethodDisplayName)`; `StripeHttpGateway.createApplePayToken` |
| Encoding | n/a | strict RFC 3986 unreserved set, so `+ / = & {` inside the PassKit JSON are escaped | `StripePayForm.encode` |
| Amount | `amount` read as dollars (sheet showed 100x) | `amount` is cents (`intentView`/`createCheckout` put `frozen.amountMinor`); `StripeIntent.amountMinor`, `amount` = cents / 100; must be a positive whole number | `StripePayMoney`; `App/ApplePayStripeAuthorizer.swift` `paymentRequest` summary item = `StripePayMoney.major(fromMinor:)` |
| Card | intent then checkout, read `url` | one `POST /checkout` (`id`) → `checkoutUrl` (host must be `checkout.stripe.com`) → `SFSafariViewController` | `StripeCheckoutSession.decode`; `RegistrationStripePayRows.payWithCard` |
| Server errors | everything → `.rejected(msg)` | `errorCode` map: `PAYMENT_DECLINED` → declined (can retry); `PAYMENT_OUTCOME_UNKNOWN` / unreadable confirm answer → outcome unknown (status read, no retry); `ORDER_ALREADY_PAID` → status read; `ORDER_EXPIRED` / `STRIPE_INTENT_CANCELED` / `ORDER_AMOUNT_CHANGED` / `STRIPE_INTENT_MISMATCH` → "place a new order"; `Please sign in` / 401 / 403 → session expired (`expireIfMatching`) | `StripePayService.mapFailure`, `StripePayFailure` |
| Result | `PaymentProviderReturnSheet` order-detail poll | Like the China rows (`RegistrationAppPayRows`): after Apple Pay or Checkout, up to 3 reads of `api/registration/info` (`session.readRegistrationPaymentStatus`, 2 s apart). `paymentStatus == 2` → "Paid. Your ticket is in the wallet." + View ticket (`SessionTicketWalletHost`). No answer → "Checking payment…" + Refresh. Checkout closed but unpaid → "Payment not completed" + pay again. The confirm answer's `paymentStatus` only counts when the read fails | `StripePayStageResolver`, `RegistrationStripePayRows.settle/refresh` |
| Related screens | — | Order detail reads the order again once the server says paid (`onPaid` → `OrderLifecycleScreenModel.load`) | `App/OrderLifecycleView.swift` `reloadAfterPayment` |
| Lease | JSON-only lease | lease admits only a form POST to the three routes on the configured host with the payment switch on | `App/StripePayBridge.swift` `StripePayLease.admits` |

## P1-3: route by the quote's currency / channels, not the storefront

| Change | Evidence |
|---|---|
| `StripePayBridge.context` no longer requires `storefrontMarket == .unitedStates`; it is non-nil whenever payments are open | `App/StripePayBridge.swift` |
| `StripePayEligibility.applies(currency:paymentChannels:)`: USD + `APPLE_PAY`/`APP_STRIPE` → Stripe, otherwise the China route. A CN-storefront player on a USD topic gets Stripe (no more 409 `STRIPE_CHANNEL_REQUIRED`); a US-storefront player on a CNY topic gets WeChat Pay | `Core/StripePayContracts.swift`; `RegistrationCheckoutServiceImpl.attachStripePaymentChannels` / `retryPayment` |
| A USD order with no Stripe channel shows "Card and Apple Pay are not available…" and never calls the China route | `App/RegistrationPaySection.swift` |
| `payment-readiness` is WeChat-only (`isPaymentReady() = wechatPayService.isReady()`), so a USD quote's readiness comes from its own channels: the sheet skips the probe and the footer notice uses `StripePayEligibility.readiness` | `App/RegistrationSheetView.swift` `readinessProbePrice`, `effectivePaymentReadiness`; `ApiRegistrationController.paymentReadiness` |
| "Pay with" row options follow `StripePayEligibility.payMarket(quote)` (storefront only previews the row before the first quote) and the quote's channels | `App/RegistrationSheetView.swift` `payMethodMarket`; `Core/RegistrationPayMethod.swift` `options(…paymentChannels:)` |
| P32: Apple Pay first when `PKPaymentAuthorizationController.canMakePayments()` and offered, else Card. The sheet passes its effective choice, so the one primary button is that method (`PayWithApplePayButton` or "Pay $25.00 with card"). Order detail has no picker, so it shows the default plus the other method as `.bordered` | `StripePayEligibility.methods`; `RegistrationStripePayRows.primaryMethod`; `chosenPayMethod` |

## Files changed

- `Core/StripePayContracts.swift`: wire contract, cents, error map, readiness, stages.
- `Core/RegistrationPayMethod.swift`: US options narrowed to the quote's channels.
- `App/StripePayBridge.swift`: no storefront gate, form lease, status read.
- `App/ApplePayStripeAuthorizer.swift`: cents → dollars summary item; `ApplePaySheetOutcome.authorized(result)` / `.refused(failure)` / `.unknown`.
- `App/RegistrationStripePaySection.swift`: rows rebuilt (P32 button, result rows like the China flow).
- `App/RegistrationPaySection.swift`, `App/RegistrationSheetView.swift`, `App/RegistrationPayMethodSection.swift`, `App/OrderLifecycleView.swift`: routing, readiness, choice, refresh.
- `Resources/Localizable.xcstrings` (+6 keys, en + zh-Hans) via `tools/add_fix_1128_us_pay_localizations.py`.
- `docs/release/owner-values.md` (new), this receipt.

## Tests (`Tests/CoreTests/StripePayContractsTests.swift`)

Route paths = `@RequestMapping` + `@PostMapping`; form body `id=42` on intent/checkout with the form Content-Type;
Apple Pay fields exactly `id/paymentData/transactionIdentifier/paymentNetwork/paymentMethodDisplayName` (no `tokenId`, no `pkToken*`),
with reserved characters escaped; empty optionals omitted; empty token refused; cents decoding (2500 → $25, fractional refused);
non-USD / foreign Checkout host refused; errorCode → state map; unreadable confirm → outcome unknown; 401 → unauthorized;
switch closed / signed out sends nothing; P1-3 eligibility and `payMarket` independent of storefront; USD readiness from channels;
Apple Pay first only when the device can pay; result stages need `paymentStatus == 2`.
Not run (no Swift toolchain here).

## Gates

`generate_project` ✓ · `check_scaffold` PASS · `contract_ratchet --check` 52 failing = baseline 52, **new 0** ·
`check_design_consistency` PASS · `check_a11y_lint` PASS (0 new).

## Owner must supply (see `docs/release/owner-values.md`)

1. Apple Pay Payment Processing Certificate made from Stripe's CSR for `merchant.com.chengyinhub.chengyinApp` (without it the backend `pk_token` exchange fails and Apple Pay is declined).
2. Backend `stripe.enabled=true`, `stripe.secret-key`, `stripe.webhook-secret` (env only), and for card `stripe.checkout-success-url` / `stripe.checkout-cancel-url`. Register the webhook `POST /api/pay/stripe/webhook`.
3. Which topics or clubs are USD (backend market-currency data).
4. A device test on a real iPhone with a Wallet card: Xcode build, sandbox Apple Pay, one card Checkout.

## Notes for the coordinator

- `fix/1128-cn-pay` (P1-2) also touches `RegistrationPaySection.swift`. This branch only changes the Stripe branch, the readiness `.task` guard and the idle readiness row, so a merge conflict should be small.
- `fix/1128-alipay` may also edit `RegistrationPayMethod.options`. This branch only adds a trailing `paymentChannels:` parameter with a default value.
