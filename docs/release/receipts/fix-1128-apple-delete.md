# Receipt: fix-1128-apple-delete (P0-6 Apple account deletion, P2-5 Apple full name)

Source: `origin/audit/1128-functions:docs/audits/1128-functions.md`, items P0-6 and P2-5 (Apple full name only).
Worker: apple-delete. Date: 2026-11-28. Nothing deployed and no SQL run. `main` is untouched in both repos.

## Branches

| Repo | Branch | Base |
|---|---|---|
| hengyin (backend) | `fix/1128-apple-delete` | `origin/us/r3-functional` |
| chein-app (iOS) | `fix/1128-apple-delete` | `origin/ui/combined-r7` |

## P0-6: deleting a Sign-in-with-Apple account (App Store 5.1.1(v))

### How the flow runs end to end
1. **Entry.** Settings → 账号注销. The notice step runs the read-only precheck.
2. **Precheck.** `POST /api/user/deregister/precheck` returns `verificationMethod`. The backend picks it in this order: `SMS` if the account has a phone, `WECHAT` if it has a WeChat openid, `APPLE` if it has an appleId, otherwise `UNAVAILABLE`. `APPLE` is new.
3. **Re-authentication.** For `APPLE`, the verify step shows the system Sign in with Apple button (`.continue`, no scopes) instead of 获取验证码. A successful sheet gives `identityToken` and `authorizationCode`. These stay in memory only (`DeregistrationAppleProof`), and the screen moves to the review step.
4. **Exact backend fields.** `POST /api/user/deregister/apply`, form-urlencoded: `requestId`, `identityToken`, `authorizationCode`. Only one proof is ever sent, so an Apple request never carries `smscode` or `wxcode`.
5. **Server check.** `ApiAccountDeregistrationController.apply` checks that the account has no bound phone and that `member.appleId` is set. It then verifies `identityToken` with `AppleIdTokenVerifier.verify(token, apple.clientId)`, the same verifier `/api/login/apple` uses (signature, iss, aud, exp). It also requires `sub == member.appleId` and `iat` no more than 10 minutes old. A bound phone always forces SMS, so an Apple token cannot skip SMS. Consent, the `requestId` check and the PENDING-replay rules are unchanged.
6. **Result handling.**
   - `PENDING`: the step goes to `.freshLogin`, then `invalidateSession` calls `AppSession.expireIfMatching`, the same sign-out and credential clearing that phone accounts already get.
   - `BLOCKED`: the blockers list is shown.
   - Explicit refusal (`code != 200` with a `msg`): the screen goes back to verify with a clear error. Apple accounts see `compliance.apple.reauthRejected`; SMS accounts see the server text. A new requestId is minted.
   - Transport failure: `.unknown`, which is the existing recovery path.
   - The user cancelling the Apple sheet is silent. Any other Apple failure shows `compliance.apple.reauthFailed`.
7. **Phone accounts** keep the SMS flow exactly as it was.

### WeChat-only accounts (`wxcode`)
The request builder still sends `wxcode` when it is given one. It is unchanged and its test is pinned. But the backend checks `wxcode` with **mini-program** `jscode2session` against `wx_open_id`. A native iOS app can only get an Open-Platform OAuth code, which that check rejects. So the app keeps showing the existing "verify in the mini-program" screen for `WECHAT`. Sending a code the server is guaranteed to reject would be a fake path. See owner action 4.

### Backend files (hengyin)
- `chengyinhub-admin/.../api/ApiAccountDeregistrationController.java`: the six-argument HTTP `apply` (adds `identityToken` and `authorizationCode`), `verifyAppleReauthentication`, and the overridable `verifyAppleIdentityToken`. The four-argument and three-argument Java overloads are kept.
- `chengyinhub-system/.../impl/AccountDeregistrationServiceImpl.java`: precheck now reports `APPLE`.
- Tests:
  - `ApiAccountDeregistrationControllerTest` has 7 new cases: Apple-only success, wrong `sub`, a stale `iat`, a bad signature, a missing token, a bound phone that cannot bypass SMS, and a missing `apple.clientId` (fails closed).
  - `AccountDeregistrationServiceImplTest` now has an `APPLE` precheck assertion.

### App files (chein-app)
- `Core/AccountComplianceContracts.swift`: new `DeregistrationAppleProof`; `verificationAvailableOnThisDevice` now accepts `APPLE`; new `verifiesWithApple`.
- `Core/DeregistrationStatusRules.swift`: new `Verification.apple`.
- `Core/MPGap/AccountPublish/AccountPublishGapModels.swift`: `deregisterApplyRequest(…, appleProof:)` with exactly one proof; the precheck parser accepts `APPLE`; new `deregisterApplyRefusal(from:)`.
- `Core/AccountComplianceService.swift`: `apply(…, appleProof:)`. The reviewed original client is SMS-only and refuses an Apple proof.
- `Core/AccountComplianceCoordinator.swift`: `prepareAppleReview`, `noteAppleReauthFailed`, `reviewedAppleProof`, `hasReviewProof`, `adoptContractApply(_:refusal:intent:)`. Precheck now also allows `.apple`.
- `App/DeregistrationAppleReauthSection.swift` (new): the verify section with `SignInWithAppleButton`.
- `App/AccountComplianceViews.swift`: the verify step branches on `APPLE`, the contract-lane apply sends the Apple proof and handles a refusal, and the error title and retry are adjusted.
- `Resources/Localizable.xcstrings`: `compliance.apple.title`, `.lead`, `.failedTitle`, `.reauthFailed` and `.reauthRejected`, each in en and zh-Hans.
- Tests:
  - `Tests/CoreTests/AccountDeregistrationAppleReauthTests.swift` (new, 7 tests): method parsing, proof validation, exact apply body, refusal parsing, the service path ending in sign-out, Apple refused for SMS accounts, and the contract-lane refusal followed by success.
  - `AccountDeregistrationParityTests`: now asserts `APPLE` is usable.

## P2-5: keeping the Apple full name on first sign-in
- Backend `ApiLoginController.loginApple(identityToken, givenName, familyName)` uses the name only when it creates a new account; existing accounts are untouched. Chinese names read family then given with no space (张三); Latin names read given, space, family (Jane Doe). Control characters are stripped, the name is capped at 30 characters, and an empty name falls back to 城瘾用户. The one-argument overload is kept.
  - New test: `ApiLoginControllerAppleNameTest` (5 cases).
- App: `AuthChannelServing.loginWithApple(identityToken:givenName:familyName:)` has a default that existing mocks fall back to. `AuthChannelService` sends multipart `givenName` and `familyName` only when they are non-empty (trimmed, at most 30 characters). `AuthChannelCoordinator`, `AuthChannelModel` and `AuthChannelAppleButton` pass along `credential.fullName`.
  - New test: `AuthChannelServiceTests.testAppleLoginForwardsFirstAuthorizationNameParts`.

## Verification
- Backend: Maven ran `-pl chengyinhub-admin -am test` for `ApiLoginController*Test`, `ApiAccountDeregistrationControllerTest` and `AccountDeregistrationServiceImplTest`: 74 tests, 0 failures, 0 errors.
- App (no Swift compiler here; reviewed by hand against neighbouring patterns):
  - `python3 tools/generate_project.py`: OK (4117 sources).
  - `python3 tools/check_scaffold.py`: PASS (5305 Swift files, 21280 bilingual keys).
  - `python3 -B tools/contract_ratchet.py --check`: 52 failing, baseline 52, **new 0**. The stale guard pin in `Tests/ContractChecks/test_pkg19_login_deletion_chain.py` was updated, with a one-line reason, to the new `hasReviewProof` guard.
  - `python3 tools/check_design_consistency.py`: PASS.
  - `python3 -B tools/check_a11y_lint.py`: PASS (0 new).
  - `python3 tools/check_missing_string_keys.py`: 0 missing, 0 incomplete locales.
  - `tools/check_swift_syntax.py` (Tree-sitter, run in a venv): every touched or new Swift file parses clean. The one diagnostic it reports, `App/AccountComplianceViews.swift:197`, is the existing `Label { … } // comment` line and appears identically on the base branch.
  - `Tests/ContractChecks` `test_deregister_index_page_ready`, `test_sign_in_with_apple_flow`, `test_us_apple_client_contract` and `test_pkg19_login_deletion_chain`: OK.
  - These failed for reasons unrelated to this change: `tools/check_account_deletion_path.py` fails identically on `origin/ui/combined-r7` (US production URL and realm configuration), and `tools/check_account_compliance.py` needs an external `/home/user/app-audit` checkout that is not here.

## Owner actions
1. **Deploy the backend before or with the app.** Until the backend is deployed, precheck never returns `APPLE`, so Apple accounts still see "verification unavailable" (no regression). No migration is needed because `ums_member.apple_id` already exists.
2. **Check `apple.clientId`** in sys_config. It is the bundle ID that `/api/login/apple` already uses. If it is empty, deletion fails closed with "Apple登录未配置".
3. **Revoking the Apple token is not built yet.** The codebase has no Sign in with Apple client-secret flow (no .p8 key, team ID or key ID). The app already sends `authorizationCode`. To revoke, provide the Sign in with Apple key (.p8, Key ID, Team ID) as server secrets, not in git. A follow-up can then exchange the code at `https://appleid.apple.com/auth/token` and call `/auth/revoke` on apply. Apple recommends doing this.
4. **WeChat-only accounts on iOS.** For the app to delete these natively, the backend would need to accept an Open-Platform app OAuth code (`sns/oauth2/access_token` with the app's appid and secret, matched on `app_open_id`), plus the WeChat SDK sign-in lane switched on. That is a product decision. Today those users delete in the mini-program, which is what the app tells them.
5. **Check multipart charset** on the deployed server: a Chinese `givenName` should arrive as UTF-8 (Spring's default `CharacterEncodingFilter`). One manual Apple sign-up with a Chinese name confirms it.
