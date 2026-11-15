"""Static source invariants; no live cancellation or refund is exercised."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]

class PublisherCancellationLifetimeTests(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'App/PublisherLifecycleViews.swift').read_text()
        self.view = source.split('@MainActor struct PublisherCancellationView:', 1)[1].split('/// Use for selected eligible club', 1)[0]

    def test_review_uses_exact_original_reason_and_resource(self):
        self.assertIn('.cancel(resource, reason: reason, scope: nil)', self.view)
        self.assertIn('let stamp = UUID(), action = currentAction', self.view)
        self.assertIn('coordinator.prepare(action)', self.view)
        self.assertIn('review.action == currentAction, let count = review.paidPlayers', self.view)
        self.assertIn('value.action == currentAction, review == value', self.view)

    def test_identity_leave_reason_and_resource_invalidate(self):
        for item in ['.onChange(of: reason)', '.onChange(of: resource)', '.onChange(of: coordinator.currentSession)', '.onDisappear { visible = false; clear() }', 'messageSession == coordinator.currentSession']:
            self.assertIn(item, self.view)
        self.assertIn('generation = UUID(); review = nil;', self.view)
        self.assertEqual(self.view.count('defer { if isCurrent(stamp, session, action) { busy = false } }'), 2)

    def test_original_confirm_retains_authorization_and_late_result_guard(self):
        self.assertEqual(self.view.count('await coordinator.confirm(value, consequentialApproval: true)'), 1)
        after = self.view.split('let outcome = await coordinator.confirm', 1)[1]
        self.assertLess(after.index('guard isCurrent'), after.index('message ='))
        self.assertIn('currentAction == action', self.view)
        self.assertNotIn('journal', self.view)

if __name__ == '__main__':
    unittest.main()
