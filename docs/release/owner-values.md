# Owner values

Values only the owner has. Each one is an xcconfig key (or an Info.plist build-setting reference) with an empty
placeholder in the repo. Put the real value in the listed xcconfig, or in the gitignored
`Config/Local.China.xcconfig` for a local build. Never commit a secret: merchant API keys, certificates and
private keys stay on the server.

## fix/1128-cn-pay: WeChat Pay (APP) for China registrations

| Key (xcconfig → Info.plist) | Where | Value | Status |
|---|---|---|---|
| `QUESTIFY_WECHAT_APP_ID` → `QuestifyWeChatAppID` | `Config/China.xcconfig` | WeChat Open Platform **mobile app** AppID (`wx…`). It must be the same AppID the backend uses for `trade_type=APP` (`wx.pay.app-appid`, audit P1-5). | **owner to supply** (empty) |
| `QUESTIFY_WECHAT_UNIVERSAL_LINK` → `QuestifyWeChatUniversalLink` | `Config/China.xcconfig` | `https://www.chengyinhub.com/app/` (owner's 9-14 plan). It must match the Universal Link registered on the Open Platform, end with `/`, and be served by the AASA file with `/app/*`. | set |
| `QUESTIFY_WECHAT_PAY_MERCHANT_ID` → `QuestifyWeChatPayMerchantID` | `Config/China.xcconfig` | WeChat Pay merchant ID (`mch_id`, digits). The app checks that `payParams.partnerId` is this merchant before opening WeChat. Comma-separate if there is more than one. | **owner to supply** (empty) |
| `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED` | `Config/China.xcconfig` | `0` until the SDK below is in place, then `1`. Passed to Objective-C as a preprocessor define for `App/QFWeChatPaymentBridge.m`. | `0` |

With an empty AppID or merchant ID, `WeChatPaymentBuildSettings.current` is nil and the app shows the
"WeChat Pay can't open on this device yet" footnote instead of a Pay button. It never opens a half-configured SDK.

### WechatOpenSDK binary (not committed)

The repo does not vendor third-party binaries. To link the SDK:

1. Download the official OpenSDK 2.0.5 XCFramework with pay
   (`https://dldir1.qq.com/WechatWebDev/opensdk/XCFramework/OpenSDK2.0.5.zip`, the archive recorded in
   `docs/wechat-sdk-adapter/source-evidence.json`). Do not use the `_NoPay` build.
2. Put it at `Vendor/WechatOpenSDK/WechatOpenSDK-XCFramework.xcframework`.
3. Run `python3 tools/generate_project.py`. The generator then links it and adds
   `-ObjC -all_load -lc++ -lz -lsqlite3 -framework WebKit -framework Security -framework CoreGraphics`.
4. Set `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED = 1` in `Config/China.xcconfig`. Then update the contract checks
   that pin "no SDK, flag 0" (`Tests/ContractChecks/test_wechat_payment_adapter.py`,
   `test_wechat_sdk_adapter.py`); they are guards for the unlinked state.

### Shared with fix/1128-wechat-login (P0-5 / P1-1)

WeChat Pay also needs the items that branch owns, so they are not added here:

- `CFBundleURLTypes` with the URL scheme `wx<AppID>` (the SDK's fallback return route `wx<AppID>://pay/`);
- `LSApplicationQueriesSchemes`: `weixin`, `weixinULAPI`, `weixinURLParamsAPI`;
- the associated-domains entitlement `applinks:www.chengyinhub.com` and the AASA file serving `/app/*`.

### Server side (not app values)

- `wx.pay.app-appid`, the APP merchant key and certificates in the backend config (audit P1-5, needs a deploy check).

## From fix/1128-alipay


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
