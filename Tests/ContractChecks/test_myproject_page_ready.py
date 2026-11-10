"""Page-ready contract for subpackageA/pages/myproject/index.

Swift tests in Tests/CoreTests/MyProjectPageReadyTests.swift cover the readout.
This file checks the source and the string manifest without Xcode.
"""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
EM = "\u2014"
DOC = ROOT / "docs/release/ui-strings-subpackageA-pages-myproject-index.json"


class MyProjectPageReadyContract(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()

    def test_string_manifest_matches_catalogs_and_names_unknown_as_em_dash(self):
        doc = json.loads(DOC.read_text())
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())
        editor = json.loads((ROOT / "Resources/MyProjectActivityEditor.xcstrings").read_text())
        self.assertEqual(doc["page"], "subpackageA/pages/myproject/index")
        self.assertGreaterEqual(len(doc["strings"]), 50)
        for key, value in doc["strings"].items():
            self.assertIn("en", value, key)
            self.assertIn("zh-Hans", value, key)
            self.assertTrue(value["en"] and value["zh-Hans"], key)
            loc = catalog["strings"][key]["localizations"]
            self.assertEqual(value["en"], loc["en"]["stringUnit"]["value"], key)
            self.assertEqual(value["zh-Hans"], loc["zh-Hans"]["stringUnit"]["value"], key)
        self.assertEqual(doc["editorTable"]["name"], "MyProjectActivityEditor")
        for key, value in doc["editorTable"]["strings"].items():
            loc = editor["strings"][key]["localizations"]
            self.assertEqual(value["en"], loc["en"]["stringUnit"]["value"], key)
            self.assertEqual(value["zh-Hans"], loc["zh-Hans"]["stringUnit"]["value"], key)
        for side in ("en", "zh-Hans"):
            self.assertEqual(doc["unknownMark"][side], EM)
            self.assertEqual(doc["states"]["unknown"][side], EM)
        self.assertNotEqual(doc["unknownMark"]["en"], "0")
        self.assertNotEqual(doc["unknownMark"]["en"], "-")
        self.assertEqual(len(doc["unknownMark"]["en"]), 1)

    def test_accessibility_identifiers_exist_in_non_view_or_existing_app_sources(self):
        doc = json.loads(DOC.read_text())
        sources = []
        for folder in ("App", "Core"):
            for path in (ROOT / folder).rglob("*.swift"):
                sources.append(path.read_text())
        blob = "\n".join(sources)
        for identifier in doc["accessibilityIdentifiers"]:
            self.assertIn('"' + identifier + '"', blob, identifier)
        for prefix in doc["accessibilityIdentifierPrefixes"]:
            self.assertIn('"' + prefix, blob, prefix)
        for state, spec in doc["states"].items():
            self.assertIn(spec["accessibilityIdentifier"], doc["accessibilityIdentifiers"], state)

    def test_model_keeps_unknown_counts_and_hides_missing_writes(self):
        contracts = self.read("Core/CreatorContentContracts.swift")
        presentation = self.read("Core/MyProjectListPresentation.swift")
        mutations = self.read("Core/MyProjectMutations.swift")
        self.assertIn('public static let unknownText = "\\u{2014}"', contracts)
        self.assertIn("guard container.contains(key), try container.decodeNil(forKey: key) == false else { return .unknown }", contracts)
        start = presentation.index("@MainActor public final class MyProjectPageCoordinator")
        end = presentation.index("public struct QuickPublishPointValidation")
        body = presentation[start:end]
        for token in ("case loading, empty, error, unknown, ready", "tab != .template",
                      "operationScope: operationScope", "reader.projects(query: query)",
                      "MyProjectCountFact.unknownText"):
            self.assertIn(token, presentation if token.startswith("case ") else body, token)
        for forbidden in ("showsMerchantChoice", "paymentEnabled", "payoutEnabled",
                          "withdrawalEnabled", "virtualGoodsEnabled", "https://", "http://",
                          "/api/topic/delete", "/api/activity/cancel", "update_publish_status",
                          "updateLibraryStatus", "/api/template/delete"):
            self.assertNotIn(forbidden, body)
        self.assertIn("{ .unavailable }", mutations)
        self.assertIn("GatedMyProjectMutator", presentation)

    def test_fixture_data_is_debug_only_and_existing_tests_stay(self):
        fixtures = self.read("Core/CreatorContentSyntheticFixtures.swift")
        debug = fixtures.split("#endif", 1)[0]
        self.assertTrue(debug.startswith("#if DEBUG"))
        self.assertIn("public enum MyProjectFixtureData", debug)
        self.assertNotIn("https://", debug)
        self.assertEqual(len(re.findall(r"func test\w+", self.read("Tests/CoreTests/MyProjectCardFieldsTests.swift"))), 3)
        self.assertEqual(len(re.findall(r"func test\w+", self.read("Tests/CoreTests/MyProjectListPresentationTests.swift"))), 13)
        self.assertEqual(len(re.findall(r"func test\w+", self.read("Tests/CoreTests/MyProjectMutationsTests.swift"))), 5)
        added = self.read("Tests/CoreTests/MyProjectPageReadyTests.swift")
        for name in ("testMissingAndNullCountsAreUnknownEmDashNotZero", "testLiteralZeroStaysZeroAndNegativeStaysLiteral",
                     "testWrongCountTypeStillFailsTheRow", "testFixtureReadyEmptyAndUnknownCounts",
                     "testTemplateTabStaysUnknownAndDoesNotReadProjects", "testSignedOutAndUnconfiguredDoNotRead",
                     "testFailureClearsRowsAndCancellationStaysLoading", "testLoadingIsVisibleAndInvalidQueryDoesNotRead",
                     "testPageAccessibilityIdentifiers"):
            self.assertIn("func " + name, added)
        self.assertNotIn("paymentEnabled = true", added)
        self.assertNotIn("https://", added)


if __name__ == "__main__":
    unittest.main()
