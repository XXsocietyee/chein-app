"""PAGE-READY guards for subpackageMember/invoice-apply/index. Not a Swift compile."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class InvoiceApplyPageReady(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "Core/InvoiceLaunchContracts.swift").read_text()
        start = self.source.index("/// Read-only page model for `subpackageMember/invoice-apply/index`.")
        self.page = self.source[start:]

    def test_route_stays_partial_and_payment_stays_off(self):
        row = next(line for line in (ROOT / "docs/parity/page-map.csv").read_text().splitlines()
                   if line.startswith("subpackageMember/invoice-apply/index,"))
        self.assertIn(",exists,", row)
        self.assertIn("App/InvoiceLaunchApplyView.swift", row)
        self.assertIn("public static let routeMarkedLive = false", self.page)
        self.assertIn("public static let paymentEnabled = false", self.page)
        self.assertIn("public static let includedInPlayerFirstEntry = false", self.page)
        self.assertNotIn("/api/registration/pay", self.page)
        self.assertNotIn("mutationsEnabled: { true }", self.page)
        self.assertNotIn("?? 0", self.page)

    def test_referenced_keys_already_exist_in_the_invoice_catalog(self):
        catalog = json.loads((ROOT / "Resources/InvoiceLaunchUI.xcstrings").read_text())
        keys = ["loading", "noOrders", "loadFailed", "session", "storage", "notSaved", "unknown", "retry", "checkResult"]
        for key in keys:
            self.assertIn(f'public static let {self._swift_name(key)}', self.page)
            entry = catalog["strings"][key]
            self.assertEqual(set(entry["localizations"]), {"en", "zh-Hans"})
            for language in ("en", "zh-Hans"):
                unit = entry["localizations"][language]["stringUnit"]
                self.assertEqual(unit["state"], "translated")
                self.assertTrue(unit["value"].strip())
        self.assertIn('public static let unknownDisplay = "—"', self.page)

    def test_unlabeled_order_fields_are_not_given_invented_copy(self):
        for key in ('"issuerName"', '"ticketName"', '"paymentTime"', '"orderTitle"', '"issuer"', '"payment time"'):
            self.assertNotIn(key, self.page)
        for sentence in ("税", "客服", "customer service", "tax rate"):
            self.assertNotIn(sentence, self.page)

    def _swift_name(self, key):
        return {
            "loading": "loading",
            "noOrders": "empty",
            "loadFailed": "loadFailed",
            "session": "session",
            "storage": "storage",
            "notSaved": "notSaved",
            "unknown": "unknown",
            "retry": "retry",
            "checkResult": "checkResult",
        }[key]


if __name__ == "__main__":
    unittest.main()
