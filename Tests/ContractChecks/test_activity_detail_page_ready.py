"""CB209 page-ready contract for pages/activity/detail/index.

Source checks only. This does not compile Swift, run xcodebuild, or call a network.
"""
import json
import pathlib
import re
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[2]
DOC = ROOT / "docs/release/ui-strings-pages-activity-detail-index.json"
MODEL = ROOT / "Core/ActivityDetailHeaderPresentation.swift"
HOST = ROOT / "Core/ActivityHostCancel.swift"
SWIFT_TESTS = ROOT / "Tests/CoreTests/ActivityDetailPageReadyTests.swift"
HOST_TESTS = ROOT / "Tests/CoreTests/ActivityHostCancelTests.swift"
PAGE_SOURCES = (
    "App/ActivityDetailView.swift",
    "App/ActivityPresentationComponents.swift",
    "App/ActivityReviewsSection.swift",
    "App/ActivityPeopleSection.swift",
    "App/ActivityAssociatedPlaysSection.swift",
    "App/ActivityHostCancelView.swift",
    "App/ActivityFixtureSupport.swift",
)
FLAGS = (
    "showsMerchantChoice",
    "paymentEnabled",
    "payoutEnabled",
    "withdrawalEnabled",
    "virtualGoodsEnabled",
)


def read(path):
    return (ROOT / path).read_text() if not isinstance(path, pathlib.Path) else path.read_text()


class ActivityDetailPageReadyContractTests(unittest.TestCase):
    def setUp(self):
        if not DOC.exists():
            self.skipTest("ENV: docs/release/ui-strings-*.json mini-program string inventories are not part of this repo layout")
        self.doc = json.loads(DOC.read_text())
        self.model = MODEL.read_text()
        self.catalog = json.loads(read("Resources/Localizable.xcstrings"))["strings"]

    def test_model_has_loading_empty_error_and_em_dash_unknown(self):
        for token in ("case loading", "case empty", "case error", 'unknownDisplay = "—"'):
            self.assertIn(token, self.model)
        self.assertNotIn("?? 0", self.model)
        self.assertNotIn("Date()", self.model)
        self.assertNotIn("URLSession", self.model)
        self.assertNotIn("participants.count", self.model)
        self.assertIn('readPath = "api/activity/info"', self.model)
        self.assertNotIn("api/club/activity/detail", self.model)
        for flag in FLAGS:
            self.assertIn(f"let {flag} = false", self.model)
            self.assertNotIn(f"let {flag} = true", self.model)
        for token in (
            'joined(separator: " · ")',
            "registrationCount = detail.people.registrationCount",
            "meetingPoint = .unconfirmed",
        ):
            self.assertIn(token, self.model)

    def test_fixture_data_is_debug_only_and_parses(self):
        start = self.model.index("#if DEBUG\n")
        end = self.model.index("#endif", start)
        body = self.model[start:end]
        self.assertIn("enum ActivityDetailPageFixtureData", body)
        self.assertNotIn("enum ActivityDetailPageFixtureData", self.model[end:])
        raws = re.findall(r'#"(\{(?:(?!"#).)*\})"#', body)
        self.assertGreaterEqual(len(raws), 7)
        for raw in raws:
            json.loads(raw)
        self.assertNotIn("https://", body)
        self.assertNotRegex(body, r"api\.us|USA_API|sk_live|AKIA")

    def test_strings_match_catalog_and_identifiers_exist(self):
        self.assertEqual(self.doc["page"], "pages/activity/detail/index")
        self.assertEqual(self.doc["table"], "Localizable")
        keys = [row["key"] for row in self.doc["strings"]]
        self.assertEqual(len(keys), len(set(keys)))
        self.assertGreaterEqual(len(keys), 60)
        for row in self.doc["strings"]:
            entry = self.catalog[row["key"]]
            for lang in ("en", "zh-Hans"):
                unit = entry["localizations"][lang]["stringUnit"]
                self.assertEqual(unit["state"], "translated", row["key"])
                self.assertEqual(unit["value"], row[lang])
                self.assertTrue(row[lang].strip())
        sources = "\n".join(read(path) for path in PAGE_SOURCES)
        for item in self.doc["accessibilityIdentifiers"]:
            self.assertIn(item["id"], sources, item["id"])
        for pattern in self.doc["accessibilityPatterns"]:
            self.assertIn(pattern, sources, pattern)
        host = read("App/ActivityHostCancelView.swift")
        for row in self.doc["inlineCopy"]:
            self.assertIn(row["zh-Hans"], host)
            self.assertIn(row["en"], host)

    def test_swift_tests_cover_states_without_removing_host_cancel_tests(self):
        tests = SWIFT_TESTS.read_text()
        for name in (
            "testCapabilityStaysOnTheLiveReadAndKeepsWritesHidden",
            "testLoadingAndFailureDoNotInventCounts",
            "testReadyFixtureKeepsKnownNumbers",
            "testUnknownFixtureIsAnEmDashAndNotZero",
            "testExplicitZeroStaysZero",
            "testEmptyShellAndBlankTitle",
            "testClubGateHidesTheActivityBody",
            "testDateOnlyActivityStaysReadyWithUnknownCounts",
        ):
            self.assertIn(f"func {name}()", tests)
        host_tests = HOST_TESTS.read_text()
        for name in ("testReasonRules", "testHostIdentity", "testPreviewVariants",
                     "testCancelSendsTrimmedReasonAndMapsOutcome", "testInvalidAndDisabledSendNothing",
                     "testUnknownPaidPlayerCountIsAnEmDash"):
            self.assertIn(f"func {name}()", host_tests)
        self.assertIn("paidPlayerCountText", HOST.read_text())


if __name__ == "__main__":
    unittest.main()
