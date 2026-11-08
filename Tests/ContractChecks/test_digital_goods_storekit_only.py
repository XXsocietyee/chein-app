"""FP-H5: digital goods on iOS are StoreKit only (App Store 3.1.1). Source-level guards that complement
Tests/CoreTests/WorkshopDigitalChannelPolicyTests.swift."""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


class DigitalGoodsStoreKitOnly(unittest.TestCase):
    def test_workshop_commerce_has_no_wechat_wallet_or_points_payment(self):
        for path in sorted((ROOT / 'Core').glob('WorkshopCommerce*.swift')) + [ROOT / 'Core/WorkshopStoreKitLauncher.swift']:
            code = '\n'.join(line for line in path.read_text().splitlines() if not line.strip().startswith('//'))
            self.assertIsNone(re.search(r'WeChatSDKPayment|WechatPay|WeChatPay|walletBalance|WALLET|WECHAT_PAY', code), path.name)

    def test_only_apple_storekit_channel_literal_in_workshop_commerce(self):
        text = ''.join((ROOT / 'Core' / name).read_text() for name in ('WorkshopCommerceContracts.swift', 'WorkshopCommerceController.swift', 'WorkshopStoreKitLauncher.swift'))
        channels = set(re.findall(r'channel\s*(?:==|!=)\s*"([A-Z_]+)"', text)) | set(re.findall(r'"channel"\]\s*==\s*"([A-Z_]+)"', text))
        self.assertEqual(channels, {'APPLE_STOREKIT'})

    def test_wechat_payment_adapter_is_not_referenced_by_workshop_or_mod_purchase_code(self):
        offenders = []
        for folder in ('App', 'Core'):
            for path in (ROOT / folder).rglob('*.swift'):
                if 'WeChatSDKPaymentAdapter' in path.read_text() and re.search(r'Workshop|ModPurchase|DigitalMod', path.name):
                    offenders.append(path.name)
        self.assertEqual(offenders, [])


if __name__ == '__main__':
    unittest.main()
