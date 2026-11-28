#!/usr/bin/env python3
"""Adds the u10-screens strings (B03/B04/B57/B62/B63/B68/B78 and the B01/B63 voice-pass rows) to
Resources/Localizable.xcstrings, copy taken from the mini-program zh source. Idempotent."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
S = {
    # B03 pages/roam/index intro-permission
    'u10.roam.permission.title': ('Location is needed to start roaming', '需要定位才能开始漫游'),
    'u10.roam.permission.sub': ("Location is off, so roaming can't see where you are", '定位没打开，漫游看不到你在哪'),
    'u10.roam.permission.settings': ('Go Settings', '去设置'),
    # B04 pages/roam/index settle (finish report)
    'u10.roamFinish.zoneFallback': ('This area', '这片街区'),
    'u10.roamFinish.title %@': ('%@ · Free roam', '%@ · 自由漫游'),
    'u10.roamFinish.today %@': ('Today · %@', '今天 · %@'),
    'u10.roamFinish.close': ('Close report', '关闭结算页'),
    'u10.roamFinish.shops': ('shops', '家探店'),
    'u10.roamFinish.explore': ('Explored', '探索度'),
    'u10.roamFinish.stamps': ('Stamps', '邮票'),
    'u10.roamFinish.xp': ('Exploration', '探索值'),
    'u10.roamFinish.medals': ('Medals', '勋章 (枚)'),
    'u10.roamFinish.story': ('This walk', '这段足迹'),
    'u10.roamFinish.noTrack': ('No route was recorded this time', '这次没有记录到轨迹'),
    'u10.roamFinish.data': ('View roam data', '查看漫游数据'),
    'u10.roamFinish.share': ('Share', '分享'),
    'u10.roamFinish.shareLabel': ('Share footprint card', '分享足迹卡'),
    'u10.roamFinish.history': ('Roam records', '漫游记录'),
    # B57 / B78 pages/templatedetail + topic-detail
    'u10.template.tab.details': ('Details', '详情'),
    'u10.template.tab.capabilities': ('Skills', '能力'),
    'u10.template.share': ('Share play', '分享玩法'),
    'u10.template.shareTopic': ('Share route template', '分享主题模板'),
    'u10.template.cap.way': ('Method', '方式'),
    'u10.template.cap.scene': ('Scene', '场景'),
    'u10.template.cap.from': ('Source', '来源'),
    'u10.template.cap.preview': ('Node preview', '节点预览'),
    'u10.template.cap.expand': ('Expand', '展开'),
    'u10.template.cap.collapse': ('Collapse', '收起'),
    'u10.template.story': ('Story', '剧情'),
    'u10.template.nodes': ('Stops', '节点'),
    'u10.template.chapterNo %lld': ('Chapter %lld', '第 %lld 章'),
    'u10.template.stopNo %lld': ('Stop %lld', '第 %lld 站'),
    'u10.template.nodeNo %lld': ('Stop %lld', '节点 %lld'),
    'u10.template.medal': ('Completion medal', '通关勋章'),
    'u10.template.medalHint': ('Lights up when every stop is done', '走完全部节点时点亮'),
    'u10.template.summary.city': ('City orienteering', '城市定向'),
    'u10.template.summary.free': ('Free exploration', '自由探索'),
    'u10.template.summary.multiDay': ('Can span days', '可以跨天'),
    'u10.template.summary.games %lld': ('%lld plays', '%lld 个玩法'),
    'u10.template.summary.stops %lld': ('%lld stops', '%lld 站'),
    # B62 收集册 album-head and stamp-album count
    'u10.album.title': ('Collection', '收集册'),
    'u10.album.medal': ('Medals', '勋章'),
    'u10.album.stamp': ('Stamps', '邮票'),
    'u10.album.object': ('Items', '藏品'),
    'u10.album.unit': ('pcs', '枚'),
    # B68 subpackageP3/pages/growthcenter
    'u10.growth.board': ('Total points', '总积分榜'),
    'u10.growth.boardRank %lld': ('Total points board · No. %lld', '总积分榜 · 第 %lld 名'),
    'u10.growth.unit.exp': ('EXP', '经验'),
    'u10.growth.unit.badge': ('pcs', '枚'),
    'u10.growth.unit.topic': ('ct', '个'),
    'u10.growth.badge.hint': ('See when you earned it', '查看获得时刻'),
    'u10.growth.badge.obtained %@': ('Earned %@', '获得于 %@'),
    'u10.growth.badge.noTime': ('Time not recorded', '获得时间未记录'),
    'u10.growth.badge.view': ('View', '查看'),
}

# Existing keys whose copy follows the mini-program text (u9-b B01 / B63 / B68 rows).
OVERRIDES = {
    # B01: tab and first card say 开始漫游 (voice pass had 走起).
    'roam.w208.tab.start': ('Start roaming', '开始漫游'),
    'roam.w208.intro.start': ('Start roaming', '开始漫游'),
    'roam.w208.recovery.recovered': ('We recovered your last walk. Tap Start roaming to keep exploring.', '已找回上一趟的记录，点“开始漫游”继续探索。'),
    # B63: stamp-album cy-empty title.
    'roam.experience.albumEmpty': ('No stamps yet', '还没有邮票'),
    # B68: gc-badge-empty heading; 累计距离 with the km unit beside the value.
    'growth.badges.empty': ('No badges lit up yet', '还没有点亮任何徽章'),
    'growth.mileage': ('Total distance', '累计距离'),
}


def unit(value):
    return {'stringUnit': {'state': 'translated', 'value': value}}


def main():
    path = ROOT / 'Resources/Localizable.xcstrings'
    catalog = json.loads(path.read_text(encoding='utf-8'))
    strings = catalog['strings']
    for key, (en, zh) in S.items():
        strings[key] = {'extractionState': 'manual', 'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}
    for key, (en, zh) in OVERRIDES.items():
        entry = strings[key]
        entry['localizations']['en'] = unit(en)
        entry['localizations']['zh-Hans'] = unit(zh)
    path.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    print(f'{len(S)} u10 strings written, {len(OVERRIDES)} updated')


if __name__ == '__main__':
    main()
