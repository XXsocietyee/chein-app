"""Page-ready contract for pages/member/index/index. Does not compile Swift or run Xcode."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Core/MemberHome.swift"
DASH = "—"


class MemberHomePageReadyContractTests(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()

    def test_unknown_is_an_em_dash_in_the_model(self):
        self.assertIn(f'public static let unknownDisplay = "{DASH}"', self.source)
        self.assertIn('"member.card.unknownValue"', self.source)
        self.assertNotEqual(DASH, "0")
        for banned in ["https://", "ICP", "京ICP", "support@", "隐私政策", "用户协议"]:
            self.assertNotIn(banned, self.source)

    def test_accessibility_identifiers_are_declared_once(self):
        block = re.search(r"accessibilityIdentifiers = \[(.*?)\]", self.source, re.S)
        self.assertIsNotNone(block)
        declared = re.findall(r'"(member\.[^"]+)"', block.group(1))
        self.assertGreaterEqual(len(declared), 8)
        self.assertEqual(len(declared), len(set(declared)))

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
