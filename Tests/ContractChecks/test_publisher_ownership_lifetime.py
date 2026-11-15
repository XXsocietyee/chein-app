"""Source invariants only: Swift and device behavior remain unverified."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]

class PublisherOwnershipLifetimeTests(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'App/PublisherLifecycleViews.swift').read_text()
        self.view = source.split('@MainActor struct PublisherOwnershipReviewView:', 1)[1].split('@MainActor struct PublisherXPBudgetSection:', 1)[0]

    def test_review_and_message_are_identity_scoped(self):
        self.assertIn('review.session == coordinator.currentSession, review.action == action', self.view)
        self.assertIn('messageSession == coordinator.currentSession', self.view)
        self.assertIn('value.session == session, value.action == action, review == value', self.view)

    def test_leave_identity_and_action_retire_results(self):
        for expected in ['.onDisappear { visible = false; clear() }', '.onChange(of: action)', '.onChange(of: coordinator.currentSession)', 'generation = UUID(); review = nil;', 'visible && phase == .active && generation == stamp']:
            self.assertIn(expected, self.view)
        self.assertEqual(self.view.count('defer { if isCurrent(stamp, session, capturedAction) { busy = false } }'), 2)

    def test_original_writer_is_unchanged_and_results_are_guarded(self):
        self.assertEqual(self.view.count('await coordinator.confirm(value, consequentialApproval: true)'), 1)
        after = self.view.split('let result = await coordinator.confirm', 1)[1]
        self.assertLess(after.index('guard isCurrent'), after.index('message ='))
        self.assertIn('await coordinator.prepare(capturedAction)', self.view)
        self.assertIn('public var currentSession: PublishingSession? { client.session }', (ROOT / 'Core/PublisherLifecycleCoordinator.swift').read_text())

if __name__ == '__main__':
    unittest.main()
