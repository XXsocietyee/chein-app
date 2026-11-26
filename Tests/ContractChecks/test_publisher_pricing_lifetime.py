"""Static UI invariants, not Swift compilation or financial verification."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]

class PublisherPricingLifetimeTests(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'App/PublisherLifecycleViews.swift').read_text()
        self.view = source.split('@MainActor struct PublisherPricingView:', 1)[1].split('@MainActor struct PublisherPartnerView:', 1)[0]

    def test_server_price_and_original_writer_are_preserved(self):
        self.assertIn('try await client.pricing(capturedInput)', self.view)
        self.assertIn('price = String(TopicPricingXcx.initialPrice(floor: value.minimum))', self.view)
        self.assertIn('try await coordinator.prepare(action)', self.view)
        # r10 R8-PC-B4-1: pages/topic/pricing/index.js:441-460 posts /api/topic/pricing/confirm (a final-price save,
        # not money). The view sends it through the coordinator, which still needs the pricing grant and a fresh review.
        self.assertIn('await coordinator.confirm(value, consequentialApproval: true)', self.view)
        self.assertIn('/api/topic/pricing/confirm', self.view)
        self.assertIn('value.action == currentAction', self.view)

    def test_queued_work_and_late_results_are_scoped(self):
        # Preview load, prepare and (r10 R8-PC-B4-1) confirm are each fenced by the same generation/session/form key.
        self.assertEqual(self.view.count('guard isCurrent(stamp, session, key), !Task.isCancelled'), 8)
        self.assertEqual(self.view.count('defer { if isCurrent(stamp, session, key) { busy = false } }'), 3)
        self.assertIn('formKey == key', self.view)
        self.assertIn('[String(topicID), String(describing: subtype), cost, team, price]', self.view)
        self.assertIn('resultSession == client.session', self.view)

    def test_leave_account_and_form_changes_retire_reviews(self):
        for item in ['.onChange(of: client.session)', '.onChange(of: topicID)', '.onDisappear { visible = false; invalidate() }', '.onChange(of: price) { _, _ in invalidate(keepPreview: true) }']:
            self.assertIn(item, self.view)
        self.assertIn('generation = UUID(); review = nil; message = ""; busy = false; loadFailed = false', self.view)
        self.assertIn('review.session == client.session, review.action == currentAction', self.view)

if __name__ == '__main__':
    unittest.main()
