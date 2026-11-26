"""Page-ready contract for the earnings overview. Not a Swift or simulator run."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "docs/release/ui-strings-subpackageA-pages-assetcenter-earnings-index.json"
UNKNOWN = "\u2014"


def read(path):
    return (ROOT / path).read_text()


def catalog(name):
    return json.loads((ROOT / "Resources" / f"{name}.xcstrings").read_text())["strings"]


class EarningsOverviewPageReady(unittest.TestCase):
    def test_strings_match_catalogs_and_name_accessibility_ids(self):
        document = json.loads(DOC.read_text())
        self.assertEqual(document["page"], "subpackageA/pages/assetcenter/earnings/index")
        self.assertEqual(document["unknownMoney"], UNKNOWN)
        self.assertNotEqual(document["unknownMoney"], "0")
        tables = {}
        app = "\n".join(path.read_text() for path in (ROOT / "App").rglob("*.swift"))
        for row in document["strings"]:
            self.assertTrue(row["key"] and row["en"] and row["zh-Hans"] and row["accessibilityIdentifier"])
            self.assertNotIn("http://", row["en"] + row["zh-Hans"])
            self.assertNotIn("https://", row["en"] + row["zh-Hans"])
            for banned in ("ICP", "UGC", "客服", "WeChat"):
                self.assertNotIn(banned, row["en"])
                self.assertNotIn(banned, row["zh-Hans"])
            table = tables.setdefault(row["table"], catalog(row["table"]))
            self.assertEqual(table[row["key"]]["localizations"]["en"]["stringUnit"]["value"], row["en"])
            self.assertEqual(table[row["key"]]["localizations"]["zh-Hans"]["stringUnit"]["value"], row["zh-Hans"])
            identifier = row["accessibilityIdentifier"]
            self.assertTrue(f'"{identifier}"' in app or f'"{identifier}.' in app, identifier)
            if row["key"] in {"wallet.earnings.stages.unknown", "wallet.earnings.stages.unconfigured", "wallet.earnings.finance.unconfigured"}:
                self.assertEqual(row["en"], UNKNOWN)
                self.assertEqual(row["zh-Hans"], UNKNOWN)
        hidden = [row for row in document["strings"] if row.get("shown") is False]
        self.assertEqual({row["accessibilityIdentifier"] for row in hidden}, {"wallet.withdrawalSupport.open", "wallet.withdrawals.open"})

    def test_fixture_is_debug_only_and_money_switches_stay_off(self):
        fixture = read("Core/WalletCommerceSyntheticFixtures.swift")
        self.assertLess(fixture.find("#if DEBUG"), fixture.find("enum WalletEarningsOverviewFixtureData"))
        self.assertIn('case "/api/wallet/stages": payload = WalletEarningsOverviewFixtureData.stagesUnknown', fixture)
        self.assertIn("guard known, let amount else { return unknownMoney }", fixture)
        for path in ("/api/withdrawal/create", "/api/asset/withdraw", "/api/wallet/withdraw", "/api/club/settlement/withdraw"):
            self.assertNotIn(path, fixture)
        views = read("App/WalletCommerceViews.swift")
        # Owner 2026-11-25: withdrawal follows the host switch in Release and DEBUG/TEST.
        cap = views[views.index("enum WalletPayoutCapability {"):]
        cap = cap[:cap.index("\n}\n")]
        self.assertIn("static var isOn: Bool { ReleaseMoneyWriteSwitch.withdrawalEnabled }", cap)
        self.assertNotIn("static let isOn = false", cap)
        self.assertIn("static let showsMerchantChoice = false", read("App/WelcomeView.swift"))
        switches = read("Core/ChinaReviewedRouteCapability.swift")
        for name in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn(f"public static var {name}: Bool {{ testDerivation?", switches)
        unit = read("Tests/CoreTests/WalletCommerceTests.swift")
        self.assertIn("func testEarningsOverviewFixtureKeepsUnknownAsEmDashAndKnownZero", unit)
        self.assertIn('XCTFail("fixture sent a withdrawal")', unit)


if __name__ == "__main__":
    unittest.main()
