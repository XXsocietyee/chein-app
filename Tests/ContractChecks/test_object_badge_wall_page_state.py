"""Badge-wall page-state contract. No Swift compiler, UI, or network."""
from pathlib import Path
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Core/ObjectBadgeWallOrdering.swift"
TESTS = ROOT / "Tests/CoreTests/ObjectBadgeWallPageStateTests.swift"
STRINGS = ROOT / "docs/release/ui-strings-subpackageP3-pages-badge-wall-index-index.json"
REQUIRED_KEYS = {
    "badgeWall.state.loading",
    "badgeWall.state.empty",
    "badgeWall.state.error",
    "badgeWall.state.unknown",
    "badgeWall.state.unknownDetail",
    "badgeWall.count.unknown",
    "badgeWall.count.known",
    "badgeWall.state.signIn",
    "badgeWall.state.denied",
    "badgeWall.state.malformed",
    "badgeWall.state.retry",
    "profile.badges.title",
}
REQUIRED_IDS = {
    "badgeWall.state.hidden",
    "badgeWall.state.loading",
    "badgeWall.state.empty",
    "badgeWall.state.error",
    "badgeWall.state.unknown",
    "badgeWall.state.ready",
    "badgeWall.count.unknown",
    "badgeWall.count.known",
}


class ObjectBadgeWallPageStateContract(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text()
        self.tests = TESTS.read_text()
        self.doc = json.loads(STRINGS.read_text())

    def test_model_states_use_em_dash_and_existing_read(self):
        for token in ("case hidden", "case loading", "case empty", "case error", "case unknown", "case ready"):
            self.assertIn(token, self.source)
        self.assertIn('public static let unknownMark = "—"', self.source)
        self.assertIn("reader.profileBadges()", self.source)
        self.assertNotIn("URLSession", self.source)
        self.assertNotIn("URLRequest", self.source)
        self.assertNotIn("api/", self.source)
        for flag in ("showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertNotIn(flag, self.source)
        self.assertNotIn("medals ?? []", self.source)
        self.assertIn("#if DEBUG", self.source)
        self.assertIn("public enum ObjectBadgeWallFixtureData", self.source)
        self.assertLess(self.source.index("#if DEBUG"), self.source.index("enum ObjectBadgeWallFixtureData"))
        self.assertGreater(self.source.rindex("#endif"), self.source.index("enum ObjectBadgeWallFixtureData"))

    def test_strings_are_bilingual_and_name_accessibility_identifiers(self):
        self.assertEqual(self.doc["page"], "subpackageP3/pages/badge-wall/index/index")
        rows = self.doc["strings"]
        keys = set()
        identifiers = set(self.doc["accessibilityIdentifiers"])
        for row in rows:
            self.assertEqual(set(row), {"key", "en", "zh-Hans", "accessibilityIdentifier"})
            for field in ("key", "en", "zh-Hans", "accessibilityIdentifier"):
                self.assertTrue(str(row[field]).strip())
            self.assertNotIn(row["key"], keys)
            keys.add(row["key"])
            identifiers.add(row["accessibilityIdentifier"])
            for locale in ("en", "zh-Hans"):
                text = row[locale].lower()
                self.assertNotIn("http", text)
                self.assertNotRegex(text, r"icp|ugc|privacy policy|terms of service")
        self.assertTrue(REQUIRED_KEYS <= keys)
        self.assertTrue(REQUIRED_IDS <= identifiers)
        for key in ("badgeWall.state.unknown", "badgeWall.count.unknown"):
            row = next(item for item in rows if item["key"] == key)
            self.assertEqual(row["en"], "—")
            self.assertEqual(row["zh-Hans"], "—")
            self.assertNotEqual(row["en"], "0")
        returned = set(re.findall(r'return "([^"]+)"', self.source))
        interesting = {item for item in returned if item.startswith("badgeWall.") or item == "profile.badges.title"}
        self.assertTrue(interesting <= keys | identifiers)
        for key in REQUIRED_KEYS:
            self.assertIn('"' + key + '"', self.source)

    def test_new_tests_do_not_weaken_existing_badge_wall_tests(self):
        ordering = (ROOT / "Tests/CoreTests/ObjectBadgeWallOrderingTests.swift").read_text()
        self.assertIn("func testLitCardsComeFirstAndServerOrderIsKeptInsideEachGroup", ordering)
        self.assertIn("func testNothingIsDroppedOrDuplicated", ordering)
        growth = (ROOT / "Tests/CoreTests/GrowthBadgeParityTests.swift").read_text()
        self.assertIn("XCTAssertEqual([partial.unlocked, partial.total], [1, 1])", growth)
        summary = (ROOT / "Core/GrowthBadgeParity.swift").read_text()
        self.assertIn("let medals = wall.medals ?? []", summary)
        for name in (
            "testEmptyWallIsKnownZero",
            "testMissingMedalCollectionIsUnknownEvenWithoutIdentityCards",
            "testReadyWallKeepsLitOrderAndLiteralZeroWaiting",
            "testLoadingHiddenAndErrorDoNotShowZero",
            "testFailureKindsStayDistinctFromEmpty",
            "testSignedOutAndUnconfiguredStayHiddenWithoutReading",
            "testConfiguredEmptyReadIsEmptyAndAFailedReadIsNot",
            "testNotConfiguredResultStaysHidden",
            "testCancellationDoesNotBecomeErrorOrZero",
            "testAccountChangeDropsTheLateWall",
            "testOlderReadCannotReplaceANewerLoad",
            "testFixtureDataProjectsReadyEmptyAndUnknown",
        ):
            self.assertIn("func " + name, self.tests)


if __name__ == "__main__":
    unittest.main(verbosity=2)
