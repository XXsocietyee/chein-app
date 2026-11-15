"""Static host lifecycle checks; no merchant or transaction request is executed."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
class MerchantOrdersReadLifetimeTests(unittest.TestCase):
    def setUp(self):
        self.view = (ROOT / 'App/MerchantOrdersView.swift').read_text().split('private struct MerchantOrderRow:', 1)[0]
    def test_identity_configuration_and_reader_replacement_key(self):
        for item in ['ObjectIdentifier(reader)', 'revision: reader.sessionRevision', 'configured: reader.isConfigured', 'signedIn: reader.isSignedIn', '.task(id: readKey)', 'loadedKey == readKey']:
            self.assertIn(item, self.view)
    def test_retry_is_owned_and_departure_retires_rows(self):
        self.assertNotIn('retry: { Task', self.view)
        self.assertIn('ownedTask?.cancel(); ownedTask = nil', self.view)
        self.assertIn('selection = nil; showFilters = false; loadedKey = nil; model.clear()', self.view)
        self.assertIn('guard visible, key == readKey, !Task.isCancelled else { return }', self.view)
    def test_cancelled_entry_does_not_retire_current_summary_or_start_access_read(self):
        reload = self.view.split('private func reload(', 1)[1]
        self.assertLess(reload.index('guard visible, !Task.isCancelled'), reload.index('selection = nil'))
        self.assertLess(reload.index('try Task.checkCancellation()'), reload.index('reader.merchantAccess()'))
        self.assertIn('guard access.allows(.orders)', reload)
        self.assertIn('reader.merchantOrders(access: access, filter: requestedFilter)', reload)
        self.assertIn('!model.isLoading && model.errorKey == nil', self.view)
if __name__ == '__main__': unittest.main()
