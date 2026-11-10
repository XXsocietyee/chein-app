"""Page-ready guards for pages/coop/invite-detail. Not a Swift compile."""
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NOTE = ROOT / "docs/release/page-ready/pages-coop-invite-detail-index.md"

# Source copy the detail page shows and this catalog does not contain.
# English was not invented for these lines.
MISSING_KEYS = [
    "cooperation.detail.state.loading",
    "cooperation.detail.state.missing",
    "cooperation.detail.state.invalidId",
    "cooperation.detail.state.absentId",
    "cooperation.detail.state.identity",
    "cooperation.detail.state.errorTitle",
    "cooperation.detail.state.listFailed",
    "cooperation.detail.state.network",
    "cooperation.detail.state.notFoundDetail",
    "cooperation.detail.state.backToList",
    "cooperation.detail.countdown.remaining",
    "cooperation.detail.countdown.expired",
]


class CoopInviteDetailPageReadyTests(unittest.TestCase):
    def text(self, name):
        return (ROOT / name).read_text()

    def test_existing_list_contract_is_wired_and_not_marked_live_here(self):
        service = self.text("Core/CooperationService.swift")
        self.assertIn('try await object("api/coop/list", token: token)', service)
        self.assertIn("list.occupancy(for: row)", service)
        self.assertIn("list.slotLine(for: row)", service)
        self.assertNotRegex(service, r"api/coop/invite")
        page = self.text("Core/CooperationInvitePresentation.swift")
        self.assertIn('public static let readPath = "api/coop/list"', page)
        self.assertIn("public static let routeMarkedLive = false", page)
        self.assertIn("public static let opensNewInviteSurface = false", page)
        self.assertIn('public static let unknownDisplay = "—"', self.text("Core/CooperationContracts.swift"))
        self.assertNotIn("?? 0", self.text("Core/CooperationContracts.swift"))
        self.assertNotIn("depositAmount || 50", page)

    def test_missing_keys_are_listed_and_absent_from_the_catalog(self):
        note = NOTE.read_text()
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())
        strings = catalog["strings"]
        for key in MISSING_KEYS:
            self.assertIn(key, note, key)
            self.assertNotIn(key, strings, key)
        self.assertNotIn("ui-strings-pages-coop-invite-detail-index.json", note)
        self.assertFalse((ROOT / "docs/release/ui-strings-pages-coop-invite-detail-index.json").exists())


if __name__ == "__main__":
    unittest.main()
