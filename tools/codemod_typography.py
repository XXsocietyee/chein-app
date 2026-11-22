#!/usr/bin/env python3
"""consist-1 typography codemod: raw fonts -> `.cyText(.token)` (the one scale).

Rewrites `.font(<expr>)` in App/**/*.swift (not App/Theme/ or CYDesignTokens.swift) when <expr> is:
  * a raw SwiftUI text style   `.caption`, `.headline.weight(.semibold)`, `.system(.title3, weight: .bold)`
  * a Theme.Font member        `Theme.Font.body`
  * a fixed size               `.system(size: 14, weight: .semibold)`
and, only with --upgrade-tokens, an existing token `CYTypography.body` -> `.cyText(.body)`.

Mapping (tools/typography_scale.py, rule card docs/design/type-and-chrome.md):
  .largeTitle->pageTitle  .title->display  .title2->sheetTitle  .title3->sectionTitle  .headline->cardTitle
  .body/.callout/.subheadline->body (emphasis -> bodyMedium / cardTitle / button)  .footnote->bodyCompact
  (tertiary/time context -> meta)  .caption->meta (.medium -> label)  .caption2->caption
  rounded/monospacedDigit -> numericBody / dataXL;  Theme.Font.X -> X;  .system(size:N) -> nearest step.

Left for a human (listed, never rewritten): SF Symbol images (icon sizing), dynamic expressions (ternaries,
variables, `.system(size: x * 0.3)`), decorative sizes >= 48 pt, monospaced/serif designs, italic/smallCaps, and
any `.font(...)` text that a contract test pins for that file.

Idempotent: a rewritten site is `.cyText(...)`, which this script never matches again.

  python3 tools/codemod_typography.py                 # dry run: counts per mapping + ambiguous list
  python3 tools/codemod_typography.py --apply         # write the files
  python3 tools/codemod_typography.py --markdown out.md --paths App/Club   # report for part of the tree
"""
import argparse
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import typography_scale as ts  # noqa: E402

FONT_CALL = re.compile(r'\.font\(')


def pinned_fonts(root):
    """(path or None, '.font(...)' text) pairs that Tests/ assert on. None path = pinned for every file."""
    pins = set()
    tests = root / 'Tests'
    if not tests.is_dir():
        return pins
    for path in list(tests.rglob('*.py')) + list(tests.rglob('*.swift')):
        try:
            text = path.read_text(encoding='utf-8')
        except (UnicodeDecodeError, OSError):
            continue
        if '.font(' not in text:
            continue
        referenced = set(re.findall(r'App/[\w/+\-]+\.swift', text))
        referenced |= {'*' + name for name in re.findall(r'["\'/]([\w+\-]+\.swift)', text)}
        for m in FONT_CALL.finditer(text):
            end = ts.balanced(text, m.end() - 1)
            if end is None:
                continue
            literal = text[m.start():end].replace('\\\\', '\\')
            if referenced:
                for ref in referenced:
                    pins.add((ref, literal))
            else:
                pins.add((None, literal))
    return pins


def is_pinned(pins, rel, text):
    return (rel, text) in pins or ('*' + rel.rsplit('/', 1)[-1], text) in pins or (None, text) in pins


class Site:
    def __init__(self, rel, line, col_start, col_end, original, replacement, mapping, confidence, reason=None):
        self.rel = rel
        self.line = line
        self.start = col_start
        self.end = col_end
        self.original = original
        self.replacement = replacement
        self.mapping = mapping
        self.confidence = confidence
        self.reason = reason


def scan_file(rel, text, pins, upgrade_tokens=False):
    """Return (rewrites, ambiguous) as lists of Site. Offsets are absolute into `text`."""
    lines = ts.code_lines(text)
    clean = '\n'.join(lines)
    rewrites, ambiguous = [], []
    offsets = [0]
    for line in lines:
        offsets.append(offsets[-1] + len(line) + 1)
    for m in FONT_CALL.finditer(clean):
        open_paren = m.end() - 1
        end = ts.balanced(clean, open_paren)
        if end is None:
            continue
        original = text[m.start():end]
        expr = text[open_paren + 1:end - 1]
        line_index = clean.count('\n', 0, m.start())
        col = m.start() - offsets[line_index]
        parsed = ts.parse_font_expr(expr)
        if parsed is None:
            if re.search(rf'(?:^|[^\w])\.(?:{ts.STYLE_RE})\b|Theme\.Font\.|\.system\(\s*size', expr):
                ambiguous.append(Site(rel, line_index + 1, m.start(), end, original, None, None, None,
                                      'dynamic expression (ternary / variable / computed size)'))
            continue
        if parsed.kind == 'token' and not upgrade_tokens:
            continue
        if ts.is_icon(lines, line_index, col) and parsed.kind != 'theme':
            if parsed.kind == 'token':
                continue
            ambiguous.append(Site(rel, line_index + 1, m.start(), end, original, None, None, None,
                                  'SF Symbol icon size (keep the text style or match the adjacent text token)'))
            continue
        if is_pinned(pins, rel, original):
            ambiguous.append(Site(rel, line_index + 1, m.start(), end, original, None, None, None,
                                  'pinned by a contract test; update the test in the same commit'))
            continue
        if parsed.kind == 'token':
            if parsed.source not in ts.SCALE or parsed.unsupported:
                continue
            token, weight = ts.apply_weight(parsed.source, parsed.weight)
            mono = parsed.mono and token not in ts.NUMERIC
            replacement = ts.render_cytext(token, weight, mono)
            rewrites.append(Site(rel, line_index + 1, m.start(), end, original, replacement,
                                 'CYTypography.%s -> %s' % (parsed.source, token), 'exact'))
            continue
        result = ts.map_parsed(parsed, lines, line_index, col)
        if result[0] is None:
            ambiguous.append(Site(rel, line_index + 1, m.start(), end, original, None, None, None, result[1]))
            continue
        token, weight, mono, confidence, label = result
        replacement = ts.render_cytext(token, weight, mono)
        mapping = '%s -> %s%s' % (label if parsed.kind != 'size' else '.system(size: %s)' % label.split()[0],
                                  token, ' (weight .%s)' % weight if weight else '')
        if parsed.kind == 'style' and parsed.weight:
            mapping = '.%s.weight(.%s) -> %s%s' % (parsed.source, parsed.weight, token,
                                                    ' (weight .%s)' % weight if weight else '')
        rewrites.append(Site(rel, line_index + 1, m.start(), end, original, replacement, mapping, confidence))
    return rewrites, ambiguous


def apply_rewrites(text, rewrites):
    for site in sorted(rewrites, key=lambda s: s.start, reverse=True):
        text = text[:site.start] + site.replacement + text[site.end:]
    return text


def run(root, paths=None, apply=False, upgrade_tokens=False):
    pins = pinned_fonts(root)
    all_rewrites, all_ambiguous = [], []
    changed_files = 0
    for rel, path in ts.swift_files(root):
        if paths and not any(rel.startswith(p.rstrip('/')) for p in paths):
            continue
        text = path.read_text(encoding='utf-8')
        if '.font(' not in text:
            continue
        rewrites, ambiguous = scan_file(rel, text, pins, upgrade_tokens)
        all_rewrites += rewrites
        all_ambiguous += ambiguous
        if apply and rewrites:
            path.write_text(apply_rewrites(text, rewrites), encoding='utf-8')
            changed_files += 1
    return all_rewrites, all_ambiguous, changed_files


def summary(rewrites, ambiguous, changed_files, apply, limit=None):
    out = []
    by_mapping = Counter(s.mapping for s in rewrites)
    by_conf = Counter(s.confidence for s in rewrites)
    files = len({s.rel for s in rewrites})
    out.append('## codemod_typography %s' % ('APPLY' if apply else 'dry run'))
    out.append('')
    out.append('- replacements: **%d** in %d files%s' % (len(rewrites), files,
                                                         ' (%d files written)' % changed_files if apply else ''))
    out.append('- confidence: ' + ', '.join('%s %d' % (k, by_conf[k]) for k in ('exact', 'context', 'nearest', 'default') if by_conf[k]))
    out.append('- left for a human: **%d**' % len(ambiguous))
    out.append('')
    out.append('### Replacements per mapping')
    out.append('')
    out.append('| count | mapping | confidence |')
    out.append('|---:|---|---|')
    conf_of = defaultdict(Counter)
    for s in rewrites:
        conf_of[s.mapping][s.confidence] += 1
    for mapping, count in by_mapping.most_common():
        conf = ', '.join('%s %d' % (k, v) for k, v in conf_of[mapping].most_common())
        out.append('| %d | `%s` | %s |' % (count, mapping, conf))
    out.append('')
    out.append('### Left for a human, by reason')
    out.append('')
    reasons = Counter(s.reason for s in ambiguous)
    out.append('| count | reason |')
    out.append('|---:|---|')
    for reason, count in reasons.most_common():
        out.append('| %d | %s |' % (count, reason))
    out.append('')
    out.append('### Ambiguous sites')
    out.append('')
    shown = ambiguous if limit is None else ambiguous[:limit]
    for s in shown:
        out.append('- `%s:%d` `%s` — %s' % (s.rel, s.line, s.original.replace('`', "'")[:120], s.reason))
    if limit is not None and len(ambiguous) > limit:
        out.append('- … %d more (run the script for the full list)' % (len(ambiguous) - limit))
    return '\n'.join(out) + '\n'


def self_test():
    sample = '\n'.join([
        'Text("a").font(.caption)',
        'Text("b").font(.footnote).foregroundStyle(palette.textTertiary)',
        'Text("c").font(.headline)',
        'Text("d").font(.subheadline.weight(.semibold))',
        'Text("e").font(Theme.Font.body)',
        'Text("f").font(.system(size: 18, weight: .bold))',
        'Image(systemName: "x").font(.body)',
        'Text("g").font(isOn ? .body : .caption)',
        'Text("h").font(.system(size: 72))',
        'Text("i").font(.system(.title, design: .rounded, weight: .bold))',
        'Text("j").font(CYTypography.body)',
        'Text("k").font(.caption.monospacedDigit())',
        '// Text("l").font(.caption)',
    ])
    rewrites, ambiguous = scan_file('App/Sample.swift', sample, set())
    got = [s.replacement for s in rewrites]
    want = ['.cyText(.meta)', '.cyText(.meta)', '.cyText(.cardTitle)', '.cyText(.bodyMedium)', '.cyText(.body)',
            '.cyText(.sectionTitle)', '.cyText(.dataXL)', '.cyText(.meta, monospacedDigit: true)']
    assert got == want, got
    assert len(ambiguous) == 3, [a.reason for a in ambiguous]
    once = apply_rewrites(sample, rewrites)
    again, _ = scan_file('App/Sample.swift', once, set())
    assert again == [], 'codemod is not idempotent'
    tokens, _ = scan_file('App/Sample.swift', once, set(), upgrade_tokens=True)
    assert [s.replacement for s in tokens] == ['.cyText(.body)'], [s.replacement for s in tokens]
    pinned, amb = scan_file('App/Sample.swift', 'Text("a").font(.caption)', {('App/Sample.swift', '.font(.caption)')})
    assert pinned == [] and amb[0].reason.startswith('pinned'), 'pinned site rewritten'


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--apply', action='store_true', help='write files (default: dry run)')
    ap.add_argument('--upgrade-tokens', action='store_true', help='also turn CYTypography.X into .cyText(.X)')
    ap.add_argument('--paths', nargs='*', help='limit to these App/ path prefixes')
    ap.add_argument('--markdown', help='write the summary to this file')
    ap.add_argument('--limit', type=int, default=None, help='cap the ambiguous list in the printed summary')
    args = ap.parse_args()
    self_test()
    rewrites, ambiguous, changed = run(ts.ROOT, args.paths, args.apply, args.upgrade_tokens)
    text = summary(rewrites, ambiguous, changed, args.apply, args.limit)
    if args.markdown:
        Path(args.markdown).write_text(text, encoding='utf-8')
    print(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
