#!/usr/bin/env python3
"""Adds the mini-program drift (ui/mpdrift) strings to Resources/Localizable.xcstrings. Idempotent."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = {
    # Settings: AI chat records (OFF-AI-DEL-01)
    'mpd.aiChat.title': ('AI chat records', 'AI 对话记录'),
    'mpd.aiChat.export': ('Export my chat records', '导出我的对话记录'),
    'mpd.aiChat.exportHint': ('Copies the loaded records as text.', '把已加载的对话记录复制为文字。'),
    'mpd.aiChat.exportTitle': ('Chein · My AI chat records', '城瘾 · 我的 AI 对话记录'),
    'mpd.aiChat.exportCount %lld': ('%lld in total', '共 %lld 条'),
    'mpd.aiChat.exportRetention %@': ('Retention: %@', '保留说明：%@'),
    'mpd.aiChat.exportMe %@': ('Me: %@', '我：%@'),
    'mpd.aiChat.exportAI %@': ('AI: %@', 'AI：%@'),
    'mpd.aiChat.exportNoContent': ('(no content)', '（无内容）'),
    'mpd.aiChat.exportNoReply': ('(no reply)', '（没有回复）'),
    # AIGC disclosure
    'mpd.aigc.label': ('AI-generated', 'AI 生成'),
    'mpd.aigc.filing %@': ('Generative AI filing: %@', '生成式 AI 备案号：%@'),
    # Chapters (切换章节)
    'mpd.chapters.switch': ('Switch chapter', '切换章节'),
    'mpd.chapters.title': ('Choose a chapter', '选择章节'),
    'mpd.chapters.all': ('All chapters', '全部章节'),
    'mpd.chapters.allSub %lld': ('%lld places', '%lld 处地点'),
    'mpd.chapters.number %lld': ('Chapter %lld', '第 %lld 章'),
    'mpd.chapters.openSub %lld': ('%lld places', '%lld 处地点'),
    'mpd.chapters.completedSub %lld': ('Completed · %lld places', '已完成 · %lld 处地点'),
    'mpd.chapters.lockedSub %lld': ('Locked · %lld places', '未解锁 · %lld 处地点'),
    'mpd.chapters.state.open': ('Open', '可进行'),
    'mpd.chapters.state.completed': ('Completed', '已完成'),
    'mpd.chapters.state.locked': ('Locked', '未解锁'),
    'mpd.tools.title': ('Play tools', '游玩工具'),
    'mpd.mode.cityOrientation': ('City orienteering', '城市定向'),
    # Common
    'mpd.common.loading': ('Loading…', '正在加载…'),
    'mpd.common.retry': ('Retry', '重试'),
    # D20
    'mpd.dice.tier.easy': ('Easy', '简单'),
    'mpd.dice.tier.medium': ('Standard', '标准'),
    'mpd.dice.tier.hard': ('Hard', '困难'),
    'mpd.dice.tier.a11y %@': ('Difficulty %@', '难度 %@'),
    'mpd.dice.hold.idle': ('Hold to shake, release to roll', '按住摇骰，松手掷出'),
    'mpd.dice.hold.release': ('Shaking… release to roll', '摇……松手掷出'),
    'mpd.dice.hold.rolling': ('The die is rolling', '骰子在转'),
    'mpd.dice.hold.a11y': ('Roll', '掷骰'),
    # IM
    'mpd.im.inviteReminder': ('Invite alerts', '邀约提醒'),
    'mpd.im.inviteReminder.on': ('Invite alerts on', '已开启邀约提醒'),
    'mpd.im.inviteReminder.denied': ('Invite alerts not turned on', '未开启邀约提醒'),
    'mpd.im.inviteReminder.unknown': ('—', '—'),
    'mpd.im.inviteReminder.unknownLabel': ('Invite alert status unknown', '邀约提醒状态未知'),
    'mpd.im.reportUnread %lld': ('%lld new updates', '%lld 条新进度'),
    'mpd.review.task': ('Review task', '审核任务'),
    'mpd.review.business': ('Business', '业务'),
    'mpd.review.current': ('Current review record', '当前审核记录'),
    'mpd.review.loading': ('Reading the current review record…', '正在读取当前审核记录…'),
    'mpd.review.failed': ('The review record did not load', '审核记录没有加载'),
    'mpd.review.status': ('Current review status', '当前审核状态'),
    # Looks
    'mpd.look.style.stardust': ('Stardust', '星尘'),
    'mpd.look.style.paper': ('Paper', '纸本'),
    'mpd.look.style.survival': ('Wasteland', '末世'),
    'mpd.look.style.cyber': ('Night city', '夜城'),
    'mpd.look.palette.default': ('Black', '黑'),
    'mpd.look.palette.blue': ('Blue', '蓝'),
    'mpd.look.palette.red': ('Red', '红'),
    'mpd.look.palette.yellow': ('Yellow', '黄'),
    'mpd.look.palette.white': ('White', '白'),
    # Post dispositions & appeal
    'mpd.postGov.title': ('Post actions & appeals', '帖文处置与申诉'),
    'mpd.postGov.intro': ('An action taken before review isn\'t final decision.', '复核前的处置不是最终结论'),
    'mpd.postGov.signedOut': ('Sign in to see action records', '登录后查看处置记录'),
    'mpd.postGov.loadFailed': ('Action records could not be loaded', '处置记录暂未取回'),
    'mpd.postGov.refreshFailed': ('More action records could not be loaded', '更多处置记录暂未取回'),
    'mpd.postGov.empty': ('No action records.', '暂无处置记录。'),
    'mpd.postGov.more': ('Load more', '加载更多'),
    'mpd.postGov.appeal': ('Submit appeal', '提交申诉'),
    'mpd.postGov.reasonPlaceholder': ('Write the reason for your appeal (text only)', '写下申诉理由（仅文字）'),
    'mpd.postGov.submit': ('Submit', '提交'),
    'mpd.postGov.submitting': ('Submitting…', '提交中…'),
    'mpd.postGov.submitted': ('Appeal submitted', '申诉已提交'),
    'mpd.postGov.submitFailed': ('The appeal was not submitted. Try again.', '申诉没有提交成功，请重试'),
    'mpd.postGov.unknown': ('The last appeal result is unconfirmed. You can submit again (it will not be duplicated).', '上次申诉的提交结果未确认，可以再次提交（不会重复提交）'),
    'mpd.postGov.reasonRequired': ('Please write a reason for the appeal', '请写下申诉理由'),
    'mpd.postGov.signInFirst': ('Please sign in before appealing', '请先登录后再申诉'),
    'mpd.postGov.liveDisabled': ('Appeals are not open yet.', '申诉暂未开放。'),
    'mpd.postGov.target.post': ('Post action', '帖文处置'),
    'mpd.postGov.target.account': ('Account action', '账号处置'),
    'mpd.postGov.until %@': ('until %@', '至 %@'),
    'mpd.postGov.decision %@': ('Review note: %@', '复核说明：%@'),
    'mpd.postGov.state.reversed': ('Action reversed', '已撤销处置'),
    'mpd.postGov.state.upheld': ('Action upheld', '维持处置'),
    'mpd.postGov.state.appealing': ('Appeal in progress', '申诉处理中'),
    'mpd.postGov.state.active': ('Action in effect', '处置生效中'),
    'mpd.postGov.state.expired': ('Action expired', '处置已到期'),
    'mpd.postGov.state.unknown': ('Status pending', '状态待确认'),
    'mpd.postGov.note.reversed': ('The original action was reversed after the appeal review', '申诉复核后原处置已撤销'),
    'mpd.postGov.note.upheld': ('The original action was upheld after the appeal review', '申诉复核后维持原处置'),
    'mpd.postGov.note.appealing': ('Not a final decision until the review is complete', '复核完成前不是最终结论'),
    'mpd.postGov.note.active': ('Not yet reviewed on appeal; not a final decision', '尚未经过申诉复核，不是最终结论'),
    'mpd.postGov.type.LABEL': ('Content labeled', '内容加标注'),
    'mpd.postGov.type.DOWNRANK': ('Fewer recommendations', '降低推荐'),
    'mpd.postGov.type.SEARCH_EXCLUDE': ('Hidden from search', '不出现在搜索中'),
    'mpd.postGov.type.INTERACTION_LIMIT': ('Interactions limited', '限制互动'),
    'mpd.postGov.type.HIDE_PENDING_REVIEW': ('Hidden pending review', '隐藏待复核'),
    'mpd.postGov.type.REMOVE': ('Content removed', '移除内容'),
    'mpd.postGov.type.WARNING': ('Warning', '警告'),
    'mpd.postGov.type.POST_RATE_LIMIT': ('Posting rate limited', '限制发帖频率'),
    'mpd.postGov.type.COMMENT_TIMEOUT': ('Comments paused', '暂停评论'),
    'mpd.postGov.type.READ_ONLY': ('Account read-only', '账号只读'),
    'mpd.postGov.type.TEMP_SUSPEND': ('Temporarily suspended', '临时停用'),
    'mpd.postGov.type.PERMANENT_BAN': ('Permanently suspended', '永久停用'),
    'mpd.postGov.type.OTHER': ('Action', '处置'),
    # Emergency help (T-37)
    'mpd.sos.title': ('Emergency help', '紧急求助'),
    'mpd.sos.call %@': ('Call %@', '拨打 %@'),
    'mpd.sos.copyLocation': ('Copy my location', '复制我的位置'),
    'mpd.sos.copied': ('Location copied. Paste it to anyone.', '位置已复制，可以粘贴给任何人'),
    'mpd.sos.noLocation': ('Could not get your location', '没有取到位置'),
    'mpd.sos.footer': ('Calls open the system dialer to confirm. Your location is read once, only when you tap.', '拨号会先打开系统拨号确认。位置只在你点按时读取一次。'),
    'mpd.sos.locationText %@ %@': ('I need help. My location: latitude %1$@, longitude %2$@', '我需要帮助，我的位置：纬度 %1$@，经度 %2$@'),
    # Replay
    'mpd.replay.title': ('Play again', '再玩一次'),
    'mpd.replay.busy': ('Starting a new run', '正在开启新一局'),
    'mpd.replay.unconfirmed': ('Not confirmed yet. Check your records before trying again.', '新一局还未确认，请先查看记录再重试'),
    # Title card
    'mpd.titleCard.brand': ('Chein', '城瘾'),
    'mpd.titleCard.start': ('Start game', '开始游戏'),
}


# en-layout r3: English count strings vary by plural; the S value is the `other` form.
EN_ONE = {
    'mpd.chapters.allSub %lld': '%lld place',
    'mpd.chapters.openSub %lld': '%lld place',
    'mpd.chapters.completedSub %lld': 'Completed · %lld place',
    'mpd.chapters.lockedSub %lld': 'Locked · %lld place',
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def english(key, en):
    if key in EN_ONE:
        return {'variations': {'plural': {'one': unit(EN_ONE[key]), 'other': unit(en)}}}
    return unit(en)


def main():
    path = ROOT / 'Resources/Localizable.xcstrings'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in S.items():
        strings[key] = {'extractionState': 'manual', 'localizations': {'en': english(key, en), 'zh-Hans': unit(zh)}}
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(S)} mpd strings written')


if __name__ == '__main__':
    main()
