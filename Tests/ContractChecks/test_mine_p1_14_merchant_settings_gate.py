"""Function audit P1-14: the Settings account card never opens the merchant brand page while merchant is gated (Release)."""
import unittest
from pathlib import Path
W=Path(__file__).resolve().parents[2]
R=(W/'App/ProfileSettingsProfileRoute.swift').read_text()
class MerchantSettingsGateTests(unittest.TestCase):
 def test_merchant_access_gated(self):self.assertIn('guard PlayerLaunch.merchantCenterEnabled, accountID > 0, role == "merchant"',R)
 def test_current_gated(self):self.assertIn('guard PlayerLaunch.merchantCenterEnabled else { return nil }',R)
 def test_brand_destination_gated(self):self.assertIn('if PlayerLaunch.merchantCenterEnabled, let reader = route.access.merchantReader',R)
if __name__=='__main__':unittest.main()
