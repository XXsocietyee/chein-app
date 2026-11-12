#!/usr/bin/env python3
"""Adds the U9 domain C/D/E screenshot-parity strings to Resources/Localizable.xcstrings. Idempotent."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = {
    # C23-C25 pages/topic/index
    'u9cde.topic.coverDetails': ('View details and sign up', '查看详情与报名'),
    'u9cde.topic.routeNote.fixed': ('Fixed route', '固定路线'),
    'u9cde.topic.routeNote.free': ('No fixed route', '没有固定路线'),
    'u9cde.topic.routeConfiguring': ('Route being set up', '路线配置中'),
    # C47-C49 pages/club/enroll sub line
    'u9cde.clubEnroll.subLine %@ %lld': ('%1$@ · %2$lld groups', '%1$@ · %2$lld 个团'),
    'u9cde.clubEnroll.subLineMine %lld': ('My club · %lld groups', '我的俱乐部 · %lld 个团'),
    'u9cde.clubEnroll.signups %lld': ('%lld registered', '已报名 %lld 人'),
    # D01-D05 subpackageMember/order
    'u9cde.orders.payable': ('Due:', '待付款：'),
    # D12b-D12k invoice signed-out states
    'u9cde.invoice.login.view': ('Sign in to view invoices', '登录后查看发票'),
    'u9cde.invoice.login.apply': ('Sign in to request an invoice', '登录后申请开票'),
    'u9cde.invoice.login.titles': ('Sign in to manage invoice titles', '登录后管理发票抬头'),
    # D17/D18/E27 subpackageMember/coupon-qr
    'u9cde.coupon.autoRefresh %@': ('Code refreshes in %@s', '二维码 %@s 后自动刷新'),
    'u9cde.coupon.failed': ("Couldn't generate the QR code. Try again later.", '二维码暂时没能生成，请稍后重试'),
    'u9cde.coupon.used': ('Redeemed', '已核销'),
    # D23 subpackageMember/myinvite
    'u9cde.invite.points %@': ('+%@ points', '+%@ 积分'),
    # D90 subpackageMember/points-history filter chips
    'u9cde.points.earned': ('Earned', '获得'),
    'u9cde.points.used': ('Used', '使用'),
    # D91 subpackageMember/report-mine
    'u9cde.report.number %@': ('No. %@', '编号 %@'),
    'u9cde.report.end': ("That's everything", '已经到底了'),
    # D92 subpackageMember/report-detail
    'u9cde.report.submittedAt': ('Submitted', '提交于'),
    'u9cde.report.decision': ('Decision', '处理结论'),
    'u9cde.report.yourNote': ('Your report note', '你的举报说明'),
    'u9cde.report.progress': ('Progress', '处理进度'),
    'u9cde.report.progressEmpty': ('No progress records yet', '暂时还没有进度记录'),
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
    print(f'{len(S)} u9cde strings written')


if __name__ == '__main__':
    main()
