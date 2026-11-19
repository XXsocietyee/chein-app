#!/usr/bin/env python3
"""consist-1 chrome report: every back-button and title deviation from the one rule, with a suggested fix.

Rules (docs/design/type-and-chrome.md):
  back   system back button in the navigation bar + edge swipe. Exceptions: `cyGuardedBack(when:onBack:)` for
         exit guards; `cyHeroChrome(heroScrolledAway:)` + `CYHeroBackButton` in the hero overlay for full-bleed heroes.
  title  tab roots `cyRootHeader(_:)` (large); pushed pages `cyPageTitle(_:)` (inline 17 pt semibold);
         sheets `CYSheetHeader`.

Read-only. Text scan, not a Swift compiler.
  python3 tools/report_chrome.py                 # markdown to stdout
  python3 tools/report_chrome.py --json          # machine-readable
"""
import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import typography_scale as ts  # noqa: E402

SANCTIONED = 'App/DesignSystem/CYScreenStyle.swift'  # defines the sanctioned back controls
CHEVRON = re.compile(r'"chevron\.(?:left|backward)"')
HIDDEN_BACK = re.compile(r'navigationBarBackButtonHidden\(\s*(?!false\s*\))')
LARGE_TITLE = re.compile(r'navigationBarTitleDisplayMode\(\s*\.large\s*\)')
TITLE_CALL = re.compile(r'\.(?:navigationTitle|appNavigationTitle)\(')
TITLE_MODE = re.compile(r'navigationBarTitleDisplayMode\(|toolbarTitleDisplayMode\(|cyRootHeader\(|cyPageTitle\(')
HERO_CHROME = re.compile(r'\.cyHeroPushedChrome\(')
CUSTOM_NAVBAR = re.compile(r'\bCYNavBar\s*\(')
HIDDEN_BAR = re.compile(r'\.toolbar\(\s*\.hidden\s*,\s*for:\s*\.navigationBar')

PAGER_HINT = re.compile(r'shift|month|Month|previous|prev|page|Page|step\.rawValue\s*-\s*1|by:\s*-1|\(-1\)|week|Week|day|Day')
BACK_HINT = re.compile(r'dismiss|onBack|action\.back|\.back\b|"back"|Back"|back"|leave\(|上一步|返回|goBack|pop|showChannelList|\.back"')
GUARD_HINT = re.compile(r'ExitGuard|exitGuard|discard|Discard|unsaved|Unsaved|isDirty|dirty|hasChanges')


def classify_chevron(rel, lines, index):
    ctx = ts.context_text(lines, index, 3, 6)
    if rel.startswith('App/DesignSystem/'):
        return 'design-system', ('component-internal: CYNavBar / CYSheetHeader sub-editor back / full-screen cover; '
                                 'migrate callers to the system bar, then retire the glyph (a full-screen cover closes '
                                 'with xmark or 完成, not a back chevron)')
    near = ts.context_text(lines, index, 2, 0)
    if PAGER_HINT.search(near) and not re.search(r'action\.back|dismiss', near.split('\n')[-1]):
        return 'pager', 'calendar / step pager, not navigation: keep (use `chevron.left` + accessibility label)'
    if '上一步' in ctx or 'Step(' in ctx:
        return 'step-back', 'wizard step back inside content: keep in content, or make it a toolbar `Button` with text 上一步'
    if BACK_HINT.search(ctx):
        return 'back', 'custom back: delete it and use the system back; for an exit guard use `cyGuardedBack(when:onBack:)`'
    return 'unknown', 'check by hand: navigation back -> system back; anything else -> keep'


def scan(root):
    items = []
    for rel, path in ts.swift_files(root):
        text = path.read_text(encoding='utf-8')
        lines = ts.code_lines(text)
        raw_lines = text.split('\n')
        file_has_mode = bool(TITLE_MODE.search('\n'.join(lines)))
        guarded_file = bool(GUARD_HINT.search(rel)) or bool(GUARD_HINT.search(text))
        title_lines = []
        for i, line in enumerate(lines):
            snippet = raw_lines[i].strip()[:140]
            if CHEVRON.search(line) and rel != SANCTIONED:
                kind, fix = classify_chevron(rel, lines, i)
                items.append(dict(file=rel, line=i + 1, kind='chevron:' + kind, code=snippet, fix=fix))
            if HIDDEN_BACK.search(line) and rel != SANCTIONED:
                if guarded_file:
                    fix = 'exit guard: replace hide + custom chevron with `cyGuardedBack(when: hasEdits, onBack: confirmDiscard)`'
                else:
                    fix = 'remove; let the system back button show (keeps the edge swipe)'
                items.append(dict(file=rel, line=i + 1, kind='hidden-back', code=snippet, fix=fix))
            if LARGE_TITLE.search(line):
                items.append(dict(file=rel, line=i + 1, kind='large-title', code=snippet,
                                  fix='tab roots only (`cyRootHeader`); a pushed page uses `cyPageTitle(_:)` (inline)'))
            if HERO_CHROME.search(line):
                items.append(dict(file=rel, line=i + 1, kind='hero-chrome', code=snippet,
                                  fix='move to `cyHeroChrome(heroScrolledAway:)` + `CYHeroBackButton` in the hero overlay '
                                      '(glass circle scrolls away with the image; keep the accessibility identifier on it)'))
            if CUSTOM_NAVBAR.search(line) and not rel.startswith('App/DesignSystem/'):
                items.append(dict(file=rel, line=i + 1, kind='custom-navbar', code=snippet,
                                  fix='drop the in-content nav bar; use the system bar + `cyPageTitle(_:)`'))
            if HIDDEN_BAR.search(line):
                items.append(dict(file=rel, line=i + 1, kind='hidden-bar', code=snippet,
                                  fix='full-screen flow / map root is fine; a pushed page must keep a way back '
                                      '(`cyHeroChrome` or `cyKeepsSwipeBack()`)'))
            if TITLE_CALL.search(line):
                title_lines.append((i, snippet))
        if title_lines and not file_has_mode:
            for i, snippet in title_lines:
                items.append(dict(file=rel, line=i + 1, kind='title-mode-unset', code=snippet,
                                  fix='title mode inherits from the stack (large after a large root): use `cyPageTitle(_:)`'))
    return items


def to_markdown(items):
    counts = Counter(item['kind'] for item in items)
    out = ['## report_chrome', '']
    out.append('| count | kind |')
    out.append('|---:|---|')
    for kind, count in sorted(counts.items(), key=lambda kv: (-kv[1], kv[0])):
        out.append('| %d | %s |' % (count, kind))
    out.append('')
    current = None
    for item in sorted(items, key=lambda x: (x['kind'], x['file'], x['line'])):
        if item['kind'] != current:
            current = item['kind']
            out.append('### ' + current)
            out.append('')
        out.append('- `%s:%d` `%s` — %s' % (item['file'], item['line'], item['code'].replace('`', "'"), item['fix']))
    return '\n'.join(out) + '\n'


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--json', action='store_true')
    ap.add_argument('--kind', help='only this kind (prefix match, e.g. chevron)')
    args = ap.parse_args()
    items = scan(ts.ROOT)
    if args.kind:
        items = [i for i in items if i['kind'].startswith(args.kind)]
    if args.json:
        print(json.dumps(items, ensure_ascii=False, indent=1))
    else:
        print(to_markdown(items))
    return 0


if __name__ == '__main__':
    sys.exit(main())
