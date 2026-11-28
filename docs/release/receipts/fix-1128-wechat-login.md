# fix/1128-wechat-login — P0-5 WeChat sign-in, P1-1 app-side link handling

Branch `fix/1128-wechat-login` from `origin/ui/combined-r7`. Audit: `origin/audit/1128-functions:docs/audits/1128-functions.md`.
Backend reference: hengyin `origin/us/r3-functional` `ApiLoginController.loginWechatApp` (`:634-770`). Not compiled here
(no Swift toolchain in this environment); Swift-free gates below.

## Receipt rows

| Audit item | Change | Evidence (file:line) | Test |
|---|---|---|---|
| P0-5 gate | `WeChatAppAuthGate` is derived on every use from facts: SDK linked, owner configuration valid, reviewed China legal catalog, Sign in with Apple live (App Store 4.8), exchange wired. Defaults stay false | Core/WeChatAppLaunch.swift `gate(...)`; App/AppSession.swift:3410; App/AppSession+AppLinks.swift `weChatReleaseGate` | `WeChatAppLaunchTests.testGateOpensOnlyWhenEveryFactHolds` |
| P0-5 SDK configuration | `weChatSDKConfiguration` = `WeChatAppLaunch.bundleConfiguration()`: AppID + Universal Link from `QUESTIFY_WECHAT_APP_ID` / `QUESTIFY_WECHAT_UNIVERSAL_LINK` (Config/OwnerValues.xcconfig → Info.plist). Callbacks `wx<AppID>://oauth` and `https://www.chengyinhub.com/app/<AppID>/oauth`. The placeholder is rejected, so the button stays hidden | App/AppSession.swift:3409; Core/WeChatAppLaunch.swift; Config/OwnerValues.xcconfig; Config/Info.plist | `testOwnerValuesBuildSchemeAndUniversalLinkCallbacks`, `testPlaceholderEmptyAndMalformedValuesGiveNoConfiguration` |
| P0-5 exchange | `WeChatAppAuthService` is injected into `weChatAuth` (`service: weChatExchangeService`): `POST api/login/wechat/app`, multipart `code`, no Authorization, then `api/userInfo` read-back before the guarded commit. Matches `loginWechatApp(String code)`; the response `{code, token, data, linkedMiniProgram}` decodes | App/AppSession.swift:3421; App/AppSession+AppLinks.swift `weChatExchangeService`; Core/WeChatAppAuth.swift:82-102 | `testExchangeRequestMatchesBackendFieldsAndDecodesLinkedAccount`, `testBackendRefusalsAreNotSignIns`; existing `WeChatAppAuthTests.testExactAppMultipartAndUserInfo` |
| P0-5 composition firewall | `CompositionHTTPTransport` admitted only phone/Apple auth; it now admits the exact one-field `code` multipart to `api/login/wechat/app` under `weChatSignInApproved` (= the reviewed China Apple/SMS grant). Line count unchanged (ratchet) | App/AppCompositionRoot.swift:2689,2718-2720,3623,3918-3936 | contract ratchet |
| P0-5 URL types | `CFBundleURLTypes`: `weixin` → `$(QUESTIFY_WECHAT_APP_ID)`, `chein` → `chein`. `LSApplicationQueriesSchemes`: weixin, weixinULAPI, weixinURLParamsAPI, alipay | Config/Info.plist:13-17 | test_universal_link_associated_domains |
| P0-5 callbacks | `onOpenURL` → `receiveNativeURL` → payment driver, then `weChatSDKDriver.handle` (unchanged order). `onContinueUserActivity` → `receiveUniversalLink`: WeChat payment/auth drivers claim first (`receiveWeChatUserActivity` now returns Bool), then the link router | App/AppSession.swift:7193-7203; App/MPParityDeepLinkEntry.swift:75-78 | test_account_marketing_entry_integration |
| P0-5 installed only | Button renders only when `isOffered` (gate + `WXApi isWXAppInstalled && isWXAppSupportApi` + service); `canOpenURL` works because the query schemes are declared | Core/WeChatAppAuth.swift:118; App/WeChatAppAuthSection.swift:25-29; App/QFWeChatSDKBridge.m:36-43 | — |
| P0-5 SDK linking | The official SDK cannot be vendored by this lane. `tools/generate_project.py` links `Vendor/WechatOpenSDK/WechatOpenSDK.xcframework` when present (+ `-ObjC -lc++ -lz -lsqlite3`, WebKit, Security, CoreGraphics); `QUESTIFY_WECHAT_SDK_APPROVED` (Base.xcconfig, default 0) feeds `GCC_PREPROCESSOR_DEFINITIONS` for App/QFWeChatSDKBridge.m | tools/generate_project.py; Config/Base.xcconfig | test_wechat_sdk_adapter |
| P0-5 P33 layout | CN: WeChat (prominent, when shown) → phone +86 → Sign in with Apple. US: Sign in with Apple → phone +1. Only the first method is prominent; system `ASAuthorizationAppleIDButton` at 50 pt; terms stay in the footer | App/LoginView.swift:125-145, 99-121; App/WeChatAppAuthSection.swift | test_auth_entry_parity, design consistency |
| P0-5 `region.usLoginPending` | No view referenced it any more; the catalog entry is removed | Resources/Localizable.xcstrings | check_scaffold (bilingual keys 21275 → 21274) |
| P0-5 same member as the MP | The app sends the Open Platform `code` with `scope = snsapi_userinfo`; the backend resolves `app_open_id` → `union_id` → `wx_open_id`. **Backend gap:** MP `/api/login/code` (ApiLoginController.java:188-207) never stores `union_id`, so the `union_id` step cannot find MP members yet. Listed in docs/release/owner-values.md for the backend lane | Core/WeChatAppAuth.swift:43; hengyin ApiLoginController.java:188-207,671-705 | — |
| P1-1 entitlement | `Config/QuestifyAssociatedDomains.entitlements` = the current entitlements + `applinks:www.chengyinhub.com`. The app target signs with `$(QUESTIFY_APP_ENTITLEMENTS_$(QUESTIFY_ASSOCIATED_DOMAINS))`; default `NO` keeps the current file, so signing works until the owner registers the capability | Config/Base.xcconfig; tools/generate_project.py; Questify.xcodeproj | test_entitlements_contract, test_universal_link_associated_domains |
| P1-1 verified origin | `verifiedHTTPSOrigins` = `https://` + `QUESTIFY_APP_LINK_DOMAIN` (default `www.chengyinhub.com`) | App/AppSession.swift:7091; App/AppSession+AppLinks.swift `verifiedLinkOrigins` | `testOriginComesFromThePlainDomainSetting` |
| P1-1 routing | `AppUniversalLinkRouter`: `/app/activity|topic|club|template|post/<id>` → content page; `/app/club/<id>/join`, `/app/ticket/<id>`, `/app/roam/go`, `/app/landing?…`, referral/gift/seat → `CheinDeepLink` → `pendingDeepLink` → `replayDeepLink`; `/app/mp/…`, `/app/pages/…` → mini-program router; today's `/pages/…` shares → `NativeEntryLinkPolicy`; `/app/wx<AppID>/…` is never routed. `chein://activity/12` etc. open the content page | Core/AppUniversalLinkRouter.swift; App/AppSession+DeepLink.swift:10-12; App/AppSession+AppLinks.swift `receiveAppLink` | `AppUniversalLinkRouterTests` (6 tests) |
| P1-1 AASA | `docs/release/aasa-template.json`: `TEAMID.com.chengyinhub.chengyinApp`, `/app/*` first, then the share paths of `docs/release/aasa.json` | docs/release/aasa-template.json | — |

## Owner actions (docs/release/owner-values.md)

1. WeChat Open Platform: register the iOS app with Universal Link `https://www.chengyinhub.com/app/`, bind it and the
   mini-program to one Open Platform account, put the mobile-app AppID in `QUESTIFY_WECHAT_APP_ID`, and the AppID/AppSecret
   in backend `app.wechat.app.appid/appsecret`.
2. Download the official WechatOpenSDK XCFramework into `Vendor/WechatOpenSDK/`, set `QUESTIFY_WECHAT_SDK_APPROVED = 1`,
   run `python3 tools/generate_project.py`.
3. Enable Associated Domains on the App ID, host the AASA (TEAMID → `9VHY8N755R`), set `QUESTIFY_ASSOCIATED_DOMAINS = YES`.
4. Backend lane: store `unionid` in `/api/login/code` so app and MP accounts converge.

## Not done / notes

- No new UI strings were needed (existing `auth.wechat.*` keys). The "Signed in with your mini-program account" note
  (owner 04:30 item 3) is not shown: the backend returns `linkedMiniProgram`, but the account sync itself depends on the
  backend gap above.
- `cn-pay` (P0-2) sets `QUESTIFY_WECHAT_PAYMENT_SDK_APPROVED`; it should append to `GCC_PREPROCESSOR_DEFINITIONS` with
  `$(inherited)` and can build its config with `WeChatAppLaunch.configuration(..., callbackHosts: ["pay"])`
  (the payment adapter requires the same AppID and Universal Link as sign-in).
- Not compiled or run on a device: no Swift toolchain, SDK binary or real AppID here.

## Gates

- `python3 tools/generate_project.py` — pass
- `python3 tools/check_scaffold.py` — PASS (AppSession 7977/7977, AppCompositionRoot 4175/4175)
- `python3 tools/contract_ratchet.py --check` — 52 failing, baseline 52, new 0
- `python3 tools/check_design_consistency.py` — PASS
- `python3 tools/check_a11y_lint.py` — PASS
