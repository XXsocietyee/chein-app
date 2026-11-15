"""Source checks for honest nearby empty-state presentation; not an App test."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


class NearbyEmptyReadStateTests(unittest.TestCase):
    def test_empty_placeholder_requires_a_successful_authenticated_read_without_error(self):
        source = (ROOT / "App/NearbyTeamViews.swift").read_text()
        section = source.split("if tab == 0 {", 1)[1].split("if viewMode == .map {", 1)[0]
        self.assertIn(
            "!model.running && coordinator.authenticated && coordinator.context != nil && coordinator.messageKey == nil && visibleTeams.isEmpty",
            section,
        )
        self.assertIn('CYEmptyState(systemImage: "person.3", "nearby.empty"', section)

    def test_count_is_not_loaded_before_successful_read_or_after_failure(self):
        source = (ROOT / "App/NearbyTeamViews.swift").read_text()
        section = source.split("NearbyTeamCountLine(", 1)[1].split("if model.running {", 1)[0]
        self.assertIn("coordinator.authenticated && !model.running && coordinator.context != nil && coordinator.messageKey == nil", section)

    def test_context_is_recorded_after_original_read_and_errors_keep_notice(self):
        core = (ROOT / "Core/NearbyTeamCoordinator.swift").read_text()
        load = core.split("public func loadNearby(", 1)[1].split("public func loadMine()", 1)[0]
        self.assertLess(load.index("try await service.nearby(context, session: session)"), load.index("self.context = context"))
        view = (ROOT / "App/NearbyTeamViews.swift").read_text()
        self.assertIn("if let key = coordinator.messageKey", view)
        self.assertIn('Text(LocalizedStringKey(key)).accessibilityIdentifier("nearby.message")', view)


if __name__ == "__main__":
    unittest.main()
