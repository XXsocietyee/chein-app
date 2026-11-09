"""Page-ready contract for pages/club/create/index. Not an Xcode or device result."""
import json
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
STRINGS = ROOT / "docs/release/ui-strings-pages-club-create-index.json"
MODEL = ROOT / "Core/ClubOperationsPort.swift"
COORDINATOR = ROOT / "Core/ClubOperationsCoordinator.swift"
FIXTURE = ROOT / "Core/ClubOperationsSyntheticFixtures.swift"
TESTS = ROOT / "Tests/CoreTests/ClubCreatePageModelTests.swift"


class ClubCreatePageReadyContract(unittest.TestCase):
    def test_model_keeps_unknown_as_em_dash_and_creation_gated(self):
        model = MODEL.read_text(encoding="utf-8")
        coordinator = COORDINATOR.read_text(encoding="utf-8")
        for phase in ["case loading", "case empty", "case error", "case unknown", "case ready"]:
            self.assertIn(phase, model)
        self.assertIn('public static let unknownMark = "—"', model)
        self.assertIn("public static let showsOnPlayerFirstEntry = false", model)
        self.assertIn("public static let mediaUploadVisible = false", model)
        self.assertIn("ClubOperationsCommand.create(ClubOperationsDraft()).path == \"api/club/create\"", model)
        self.assertNotIn("api/club/update", model)
        self.assertIn("func createPageModel(loading: Bool, snapshot: ClubOperationsSnapshot? = nil, onPlayerFirstEntry: Bool = false)", coordinator)
        for forbidden in [
            "showsMerchantChoice = true",
            "paymentEnabled = true",
            "payoutEnabled = true",
            "withdrawalEnabled = true",
            "virtualGoodsEnabled = true",
            "https://",
            "http://",
        ]:
            self.assertNotIn(forbidden, model)
            self.assertNotIn(forbidden, coordinator[coordinator.rfind("func createPageModel"):])

    def test_strings_have_both_languages_and_accessibility_identifiers(self):
        document = json.loads(STRINGS.read_text(encoding="utf-8"))
        self.assertEqual(document["page"], "pages/club/create/index")
        rows = document["strings"]
        self.assertGreaterEqual(len(rows), 8)
        identifiers = set()
        keys = set()
        for row in rows:
            self.assertTrue(row["en"])
            self.assertTrue(row["zh-Hans"])
            self.assertTrue(row["accessibilityIdentifier"])
            self.assertNotIn("http://", row["en"] + row["zh-Hans"])
            self.assertNotIn("https://", row["en"] + row["zh-Hans"])
            for banned in ["ICP", "备案", "UGC"]:
                self.assertNotIn(banned, row["en"])
                self.assertNotIn(banned, row["zh-Hans"])
            keys.add(row["key"])
            identifiers.add(row["accessibilityIdentifier"])
        unknown = next(row for row in rows if row["key"] == "club.ops.create.unknownCount")
        self.assertEqual(unknown["en"], "—")
        self.assertEqual(unknown["zh-Hans"], "—")
        self.assertNotEqual(unknown["en"], "0")
        for key in [
            "club.ops.create",
            "club.ops.create.empty",
            "club.ops.checking",
            "club.ops.readFailed",
            "club.ops.create.unknownCount",
        ]:
            self.assertIn(key, keys)
        for identifier in [
            "club.ops.openCreate",
            "club.ops.create.state.loading",
            "club.ops.create.state.empty",
            "club.ops.create.state.error",
            "club.ops.create.state.unknown",
            "club.ops.create.currentRecordCount",
        ]:
            self.assertIn(identifier, identifiers)

    def test_debug_fixture_data_and_unit_tests_exist(self):
        fixture = FIXTURE.read_text(encoding="utf-8")
        self.assertTrue(fixture.startswith("#if DEBUG"))
        self.assertLess(fixture.index("#if DEBUG"), fixture.index("public enum ClubCreatePageFixtureData"))
        self.assertIn("public static let withheldOwned", fixture)
        self.assertIn("public static let emptyOwned", fixture)
        tests = TESTS.read_text(encoding="utf-8")
        for name in [
            "testUnknownCountIsAnEmDashAndNeverZero",
            "testOwnedPayloadClassifiesEmptyErrorAndUnknown",
            "testLoadingSignedOutAndFailedReadDoNotGuessACount",
            "testCreationStaysGatedAndOffThePlayerFirstEntry",
            "testCoordinatorProjectsTheGateWithoutSending",
            "testDebugFixtureDataFeedsTheReadModel",
        ]:
            self.assertIn(name, tests)
        self.assertNotIn("paymentEnabled = true", tests)
        self.assertNotIn("https://", tests)


if __name__ == "__main__":
    unittest.main()
