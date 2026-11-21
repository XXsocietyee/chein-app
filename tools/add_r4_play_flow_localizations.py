#!/usr/bin/env python3
"""ui/r4-play-flow strings: the play HUD (401:4731) and the in-place 结算 rating result (204:15096)."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

S = {
    'playHUD.next': ('Next stop', '下一站'),
    'playHUD.hint': ('Hint', '提示'),
    'playHUD.backpack': ('Backpack', '背包'),
    'mp.settle.rate.submitting': ('Submitting', '正在提交'),
    'mp.settle.rate.submitted': ('Submitted', '已提交'),
    'homeFeed.feedFailed': ("Couldn't load the home page.", '首页加载失败'),
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
    print(f'{len(S)} r4 play-flow strings written')


if __name__ == '__main__':
    main()
