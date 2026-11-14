#!/usr/bin/env python3
"""Fail when a user-facing string key used in App/ or Core/ is missing.

A lookup is the same call the catalog coverage gate already treats as a key
(Text, String(localized:), LocalizedStringKey, and the other catalog calls),
plus String.LocalizationValue(stringLiteral:) when the literal is a whole key.
The key must exist in the catalog that call reads, with a non-empty translated
en value and a non-empty translated zh-Hans value.

Dynamic prefixes (a literal ending in "." or "_") are not guessed. Fixture,
harness, preview, sample, stub, demo, and mock Swift files are skipped.
This does not run Xcode or export strings.

usage: python3 -B tools/check_missing_string_keys.py
exit 1 when missing is not 0. The last line is: missing: N
"""
import glob
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import localization_usage_audit as audit
import check_catalog_coverage as cov

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = ('en', 'zh-Hans')


def entry_gap(entry, lang):
    """None when lang is translated and non-blank. Otherwise a short reason."""
    if not isinstance(entry, dict) or entry.get('shouldTranslate') is False:
        return None
    wrapped = (entry.get('localizations') or {}).get(lang)
    if not isinstance(wrapped, dict):
        return 'missing'
    units = list(cov.string_units(wrapped))
    if not units:
        return 'missing-value'
    for state, value in units:
        if state != 'translated':
            return state or 'missing-state'
        if not isinstance(value, str) or not value.strip():
            return 'blank'
    return None


def whole_key(literal):
    text = literal.text
    if not text or literal.interp or audit.CJKH.search(text):
        return None
    if text.endswith('.') or text.endswith('_'):
        return None
    if not audit._is_key_shaped(text):
        return None
    return text


def string_literal_key(literal):
    """A complete key passed as String.LocalizationValue(stringLiteral:)."""
    if not literal.stack or any(frame[0] == '<interp>' for frame in literal.stack):
        return None
    if getattr(literal, 'label', None) != 'stringLiteral':
        return None
    if literal.stack[-1][0] != 'LocalizationValue':
        return None
    return whole_key(literal)


def scan(root=ROOT):
    tables = cov.load_tables(root)
    missing = []
    wrong_table = []
    incomplete = []
    seen = set()
    for base in ('App', 'Core'):
        paths = sorted(glob.glob(os.path.join(root, base, '**', '*.swift'), recursive=True))
        for path in paths:
            if audit.FIXTURE_FILE.search(os.path.basename(path)):
                continue
            with open(path, encoding='utf-8', errors='replace') as handle:
                source = handle.read()
            names = cov.constants(source)
            relative = os.path.relpath(path, root)
            for literal in audit.lex(relative, source):
                lookups = []
                if cov.is_lookup(literal):
                    pattern = cov.key_pattern(literal)
                    if pattern is not None:
                        lookups.append((pattern, literal.interp))
                literal_key = string_literal_key(literal)
                if literal_key is not None:
                    lookups.append((literal_key, False))
                if not lookups:
                    continue
                table = cov.resolved_table(literal, source, names)
                if table is None:
                    continue
                for pattern, interpolated in lookups:
                    identity = (relative, literal.line, table, cov.normalized_key(pattern))
                    if identity in seen:
                        continue
                    seen.add(identity)
                    owners = cov.owners_of(tables, pattern, interpolated)
                    in_table = [key for owner, key in owners if owner == table]
                    shown = pattern.replace('\x00', '%@')
                    if not in_table:
                        if owners:
                            wrong_table.append((relative, literal.line, table, shown,
                                                ','.join(sorted({owner for owner, _ in owners}))))
                        else:
                            missing.append((table, shown, relative, literal.line))
                        continue
                    for key in in_table:
                        entry = tables[table][key]
                        for lang in LOCALES:
                            reason = entry_gap(entry, lang)
                            if reason:
                                incomplete.append((table, key, lang, reason, relative, literal.line))
    return {
        'missing_keys': cov.unique(missing),
        'wrong_table': cov.unique(wrong_table),
        'incomplete_locales': cov.unique(incomplete),
    }


def main():
    found = scan()
    order = ('missing_keys', 'wrong_table', 'incomplete_locales')
    total = 0
    for kind in order:
        rows = found[kind]
        total += len(rows)
        print(f'{kind}: {len(rows)}')
        for row in rows[:50]:
            print('  ', *row)
    print(f'missing: {total}')
    return 1 if total else 0


if __name__ == '__main__':
    sys.exit(main())
