"""CB261 page-ready contract for pages/coop/invite/index. Source and JSON only."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
MODEL = ROOT / "Core/CooperationContextual.swift"
TESTS = ROOT / "Tests/CoreTests/CoopInviteIndexReadinessTests.swift"
EXISTING = ROOT / "Tests/CoreTests/CoopBatchInviteTests.swift"
NOTE = ROOT / "docs/release/page-ready/pages-coop-invite-index.md"
CAPABILITY = ROOT / "Core/ChinaReviewedRouteCapability.swift"
VIEW = ROOT / "App/CooperationContextualViews.swift"
LEDGER = ROOT / "Core/MiniProgramPageByPage99DecisionLedgerContract.swift"


class CoopInviteIndexPageReadyContract(unittest.TestCase):
    def test_model_keeps_states_unknown_dash_and_hides_missing_capabilities(self):
        model = MODEL.read_text()
        self.assertIn("enum CoopInviteIndexReadiness", model)
        for phase in ("loading", "empty", "error", "unknown", "ready"):
            self.assertIn("case %s" % phase, model)
        self.assertIn('public static let unknownDisplay = "\\u{2014}"', model)
        self.assertIn("public static var inviteSendOffered: Bool { false }", model)
        self.assertIn("public static var shareOffered: Bool { false }", model)
        self.assertIn("public var showsLockedTarget: Bool { false }", model)
        self.assertIn("public var showsMerchantChoice: Bool { false }", model)
        for flag in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn("ReleaseMoneyWriteSwitch.%s" % flag, model)
            self.assertNotRegex(model, r"%s\s*=\s*true" % flag)
        self.assertNotIn("CoopFlowMutation", model)
        self.assertNotIn("dormantWritesEnabled", model)
        capability = CAPABILITY.read_text()
        self.assertNotIn('"/api/coop/invite": .liveInProduction', capability)
        for flag in ("paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"):
            self.assertIn("public static var %s: Bool { testDerivation?" % flag, capability)

    def test_missing_keys_are_listed_and_not_invented_as_a_surface(self):
        model = MODEL.read_text()
        note = NOTE.read_text()
        match = re.search(r"public static let missingKeys = \[(.*?)\]", model, re.S)
        self.assertIsNotNone(match)
        keys = re.findall(r'"([^"]+)"', match.group(1))
        self.assertEqual(
            keys,
            ["toId", "originApplyId", "merchantName", "share", "coopInvited", "originalRequest", "countdown"],
        )
        for key in keys:
            self.assertIn("`%s`" % key, note)
        self.assertIn("pages/coop/invite/index", note)
        self.assertIn("App/CooperationContextualViews.swift", note)
        view = VIEW.read_text()
        self.assertIn("CoopInviteIndexReadiness", view)
        self.assertNotIn("enum CoopInviteIndexReadiness", view)

    def test_swift_tests_were_added_without_removing_existing_ones(self):
        tests = TESTS.read_text()
        names = re.findall(r"func (test\w+)", tests)
        self.assertGreaterEqual(len(names), 5)
        self.assertEqual(len(names), len(set(names)))
        self.assertIn("testUnknownCountIsEmDashAndLiteralZeroStaysZero", names)
        self.assertIn("testMerchantMemberCountStaysHidden", names)
        existing = re.findall(r"func (test\w+)", EXISTING.read_text())
        for name in (
            "testThreeTargetsGiveThreeDraftsWithSharedNoteAndFixedFee",
            "testEmptyNoteUsesDefaultAndTrafficHasNoFee",
            "testInvalidFeeStaleSessionDuplicatesAndEmptySelectionProduceNoDrafts",
            "testEachDraftSendsExactlyOneWireRequestOnlyAfterItsOwnConfirm",
        ):
            self.assertIn(name, existing)
        self.assertNotIn("http://", tests)
        self.assertNotIn("https://", tests)
        ledger = LEDGER.read_text()
        self.assertIn('"pages/coop/invite/index"', ledger)
        self.assertNotIn("wiringStatus: .live", ledger)


if __name__ == "__main__":
    unittest.main()
