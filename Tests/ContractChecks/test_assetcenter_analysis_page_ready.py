"""Page-ready contract for asset-balance analysis. Source only; no Xcode and no network."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]
EM = "—"


def read(path):
    return (ROOT / path).read_text()


class AssetCenterAnalysisPageReadyTests(unittest.TestCase):
    def test_string_catalog_has_both_languages_and_existing_identifiers(self):
        doc = json.loads(read("docs/release/ui-strings-subpackageA-pages-assetcenter-analysis-index.json"))
        self.assertEqual(doc["page"], "subpackageA/pages/assetcenter/analysis/index")
        self.assertEqual(doc["mapStatus"], "exists")
        self.assertGreaterEqual(len(doc["strings"]), 30)
        for row in doc["strings"]:
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            self.assertNotIn("http", row["en"].lower())
            self.assertNotIn("http", row["zh-Hans"].lower())
            expected = "WalletIncomeAnalysisRead" if row["key"].startswith("wallet.analysis.read.") else "WalletIncomeAnalysis"
            self.assertEqual(row["table"], expected)
        unverified = next(row for row in doc["strings"] if row["key"] == "wallet.analysis.unverified")
        self.assertEqual(unverified["en"], EM)
        self.assertEqual(unverified["zh-Hans"], EM)
        ids = [item["id"] for item in doc["accessibilityIdentifiers"]]
        self.assertEqual(ids, [
            "wallet.analysis",
            "wallet.analysis.loading",
            "wallet.analysis.partial.retry",
            "wallet.analysis.open",
        ])
        view = read("App/WalletIncomeAnalysisView.swift")
        home = read("App/WalletCommerceViews.swift")
        for identifier in ids[:3]:
            self.assertIn('.accessibilityIdentifier("%s")' % identifier, view)
        # R7-PC-D5-2: the earnings home opens analysis from its quick action only.
        self.assertIn('id: "wallet.analysis.quick"', home)
        self.assertIn(".accessibilityIdentifier(id)", home)

    def test_model_states_use_em_dash_and_the_existing_income_route(self):
        model = read("Core/WalletCommerceContracts.swift")
        self.assertIn("public struct AssetCenterAnalysisPageModel", model)
        self.assertIn('public static let unknownMoney = "%s"' % EM, model)
        self.assertIn('public static let incomeListPath = "api/user/balance/list"', model)
        for phase in ["loading", "empty", "error", "unknown", "ready"]:
            self.assertIn("case %s" % phase, model)
        self.assertNotIn("price ?? 0", model)
        self.assertNotIn("api/withdrawal/create", model)
        self.assertNotIn("http", model[model.index("struct AssetCenterAnalysisPageModel"):])
        reader = read("App/WalletIncomeAnalysisReader.swift")
        self.assertIn("var pageModel: AssetCenterAnalysisPageModel", reader)
        self.assertIn("result.isPartial ? .unknown : .empty", reader)
        self.assertIn("$0.ledger(.income(.all), page: pageNumber", reader)

    def test_fixture_data_is_debug_only_and_does_not_enable_payout(self):
        fixture = read("Core/WalletCommerceSyntheticFixtures.swift")
        start = fixture.index("enum AssetCenterAnalysisFixtureData")
        self.assertLess(fixture.index("#if DEBUG"), start)
        self.assertLess(start, fixture.rindex("#endif"))
        self.assertIn("default: throw APIError.invalidRequest", fixture)
        self.assertNotIn("URLSession", fixture)
        self.assertNotIn("case \"/api/cart/order/settlement\"", fixture)
        self.assertNotIn("showsMerchantChoice = true", fixture)
        self.assertNotIn("api/withdrawal/create", fixture)
        self.assertIn("unknownAmountPage", fixture)
        self.assertIn("knownZeroPage", fixture)

    def test_existing_analysis_closure_tests_stay_intact(self):
        source = read("Tests/AppUnitTests/WalletIncomeAnalysisClosureTests.swift")
        self.assertEqual(len(__import__("re").findall(r"func test", source)), 12)
        contract = read("Tests/ContractChecks/test_wallet_income_analysis_closure.py")
        self.assertIn("self.assertEqual(len(re.findall(r'func test',s)),12)", contract)


if __name__ == "__main__":
    unittest.main()
