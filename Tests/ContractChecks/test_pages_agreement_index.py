"""Source checks for pages/agreement/index. Not a Swift or Xcode run."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DASH = "\u2014"


class PagesAgreementIndexTests(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()

    def test_page_facts_keep_unknown_as_an_em_dash_and_hide_the_missing_route(self):
        source = self.read("Core/SettingsIdentityApplications.swift")
        catalog = self.read("Core/ChinaReviewedRouteCapability.swift")
        for token in [
            "case loading",
            "case empty(SettingsLegalMissingReason)",
            "case error",
            "case unknown",
            "case ready(SettingsLegalDocument)",
            'public static let unknownDisplay = "—"',
            "guard let count else { return unknownDisplay }",
            "return String(count)",
            'hiddenAgreementGetPath = "api/agreement/get"',
            "agreementGetStaysHidden",
            "mark(for: \"/\" + hiddenAgreementGetPath) == nil",
            "admitsChinaProductionCall(\"/\" + hiddenAgreementGetPath) == false",
        ]:
            self.assertIn(token, source)
        self.assertIn(DASH, source)
        self.assertNotIn('"/api/agreement/get"', catalog)
        for forbidden in [
            "showsMerchantChoice = true",
            "paymentEnabled = true",
            "payoutEnabled = true",
            "withdrawalEnabled = true",
            "virtualGoodsEnabled = true",
            "https://",
            "http://",
            "URLSession",
            "URLRequest",
        ]:
            self.assertNotIn(forbidden, source)
        self.assertIn("public var isReleaseApproved: Bool { false }", self.read("Core/SettingsLegalContracts.swift"))
        self.assertNotIn("func accept", self.read("App/SettingsLegalDocumentView.swift"))

    def test_debug_fixture_data_is_compiled_out_of_release(self):
        source = self.read("Core/SettingsIdentityApplications.swift")
        start = source.index("#if DEBUG")
        end = source.index("#endif", start)
        body = source[start:end]
        self.assertIn("public enum SettingsLegalAgreementFixtureData {", body)
        self.assertNotIn("public enum SettingsLegalAgreementFixtureData {", source[end:])
        for label in ["fixture-title", "fixture-v0", "fixture-heading", "fixture-body"]:
            self.assertIn(label, body)
        self.assertNotIn("15229020419", body)
        self.assertNotIn("ICP", body)

    def test_strings_have_english_chinese_and_accessibility_identifiers(self):
        payload = json.loads(self.read("docs/release/ui-strings-pages-agreement-index.json"))
        self.assertEqual(payload["page"], "pages/agreement/index")
        strings = payload["strings"]
        identifiers = payload["accessibilityIdentifiers"]
        self.assertGreaterEqual(len(strings), 15)
        self.assertGreaterEqual(len(identifiers), 8)
        keys = [row["key"] for row in strings]
        ids = [row["id"] for row in identifiers]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertEqual(len(ids), len(set(ids)))
        for row in strings + identifiers:
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
        self.assertNotIn("settingsNative.legal.unknown", keys)
        self.assertIn("settingsNative.legal.unknown", ids)
        unknown = next(row for row in identifiers if row["id"] == "settingsNative.legal.unknown")
        self.assertEqual(unknown["en"], DASH)
        self.assertEqual(unknown["zh-Hans"], DASH)
        source = self.read("Core/SettingsIdentityApplications.swift")
        for identifier in ids:
            token = identifier.replace(".{index}", "")
            self.assertIn(token, source)
        catalog = json.loads(self.read("docs/settings-native-localizations.json"))
        existing = {row["key"]: row for row in catalog}
        for row in strings:
            self.assertEqual(existing[row["key"]]["en"], row["en"])
            self.assertEqual(existing[row["key"]]["zh-Hans"], row["zh-Hans"])
        joined = json.dumps(payload, ensure_ascii=False)
        self.assertNotIn("15229020419", joined)
        self.assertNotIn("[ICP_FILING_PLACEHOLDER]", joined)
        self.assertNotIn("[SUPPORT_CONTACT_PLACEHOLDER]", joined)

    def test_existing_legal_tests_remain(self):
        admission = self.read("Tests/CoreTests/SettingsLegalCancellationAdmissionTests.swift")
        native = self.read("Tests/CoreTests/SettingsNativeTests.swift")
        self.assertIn("func testAlreadyCancelledEntryDoesNotStartReaderOrPublishLoading", admission)
        self.assertIn("func testDocumentFailureAndRetry", native)
        self.assertIn("func testUnknownRouteMatchesSourceFallbackButStillHonorsMarket", native)
        added = self.read("Tests/CoreTests/SettingsLegalAgreementPageTests.swift")
        self.assertIn("func testUnknownCountIsAnEmDashAndALiteralZeroStaysZero", added)
        self.assertIn("func testBundledReaderProjectsReadyEmptyAndErrorWithoutANetworkRoute", added)
        self.assertGreaterEqual(added.count("func test"), 8)


if __name__ == "__main__":
    unittest.main()
