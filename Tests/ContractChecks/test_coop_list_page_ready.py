"""Contract guards for pages/coop/list/index page-ready model work.

They do not compile Swift, run XCTest, or claim an Xcode Cloud result.
"""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
EM = "\u2014"
MODEL = ROOT / "Core" / "CoopListParity.swift"
NOTE = ROOT / "docs" / "release" / "page-ready" / "pages-coop-list-index.md"
CATALOG = ROOT / "Resources" / "Localizable.xcstrings"
VIEW = ROOT / "App" / "CooperationBrowserView.swift"
ROUTES = ROOT / "Core" / "ChinaReviewedRouteCapability.swift"
STRINGS = ROOT / "docs" / "release" / "ui-strings-pages-coop-list-index.json"
MISSING = (
    "pages.coop.list.index.loading",
    "pages.coop.list.index.empty",
    "pages.coop.list.index.error",
    "pages.coop.list.index.unknown",
    "pages.coop.list.index.ready",
    "pages.coop.list.index.invitationCount",
    "pages.coop.list.index.applicationCount",
    "pages.coop.list.index.registrationCount",
    "pages.coop.list.index.slotCount",
    "pages.coop.list.index.slotCapacity",
    "pages.coop.list.index.share",
    "pages.coop.list.index.countdown",
    "pages.coop.list.index.subscribe",
)
FLAGS = (
    "showsShare",
    "showsMerchantChoice",
    "paymentEnabled",
    "payoutEnabled",
    "withdrawalEnabled",
    "virtualGoodsEnabled",
)


def text(path):
    return path.read_text(encoding="utf-8")


class CoopListPageReadyTests(unittest.TestCase):
    def test_model_states_keep_unknown_counts_and_hidden_capabilities(self):
        source = text(MODEL)
        self.assertIn(f'unknownMark = "{EM}"', source)
        for phase in ("loading", "empty", "error", "unknown", "ready"):
            self.assertIn(f"case {phase}", source)
        for flag in FLAGS:
            self.assertIn(f"public let {flag} = false", source)
            self.assertNotIn(f"{flag} = true", source)
        self.assertIn("guard canRead else", source)
        self.assertIn("canRead && canComposeInvite", source)
        self.assertIn("direction == .received", source)
        self.assertNotIn(".liveInProduction", source)
        self.assertNotIn("URLSession", source)
        self.assertNotIn("HTTPTransport", source)
        self.assertNotIn("requestPayment", source)

    def test_existing_list_route_stays_live_and_the_view_is_unwired(self):
        routes = text(ROUTES)
        self.assertIn('"/api/coop/list": .liveInProduction', routes)
        self.assertIn('"/api/coop/pool/received": .liveInProduction', routes)
        self.assertIn('"/api/coop/candidates/received": .liveInProduction', routes)
        self.assertNotIn("CoopListPage", text(VIEW))
        self.assertFalse(STRINGS.exists())

    def test_missing_keys_are_listed_and_absent_from_the_catalog(self):
        note = text(NOTE)
        catalog = text(CATALOG)
        for key in MISSING:
            self.assertIn(key, note)
            self.assertNotIn(f'"{key}"', catalog)
        self.assertIn(EM, note)
        self.assertIn("coopInvited", note)


if __name__ == "__main__":
    unittest.main()
