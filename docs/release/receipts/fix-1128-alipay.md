# Receipt: fix-1128-alipay (audit P0-4, Alipay app pay, and the P32 "Pay with" row)

Branch `fix/1128-alipay`, based on `origin/ui/combined-r7`. Backend reference: hengyin `origin/us/r3-functional`
`ApiAlipayPayController.java:48-60` (`/api/pay/alipay/order|query|notify`), `AlipayPaymentService.java:70-122`,
`RegistrationCheckoutServiceImpl.java:96-98` (`APP_ALIPAY` in quote channels). The MP has no Alipay. The behaviour
reference is the MP baoming pay result: paid → ticket in the wallet; cancelled → pay again; unknown → checking.
WeChat Pay in the app shows the same states (`RegistrationAppPayRows`).

## Loop, end to end

| Step | App | Backend |
|---|---|---|
| Offer | `RegistrationAlipayBridge.offered` (`App/RegistrationAlipayPayRows.swift`): the quote or order lists `APP_ALIPAY` **and** the session adapter is configured (money payment switch, money payments open for the API host, CN player/club, owner scheme set) | `attachPaymentChannels` adds `APP_ALIPAY` only when `alipayReady()` |
| Choose | "Pay with" row under 费用明细 (`RegistrationPayMethodSection`, now with `alipayOffered:`) and on the pay step itself (`RegistrationPayStepMethodRow` in `RegistrationPaySection`, also covers order detail). WeChat Pay is the default. Alipay becomes the default only when the backend lists `APP_ALIPAY` without `APP`. | — |
| Button | P32: the button names the method. The checkout bar shows "Pay ¥12.50 with WeChat Pay" or "… with Alipay" (`RegistrationSheetView.payWithLabel`). The pay step shows the WeChat button label, and Alipay's "Pay ¥12.50 with Alipay". | — |
| Order | `AlipayAppPayService.createOrder` → `POST api/pay/alipay/order`, multipart form `id`, member `Authorization` token, through `AppSession.AlipayPayLease` (POST only, expected host, money switch, positive form id) | returns `data.orderString`; failures carry `errorCode` |
| Open Alipay | `AlipaySDKPaymentAdapter` → `AlipayPaymentDriver`: the official SDK (`QFAlipayPaymentBridge`, `QUESTIFY_ALIPAY_SDK_APPROVED=1` + `AlipaySDK.framework`), otherwise `alipay://alipayclient/?{SafePay JSON}` | — |
| Return | `<scheme>://safepay/?…` → `AppSession.receiveNativeURL` → `handleAlipayReturn` → adapter (only while an order waits). With no return URL, coming back to the foreground ends the wait after 1.5 s. | — |
| Confirm | one `POST api/pay/alipay/query` (form `id`) → `RegistrationAlipayResolver.stage` | settles a paid trade whose notify was lost |
| Result | paid → "Paid. Your ticket is in the wallet." + View ticket (wallet sheet focused on the registration); cancelled / Alipay failed / no trade → "Payment cancelled" + Pay again; returned-but-unpaid / unknown → "Checking payment…" + Refresh (one more query); not installed / not configured → warning + "switch to WeChat Pay under Pay with"; `ORDER_EXPIRED` → Rebuild order; 401 → session expired | — |

## Audit rows

| Item | Evidence | Status |
|---|---|---|
| P0-4 Alipay app pay | `Core/AlipayAppPay.swift` (routes, request, decode, stages, URL hand-off, form-id parser); `App/AlipayPaymentDriver.swift`; `App/QFAlipayPaymentBridge.h/.m`; `App/AppSession+AlipayPay.swift` (`AlipayPayHub`, order/query, lease, return hook); `App/AppSession.swift` (1 stored line, 1 URL hook in the existing line, so the AppSession line ratchet does not grow); `App/RegistrationAlipayPayRows.swift`; `App/RegistrationPaySection.swift` (Alipay branch before the WeChat branch, WeChat label only); `App/QuestifyApp.swift` (environment injection); `Core/ChinaReviewedRouteCapability.swift` (grants: order = payment write, query = payment-area read); `Core/RegistrationContracts.swift` (`APP_ALIPAY` counts as an app channel) | done; Release-gated by owner values (below) |
| P32 "Pay with" row | CN: WeChat Pay (default) + Alipay; the button follows the method (`Core/RegistrationAlipayChoice.swift` `effective`, `payButtonKey`). The DEBUG "Coming soon" row shows only while Alipay is not offered. | done |
| No Alipay login (owner 04:45; P1-16 app side) | `grep -r "login/alipay\|AlipayAuthAdapter" App Core` → nothing; pinned by `test_no_alipay_login_anywhere`. LoginView already renders no Alipay row (`App/LoginView.swift:133`). | done (no code left) |

## Tests

- `Tests/CoreTests/AlipayAppPayTests.swift`: request shape (POST, path, no query, token, multipart `id`), money-switch block (no request sent), route grants, order success / error-code mapping / wrong registration, query decode, provider return + query → stage, order outcome → stage, offered rule, effective method, Alipay-only quote is not "payment unavailable", launch URL JSON, return URL `ResultStatus`, form-id parser.
- Existing `Tests/CoreTests/AlipaySDKPaymentAdapterTests.swift` still covers the adapter (gates, scheme, safepay return, timeout).
- `Tests/ContractChecks/test_fix_1128_alipay.py`: wiring, bridge flag, owner placeholder, no Alipay login.

## Gates

`python3 tools/generate_project.py` ✓ · `python3 tools/check_scaffold.py` ✓ (AppSession ratchet unchanged) · `python3 -B tools/contract_ratchet.py --check` new 0 · `python3 tools/check_design_consistency.py` PASS · `python3 -B tools/check_a11y_lint.py` 0 new. No Swift compiler here: new code uses typed helpers and static functions, and every `@State` / `@Environment` it reads is declared.

## Owner values (docs/release/owner-values.md)

`QUESTIFY_ALIPAY_APP_SCHEME` (empty means Alipay is off) · the URL type for that scheme (with `fix/1128-wechat-login`, which owns `CFBundleURLTypes` and the two contract checks that forbid it today) · optional `QUESTIFY_ALIPAY_SDK_APPROVED=1` + the AlipaySDK framework · the backend Alipay keys / `alipay.pay.enabled` (backend lane).

## Notes for the coordinator / siblings

- Shared-file edits are additive. `RegistrationPaySection.swift`: two `@Environment`, one `@State`, the Alipay `else if` before the WeChat branch, the WeChat button label → `weChatPayTitle`, and four computed helpers. `RegistrationSheetView.swift`: one `@Environment`, `alipayOffered:` on the Pay with row, one `.environment(...)`, the CN checkout label, and three helpers.
- Seen while reading, not changed (cn-pay lane): `RegistrationPayBridge.RegistrationPayLease` parses the form body as url-encoded (`URLComponents(string: "?" + text)`), but `AuthRequestBuilder.makeFormRequest` sends multipart. That lease probably refuses every `/api/registration/pay[/app]` request. The Alipay lease uses `RegistrationAlipayFormID`, which reads both formats.
- Not done here: a design fixture / sweep shot of the Alipay rows (no simulator in this environment).
