"""Normal-entry source wiring only; not a SwiftUI navigation execution."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NearbyMineReentryTests(unittest.TestCase):
    def task_body(self):
        return (ROOT / "App/NearbyTeamViews.swift").read_text().split(
            "            .task {", 1
        )[1].split("            .onChange(of: tab)", 1)[0]

    def test_mine_reentry_reads_current_applications_before_nearby_initialization(self):
        body = self.task_body()
        self.assertLess(body.index("guard !Task.isCancelled"), body.index("coordinator.resume()"))
        branch = body.split("if tab == 1 {", 1)[1].split("if let context = initialContext", 1)[0]
        self.assertIn("await loadMine()", branch)
        self.assertIn("return", branch)
        self.assertNotIn("loadNearby", branch)
        self.assertNotIn("latitude =", branch)
        for forbidden in ["confirm(", "submit(", "prepare(", "locks.", "pending ="]:
            self.assertNotIn(forbidden, body)

    def test_nearby_original_entry_and_navigation_retirement_remain(self):
        body = self.task_body()
        self.assertIn("if let context = initialContext", body)
        self.assertIn("await model.run { await coordinator.loadNearby(", body)
        source = (ROOT / "App/NearbyTeamViews.swift").read_text()
        self.assertIn("coordinator.leave()", source)


if __name__ == "__main__":
    unittest.main()
