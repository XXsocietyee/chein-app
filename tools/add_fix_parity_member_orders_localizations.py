#!/usr/bin/env python3
"""fix/parity-member orders slice (pages 16-20): 我的订单, 订单详情, 积分明细, 提现记录, 邀请记录."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

S = {
    # FIN-16-1 / FIN-17-1: MP cancelRegistration labels.
    'profile.orderExit.cancel': ('Cancel order', '取消订单'),
    'profile.orderExit.refund': ('Request refund', '申请退款'),
    'profile.orderExit.cancelSignup': ('Cancel sign-up', '取消报名'),
    'profile.orderExit.viaSupport': ('To cancel or get a refund, contact support.', '如需取消或退款，请联系客服'),
    # FIN-16-5: payment is gated in this release.
    'profile.orders.payElsewhere': ('Complete payment in the mini-program', '请在小程序完成支付'),
    # FIN-18-3: MP points-history empty copy.
    'wallet.points.empty.all': ('No points records yet', '还没有积分记录'),
    # FIN-16-3: a failed pull keeps the page (MP toast 刷新失败，稍后再试).
    'profile.refreshFailed': ("Couldn't refresh. Try again later.", '刷新失败，稍后再试'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    path = ROOT / 'Resources/Localizable.xcstrings'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in S.items():
        strings[key] = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(S)} fix-parity-member orders strings written')


if __name__ == '__main__':
    main()
