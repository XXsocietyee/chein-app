#!/usr/bin/env python3
"""Fix 11-28 us-pay (audit P0-3 / P1-3): strings of the US Stripe / Apple Pay pay rows (en + zh-Hans)."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Resources' / 'Localizable.xcstrings'

STRINGS = {
    'registration.stripe.payWithCard %@': ('Pay %@ by card', '使用银行卡支付 %@'),
    'registration.stripe.declined': ('The card was declined. Try another card.', '银行卡被拒绝，请换一张卡再试。'),
    'registration.stripe.expired': ('This order can no longer be paid. Place a new order.', '该订单已无法支付，请重新下单。'),
    'registration.stripe.notCompleted': ('Payment not completed. You can pay again.', '支付未完成，可以重新支付。'),
    'registration.stripe.unavailable': ('Card and Apple Pay are not available for this order right now. Try again later.',
                                        '该订单暂时无法使用银行卡或 Apple Pay 支付，请稍后再试。'),
    'registration.stripe.noMethod': ('Apple Pay is not set up on this device. Add a card in Wallet to pay.',
                                     '此设备尚未设置 Apple Pay，请先在钱包中添加银行卡。'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    catalog = json.loads(CATALOG.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in STRINGS.items():
        strings[key] = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
    CATALOG.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


if __name__ == '__main__':
    main()
