# Receipt: fix/1128-cn-pay (China registration payment, end to end)

Branch `fix/1128-cn-pay` from `origin/ui/combined-r7`. Items from `origin/audit/1128-functions:docs/audits/1128-functions.md`:
P0-1, P0-2, P1-2, P1-4. Backend reference is hengyin `origin/us/r3-functional`
(`ApiRegistrationController`, `RegistrationCheckoutServiceImpl`, `WechatPaymentSdkGateway`).

No Swift compiler was available here. The Swift unit tests below are written but were **not run**; only the
Swift-free gates ran (results at the end).

## The loop as it now runs

1. **Entry.** In the registration sheet, a priced ticket's checkout button reads "Pay ¥12.50 with WeChat Pay"
   (P32, mp-activity's label, kept as merged).
2. **Create.** `POST /api/registration/create` with a JSON `RegistrationRequest` that now carries `payChannel: "APP"`
   for a paid quote (a free quote sends no channel). The backend's `isAppChannel` → `finishOrder` →
   `createWechatOrder(…, appChannel=true)` returns `data.payParams`, the seven APP keys
   `appId, partnerId, prepayId, packageValue, nonceStr, timeStamp, sign`.
3. **Pay.** The create's `payParams` go straight to the session's `WeChatSDKPaymentAdapter`, as in MP baoming
   (create → `wx.requestPayment`). Any later pay, from the sheet's recovered order or from order detail, sends
   `POST /api/registration/pay/app` with the multipart form field `id` (`payApp(String id)`).
4. **Result.** When WeChat returns, the app reads `POST /api/registration/info` once (no polling). The read decides
   the state:
   - `paymentStatus == 2`: paid. A success haptic plays, a "View ticket" link opens the wallet, and the host
     refreshes (sheet: `readKnownStatus` / `readDurableStatus`; order detail: `load(id:)`).
   - Cancelled or failed in WeChat: "Payment cancelled", a warning haptic, and **Pay again**.
   - Anything else: "Checking payment…" with **Refresh**.
5. **Errors.** A 410 shows the rebuild message. A business error shows the server sentence. A 401/403 expires the
   session (signed-out copy). Timeouts show the unknown outcome and are never retried automatically.

## Items

| Item | What changed | Files |
|---|---|---|
| **P0-1** paid registration blocked | `confirm` blocks a paid quote with `.paymentRequired` only while the payment switch is off (an injectable `paymentsOpen`, default `ReleaseMoneyWriteSwitch.paymentEnabled`). The hard-coded `usesAppPaymentChannel: false` is gone: a paid quote sends `payChannel=APP`, a free one sends none. The free UI path no longer returns `.paymentRequired` while payments are on. The production create lease (`registrationCreateBody`) admits `payChannel == "APP"` and positive amounts only while payment is on; any other channel (JSAPI, XPAY) stays refused. | `Core/RegistrationCoordinator.swift:103-108,129-158,271,278`; `Core/RegistrationUIFlow.swift:165-167`; `App/ReviewedPlayerWriteLeases.swift:70-73,432-447`; `Core/RegistrationUIForm.swift:37`; `App/SessionRegistrationSheet.swift:30`; `App/RegistrationSheetView.swift` (the `.paymentRequired` copy now applies only while payment is off) |
| **P0-2** WeChat Pay end to end | All three call sites already used `RegistrationPayChannel.app`. This branch fixes the rest. (a) **Lease bug:** `RegistrationPayLease` parsed the pay body as URL-encoded, but `RegistrationPayService` sends multipart. Every `pay/app` was refused locally and surfaced as "outcome unknown". The lease now checks the body byte-for-byte against the canonical multipart form (`singlePositiveFormField`). (b) The create's `payParams` open WeChat at once (`initialPayParams`). (c) `weChatPaymentConfiguration` is injected from build settings: `WeChatPaymentBuildSettings` reads `QuestifyWeChatAppID` / `QuestifyWeChatUniversalLink` / `QuestifyWeChatPayMerchantID` from Info.plist and derives the SDK callbacks `wx<AppID>://pay/` and `https://www.chengyinhub.com/app/<AppID>/pay/`. It is used by the session adapter (`AppSession.swift:4366`) and the China session dependencies. (d) `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED` reaches `QFWeChatPaymentBridge.m` through `GCC_PREPROCESSOR_DEFINITIONS` (`Config/China.xcconfig`). The generator links `Vendor/WechatOpenSDK/WechatOpenSDK-XCFramework.xcframework` plus the SDK linker flags when that folder exists. (e) `devicePaymentApproved` follows the payment switch. | `App/RegistrationPaySection.swift` (lease, `initialPayParams`, `startPay`); `App/RegistrationSheetView.swift` (both `RegistrationPaySection(` call sites); `App/OrderLifecycleView.swift:169-180`; `Core/WeChatPaymentBuildSettings.swift` (new); `App/AppSession.swift:4366`; `App/ReviewedPlayerWriteLeases.swift:1441-1444,1470`; `Config/China.xcconfig`; `Config/Info.plist`; `tools/generate_project.py:105-114,124` |
| **P1-2** server-confirmed result | The "支付成功，票已放入票夹" chip shown without any read is removed. A pay response with or without params now goes through `RegistrationAppPayRows`. With no params, nothing opens; one `registration/info` read gives paid or checking. The stage resolver (`RegistrationAppPayResolver`) is unchanged: one read, paid only on `paymentStatus == 2`. The session context is always built, so the read works even when WeChat can't open. `onSettled` refreshes the sheet status / order detail after a paid read. | `App/RegistrationAppPayRows.swift`; `App/RegistrationPaySection.swift:332-334` |
| **P1-4** dead 审核支付 | `OrderLifecycleCoordinator.detailActions(detail:)` drops `.payment` (it always ended in `.dispatchDisabled`; the order's Pay is the pay step). The pinned slot shows the first working action (cancel / refund). While the order awaits payment, the pinned cancel uses the secondary style, so the method-labelled Pay stays the one prominent button. The action list and the DEBUG auto-review use the same list. | `Core/OrderLifecycleCoordinator.swift:246-251`; `App/OrderLifecycleView.swift:119,146-160,299-301,410-421` |
| **P32** pay step | There is one "Pay with" row showing the method (plain text, as in `RegistrationPayMethodSection`, no logos). The button label comes from mp-activity's `RegistrationPayMethod.payTitle` (merged from `ui/combined-r7`, "微信支付 ¥12.50" / "Pay ¥12.50 with WeChat Pay"). Order detail, which has no sheet choice, now defaults to WeChat Pay instead of "立即支付". When WeChat can't open (SDK not linked, AppID/merchant not set, WeChat not installed), a footnote gives the reason instead of a button. Alipay joins the row in `fix/1128-alipay`. | `App/RegistrationPaySection.swift` |
| Payment moment (OWNER RULE 3) | The paid check plays `symbolEffect(.bounce)` with `.sensoryFeedback(.success)`. A cancel plays `.warning`, and "Pay again" retries. | `App/RegistrationAppPayRows.swift` |

New strings (en + zh-Hans) in `Resources/Localizable.xcstrings`: `registration.pay.payWith`,
`registration.pay.weChatNotReady`. Method names and the button title reuse `RegistrationPayMethod.names` /
`payTitle` (zh + en), so there is one source for them.

## Tests

Swift (written, not run here, since there is no compiler):
- `Tests/CoreTests/RegistrationCoordinatorTests.swift`: `testPaidQuoteCreatesWithAppChannelWhenPaymentsOpen` (body has `payChannel: "APP"` and the `quoteSign`, no client amount; create response with params), `testFreeQuoteSendsNoChannelWhenPaymentsOpen`, and `testPaidQuoteDoesNotCreate` (payments off → `.paymentRequired`, nothing sent).
- `Tests/CoreTests/RegistrationUIFlowTests.swift`: `testFreePolicyConfirmsPaidQuoteWhenPaymentsOpen`. The existing payments-off case is kept with an explicit `paymentsOpen: false`.
- `Tests/CoreTests/RegistrationAppPayTests.swift`: the `pay/app` request shape (POST, `/api/registration/pay/app`, no query, multipart `id`, no `payChannel`), refusal while payment is off, APP params kept intact, and a response without params is not paid.
- `Tests/CoreTests/WeChatPaymentBuildSettingsTests.swift`: owner values → config and callbacks; placeholders and malformed values → nil; backend `payParams` → `WeChatSDKPaymentRequest`.
- `Tests/CoreTests/OrderLifecycleTests.swift`: `testDetailActionsSkipReviewSheetPayment`.
- `Tests/AppUnitTests/RegistrationPayLeaseTests.swift`: the canonical multipart `pay/app` passes the lease; an altered body or a query is refused.

Python contract pins updated, each with a one-line reason: `Tests/ContractChecks/test_player_write_grant.py`
(the free-only create pins become the APP-while-payment-on pins) and `Tests/ContractChecks/test_cb97_payment_gating.py`
(`devicePaymentApproved` follows the switch; the build-setting config is injected).

## Gates

- `python3 tools/generate_project.py`: OK
- `python3 tools/check_scaffold.py`: PASS (the AppSession line ratchet is held: net +0 lines)
- `python3 tools/contract_ratchet.py --check`: 52 failing, baseline 52, **new 0**, fixed 0
- `python3 tools/check_design_consistency.py`: PASS
- `python3 tools/check_a11y_lint.py`: PASS (0 new)

## What the owner must supply

See `docs/release/owner-values.md`, section fix/1128-cn-pay:
1. The WeChat Open Platform mobile-app **AppID** → `QUESTIFY_WECHAT_APP_ID`.
2. The WeChat Pay **merchant ID** (`mch_id`) → `QUESTIFY_WECHAT_PAY_MERCHANT_ID`.
3. The official **WechatOpenSDK 2.0.5 XCFramework (with pay)** at `Vendor/WechatOpenSDK/`, then regenerate and set
   `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED = 1`. Binaries are not committed from here.
4. From `fix/1128-wechat-login` (P0-5 / P1-1): the `wx<AppID>` URL type, `LSApplicationQueriesSchemes`,
   `applinks:www.chengyinhub.com` and the AASA file for `/app/*`.
5. Backend: `wx.pay.app-appid` plus the APP merchant key and certificates (audit P1-5).

Until 1–3 are in, the pay step shows the "WeChat Pay can't open on this device yet" footnote. It never shows a dead
Pay button and never shows a success it didn't read from the server.

## Not done / follow-ups (mp-activity)

- No device run: the SDK isn't linked, so a live WeChat payment is NOT_RUN.
- The ticket "slides into the wallet" transition (OWNER RULE 3 payment moment) is not built. The paid row has the
  bounce, the haptic and the wallet link.
