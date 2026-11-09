import pathlib, unittest
R = pathlib.Path(__file__).resolve().parents[2]
class ClubCustomerDetailPageViewContract(unittest.TestCase):
    def test_view_reads_project(self):
        view = (R / "App/ClubOpsCustomerViews.swift").read_text()
        self.assertGreaterEqual(view.count("ClubCustomerDetailPage.project"), 2)
        page = view.split("enum ClubCustomerDetailPage", 1)[1].split("struct ClubOpsCustomerMetricTile", 1)[0]
        for dropped in ("phone", "email", "address"): self.assertNotIn(dropped, page)
        self.assertIn("if !capabilityPresent { return .hidden }", page)
        self.assertIn("return number.map(Number.known) ?? .unknown", page)
        self.assertIn('case .unknown: Text(verbatim: "—")', view)
        self.assertIn("Text(number, format: .number)", view)
        self.assertIn("static let showsMerchantChoice = false", (R / "App/WelcomeView.swift").read_text())
