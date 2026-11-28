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
