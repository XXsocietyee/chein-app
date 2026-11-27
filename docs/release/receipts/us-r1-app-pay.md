# US launch r1 — lane app-pay receipt (2026-11-27)

Branch `us/r1-pay`, based on `origin/ui/combined-r7`. Brief: `docs/briefs/us-launch-r1.md` (design/handoff-r2), lane **app-pay**.
No compiler in the cloud: every API was checked by grep and by reading. **Not built and not run on a device.**

## What changed

| File | Change |
|---|---|
| `Core/StripePayContracts.swift` (new) | **All Stripe / Apple Pay wire details in one file.** Routes, channel names, merchant id, request bodies, response decoding, `StripePayService` (single-shot, no retry), `StripePayEligibility`. |
| `App/StripePayBridge.swift` (new) | Session glue + `StripePayLease` transport (JSON POST, one of the 3 routes, configured host, payment switch on). `\.stripePayContext` environment value: nil outside the US market or with payments closed. |
| `App/ApplePayStripeAuthorizer.swift` (new) | `PKPaymentAuthorizationController` (merchant `merchant.com.chengyinhub.chengyinApp`, networks visa/masterCard/amex/discover, `.threeDSecure`, country US, currency USD, amount from the server's PaymentIntent). SwiftUI `PayWithApplePayButton`. `SFSafariViewController` wrapper for Stripe Checkout. |
| `App/RegistrationStripePaySection.swift` (new) | US pay rows: Apple Pay button and/or "Pay with card". Same preconditions as the China step (consent, payment readiness, money switch). Both paths end in the **existing order-status poll** (`PaymentProviderReturnSheet` → `PaymentProviderReturnFlow` → `OrderPaymentVerifier` → `orderLifecycleReader.detail`). Only server readback says "paid". |
| `App/RegistrationPaySection.swift` | If `stripePayContext` is set **and** the quote is a USD quote listing `APPLE_PAY`/`APP_STRIPE`, show the US rows instead of the China "Pay now" button. Otherwise unchanged. |
| `App/QuestifyApp.swift` (`chain3_1`) | Injects `\.stripePayContext`. |
| `Core/RegistrationContracts.swift` | `RegistrationQuote.currency` (lenient, nil on old/China quotes). `paymentChannelUnavailable` also accepts `APP_STRIPE`/`APPLE_PAY` (China lists never carry them, so China behaviour is byte-identical). |
| `Core/ChinaReviewedRouteCapability.swift` | `/api/pay/stripe/{intent,applepay,checkout}` → `ReleaseMoneyWriteKind.payment` in `ReleaseMoneyWriteSwitch.kind(for:)` and in `moneyAreaOwnerGrant` (the US build uses the same production host, so the production route gate must admit them; admitted only while payment is on). |
| `Config/Questify.entitlements` | `com.apple.developer.in-app-payments` = `[merchant.com.chengyinhub.chengyinApp]`. |
| `Tests/ContractChecks/test_entitlements_contract.py`, `test_sign_in_with_apple_flow.py`, `test_universal_link_associated_domains.py`, `tools/archive_unsigned.py` | Exact-entitlement assertions now include the merchant id. |
| `Tests/CoreTests/StripePayContractsTests.swift` (new) | Route kind/switch, eligibility, quote channel check, intent body has no amount, minor-unit decode, non-USD / foreign checkout host refused, closed switch sends nothing, Apple Pay token body, server rejection message. |
| `Questify.xcodeproj` | `tools/generate_project.py`. |

China flow (WeChat / Alipay via `/api/registration/pay[/app]`) is not touched: the US rows render only when the market is `US`, the quote is USD, and its channel list has a Stripe channel. No new third-party SDK.

## API contract assumed (adjust in `Core/StripePayContracts.swift` only)

The backend receipt `docs/receipts/us-r1-backend.md` on hengyin `us/r1-backend` **did not exist yet** at the time of this run (branch 404). The app codes against the brief:

| Call | Body (JSON, `Authorization: <token>`) | `data` read by the app |
|---|---|---|
| `POST /api/pay/stripe/intent` | `{registrationId, orderNo?, bizType:"REGISTRATION"}` — **no amount/currency** | `paymentIntentId`\|`id`, `amountMinor`\|`amountCents` (cents) or `amount` (dollars), `currency` (must be USD), `status`, `checkoutUrl`\|`url` (optional) |
| `POST /api/pay/stripe/applepay` | above + `paymentIntentId`, `pkToken` (PKPaymentToken.paymentData as UTF-8 JSON = Stripe `pk_token`), `pkTokenBase64`, `pkTokenInstrumentName`, `pkTokenPaymentNetwork`, `pkTokenTransactionId` | `status` (`succeeded`/`processing`/`requires_capture`/`paid` close the sheet as success) |
| `POST /api/pay/stripe/checkout` | same as intent | `url`\|`checkoutUrl` — must be `https://checkout.stripe.com/...` |

Envelope `AjaxResult {code,msg,data}`; `code != 200` shows `msg`. Quote: `currency: "USD"` and `paymentChannels` containing `APPLE_PAY` and/or `APP_STRIPE`.
Server side must create the Stripe token from `pkToken` (`POST /v1/tokens` with `pk_token*`) and confirm with `payment_method_data[card][token]`, as in the brief. The checkout URL is only used if the intent response has none.

## Config the owner / coordinator must set

| Where | Key | Note |
|---|---|---|
| Apple Developer | Merchant ID `merchant.com.chengyinhub.chengyinApp` | Create it, enable Apple Pay on the App ID, regenerate provisioning profiles (entitlement is now in the app). |
| Apple Developer ↔ Stripe | Apple Pay Payment Processing certificate | Generate the CSR in the Stripe Dashboard (Settings → Apple Pay), upload to Apple, upload the cert back to Stripe. |
| Backend config (be-us) | `stripe.secretKey`, `stripe.webhookSecret`, `stripe.publishableKey` | Not in git. The app does not need the publishable key (no Stripe SDK). |
| Stripe Dashboard | Webhook endpoint `…/prod-api/api/pay/stripe/webhook` (`payment_intent.succeeded`, refunds) | Its signing secret → `stripe.webhookSecret`. |
| Stripe Checkout (backend) | `success_url` / `cancel_url` | Any https page; the user closes Safari and the app polls. |
| App xcconfig | none new | US host/realm are lane app-us (`Config/UnitedStates.Production.xcconfig`). Payments follow the existing host switch + `ReleaseMoneyWriteSwitch.paymentEnabled`, plus the US market. |

## Gates

- `python3 tools/check_scaffold.py` → PASS structural checks (5234 Swift files)
- `python3 tools/check_a11y_lint.py` → PASS, 0 new
- `python3 tools/contract_ratchet.py --check` → 104 failing, baseline 104, **new 0**
- `python3 tools/check_appsession_ratchet.py` → PASS (AppSession untouched)

## Open items / risks

- **Not compiled.** Watch on first `build_sim`: `PKPaymentAuthorizationController.present(completion:)` / delegate `didAuthorizePayment:handler:` (nonisolated → MainActor hop), `PayWithApplePayButton(.plain, action:)`, `@State` holding a class (`ApplePayStripeAuthorizer`).
- `OrderLifecycleView` passes no quote to `RegistrationPaySection`, so the order-detail pay step stays on the China button for now. Needs `currency`/`paymentChannels` on `OrderLifecycleDetail` (backend) to show the US rows there too.
- `Tests/CoreTests/SignInWithAppleFlowTests.testRepositoryEntitlementIsTheOnlySignInValue` asserts `keys.count == 1`; it was already wrong before this lane (app group key). Not touched; it now has 3 keys.
- Amount display (`RegistrationUIMoney.display`) currency formatting is i18n/app-us territory.
- Apple Pay is locked for the order after a token reaches the server (success or unknown); a decline or cancel allows another tap. Card checkout can be reopened (Stripe Checkout session is idempotent server-side per order no).
