"""Source contract only (not compiled Swift): the host-cancel sheet must stay open on the server notice."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class HostCancelAcknowledgementChecks(unittest.TestCase):
    def setUp(self):
        self.view = (ROOT / 'App/ActivityHostCancelView.swift').read_text()
    def test_submit_does_not_auto_complete(self):
        self.assertNotIn('if await model.submit()', self.view)
        self.assertIn('_ = await model.submit()', self.view)
    def test_notice_uses_server_message_rule(self):
        self.assertIn('ActivityHostCancelRules.completionNotice(serverMessage: serverMsg)', self.view)
    def test_done_and_close_acknowledge(self):
        self.assertIn('activity.hostCancel.done', self.view)
        self.assertIn('if case .cancelled = model.phase { Task { await onCompleted() } }', self.view)
if __name__ == '__main__':
    unittest.main()
