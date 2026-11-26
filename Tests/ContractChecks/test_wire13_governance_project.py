"""ClubOpsGovernanceSections reads ClubOpsGovernancePage.project."""
import unittest
from pathlib import Path
ROOT = Path(__file__).resolve().parents[2]
class T(unittest.TestCase):
    def test_view_reads_governance_page_project(self):
        view = (ROOT / "App/ClubOpsGovernanceSections.swift").read_text()
        for token in ("ClubOpsGovernancePage.project", 'if count.literal == 0 { return "0" }', 'return count.literal == nil ? "—" : count.displayText', "page?.hidden", "capability?.manageMembers != false"):
            self.assertIn(token, view)
        self.assertNotIn("showsMerchantChoice = true", view); self.assertNotIn("paymentEnabled = true", view)
        self.assertIn("showsMerchantChoice = false", (ROOT / "App/WelcomeView.swift").read_text()); self.assertIn("testDerivation?(.payment) ?? false", (ROOT / "Core/ChinaReviewedRouteCapability.swift").read_text())
if __name__ == "__main__":
    unittest.main()
