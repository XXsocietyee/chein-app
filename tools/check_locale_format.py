#!/usr/bin/env python3
"""i18n r1 (locale lane): ratchet against hard-coded, locale-unsafe presentation in player/club code.

Counts, per App/ file (merchant, fixtures and galleries excluded):
  yuan      a literal "¥" glued to an amount ("¥" + x, "¥\\(x)", "−¥")          -> LocaleDisplay.money
  pattern   a fixed DateFormatter.dateFormat literal                            -> LocaleDisplay.date / civil
  unit      a literal km / 公里 / 米 distance unit                              -> LocaleDisplay.distance
  joinzh    joined(separator: "、") lists                                      -> LocaleDisplay.list
  measure   UnitLength `.measurement(width:)` without `usage:`                  -> add `usage: .road`
Counts may only go down. `--update` rewrites the baseline after a reduction.
Also runs the plural ratchets (tools/add_i18n_r1_plurals.py --check, tools/add_i18n_r2_substitutions.py --check).

Usage: python3 -B tools/check_locale_format.py [--update]
"""
import json
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'tools/locale_format_baseline.json'
EXCLUDE = re.compile(r'(?i)merchant|/DesignFixtures/|/NativeGallery/|Fixture|Preview|/MerchantKit/|/MerchantApprovals/')
RULES = {
    'yuan': re.compile(r'"[−-]?¥"|"[−-]?¥\\\(|"¥[0-9%]|¥"\s*:|"\s*\+\s*"¥|\?\s*"[−-]?¥"'),
    'pattern': re.compile(r'dateFormat\s*=\s*"'),
    'unit': re.compile(r'(?:"[^"\n]*(?:\d|\\\))\s?(?:km|公里|米)"|"(?:km|公里)")'),
    'joinzh': re.compile(r'joined\(separator:\s*"、"\)'),
    'measure': re.compile(r'UnitLength\.\w+\)\s*,\s*format:\s*\.measurement\(width:\s*\.\w+\)'),
}


def scan():
    counts = {}
    for path in sorted((ROOT / 'App').rglob('*.swift')):
        rel = str(path.relative_to(ROOT))
        if EXCLUDE.search(rel):
            continue
        text = path.read_text(encoding='utf-8')
        lines = [line for line in text.split('\n') if not line.lstrip().startswith('//')]
        body = '\n'.join(lines)
        row = {name: len(rule.findall(body)) for name, rule in RULES.items()}
        row = {name: value for name, value in row.items() if value}
        if row:
            counts[rel] = row
    return counts


def totals(counts):
    out = {name: 0 for name in RULES}
    for row in counts.values():
        for name, value in row.items():
            out[name] += value
    return out


def main():
    counts = scan()
    if '--update' in sys.argv or not BASELINE.exists():
        BASELINE.write_text(json.dumps({'totals': totals(counts), 'files': counts}, indent=2, ensure_ascii=False, sort_keys=True) + '\n')
        print('UPDATED locale format baseline: %s' % json.dumps(totals(counts), sort_keys=True))
        return
    baseline = json.loads(BASELINE.read_text())['files']
    regressions = []
    for rel, row in counts.items():
        for name, value in row.items():
            allowed = baseline.get(rel, {}).get(name, 0)
            if value > allowed:
                regressions.append('%s %s %d > %d' % (rel, name, value, allowed))
    plural = subprocess.run([sys.executable, '-B', str(ROOT / 'tools/add_i18n_r1_plurals.py'), '--check'],
                            capture_output=True, text=True)
    # i18n r2: multi-argument count strings must carry English plural substitutions too.
    substitutions = subprocess.run([sys.executable, '-B', str(ROOT / 'tools/add_i18n_r2_substitutions.py'), '--check'],
                                   capture_output=True, text=True)
    if regressions or plural.returncode or substitutions.returncode:
        for line in regressions:
            print('FAIL locale format: ' + line + ' (use LocaleDisplay; see Core/LocaleDisplay.swift)')
        if plural.returncode:
            print(plural.stdout.strip())
        if substitutions.returncode:
            print((substitutions.stdout + substitutions.stderr).strip())
        sys.exit(1)
    now, before = totals(counts), totals(baseline)
    print('PASS locale format: %s (baseline %s); %s; %s' % (json.dumps(now, sort_keys=True), json.dumps(before, sort_keys=True),
                                                         plural.stdout.strip(), substitutions.stdout.strip()))


if __name__ == '__main__':
    main()
