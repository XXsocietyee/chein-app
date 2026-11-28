#!/usr/bin/env python3
"""CB212 page-ready contract for pages/activity/official-detail. Source checks only."""
import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
PAGE = "pages/activity/official-detail/index"
STRINGS = ROOT / "docs/release/ui-strings-pages-activity-official-detail-index.json"
MODEL = ROOT / "Core/OfficialEventDetailPresentation.swift"
FIXTURE = ROOT / "Core/OfficialEventSyntheticFixtures.swift"
READING = ROOT / "Core/OfficialEventReading.swift"
SERVICE = ROOT / "Core/OfficialEventService.swift"
TESTS = ROOT / "Tests/CoreTests/OfficialEventDetailPresentationTests.swift"
DASH = "\u2014"
FLAGS = (
    "showsMerchantChoice",
    "paymentEnabled",
    "payoutEnabled",
    "withdrawalEnabled",
    "virtualGoodsEnabled",
)


def read(path):
    return path.read_text() if isinstance(path, pathlib.Path) else (ROOT / path).read_text()


class OfficialDetailPageReadyChecks(unittest.TestCase):
    def test_model_has_loading_empty_error_and_unknown_without_a_new_route(self):
        model = read(MODEL)
        state = model[model.index("public struct OfficialEventDetailPageState"):]
        for phase in ("loading", "empty", "error", "unknown", "ready"):
            self.assertIn(f"case {phase}", model)
        self.assertIn(f'public static let unknownText = "{DASH}"', state)
        for flag in FLAGS:
            self.assertIn(f"public static let {flag} = false", state)
            self.assertNotIn(f"public static let {flag} = true", state)
        self.assertIn("public static let registersRoute = false", state)
        self.assertIn("public static let marksRouteLive = false", state)
        self.assertIn("public static let shareVisible = false", state)
        self.assertIn("public static let usesExistingDetailRead = true", state)
        project = state[state.index("static func project"):]
        self.assertLess(project.index("if loading"), project.index("if error != nil"))
        self.assertLess(project.index("if error != nil"), project.index("event.isCompleteRecord"))
        self.assertLess(project.index("event.isCompleteRecord"), project.index('"official.status.unknown"'))
        self.assertNotIn("http://", state)
        self.assertNotIn("https://", state)
        self.assertNotIn("api/official", state)
        self.assertNotIn("signup", state)
        self.assertIn("func detail(id: Int)", read(READING))
        service = read(SERVICE)
        self.assertIn('get("api/official/events/\\(id)"', service)
        self.assertNotIn("share", service)

    def test_unknown_dash_and_literal_zero_tests_stay(self):
        tests = read(TESTS)
        body = tests[tests.index("func testMissingCountsStayDashAndLiteralZeroStaysZero"):]
        body = body[:body.index("\n    func ")]
        self.assertIn('XCTAssertEqual(zero[0].value, .verbatim("0"))', body)
        self.assertIn('XCTAssertEqual(missing[0].value, .verbatim("—"))', body)
        added = tests[tests.index("func testDetailPageStateKeepsLoadingEmptyErrorAndUnknownOffZero"):]
        self.assertIn("OfficialEventDetailFixtureData.unknown", added)
        self.assertIn("OfficialEventDetailFixtureData.empty", added)
        self.assertIn("OfficialEventDetailFixtureData.literalZero", added)
        self.assertIn('XCTAssertEqual(ready.participantsText, "0")', added)
        self.assertIn('XCTAssertEqual(unknown.participantsText, "—")', added)
        self.assertIn("XCTAssertEqual(loading.phase, .loading)", added)
        self.assertIn("XCTAssertEqual(empty.phase, .empty)", added)
        self.assertIn("XCTAssertEqual(failed.phase, .error)", added)

    def test_detail_fixture_data_is_debug_only(self):
        fixture = read(FIXTURE)
        self.assertTrue(fixture.startswith("#if DEBUG\n"))
        self.assertTrue(fixture.rstrip().endswith("#endif"))
        self.assertLess(fixture.index("public enum OfficialEventDetailFixtureData"), fixture.rindex("#endif"))
        self.assertIn("public static let content = OfficialEventSyntheticFixtures.eventJSON", fixture)
        self.assertNotIn("http://", fixture)
        self.assertNotIn("https://", fixture)
        # Doc comments may say "no token"; only code may not carry one.
        code = "\n".join(line for line in fixture.splitlines() if not line.lstrip().startswith("//"))
        self.assertNotIn("token", code.lower())

    def test_string_catalog_is_bilingual_and_matches_existing_keys(self):
        document = json.loads(read(STRINGS))
        self.assertEqual(document["page"], PAGE)
        self.assertEqual(document["native"], "App/OfficialEventDetailView.swift")
        catalog = json.loads(read("Resources/Localizable.xcstrings"))["strings"]
        self.assertGreaterEqual(len(document["strings"]), 100)
        seen = set()
        banned = re.compile(r"https?://|备案|ICP|support@|privacy policy|terms of service|user-generated|\bUGC\b", re.I)
        for row in document["strings"]:
            key = row["key"]
            self.assertNotIn(key, seen)
            seen.add(key)
            self.assertIn(key, catalog)
            for language in ("en", "zh-Hans"):
                value = row[language]
                self.assertTrue(value.strip())
                # en-layout r3: English count strings carry plural variations; read the `other` form.
                loc = catalog[key]["localizations"][language]
                unit = loc.get("stringUnit") or loc["variations"]["plural"]["other"]["stringUnit"]
                self.assertEqual(value, unit["value"])
                self.assertIsNone(banned.search(value), value)
        inline = document["inline"]
        self.assertEqual(inline, [{
            "en": "Verify in Roam",
            "zh-Hans": "去漫游完成",
            "source": "App/OfficialOrganizerConsoleView.swift",
        }])
        self.assertIn('CoreLoopCopy(locale: locale).t("去漫游完成", "Verify in Roam")',
                      read(inline[0]["source"]))
        self.assertGreaterEqual(len(document["accessibilityIdentifiers"]), 20)
        for item in document["accessibilityIdentifiers"]:
            self.assertIn(item["pattern"], read(item["source"]))
            self.assertTrue(item["id"])


if __name__ == "__main__":
    unittest.main()
