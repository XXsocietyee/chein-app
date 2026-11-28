"""mp-nav r3 (B lane): activity detail → 票夹 is a push (MP navigateTo subpackageMember/signup/index), not a sheet."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class ActivityWalletPushChecks(unittest.TestCase):
    def test_wallet_is_pushed_with_system_back(self):
        source = (ROOT / 'App/ActivityDetailView.swift').read_text()
        self.assertIn('.navigationDestination(isPresented: $showsTicketWallet) {', source)
        self.assertIn('SessionTicketWalletHost(isPushed: true)', source)
        self.assertNotIn('.cySheet(isPresented:$showsTicketWallet', source)
        self.assertNotIn('SessionTicketWalletHost(onClose:{ showsTicketWallet=false })', source)


if __name__ == '__main__':
    unittest.main()
