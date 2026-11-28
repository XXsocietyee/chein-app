#!/usr/bin/env python3
"""English copy lint for Resources/*.xcstrings.

A catalog key fails when its English value is:

  missing   no non-blank en string (unless shouldTranslate is false)
  chinese   an en value still contains Han or other CJK characters
  long      an en value's layout length is more than 2.2 times the
            paired zh-Hans value's layout length

Layout length is the width a label uses: a wide character (Han, kana,
Hangul, fullwidth forms, emoji) counts as 2 and every other code point
counts as 1. Substitution fragments are part of the English value for
the missing and chinese checks. The length check compares each full
string (the locale stringUnit and each plural or device variation) with
the zh-Hans string at the same path, or with the only zh-Hans string
when Chinese has a single form.

usage: python3 -B tools/check_en_strings.py
exit 1 when problems is not 0. The last line is: problems: N
"""
import glob
import json
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CJK = re.compile(r'[　-〿㐀-䶿一-鿿豈-﫿＀-￯]')
RATIO = 2.2


def length(text):
    """Layout width. Wide characters count as 2."""
    total = 0
    for char in text or '':
        code = ord(char)
        if (
            0x1100 <= code <= 0x115F
            or 0x2329 <= code <= 0x232A
            or 0x2E80 <= code <= 0xA4CF
            or 0xAC00 <= code <= 0xD7A3
            or 0xF900 <= code <= 0xFAFF
            or 0xFE10 <= code <= 0xFE19
            or 0xFE30 <= code <= 0xFE6F
            or 0xFF00 <= code <= 0xFF60
            or 0xFFE0 <= code <= 0xFFE6
            or 0x1F300 <= code <= 0x1F64F
            or 0x1F900 <= code <= 0x1F9FF
            or 0x1FA70 <= code <= 0x1FAFF
            or 0x20000 <= code <= 0x3FFFD
        ):
            total += 2
        else:
            total += 1
    return total


def too_long(english, chinese):
    chinese_length = length(chinese)
    if chinese_length <= 0:
        return False
    return length(english) > RATIO * chinese_length


def _units(node, under_substitution=False):
    """Yield (is_fragment, stringUnit dict) in catalog order."""
    if not isinstance(node, dict):
        return
    unit = node.get('stringUnit')
    if isinstance(unit, dict) and 'value' in unit:
        yield under_substitution, unit
    variations = node.get('variations')
    if isinstance(variations, dict):
        for forms in variations.values():
            if isinstance(forms, dict):
                for child in forms.values():
                    yield from _units(child, under_substitution)
    substitutions = node.get('substitutions')
    if isinstance(substitutions, dict):
        for child in substitutions.values():
            yield from _units(child, True)


def _full_values(localization):
    return [unit.get('value') or '' for fragment, unit in _units(localization) if not fragment]


def _all_values(localization):
    return [unit.get('value') or '' for _, unit in _units(localization)]


def _pair_chinese(english_values, chinese_values):
    if len(chinese_values) == 1:
        return [chinese_values[0] for _ in english_values]
    paired = []
    for index, _ in enumerate(english_values):
        if index < len(chinese_values):
            paired.append(chinese_values[index])
        elif chinese_values:
            paired.append(chinese_values[-1])
        else:
            paired.append('')
    return paired


def scan(root=ROOT):
    """Return problem rows: (catalog, key, kind, detail)."""
    problems = []
    directory = os.path.join(root, 'Resources')
    for path in sorted(glob.glob(os.path.join(directory, '*.xcstrings'))):
        with open(path, encoding='utf-8') as handle:
            catalog = json.load(handle)
        name = os.path.basename(path)
        source = catalog.get('sourceLanguage', 'en')
        for key, entry in (catalog.get('strings') or {}).items():
            if not isinstance(entry, dict) or entry.get('shouldTranslate') is False:
                continue
            localizations = entry.get('localizations') or {}
            english = localizations.get('en')
            values = _all_values(english)
            # A source-language key with no localizations is itself the English
            # value. An explicit blank en unit, or Chinese with no en unit, is missing.
            if not any(isinstance(value, str) and value.strip() for value in values):
                key_is_english = (
                    not localizations and not isinstance(english, dict)
                    and source == 'en' and isinstance(key, str) and key.strip()
                    and not CJK.search(key)
                )
                if key_is_english:
                    values = [key]
                else:
                    problems.append((name, key, 'missing', 'no en value'))
                    continue
            chinese_hits = [value for value in values if isinstance(value, str) and CJK.search(value)]
            if chinese_hits:
                problems.append((name, key, 'chinese', chinese_hits[0][:80]))
            full_english = _full_values(english)
            full_chinese = _full_values(localizations.get('zh-Hans'))
            if not full_english and values == [key]:
                full_english = [key]
            for english_value, chinese_value in zip(full_english, _pair_chinese(full_english, full_chinese)):
                if not isinstance(english_value, str) or not isinstance(chinese_value, str):
                    continue
                if chinese_value and too_long(english_value, chinese_value):
                    problems.append((
                        name, key, 'long',
                        f'{length(english_value)}>{RATIO}*{length(chinese_value)} {english_value[:80]}',
                    ))
                    break
    return problems


def main():
    found = scan()
    counts = {kind: 0 for kind in ('missing', 'chinese', 'long')}
    for row in found:
        counts[row[2]] = counts.get(row[2], 0) + 1
    for kind in ('missing', 'chinese', 'long'):
        print(f'{kind}: {counts[kind]}')
        shown = 0
        for catalog, key, problem_kind, detail in found:
            if problem_kind != kind:
                continue
            print(f'  {catalog} {key}: {detail}')
            shown += 1
            if shown >= 40:
                break
    print(f'problems: {len(found)}')
    return 1 if found else 0


if __name__ == '__main__':
    sys.exit(main())
