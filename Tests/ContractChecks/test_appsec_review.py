"""Static AppSec review contract checks across all 7 security domains (no Xcode/simulator needed)."""
import json
import pathlib
import plistlib
import re
import subprocess
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(rel: str) -> str:
    return (ROOT / rel).read_text(encoding="utf-8")


class AppSecReviewContractTests(unittest.TestCase):
    # (1) Token / credential storage
    def test_1_keychain_token_storage_and_clear_on_logout_and_delete(self):
        kc = read("App/KeychainTokenStore.swift")
        self.assertIn("kSecAttrAccessibleWhenUnlockedThisDeviceOnly", kc)
        self.assertIn("kSecAttrSynchronizable as String:false", kc)
        self.assertIn("kSecReturnAttributes as String]=true", kc)
        # Verify accessibility class check on read
        read_fn = kc.split("func read()", 1)[1].split("func write(", 1)[0]
        self.assertIn("kSecAttrAccessibleWhenUnlockedThisDeviceOnly", read_fn)
        self.assertIn("kSecAttrSynchronizable", read_fn)
        self.assertIn("try? clear()", read_fn)

        session = read("App/AppSession.swift")
        logout_fn = session.split("func logout() async", 1)[1].split("func activities(", 1)[0]
        self.assertIn("try vault.clear()", logout_fn)
        self.assertIn("weChatAuth.cancel()", logout_fn)
        self.assertIn("authChannels.cancel()", logout_fn)
        self.assertIn("storedRoles?.clear()", logout_fn)

        expire_fn = session.split("func expireIfMatching(", 1)[1].split("private static func messageKey(", 1)[0]
        self.assertIn("try? vault.clear()", expire_fn)
        self.assertIn("weChatAuth.cancel()", expire_fn)
        self.assertIn("authChannels.cancel()", expire_fn)
        self.assertIn("retainedPersonalLocationShareHost?.prepareLogout()", expire_fn)

        # Ensure Keychain tokens are never stored in UserDefaults across App/ or Core/
        self.assertNotIn("UserDefaults", kc)

    # (2) Network: ATS, no auth header logging, TLS only
    def test_2_network_ats_tls_only_and_no_auth_header_logging(self):
        info = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
        self.assertNotIn("NSAppTransportSecurity", info)
        for cfg in (ROOT / "Config").glob("*.xcconfig"):
            self.assertNotIn("NSAllowsArbitraryLoads", cfg.read_text(encoding="utf-8"))

        api_cfg = read("Core/APIConfiguration.swift")
        self.assertIn('parts.scheme == "https"', api_cfg)

        transport = read("Core/AuthService.swift")
        self.assertIn("URLSessionConfiguration.ephemeral", transport)
        self.assertIn("httpCookieStorage = nil", transport)
        self.assertIn("NoRedirectDelegate", transport)

        player_gap = read("Core/PlayerGapRoutes.swift")
        player_code_fn = player_gap.split("public enum PlayerCode", 1)[1]
        self.assertIn('qr.hasPrefix("https://")', player_code_fn)
        self.assertNotIn('qr.hasPrefix("http://")', player_code_fn)

        # Ensure no NSLog / Logger logs allHTTPHeaderFields or Authorization header
        for folder in ("App", "Core"):
            for swift_file in (ROOT / folder).glob("*.swift"):
                text = swift_file.read_text(encoding="utf-8")
                self.assertNotRegex(
                    text,
                    r'(?:NSLog|os_log|Logger\s*\(.*\)\.\w+)\s*\([^\n]*(?:allHTTPHeaderFields|Authorization)',
                    msg=f"Potential header logging in {swift_file.name}",
                )

    # (3) Deep links, universal links, and notification payloads
    def test_3_deep_links_universal_links_and_notifications_validated(self):
        audit = read("Core/DeepLinkAndUniversalLinkSafetyAudit.swift")
        self.assertIn('rawString.lowercased().contains("%00")', audit)
        self.assertIn('rawString.lowercased().contains("%252e")', audit)
        self.assertIn('decodedSegments.contains("..")', audit)
        self.assertIn('components.percentEncodedPath.lowercased().contains("%2e")', audit)
        self.assertIn("positiveCanonicalID(", audit)

        nav = read("Core/NativeNavigationCompletion.swift")
        self.assertIn('!text.contains("\\\\")', nav)
        self.assertIn('%2e', nav)

        parity = read("App/MPParityKit.swift")
        init_fn = parity.split("init?(miniProgramPath path:", 1)[1].split("enum MPParityDestination", 1)[0]
        self.assertIn('!path.contains("..")', init_fn)
        self.assertIn('!path.contains("\\\\")', init_fn)
        self.assertIn("self = .reveal(paid: nil)", init_fn)
        self.assertNotIn('query["mode"] == "paid"', init_fn)
        self.assertIn('guard let token = nonEmpty("token")', init_fn)
        self.assertIn("positiveIDString(", init_fn)

        push = read("Core/NativeEntryRouting.swift")
        self.assertIn("AppUniversalLinkRouter(verifiedHTTPSOrigins: AppSession.verifiedLinkOrigins())", read("App/AppSession.swift"))
        self.assertIn("NativeNavigationContract.parseInternal", push)

    # (4) External-games WKWebView sandbox
    def test_4_external_games_wkwebview_sandbox_and_pinning(self):
        view = read("App/ExternalGameImportView.swift")
        self.assertIn("WKUIDelegate", view)
        self.assertIn("createWebViewWith", view)
        self.assertIn("webView.uiDelegate = context.coordinator", view)
        self.assertIn("config.websiteDataStore = .nonPersistent()", view)
        self.assertIn("config.preferences.javaScriptCanOpenWindowsAutomatically = false", view)
        self.assertIn('config.preferences.setValue(false, forKey: "allowFileAccessFromFileURLs")', view)
        self.assertIn('config.setValue(false, forKey: "allowUniversalAccessFromFileURLs")', view)
        self.assertIn("navigationAction.targetFrame != nil", view)
        self.assertIn("message.frameInfo.isMainFrame", view)
        self.assertIn("ExternalGameSandboxPolicy.allowsNavigation(", view)

        core = read("Core/ExternalGameImport.swift")
        self.assertIn("public static func applyStrictCSP(", core)
        self.assertIn("maxTotalProgressEntries", core)
        self.assertIn("maxTotalProgressBytes", core)
        self.assertIn("verifyInstalledEntryIntegrity(", core)
        self.assertIn("hardenedEntrySHA256", core)
        self.assertIn("ExternalGameValidator.verifyServerSignature(game.manifest, publicKeyRaw: verificationPublicKey)",
                      core.split("public func entryFileURL(", 1)[1].split("private func verifyInstalledEntryIntegrity", 1)[0])

        model = read("App/ExternalGameReviewModel.swift")
        self.assertIn("kSecAttrService as String: \"questify.externalGame.signingKey.v1\"", model)
        self.assertIn("kSecAttrAccessibleWhenUnlockedThisDeviceOnly", model)

        client = read("Core/ExternalGameReviewClient.swift")
        self.assertIn("ExternalGameValidator.isValidPackageID(gameID)", client)

    # (5) Local data at rest & client-data catalog
    def test_5_local_data_protection_and_client_data_catalog(self):
        protected_files = [
            "Core/ExternalGameImport.swift",
            "Core/WorkshopUpgradeDraftStore.swift",
            "Core/ClientOperationID.swift",
            "Core/AccountComplianceContracts.swift",
            "Core/ChapterReplacementInvitationCoordinator.swift",
            "Core/CityActionBudgetRecovery.swift",
            "Core/CityActionRecoveryJournal.swift",
            "Core/CityParticipationCommandRecovery.swift",
            "Core/ClubGovernanceIntentStore.swift",
            "Core/ClubOwnerRefundLocks.swift",
            "Core/ClubSeriesOriginalRequestJournal.swift",
            "Core/CooperationFlowCoordinator.swift",
            "Core/CouponManagementLocks.swift",
            "Core/DoorReferralCoordinator.swift",
            "Core/MerchantBusinessCoordinator.swift",
            "Core/MerchantContentService.swift",
            "Core/MerchantEngagementCoordinator.swift",
            "Core/MerchantMarketingService.swift",
            "Core/MerchantOfferWithdrawalCoordinator.swift",
            "Core/OfficialActionCoordinator.swift",
            "Core/OrderLifecycleProduction.swift",
            "Core/RewardPledge.swift",
            "Core/RoamPrivatePendingJournal.swift",
            "Core/TeamMeetingPendingJournal.swift",
            "Core/IMFileJournal.swift",
            "Core/IMVideoJournal.swift",
            "Core/ContentDraftSystemStorage.swift",
            "App/RewardPledgeViews.swift",
            "App/SquareCloudComposerView.swift",
        ]
        for rel in protected_files:
            text = read(rel)
            has_protection = (
                ".completeFileProtection" in text
                or "completeProtectionClass" in text
            )
            self.assertTrue(has_protection, f"{rel} must set iOS file protection")

        composer = read("App/SquareCloudComposerView.swift")
        self.assertNotIn("UserDefaults.standard.set(", composer)
        self.assertIn("SquareCloudDrafts-v1", composer)

        result = subprocess.run(
            [sys.executable, "-B", str(ROOT / "tools/audit_client_ops_surfaces.py"), "--check"],
            capture_output=True,
            text=True,
        )
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    # (6) Screenshots / privacy cover in app switcher
    def test_6_sensitive_screens_protected_in_app_switcher(self):
        wallet = read("App/WalletCommerceViews.swift")
        self.assertIn("struct AppSwitcherPrivacyShieldModifier", wallet)
        self.assertIn("scenePhase == .active ? [] : .privacy", wallet)
        self.assertIn("scenePhase != .active", wallet)

        for rel in [
            "App/WalletCommerceViews.swift",
            "App/BankWithdrawalView.swift",
            "App/ClubPayoutReceiverView.swift",
            "App/MerchantPayoutAccountView.swift",
            "App/BundleWalletView.swift",
            "App/TicketWalletView.swift",
            "App/TicketWalletDetailView.swift",
        ]:
            self.assertIn(".appSwitcherPrivacyShield()", read(rel), f"{rel} missing .appSwitcherPrivacyShield()")

        # The sign link is copied through LocalPasteboard, which applies the same local-only, expiring options.
        merchant_payout = read("App/MerchantPayoutAccountView.swift")
        self.assertIn("LocalPasteboard.copy(", merchant_payout)
        pasteboard = read("App/LocalPasteboard.swift")
        self.assertIn(".localOnly: true", pasteboard)
        self.assertIn(".expirationDate:", pasteboard)

    # (7) Offline write queue: no secrets, random idempotency keys
    def test_7_offline_write_queue_no_secrets_and_random_idempotency_keys(self):
        analytics = read("Core/AnalyticsEventClient.swift")
        self.assertNotIn("Int.random(", analytics)
        self.assertIn("UUID().uuidString", analytics)
        self.assertIn("secret|password|passwd|authorization|bearer|cookie|credential", analytics)
        self.assertIn("(Bearer|Basic)", analytics)

        transfer_store = read("Core/BundleTransferPendingStore.swift")
        self.assertNotIn("code", transfer_store.split("public struct BundleTransferPendingOperation")[1].split("}")[0])

        op_id = read("Core/ClientOperationID.swift")
        self.assertIn("UUID().uuidString.lowercased()", op_id)

    # K50-R9: player-reachable leaks and unvalidated deep-link inputs. ATS stays at the system default.
    def test_8_k50_r9_player_reachable_leaks_and_deep_link_inputs(self):
        info = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
        self.assertNotIn("NSAppTransportSecurity", info)
        for cfg in (ROOT / "Config").glob("*.xcconfig"):
            text = cfg.read_text(encoding="utf-8")
            self.assertNotIn("NSAllowsArbitraryLoads", text)
            self.assertNotIn("NSExceptionDomains", text)

        badge = read("Core/ObjectCardContracts.swift")
        self.assertIn("ObjectCardMediaPolicy.origin(candidate)", badge)
        self.assertNotIn('["http", "https"]', badge)

        parity = read("App/MPParityKit.swift")
        self.assertIn('v != ".", v != "..", !v.contains("..")', parity)

        landing = read("App/JourneyLandingViews.swift")
        self.assertIn('value != ".", value != "..", !value.contains("..")', landing)
        self.assertIn("String(value) == raw", landing)

        scheme = read("Core/CheinDeepLink.swift")
        self.assertIn('token != ".", token != ".."', scheme)
        self.assertIn('!token.contains("\\\\")', scheme)
        plain = scheme.split("func plainToken", 1)[1].split("func optionalID", 1)[0]
        self.assertNotIn('token.contains("/")', plain)

        page = read("Core/MiniProgramPageLink.swift")
        self.assertIn('ids: ["id", "sessionId"]', page)
        self.assertIn("opaqueShareToken", page)
        self.assertIn("ObjectCardMediaPolicy.origin(value)", page)

        journey = read("Core/JourneyLoopSource.swift")
        self.assertIn('value != "." && value != ".."', journey)
        self.assertIn("!value.contains(\"%\")", journey)

        pin = read("App/ExternalGameReviewModel.swift")
        self.assertIn("KeychainItemProtection.isDeviceOnlyUnlocked(attrs)", pin)
        self.assertIn("SecItemDelete(baseQuery as CFDictionary)", pin)
        protection = read("Core/KeychainItemProtection.swift")
        self.assertIn("kSecAttrAccessibleWhenUnlockedThisDeviceOnly", protection)
        self.assertIn("kSecAttrSynchronizable", protection)
        for rel in (
            "App/ImageUploadSecureStorage.swift",
            "App/SquareWorkspaceSecureStorage.swift",
            "App/RoamHistoryKeychainStorage.swift",
            "App/NativeEnrollmentKeychainStore.swift",
            "App/TemplateAuthoringSecureStorage.swift",
            "App/ProjectEditSecureStorage.swift",
        ):
            self.assertIn("KeychainItemProtection.isDeviceOnlyUnlocked", read(rel), rel)

        share = read("App/DesignSystem/CYSquareShareSheet.swift")
        self.assertNotIn("UIPasteboard.general.url", share)
        self.assertIn(".localOnly: true", share)
        self.assertIn(".expirationDate:", share)
        self.assertIn("ObjectCardMediaPolicy.origin", share)
        place = read("App/NativeR2/MapHome/RoamMapHomePlaceNote.swift")
        self.assertIn(".expirationDate:", place)
        self.assertIn(".localOnly: true", place)

        attachments = read("Core/ChannelDiscordMessaging.swift")
        self.assertIn("ObjectCardMediaPolicy.origin(raw)", attachments)
        self.assertNotIn("http://127.0.0.1", attachments)
        self.assertNotIn("http://localhost", attachments)

        e2e = read("App/E2ETestHostOverride.swift")
        self.assertNotIn("data.prefix(600)", e2e)
        self.assertIn('outgoing.url?.path', e2e)
        self.assertNotIn("absoluteString", e2e.split("NSLog", 1)[1])

        launch = read("Core/PlayerLaunch.swift")
        self.assertIn("static let merchantCenterEnabled = false", launch)


if __name__ == "__main__":
    unittest.main(verbosity=2)
