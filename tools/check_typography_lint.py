#!/usr/bin/env python3
"""consist-1 typography + chrome ratchet. Text scan, not a Swift compiler.

Counts, per App/*.swift file (not App/Theme/ or CYDesignTokens.swift, which define the scale):
  raw text style   `.font(.caption2)` and `Font.caption2` (smaller than `.caption`).
                   Semantic Dynamic Type from `.largeTitle` through `.caption` is allowed
                   (`.headline`, `.body`, `.title`, and the other styles in that range).
  Theme.Font       `Theme.Font.body` (use `CYTypography` / `.cyText(_:)`)
  raw size         `.system(size: 14)`, `UIFont.systemFont(ofSize:)`
  back chevron     `"chevron.left"` / `"chevron.backward"` used as a back control (pagers are not counted)
  hidden back      `navigationBarBackButtonHidden(...)` other than `(false)`
  large title      `navigationBarTitleDisplayMode(.large)` (tab roots use `cyRootHeader`)
and compares them with tools/typography_lint_baseline.json. A count above the baseline fails, so new raw fonts,
custom back chevrons and hidden back buttons cannot come in. Counts below the baseline pass; run --update to
lower the baseline after a sweep (it never raises a count unless --allow-increase is given).

  python3 tools/check_typography_lint.py              # check
  python3 tools/check_typography_lint.py --update     # lower the baseline to the current tree
Wired into tools/check_design_lint.py, which CI, check_scaffold.py and release preflight already run.
"""
import argparse
import json
import re
import sys
import tempfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import typography_scale as ts  # noqa: E402
import report_chrome as rc  # noqa: E402

BASELINE = ts.ROOT / 'tools' / 'typography_lint_baseline.json'

RAW_STYLE = 'raw text style'
THEME_FONT = 'Theme.Font'
RAW_SIZE = 'raw size'
BACK_CHEVRON = 'back chevron'
HIDDEN_BACK = 'hidden back'
LARGE_TITLE = 'large title'
KINDS = (RAW_STYLE, THEME_FONT, RAW_SIZE, BACK_CHEVRON, HIDDEN_BACK, LARGE_TITLE)

# Owner rule: `.largeTitle` … `.caption` scale with Dynamic Type. `.caption2` is below that floor.
BELOW_CAPTION = 'caption2'
RAW_STYLE_PATTERNS = (
    re.compile(rf'(?<![\w.])Font\.{BELOW_CAPTION}\b'),
    re.compile(rf'\.font\(\s*\.{BELOW_CAPTION}\b'),
    re.compile(rf'\.system\(\s*\.{BELOW_CAPTION}\b'),
    re.compile(rf'\bfont\s*:\s*\.{BELOW_CAPTION}\b'),
    re.compile(rf'(?<![\w.])Font\s*=\s*\.{BELOW_CAPTION}\b'),
    re.compile(rf'\?\s*\.{BELOW_CAPTION}\s*:\s*\.{BELOW_CAPTION}\b'),
)
THEME_FONT_RE = re.compile(r'\bTheme\.Font\.\w+')
RAW_SIZE_RE = re.compile(r'\.system\(\s*size\s*:|\bsystemFont\s*\(\s*ofSize\s*:|\bboldSystemFont\s*\(\s*ofSize\s*:'
                         r'|\bmonospacedDigitSystemFont\s*\(\s*ofSize\s*:|\bmonospacedSystemFont\s*\(\s*ofSize\s*:')
ROOT_HEADER_FILE = 'App/DesignSystem/CYPlayerKit.swift'


def counts_in(rel, text):
    lines = ts.code_lines(text)
    clean = '\n'.join(lines)
    counts = {}

    def add(kind, n=1):
        if n:
            counts[kind] = counts.get(kind, 0) + n

    seen = set()
    for pattern in RAW_STYLE_PATTERNS:
        for m in pattern.finditer(clean):
            seen.add(m.start())
    add(RAW_STYLE, len(seen))
    add(THEME_FONT, len(THEME_FONT_RE.findall(clean)))
    add(RAW_SIZE, len(RAW_SIZE_RE.findall(clean)))
    if rel != rc.SANCTIONED:
        for i, line in enumerate(lines):
            if rc.CHEVRON.search(line) and rc.classify_chevron(rel, lines, i)[0] != 'pager':
                add(BACK_CHEVRON)
            if rc.HIDDEN_BACK.search(line):
                add(HIDDEN_BACK)
    if rel != ROOT_HEADER_FILE:
        add(LARGE_TITLE, len(rc.LARGE_TITLE.findall(clean)))
    return counts


def scan(root):
    result = {}
    for rel, path in ts.swift_files(root):
        counts = counts_in(rel, path.read_text(encoding='utf-8'))
        if counts:
            result[rel] = counts
    return result


def read_baseline(path=BASELINE):
    if not path.exists():
        return {}
    data = json.loads(path.read_text(encoding='utf-8'))
    return data.get('files', {})


def write_baseline(files, path=BASELINE):
    totals = {kind: sum(c.get(kind, 0) for c in files.values()) for kind in KINDS}
    data = {
        '_doc': 'consist-1 ratchet for tools/check_typography_lint.py. Per-file counts may only go down. '
                'Rules: docs/design/type-and-chrome.md. Lower with --update after a sweep.',
        'totals': totals,
        'files': {rel: {k: files[rel][k] for k in KINDS if files[rel].get(k)} for rel in sorted(files)},
    }
    path.write_text(json.dumps(data, ensure_ascii=False, indent=1, sort_keys=False) + '\n', encoding='utf-8')
    return totals


def compare(actual, baseline):
    """Return (increases, decreases) as lists of (path, kind, base, got)."""
    increases, decreases = [], []
    for rel in sorted(set(actual) | set(baseline)):
        got = actual.get(rel, {})
        base = baseline.get(rel, {})
        for kind in KINDS:
            g, b = got.get(kind, 0), base.get(kind, 0)
            if g > b:
                increases.append((rel, kind, b, g))
            elif g < b:
                decreases.append((rel, kind, b, g))
    return increases, decreases


HINT = {
    RAW_STYLE: '`.caption2` is below `.caption`; use `.caption` or `.cyText(.token)`',
    THEME_FONT: 'use `.cyText(.token)` / `CYTypography.token`',
    RAW_SIZE: 'use a scale token; decorative glyph sizes belong in App/DesignSystem components',
    BACK_CHEVRON: 'use the system back button (exit guard: `cyGuardedBack`; hero: `CYHeroBackButton` in `cyHeroChrome`)',
    HIDDEN_BACK: 'keep the system back; exit guards use `cyGuardedBack(when:onBack:)`',
    LARGE_TITLE: 'large titles are for tab roots (`cyRootHeader`); pushed pages use `cyPageTitle(_:)`',
}


def self_test():
    sample = '\n'.join([
        'Text("a").font(.caption)',
        'Text("b").font(.system(.title3, weight: .bold))',
        'let f: Font = .headline',
        'Text("e").font(.caption2)',
        'Label("x", systemImage: "chevron.left").onTapGesture { dismiss() }',
        'Button { shift(-1) } label: { Image(systemName: "chevron.left") }',
        '.navigationBarBackButtonHidden(true)',
        '.navigationBarBackButtonHidden(false)',
        '.navigationBarTitleDisplayMode(.large)',
        'Text("c").font(Theme.Font.body).font(.system(size: 12))',
        '// .font(.caption) in a comment',
        'Text("d").cyText(.meta)',
    ])
    got = counts_in('App/Sample.swift', sample)
    want = {RAW_STYLE: 1, THEME_FONT: 1, RAW_SIZE: 1, BACK_CHEVRON: 1, HIDDEN_BACK: 1, LARGE_TITLE: 1}
    assert got == want, got
    inc, dec = compare({'App/A.swift': {RAW_STYLE: 2}}, {'App/A.swift': {RAW_STYLE: 1}})
    assert inc and not dec, 'ratchet missed an increase'
    inc, dec = compare({}, {'App/A.swift': {RAW_STYLE: 1}})
    assert not inc and dec, 'ratchet failed a decrease'
    inc, _ = compare({'App/New.swift': {HIDDEN_BACK: 1}}, {})
    assert inc, 'ratchet allowed a new file with a hidden back'
    with tempfile.TemporaryDirectory() as d:
        root = Path(d)
        (root / 'App' / 'Theme').mkdir(parents=True)
        (root / 'App' / 'DesignSystem').mkdir()
        (root / 'App' / 'Theme' / 'Theme.swift').write_text('.font(.caption)\n', encoding='utf-8')
        (root / 'App' / 'DesignSystem' / 'CYDesignTokens.swift').write_text('.system(size: 14)\n', encoding='utf-8')
        (root / 'App' / 'Dirty.swift').write_text('.font(.caption2)\n', encoding='utf-8')
        assert set(scan(root)) == {'App/Dirty.swift'}, 'scanned the scale definition files'


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--update', action='store_true', help='lower the baseline to the current counts')
    ap.add_argument('--allow-increase', action='store_true', help='with --update: also raise counts (needs review)')
    args = ap.parse_args()
    return run(update=args.update, allow_increase=args.allow_increase)


def run(update=False, allow_increase=False):
    self_test()
    actual = scan(ts.ROOT)
    baseline = read_baseline()
    increases, decreases = compare(actual, baseline)
    if update:
        if increases and not allow_increase:
            for rel, kind, b, g in increases:
                print(f'{rel}: {kind} {b} -> {g} (refusing to raise the baseline; fix it or pass --allow-increase)')
            return 1
        totals = write_baseline(actual)
        print('typography lint: baseline written ' + ', '.join(f'{k} {v}' for k, v in totals.items()))
        return 0
    if increases:
        for rel, kind, b, g in increases:
            print(f'{rel}: {kind} {b} -> {g}: {HINT[kind]}')
        print(f'FAIL typography lint: {len(increases)} new raw font / back / title deviation(s) over '
              f'tools/typography_lint_baseline.json (rules: docs/design/type-and-chrome.md)')
        return 1
    totals = {kind: sum(c.get(kind, 0) for c in actual.values()) for kind in KINDS}
    note = f'; {len(decreases)} count(s) below baseline (run --update to ratchet down)' if decreases else ''
    print('PASS typography lint: ' + ', '.join(f'{k} {v}' for k, v in totals.items()) + note)
    return 0


if __name__ == '__main__':
    sys.exit(main())
