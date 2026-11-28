"""Owner check 11-28 05:35 (mp-activity P0): every in-app registration pay uses `/api/registration/pay/app`.

`/api/registration/pay` is the MP JSAPI route (wx.requestPayment for the mini-program openid); the app's WeChat SDK
cannot use its params, so no app call site may pass `.standard`, and the pay section must hand APP params to the SDK.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class RegistrationAppPayChannelTests(unittest.TestCase):
    def test_no_in_app_pay_section_uses_the_jsapi_route(self):
        offenders = []
        for path in sorted((ROOT / "App").rglob("*.swift")):
            text = path.read_text(encoding="utf-8")
            if "RegistrationPaySection(" not in text and "RegistrationPayBridge.pay(" not in text:
                continue
            if re.search(r"channel:\s*\.standard\b", text):
                offenders.append(str(path.relative_to(ROOT)))
        self.assertEqual(offenders, [])

    def test_defaults_point_at_the_app_route(self):
        section = (ROOT / "App/RegistrationPaySection.swift").read_text(encoding="utf-8")
        self.assertNotIn("channel: RegistrationPayChannel = .standard", section)
        self.assertIn("RegistrationAppPayResolver.inAppChannel", section)
        resolver = (ROOT / "Core/RegistrationAppPay.swift").read_text(encoding="utf-8")
        self.assertIn("inAppChannel: RegistrationPayChannel = .app", resolver)

    def test_pay_params_open_the_wechat_sdk(self):
        section = (ROOT / "App/RegistrationPaySection.swift").read_text(encoding="utf-8")
        self.assertIn("RegistrationAppPayRows(context: appPay", section)
        rows = (ROOT / "App/RegistrationAppPayRows.swift").read_text(encoding="utf-8")
        self.assertIn("session.registrationPaymentProvider", rows)
        self.assertIn("readRegistrationPaymentStatus", rows)
        app = (ROOT / "App/QuestifyApp.swift").read_text(encoding="utf-8")
        self.assertIn(".environment(\\.registrationAppPay, RegistrationAppPayBridge.context(session))", app)


if __name__ == "__main__":
    unittest.main()
