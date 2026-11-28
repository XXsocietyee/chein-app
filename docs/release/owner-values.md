# Owner-only values

Values the app or backend cannot invent. Each row says where the value goes and its placeholder. Secrets are never committed;
backend secrets go in the deployment's environment / `application-*.yml` overrides, not in git.

## US payment: Stripe + Apple Pay (fix/1128-us-pay, audit P0-3 / P1-3)

| Value | Where | Placeholder / current | Notes |
|---|---|---|---|
| Apple Pay merchant ID | `Config/Questify.entitlements` `com.apple.developer.in-app-payments`; `Core/StripePayContracts.swift` `StripePayWire.merchantIdentifier` | `merchant.com.chengyinhub.chengyinApp` | Must be registered in the Apple Developer account and enabled on the App ID. The two places must match. |
| Apple Pay Payment Processing Certificate | Apple Developer → Merchant IDs, CSR from Stripe Dashboard → Settings → Apple Pay | none | Required for the backend's `POST /v1/tokens` `pk_token` exchange (`StripeHttpGateway.createApplePayToken`). Without it every Apple Pay confirm is declined. |
| `stripe.enabled` | backend config (`StripeProperties`, prefix `stripe`) | `false` | `true` lists `APPLE_PAY` on USD quotes. |
| `stripe.secret-key` | backend env only | `sk_live_…` (secret) | Never in the app or in git. |
| `stripe.webhook-secret` | backend env only | `whsec_…` (secret) | For `POST /api/pay/stripe/webhook`; endpoint registered in the Stripe Dashboard. |
| `stripe.publishable-key` | backend config | `pk_live_…` | Returned by `/intent`; the app does not need it (no Stripe SDK). |
| `stripe.checkout-success-url`, `stripe.checkout-cancel-url` | backend config | empty | Both set → `APP_STRIPE` (card via Stripe Checkout) is listed; empty → Apple Pay only. |
| USD market mapping per topic / club | backend data (`RegistrationStripeOrderPort.MarketCurrency`) | none | Decides which orders are USD. The app follows the quote's `currency`. |
| Release money switch for payments | `ReleaseMoneyWriteSwitch` / `ReviewedAreaSwitch.moneyPayments` (existing) | off unless the host is approved | Same switch as the China pay routes. |

No new xcconfig key was needed: the app sends no key and reads amount and currency from the server.
