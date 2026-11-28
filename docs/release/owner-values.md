# Owner-only values

Values the app cannot invent. Each one is an empty placeholder in a tracked xcconfig. Set the real value in the
git-ignored `Config/Local.China.xcconfig` (or `Config/Local.China.<Environment>.xcconfig`). Never commit secrets:
the app holds no private key, merchant key or app secret. Signing stays on the backend.

## Alipay app pay (fix-1128-alipay, audit P0-4)

| Setting | Where | Value | Effect while empty |
|---|---|---|---|
| `QUESTIFY_ALIPAY_APP_SCHEME` | `Config/Base.xcconfig` → Info.plist `QuestifyAlipayAppScheme` | The app's own URL scheme that Alipay returns to, e.g. `chengyinalipay` (letters first; letters, digits, `.`, `-`, `+`). | Alipay stays off: the "Pay with" row lists WeChat Pay only. |
| URL type for that scheme | `Config/Info.plist` `CFBundleURLTypes` (owned by `fix/1128-wechat-login`, which adds the URL types and updates the two contract checks that forbid them today) | One entry with `CFBundleURLSchemes = [$(QUESTIFY_ALIPAY_APP_SCHEME)]`. | Without it Alipay cannot jump back on its own. The pay step still confirms: when the player switches back by hand, it ends the wait and reads `/api/pay/alipay/query`. |
| `LSApplicationQueriesSchemes` | `Config/Info.plist` | Add `alipay` and `alipays` (needed only by the SDK's installed-app check). | The URL hand-off still works; `UIApplication.open` reports when Alipay is not installed. |
| `QUESTIFY_ALIPAY_SDK_APPROVED=1` | `GCC_PREPROCESSOR_DEFINITIONS` in `Local.China.xcconfig` plus the official `AlipaySDK.framework` / `AlipaySDK.bundle` added to the app target | Optional. Turns on the official SDK path in `App/QFAlipayPaymentBridge.m`. | The app uses the `alipay://alipayclient/?…` URL hand-off with the same server-signed `orderString`. |

The backend side is separate: `alipay.pay.enabled`, the Alipay Open Platform app id, the app private key and the
Alipay public key live in hengyin `AlipayPayProperties` (backend lane, `us/r3-functional`). While they are unset,
`/api/pay/alipay/order` answers `ALIPAY_NOT_CONFIGURED` and the quote does not list `APP_ALIPAY`, so the app never
offers Alipay.

No Alipay sign-in: owner decision 11-28 04:45. The app has no `api/login/alipay*` caller.
