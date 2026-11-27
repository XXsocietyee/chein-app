"""Source checks for the capability-gated Sign in with Apple flow.

These read files only. They do not compile Swift, sign a build, or contact a host.
"""
import pathlib
import plistlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(name):
    return (ROOT / name).read_text()


class SignInWithAppleFlowContract(unittest.TestCase):
    def test_entitlement_file_is_only_the_default_sign_in_value(self):
        plist = plistlib.loads((ROOT / "Config/Questify.entitlements").read_bytes())
        # Components r1 (C2): plus the widget App Group. US launch r1: plus the Apple Pay merchant id.
        # Components r1 (C7, 4882db52f): plus push (aps-environment) for Live Activity push tokens. Nothing else.
        self.assertEqual(plist, {"aps-environment": "development", "com.apple.developer.applesignin": ["Default"],
                                 "com.apple.developer.in-app-payments": ["merchant.com.chengyinhub.chengyinApp"],
                                 "com.apple.security.application-groups": ["group.com.chengyinhub.chengyinApp"]})
        flow = read("Core/SignInWithAppleFlow.swift")
        self.assertIn('static let key = "com.apple.developer.applesignin"', flow)
        self.assertIn('static let requiredValues = ["Default"]', flow)
        self.assertIn("values == Self.requiredValues", flow)

    def test_empty_base_build_does_not_enable_or_name_a_host(self):
        base = read("Config/Base.xcconfig")
        self.assertRegex(base, r"(?m)^QUESTIFY_API_BASE_URL =\s*$")
        self.assertRegex(base, r"(?m)^QUESTIFY_SESSION_REALM =\s*$")
        self.assertIn("MARKETING_VERSION = 1.0.0\n", base)
        self.assertIn("CURRENT_PROJECT_VERSION = 2\n", base)
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios\n", base)
        self.assertNotIn("chengyinhub.com", base)
        self.assertNotIn("DEVELOPMENT_TEAM", base)
        self.assertNotIn("9VHY8N755R", base)
        self.assertNotIn("com.chengyinhub.chengyinApp", base)
        self.assertNotIn("SIGN_IN_WITH_APPLE", base)
        self.assertIsNone(re.search(r"(?m)^DEVELOPMENT_TEAM\s*=", base))

    def test_china_host_and_realm_stay_on_the_reviewed_profile_only(self):
        china = read("Config/China.Production.xcconfig")
        self.assertIn("QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/", china)
        self.assertIn("QUESTIFY_SESSION_REALM = cn-prod", china)
        self.assertNotIn("signInWithApple", china)
        self.assertNotIn("DEVELOPMENT_TEAM", china)
        self.assertNotIn("com.chengyinhub.chengyinApp", china)
        # US launch r1 (owner 2026-11-27): the US storefront shares the reviewed backend and realm.
        united = read("Config/UnitedStates.Production.xcconfig")
        self.assertIn("QUESTIFY_API_BASE_URL = https:/$()/www.chengyinhub.com/prod-api/", united)
        self.assertIn("QUESTIFY_SESSION_REALM = cn-prod", united)
        self.assertNotIn("signInWithApple", united)
        self.assertNotIn("DEVELOPMENT_TEAM", united)
        self.assertNotIn("chengyinhub.com", read("Config/UnitedStates.Staging.xcconfig"))

    def test_flow_refuses_an_empty_url_and_is_not_mounted(self):
        flow = read("Core/SignInWithAppleFlow.swift")
        self.assertIn("verifiedCapabilities.contains(.signInWithApple)", flow)
        self.assertIn("!trimmed.isEmpty", flow)
        self.assertIn("market == .china", flow)
        self.assertIn('private static let deniedHost = "47.103.124.64"', flow)
        self.assertNotIn("https://", flow)
        self.assertNotIn("URLSession(", flow)
        self.assertNotIn("appleConfigurationVerified: true", flow)
        self.assertNotIn(".password", flow)
        self.assertNotIn("withdrawal", flow)
        self.assertIn("builder.make(.apple", flow)
        self.assertIn("builder.make(.userInfo", flow)
        for path in ["App/AppSession.swift", "App/AppCompositionRoot.swift", "App/AuthChannelView.swift",
                     "App/RegionalLaunchConfiguration.swift"]:
            self.assertNotIn("SignInWithAppleFlow(", read(path), path)

    def test_core_tests_cover_the_hidden_and_entitlement_paths(self):
        tests = read("Tests/CoreTests/SignInWithAppleFlowTests.swift")
        for name in [
            "testEmptyURLStaysHiddenAndDoesNotCallTheReviewedHost",
            "testReviewedChinaHostStaysHiddenUntilTheCapabilityIsNamed",
            "testRepositoryEntitlementIsTheOnlySignInValue",
            "testExplicitReviewedChinaHostIsUsedOnlyWhenTheCapabilityIsPresent",
            "testBuildFilesDoNotEnableTheFlowOrChangeIdentity",
        ]:
            self.assertIn(f"func {name}", tests)


if __name__ == "__main__":
    unittest.main()
