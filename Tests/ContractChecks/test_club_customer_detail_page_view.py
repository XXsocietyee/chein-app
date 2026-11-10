import pathlib, unittest
R = pathlib.Path(__file__).resolve().parents[2]
class ClubCustomerDetailPageViewContract(unittest.TestCase):
    def test_view_reads_core_count(self):
        view = (R / "App/ClubOpsCustomerViews.swift").read_text()
        self.assertNotIn("enum ClubCustomerDetailPage", view)
        self.assertIn("let value: ClubCustomerDetailCount", view)
        self.assertIn("value.displayText", view)
        self.assertIn("static let showsMerchantChoice = false", (R / "App/WelcomeView.swift").read_text())
