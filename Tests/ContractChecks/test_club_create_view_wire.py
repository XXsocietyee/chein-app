"""Create screen reads ClubCreatePageModel.interpret. Not an Xcode result."""
import pathlib, unittest
ROOT = pathlib.Path(__file__).resolve().parents[2]
class ClubCreateViewWireContract(unittest.TestCase):
    def test_view_reads_interpret(self):
        view = (ROOT / "App/ClubOperationsViews.swift").read_text()
        edit = view.split("private var editSections", 1)[1].split("private var directionToggles", 1)[0]
        self.assertIn("ClubCreatePageModel.interpret(", view)
        self.assertIn("countText: page.recordCountText", view)
        self.assertIn(".showsHostApplication {", view)
        self.assertNotIn("ClubCreatePageModel", edit)
        self.assertNotIn("showsMerchantChoice = true", (ROOT / "App/WelcomeView.swift").read_text())
        self.assertNotIn("paymentEnabled = true", (ROOT / "Core/ChinaReviewedRouteCapability.swift").read_text())
if __name__ == "__main__":
    unittest.main()
