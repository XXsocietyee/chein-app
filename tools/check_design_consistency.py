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
  button style    a page-level `struct …: ButtonStyle` outside App/DesignSystem, or `.buttonStyle(.questifyPrimary)`
                  (one button system: `.borderedProminent` / `.bordered` / `.borderless` or the CY styles)
  popup scrim     `Color.black.opacity(0.2…0.8).ignoresSafeArea(` outside App/DesignSystem: an MP popup copied as a
                  dimmed overlay (use `.sheet` + `.presentationDetents`)
  raw colour      `Color(red:` / `UIColor(red:` / `Color(hex:` / `"#RRGGBB"` / `0xRRGGBB` outside App/DesignSystem
                  and App/Theme  -> semantic system colours or the CY palette
  list style      `.listStyle(...)` other than `.insetGrouped` (190 sibling pages use `.insetGrouped`; a `.plain` /
                  `.grouped` / `.inset` / `.sidebar` page next to them is a list-style mix)
  custom sheet    an MP popup / half-screen built by hand instead of `.sheet` + `.presentationDetents`, outside
                  App/DesignSystem: `.accessibilityAddTraits(.isModal)` (hand-made modal), a dimmed
                  `CYColor.bgOverlay` / `Color.black.opacity(…)` scrim with `.ignoresSafeArea()` + `.onTapGesture`,
                  or a drawn sheet grabber `Capsule()…frame(width: 3x–4x, height: 4–6)`
  custom tabs     a hand-made tab bar / segment row outside App/DesignSystem: `ForEach` over tabs / segments whose
                  rows are `Button`s compared against the selection (use `Picker` + `.cyAdaptiveSegmented()` or
                  `CYTabs`), or the design-kit bottom bars `CYNightTabBar(` / `CYDomainTabBar(` used in place of the
                  system `TabView` (App/QuestifyApp.swift)
  font design     `design: .rounded` / `.serif` or `.fontDesign(.rounded / .serif)` outside App/DesignSystem and
                  App/Theme: a per-page numeral / heading face (stat numbers use `.cyText(.dataXL)`, the one rounded
                  data style; `.monospaced` code editors are fine)
  custom search   a hand-drawn search field outside App/DesignSystem: an `Image(systemName: "magnifyingglass")`
                  followed within 3 lines by a `TextField(` (use `.searchable` on the page, or `CYFormSearchRow` for a
                  filter that is one row of a Form / List section)
  text on art     a generated cover `CYCoverArt(` used as the `.background` of a view outside App/DesignSystem
                  (a title / text laid on busy procedural art): put the cover above the text as the hero
                  illustration (`CYHeroHeader { Cloud07Cover(...) }`) and keep text on system backgrounds
  raw segmented   `.pickerStyle(.segmented)` outside App/DesignSystem: 85 sibling pickers use `.cyAdaptiveSegmented()`
                  (segmented while every title fits, the system menu for long English titles / accessibility sizes),
                  so a bare segmented picker truncates where its siblings do not

Build-break guards (module-wide: App/ and Core/ compile into ONE module, so every file is scanned, merchant and
fixtures included; there is no Swift compiler in the lanes' cloud sessions):
  duplicate type   the same top-level `struct` / `class` / `enum` / `protocol` / `actor` / `typealias` name declared
                   in two files of App/ + Core/ (two lanes each added a `PlayRouteNotice`). `private` / `fileprivate`
                   top-level types only clash inside their own file; declarations in different branches of the same
                   `#if … #else` are not a clash.
  undeclared state inside a SwiftUI `View` struct (its body plus every `extension Name` in the module): a `$name`
                   binding or an assignment `name = …` / `self.name = …` / `name += …` whose name is never declared
                   (`var` / `let` / `inout` / enum `case`) in that type, its extensions or the module's globals
                   (a lane used `governanceMemberCount = $0` without `@State private var governanceMemberCount`).
                   Heuristic text scan: string literals are blanked first.

Baseline: tools/design_consistency_baseline.json
  "allowed":  {file: {kind: reason}}  intentional chrome (game HUDs, full-screen maps, procedural art), never fails;
                                      an allowed kind with no hit left in its file is reported as stale and fails
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
BUTTON_STYLE = 'button style'
POPUP_SCRIM = 'popup scrim'
LIST_STYLE = 'list style'
CUSTOM_SHEET = 'custom sheet'
CUSTOM_TABS = 'custom tabs'
FONT_DESIGN = 'font design'
CUSTOM_SEARCH = 'custom search'
TEXT_ON_ART = 'text on art'
RAW_SEGMENTED = 'raw segmented'
RAW_SEGMENTED_PATTERN = re.compile(r'\.pickerStyle\(\s*\.segmented\s*\)')
DUPLICATE_TYPE = 'duplicate type'
UNDECLARED_STATE = 'undeclared state'
KINDS = (RAW_FONT, TRACKING, ROOT_TITLE, PUSHED_LARGE, TITLE_MODE, HIDDEN_NAV, CUSTOM_BACK, BUTTON_STYLE, POPUP_SCRIM,
         RAW_COLOUR, LIST_STYLE, CUSTOM_SHEET, CUSTOM_TABS, FONT_DESIGN, CUSTOM_SEARCH, TEXT_ON_ART, RAW_SEGMENTED,
         DUPLICATE_TYPE, UNDECLARED_STATE)

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
# One button system: `.borderedProminent` / `.bordered` / `.borderless` or the CY styles in App/DesignSystem.
BUTTON_STYLE_PATTERNS = (
    re.compile(r'\bstruct\s+\w+\s*:\s*(?:Primitive)?ButtonStyle\b'),
    re.compile(r'\.buttonStyle\s*\(\s*\.questifyPrimary\s*\)'),
)
# A hand-made dimmed full-screen scrim = an MP popup copied as an overlay. MP popups are `.sheet` with detents.
POPUP_SCRIM_PATTERN = re.compile(r'Color\.black\.opacity\(\s*0?\.[2-8]\d*\s*\)\s*\.ignoresSafeArea\(')
# One list pattern: the app's list pages are `.insetGrouped` (the iOS Settings look); anything else is a mix.
LIST_STYLE_PATTERN = re.compile(r'\.listStyle\s*\(\s*(?!\.insetGrouped\b|InsetGroupedListStyle\s*\()([^)]*\)?)')
# Hand-made MP popups / half-screens instead of `.sheet` + detents.
CUSTOM_SHEET_PATTERNS = (
    re.compile(r'\.accessibilityAddTraits\s*\(\s*(?:\[[^\]]*)?\.isModal\b'),
    re.compile(r'(?:CYColor\.bgOverlay|Color\.black\.opacity\([^)]*\))\s*\.ignoresSafeArea\([^)]*\)\s*\.onTapGesture\b'),
    re.compile(r'\bCapsule\(\)[^\n]*\.frame\(\s*width:\s*[34]\d(?:\.\d+)?\s*,\s*height:\s*[4-6](?:\.\d+)?\s*\)'),
)
# Hand-made tab bars: a ForEach over tabs / segments whose items are Buttons tested against the selection.
TABS_FOREACH = re.compile(r'\bForEach\s*\([^\n]*\b(?:tabs|segments|\w*(?:Tab|Segment)\w*\.allCases)\b')
TABS_BUTTON = re.compile(r'\bButton\b')
TABS_SELECTED = re.compile(r'==\s*(?:self\.)?(?:selection|selected\w*|active|current|state\.selected\w*)\b|'
                           r'\b(?:isSelected|on)\s*=\s*\w+(?:\.\w+)?\s*==')
DS_TAB_BAR = re.compile(r'(?<![\w.])(?:CYNightTabBar|CYDomainTabBar)\s*\(')
APP_ROOT = 'App/QuestifyApp.swift'
# Hand-drawn search fields: the search symbol drawn next to a TextField.
BACKGROUND_OPEN = re.compile(r'\.background\s*[({]')
SEARCH_GLYPH = re.compile(r'Image\(systemName:\s*"magnifyingglass"\)')
FONT_DESIGN_PATTERN = re.compile(r'\bdesign\s*:\s*\.(?:rounded|serif)\b|\.fontDesign\s*\(\s*\.(?:rounded|serif)\b')
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
    if not state['block'] and '/' not in line:
        return line
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
        if not design_system and any(p.search(code) for p in BUTTON_STYLE_PATTERNS):
            hits.append((number, BUTTON_STYLE, code.strip()))
        if not design_system and POPUP_SCRIM_PATTERN.search(code):
            hits.append((number, POPUP_SCRIM, code.strip()))
        if not colour_exempt and any(p.search(code) for p in COLOUR_PATTERNS):
            hits.append((number, RAW_COLOUR, code.strip()))
        if not design_system and LIST_STYLE_PATTERN.search(code):
            hits.append((number, LIST_STYLE, code.strip()))
        if not design_system and any(p.search(code) for p in CUSTOM_SHEET_PATTERNS):
            hits.append((number, CUSTOM_SHEET, code.strip()))
        if not font_scale and not design_system and FONT_DESIGN_PATTERN.search(code):
            hits.append((number, FONT_DESIGN, code.strip()))
        if not design_system and RAW_SEGMENTED_PATTERN.search(code):
            hits.append((number, RAW_SEGMENTED, code.strip()))
        if not design_system and rel != APP_ROOT and DS_TAB_BAR.search(code):
            hits.append((number, CUSTOM_TABS, code.strip()))
    if not design_system:
        for index, (number, code) in enumerate(lines):
            if not TABS_FOREACH.search(code):
                continue
            window = ' '.join(c for _, c in lines[index:index + 8])
            if TABS_BUTTON.search(window) and TABS_SELECTED.search(window):
                hits.append((number, CUSTOM_TABS, code.strip()))
        for index, (number, code) in enumerate(lines):
            match = BACKGROUND_OPEN.search(code)
            if match and any('CYCoverArt(' in c for c in [code[match.start():]] + [c for _, c in lines[index + 1:index + 2]]):
                hits.append((number, TEXT_ON_ART, code.strip()))
        for index, (number, code) in enumerate(lines):
            if SEARCH_GLYPH.search(code) and any('TextField(' in c for _, c in lines[index:index + 4]):
                hits.append((number, CUSTOM_SEARCH, code.strip()))
    if not design_system and rel not in TITLE_MODE_EXEMPT and not any(ANY_MODE_PATTERN.search(c) for _, c in lines):
        for number, code in lines:
            if TITLE_PATTERN.search(code):
                hits.append((number, TITLE_MODE, code.strip()))
    if is_root:
        has_large = any(ROOT_HEADER_PATTERN.search(c) or LARGE_PATTERN.search(c) for _, c in lines)
        if not has_large:
            hits.append((1, ROOT_TITLE, 'tab root without .cyRootHeader(...) / .navigationBarTitleDisplayMode(.large)'))
    return hits


TYPE_DECL = re.compile(r'^\s*(?:@[\w.]+(?:\([^)]*\))?\s+)*((?:(?:public|internal|private|fileprivate|open|final|'
                       r'indirect|nonisolated|package)\s+)*)(struct|class|enum|protocol|actor|typealias|extension)\s+'
                       r'([A-Za-z_][\w.]*)([^{]*)')
DECL_NAMES = re.compile(r'\b(?:var|let)\s+([A-Za-z_]\w*)')
DECL_TUPLES = re.compile(r'\b(?:var|let)\s*\(([^)]*)\)')
DECL_LINE = re.compile(r'\b(?:let|var)\b')
DECL_LIST = re.compile(r',\s*([A-Za-z_]\w*)\s*[:=]')
CLOSURE_BINDINGS = re.compile(r'\$([A-Za-z_]\w*)\s*(?=,[^{}]*\bin\b|\bin\b)')
CAPTURE_LIST = re.compile(r'\[\s*((?:(?:weak|unowned)\s+)?[A-Za-z_]\w*\s*=[^\[\]]*)\]\s*(?:\([^)]*\)\s*)?(?:async\s+)?in\b')
CAPTURE_NAMES = re.compile(r'(?:^|,)\s*(?:(?:weak|unowned)\s+)?([A-Za-z_]\w*)\s*=')
INOUT_NAMES = re.compile(r'\b([A-Za-z_]\w*)\s*:\s*inout\b')
CASE_NAMES = re.compile(r'^\s*(?:indirect\s+)?case\s+([^:=(]+?)\s*(?:=|\(|$)')
BINDING_USE = re.compile(r'(?<![\w$.\\])\$([a-z_]\w*)')
ASSIGN_USE = re.compile(r'(?:(?<![\w$.\\])|\bself\.)([a-z_]\w*)\s*(?:[-+*/]?=)(?!=)')
NOT_ASSIGNABLE = {'_', 'self', 'super', 'try', 'await', 'return', 'in', 'let', 'var', 'case', 'where', 'if', 'guard',
                  'else', 'some', 'any', 'inout', 'static', 'lazy', 'weak', 'private', 'fileprivate', 'public'}


def blank_strings(code, state):
    """Replaces string-literal contents with spaces (keeps the quotes); `state['multi']` tracks a `\"\"\"` block."""
    if not state.get('multi') and '"' not in code:
        return code
    out = []
    i = 0
    in_string = False
    while i < len(code):
        if state.get('multi'):
            end = code.find('\"\"\"', i)
            if end < 0:
                out.append(' ' * (len(code) - i))
                return ''.join(out)
            state['multi'] = False
            out.append(' ' * (end - i) + '\"\"\"')
            i = end + 3
            continue
        if not in_string and code.startswith('\"\"\"', i):
            state['multi'] = True
            out.append('\"\"\"')
            i += 3
            continue
        ch = code[i]
        if in_string:
            if ch == '\\\\' and i + 1 < len(code):
                out.append('  ')
                i += 2
                continue
            if ch == '"':
                in_string = False
                out.append(ch)
            else:
                out.append(' ')
            i += 1
            continue
        if ch == '"':
            in_string = True
        out.append(ch)
        i += 1
    return ''.join(out)


def module_files():
    for top in ('App', 'Core'):
        for path in sorted((ROOT / top).rglob('*.swift')):
            yield path.relative_to(ROOT).as_posix(), path


def parse_module():
    """Top-level declarations and their bodies for every App/ + Core/ file (one Swift module)."""
    decls = []   # (name, kind, access, file, line, if-stack, inheritance)
    bodies = {}  # type name -> [(file, [(line, code)])]
    globals_declared = set()
    for rel, path in module_files():
        text = path.read_text(encoding='utf-8', errors='replace')
        sstate = {}
        depth = 0
        if_stack = []
        if_counter = 0
        current = None
        for number, code in code_lines(text):
            code = blank_strings(code, sstate)
            stripped = code.strip()
            if stripped.startswith('#if'):
                if_counter += 1
                if_stack.append([f'{rel}#{if_counter}', 0])
            elif stripped.startswith('#elseif') or stripped.startswith('#else'):
                if if_stack:
                    if_stack[-1][1] += 1
            elif stripped.startswith('#endif'):
                if if_stack:
                    if_stack.pop()
            if depth == 0 and current is None:
                m = TYPE_DECL.match(code)
                if m:
                    access, kind, name, rest = m.group(1), m.group(2), m.group(3), m.group(4)
                    if kind != 'extension':
                        decls.append((name, kind, access, rel, number, tuple(tuple(x) for x in if_stack), rest))
                    if '{' in code and kind in ('struct', 'class', 'enum', 'actor', 'extension'):
                        current = (name.split('.')[-1] if kind == 'extension' else name, [])
                elif not stripped.startswith('func') and depth == 0:
                    globals_declared.update(DECL_NAMES.findall(code))
            if current is not None:
                current[1].append((number, code))
            depth += code.count('{') - code.count('}')
            if current is not None and depth <= 0:
                bodies.setdefault(current[0], []).append((rel, current[1]))
                current = None
                depth = 0
    return decls, bodies, globals_declared


def exclusive(a, b):
    """True when two `#if` stacks put the declarations in different branches of the same `#if` group."""
    branches = dict(a)
    return any(key in branches and branches[key] != branch for key, branch in b)


def duplicate_type_hits(decls):
    by_name = {}
    for d in decls:
        if d[1] == 'typealias' and '.' in d[0]:
            continue
        by_name.setdefault(d[0], []).append(d)
    hits = {}
    for name, rows in by_name.items():
        if len(rows) < 2:
            continue
        for row in rows:
            clashes = []
            for other in rows:
                if other is row or exclusive(row[5], other[5]):
                    continue
                private_row = 'private' in row[2]
                private_other = 'private' in other[2]
                if (private_row or private_other) and row[3] != other[3]:
                    continue
                clashes.append(f'{other[3]}:{other[4]}')
            if clashes:
                hits.setdefault(row[3], []).append(
                    (row[4], DUPLICATE_TYPE, f'{row[1]} {name} also declared at ' + ', '.join(clashes[:3])))
    return hits


def undeclared_state_hits(decls, bodies, globals_declared):
    views = {d[0] for d in decls if d[1] == 'struct' and re.search(r'\bView\b', d[6] or '')}
    hits = {}
    for name in sorted(views):
        parts = bodies.get(name, [])
        declared = set(globals_declared)
        for _, lines in parts:
            for _, code in lines:
                declared.update(DECL_NAMES.findall(code))
                declared.update(INOUT_NAMES.findall(code))
                declared.update(CLOSURE_BINDINGS.findall(code))
                for group in CAPTURE_LIST.findall(code):
                    declared.update(CAPTURE_NAMES.findall(group))
                if DECL_LINE.search(code):
                    declared.update(DECL_LIST.findall(code))
                for group in DECL_TUPLES.findall(code):
                    declared.update(re.findall(r'[A-Za-z_]\w*', group))
                m = CASE_NAMES.match(code)
                if m:
                    declared.update(re.findall(r'(?<![.\w])([a-z_]\w*)', m.group(1)))
        for rel, lines in parts:
            for number, code in lines:
                used = set(BINDING_USE.findall(code))
                used.update(n for n in ASSIGN_USE.findall(code) if n not in NOT_ASSIGNABLE)
                for n in sorted(used):
                    if n in declared or (n.startswith('_') and n[1:] in declared):
                        continue
                    hits.setdefault(rel, []).append(
                        (number, UNDECLARED_STATE, f'{name}: `{n}` used but never declared: {code.strip()}'))
    return hits


def module_hits():
    decls, bodies, globals_declared = parse_module()
    out = {}
    for source in (duplicate_type_hits(decls), undeclared_state_hits(decls, bodies, globals_declared)):
        for rel, rows in source.items():
            out.setdefault(rel, []).extend(rows)
    return out


def scan():
    result = {}
    for rel, path in player_files():
        hits = scan_file(rel, path.read_text(encoding='utf-8', errors='replace'))
        if hits:
            result[rel] = hits
    for rel, hits in module_hits().items():
        result.setdefault(rel, []).extend(hits)
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

    stale = []
    for rel, kinds in sorted(allowed.items()):
        present = {kind for _, kind, _ in found.get(rel, [])}
        for kind in kinds:
            if kind not in present:
                stale.append(f'{rel}: {kind}')

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
        for row in stale:
            rel, kind = row.split(': ', 1)
            allowed.get(rel, {}).pop(kind, None)
            if rel in allowed and not allowed[rel]:
                del allowed[rel]
        data['baseline'] = new
        BASELINE.write_text(json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + '\n', encoding='utf-8')
        print(f'updated {BASELINE.relative_to(ROOT)}: {sum(sum(r.values()) for r in new.values())} baselined hits')
        if not args.allow_increase and failures:
            print('note: new violations were not baselined (use --allow-increase only after review)')
        return 0 if args.allow_increase or not failures else 1

    summary = ', '.join(f'{k} {totals[k]}' for k in KINDS)
    allowed_summary = sum(allowed_totals.values())
    if stale and not failures:
        print('FAIL design consistency: stale "allowed" entries (no hit left; remove them from the baseline):')
        for row in stale:
            print(f'  {row}')
        return 1
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
