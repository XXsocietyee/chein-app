"""Page-ready contract for pages/activity/official-inbox. Not an Xcode or device run."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
DOC = ROOT / "docs/release/ui-strings-pages-activity-official-inbox-index.json"
BANNED = (
    "showsMerchantChoice",
    "paymentEnabled",
    "payoutEnabled",
    "withdrawalEnabled",
    "virtualGoodsEnabled",
)


def read(path):
    return (ROOT / path).read_text(encoding="utf-8")


class OfficialInboxPageReadyChecks(unittest.TestCase):
    def test_string_catalog_has_both_languages_and_identifiers(self):
        doc = json.loads(DOC.read_text(encoding="utf-8"))
        self.assertEqual(doc["page"], "pages/activity/official-inbox/index")
        self.assertEqual(doc["states"]["unknown"], "—")
        self.assertNotEqual(doc["states"]["unknown"], "0")
        keys = []
        for row in doc["strings"]:
            keys.append(row["key"])
            for language in ("en", "zh-Hans"):
                self.assertTrue(row[language].strip(), (row["key"], language))
            blob = row["en"] + row["zh-Hans"]
            self.assertNotIn("http://", blob.lower())
            self.assertNotIn("https://", blob.lower())
        self.assertEqual(len(keys), len(set(keys)))
        for key in (
            "official.loading",
            "official.inbox.empty",
            "official.w206.inbox.failed.title",
            "official.inbox.status.unknown",
        ):
            self.assertIn(key, keys)
        identifiers = [row["id"] for row in doc["accessibilityIdentifiers"]]
        self.assertEqual(len(identifiers), len(set(identifiers)))
        for row in doc["accessibilityIdentifiers"]:
            self.assertTrue(row["id"].strip())
            self.assertTrue(row["en"].strip())
            self.assertTrue(row["zh-Hans"].strip())
        for identifier in ("official.inbox.content", "official.invite.{id}", "official.inbox.failed"):
            self.assertIn(identifier, identifiers)

    def test_model_keeps_unknown_distinct_from_zero_and_hides_missing_routes(self):
        model = read("Core/OfficialPrivatePresentation.swift")
        self.assertIn("case loading", model)
        self.assertIn("case empty", model)
        self.assertIn("case error", model)
        self.assertIn("case unknown", model)
        self.assertIn('public static let unknownMark = "—"', model)
        self.assertIn('public static let partyInboxPath = "api/official/v2/party-inbox"', model)
        self.assertIn("ChinaReviewedRouteCapability.mark(for: path) == .liveInProduction", model)
        self.assertIn("case .loading, .error, .unknown: return OfficialInboxQuantity.unknownMark", model)
        contracts = read("Core/OfficialEventContracts.swift")
        self.assertIn("capacity = c.integer(\"capacity\").flatMap { $0 > 0 ? $0 : nil }", contracts)
        self.assertIn("capacityFact = (try? c.decode(OfficialInboxQuantity.self, forKey: OfficialKey(\"capacity\"))) ?? .unknown", contracts)
        routes = read("Core/ChinaReviewedRouteCapability.swift")
        self.assertIn('"/api/official/v2/party-inbox": .liveInProduction', routes)
        self.assertIn('"/api/official/v2/organizer-invites/{}/{}": .missing', routes)

    def test_fixture_data_is_debug_only_and_flags_stay_off(self):
        fixture = read("Core/OfficialEventSyntheticFixtures.swift")
        start = fixture.index("#if DEBUG")
        end = fixture.index("#endif")
        body = fixture[start:end]
        self.assertIn("public enum OfficialInboxFixtureData", body)
        self.assertIn("public static let unknownCapacity", body)
        self.assertIn("public static let zeroCapacity", body)
        self.assertNotIn("http://", body)
        self.assertNotIn("https://", body)
        touched = "\n".join(
            read(path)
            for path in (
                "Core/OfficialPrivatePresentation.swift",
                "Core/OfficialEventContracts.swift",
                "Core/OfficialEventSyntheticFixtures.swift",
                "Tests/CoreTests/OfficialInboxPageReadyTests.swift",
            )
        )
        for name in BANNED:
            self.assertNotIn(name + " = true", touched)
            self.assertNotIn(name + "=true", touched)


if __name__ == "__main__":
    unittest.main()
