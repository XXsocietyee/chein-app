#!/usr/bin/env python3
"""Key-wise union of bilingual fragment catalogs into Resources/Localizable.xcstrings.

A fragment entry replaces the catalog entry when both have exactly en and zh-Hans.
`--check-member` fails when a member fragment's zh-Hans differs from the catalog.
Usage:
  python3 -B tools/merge_localization_fragments.py Resources/X.fragment.json [...]
  python3 -B tools/merge_localization_fragments.py --check-member
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CATALOG = ROOT / 'Resources/Localizable.xcstrings'


def _entry_ok(path, key, entry):
    if not isinstance(entry, dict) or set(entry.get('localizations', {})) != {'en', 'zh-Hans'}:
        raise SystemExit(f'{path}: {key} must have exactly en and zh-Hans')


def fragment_strings(path):
    data = json.loads(Path(path).read_text())
    if isinstance(data, dict) and isinstance(data.get('strings'), dict):
        return data['strings']
    if isinstance(data, dict):
        return data
    raise SystemExit(f'{path}: fragment must be a string catalog')


def merge(paths, catalog_path=None):
    catalog_file = Path(catalog_path) if catalog_path else CATALOG
    catalog = json.loads(catalog_file.read_text())
    strings = catalog['strings']
    added = 0
    overridden = 0
    for path in paths:
        fragment = fragment_strings(path)
        for key, entry in fragment.items():
            _entry_ok(path, key, entry)
            if key in strings:
                if strings[key] == entry:
                    continue
                strings[key] = entry
                overridden += 1
                continue
            strings[key] = entry
            added += 1
    catalog_file.write_text(json.dumps(catalog, ensure_ascii=False, indent=2) + '\n')
    return {'status': 'MERGED', 'added': added, 'overridden': overridden}


def member_fragment_paths(root=None):
    folder = (Path(root) if root else ROOT) / 'docs/port/strings'
    return sorted(path for path in folder.glob('*member*.json') if path.is_file())


def member_zh_drifts(catalog_path, fragment_paths):
    catalog = json.loads(Path(catalog_path).read_text())['strings']
    drifts = []
    for path in fragment_paths:
        fragment = fragment_strings(path)
        for key, entry in fragment.items():
            _entry_ok(path, key, entry)
            current = catalog.get(key, {}).get('localizations', {}).get('zh-Hans')
            if current != entry['localizations']['zh-Hans']:
                drifts.append((str(path), key))
    return drifts


def check_member(catalog_path=None, root=None):
    catalog_file = Path(catalog_path) if catalog_path else CATALOG
    drifts = member_zh_drifts(catalog_file, member_fragment_paths(root))
    if drifts:
        for path, key in drifts:
            print(f'{path}: {key} zh-Hans differs from the catalog', file=sys.stderr)
        raise SystemExit(1)
    return {'status': 'MATCH', 'checked': len(member_fragment_paths(root))}


if __name__ == '__main__':
    args = sys.argv[1:]
    if args == ['--check-member']:
        print(json.dumps(check_member()))
    else:
        print(json.dumps(merge(args)))
