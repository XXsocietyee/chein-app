#!/usr/bin/env python3
"""i18n r1 gate for the English (US) launch.

Fails when:
  1. any English value in a string catalog contains CJK characters;
  2. any catalog key has no English value (unless marked shouldTranslate: false);
  3. an App/ Swift file gains hard-coded CJK string literals beyond its ratchet
     baseline (tools/l10n_cjk_literal_baseline.json). Merchant code, design
     fixtures, previews and comments are out of scope. A CJK literal that is
     itself a catalog key with a proper English value counts as localized.

Usage:
  python3 tools/check_l10n.py              # check
  python3 tools/check_l10n.py --update     # rewrite the baseline (only lowers or
                                           # drops entries unless --allow-raise)
  python3 tools/check_l10n.py --report     # per-file counts, highest first
"""
import json
import os
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'tools/l10n_cjk_literal_baseline.json'
CATALOG_DIRS = ['Resources', 'LiveActivityWidget']
CJK = re.compile(r'[　-〿㐀-䶿一-鿿豈-﫿＀-￯]')
LITERAL = re.compile(r'"((?:[^"\\\n]|\\.)*)"')
FORMAT = re.compile(r'%(?:\d+\$)?(?:@|lld|ld|d|lf|f|llu|lu|u)')
LATIN = re.compile(r'[A-Za-z]{2}')


def normalize_key(text):
    """Catalog key with its format specifiers collapsed, so `Text("个 \\(n)")` matches `个 %lld`."""
    return FORMAT.sub('\x00', text)


def normalize_literal(text):
    out, i = [], 0
    while i < len(text):
        if text.startswith('\\(', i):
            depth, i = 1, i + 2
            while i < len(text) and depth:
                depth += {'(': 1, ')': -1}.get(text[i], 0)
                i += 1
            out.append('\x00')
        else:
            out.append(text[i])
            i += 1
    return ''.join(out)


def catalogs():
    for d in CATALOG_DIRS:
        for p in sorted((ROOT / d).glob('*.xcstrings')):
            yield p


def unit_values(loc):
    if not isinstance(loc, dict):
        return []
    out = []
    su = loc.get('stringUnit')
    if su is not None:
        out.append(su.get('value', ''))
    for cases in (loc.get('variations') or {}).values():
        for case in cases.values():
            out += unit_values(case)
    for sub in (loc.get('substitutions') or {}).values():
        out += unit_values(sub)
    return out


def check_catalogs():
    errors, localized_keys = [], set()
    for path in catalogs():
        rel = path.relative_to(ROOT)
        data = json.loads(path.read_text(encoding='utf-8'))
        source = data.get('sourceLanguage', 'en')
        for key, entry in data.get('strings', {}).items():
            if entry.get('shouldTranslate') is False:
                localized_keys.add(key)
                continue
            en = (entry.get('localizations') or {}).get('en')
            values = unit_values(en)
            if not values and source == 'en' and not CJK.search(key):
                # Source-language key without an explicit en unit: the key is the English text.
                values = [key]
            if not values or not all(v.strip() for v in values):
                errors.append(f'{rel}: missing en value for {key!r}')
                continue
            bad = [v for v in values if CJK.search(v)]
            if bad:
                errors.append(f'{rel}: CJK in en value for {key!r}: {bad[0][:80]!r}')
            else:
                localized_keys.add(key)
                localized_keys.add(normalize_key(key))
    return errors, localized_keys


def out_of_scope(rel):
    parts = rel.split('/')
    name = parts[-1]
    return ('erchant' in rel or 'DesignFixtures' in parts or 'Fixture' in name
            or 'Preview' in name or name.endswith('Previews.swift'))


MAPPED = re.compile(r'"((?:[^"\\\n]|\\.)*)"\s*:\s*"([A-Za-z][A-Za-z0-9_.]*)"')


def mapped_literals(localized_keys):
    """CJK lookup tokens the app maps to a catalog key, e.g. `"生命值": "zeroHP.copy.017"` (i18n r2).

    Such a token is never shown as is: the view resolves it through the key, so the token
    counts as localized wherever it appears in App/.
    """
    tokens = set()
    for path in sorted((ROOT / 'App').rglob('*.swift')):
        for m in MAPPED.finditer(path.read_text(encoding='utf-8')):
            if CJK.search(m.group(1)) and m.group(2) in localized_keys:
                tokens.add(m.group(1))
    return tokens


def literal_counts(localized_keys):
    counts = {}
    localized_keys = set(localized_keys) | mapped_literals(localized_keys)
    for path in sorted((ROOT / 'App').rglob('*.swift')):
        rel = str(path.relative_to(ROOT))
        if out_of_scope(rel):
            continue
        n = 0
        in_preview = False
        for line in path.read_text(encoding='utf-8').split('\n'):
            stripped = line.strip()
            if stripped.startswith('#Preview'):
                in_preview = True
            if in_preview:
                continue
            if stripped.startswith(('//', '*', '/*')):
                continue
            for m in LITERAL.finditer(line):
                text = m.group(1)
                if not CJK.search(text):
                    continue
                comment = line.find('//')
                if comment != -1 and comment < m.start() and line[:comment].count('"') % 2 == 0:
                    continue
                if text in localized_keys or normalize_literal(text) in localized_keys:
                    continue
                # Inline bilingual pair such as W8Text.t("中文", "English") or c("English", "中文"),
                # or a translation-table entry "中文": "English" (i18n r2).
                after = re.match(r'\s*[,:]\s*"((?:[^"\\\n]|\\.)*)"', line[m.end():])
                before = re.search(r'"((?:[^"\\\n]|\\.)*)"\s*,\s*$', line[:m.start()])
                if any(x and LATIN.search(x.group(1)) and not CJK.search(x.group(1)) for x in (after, before)):
                    continue
                n += 1
        if n:
            counts[rel] = n
    return counts


def main(argv):
    errors, localized_keys = check_catalogs()
    counts = literal_counts(localized_keys)
    if '--report' in argv:
        for rel, n in sorted(counts.items(), key=lambda kv: -kv[1]):
            print(n, rel)
        print('TOTAL', sum(counts.values()), 'in', len(counts), 'files')
        return 0
    baseline = json.loads(BASELINE.read_text()) if BASELINE.exists() else {}
    if '--update' in argv:
        allow = '--allow-raise' in argv
        new = {k: (v if allow else min(v, baseline.get(k, v if not baseline else 0)))
               for k, v in counts.items()}
        new = {k: v for k, v in sorted(new.items()) if v}
        BASELINE.write_text(json.dumps(new, indent=1, ensure_ascii=False) + '\n')
        print(f'baseline: {sum(new.values())} literals in {len(new)} files')
        return 0
    for rel, n in sorted(counts.items()):
        allowed = baseline.get(rel, 0)
        if n > allowed:
            errors.append(f'{rel}: {n} hard-coded CJK literals (baseline {allowed}); '
                          'move UI text into Localizable.xcstrings with zh-Hans + en')
    lowered = sum(1 for rel, n in baseline.items() if counts.get(rel, 0) < n)
    if errors:
        for e in errors:
            print('FAIL', e)
        print(f'FAIL l10n: {len(errors)} problem(s)')
        return 1
    print(f'PASS l10n: 0 CJK en values, 0 missing en; {sum(counts.values())} baselined CJK literals '
          f'in {len(counts)} App files (baseline {sum(baseline.values())}'
          + (f'; {lowered} file(s) below baseline, run --update to ratchet down' if lowered else '') + ')')
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
