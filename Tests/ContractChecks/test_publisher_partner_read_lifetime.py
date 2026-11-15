"""Static read lifecycle checks; no production partner requests are made."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class PublisherPartnerReadLifetimeTests(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'App/PublisherLifecycleViews.swift').read_text()
        self.view = source.split('@MainActor struct PublisherPartnerView:', 1)[1].split('@MainActor struct PublisherCancellationView:', 1)[0]
    def test_full_identity_and_target_key_controls_load_and_display(self):
        for text in ['ObjectIdentifier(client)', 'session: client.session', 'topicID: topicID, row: row', 'active: phase == .active', '.task(id: readKey)', 'resultKey == readKey', 'if resultKey == readKey, !message.isEmpty']:
            self.assertIn(text, self.view)
    def test_cancelled_entry_and_late_success_or_error_do_not_mutate_current_state(self):
        load = self.view.split('private func load(', 1)[1]
        self.assertLess(load.index('guard !Task.isCancelled'), load.index('retire()'))
        self.assertEqual(load.count('guard !Task.isCancelled, generation == stamp, key == readKey else { return }'), 2)
        self.assertIn('.onDisappear { retire() }', self.view)
    def test_original_read_contract_and_terms_are_preserved(self):
        self.assertIn('try await client.partner(topicID: key.topicID, type: key.row.type, id: key.row.partnerID)', self.view)
        self.assertIn('terms.mode == 1', self.view)
        self.assertIn('terms.fixedFee', self.view)
        self.assertNotIn('coordinator.confirm', self.view)
if __name__ == '__main__': unittest.main()
