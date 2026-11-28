"""K40 ADA behaviour: empty is not shown before a home page loads, and P39 celebrations
fire a success haptic with a burst that Reduce Motion does not draw.

Layout, spacing, colour and type are not part of this contract.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class K40AdaBehaviour(unittest.TestCase):
    def test_home_stream_empty_waits_for_a_settled_page(self):
        model = read("App/HomeFeedModel.swift")
        placeholder = model.split("var streamPlaceholder:", 1)[1].split("func sectionReadiness", 1)[0]
        self.assertIn("if pageFailed { return .error }", placeholder)
        self.assertIn("if !pageLoaded { return .loading }", placeholder)
        self.assertIn("if pagination.items.isEmpty { return .empty }", placeholder)
        view = read("App/HomeFeedView.swift")
        self.assertIn("model.streamPlaceholder == .loading", view)
        self.assertIn("model.streamPlaceholder == .empty", view)
        self.assertIn("model.streamPlaceholder != .loading", view)
        self.assertIn('ProgressView("homeFeed.loading")', view)
        self.assertIn('accessibilityIdentifier("homeFeed.empty")', view)
        # The empty view is the settled branch, not the branch that runs before the page arrives.
        loading_at = view.index("model.streamPlaceholder == .loading")
        empty_at = view.index("model.streamPlaceholder == .empty")
        self.assertLess(loading_at, empty_at)
        self.assertIn("testStreamPlaceholderStaysLoadingUntilAPageSettles",
                      read("Tests/AppUnitTests/HomeFeedReturnModelTests.swift"))

    def test_p39_celebrations_haptic_once_and_burst_respects_reduce_motion(self):
        stamp = read("App/RoamSubpageParityViews.swift")
        self.assertIn(".cyHaptic(.success, trigger: revealed, where: CYHapticTransition.turnedOn)", stamp)
        self.assertIn(".roamStampCollectedBurst(revealed)", stamp)
        created = read("App/RoamCreatedStampView.swift")
        self.assertIn(".cyHaptic(.success, trigger: lookup.phase == .found, where: CYHapticTransition.turnedOn)", created)
        self.assertIn(".roamStampCollectedBurst(true)", created)
        badge = read("App/PlayRewardBadgeViews.swift")
        self.assertIn(".cyHaptic(.success, trigger: celebrated, where: CYHapticTransition.turnedOn)", badge)
        self.assertIn("CYConfettiBurst(fireOnAppear: true)", badge)
        settle = read("App/JourneyReportViews.swift")
        self.assertIn(".cyHaptic(.success, trigger: sealSuccess, where: CYHapticTransition.isOn)", settle)
        self.assertIn("if sealSuccess && !reduceMotion", settle)
        self.assertIn("CYBurst(", settle)
        chapter = read("App/DesignSystem/CYChapterFlip.swift")
        self.assertIn(".cyHaptic(.success, trigger: shown)", chapter)
        self.assertIn("if shown && !reduceMotion", chapter)
        self.assertIn("CYBurst(", chapter)
        burst = read("App/DesignSystem/CYBurst.swift")
        self.assertIn("if !reduceMotion && CYLightBudget.particlesAllowed", burst)
        stripe = read("App/RegistrationStripePaySection.swift")
        paid = stripe.split("private var paidRows", 1)[1].split("private var checkingRows", 1)[0]
        self.assertIn("RegistrationPaidTicketMoment(", paid)
        self.assertIn('accessibilityIdentifier("registration.pay.succeeded")', paid)
        self.assertIn('accessibilityIdentifier("registration.pay.openTicket")', paid)
        self.assertIn(".sensoryFeedback(.success, trigger: stage, condition: Self.becamePaid)", stripe)
        moment = read("App/RegistrationPayMoment.swift")
        self.assertIn("if landed && !reduceMotion", moment)
        self.assertIn("CYBurst(", moment)

    def test_new_haptics_use_a_named_transition(self):
        # New success haptics go through CYHapticTransition, not an untyped `{ old, new in }` closure.
        for path in ("App/PlayRewardBadgeViews.swift", "App/RoamCreatedStampView.swift"):
            source = read(path)
            self.assertIn("CYHapticTransition.turnedOn", source, path)
            self.assertNotRegex(source, r"\.cyHaptic\([^)]*\)\s*\{")
            self.assertNotRegex(source, r"\.(?:cyHaptic|sensoryFeedback)\([^{]*(?:where|condition):\s*\{")
        settle = read("App/JourneyReportViews.swift")
        added = settle.split("if sealSuccess && !reduceMotion", 1)[1].split(".cyHaptic(.success, trigger: sealSuccess", 1)[0]
        self.assertNotIn("String(localized:", added)
        self.assertNotIn("{ old, new in", added)


if __name__ == "__main__":
    unittest.main()
