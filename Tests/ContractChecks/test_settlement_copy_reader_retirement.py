"""Static retirement wiring checks; clipboard and production remain untouched."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class SettlementCopyReaderRetirementTests(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / 'App/MerchantSettlementProgressView.swift').read_text()
    def test_same_scope_reader_replacement_and_disabled_configuration_retire_intent(self):
        for expression in ['ObjectIdentifier(reader)', 'reader.isConfigured', 'reader.scope', 'reader.authorizationGeneration']:
            self.assertIn('.onChange(of: '+expression+') { _, _ in copyModel.invalidate() }', self.source)
    def test_retirement_clears_feedback_and_rejects_old_copy_before_and_after_read(self):
        self.assertIn('func invalidate() { intentID = UUID(); busy = false; messageKey = nil }', self.source)
        self.assertIn('guard intent == intentID, !busy, !Task.isCancelled else { return }', self.source)
        self.assertIn('guard intentID == ticket, !Task.isCancelled,', self.source)
        self.assertIn('reader.isConfigured, reader.scope == scope, reader.authorizationGeneration == authorization', self.source)
        self.assertIn('currentSnapshot() == baseline, latest.access == baseline.access', self.source)
if __name__ == '__main__': unittest.main()
