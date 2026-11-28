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

## From fix/1128-us-pay

# Owner-only values
Values the app or backend cannot invent. Each row says where the value goes and its placeholder. Secrets are never committed;
backend secrets go in the deployment's environment / `application-*.yml` overrides, not in git.
## US payment: Stripe + Apple Pay (fix/1128-us-pay, audit P0-3 / P1-3)
| Value | Where | Placeholder / current | Notes |
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

## From fix/1128-wechat-login

# Owner values (build settings the app cannot invent)
All values are public identifiers. No secret, key or password goes into an xcconfig or the repo.
The defaults keep every dependent feature hidden, so a build with placeholders still signs, archives and runs.
| Build setting | File | Default | Real value / what the owner does | Unlocks |
|---|---|---|---|---|
| `QUESTIFY_WECHAT_APP_ID` | `Config/OwnerValues.xcconfig` | `chein-wechat-unset` (rejected by `WeChatAppLaunch`, button hidden) | The **mobile-app** AppID from the WeChat Open Platform (开放平台 → 移动应用, starts with `wx`). It is **not** the mini-program AppID (`wxdf8f…`). It also fills the `weixin` URL scheme in `Config/Info.plist` | P0-5 WeChat sign-in |
| `QUESTIFY_WECHAT_UNIVERSAL_LINK` | `Config/OwnerValues.xcconfig` | `https://www.chengyinhub.com/app/` (owner plan 9-14) | Register exactly this Universal Link for the iOS app on the Open Platform. It must end in `/` | P0-5 (the SDK returns to `/app/<AppID>/oauth`) |
| `QUESTIFY_APP_LINK_DOMAIN` | `Config/OwnerValues.xcconfig` | `www.chengyinhub.com` | Host name only. Change it only if the AASA moves | P1-1 link routing (`AppUniversalLinkRouter`) |
| `QUESTIFY_WECHAT_SDK_APPROVED` | `Config/Base.xcconfig` | `0` | Set `1` **after** placing the official Tencent `WechatOpenSDK.xcframework` (open.weixin.qq.com → 资源下载 → iOS, XCFramework) at `Vendor/WechatOpenSDK/WechatOpenSDK.xcframework` and re-running `python3 tools/generate_project.py` (it then links the framework with `-ObjC -lc++ -lz -lsqlite3`, WebKit, Security, CoreGraphics). Both keys are needed; either alone keeps the button hidden | P0-5 |
| `QUESTIFY_ASSOCIATED_DOMAINS` | `Config/Base.xcconfig` | `NO` (`Config/Questify.entitlements`) | `YES` **after** enabling Associated Domains on App ID `com.chengyinhub.chengyinApp` (developer.apple.com → Identifiers) and hosting the AASA file below. `YES` signs with `Config/QuestifyAssociatedDomains.entitlements` (`applinks:www.chengyinhub.com`) | P1-1 Universal Links, and the WeChat Universal Link handshake |
## Files the owner deploys (outside this repo)
- `docs/release/aasa-template.json` → `https://www.chengyinhub.com/.well-known/apple-app-site-association`
  (also at `/apple-app-site-association`). Replace `TEAMID` with `9VHY8N755R` (Release `DEVELOPMENT_TEAM`).
  Serve it as `application/json`, over HTTPS, no redirect, no `.json` extension. It claims `/app/*` (app links and the
  WeChat callbacks) plus the mini-program share paths the app already routes.
## Backend values (sys_config, not in the app)
- `app.wechat.app.appid` = the same mobile-app AppID as `QUESTIFY_WECHAT_APP_ID`.
- `app.wechat.app.appsecret` = its AppSecret (backend only).
- Bind the iOS app **and** the mini-program to the same Open Platform account (开放平台 → 管理中心 → 绑定小程序).
  Only then does WeChat return a `unionid`, and `ApiLoginController.loginWechatApp` lands the app sign-in on the
  mini-program member (`app_open_id` → `union_id` → `wx_open_id`).
- **Backend gap (not app-side):** `/api/login/code` (MP, `ApiLoginController.java:188-207` on `us/r3-functional`) reads
  only `openid` from `jscode2session` and never writes `union_id`. Until it stores the returned `unionid` (and existing MP
  members log in once more), the `union_id` lookup finds no MP member and an app WeChat sign-in creates a new account.

## fix/1128b-play: upload-result / kit artwork origins

| Key (xcconfig → Info.plist) | Where | Value | Status |
|---|---|---|---|
| `QUESTIFY_IMAGE_ORIGINS` → `CYStampImageOrigins` | `Config/OwnerValues.xcconfig` | Comma-separated https origins that `api/common/uploadOSS` returns (OSS bucket / CDN host). Used by avatar, stamp, IM image, play photo upload and, since fix-1128b #22, play kit artwork (`artworkHosts`). The API origin is always included. Write each URL as `https:/$()/host`. | **owner to supply** (empty = API origin only) |

## fix/1128c-ai-showcase: AI on the home page and in the build process

No new app-side secret. The app switches the creator AI routes on in Release; the backend decides with its own values.

| Value | Where | Status |
|---|---|---|
| AI provider key and model for `ApiAiController` (theme draft, template fill, safety precheck, club design) | backend `sys_config` / env (us/r3-functional) | **owner to confirm** it is set on the production host; without it every call answers with the server's own message, the precheck degrades to pass |
| Daily AI quota per member (`今日AI次数已用完`, shared by all creator AI endpoints) | backend `sys_config` | **owner to confirm** the value (the app shows the server's count and wording) |
| AIGC filing number (算法备案号) shown under every AI tool (`AIGCFilingNumberText`) | read from the backend (`squareReader.aigcFilingNumber()`, App/CloudB3Production.swift:90) | **owner to set server-side**; empty renders nothing |
| Home showcase copy (`aiShowcase.guide.*`, 24 lines, en + zh-Hans) | `Resources/Localizable.xcstrings` via `tools/add_fix_1128c_ai_showcase_localizations.py` | placeholder copy written by the worker; **owner to revise** (content, not code) |

## fix/1128c-ai-weather: Apple WeatherKit (temperature chip, day / night, weather outside the backend provider)

| Key (xcconfig → Info.plist) | Where | Value | Status |
|---|---|---|---|
| `CY_WEATHERKIT_ENABLED` → `CYWeatherKitEnabled` | `Config/OwnerValues.xcconfig` | `YES` once the two steps below are done; `NO` keeps the backend weather only (`api/map/weather` + `api/play/environment`). | `NO` (owner to switch) |
| WeatherKit capability | developer.apple.com → Identifiers → the app's App ID → Capabilities **and** App Services → WeatherKit | Enable both (the App Services checkbox can take ~30 min to propagate). | **owner to do** |
| `com.apple.developer.weatherkit` = `true` | `Config/Questify.entitlements` | Add after the capability exists, then regenerate the provisioning profile. Not committed: an entitlement the profile lacks breaks Release signing. | **owner to add** |

With the switch on, the chip shows the temperature (°C / °F by locale), the scene uses Apple's day / night, and the
Apple Weather mark with its legal link appears under the chip wherever an Apple value is shown (WeatherKit attribution
rule). Any WeatherKit error (missing entitlement, no network, quota) is silent: the app falls back to the backend reading
and the sun-position light. WeatherKit includes 500,000 calls / month with the developer membership; the app asks at
most once per ~5.5 km cell per ten minutes, with the cell centre only. Backend values: none (the Tencent weather key for
`MapWeatherServiceImpl` / `TencentTopicWeatherProvider` is already a backend config).
