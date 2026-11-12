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
    # C44/C45 pages/club/detail: source PUBLIC_TABS label is 帖文
    'club.detail.tab.posts': ('Posts', '帖文'),
    # C47-C49 pages/club/enroll sub line
    'u9cde.clubEnroll.subLine %@ %lld': ('%1$@ · %2$lld groups', '%1$@ · %2$lld 个团'),
    'u9cde.clubEnroll.subLineMine %lld': ('My club · %lld groups', '我的俱乐部 · %lld 个团'),
    'u9cde.clubEnroll.signups %lld': ('%lld registered', '已报名 %lld 人'),
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
