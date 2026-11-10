"""Source checks for the income-detail page model. Does not run Swift or Xcode."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DASH = "\u2014"
JSON_PATH = ROOT / "docs/release/ui-strings-subpackageA-pages-assetcenter-income-detail-income-detail.json"


class IncomeDetailPageReadyContracts(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()

    def test_catalog_has_both_languages_and_accessibility_ids(self):
        catalog = json.loads(JSON_PATH.read_text())
        self.assertEqual(catalog["page"], "subpackageA/pages/assetcenter/income-detail/income-detail")
        self.assertIs(catalog["showsMerchantChoice"], False)
        self.assertEqual(catalog["existingReadPath"], "api/user/balance/list")
        self.assertGreaterEqual(len(catalog["strings"]), 30)
        keys = set()
        for row in catalog["strings"]:
            self.assertEqual(set(row), {"key", "en", "zh-Hans"})
            self.assertTrue(row["key"] and row["en"] and row["zh-Hans"])
            self.assertNotIn(row["key"], keys)
            keys.add(row["key"])
            self.assertNotIn("http://", row["en"] + row["zh-Hans"])
            self.assertNotIn("https://", row["en"] + row["zh-Hans"])
        unknown = next(row for row in catalog["strings"] if row["key"] == "wallet.income.detail.unknownMoney")
        self.assertEqual(unknown["en"], DASH)
        self.assertEqual(unknown["zh-Hans"], DASH)
        self.assertNotEqual(unknown["en"], "0")
        ids = catalog["accessibilityIdentifiers"]
        seen = set()
        for row in ids:
            self.assertEqual(set(row), {"id", "en", "zh-Hans", "source"})
            self.assertTrue(row["id"] and row["en"] and row["zh-Hans"] and row["source"])
            self.assertNotIn(row["id"], seen)
            seen.add(row["id"])
            self.assertIn(row["id"], self.read(row["source"]))
        self.assertIn("wallet.income.detail.unknownMoney", seen)
        self.assertIn("wallet.ledger.empty", seen)
        self.assertIn("wallet.fixture.income", seen)

    def test_model_states_and_existing_read_stay_hidden_when_off(self):
        model = self.read("Core/WalletIncomeDay.swift")
        safety = self.read("Core/WalletCommerceSafety.swift")
        service = self.read("Core/WalletCommerceService.swift")
        welcome = self.read("App/WelcomeView.swift")
        self.assertIn('public static let unknownMoney = "\\u{2014}"', model)
        self.assertIn('existingReadPath = "api/user/balance/list"', model)
        self.assertIn('path = "api/user/balance/list"; paged = true', service)
        for flag in (
            "registersRoute = false",
            "opensHost = false",
            "showsMerchantChoice = false",
            "showsOrganizerShare = false",
            "enablesPayment = false",
            "enablesPayout = false",
            "enablesWithdrawal = false",
            "enablesVirtualGoods = false",
        ):
            self.assertIn(flag, model)
        self.assertNotIn("showsMerchantChoice = true", model + welcome)
        self.assertNotIn("liveInProduction", model)
        self.assertNotIn("URLSession", model)
        self.assertIn("case loading, empty, error, unknown, ready", model)
        self.assertIn("guard let amount else { return unknownMoney }", model)
        self.assertNotIn('return "0"', model)
        self.assertIn("func incomeDetailListState()", safety)
        self.assertIn("func incomeDetailAmountState(", safety)
        self.assertIn("WalletIncomeDetailPageModel.list(loading: isLoading, failed: failed, hasLoadedPage: hasLoadedPage, rowCount: rows.count)", safety)
        self.assertIn("incomeDetail(rowID:", safety)

    def test_debug_fixture_data_preserves_the_existing_income_payload(self):
        fixture = self.read("Core/WalletCommerceSyntheticFixtures.swift")
        self.assertLess(fixture.index("#if DEBUG"), fixture.index("enum WalletIncomeDetailFixtureData"))
        self.assertIn('case "/api/user/balance/list": payload = WalletIncomeDetailFixtureData.incomeList', fixture)
        self.assertIn('WalletIncomeDetailFixtureData.errorEnvelope', fixture)
        self.assertIn('"changeBalance":"8.50"', fixture)
        self.assertIn('"changeBalance":"0"', fixture)
        self.assertIn("Synthetic missing amount", fixture)
        self.assertNotIn("URLSession", fixture)
        self.assertNotIn('case "/api/cart/order/settlement"', fixture)

    def test_existing_income_detail_tests_remain(self):
        tests = self.read("Tests/CoreTests/WalletCommerceTests.swift")
        for name in (
            "testIncomeDetailUsesLoadedRowWithoutAnotherRequest",
            "testIncomeDetailPreservesUnknownAmountsAndKnownZero",
            "testIncomeDetailRejectsAccountEpochNamespaceChangesAndLogout",
            "testIncomeDetailRetiredByRefreshEvenWithIdenticalRows",
            "testIncomeDetailFilterABADoesNotReviveOldSelection",
            "testIncomeDetailCannotOpenFromBalanceOrUnloadedPager",
        ):
            self.assertIn("func " + name, tests)
        added = self.read("Tests/CoreTests/WalletIncomeDetailPageModelTests.swift")
        self.assertIn("testLoadingEmptyErrorAndUnknownNeverShowZero", added)
        self.assertIn("testExistingBalanceListFeedsEmptyUnknownZeroAndError", added)
        self.assertNotIn("showsMerchantChoice = true", added)


if __name__ == "__main__":
    unittest.main()
