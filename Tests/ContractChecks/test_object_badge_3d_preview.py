"""Contract for the 3D badge preview page model. No route is marked live."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PAGE = "subpackageP3/pages/badge-3d/index"
STRINGS = ROOT / "docs/release/ui-strings-subpackageP3-pages-badge-3d-index.json"
MODEL = ROOT / "Core/ObjectBadgePresentation.swift"
TURN = ROOT / "Tests/CoreTests/ObjectBadgeTurntableTests.swift"
PREVIEW = ROOT / "Tests/CoreTests/ObjectBadge3DPreviewTests.swift"
CATALOG = ROOT / "Resources/Localizable.xcstrings"
UNKNOWN = "\u2014"
IDENTIFIERS = {
    "objects.badge3d.loading",
    "objects.badge3d.empty",
    "objects.badge3d.error.session",
    "objects.badge3d.error.malformed",
    "objects.badge3d.unknown",
    "objects.badge3d.ready",
    "objects.badge3d.rarity",
    "objects.badge3d.staticPreview",
    "objects.badge.turntable",
    "objects.badge.turntableHint",
    "objects.badge.threeD",
}


class ObjectBadge3DPreviewContract(unittest.TestCase):
    def test_string_catalog_has_both_languages_and_the_unknown_mark(self):
        document = json.loads(STRINGS.read_text())
        self.assertEqual(document["page"], PAGE)
        rows = document["strings"]
        self.assertEqual(len(rows), len({row["key"] for row in rows}))
        catalog = json.loads(CATALOG.read_text())["strings"]
        for row in rows:
            self.assertEqual(set(row), {"key", "en", "zh-Hans"})
            self.assertIn(row["key"], catalog)
            stored = catalog[row["key"]]["localizations"]
            self.assertEqual(row["en"], stored["en"]["stringUnit"]["value"])
            self.assertEqual(row["zh-Hans"], stored["zh-Hans"]["stringUnit"]["value"])
        mark = document["unknownMark"]
        self.assertEqual(mark["en"], UNKNOWN)
        self.assertEqual(mark["zh-Hans"], UNKNOWN)
        self.assertNotEqual(mark["en"], "0")
        self.assertEqual(set(document["accessibilityIdentifiers"]), IDENTIFIERS)

    def test_model_keeps_four_states_unknown_mark_and_debug_fixture_only(self):
        source = MODEL.read_text()
        for token in ("case loading", "case empty", "case error", "case unknown"):
            self.assertIn(token, source)
        self.assertIn('unknownMark = "\u2014"', source)
        self.assertIn("showsMesh = false", source)
        self.assertNotIn("showsMesh = true", source)
        for flag in ("showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertNotIn(flag, source)
        debug = source.split("#if DEBUG", 1)[1].split("#endif", 1)[0]
        self.assertIn("enum ObjectBadge3DPreviewFixtureData", debug)
        self.assertIn("https://fixtures.invalid/badge.png", debug)
        self.assertNotIn("https://", source.split("#if DEBUG", 1)[0])
        self.assertNotIn("NativeNavigationContract", source.split("public enum ObjectBadge3DPreviewCoordinator", 1)[0])

    def test_existing_turntable_tests_and_new_preview_tests_both_stay(self):
        turn = TURN.read_text()
        for name in (
            "testRouteParametersAcceptPinStyleAndGlyphLikeTheMiniProgram",
            "testDragRotatesAndCommitsOnEnd",
            "testTapSpinsOnlyPinBadges",
            "testReducedMotionAndGlowStayStaticWithSourceHints",
        ):
            self.assertEqual(turn.count("func " + name), 1)
        preview = PREVIEW.read_text()
        for name in (
            "testLoadingDoesNotReadALaterRarity",
            "testEmptyRoutePublishesNoNumber",
            "testExplicitZeroStaysZeroAndMissingRarityIsTheEmDash",
            "testNoncanonicalRarityDoesNotBecomeZeroOrAClampedGuess",
            "testReadyRouteKeepsTheExistingQueryContractAndHidesAMesh",
            "testGlyphQueryStaysOffTheLiveRouteAndInAppParametersStillCarryIt",
            "testFallbackClockUsesRecordedDurationsAndUnknownElapsedIsTheEmDash",
        ):
            self.assertEqual(preview.count("func " + name), 1)


if __name__ == "__main__":
    unittest.main()
