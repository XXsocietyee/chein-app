"""PAGE-READY source contract for the play-detail document. Does not compile Swift or run Xcode."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
STRINGS = ROOT / "docs/release/ui-strings-subpackageA-pages-infomationdetail-infomationdetail.json"
MODEL = ROOT / "Core/ProfileGuideRead.swift"
FIXTURE = ROOT / "Core/SocialAccountSyntheticFixtures.swift"
FORBIDDEN_TRUE = (
    "showsMerchantChoice = true",
    "paymentEnabled = true",
    "payoutEnabled = true",
    "withdrawalEnabled = true",
    "virtualGoodsEnabled = true",
)


class InformationDetailPageReady(unittest.TestCase):
    def test_strings_are_bilingual_and_name_accessibility_ids(self):
        document = json.loads(STRINGS.read_text())
        self.assertEqual(document["page"], "subpackageA/pages/infomationdetail/infomationdetail")
        keys = [row["key"] for row in document["strings"]]
        self.assertEqual(len(keys), len(set(keys)))
        for row in document["strings"]:
            self.assertTrue(row["en"].strip(), row["key"])
            self.assertTrue(row["zh-Hans"].strip(), row["key"])
            self.assertNotIn("http://", row["en"])
            self.assertNotIn("https://", row["en"])
            self.assertNotIn("http://", row["zh-Hans"])
            self.assertNotIn("https://", row["zh-Hans"])
        self.assertEqual(document["strings"][-1]["key"], "informationDetail.state.unknown")
        self.assertEqual(document["strings"][-1]["en"], "—")
        self.assertEqual(document["strings"][-1]["zh-Hans"], "—")
        identifiers = document["accessibilityIdentifiers"]
        for required in (
            "social.information.detail",
            "social.information.createTime",
            "social.information.detail.loading",
            "social.information.detail.empty.incompleteLink",
            "social.information.detail.empty.removed",
            "social.information.detail.error",
            "social.information.detail.unknown",
        ):
            self.assertIn(required, identifiers)
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())["strings"]
        for row in document["strings"]:
            if row["key"] == "informationDetail.state.unknown":
                # Value mark stays an em dash on ProfileCurrentReview (the row's table).
                # The restyled detail empty state looks the same key up from Localizable as a sentence.
                feature = json.loads((ROOT / "Resources/ProfileCurrentReview.xcstrings").read_text())["strings"][row["key"]]
                for language in ("en", "zh-Hans"):
                    self.assertEqual(feature["localizations"][language]["stringUnit"]["value"], row[language])
                    shown = catalog[row["key"]]["localizations"][language]["stringUnit"]["value"].strip()
                    self.assertTrue(shown)
                    self.assertNotEqual(shown, "0")
                continue
            for language in ("en", "zh-Hans"):
                self.assertEqual(
                    catalog[row["key"]]["localizations"][language]["stringUnit"]["value"],
                    row[language],
                    row["key"],
                )

    def test_model_keeps_existing_detail_path_and_unknown_em_dash(self):
        source = MODEL.read_text()
        self.assertIn("public static let detailPath = \"api/common/infomation_detail\"", source)
        self.assertIn("public static let contractPath = ProfileGuideReadRoute.detailPath", source)
        for phase in ("case loading", "case empty(EmptyReason)", "case error(status: Int?, message: String?)", "case unknown", "case ready(SocialInformation)"):
            self.assertIn(phase, source)
        self.assertIn("public static let unknownDisplay = \"—\"", source)
        self.assertIn("return Self.unknownDisplay", source)
        self.assertIn("guard readCapabilityPresent, path == Self.contractPath else", source)
        for flag in FORBIDDEN_TRUE:
            self.assertNotIn(flag, source)
        self.assertNotIn("liveInProduction", source)
        self.assertNotIn("https://", source)
        self.assertNotIn("http://", source)

    def test_fixture_data_is_debug_only_and_uses_the_existing_path(self):
        source = FIXTURE.read_text()
        self.assertTrue(source.startswith("#if DEBUG\n"))
        self.assertIn("public enum InformationDetailFixtureData", source)
        self.assertLess(source.index("public enum InformationDetailFixtureData"), source.rindex("#endif"))
        self.assertIn('public static let contractPath = "api/common/infomation_detail"', source)
        body = source.split("public enum InformationDetailFixtureData", 1)[1]
        self.assertNotIn("https://", body)
        self.assertNotIn("http://", body)
        for flag in FORBIDDEN_TRUE:
            self.assertNotIn(flag, body)

    def test_unit_tests_cover_states_without_removing_prior_files(self):
        tests = (ROOT / "Tests/CoreTests/InformationDetailPageModelTests.swift").read_text()
        for name in (
            "testLoadingEmptyErrorAndUnknownStayDistinct",
            "testUnknownCountIsAnEmDashAndLiteralZeroStaysZero",
            "testMissingCapabilityOrOtherPathStaysHidden",
            "testCommerceFlagsStayOffAndURLMessagesAreDropped",
        ):
            self.assertIn(name, tests)
        self.assertIn("#if DEBUG", tests)
        self.assertTrue((ROOT / "Tests/CoreTests/W2GuideXcxParityTests.swift").is_file())
        self.assertTrue((ROOT / "Tests/CoreTests/ProfileGuideReadRouteTests.swift").is_file())


if __name__ == "__main__":
    unittest.main()
