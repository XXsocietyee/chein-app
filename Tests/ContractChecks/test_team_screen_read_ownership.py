"""Wiring checks only: reads have task ownership; writes retain their original path."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]

class TeamScreenReadOwnershipTests(unittest.TestCase):
    def sections(self):
        home = (ROOT / 'App/TeamHomeView.swift').read_text()
        first, second = home.split('@MainActor struct TeamDetailView', 1)
        return [first, second]

    def test_home_and_detail_entries_own_lifecycle_pull_and_button_reads(self):
        for section in self.sections():
            self.assertIn('@State private var readOwner = ManualMapReadTaskOwner()', section)
            self.assertIn('readOwner.start { await reload(permit: permit) }', section)
            self.assertIn('.refreshable { await readOwner.run { await reload() } }', section)
            self.assertIn('.onDisappear { readOwner.deactivate(); model.leave() }', section)
            task = section.split('.task {', 1)[1].split('.refreshable', 1)[0]
            self.assertLess(task.index('guard !Task.isCancelled'), task.index('readOwner.activate()'))
            self.assertIn('await readOwner.run { await reload() }', task)
            self.assertNotIn('Task { await reload(', section)

    def test_existing_receipt_checks_and_confirmations_are_not_owned_or_cancelled(self):
        for section in self.sections()[1:]:
            self.assertIn('Task { await model.run(permit: permit) { await model.coordinator.checkOutcome() } }', section)
            self.assertIn('TeamReviewSheet(model: model, review: $0)', section)
            self.assertNotIn('readOwner.start { await model.coordinator.checkOutcome', section)
        components = (ROOT / 'App/TeamComponents.swift').read_text()
        self.assertNotIn('readOwner', components)
        self.assertIn('await model.coordinator.confirm(review)', components)

    def test_original_readers_and_membership_constraints_remain(self):
        home, detail = self.sections()
        self.assertIn('await model.coordinator.loadTeams()', home)
        self.assertIn('await model.coordinator.loadPostJoinDetail(teamID: teamID)', detail)
        self.assertIn('await model.coordinator.loadDetail(lookup, requireMembership: requiresMembership)', detail)

if __name__ == '__main__': unittest.main()
