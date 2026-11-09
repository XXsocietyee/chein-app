"""Page-ready contract for pages/member/index/index. Does not compile Swift or run Xcode."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Core/MemberHome.swift"
STRINGS = ROOT / "docs/release/ui-strings-pages-member-index-index.json"
DASH = "—"


class MemberHomePageReadyContractTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()
        self.catalog = json.loads(STRINGS.read_text())

    def test_catalog_has_both_languages_and_unknown_is_an_em_dash(self):
        strings = self.catalog["strings"]
        self.assertEqual(self.catalog["page"], "pages/member/index/index")
        self.assertGreaterEqual(len(strings), 8)
        for key, value in strings.items():
            self.assertEqual(set(value), {"en", "zh-Hans"}, key)
            self.assertTrue(value["en"].strip(), key)
            self.assertTrue(value["zh-Hans"].strip(), key)
            self.assertNotEqual(value["en"], "0", key)
            self.assertNotEqual(value["zh-Hans"], "0", key)
        self.assertEqual(strings["member.card.unknownValue"]["en"], DASH)
        self.assertEqual(strings["member.card.unknownValue"]["zh-Hans"], DASH)
        for banned in ["https://", "ICP", "京ICP", "support@", "隐私政策", "用户协议"]:
            self.assertNotIn(banned, STRINGS.read_text())

    def test_accessibility_identifiers_match_the_model(self):
        block = re.search(r"accessibilityIdentifiers = \[(.*?)\]", self.source, re.S)
        self.assertIsNotNone(block)
        declared = re.findall(r'"(member\.[^"]+)"', block.group(1))
        listed = [row["id"] for row in self.catalog["accessibility"]]
        self.assertEqual(listed, declared)
        self.assertEqual(len(listed), len(set(listed)))
        keys = self.catalog["strings"]
        for row in self.catalog["accessibility"]:
            self.assertIn(row["key"], keys)

    def test_states_routes_and_money_switches_stay_off(self):
        for state in ["case loading", "case empty", "case error", "case unknown", "case ready"]:
            self.assertIn(state, self.source)
        self.assertIn('public static let unknownDisplay = "—"', self.source)
        self.assertIn("public static let identityRoute = AuthEndpoint.userInfo.rawValue", self.source)
        self.assertIn("public static let roleInfoRoute = MemberRoleInfoReadRoute.path", self.source)
        self.assertNotIn("api/common/banner", self.source)
        self.assertNotIn("points/result_list", self.source)
        for name in ["showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"]:
            self.assertNotRegex(self.source, rf"{name}\s*=\s*true")
            self.assertRegex(self.source, rf"var {name}: Bool \{{ false \}}")
        self.assertIn("#if DEBUG", self.source)
        self.assertIn("public enum MemberHomeFixtureData", self.source)
        self.assertLess(self.source.index("#if DEBUG"), self.source.index("public enum MemberHomeFixtureData"))
        self.assertIn("#endif", self.source[self.source.index("public enum MemberHomeFixtureData"):])


if __name__ == "__main__":
    unittest.main()
