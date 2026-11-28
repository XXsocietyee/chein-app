#!/usr/bin/env python3
"""fix/parity2-player-content: strings for the round-2 player-content parity fixes. Idempotent."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

S = {
    # PC-B-1-3: MP topic-motion buildHeroCta kind 'closed'.
    'topicXcx.cta.closed': ('Closed', '已截止'),
    # PC-C-3-2: MP official list refresh line.
    'official.refreshing': ('Updating…', '正在更新活动列表…'),
    # PC-C-7-3: MP official-organizer oo-sync line.
    'official.organizer.refreshing': ('Reading the latest platform record…', '正在读取平台最新记录…'),
    # PC-C-1-3: MP scene-play-activity-detail noTicketText.
    'activity.cta.noSelectableTicket': ('No tickets available', '暂无可报名票种'),
    'activity.cta.noTicketOpen': ('Tickets not open yet', '暂未开放票种'),
    # PC-D-7-1: video bounty signed-out gate.
    'mp.vb.signedOut': ('Sign in to see your video submissions and rewards', '登录后查看你的视频投稿与奖励'),
    # PC-B-1-15: MP topic paywall recovery link.
    'topicXcx.paywall.purchased': ('Already bought?', '已购？去票夹'),
    # PC-D-5-3: MP scene-asset-earnings balance label.
    'wallet.earnings.balance': ('Account earnings', '账户收益'),
    # PC-D-1-4: visible row menu.
    'myProject.more': ('More', '项目操作'),
    # PC-A-7-3: MP topic-detail CTA, disabled with a reason while the copy write is gated.
    'topicTemplate.useCta': ('Use this template', '用这个模板'),
    'topicTemplate.useUnavailable': ('Copying a template isn\'t available in version yet.', '当前版本暂未开放复制模板'),
    # PC-D-5-4: MP scene-asset-earnings empty CTA.
    'wallet.earnings.goPublish': ('Publish a route', '去发布路线'),
    # PC-C-1-4: MP host label for shop-hosted activities.
    'activity.people.organizerShop': ('Organizer', '主办方'),
    # PC-B-1-7: MP topic route walkText.
    'topicXcx.route.straightLine %@': ('About %@ straight', '直线约 %@'),
    'official.refreshFailed': ("Couldn't refresh. Try again later.", '刷新失败，稍后再试'),
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
    print(f'{len(S)} fix-parity2-player-content strings written')


if __name__ == '__main__':
    main()
