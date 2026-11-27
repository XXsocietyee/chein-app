#!/usr/bin/env python3
"""i18n r2 (locale lane): English plural substitutions for multi-argument count strings.

r1 (`add_i18n_r1_plurals.py`) converted count strings with exactly one integer argument into
`variations.plural`. Strings with two or more arguments (`%1$lld of %2$lld days left`,
`Streak %lld days · %lld added by staff`) need Xcode string-catalog *substitutions*: the English
value becomes `%1$lld of %#@day@ left` and the counted noun varies by plural inside the
substitution (`%arg day` / `%arg days`). Chinese keeps its single stringUnit (no grammatical plural).

Rules (same spirit as r1): never `merchant.*`; the noun must directly follow an integer argument
and be a known plural noun; keys spelled in tools/, Tests/, Resources/*.json or a docs/ JSON other
than a docs/port/strings fragment that round-trips byte for byte stay plain (contract checks compare those values). When a
docs/port/strings fragment spells the key, its English entry is updated too, so a later fragment
merge does not revert the catalog. Idempotent.

Usage: python3 -B tools/add_i18n_r2_substitutions.py [--check]
  --check  exit 1 when a convertible multi-argument count string is still a plain stringUnit.
"""
import importlib.util
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Resources/Localizable.xcstrings'
FRAGMENTS = 'docs/port/strings/'

_spec = importlib.util.spec_from_file_location('i18n_r1_plurals', ROOT / 'tools/add_i18n_r1_plurals.py')
r1 = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(r1)

ARG = re.compile(r'%(?:(\d+)\$)?(lld|ld|li|d|i|@|f|\.\d+f|u|llu|lu)')
INT_SPECS = {'lld', 'ld', 'li', 'd', 'i'}
# Keys whose call site runs `String(format:)` on an already-resolved value: a `%#@name@` substitution
# would not survive that path, so they stay plain stringUnits.
FORMAT_KEYS = {'roam.share.square.copyDistance', 'roam.share.square.copy'}
SELF = ('tools/add_i18n_r2_substitutions.py', 'tools/add_i18n_r1_plurals.py')


def stable(name):
    """A fragment is rewritten only when json.dumps(indent=2) reproduces it byte for byte (no churn);
    keys in any other fragment stay pinned."""
    try:
        text = (ROOT / name).read_text(encoding='utf-8')
        return json.dumps(json.loads(text), indent=2, ensure_ascii=False) + '\n' == text
    except (UnicodeDecodeError, OSError, ValueError):
        return False


def tracked_texts():
    files = subprocess.run(['git', 'ls-files', '--', 'tools', 'Tests', 'docs', 'Resources/*.json'],
                           cwd=ROOT, capture_output=True, text=True).stdout.split()
    pinned_blob, fragment_files = [], []
    for name in files:
        if name in SELF or not name.endswith(('.py', '.json', '.swift', '.txt', '.xcstrings', '.md')):
            continue
        if name.startswith(FRAGMENTS) and name.endswith('.json') and stable(name):
            fragment_files.append(name)
            continue
        if name.startswith('docs/') and name.endswith('.md'):
            continue  # receipts and briefs only mention keys; they do not compare values
        try:
            pinned_blob.append((ROOT / name).read_text(encoding='utf-8'))
        except (UnicodeDecodeError, OSError):
            continue
    return '\n'.join(pinned_blob), fragment_files


def plan(value):
    """Returns (new English value, substitutions) or None."""
    args = list(ARG.finditer(value))
    if len(args) < 2:
        return None
    numbers, sequential = [], 0
    for match in args:
        sequential += 1
        numbers.append(int(match.group(1)) if match.group(1) else sequential)
    nouns = {}
    for match in r1.INT_NOUN.finditer(value):
        noun = match.group(3)
        if noun.lower() not in r1.SINGULAR:
            continue
        index = next(i for i, arg in enumerate(args) if arg.start() == match.start(1))
        nouns[index] = match
    if not nouns:
        return None
    pieces, cursor, substitutions = [], 0, {}
    for index, arg in enumerate(args):
        number, spec = numbers[index], arg.group(2)
        if index in nouns:
            match = nouns[index]
            noun = match.group(3)
            singular = r1.SINGULAR[noun.lower()]
            if noun[0].isupper():
                singular = singular[0].upper() + singular[1:]
            name = re.sub(r'[^A-Za-z0-9]', '', singular.lower()) or 'count'
            while name in substitutions:
                name += str(number)
            pieces.append(value[cursor:arg.start()])
            pieces.append('%#@' + name + '@')
            cursor = match.end(3)
            substitutions[name] = {
                'argNum': number,
                'formatSpecifier': spec,
                'variations': {'plural': {
                    'one': r1.unit('%arg' + match.group(2) + singular),
                    'other': r1.unit('%arg' + match.group(2) + noun),
                }},
            }
        else:
            pieces.append(value[cursor:arg.start()])
            pieces.append('%' + str(number) + '$' + spec)
            cursor = arg.end()
    pieces.append(value[cursor:])
    return ''.join(pieces), substitutions


def convertible(key, entry, pinned_blob):
    if key.startswith('merchant') or key in FORMAT_KEYS:
        return None
    en = entry.get('localizations', {}).get('en', {})
    unit = en.get('stringUnit')
    if not unit or 'substitutions' in en or 'variations' in en:
        return None
    found = plan(unit.get('value', ''))
    if not found or key in pinned_blob or json.dumps(key, ensure_ascii=False)[1:-1] in pinned_blob:
        return None
    return found


def english(new_value, substitutions):
    return {'stringUnit': {'state': 'translated', 'value': new_value}, 'substitutions': substitutions}


def main():
    check = '--check' in sys.argv
    catalog = json.loads(CATALOG.read_text())
    pinned_blob, fragment_files = tracked_texts()
    converted = {}
    for key, entry in catalog['strings'].items():
        found = convertible(key, entry, pinned_blob)
        if found:
            converted[key] = english(*found)
    if check:
        if converted:
            print('FAIL plural substitutions missing for %d multi-argument count string(s): %s'
                  % (len(converted), ', '.join(sorted(converted)[:10])))
            sys.exit(1)
        print('PASS plural substitutions: every convertible multi-argument count string varies by plural')
        return
    for key, en in converted.items():
        catalog['strings'][key]['localizations']['en'] = en
    if converted:
        CATALOG.write_text(json.dumps(catalog, indent=2, ensure_ascii=False) + '\n')
    touched = []
    for name in fragment_files:
        path = ROOT / name
        data = json.loads(path.read_text())
        strings = data.get('strings') if isinstance(data.get('strings'), dict) else data
        changed = False
        for key, en in converted.items():
            if isinstance(strings.get(key), dict) and 'en' in strings[key].get('localizations', {}):
                strings[key]['localizations']['en'] = en
                changed = True
        if changed:
            path.write_text(json.dumps(data, indent=2, ensure_ascii=False) + '\n')
            touched.append(name)
    print(json.dumps({'status': 'SUBSTITUTED', 'converted': sorted(converted), 'fragments': touched}, ensure_ascii=False))


if __name__ == '__main__':
    main()
