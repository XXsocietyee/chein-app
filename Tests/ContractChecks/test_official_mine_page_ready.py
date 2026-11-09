"""Page-ready contract for pages/activity/official-mine/index. Source text only."""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODEL = ROOT / "Core/OfficialPrivatePresentation.swift"
FIXTURE = ROOT / "Core/OfficialEventSyntheticFixtures.swift"
STRINGS = ROOT / "docs/release/ui-strings-pages-activity-official-mine-index.json"
SERVICE = ROOT / "Core/OfficialEventService.swift"
FORBIDDEN_TRUE = (
    "showsMerchantChoice = true",
    "paymentEnabled = true",
    "payoutEnabled = true",
    "withdrawalEnabled = true",
    "virtualGoodsEnabled = true",
)


def read(path):
    return path.read_text(encoding="utf-8")


class OfficialMinePageReadyChecks(unittest.TestCase):
    def test_model_has_loading_empty_error_and_unknown_em_dash(self):
        source = read(MODEL)
        model = source.split("public struct OfficialMinePageModel", 1)[1].split("@MainActor public final class OfficialMinePageCoordinator", 1)[0]
        for phase in ("case loading", "case empty", "case error(OfficialMinePageIssue)", "case unknown", "case ready"):
            self.assertIn(phase, model)
        self.assertIn('public static let unknownMark = "\u2014"', source)
        self.assertIn("case .unknown: return Self.unknownMark", source)
        self.assertIn("guard let number, number >= 0 else { return .unknown }", source)
        self.assertIn("guard number >= 0 else { return Self.unknownMark }", source)
        self.assertNotIn('unknownMark = "0"', source)
        self.assertNotIn('unknownMark = "-"', source)

    def test_coordinator_uses_existing_reads_and_hides_a_missing_grant(self):
        source = read(MODEL)
        coordinator = source.split("@MainActor public final class OfficialMinePageCoordinator", 1)[1]
        self.assertLess(coordinator.index("reader.myPublished()"), coordinator.index("reader.canPublish()"))
        self.assertIn("model = .failure(.notConfigured)", coordinator)
        self.assertIn("model = .failure(.unauthorized)", coordinator)
        self.assertIn("publisherCapabilityGranted: granted", coordinator)
        self.assertNotIn("http://", coordinator)
        self.assertNotIn("https://", coordinator)
        self.assertNotIn("api/official/", coordinator)
        service = read(SERVICE)
        self.assertIn('get("api/official/my-published"', service)
        self.assertIn('get("api/official/can-publish"', service)
        for flag in FORBIDDEN_TRUE:
            self.assertNotIn(flag, source)

    def test_debug_fixture_data_stays_inside_debug(self):
        source = read(FIXTURE)
        self.assertTrue(source.startswith("#if DEBUG"))
        self.assertIn("public enum OfficialMinePageFixtureData", source)
        self.assertLess(source.index("public enum OfficialMinePageFixtureData"), source.rindex("#endif"))
        self.assertIn('"reachedCount":"UNKNOWN"', source)
        self.assertIn('"reachedCount":0', source)
        self.assertNotIn("https://", source)
        self.assertNotIn("http://", source)

    def test_string_file_has_both_languages_and_identifiers(self):
        doc = json.loads(STRINGS.read_text(encoding="utf-8"))
        self.assertEqual(doc["page"], "pages/activity/official-mine/index")
        self.assertGreaterEqual(len(doc["strings"]), 1)
        self.assertGreaterEqual(len(doc["accessibilityIdentifiers"]), 1)
        seen = set()
        for row in doc["strings"]:
            self.assertTrue(row["key"])
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            self.assertTrue(row["accessibilityIdentifier"])
            self.assertNotIn("http://", row["en"] + row["zh-Hans"])
            self.assertNotIn("https://", row["en"] + row["zh-Hans"])
            seen.add(row["key"])
        self.assertIn("official.published.reachUnknown", seen)
        self.assertIn("official.published.title", seen)
        unknown = next(row for row in doc["accessibilityIdentifiers"] if row["id"] == "official.published.unknown")
        self.assertEqual(unknown["en"], "\u2014")
        self.assertEqual(unknown["zh-Hans"], "\u2014")
        ids = set()
        for row in doc["accessibilityIdentifiers"]:
            self.assertTrue(row["id"])
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            ids.add(row["id"])
        for ident in ("official.published.content", "official.published.loading", "official.published.empty",
                      "official.published.error", "official.published.unknown", "official.published.event.{id}",
                      "official.broadcast.{id}"):
            self.assertIn(ident, ids)
        blob = json.dumps(doc, ensure_ascii=False)
        for banned in ("ICP", "备案", "support@", "UGC", "showsMerchantChoice"):
            self.assertNotIn(banned, blob)

    def test_existing_published_presentation_tests_remain(self):
        tests = read(ROOT / "Tests/CoreTests/OfficialPrivatePresentationTests.swift")
        self.assertIn("func testPublisherStatusUsesOwnerLabels", tests)
        self.assertIn("OfficialPublishedPresentation.ownerStatusKey", tests)
        decoding = read(ROOT / "Tests/CoreTests/OfficialPrivateFactsDecodingTests.swift")
        self.assertIn("func testBroadcastRowCarriesSourceFactsWithoutGuessing", decoding)


if __name__ == "__main__":
    unittest.main()
