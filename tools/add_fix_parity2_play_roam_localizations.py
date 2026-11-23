#!/usr/bin/env python3
"""fix/parity2-play-roam strings (audit docs/audit/parity/play-roam.md). Idempotent: re-running rewrites the same values."""
import json
import pathlib

ROOT = pathlib.Path(__file__).resolve().parents[1]

# key: (en, zh-Hans)
S = {
    # RCODE-2
    'roamSub.w208.voucher.network': ('Network error. Try again later.', '网络异常，请稍后重试'),
    'roamSub.w208.voucher.retry': ('Retry', '重试'),
    # RROUTE-3 / RROUTES-2: route copy into the catalog (noun 路线 kept until the owner glossary rules 线路/路线)
    'officialRoute.badge': ('Official route', '官方路线'),
    'officialRoute.openFirstStop': ('Open first stop in Maps', '在地图中打开起点'),
    'officialRoute.stat.duration': ('Duration', '用时'),
    'officialRoute.stat.distance': ('Distance', '距离'),
    'officialRoute.stat.stops': ('Stops', '站点'),
    # JSEAT-7
    'mp.seats.unconfirmed': ('The result is not confirmed yet. Check again later.', '结果还没确认，请稍后查询'),
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
    print(f'{len(S)} parity2 play-roam strings written')


if __name__ == '__main__':
    main()
