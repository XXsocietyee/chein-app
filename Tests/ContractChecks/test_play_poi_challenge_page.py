"""Source contract for the timed POI challenge page. This does not compile Swift."""
import json
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
DASH = "\u2014"


class PlayPoiChallengePageContract(unittest.TestCase):
    def text(self, path):
        return (ROOT / path).read_text()

    def test_model_keeps_unknown_as_em_dash_and_hides_a_missing_grant(self):
        source = self.text("Core/PlayKitChallengeMachines.swift")
        page = source.split("public struct PlayKitTimedChallengePage", 1)[1].split("#if DEBUG", 1)[0]
        phases = page.split("public enum Phase", 1)[1].split("}", 1)[0]
        for phase in ["loading", "empty", "error", "unknown", "ready"]:
            self.assertIn(phase, phases)
        self.assertIn('public static let unknownDisplay = "' + DASH + '"', page)
        self.assertNotIn("?? 0", page)
        self.assertNotIn("?? 3", page)
        self.assertIn('"/api/play/advanced/state"', page)
        self.assertIn('"/api/play/advanced/action"', page)
        self.assertNotIn("/api/play/poi-challenge", page)
        self.assertNotIn("https://us.", page)
        self.assertIn("PlayWriteAvailability.current(for: .challengeSubmit).isAvailable", page)
        self.assertIn("advancedEnabled && showsReadRoute && showsActionRoute", page)
        runtime = self.text("Core/PlayAdvancedRuntime.swift")
        self.assertIn("func timedChallengePage(kind: PlayKitScreenKind, configuration: RegionalConfiguration)", runtime)
        self.assertIn("service.enabled.contains(.advanced)", runtime)

    def test_debug_fixture_is_debug_only(self):
        source = self.text("Core/PlayKitChallengeMachines.swift")
        self.assertIn("public enum PlayKitTimedChallengeFixtureData", source)
        fixture = source.split("#if DEBUG", 1)[1]
        self.assertIn("PlayKitTimedChallengeFixtureData", fixture)
        self.assertIn("#endif", fixture)
        self.assertNotIn("https://us.", fixture)
        self.assertLess(source.split("#if DEBUG", 1)[0].find("PlayKitTimedChallengeFixtureData"), 0)

    def test_strings_have_english_chinese_and_accessibility_ids(self):
        document = json.loads(self.text("docs/release/ui-strings-pages-play-poi-challenge-index.json"))
        self.assertEqual(document["page"], "pages/play/poi-challenge/index")
        keys = []
        for row in document["strings"]:
            keys.append(row["key"])
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            self.assertNotIn("http://", row["en"] + row["zh-Hans"])
            self.assertNotIn("https://", row["en"] + row["zh-Hans"])
        self.assertEqual(len(keys), len(set(keys)))
        for phase in ["playkit.timed.loading", "playkit.timed.empty", "playkit.timed.error", "playkit.timed.unknown"]:
            self.assertIn(phase, keys)
        unknown = next(row for row in document["strings"] if row["key"] == "playkit.timed.unknown")
        self.assertEqual(unknown["en"], DASH)
        self.assertEqual(unknown["zh-Hans"], DASH)
        identifiers = []
        for row in document["accessibilityIdentifiers"]:
            identifiers.append(row["id"])
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
        self.assertEqual(len(identifiers), len(set(identifiers)))
        for identifier in [
            "playkit.challenge.start", "playkit.challenge.measure", "playkit.challenge.submit",
            "playkit.reaction.target", "playkit.type.result", "playkit.timed.loading",
            "playkit.timed.empty", "playkit.timed.error", "playkit.timed.unknown",
        ]:
            self.assertIn(identifier, identifiers)

    def test_existing_gates_stay_closed(self):
        self.assertIn("static let showsMerchantChoice = false", self.text("App/WelcomeView.swift"))
        switches = self.text("Core/ChinaReviewedRouteCapability.swift")
        for name in ["paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"]:
            self.assertIn("public static var " + name + ": Bool { testDerivation?", switches)
        writer = self.text("Core/ChallengePOISubmission.swift")
        self.assertIn("case .unavailable", writer)
        self.assertIn("public func complete(_ request: ChallengePOICompleteRequest) async -> ChallengePOIWriteOutcome { .unavailable }", writer)
        availability = self.text("Core/PlayRPGPresentation.swift")
        self.assertIn("isAvailable: false", availability)


if __name__ == "__main__":
    unittest.main()
