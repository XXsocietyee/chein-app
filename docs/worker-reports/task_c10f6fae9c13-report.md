# G1 — Open Production Gates (Account, Consent, Sign-In, Wallet, Orders/Addresses/Favorites/Coupons, G2 Hook)

- **Task ID**: `task_c10f6fae9c13`
- **Dispatch ID**: `ctx_1cd0a71e76a7`
- **Branch / Worktree**: `liboyang42-cpu/g1-gates` (`/Users/fanning/orca/workspaces/native-ios/g1-gates`)
- **Owned Files**: `App/AppSession.swift`, `App/AppCompositionRoot.swift`, `App/RegionalLaunchConfiguration.swift`

---

## 1. Summary of Changes by Deliverable

### (1) In-App Account Deletion End to End (App Store 5.1.1(v))
- **`App/AppCompositionRoot.swift` & `App/RegionalLaunchConfiguration.swift`**:
  - Added `productionGatesEnabled: Bool` and `allowLoginRoleFallbackOnRolelessUserInfo: Bool` to `ReviewedAppDeployment` (both defaulting to `false` so `.unconfigured` and existing unit tests remain untouched).
  - Added `RegionalLaunchConfiguration.reviewedDeployment(...)` and `RegionalLaunchConfiguration.reviewedComposition(...)` so an explicit reviewed CN deployment can be constructed with an injected base URL (`example.com` in tests or gitignored `Config/Local.*.xcconfig` in local runs; never hardcoded in source).
  - Added `AccountComplianceCompositionRoute` in `CompositionHTTPTransport` to permit canonical `/api/user/deregister/status`, `/api/user/deregister/precheck`, `/api/user/deregister/apply`, `/api/user/deregister/cancel`, `/api/compliance/consents`, and `/api/compliance/consents/latest` when `deployment.productionGatesEnabled` is true.
- **`App/AppSession.swift` & `Core/AccountComplianceCoordinator.swift`**:
  - Added `makeReviewedAccountComplianceService(configuration:journal:)` and `ReviewedComplianceRoamEffects` when `composition.isAccountComplianceEnabled` is true, while preserving the default-closed `AccountComplianceService(..., readsEnabled: false, writesEnabled: false, legalApproved: { _, _ in false })` fallback when unconfigured.
  - Preserved post-invalidation `.freshLogin` / `.completed` confirmation state via `restorePostInvalidationConfirmation(step:status:)` so the user sees the confirmation screen after session invalidation/sign-out.

### (2) Legal/Agreement Text + Consent Withdrawal
- **`Core/SettingsLegalContracts.swift`**:
  - Populated `SettingsSourceLegalCatalog.privacyPolicy` with real bilingual (`zh-Hans` + `en`) privacy policy sections (`v2.1`, matching `UsageConsentDocument.privacyPolicy.currentVersion`).
  - Enabled `SettingsBundledLegalReader(privacyPolicyApproved: reviewed?.legalCatalogApproved == true)` under reviewed CN deployment while keeping `defaultPrivacyPolicyApproved = false` as the safe default.
- **`App/PrivacyProtectionView.swift` & `Resources/Localizable.xcstrings`**:
  - Wired app-level usage consent status and withdrawal (`UsageConsentPolicy.decline()`) directly in `PrivacyProtectionView` (`privacy.usageConsent.withdraw.action` with confirmation dialog), alongside roam location consent withdrawal (`AccountComplianceCoordinator.revokeRoam`) and merchant marketing consent withdrawal (`AccountComplianceCoordinator.setMarketing`).
  - Wired `UsageConsentReadSourceSelection` and `MerchantMarketingConsentSourceSelection` in `AppCompositionRoot` to issue reviewed defaults when `productionGatesEnabled` is true while still honoring explicit `.revoke()`.

### (3) Apple + SMS Sign-In Composition & `/api/userInfo` Role Fallback Report
- **`App/AppCompositionRoot.swift` & `App/AppSession.swift`**:
  - Enabled `appleConfigurationVerified: reviewed.appleSignInApproved` in `AppSession.authChannels` when `ReviewedAppDeployment.productionGatesEnabled` is true in CN market (`canUseDomesticChinaPhone`), without hardcoding `true` in source.
  - Added `CompositionHTTPTransport.acceptsAppleLogin(_:configuration:)` for canonical `POST /api/login/apple` multipart requests.
  - **Password login stays strictly DISABLED** (`canUsePassword == false`, `AuthChannelService` has no password login method).
- **`/api/userInfo` Role Fallback Investigation & Safe Opt-In (`Core/AuthChannelCoordinator.swift`)**:
  - **Root cause**: Master `SystemUserController.getInfo` (`/api/userInfo`) uses `userInfoView`, which whitelists `userId`, `nickName`, `avatar`, `phonenumber`, `sex`, `userType`, `vipStatus`, `vipExpireTime`, `points`, `balance`, `backgroundImage`, `introduction` and **omits `role`**, whereas `/api/auth/login/phone` (`AuthController`) returns `data.role` (`player` / `club` / `merchant`).
  - **Security invariant**: `Tests/CoreTests/I00SessionAdmissionBaselineTests.swift` (`testMasterUserInfoProjectionWithoutRoleCannotRestoreOrCompleteLogin`) explicitly enforces that by default (`allowLoginRoleFallbackOnRolelessUserInfo == false`), a `/api/userInfo` response without `role` is rejected with `.roleUnresolved`.
  - **Solution**: Added `allowLoginRoleFallbackOnRolelessUserInfo: Bool = false` on `AuthChannelCoordinator` (wired from `ReviewedAppDeployment.allowLoginRoleFallbackOnRolelessUserInfo`, enabled in `RegionalLaunchConfiguration.reviewedDeployment`). When false (default), `I00SessionAdmissionBaselineTests` passes unchanged. When true (reviewed deployment), if `/api/userInfo` returns the matching positive `id` without `role`, `AuthChannelCoordinator` falls back to the validated `LoginResult.role` from `/api/login/phone` or `/api/login/apple`.

### (4) Wallet History/Overview Read Approvals
- **`App/AppCompositionRoot.swift`**:
  - Wired `ReviewedProductionGateLeases.walletHistory(_:)` into `AppCompositionRoot.walletHistoryReadApproval` when `productionGatesEnabled` is true, enabling `/api/wallet/stages`, `/api/balance/list`, `/api/points/list`, `/api/user/points/list`, `/api/user/balance/list`, and `/api/withdrawal/list`.
  - **Bank withdrawal and virtual goods remain strictly flagged off** (`session.makeBankWithdrawalContext() == nil`, no `.bankConsentRead` / `.bankPrepare` / `.bankCreate` routes).

### (5) Orders, Addresses, Favorites, Coupons Leases & Fixture Removal
- **`App/AppCompositionRoot.swift`**:
  - Wired `ownedOrderReadApproval`, `orderLifecycleConfiguration` (`allowsReviewedCancellationAndRefund: true`), `profileParticipantAccess` (shipping address list/create/edit/delete), `profileFavoritesReadAccess`, `profileFavoriteTopicReadAccess`, `profileFavoriteDetailAccess`, `profileFavoriteRemovalAccesses`, `topicUnlikeApproval`, `profileOwnedCouponReadAccess`, `couponReadApproval`, `couponWriteApproval`, and `couponCodeApproval` (`api/coupon/qr-token`, `api/coupon/status`) in `ReviewedProductionGateLeases`.
  - Added canonical multipart form validation in `ReviewedProductionFormMutationRoute` for `api/registration/cancel`, `api/registration/cancel-refund`, `api/coupon/qr-token`, `api/coupon/status`, and `api/topic/like`.
- **`App/AssetPointsAndOrderCancellationSectionView.swift`**:
  - Removed hardcoded fixture orders (`CY202610200101`, `CY202610200102`) and hardcoded points balance (`1280`), replacing them with empty default state (`orderItems: [OrderCancellationItem] = []`, `availablePoints: Int = 0`) and an explicit empty state view (`assetPointsOrderCancellation.orders.empty`).

### (6) G2 Club/Channel Safety Hook & IM Safety Approvals
- **`App/AppCompositionRoot.swift` & `App/AppSession.swift`**:
  - Wired `ReviewedProductionGateLeases.messagingHistory(_:)` and `businessConfiguration` routes (`.imDelete`, `.imReport`, `.imBlock`, `.imUnblock`, `.imMute`, `.imRead`, `.imStart`, `.imSend`, `.imUnreadTotal`, `.clubChat`) plus `ReviewedProductionFormMutationRoute` validation for `api/im/delete`, `api/im/read`, `api/im/mute`, `api/im/report`, `api/im/block`, `api/im/unblock`, and `api/im/start`.
  - Added `AppCompositionRoot.clubChannelSafetyHostFactory` and `AppSession.makeClubChannelSafetyHost(clubID:channelID:)` hook for G2's `ClubSafetyComposition`.

---

## 2. `docs/parity/page-map.csv` Rows Updated (with Test Evidence)

| `mp_path` | Status Change | Evidence |
|---|---|---|
| `pages/login/index` | `partial` -> `exists` | Exercised by `G1ProductionGatesEndToEndTests.testGate3AppleAndSMSSignInEnabledAndRolelessUserInfoFallbackWorksWhilePasswordStaysDisabled` (`sendSMSCode`, `loginWithPhone`, `beginAppleAuthorization`/`completeAppleAuthorization`, password disabled). |
| `pages/me/privacy` | `partial` -> `exists` | Exercised by `G1ProductionGatesEndToEndTests.testGate1InAppAccountDeletionEndToEndAndRetryStatesThroughReviewedComposition` and `testGate2LegalCatalogAndConsentWithdrawalEndToEndThroughReviewedComposition` (legal docs, usage consent withdrawal, roam consent withdrawal, marketing consent withdrawal, and full account deletion). |
| `pages/me/orders` | `partial` -> `exists` | Exercised by `G1ProductionGatesEndToEndTests.testGate5OrdersAddressesFavoritesCouponsLeasesOpenUnderReviewedComposition` (`ownedOrderReader.list`, `orderDetail`, `orderLifecycleCoordinator.begin` + `submit` -> `/api/registration/cancel`). |
| `pages/me/favorites` | `partial` -> `exists` | Exercised by `G1ProductionGatesEndToEndTests.testGate5OrdersAddressesFavoritesCouponsLeasesOpenUnderReviewedComposition` (`profileFavoritesReader.favoritePosts`, `profileFavoriteTopicReader.favoriteTopics`, `topicUnlikeController.confirmUnlike` -> `/api/topic/like`). |
| `pages/me/address` | `partial` -> `exists` | Exercised by `G1ProductionGatesEndToEndTests.testGate5OrdersAddressesFavoritesCouponsLeasesOpenUnderReviewedComposition` (`participantReader.shippingAddresses`, `participantCoordinator.saveAddress`, `deleteAddress`). |
| `packageB/pages/me/addressEdit` | `partial` -> `exists` | Exercised by `G1ProductionGatesEndToEndTests.testGate5OrdersAddressesFavoritesCouponsLeasesOpenUnderReviewedComposition` (`participantCoordinator.saveAddress` -> `/api/user/address/action`, `deleteAddress` -> `/api/user/address/delete`). |
| `packageB/pages/coupon/my` | `partial` -> `exists` | Exercised by `G1ProductionGatesEndToEndTests.testGate5OrdersAddressesFavoritesCouponsLeasesOpenUnderReviewedComposition` (`profileOwnedCouponReader.ownedCoupons` -> `/api/coupon/myrecvlist`, `makeCouponCodeCoordinator(historyID:).confirmPresentation()` -> `/api/coupon/qr-token`). |

---

## 3. What Remains Intentionally Flagged Off / Partial

- **Bank withdrawal (`packageB/pages/wallet/withdraw`)**: Kept `partial` and strictly flagged off (`session.makeBankWithdrawalContext() == nil`, no `.bankConsentRead`/`.bankPrepare`/`.bankCreate` routes) per task specification.
- **Virtual goods / points mall (`packageB/pages/points/mall`, `packageB/pages/points/order`)**: Kept flagged off per task specification.
- **Password login**: Kept strictly disabled (`session.canUsePassword == false`).
- **WeChat native sign-in & WeChat reconfirmation for deletion**: Requires native WeChat SDK / mini-program `wx.login` openid; SMS and Apple Sign-In are active.
- **Default `.unconfigured` launch posture**: `RegionalLaunchConfiguration.composition` defaults to `reviewed: nil` (`.unconfigured`) in committed source so unit tests and unconfigured builds never contact a network host; supplying `QUESTIFY_API_BASE_URL` via gitignored `Config/Local.*.xcconfig` or calling `RegionalLaunchConfiguration.reviewedComposition(baseURL:...)` activates all reviewed gates.

---

## 4. Build, Scaffold, and Test Verification Evidence

- **Xcode App Build (`Questify`, `/private/tmp/build-g1-gates-final-2.log`)**:
  ```text
  ** BUILD SUCCEEDED **
  BUILD_EXIT=0
  ```
- **Xcode App Unit Tests (`QuestifyAppUnitTests`, `/private/tmp/test-g1-gates-final-2.log`)**:
  ```text
  Test Suite 'AppCompositionRootTests' passed at 2026-11-07 08:39:47.582.
  	 Executed 18 tests, with 0 failures (0 unexpected) in 0.207 (0.213) seconds
  Test Suite 'AssetPointsAndOrderCancellationSectionViewTests' passed at 2026-11-07 08:39:47.596.
  	 Executed 4 tests, with 0 failures (0 unexpected) in 0.013 (0.014) seconds
  Test Suite 'G1ProductionGatesEndToEndTests' passed at 2026-11-07 08:39:47.776.
  	 Executed 6 tests, with 0 failures (0 unexpected) in 0.178 (0.180) seconds
  Test Suite 'OwnedOrderCompositionTests' passed at 2026-11-07 08:39:48.035.
  	 Executed 9 tests, with 0 failures (0 unexpected) in 0.257 (0.259) seconds
  Test Suite 'WalletHistoryCompositionTests' passed at 2026-11-07 08:39:48.382.
  	 Executed 31 tests, with 0 failures (0 unexpected) in 0.339 (0.346) seconds
  Test Suite 'QuestifyAppUnitTests.xctest' passed at 2026-11-07 08:39:48.382.
  	 Executed 68 tests, with 0 failures (0 unexpected) in 0.994 (1.013) seconds
  Test Suite 'Selected tests' passed at 2026-11-07 08:39:48.382.
  	 Executed 68 tests, with 0 failures (0 unexpected) in 0.994 (1.014) seconds
  ** TEST SUCCEEDED **
  TEST_EXIT=0
  ```
- **SwiftPM Core Unit Tests (`QuestifyCoreTests`, `/private/tmp/swift-test-g1-final-34594.log`)**:
  ```text
  Test Suite 'G1CoreProductionGatesTests' passed at 2026-11-07 07:45:43.479.
  	 Executed 2 tests, with 0 failures (0 unexpected) in 0.015 (0.015) seconds
  Test Suite 'I00SessionAdmissionBaselineTests' passed at 2026-11-07 07:45:43.495.
  	 Executed 3 tests, with 0 failures (0 unexpected) in 0.016 (0.016) seconds
  Test Suite 'Selected tests' passed at 2026-11-07 07:45:43.495.
  	 Executed 5 tests, with 0 failures (0 unexpected) in 0.031 (0.032) seconds
  TEST_EXIT=0
  ```
- **Scaffold & Contract Checks**:
  - `/Users/fanning/.local/bin/python3.12 tools/check_scaffold.py`: `PASS structural checks: 4116 Swift source files, 13462 bilingual keys, references, scheme, read-only expected project equivalence` (exit 0).
  - `/Users/fanning/.local/bin/python3.12 -m unittest Tests/ContractChecks/test_pkg19_login_deletion_chain.py`: `Ran 11 tests in 0.299s — OK` (exit 0).

