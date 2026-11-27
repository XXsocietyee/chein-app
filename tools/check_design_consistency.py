#!/usr/bin/env python3
"""ds-consistency r3: ONE design system ratchet (owner rule 2, 2026-11-27). Text scan, not a Swift compiler.

Scans player-facing App/**/*.swift (skips paths with `Merchant`, `Fixture`, `DesignFixtures/`, `Diagnostics`,
and `#Preview { ... }` blocks; comments are ignored) and counts, per file:

  raw font        `.system(size:` (unless the size is an `@ScaledMetric`), `.font(.custom(`, `Font.custom(`,
                  `UIFont.systemFont(ofSize:`  -> use Dynamic Type text styles or `.cyText(_:)`
                  (App/Theme and CYDesignTokens.swift define the scale and are not counted)
  tracking        `.tracking(` / `.kerning(`  -> the system letter spacing only
  root title      a tab-root file (TAB_ROOTS) without `.cyRootHeader(` or `.navigationBarTitleDisplayMode(.large)`
                  (a transparent / hidden bar on a root is caught by `hidden nav`)
  pushed large    `.navigationBarTitleDisplayMode(.large)` outside the tab roots and the design system
                  (pushed pages use the inline title, `cyPageTitle(_:)`)
  title mode      a file that sets navigation titles but never a display mode (no `.navigationBarTitleDisplayMode`,
                  `cyPageTitle`, `cyRootHeader`): a pushed page then inherits the tab root's large title
  hidden nav      `.navigationBarHidden(true)`, `.toolbar(.hidden, for: .navigationBar)`,
                  `.toolbarBackground(.hidden, for: .navigationBar)`, `.navigationBarBackButtonHidden(true)`
                  (custom back buttons / MP custom nav chrome)
  custom back     `CYNavBar(` / `CYBareBackButton(` / `CYHeroBackButton(` outside App/DesignSystem
                  (use the system bar; `cyGuardedBack(when:onBack:)` for an unsaved-changes exit)
  raw colour      `Color(red:` / `UIColor(red:` / `Color(hex:` / `"#RRGGBB"` / `0xRRGGBB` outside App/DesignSystem
                  and App/Theme  -> semantic system colours or the CY palette

Baseline: tools/design_consistency_baseline.json
  "allowed":  {file: {kind: reason}}  intentional chrome (game HUDs, full-screen maps, procedural art), never fails
  "baseline": {file: {kind: count}}   debt on this tree; a count above it fails, so new violations fail

  python3 tools/check_design_consistency.py            # check (exit 1 on a new violation)
  python3 tools/check_design_consistency.py --list     # print every current hit
  python3 tools/check_design_consistency.py --update   # lower the baseline to the tree (never raises a count)
  python3 tools/check_design_consistency.py --update --allow-increase   # re-baseline (reviewed only)
"""
import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE = ROOT / 'tools' / 'design_consistency_baseline.json'

RAW_FONT = 'raw font'
TRACKING = 'tracking'
ROOT_TITLE = 'root title'
PUSHED_LARGE = 'pushed large'
HIDDEN_NAV = 'hidden nav'
RAW_COLOUR = 'raw colour'
CUSTOM_BACK = 'custom back'
TITLE_MODE = 'title mode'
KINDS = (RAW_FONT, TRACKING, ROOT_TITLE, PUSHED_LARGE, TITLE_MODE, HIDDEN_NAV, CUSTOM_BACK, RAW_COLOUR)

# The five player tab roots (Core/RootTab.swift, QuestifyApp root TabView) and the files that own their title.
# 漫游 is the full-screen map home: its chrome is allowed in the baseline instead.
TAB_ROOTS = (
    'App/HomeFeedView.swift',                 # 首页 (SessionHomeFeedView -> HomeFeedView)
    'App/DiscoveryTemplateBrowserView.swift', # 发布 (PublishTabRootView -> isTabRoot: true)
    'App/ClubHomeView.swift',                 # 俱乐部
    'App/AccountView.swift',                  # 我的 (signed in, PassportView -> AccountView)
    'App/WelcomeView.swift',                  # 我的 (signed out)
)

SKIP_PARTS = ('Merchant', 'Fixture', 'DesignFixtures/', 'Diagnostics')
FONT_SCALE_FILES = ('App/DesignSystem/CYDesignTokens.swift',)
COLOUR_EXEMPT_PREFIXES = ('App/DesignSystem/', 'App/Theme/')

FONT_PATTERNS = (
    re.compile(r'\.system\s*\(\s*size\s*:'),
    re.compile(r'\.font\s*\(\s*\.custom\s*\('),
    re.compile(r'\bFont\.custom\s*\('),
    re.compile(r'\bUIFont\.systemFont\s*\(\s*ofSize\s*:'),
    re.compile(r'\bUIFont\s*\(\s*name\s*:'),
)
SCALED_METRIC = re.compile(r'@ScaledMetric\b[^\n]*?\bvar\s+(\w+)')
SYSTEM_SIZE_ARG = re.compile(r'\.system\s*\(\s*size\s*:\s*(\w+)\s*[,)]')
TRACKING_PATTERN = re.compile(r'\.(?:tracking|kerning)\s*\(')
LARGE_PATTERN = re.compile(r'\.navigationBarTitleDisplayMode\s*\(\s*\.large\s*\)')
TITLE_PATTERN = re.compile(r'\.(?:navigationTitle|appNavigationTitle)\s*\(')
ANY_MODE_PATTERN = re.compile(r'\.navigationBarTitleDisplayMode\s*\(|\.cyPageTitle\s*\(|\.cyRootHeader\s*\(')
TITLE_MODE_EXEMPT = ('App/AppLocalizedString.swift',)
ROOT_HEADER_PATTERN = re.compile(r'\.cyRootHeader\s*\(')
HIDDEN_PATTERNS = (
    re.compile(r'\.navigationBarHidden\s*\(\s*true\s*\)'),
    re.compile(r'\.toolbar\s*\(\s*\.hidden\s*,\s*for\s*:\s*\.navigationBar\s*\)'),
    re.compile(r'\.toolbarBackground\s*\(\s*\.hidden\s*,\s*for\s*:\s*\.navigationBar\s*\)'),
    re.compile(r'\.navigationBarBackButtonHidden\s*\(\s*true\s*\)'),
)
# MP-style custom navigation chrome built from the design kit instead of the system bar (`cyGuardedBack` is the
# approved guarded exit and lives inside the design system).
CUSTOM_BACK_PATTERN = re.compile(r'(?<![\w.])(?:CYNavBar|CYBareBackButton|CYHeroBackButton)\s*[(<]')
COLOUR_PATTERNS = (
    re.compile(r'(?<![\w.])(?:UI)?Color\s*\(\s*red\s*:'),
    re.compile(r'(?<![\w.])(?:UI)?Color\s*\(\s*hex\s*:'),
    re.compile(r'"#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?"'),
    re.compile(r'\b0x[0-9A-Fa-f]{6}\b'),
)


def player_files():
    for path in sorted((ROOT / 'App').rglob('*.swift')):
        rel = path.relative_to(ROOT).as_posix()
        if any(part in rel for part in SKIP_PARTS):
            continue
        yield rel, path


def strip_comments(line, state):
    """Drops `//` and `/* */` comments outside string literals. `state` carries an open block comment."""
    out = []
    i = 0
    in_string = False
    while i < len(line):
        if state['block']:
            end = line.find('*/', i)
            if end < 0:
                return ''.join(out)
            state['block'] = False
            i = end + 2
            continue
        ch = line[i]
        if in_string:
            out.append(ch)
            if ch == '\\' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if ch == '"':
                in_string = False
            i += 1
            continue
        if ch == '"':
            in_string = True
            out.append(ch)
            i += 1
            continue
        if line.startswith('//', i):
            break
        if line.startswith('/*', i):
            state['block'] = True
            i += 2
            continue
        out.append(ch)
        i += 1
    return ''.join(out)


def code_lines(text):
    """(line number, code) pairs without comments and without `#Preview { ... }` blocks."""
    state = {'block': False}
    preview_depth = None
    for number, raw in enumerate(text.split('\n'), start=1):
        code = strip_comments(raw, state)
        if preview_depth is None and re.match(r'\s*#Preview\b', code):
            preview_depth = 0
            opened = False
            for ch in code:
                if ch == '{':
                    preview_depth += 1
                    opened = True
                elif ch == '}':
                    preview_depth -= 1
            if opened and preview_depth <= 0:
                preview_depth = None
            continue
        if preview_depth is not None:
            preview_depth += code.count('{') - code.count('}')
            if preview_depth <= 0 and '}' in code:
                preview_depth = None
            continue
        yield number, code


def scan_file(rel, text):
    hits = []
    lines = list(code_lines(text))
    font_scale = rel in FONT_SCALE_FILES or rel.startswith('App/Theme/')
    colour_exempt = rel.startswith(COLOUR_EXEMPT_PREFIXES)
    design_system = rel.startswith('App/DesignSystem/')
    is_root = rel in TAB_ROOTS
    # `.system(size: x)` where `x` is an `@ScaledMetric` scales with Dynamic Type: that is the approved pattern.
    scaled = set(SCALED_METRIC.findall(text))
    for number, code in lines:
        sized = SYSTEM_SIZE_ARG.findall(code)
        scaled_only = bool(sized) and all(name in scaled for name in sized) and not any(
            p.search(code) for p in FONT_PATTERNS[1:])
        if not font_scale and not scaled_only and any(p.search(code) for p in FONT_PATTERNS):
            hits.append((number, RAW_FONT, code.strip()))
        if not font_scale and TRACKING_PATTERN.search(code):
            hits.append((number, TRACKING, code.strip()))
        if LARGE_PATTERN.search(code) and not is_root and not design_system:
            hits.append((number, PUSHED_LARGE, code.strip()))
        if any(p.search(code) for p in HIDDEN_PATTERNS):
            hits.append((number, HIDDEN_NAV, code.strip()))
        if not design_system and CUSTOM_BACK_PATTERN.search(code):
            hits.append((number, CUSTOM_BACK, code.strip()))
        if not colour_exempt and any(p.search(code) for p in COLOUR_PATTERNS):
            hits.append((number, RAW_COLOUR, code.strip()))
    if not design_system and rel not in TITLE_MODE_EXEMPT and not any(ANY_MODE_PATTERN.search(c) for _, c in lines):
        for number, code in lines:
            if TITLE_PATTERN.search(code):
                hits.append((number, TITLE_MODE, code.strip()))
    if is_root:
        has_large = any(ROOT_HEADER_PATTERN.search(c) or LARGE_PATTERN.search(c) for _, c in lines)
        if not has_large:
            hits.append((1, ROOT_TITLE, 'tab root without .cyRootHeader(...) / .navigationBarTitleDisplayMode(.large)'))
    return hits


def scan():
    result = {}
    for rel, path in player_files():
        hits = scan_file(rel, path.read_text(encoding='utf-8', errors='replace'))
        if hits:
            result[rel] = hits
    missing = [r for r in TAB_ROOTS if not (ROOT / r).exists()]
    for rel in missing:
        result[rel] = [(0, ROOT_TITLE, 'tab root file is missing: update TAB_ROOTS')]
    return result


def counts(hits):
    out = {}
    for _, kind, _ in hits:
        out[kind] = out.get(kind, 0) + 1
    return out


def load_baseline():
    if not BASELINE.exists():
        return {'allowed': {}, 'baseline': {}}
    data = json.loads(BASELINE.read_text(encoding='utf-8'))
    data.setdefault('allowed', {})
    data.setdefault('baseline', {})
    return data


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--list', action='store_true', help='print every current hit')
    parser.add_argument('--update', action='store_true', help='lower the baseline to the current tree')
    parser.add_argument('--allow-increase', action='store_true', help='with --update, also raise counts')
    args = parser.parse_args()

    data = load_baseline()
    allowed = data['allowed']
    baseline = data['baseline']
    found = scan()

    failures = []
    totals = {k: 0 for k in KINDS}
    allowed_totals = {k: 0 for k in KINDS}
    current = {}
    for rel, hits in sorted(found.items()):
        file_allowed = allowed.get(rel, {})
        kept = [h for h in hits if h[1] not in file_allowed]
        for h in hits:
            if h[1] in file_allowed:
                allowed_totals[h[1]] += 1
        if args.list:
            for number, kind, code in hits:
                tag = ' (allowed)' if kind in file_allowed else ''
                print(f'{rel}:{number}: {kind}{tag}: {code[:160]}')
        c = counts(kept)
        if c:
            current[rel] = c
        for kind, n in c.items():
            totals[kind] += n
            limit = baseline.get(rel, {}).get(kind, 0)
            if n > limit:
                lines = [f'{rel}:{num}: {code[:160]}' for num, k, code in kept if k == kind]
                failures.append((rel, kind, n, limit, lines))

    below = 0
    for rel, kinds in baseline.items():
        for kind, limit in kinds.items():
            if current.get(rel, {}).get(kind, 0) < limit:
                below += 1

    if args.update:
        new = {}
        for rel in sorted(set(baseline) | set(current)):
            row = {}
            for kind in KINDS:
                now = current.get(rel, {}).get(kind, 0)
                was = baseline.get(rel, {}).get(kind, 0)
                value = now if args.allow_increase else min(now, was)
                if value:
                    row[kind] = value
            if row:
                new[rel] = row
        data['baseline'] = new
        BASELINE.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
        print(f'updated {BASELINE.relative_to(ROOT)}: {sum(sum(r.values()) for r in new.values())} baselined hits')
        if not args.allow_increase and failures:
            print('note: new violations were not baselined (use --allow-increase only after review)')
        return 0 if args.allow_increase or not failures else 1

    summary = ', '.join(f'{k} {totals[k]}' for k in KINDS)
    allowed_summary = sum(allowed_totals.values())
    if failures:
        print('FAIL design consistency: new violations of the one design system (owner rule 2):')
        for rel, kind, n, limit, lines in failures:
            print(f'  {rel}: {kind} {n} > baseline {limit}')
            for line in lines[:8]:
                print(f'    {line}')
        print('Use Dynamic Type text styles / .cyText(_:), the system letter spacing, cyRootHeader / cyPageTitle,')
        print('the system navigation bar and semantic colours. Intentional chrome goes in "allowed" with a reason.')
        return 1
    print(f'PASS design consistency: {summary}; {allowed_summary} allowed hit(s); '
          f'{below} count(s) below baseline (run --update to ratchet down)')
    return 0


if __name__ == '__main__':
    sys.exit(main())
