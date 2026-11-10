"""pages/club/apply/index page-model contract. Does not compile Swift or run xcodebuild."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODEL = "Core/ClubHostApplyPort.swift"
CATALOG = "docs/release/ui-strings-pages-club-apply-index.json"
EM = "—"


def read(path):
    return (ROOT / path).read_text()


class ClubHostApplyPageModelContract(unittest.TestCase):
    def test_model_keeps_existing_routes_and_hides_a_missing_capability(self):
        source = read(MODEL)
        self.assertIn('public static let statusPath = ClubGovernanceRead.hostStatus.path', source)
        self.assertIn('public static let submitPath = ClubGovernanceMutation.hostApply.path', source)
        self.assertIn("case hidden", source)
        self.assertIn("case loading", source)
        self.assertIn("case empty", source)
        self.assertIn("case error", source)
        self.assertIn("case unknown", source)
        self.assertIn('public static let unknownDisplay = "—"', source)
        self.assertIn("public static let showsOnPlayerFirstEntry = false", source)
        self.assertIn("public static let showsMerchantChoice = false", source)
        self.assertNotIn("showsMerchantChoice = true", source)
        self.assertNotIn("paymentEnabled = true", source)
        self.assertNotIn("payoutEnabled = true", source)
        self.assertNotIn("withdrawalEnabled = true", source)
        self.assertNotIn("virtualGoodsEnabled = true", source)
        self.assertNotIn("liveInProduction", source)
        self.assertIn("#if DEBUG", source)
        self.assertIn("public enum ClubHostApplyFixtureData", source)
        self.assertLess(source.index("#if DEBUG"), source.index("public enum ClubHostApplyFixtureData"))
        self.assertIn(MODEL, read("Questify.xcodeproj/project.pbxproj"))
        welcome = read("App/WelcomeView.swift")
        self.assertIn("static let showsMerchantChoice = false", welcome)
        self.assertNotIn("showsMerchantChoice = true", welcome)

    def test_string_catalog_has_both_locales_and_identifiers(self):
        document = json.loads(read(CATALOG))
        self.assertEqual(document["page"], "pages/club/apply/index")
        self.assertFalse(document["showsOnPlayerFirstEntry"])
        self.assertFalse(document["showsMerchantChoice"])
        title = document["title"]
        self.assertTrue(title["en"])
        self.assertEqual(title["zh-Hans"], "申请成为俱乐部主理人")
        xcstrings = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        identifiers = set()
        keys = set()
        for row in document["strings"]:
            self.assertTrue(row["key"])
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            self.assertTrue(row["accessibilityIdentifier"])
            self.assertNotIn("http://", row["en"] + row["zh-Hans"])
            self.assertNotIn("https://", row["en"] + row["zh-Hans"])
            identifiers.add(row["accessibilityIdentifier"])
            keys.add(row["key"])
            if row["key"] in xcstrings:
                locs = xcstrings[row["key"]]["localizations"]
                self.assertEqual(row["en"], locs["en"]["stringUnit"]["value"])
                self.assertEqual(row["zh-Hans"], locs["zh-Hans"]["stringUnit"]["value"])
        for identifier in [
            "club.host.apply.hidden", "club.host.apply.loading", "club.host.apply.empty",
            "club.host.apply.error", "club.host.apply.unknown", "club.host.apply.intro",
            "club.host.apply.merchantBlocked", "club.host.apply.host",
            "club.host.apply.allowance", "club.host.apply.selectedCount",
            "club.gov.openHost", "club.ops.applyHost", "club.gov.action.hostApply",
            "club.gov.input.leaderName", "club.gov.input.phone",
        ]:
            self.assertIn(identifier, identifiers)
        unknown = next(row for row in document["strings"] if row["key"] == "club.host.apply.unknownCount")
        self.assertEqual(unknown["en"], EM)
        self.assertEqual(unknown["zh-Hans"], EM)
        self.assertNotEqual(unknown["en"], "0")
        for key in ["club.host.apply.loading", "club.host.apply.unknownCount"]:
            self.assertIn(key, keys)
            self.assertNotIn(key, xcstrings)
        for existing in ["ClubHostApplyDraftTests.swift", "Port1ClubHostApplyTests.swift"]:
            self.assertTrue((ROOT / "Tests/CoreTests" / existing).is_file())


if __name__ == "__main__":
    unittest.main()
