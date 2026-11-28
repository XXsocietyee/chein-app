# K40 · account, sign-in, settings, deletion

Branch `cursor/1128-k40-account` from `origin/ui/combined-r7` @ `a7c956335`. Base for the PR is `ui/combined-r7`. Audits read: `origin/design/handoff-r2:docs/briefs/round3-1127.md`, `origin/audit/1128-functions:docs/audits/1128-functions.md`, `origin/audit/1128-plan:docs/audits/1128-plan.md`, `origin/audit/1128-ada:docs/audits/1128-ada.md`. Only account, sign-in, settings, and deletion rows.

hengyin `https://github.com/XXsocietyee/hengyin` (`us/r3-functional`, intended branch `cursor/1128-be-k40-account`) returned **404** for this token (`gh repo view` and `gh api repos/XXsocietyee/hengyin/branches/us/r3-functional`). No backend branch, no SQL, no deploy. The app diff is the full change.

Counts: **n=16** rows rechecked, **m=11** already closed on this tip, **k=1** closed here with a test. Four rows stay owner-only because the product (or a security pin) is right.

`App/AppSession.swift` stays 7977 lines. `App/AppCompositionRoot.swift` stays 4175. Init order is still `devices`, `sensors`, `artworkHosts`. No `String(localized:)`. Merchant stays behind `PlayerLaunch.merchantCenterEnabled`. Money switches were not edited.

## Already fixed on this tip (m=11)

| Row | What the audit called open | Closed at |
|---|---|---|
| P0-5 WeChat sign-in and the SDK callback | Gate all false, no URL scheme, exchange not injected | `6167f0f7d` The button renders only when the SDK, owner AppID, legal catalog, Apple alternative, and exchange are all true (P27: a gated channel draws nothing). |
| P2-5b Apple full name | `givenName` / `familyName` dropped, so a new Apple account was 城瘾用户 | `1b9caf4ee` |
| P1-16 SMS `errorCode` | `SMS_RATE_LIMITED`, `SMS_DAILY_LIMIT`, `SMS_INTL_NOT_CONFIGURED` collapsed to one message | `22ae6f0b6` |
| P1-15 填写邀请人 | Sheet `enabled: false`, `bindingEnabled: false` | `22ae6f0b6` `bindingEnabled: true`, sheet `enabled: true`, `POST /api/user/setInviter` |
| P2-5a 私人主页 | Row always opened "disabled" | `22ae6f0b6` The row is omitted when `privateHomeCoordinator` is nil |
| P1-14 Settings merchant card | A merchant-role account opened `MerchantOperationsDocumentView` in Release | `22ae6f0b6` `PlayerLaunch.merchantCenterEnabled` gates the route |
| P0-6 / O-13 Apple-only deletion | SMS required, no Apple proof | `fcc8f1e33` (apply body) and `db441a60c` (Sign in with Apple re-auth). Phone accounts still use SMS |
| O-14b 我的邀请 | `profileInviteHistoryReadAccess` nil in Release | `d0dda0166` Production gate `gates.profileInviteHistory(context)` |
| O-21b Me level line | "Lv.N" without 城市探索者 | `894e4a75d` |
| ADA `login-player` | Grey Apple pill; phone-only fixture | `acfe6c8c6` Enabled system `SignInWithAppleButton`; a tap asks for consent. P33 order stands (CN WeChat → phone → Apple; US Apple → phone +1). The earlier ADA request for an inline phone field on this sheet is the older layout; P33 replaced it |
| ADA `e4-settings` avatar/level and `e4-member` merchant rows | Lettermark, a different level string, merchant capability rows on a player | `894e4a75d` and `0f2697fea` Locked merchant benefit rows stay hidden while the merchant center is off |

## Closed here (k=1)

| Row | Loop | Change | Test |
|---|---|---|---|
| O-12 item 3, owner 04:30: after WeChat sign-in, if the server says this is the mini-program account, show one line | `WeChatAppAuthService.Envelope` dropped `linkedMiniProgram`. The nav lane left the note blocked on that field. The launch test already sends the Bool | Decode a Bool only. Missing or non-Bool stays false and still signs in. The flag is copied onto `LoginResult` before `commitAuthenticatedSession`, so the signed-in shell can read it. Phone and Apple keep the default `false`. Logout and session expiry clear it before `account` becomes nil. The line is `auth.wechat.linkedMiniProgram` (en "Signed in with your mini-program account", zh-Hans "已使用小程序账号登录") with a 44 pt dismiss. It does not authorize anything and it does not read `msg` | `WeChatLaunchAndAppLinkTests.testLinkedMiniProgramFlagIsPresentationOnly`, `WeChatAppAuthTests.testCoordinatorForwardsMiniProgramFlagWithoutAuthorizingFromIt`, `test_wechat_app_auth.py` `test_mini_program_note_is_not_authorization` |

## Owner-only (product or security pin is right; not changed)

| Row | Why it stays |
|---|---|
| Phone / WeChat refusal text ("验证码错误或已过期", "账号已被冻结") | `AuthChannelServiceTests.testBusinessAndHTTPFailuresKeepStructuredCodesWithoutRawMessage` and `WeChatLaunchAndAppLinkTests.testBackendRefusalsAreNotSignIns` require a structured code and drop arbitrary `msg`. Typed SMS `errorCode`s are already mapped. Showing the raw server string would weaken that pin |
| 绑定/更换手机号 (`api/getwxbindphone`) | `G2OpsGapTests` and `ConditionPackageClosureTests` pin WeChat phone bind as out (OWN-D-09). The route is a mini-program `code`. No iOS path was added |
| Participants +1 | `ParticipantFormDraft` already accepts a US E.164 number (`PhoneCountryCode.isValidUnitedStatesWire`). The audit's rejection is the backend regex `^1[3-9]\d{9}$`. hengyin is 404 here, so the regex was not patched. Create still sends `isDefault=0`, which is the MP create (`O-17`, kept) |
| US legal text | `SettingsSourceLegalCatalog` returns `.missing(.regionalTextNotProvided)` outside China. CN legal is not shown to the US as if it were the US text. The source text is an owner document |

Also not open player loops, so not in n: Alipay login superseded by the 04:45 correction (`2368e0680`). O-17 create-as-default kept as the MP. O-22 creator apply kept off (no MP page calls `/api/creator/apply`). Settings 通知权限 does not call `registerForRemoteNotifications`; remote push is P1-9 (backend + mp-states), not this loop. WeChat-only deletion still uses the mini-program verification screen: an Open Platform code cannot satisfy mini-program `jscode2session` (apple-delete receipt). The WeChat button stays hidden until the owner AppID, Universal Link, and SDK are present.

Backend still required, not applied (404): store `union_id` on MP `/api/login/code` so `linkedMiniProgram` can become true for a player who already used the mini-program. Until that ships, the note appears only when the server actually sends `linkedMiniProgram: true`.

## Gates

- `python3 tools/check_appsession_ratchet.py` PASS (7977 / 4175)
- `python3 -B tools/contract_ratchet.py --check` — 46 failing, baseline 46, **new 0**
- `python3 tools/check_a11y_lint.py` — 0 new
- `python3 tools/check_design_consistency.py` PASS
- `python3 tools/check_scaffold.py` PASS (21685 bilingual keys, missing 0)
- Account contract tests: `test_wechat_app_auth`, `test_pkg19_login_deletion_chain`, `test_sign_in_with_apple_flow`, `test_deletion_settings_composition`, `test_deregister_index_page_ready`, `test_cn_native_login_contract`, `test_auth_entry_parity`, `test_mine_p1_14_merchant_settings_gate`, `test_adapt5_password_login_off` — 48 tests OK
- No Swift toolchain in this environment, so the new XCTest cases were not executed
