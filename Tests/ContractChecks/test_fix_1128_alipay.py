"""fix-1128-alipay (audit P0-4): Alipay app pay wiring, source checks only (no Swift compiler, no SDK binary)."""
from pathlib import Path
import plistlib
import unittest

ROOT = Path(__file__).resolve().parents[2]


class AlipayAppPayWiring(unittest.TestCase):
    def read(self, p):
        return (ROOT / p).read_text(encoding='utf-8')

    def test_backend_routes_and_form_id(self):
        s = self.read('Core/AlipayAppPay.swift')
        for token in ['case order = "api/pay/alipay/order"', 'case query = "api/pay/alipay/query"',
                      'fields: ["id": String(registrationID)]', 'quoteChannel = "APP_ALIPAY"',
                      '"ORDER_ALREADY_PAID"', '"ORDER_EXPIRED"', '"ALIPAY_NOT_CONFIGURED"']:
            self.assertIn(token, s)
        grants = self.read('Core/ChinaReviewedRouteCapability.swift')
        self.assertIn('"/api/pay/alipay/order": .payment, "/api/pay/alipay/query": .payment', grants)

    def test_driver_bridge_flag_and_url_fallback(self):
        m = self.read('App/QFAlipayPaymentBridge.m')
        for token in ['QUESTIFY_ALIPAY_SDK_APPROVED', '__has_include(<AlipaySDK/AlipaySDK.h>)',
                      'payOrder:orderString fromScheme:scheme callback:', 'processOrderWithPaymentResult:url']:
            self.assertIn(token, m)
        self.assertIn('"QFAlipayPaymentBridge.h"', self.read('App/Questify-Bridging-Header.h'))
        d = self.read('App/AlipayPaymentDriver.swift')
        self.assertIn('AlipayURLPayment.launchURL', d)
        self.assertIn('"QuestifyAlipayAppScheme"', d)
        for p in (ROOT / 'Config').glob('*'):
            if p.is_file():
                self.assertNotIn('QUESTIFY_ALIPAY_SDK_APPROVED=1', p.read_text())

    def test_owner_scheme_is_an_empty_placeholder(self):
        info = plistlib.loads((ROOT / 'Config/Info.plist').read_bytes())
        self.assertEqual(info['QuestifyAlipayAppScheme'], '$(QUESTIFY_ALIPAY_APP_SCHEME)')
        self.assertIn('QUESTIFY_ALIPAY_APP_SCHEME =\n', self.read('Config/Base.xcconfig'))
        self.assertIn('QUESTIFY_ALIPAY_APP_SCHEME', self.read('docs/release/owner-values.md'))

    def test_session_and_pay_step_are_wired(self):
        session = self.read('App/AppSession.swift')
        self.assertIn('lazy var alipayPay = AlipayPayHub(session: self)', session)
        self.assertIn('|| handleAlipayReturn(url) { return }', session)
        self.assertIn('.environment(\\.registrationAlipayPay, RegistrationAlipayBridge.context(session))',
                      self.read('App/QuestifyApp.swift'))
        pay = self.read('App/RegistrationPaySection.swift')
        self.assertIn('RegistrationAlipayPayRows(context: alipayPay', pay)
        self.assertIn('RegistrationPayStepMethodRow(selection: payStepMethodBinding', pay)
        sheet = self.read('App/RegistrationSheetView.swift')
        self.assertIn('alipayOffered: alipayOffered)', sheet)
        self.assertIn('.environment(\\.registrationPayMethodChoice, effectivePayMethod)', sheet)
        rows = self.read('App/RegistrationAlipayPayRows.swift')
        for token in ['context.createOrder(registrationID)', 'context.launch(registrationID, order)',
                      'context.query(registrationID)', 'RegistrationAlipayResolver.stage(providerReturn:']:
            self.assertIn(token, rows)

    def test_no_alipay_login_anywhere(self):
        for folder in ('App', 'Core'):
            for p in (ROOT / folder).rglob('*.swift'):
                text = p.read_text(encoding='utf-8')
                self.assertNotIn('login/alipay', text, str(p))
                self.assertNotIn('AlipayAuthAdapter', text, str(p))


if __name__ == '__main__':
    unittest.main()
