# iOS App Security Review (`ui/h-appsec`)

**Date:** 2026-11-14  
**Base Revision:** `origin/ui/main` (`3ac970ec2`)  
**Verification Scope:** Static analysis, per-file `swiftc -parse`, Python release/security contract checks (`Tests/ContractChecks/test_appsec_review.py`), client-data catalog audit, and project scaffold checks (`tools/check_scaffold.py`). Full `xcodebuild` / `swift build` / `swift test` was not run per task environment constraints.

---

## Executive Summary

Across the 7 required security domains, **15 confirmed findings** (**5 High**, **9 Medium**, **1 Low**) were identified and fixed with regression unit tests (`Tests/CoreTests/`, `Tests/AppUnitTests/`) and automated contract checks (`Tests/ContractChecks/test_appsec_review.py`).

| # | Area | Severity | Summary | Status |
|---|---|---|---|---|
| APPSEC-01 | (1) Token / Credential Storage | Medium | `KeychainTokenStore.read()` did not verify Keychain accessibility / sync attributes on read | Fixed |
| APPSEC-02 | (1) Token / Credential Storage | Medium | `AppSession.expireIfMatching` (used by deregistration) skipped `weChatAuth`/`authChannels`/location cleanup | Fixed |
| APPSEC-03 | (2) Network | Low | `PlayerCode.read` accepted `http://`; DEBUG E2E logger logged full URL including query parameters | Fixed |
| APPSEC-04 | (3) Deep & Universal Links | High | `DeepLinkAndUniversalLinkSafetyAudit` & `NativeNavigationContract` missed encoded `%2e%2e`/`\`/`%00` traversal | Fixed |
| APPSEC-05 | (3) Deep & Universal Links | Medium | `DeepLinkAndUniversalLinkSafetyAudit` accepted non-canonical integers (`+12`, `007`) for `topicId`/`merchantId`/`clubId` | Fixed |
| APPSEC-06 | (3) Deep & Universal Links | High | `MPParityRoute` allowed `mode=paid` reveal spoofing, empty gift token, unvalidated IDs, and path traversal | Fixed |
| APPSEC-07 | (4) External-Games WKWebView | High | `ExternalGameSandboxedWebView` lacked `WKUIDelegate` to block `window.open()` and `targetFrame == nil` check | Fixed |
| APPSEC-08 | (4) External-Games WKWebView | High | WebView preferences allowed file/universal access flags; JS bridge handler did not verify `isMainFrame` / origin | Fixed |
| APPSEC-09 | (4) External-Games WKWebView | High | CSP injection used a case-sensitive literal check easily bypassed by uppercase/single-quoted meta tags | Fixed |
| APPSEC-10 | (4) External-Games WKWebView | Medium | JS bridge lacked cumulative storage quota (`64` keys / `64 KiB`), key format, haptic, and no-arg validation | Fixed |
| APPSEC-11 | (4) External-Games WKWebView | Medium | `entryFileURL(for:)` skipped disk SHA-256 verification; key pinning used `UserDefaults` only; `gameID` unvalidated on catalog download | Fixed |
| APPSEC-12 | (5) Local Data at Rest | Medium | `SquareCloudDraftDisk` stored compose drafts and pending locks in plaintext `UserDefaults.standard` | Fixed |
| APPSEC-13 | (5) Local Data at Rest | Medium | 25 draft/offline-recovery file stores wrote without `#if os(iOS)` `.completeFileProtection`; catalog needed sync | Fixed |
| APPSEC-14 | (6) Screenshots / Privacy | High | Wallet, bank withdrawal, and payout screens were exposed in `.inactive` app switcher snapshots; unexpiring pasteboard copy | Fixed |
| APPSEC-15 | (7) Offline Write Queue | Medium | `AnalyticsEventClient` used low-entropy `Int.random` idempotency/session IDs and omitted explicit secret patterns in `sanitize` | Fixed |

---

## Detailed Findings (`finding -> severity -> fix -> evidence`)

### Domain (1): Token & Credential Storage

#### APPSEC-01: Keychain read path did not enforce accessibility class or non-synchronizable attribute
- **Severity:** Medium
- **Finding:** `App/KeychainTokenStore.swift` wrote session tokens with `kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and `kSecAttrSynchronizable: false`, but `read()` only requested `kSecReturnData` without inspecting `kSecAttrAccessible` or `kSecAttrSynchronizable` on the returned item. A pre-existing or migrated Keychain item with a weaker accessibility class (e.g., backed-up/migratable) would still be accepted.
- **Fix:** Updated `KeychainTokenStore.read()` in `App/KeychainTokenStore.swift` to request `kSecReturnAttributes: true` alongside `kSecReturnData: true`, verify `kSecAttrAccessible == kSecAttrAccessibleWhenUnlockedThisDeviceOnly` and `kSecAttrSynchronizable == false`, and clear/reject (`StoreError.invalidToken`) any non-compliant item.
- **Evidence:** `App/KeychainTokenStore.swift` (`read()`), `Tests/ContractChecks/test_appsec_review.py::test_1_keychain_token_storage_and_clear_on_logout_and_delete`, `Tests/ContractChecks/test_regional_storage_boundaries.py`.

#### APPSEC-02: Session invalidation during account deletion skipped auth channel cancellation
- **Severity:** Medium
- **Finding:** `AppSession.logout()` cleared Keychain, `storedRoles`, `weChatAuth`, `authChannels`, and `retainedPersonalLocationShareHost`, whereas `AppSession.expireIfMatching(...)` (invoked on `401` and by `AccountComplianceCoordinator` during account deregistration) omitted `weChatAuth.cancel()`, `authChannels.cancel()`, and `retainedPersonalLocationShareHost?.prepareLogout()`.
- **Fix:** Updated `AppSession.expireIfMatching(...)` in `App/AppSession.swift` to cancel `weChatAuth`, `authChannels`, and `retainedPersonalLocationShareHost?.prepareLogout()` alongside clearing `vault` and `storedRoles` while respecting the `tools/check_appsession_ratchet.py` line ceiling (`8171`).
- **Evidence:** `App/AppSession.swift` (`expireIfMatching`), `Tests/ContractChecks/test_appsec_review.py::test_1_keychain_token_storage_and_clear_on_logout_and_delete`, `tools/check_appsession_ratchet.py`.

> **Domain (1) Verification Note:** Verified `SearchMapComponents.swift` stores non-credential search keywords with `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` and `kSecAttrSynchronizable: false` (intentional per `docs/release/cb38-security.md`). No session tokens are stored in `UserDefaults` or files.

---

### Domain (2): Network Security (ATS, Header Logging, TLS)

#### APPSEC-03: Cleartext `http://` QR acceptance and DEBUG query string logging
- **Severity:** Low
- **Finding:** `Config/Info.plist` and `Config/*.xcconfig` enforce ATS with zero `NSAllowsArbitraryLoads` exceptions, and `URLSessionTransport` uses `.ephemeral` configuration, `NoRedirectDelegate`, and `APIConfiguration` (`scheme == "https"`). However, `Core/PlayerGapRoutes.swift` (`PlayerCode.read`) permitted `http://` QR URLs, and `App/RegionalLaunchConfiguration.swift` (`#if DEBUG` `E2ETestHostTransport`) logged `outgoing.url?.absoluteString` (potentially exposing query strings).
- **Fix:** Restricted `PlayerCode.read` in `Core/PlayerGapRoutes.swift` to `https://` only, and updated `E2ETestHostTransport` in `App/RegionalLaunchConfiguration.swift` to log `outgoing.url?.path ?? ""` only. Confirmed no `NSLog`/`os_log`/`Logger` call logs `Authorization` or `allHTTPHeaderFields`.
- **Evidence:** `Core/PlayerGapRoutes.swift`, `App/RegionalLaunchConfiguration.swift`, `Core/AuthService.swift`, `Core/APIConfiguration.swift`, `tools/check_l2_environment_configs.py`, `Tests/ContractChecks/test_appsec_review.py::test_2_network_ats_tls_only_and_no_auth_header_logging`, `Tests/CoreTests/DeepLinkAndUniversalLinkSafetyAuditTests.swift::testRejectsEncodedPathTraversalNullBytesAndNonCanonicalNumericIDs`.

---

### Domain (3): Deep Links, Universal Links & Notification Payloads

#### APPSEC-04: Encoded path traversal bypass in universal link & internal navigation parsers
- **Severity:** High
- **Finding:** `DeepLinkAndUniversalLinkSafetyAudit.audit(...)` checked `".."` and `"."` only against `components.percentEncodedPath` segments, leaving `%2e%2e`, `%252e`, `%00` null bytes, and backslashes `\` undetected. `NativeNavigationContract.parseInternal` also lacked `%2e` and `\` rejection.
- **Fix:** Updated `Core/DeepLinkAndUniversalLinkSafetyAudit.swift` to enforce a `4096`-byte URL bound, reject `\`, `%00`, `%252e`, control characters, `%2e` in `percentEncodedPath`, and `".."`/`"."` in both `percentEncodedPath` and decoded `components.path` segments. Hardened `NativeNavigationContract.parseInternal` in `Core/NativeNavigationCompletion.swift` similarly.
- **Evidence:** `Core/DeepLinkAndUniversalLinkSafetyAudit.swift`, `Core/NativeNavigationCompletion.swift`, `Tests/CoreTests/DeepLinkAndUniversalLinkSafetyAuditTests.swift`, `Tests/ContractChecks/test_appsec_review.py::test_3_deep_links_universal_links_and_notifications_validated`.

#### APPSEC-05: Non-canonical integer parsing allowed `+` signs and leading zeros
- **Severity:** Medium
- **Finding:** `DeepLinkAndUniversalLinkSafetyAudit` used raw `Int(raw)` for `topicId`, `merchantId`, and `clubId`, accepting non-canonical inputs (`+12`, `007`).
- **Fix:** Replaced raw `Int(raw)` checks with `positiveCanonicalID(_:)` (`0-9` ASCII digits only, `<= 18` chars, `> 0`, `String(value) == raw`) for all resource IDs in `Core/DeepLinkAndUniversalLinkSafetyAudit.swift`.
- **Evidence:** `Core/DeepLinkAndUniversalLinkSafetyAudit.swift`, `Tests/CoreTests/DeepLinkAndUniversalLinkSafetyAuditTests.swift`.

#### APPSEC-06: `MPParityRoute` parameter spoofing (`mode=paid`) and unvalidated route parameters
- **Severity:** High
- **Finding:** `MPParityRoute.init?(miniProgramPath:query:)` in `App/MPParityKit.swift` trusted `mode=paid` query arguments (`count`, `until`) to construct `PassRevealPaidFacts`, accepted empty `gift` tokens (`query["token"] ?? ""`), did not reject `..`/`\`/control chars or unvalidated IDs across `pass`, `seats`, `video-bounty`, `report`, `settle`, `payout-receiver`, and `settlement`. Notification taps route via `MPNotificationTapRouter` -> `PushTapRouter` -> `NativeNavigationContract.parseInternal`, which already rejects schemes/hosts, but direct parity route construction was overly permissive.
- **Fix:** Hardened `MPParityRoute.init?(miniProgramPath:query:)` in `App/MPParityKit.swift` to reject path traversal/backslashes/control chars/schemes, enforce canonical positive integers for numeric IDs, enforce `[A-Za-z0-9._-]{1,64}` for `pass.id` and `campaignKey`, require non-empty bounded `token` for `gift`, and always construct `.reveal(paid: nil)` from path/query links (blocking `mode=paid` spoofing).
- **Evidence:** `App/MPParityKit.swift`, `Tests/AppUnitTests/MPParityDeepLinkRouteTests.swift`, `Tests/ContractChecks/test_appsec_review.py::test_3_deep_links_universal_links_and_notifications_validated`.

---

### Domain (4): External-Games `WKWebView` Sandbox

#### APPSEC-07: Missing `WKUIDelegate` (`window.open` / `target="_blank"`) & `targetFrame` check
- **Severity:** High
- **Finding:** Both iOS and macOS `ExternalGameSandboxedWebView` in `App/ExternalGameImportView.swift` omitted `WKUIDelegate`, so `window.open()` or `target="_blank"` could attempt popup creation rather than returning `nil`, and `decidePolicyFor navigationAction` did not reject `navigationAction.targetFrame == nil`.
- **Fix:** Consolidated duplicated iOS/macOS coordinators into a single `ExternalGameWebViewCoordinator` conforming to `WKNavigationDelegate, WKUIDelegate, WKScriptMessageHandler`, assigning `webView.uiDelegate = context.coordinator`, returning `nil` from `webView(_:createWebViewWith:for:windowFeatures:)`, and requiring `navigationAction.targetFrame != nil` in `decidePolicyFor navigationAction`.
- **Evidence:** `App/ExternalGameImportView.swift`, `Tests/ContractChecks/test_appsec_review.py::test_4_external_games_wkwebview_sandbox_and_pinning`.

#### APPSEC-08: Explicit file-access flags not disabled and bridge frame origin not checked
- **Severity:** High
- **Finding:** `WKWebViewConfiguration` did not explicitly disable `allowFileAccessFromFileURLs` or `allowUniversalAccessFromFileURLs`, and `userContentController(_:didReceive:)` did not check `message.frameInfo.isMainFrame` or verify `message.frameInfo.request.url` against `ExternalGameSandboxPolicy.allowsNavigation`.
- **Fix:** Set `allowFileAccessFromFileURLs = false` and `allowUniversalAccessFromFileURLs = false` in `makeConfiguration()` (alongside `.nonPersistent()` data store and `javaScriptCanOpenWindowsAutomatically = false`), and enforced `message.frameInfo.isMainFrame` plus `ExternalGameSandboxPolicy.allowsNavigation` on `message.frameInfo.request.url` before invoking `onBridgeMessage`.
- **Evidence:** `App/ExternalGameImportView.swift`, `Tests/ContractChecks/test_appsec_review.py::test_4_external_games_wkwebview_sandbox_and_pinning`.

#### APPSEC-09: Case-sensitive CSP check bypassable by crafted HTML meta tags
- **Severity:** High
- **Finding:** `ExternalGameStore.confirmInstall()` skipped injecting the strict CSP if `!html.contains("http-equiv=\"Content-Security-Policy\"")` was false—bypassable using uppercase/single-quoted `<META HTTP-EQUIV='Content-Security-Policy' CONTENT="script-src 'unsafe-inline'">` or HTML comments.
- **Fix:** Added `ExternalGameSandboxPolicy.applyStrictCSP(to:manifest:)` in `Core/ExternalGameImport.swift` to strip all pre-existing CSP `<meta>` tags case-insensitively and unconditionally prepend the host's strict CSP (`worker-src 'none'; child-src 'none'` also added).
- **Evidence:** `Core/ExternalGameImport.swift`, `Tests/CoreTests/ExternalGameImportTests.swift::testStrictCSPRemovesAttackerMetaAndEntryVerifiesIntegrityAndPinning`.

#### APPSEC-10: JS bridge cumulative storage quota and argument validation gaps
- **Severity:** Medium
- **Finding:** `ExternalGameBridgeHandler.handle` restricted calls to the 4 declared actions (`getMetadata`, `loadProgress`, `saveProgress`, `haptic`), but did not cap cumulative `progressStore` growth across calls, did not validate key character sets, and ignored unexpected payload arguments on `getMetadata`, `loadProgress`, and `haptic`.
- **Fix:** Enforced empty payload checks on `getMetadata`/`loadProgress`, `^[A-Za-z0-9._-]{1,64}$` key format & non-control values on `saveProgress`, cumulative quota caps (`64` entries, `64 KiB`), and an explicit `["style"]` allowlist (`light`, `medium`, `heavy`, `selection`, `success`, `warning`, `error`) on `haptic`.
- **Evidence:** `Core/ExternalGameImport.swift`, `Tests/CoreTests/ExternalGameImportTests.swift::testBridgeRejectsUnexpectedArgsBadStorageKeysBadHapticAndTotalQuota`.

#### APPSEC-11: Pre-load disk integrity check, Keychain key pinning & catalog `gameID` validation
- **Severity:** Medium
- **Finding:** `ExternalGameStore.entryFileURL(for:)` verified Ed25519 signature over the manifest only and did not re-verify the installed package files on disk against `manifest.sha256` before `WKWebView` load; `ExternalGameReviewModel.pin(_:host:defaults:)` pinned signing keys solely in `UserDefaults`; `ExternalGameReviewClient.downloadApproved(gameID:)` interpolated `gameID` into a URL path without format validation.
- **Fix:** Added `verifyInstalledEntryIntegrity(target:manifest:)` and explicit `verificationPublicKey.count == 32` check inside `ExternalGameStore.entryFileURL(for:)`; backed production key pinning in `ExternalGameReviewModel.pin` with Keychain (`questify.externalGame.signingKey.v1`, `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, `kSecAttrSynchronizable: false`); and validated `ExternalGameValidator.isValidPackageID(gameID)` in `ExternalGameReviewClient.downloadApproved`.
- **Evidence:** `Core/ExternalGameImport.swift`, `App/ExternalGameReviewModel.swift`, `Core/ExternalGameReviewClient.swift`, `Tests/CoreTests/ExternalGameImportTests.swift`, `Tests/ContractChecks/test_appsec_review.py::test_4_external_games_wkwebview_sandbox_and_pinning`.

---

### Domain (5): Local Data at Rest & Client-Data Catalog

#### APPSEC-12: Compose drafts and pending request locks stored in `UserDefaults.standard`
- **Severity:** Medium
- **Finding:** `SquareCloudDraftDisk` in `App/SquareCloudComposerView.swift` persisted user-authored composer draft text, member IDs, and pending publish locks in `UserDefaults.standard` (unprotected by iOS file-level encryption classes).
- **Fix:** Migrated `SquareCloudDraftDisk` to `Application Support/SquareCloudDrafts-v1` files written with `[.atomic, .completeFileProtection]` (`#if os(iOS)`), `0o700` directory / `0o600` file permissions, `isExcludedFromBackup = true`, and automatic cleanup of any legacy `UserDefaults.standard` keys; updated `docs/ops-safety/client-data-catalog.json`.
- **Evidence:** `App/SquareCloudComposerView.swift`, `docs/ops-safety/client-data-catalog.json`, `tools/audit_client_ops_surfaces.py --check`.

#### APPSEC-13: Drafts and offline recovery journals written without `.completeFileProtection`
- **Severity:** Medium
- **Finding:** While IM encrypted journals (`IMFileJournal`, `IMVideoJournal`) and `ContentDraftSystemCiphertexts` enforced `FileProtectionType.complete`, 25 draft/offline-recovery file stores across `Core/` and `App/` invoked `Data.write(to:options:)` with `.atomic` or `.withoutOverwriting` without specifying `.completeFileProtection`.
- **Fix:** Added `#if os(iOS)` `.completeFileProtection` to all 25 stores (`Core/ExternalGameImport.swift`, `Core/WorkshopUpgradeDraftStore.swift`, `Core/ClientOperationID.swift`, `Core/AccountComplianceContracts.swift`, `Core/ChapterReplacementInvitationCoordinator.swift`, `Core/CityActionBudgetRecovery.swift`, `Core/CityActionRecoveryJournal.swift`, `Core/CityParticipationCommandRecovery.swift`, `Core/ClubGovernanceIntentStore.swift`, `Core/ClubOwnerRefundLocks.swift`, `Core/ClubSeriesOriginalRequestJournal.swift`, `Core/CooperationFlowCoordinator.swift`, `Core/CouponManagementLocks.swift`, `Core/DoorReferralCoordinator.swift`, `Core/MerchantBusinessCoordinator.swift`, `Core/MerchantContentService.swift`, `Core/MerchantEngagementCoordinator.swift`, `Core/MerchantMarketingService.swift`, `Core/MerchantOfferWithdrawalCoordinator.swift`, `Core/OfficialActionCoordinator.swift`, `Core/OrderLifecycleProduction.swift`, `Core/RewardPledge.swift`, `Core/RoamPrivatePendingJournal.swift`, `Core/TeamMeetingPendingJournal.swift`, `App/RewardPledgeViews.swift`) and kept `docs/ops-safety/client-data-catalog.json` synchronized.
- **Evidence:** Git diff across listed files, `python3 -B tools/audit_client_ops_surfaces.py --check`, `Tests/ContractChecks/test_appsec_review.py::test_5_local_data_protection_and_client_data_catalog`.

---

### Domain (6): Screenshots & App Switcher Privacy

#### APPSEC-14: Sensitive wallet and payout screens exposed in `.inactive` app switcher snapshots
- **Severity:** High
- **Finding:** `BankWithdrawalView` cleared form state only on `scenePhase == .background` (too late for the iOS `.inactive` snapshot captured when entering the app switcher), while `ClubPayoutReceiverView`, `MerchantPayoutAccountView`, `OwnerDecisionClubPayoutReceiverView`, `OwnerDecisionMerchantPayoutAccountView`, `BundleWalletView`, `WalletAssetsView`, and `WalletWithdrawalsView` lacked app-switcher redaction/shielding. Additionally, `MerchantPayoutAccountView` wrote signing URLs to the global pasteboard without expiration or `.localOnly`.
- **Fix:** Added `AppSwitcherPrivacyShieldModifier` (`View.appSwitcherPrivacyShield()`) in `App/WalletCommerceViews.swift` applying `.privacySensitive()`, `.redacted(reason: scenePhase == .active ? [] : .privacy)`, and an opaque lock overlay whenever `scenePhase != .active`, and attached it to all wallet, bank withdrawal, ticket wallet, and payout account views. Updated `MerchantPayoutAccountView` pasteboard writes to `[.localOnly: true, .expirationDate: Date().addingTimeInterval(120)]`.
- **Evidence:** `App/WalletCommerceViews.swift`, `App/BankWithdrawalView.swift`, `App/ClubPayoutReceiverView.swift`, `App/MerchantPayoutAccountView.swift`, `App/OwnerDecisionPayoutViews.swift`, `App/BundleWalletView.swift`, `App/TicketWalletView.swift`, `App/TicketWalletDetailView.swift`, `Tests/ContractChecks/test_appsec_review.py::test_6_sensitive_screens_protected_in_app_switcher`, `Tests/ContractChecks/test_bank_withdrawal_contracts.py`.

---

### Domain (7): Offline Write Queue

#### APPSEC-15: Low-entropy `Int.random` keys and secret pattern gaps in `AnalyticsEventClient`
- **Severity:** Medium
- **Finding:** Offline operational queues (`BundleTransferPendingStore`, `FileClientOperationIDStore`, `SecondRegistrationMetrics`) store no credentials/secrets and use `UUID` keys, but `AnalyticsEventClient` used `"\(eventName)_\(millis)_\(sequence)_\(Int.random(in: 0..<10_000))"` for generated `idempotencyKey` (only ~13 bits of randomness), `Int.random(in: 0..<100_000)` for `sessionID`, and `Int.random(in: 0..<100_000_000)` for `FinishRouteAnalyticsSource.impressionID`, and its `sanitize(_:)` regex did not explicitly strip `secret`, `password`, `passwd`, `authorization`, `bearer`, `cookie`, `credential`, `private_key`, `api_key`, `access_key`, `passcode`, `otp`, or `Bearer`/`Basic` string prefixes.
- **Fix:** Replaced `Int.random` across `Core/AnalyticsEventClient.swift` with 122-bit random `UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()`, expanded `sanitize(_:)` key filtering for secret/credential keys, and scrubbed `Bearer ` / `Basic ` token values.
- **Evidence:** `Core/AnalyticsEventClient.swift`, `Tests/CoreTests/PlayerParityBRoutesTests.swift`, `Tests/ContractChecks/test_appsec_review.py::test_7_offline_write_queue_no_secrets_and_random_idempotency_keys`.

---

## Verification Gate Results

- `git diff --name-only -- '*.swift' | xargs -I{} swiftc -parse "{}"` — **PASS** (0 parse errors across all modified Swift files)
- `python3 -B Tests/ContractChecks/test_appsec_review.py` — **PASS** (7/7 tests)
- `python3 -B Tests/ContractChecks/test_bank_withdrawal_contracts.py` — **PASS** (10/10 tests)
- `python3 -B Tests/ContractChecks/test_regional_storage_boundaries.py` — **PASS** (5/5 tests)
- `python3 -B Tests/ContractChecks/test_universal_link_associated_domains.py` — **PASS** (4/4 tests)
- `python3 -B tools/check_l2_environment_configs.py` — **PASS** (15/15 tests)
- `python3 -B tools/audit_client_ops_surfaces.py --check` — **PASS** (`94 store files (87 production) catalogued`)
- `python3 -B tools/check_appsession_ratchet.py` — **PASS**
- `python3 -B tools/check_scaffold.py` — **PASS**
- *Note:* `xcodebuild` / `swift build` / `swift test` were intentionally not run per environment constraints.
