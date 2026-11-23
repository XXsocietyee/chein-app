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
