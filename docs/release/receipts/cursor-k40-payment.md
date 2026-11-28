# K40 payment UX

Branch `cursor/1128-k40-payment` from `origin/ui/combined-r7` @ `a7c956335`. Scope is payment UX behaviour. Money switches, cash enablement, and merchant gating were not changed. No pay sender was added. `App/AppSession.swift` was not edited (7977 lines). Init order is untouched.

Sources: `origin/design/handoff-r2:docs/briefs/round3-1127.md` (P32 checkout, owner correction 04:45, sweeps), `origin/audit/1128-functions` (cross-tab money, P0-1..P0-4, P1-2..P1-4, P2-1), `origin/audit/1128-plan` (gap #9, O-05, O-07, G-01a, G-06), `origin/audit/1128-ada` (t5-baoming, currency on pay amounts).

Counts: **20** payment UX rows re-checked, **14** already fixed, **4** closed here with a test, **2** owner-only.

## Closed here

| Row | What was wrong | What the test locks |
|---|---|---|
| P2-1 host-tip banner | A payable `POST /api/host-tip/prepare` set the banner to payment-closed on both sides of the switch. | `testPayablePrepareIsPendingOnlyWhilePaymentsAreOpen`. Switch on → `.pending` (not paid, not closed). Switch off → `.paymentClosed`. A 501 stays `.unavailable`. A `paymentSucceeded` flag still does not become a paid result. No `/api/host-tip/pay` call. |
| Checkout button vs footnote (ADA t5-baoming, sweep 04:50) | The sheet already kept the action on the button. Nothing pinned that a block cannot replace it. | `testBlockedCheckoutKeepsThePayLabelAndPutsConsentInTheFootnote`. `submit` does not take the block. A paid quote stays `.pay`. Missing consent, a missing participant, and a closed signup are footnotes. |
| Pay-with row on a free quote (P32, sweep 13:15) | The row used the ticket's list price, so a quote that brought the amount due to zero still offered a method beside 确认报名. | `testFreeQuoteHidesPayWithAndConfirmsSignup`. Amount due zero → confirm signup, row hidden. Before a quote, a priced ticket still asks to confirm the price and shows the row. |
| Gap #9 order re-pay choice (O-05 / O-07) | `OrderRepaySection` already drew the USD picker. The choice lived only in the view. | `testOrderRepayChoiceFollowsTheOrderCurrency`. USD + Card offered → `.card`. Card is dropped when the order lists only Apple Pay. Apple Pay is dropped when the device cannot pay. A CNY order returns nil so the China pay section keeps WeChat Pay / Alipay. |

## Already fixed

| Row | SHA | Proof |
|---|---|---|
| P0-1 paid create sends `payChannel=APP` while payments are on; a closed switch still blocks | `5880f1880` | `RegistrationCoordinatorTests.testPaidQuoteCreatesWithAppChannelWhenPaymentsOpen` |
| P0-2 `/api/registration/pay/app`, params open WeChat, one `registration/info` read → paid / cancelled / checking | `17c574000`, `eea73b432` | `RegistrationAppPayTests`, `WeChatPaymentBuildSettingsTests` |
| P0-3 Stripe form `id`, Apple Pay field names, amount in cents | `7332e1b33` | `StripePayContractsTests` |
| P0-4 Alipay order → return → one query; paid / Pay again / checking | `944171c79`, `5e0e6ef06` | `AlipayAppPayTests` |
| P1-2 no "paid" chip without a server read | `17c574000` | `RegistrationAppPayRows` stages |
| P1-3 route by quote currency and channels, not the storefront | `7332e1b33` | `StripePayEligibility` tests |
| P1-4 detail actions omit the dead 审核支付; cancel is the pinned action | `17c574000` | `testDetailActionsSkipReviewSheetPayment` |
| P2-1 USD readiness comes from the order's Stripe channels, not the WeChat probe | `ff0837728` | `StripePayEligibility.readiness` |
| Pay-with row in the checkout bar (WeChat / Alipay, Apple Pay / Card) | `749961fbf` | `RegistrationPayMethodTests` options and names |
| Method-labelled button ("Pay ¥12.50 with WeChat Pay") | `9415e9ab6`, `944171c79` | `testPayTitleNamesMethodAndTotal` |
| Saved participant phone on the sheet is `139****0000` | `4e6347461` | `ProfileBoundPhoneDisplay.masking` |
| Registration bar title caps at xxxLarge and uses the Large Content Viewer; the form is not capped | `967839c1a` | `RegistrationPlayerSheetHeader.title` |
| Pay amounts use the order currency's narrow symbol (`¥` / `$`) in both languages | `b0b25e54e` | `testDisplayUsesTheOrderCurrencySymbolInEveryLocale` |
| Paid and free success offer 查看门票 | `576660fc6` | `RegistrationAppPayRows`, `RegistrationAcceptedTicketLink` |
| Payment moment: bounce, success haptic, ticket into the wallet; cancel shakes | `928cbea98` | `RegistrationPaidTicketMoment` |
| WeChat cannot open → footnote, not a dead Pay button | `17c574000` | `registration.pay.weChatNotReady` |

## Owner-only

These need a money switch, a cash gate, or owner credentials. They were not changed.

| Row | Why it stays with the owner |
|---|---|
| Pass / workshop purchase (P2-1) | `MPCommerceGate.purchasesEnabled` is off. The detail already shows the quote as text plus `mp.gate.purchase`, not a pay button. Turning cash on is out of scope. |
| Topic self-play pay (G-06) | The provider is on only when `selfPlayExternalCheckoutApproved` and `selfPlayPayment` are set. Those are payment approvals. A free self-play order still completes without the provider. |
| WeChat Pay on a device | AppID, merchant id, and the WeChat Pay SDK binary. Until they are set, the footnote says WeChat cannot open. |
| Alipay on a device | `QUESTIFY_ALIPAY_APP_SCHEME` and the optional SDK. The row stays hidden in Release until the quote lists `APP_ALIPAY` and the app can open Alipay. |
| Stripe / Apple Pay live charges | Stripe secret, webhook secret, and the Apple Pay processing certificate. |
| Host-tip collection | There is no admitted `/api/host-tip/pay`. The banner no longer calls that a closed switch when payments are on. Taking the money needs a backend pay route and an owner decision. |

## Gates

`check_scaffold.py` PASS · `contract_ratchet.py --check` 46 failing, baseline 46, **new 0** · `check_design_consistency.py` PASS · `check_a11y_lint.py` 0 new · `check_appsession_ratchet.py` PASS (7977). No `String(localized:)` added. No secrets, deploys, or SQL.
