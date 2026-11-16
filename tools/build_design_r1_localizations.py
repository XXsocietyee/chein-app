#!/usr/bin/env python3
"""Build the design hand-off r1 catalogs for the member/club and merchant/creator kits.

Writes Resources/DesignR1Club.xcstrings (keys `r1club.*`, read by `clubR1(_:_:)`) and
Resources/DesignR1Merchant.xcstrings (keys `r1merchant.*`, read by `merchantR1(_:_:)`).
Usage: python3 -B tools/build_design_r1_localizations.py [--check]
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

CLUB = {
    'common.close': ('Close', '关闭'),
    'common.cancel': ('Cancel', '取消'),
    'common.more': ('More', '更多'),
    # MC-10 create flow
    'create.kind.0.sub': ('Student groups · campus routes', '学生组织 · 校园路线'),
    'create.kind.1.sub': ('City exploring · outdoor leading', '城市探索 · 户外带队'),
    'create.kind.2.sub': ('Like-minded people · city routes', '同好聚集 · 城市路线'),
    'create.kind.3.sub': ('Brand routes · commercial events', '品牌路线 · 商业执行'),
    'create.kind.4.sub': ('Content output · IP operations', '内容产出 · IP 运营'),
    'create.kind.5.sub': ('None of the above', '以上都不是'),
    'create.city.label': ('City', '城市'),
    'create.city.placeholder': ('Choose a city', '选择城市'),
    'create.city.hint': ('Opens the city list', '打开城市列表'),
    'create.city.sheetTitle': ('Choose a city', '选择城市'),
    'create.city.search': ('Search cities', '搜索城市'),
    'create.city.current': ('Current location', '当前定位'),
    'create.city.hot': ('Popular cities', '热门城市'),
    # MC-20 member actions, MC-33 consequence sheet, page-end rows
    'member.action.report': ('Report', '举报'),
    'member.action.makeAdmin': ('Make admin', '设为管理员'),
    'member.action.tempBan': ('Suspend for a while', '临时封禁'),
    'member.action.remove': ('Remove', '移除'),
    'member.menuNamed': ('Actions for %@', '%@ 的操作'),
    'member.consequence.tempBan.title': ('Suspend member', '临时封禁成员'),
    'member.consequence.tempBan.line1': ('They cannot post, comment or sign up until the suspension ends', '封禁期内不能发帖、评论或报名'),
    'member.consequence.tempBan.line2': ('They are told the reason and the end date', '对方会收到原因和解封时间'),
    'member.consequence.remove.title': ('Remove member', '移除成员'),
    'member.consequence.remove.line1': ('They leave the club and lose member-only access', '对方将离开俱乐部，失去成员权限'),
    'member.consequence.remove.line2': ('They can apply again later', '之后对方仍可重新申请加入'),
    'club.leave': ('Leave club', '退出俱乐部'),
    'club.report': ('Report club', '举报俱乐部'),
    'request.approve': ('Approve', '通过'),
    'request.reject': ('Decline', '拒绝'),
    # MC-29 withdrawal hand-off (owner Q-C: keep it, name it, explain it)
    'funds.withdrawViaSupport': ('Request withdrawal via support', '通过客服申请提现'),
    'funds.handOff.title': ('Withdrawals are handled by platform support', '提现由平台客服办理'),
    'funds.handOff.line': ('Open support and send the club name and amount. Support replies within 1 working day and pays out to your verified account.', '打开客服后发送俱乐部名称和金额，客服 1 个工作日内回复，款项打到你已核验的收款账户。'),
    # MC-30 badges
    'badge.a11y.earned': ('%@, earned', '%@，已获得'),
    'badge.a11y.locked': ('%@, locked. %@', '%@，未解锁。%@'),
    'badge.a11y.progress': ('%@, %ld of %ld', '%@，进度 %ld / %ld'),
}

MERCHANT = {
    'common.close': ('Close', '关闭'),
}


def entry(en, zh):
    return {'localizations': {
        'en': {'stringUnit': {'state': 'translated', 'value': en}},
        'zh-Hans': {'stringUnit': {'state': 'translated', 'value': zh}},
    }}


def render(prefix, table):
    catalog = {'sourceLanguage': 'en',
               'strings': {f'{prefix}.{key}': entry(en, zh) for key, (en, zh) in sorted(table.items())},
               'version': '1.0'}
    return json.dumps(catalog, ensure_ascii=False, indent=2) + '\n'


TARGETS = (
    (ROOT / 'Resources/DesignR1Club.xcstrings', 'r1club', CLUB),
    (ROOT / 'Resources/DesignR1Merchant.xcstrings', 'r1merchant', MERCHANT),
)


def main(argv):
    check = '--check' in argv
    stale = []
    for path, prefix, table in TARGETS:
        text = render(prefix, table)
        if check:
            if not path.exists() or path.read_text() != text:
                stale.append(str(path.relative_to(ROOT)))
        else:
            path.write_text(text)
    if stale:
        print('STALE: ' + ', '.join(stale) + ' (run tools/build_design_r1_localizations.py)')
        return 1
    print(json.dumps({'status': 'CHECKED' if check else 'WRITTEN', 'club': len(CLUB), 'merchant': len(MERCHANT)}))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
