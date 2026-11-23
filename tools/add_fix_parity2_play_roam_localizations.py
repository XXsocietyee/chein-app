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
