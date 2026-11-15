"""Source presentation regression, not a payment or entitlement acceptance test."""
from pathlib import Path
import json
import unittest
ROOT = Path(__file__).resolve().parents[2]

class PaymentReturnAcceptedCopyTests(unittest.TestCase):
    def test_accepted_uses_registration_fact_not_pass_entitlement(self):
        view = (ROOT / 'App/PaymentProviderReturnSheet.swift').read_text()
        self.assertIn('model.flow.phase == .paid ? "contextSelfPlay.paymentConfirmed" : "orderLifecycle.payment.registrationAccepted"', view)
        self.assertNotIn('contextSelfPlay.passConfirmed', view)
        flow = (ROOT / 'Core/PaymentProviderReturnFlow.swift').read_text()
        self.assertIn('case .registrationAccepted: phase = .accepted', flow)
        self.assertIn('case .paid: phase = .paid', flow)

    def test_reused_resource_explicitly_does_not_confirm_settlement(self):
        values = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text())['strings']['orderLifecycle.payment.registrationAccepted']['localizations']
        self.assertEqual(values['en']['stringUnit']['value'], 'Registration accepted; payment settlement is not confirmed')
        self.assertEqual(values['zh-Hans']['stringUnit']['value'], '报名已确认，支付到账尚未确认')

if __name__ == '__main__':
    unittest.main()
