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
    # r4 (MC-29, owner Q-C 2026-11-16): the button says what it does; the hand-off note above it names support.
    'funds.withdrawViaSupport': ('Contact platform support to withdraw', '联系平台客服提现'),  # MP settlement (fix-r3-club-b r4)
    'funds.handOff.title': ('Withdrawals are handled by platform support', '提现由平台客服办理'),
    'funds.handOff.line': ('Open support and send the club name and amount. Support replies within 1 working day and pays out to your verified account.', '打开客服后发送俱乐部名称和金额，客服 1 个工作日内回复，款项打到你已核验的收款账户。'),
    # MC-13 switch explanations
    'switch.prioritySignup': ('Members can sign up for activities before everyone else', '成员可以比其他人更早报名活动'),
    'switch.joinReview': ('New members join only after an organizer approves them', '新成员需要组织者通过后才能加入'),
    # MC-25 roster card
    'roster.expand': ('Shows money and attendees', '展开收款与报名人'),
    'roster.collapse': ('Hides money and attendees', '收起收款与报名人'),
    'roster.received': ('Received', '实收'),
    'roster.refunded': ('Refunded', '已退'),
    'roster.net': ('Net', '净额'),
    # polish-d-r1: the members screen roster summary
    'roster.members.roles': ('Creator: %ld · Admins: %ld · Members: %ld', '创建者 %ld · 管理员 %ld · 成员 %ld'),
    # verify-r1 2.6: the roster card heads 报名名册
    'roster.title': ('Sign-up roster', '报名名册'),
    # polish-d-r1: club tab creation quota in plain words
    'quota.within': ('You have created %ld clubs. You can create %ld more.', '你已创建 %ld 个俱乐部，还能再创建 %ld 个。'),
    'quota.full': ('You have created %ld clubs, the most allowed.', '你已创建 %ld 个俱乐部，已达上限。'),
    'quota.over': ('You have created %ld clubs; the limit is %ld. You cannot create another one for now.', '你已创建 %ld 个俱乐部，上限是 %ld 个，暂时不能再创建新的俱乐部。'),
    'quota.overTag': ('Over the limit', '已超出上限'),
    # MC-30 badges
    'badge.a11y.earned': ('%@, earned', '%@，已获得'),
    'badge.a11y.locked': ('%@, locked. %@', '%@，未解锁。%@'),
    'badge.a11y.progress': ('%@, %ld of %ld', '%@，进度 %ld / %ld'),
}

MERCHANT = {
    'common.close': ('Close', '关闭'),
    'common.more': ('More', '更多'),
    # MR-01 onboarding review step
    'onboarding.review.group1': ('Shop basics', '店铺基本信息'),
    'onboarding.review.group2': ('Where and when', '店在哪、几点开'),
    'onboarding.review.group3': ('Business documents', '上传经营资料'),
    # Owner 2026-11-16: the identity step (verify-r1 Q2 changed)
    'onboarding.review.group4': ('Operator identity', '经营者身份'),
    'onboarding.review.edit': ('Edit', '修改'),
    'onboarding.review.licenseMissing': ('Business licence not uploaded yet', '还没有上传营业执照'),
    'onboarding.consent': ('By submitting you confirm the information is true and agree to the merchant terms.', '提交即表示你确认以上信息真实，并同意商家入驻协议。'),
    'onboarding.submit': ('Submit application', '提交入驻申请'),
    # MR-04 unknown outcome
    'outcome.check': ('Check result', '查看结果'),
    'outcome.retry': ('Try again', '重试'),
    'outcome.copyDiagnostics': ('Copy diagnostic info', '复制诊断信息'),
    # MR-20 workbench today, MR-21 账本
    'today.title': ('Today', '今日'),
    'today.redemptions': ('Redeemed today', '今日核销'),
    'today.income': ('Income today', '今日收入'),
    'today.pending': ('To handle', '待处理'),
    # verify-r1 1.6 / 2.8 (owner Q4): plain words, and 7-day numbers until the server has day-scoped counts
    'today.unknownReason': ('No data for today yet', '今天还没有数据'),
    'today.pendingCaption': ('orders need you', '笔订单等你处理'),
    'week.income': ('Income, last 7 days', '近 7 天收入'),
    'week.average': ('Daily average, last 7 days', '近 7 天日均'),
    'ledger.cumulative': ('Total income', '累计收入'),
    'ledger.view.label': ('Ledger view', '账本视图'),
    'ledger.view.redemptions': ('Redemptions', '核销'),
    'ledger.view.settlements': ('Settlements', '结算'),
    # MR-07 signing and MR-38 withdrawal hand-offs (owner Q-A: keep them, name them, show the next step)
    'signing.title': ('Signing happens in WeChat', '签约在微信中完成'),
    'signing.line': ('The payment provider\'s signing page only opens inside WeChat.', '收款服务商的签约页面只能在微信里打开。'),
    'signing.step1': ('Copy the signing link below', '复制下方的签约链接'),
    'signing.step2': ('Open WeChat, paste it into any chat and tap it', '打开微信，把链接发到任意聊天并点开'),
    'signing.step3': ('Follow the page to finish signing', '按页面提示完成签约'),
    'signing.after': ('When signing is done, pull down here to see the new status.', '签约完成后，回到这里下拉刷新即可看到新状态。'),
    'signing.openWeChat': ('Open WeChat', '打开微信'),
    'withdraw.title': ('Withdrawals are handled by platform support', '提现由平台客服办理'),
    'withdraw.line': ('The app does not pay out by itself. Support checks the amount and pays it to your verified account.', 'App 不会直接打款。客服核对金额后，打到你已核验的收款账户。'),
    'withdraw.step1': ('Tap the button below to contact support', '点下方按钮联系客服'),
    'withdraw.step2': ('Send your shop name and the amount to withdraw', '发送店铺名称和要提现的金额'),
    'withdraw.after': ('Support replies within 1 working day.', '客服 1 个工作日内回复。'),
    # Money stays TEST-only until the owner says "money on"
    'money.testOnly': ('Test build only', '仅测试环境'),
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
