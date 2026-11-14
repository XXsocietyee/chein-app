"""PAGE-READY guards for subpackageMember/couponInfo/couponInfo. Not a Swift compile."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[2]


class CouponInfoPageReady(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / "Core/CouponManagementDomain.swift").read_text()
        start = self.source.index("/// Read model for `subpackageMember/couponInfo/couponInfo`.")
        self.page = self.source[start:]
        self.contract = (ROOT / "Core/CouponManagementContract.swift").read_text()

    def test_route_stays_partial_and_payment_stays_off(self):
        row = next(line for line in (ROOT / "docs/parity/page-map.csv").read_text().splitlines()
                   if line.startswith("subpackageMember/couponInfo/couponInfo,"))
        self.assertIn(",exists,", row)
        self.assertIn("App/CouponManagementView.swift", row)
        self.assertIn("public static let routeMarkedLive = false", self.page)
        self.assertIn("public static let paymentEnabled = false", self.page)
        self.assertIn("public static let virtualGoodsEnabled = false", self.page)
        self.assertIn("public static let saveEnabled = false", self.page)
        self.assertIn("public static let includedInPlayerFirstEntry = false", self.page)
        self.assertIn('public static let publishedPath = "/api/coupon/mypublishlist"', self.page)
        self.assertIn('public static let publishPath = "/api/coupon/publish"', self.page)
        self.assertIn('"/api/coupon/mypublishlist"', self.contract)
        self.assertIn('"/api/coupon/publish"', self.contract)
        self.assertNotIn("/api/coupon/update", self.page)
        self.assertNotIn("/api/coupon/update", self.contract)
        self.assertNotIn("/api/registration/pay", self.page)
        self.assertNotIn("dormantWritesEnabled: true", self.page)
        self.assertNotIn("?? 0", self.page)
        self.assertNotIn("amount ?? 0", self.source)

    def test_referenced_keys_already_exist(self):
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())["strings"]
        fragment = json.loads((ROOT / "Resources/CouponManagementLocalizations.fragment.json").read_text())
        keys = [
            "couponManagement.loading", "couponManagement.empty", "couponManagement.signIn",
            "couponManagement.unavailable", "couponManagement.malformed", "couponManagement.serverError",
            "couponManagement.unknownOutcome", "couponManagement.forbidden", "couponManagement.storage",
            "couponManagement.changed", "couponManagement.invalid", "couponManagement.refresh",
            "couponManagement.checkPendingResults",
        ]
        for key in keys:
            self.assertIn(f'"{key}"', self.page)
            for table in (catalog, fragment):
                entry = table[key]
                self.assertEqual(set(entry["localizations"]), {"en", "zh-Hans"})
                for language in ("en", "zh-Hans"):
                    unit = entry["localizations"][language]["stringUnit"]
                    self.assertEqual(unit["state"], "translated")
                    self.assertTrue(unit["value"].strip())
        self.assertIn('public static let unknownDisplay = "—"', self.page)

    def test_missing_keys_are_listed_and_not_invented(self):
        note = (ROOT / "docs/release/page-ready/subpackageMember-couponInfo-couponInfo.md").read_text()
        catalog = json.loads((ROOT / "Resources/Localizable.xcstrings").read_text())["strings"]
        missing = [
            "couponManagement.save",
            "couponManagement.range.completed",
            "couponManagement.network",
            "couponManagement.dataError",
            "couponManagement.retry",
        ]
        for key in missing:
            self.assertIn(f"`{key}`", note)
            # ui/prkeys (L1) added these with en + zh-Hans; the page model still does not reference them.
            self.assertEqual(set(catalog[key]["localizations"]), {"en", "zh-Hans"})
            self.assertNotIn(f'"{key}"', self.page)
        self.assertIn("时间设置完成", note)
        self.assertNotIn("/api/coupon/update", note)


if __name__ == "__main__":
    unittest.main()
