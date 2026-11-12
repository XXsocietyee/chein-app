"""Composition admits only the signed-in ordinary send receipt. Not Swift or HTTP."""
import pathlib
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class IMSendReceiptCompositionContracts(unittest.TestCase):
    def test_signed_in_receipt_is_admitted_without_opening_send(self):
        source = (ROOT / "App/AppCompositionRoot.swift").read_text()
        start = source.index('url == api.baseURL.appendingPathComponent("api/im/send-receipt")')
        block = source[source.rfind("} else if", 0, start):source.index("} else if", start)]
        self.assertIn('request.httpMethod == "POST"', block)
        self.assertIn("request.url?.query == nil", block)
        self.assertIn("request.url?.fragment == nil", block)
        self.assertIn("captured.isSignedInContentViewer", block)
        self.assertNotIn('appendingPathComponent("api/im/send")', block)
        feature = (ROOT / "Core/BusinessRuntimeConfiguration.swift").read_text()
        self.assertIn('case .imSend: paths = ["api/im/send", "api/im/send-receipt"]', feature)


if __name__ == "__main__":
    unittest.main()
