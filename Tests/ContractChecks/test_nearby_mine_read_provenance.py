"""Source wiring only; does not execute Swift or a backend."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NearbyMineReadProvenanceTests(unittest.TestCase):
    def test_summary_and_empty_need_successful_current_account_read(self):
        source = (ROOT / "App/NearbyTeamViews.swift").read_text()
        section = source.split("private var mineSection:", 1)[1].split("@ViewBuilder private func mineRow", 1)[0]
        self.assertIn(
            "let mineReady = !model.running && !mine.loading && coordinator.authenticated && coordinator.hasLoadedMine && coordinator.messageKey == nil && joinedTeamsStatus.isLoaded && !mine.failed",
            section,
        )
        self.assertIn("if rows.isEmpty && mine.loaded && mineReady {", section)
        self.assertIn('"nearby.mine.empty"', section)

    def test_read_provenance_is_reset_on_binding_and_before_read_then_set_after_result(self):
        source = (ROOT / "Core/NearbyTeamCoordinator.swift").read_text()
        binding = source.split("public func bind(", 1)[1].split("public func leave()", 1)[0]
        self.assertIn("hasLoadedMine = false", binding)
        reader = source.split("public func loadMine()", 1)[1].split("public func loadApplicants", 1)[0]
        self.assertLess(reader.index("guard !Task.isCancelled"), reader.index("hasLoadedMine = false"))
        self.assertLess(reader.index("hasLoadedMine = false"), reader.index("try await service.myApplications"))
        self.assertLess(reader.index("guard valid(session, generation)"), reader.index("hasLoadedMine = true"))
        self.assertEqual(reader.count("hasLoadedMine = true"), 1)
        self.assertNotIn("hasLoadedMine", source.split("public func confirm(", 1)[1])


if __name__ == "__main__":
    unittest.main()
