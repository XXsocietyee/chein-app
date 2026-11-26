import unittest
from pathlib import Path
R = Path(__file__).resolve().parents[2]
class ClubGroupCodeViewWireContract(unittest.TestCase):
    def test_group_code_view_reads_project(self):
        view = (R / "App/ClubGovernanceViews.swift").read_text()
        self.assertIn("ClubGroupCodePage.project(", view)
        self.assertIn("headcount.displayText", view)
        self.assertIn("groupCodePage.hidden", view)
        apply = view.split("operation == .hostStatus", 1)[1].split("operation == .roster", 1)[0]
        checkin = view[view.index("operation == .checkin"):view.index("operation == .registrations")]
        for part in (apply, checkin): self.assertNotIn("ClubGroupCodePage", part)
        self.assertIn("showsMerchantChoice = false", (R / "App/WelcomeView.swift").read_text())
        money = (R / "Core/ChinaReviewedRouteCapability.swift").read_text()
        self.assertIn("testDerivation?(.payment) ?? false", money)
        self.assertNotIn("paymentEnabled = true", money)
if __name__ == "__main__":
    unittest.main()
