"""CB33 source contracts. Does not compile Swift or claim an associated domain."""
import plistlib
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
LEGACY_IPV4 = ".".join(["47", "103", "124", "64"])


class UniversalLinkAssociatedDomains(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()

    def test_entitlement_claims_sign_in_with_apple_only(self):
        plist = plistlib.loads((ROOT / "Config/Questify.entitlements").read_bytes())
        # Components r1 (C2): plus the widget App Group. US launch r1: plus the Apple Pay merchant id.
        # Components r1 (C7, 4882db52f): plus push (aps-environment) for Live Activity push tokens. Nothing else.
        self.assertEqual(plist, {"aps-environment": "development", "com.apple.developer.applesignin": ["Default"],
                                 "com.apple.developer.in-app-payments": ["merchant.com.chengyinhub.chengyinApp"],
                                 "com.apple.security.application-groups": ["group.com.chengyinhub.chengyinApp"]})
        self.assertNotIn("associated-domains", (ROOT / "Config/Questify.entitlements").read_text())
        # P1-1 (audit 11-28): applinks live only in the opt-in file, picked by QUESTIFY_ASSOCIATED_DOMAINS (default NO).
        linked = plistlib.loads((ROOT / "Config/QuestifyAssociatedDomains.entitlements").read_bytes())
        self.assertEqual(linked.pop("com.apple.developer.associated-domains"), ["applinks:www.chengyinhub.com"])
        self.assertEqual(linked, plist)
        self.assertIn("\nQUESTIFY_ASSOCIATED_DOMAINS = NO\n", self.read("Config/Base.xcconfig"))
        self.assertIn('"CODE_SIGN_ENTITLEMENTS" = "$(QUESTIFY_APP_ENTITLEMENTS_$(QUESTIFY_ASSOCIATED_DOMAINS))";',
                      self.read("Questify.xcodeproj/project.pbxproj"))
        info = plistlib.loads((ROOT / "Config/Info.plist").read_bytes())
        self.assertEqual([t["CFBundleURLSchemes"] for t in info["CFBundleURLTypes"]], [["$(QUESTIFY_WECHAT_APP_ID)"], ["chein"]])
        self.assertEqual(info["LSApplicationQueriesSchemes"], ["weixin", "weixinULAPI", "weixinURLParamsAPI", "alipay"])
        self.assertNotIn("applinks:", self.read("Config/Info.plist"))
        self.assertNotIn("applinks:", self.read("Config/Base.xcconfig"))

    def test_configuration_stays_empty_and_production_allowlist_stays_empty(self):
        parser = self.read("Core/UniversalLinkParser.swift")
        self.assertIn("public static let verifiedHTTPSOrigins: Set<String> = []", parser)
        self.assertIn("public static let associatedDomainEntitlements: [String] = []", parser)
        self.assertIn('["47", "103", "124", "64"].joined(separator: ".")', parser)
        self.assertNotIn(LEGACY_IPV4, parser)
        self.assertNotIn("applinks:", parser)
        self.assertNotIn("URLSession", parser)
        self.assertNotIn("associated-domains", parser)
        self.assertIn("AppUniversalLinkRouter(verifiedHTTPSOrigins: AppSession.verifiedLinkOrigins())", self.read("App/AppSession.swift"))
        self.assertIn("verifiedHTTPSOrigins: Set<String> = []", self.read("Core/NativeEntryRouting.swift"))

    def test_release_identity_stays_unconfigured(self):
        config = "\n" + self.read("Config/Base.xcconfig")
        self.assertIn("\nMARKETING_VERSION = 1.0.0\n", config)
        self.assertIn("\nCURRENT_PROJECT_VERSION = 2\n", config)
        self.assertIn("\nQUESTIFY_API_BASE_URL =\n", config)
        self.assertIn("\nQUESTIFY_SESSION_REALM =\n", config)
        self.assertIn("PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios\n", config)

    def test_plan_names_a_placeholder_host_and_no_real_applink(self):
        plan = self.read("docs/universal-links/cb33-associated-domains-plan.md")
        placeholder = "applinks:<owner-supplied-host>"
        self.assertIn(placeholder, plan)
        self.assertNotIn("applinks:", plan.replace(placeholder, ""))
        self.assertNotIn(LEGACY_IPV4, plan)
        for invented in [
            "chengyin.com",
            "chengyinhub.com",
            "questify.com",
            "icp",
            "ICP",
        ]:
            self.assertNotIn(invented, plan)
        self.assertIn("Config/Questify.entitlements", plan)
        self.assertIn("verifiedHTTPSOrigins: [])", plan)
        self.assertIn("Not run", plan)


if __name__ == "__main__":
    unittest.main()
