"""Source wiring checks; not Swift/App validation."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class TeamOwnedReadProvenanceTests(unittest.TestCase):
    def test_home_list_and_nearby_entry_use_current_identity_projection(self):
        view = (ROOT / 'App/TeamHomeView.swift').read_text().split('@MainActor struct TeamDetailView', 1)[0]
        self.assertNotIn('model.coordinator.teams', view)
        self.assertIn('ForEach(model.coordinator.currentTeams)', view)
        self.assertIn('nearbyDestination(model.coordinator.currentTeams)', view)
        self.assertIn('model.coordinator.hasCurrentTeamsRead && model.coordinator.messageKey == nil', view)
    def test_reader_success_and_identity_guards_are_distinct_from_write_state(self):
        source = (ROOT / 'Core/TeamCoordinator.swift').read_text()
        self.assertIn('completedTeamsRead && capturedSession != nil && currentSession() == capturedSession', source)
        self.assertIn('guard capturedSession != nil, currentSession() == capturedSession else { return [] }', source)
        read = source.split('public func loadTeams()', 1)[1].split('public func loadDetail', 1)[0]
        self.assertLess(read.index('completedTeamsRead = false'), read.index('service.myTeams'))
        self.assertLess(read.index('guard active(session, stamp)'), read.index('completedTeamsRead = true'))
        self.assertNotIn('journal.', read)
        self.assertNotIn('pending =', read)
if __name__ == '__main__': unittest.main()
