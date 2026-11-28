#!/usr/bin/env python3
"""consist-1: the one type scale and the raw-font -> token mapping, shared by

  tools/codemod_typography.py   (rewrites raw fonts to `.cyText(.token)`)
  tools/check_typography_lint.py (ratchet: no new raw fonts / custom back chevrons / hidden backs)
  tools/report_chrome.py        (lists back-button and title deviations)

The scale mirrors `CYTextStyle.spec` in App/DesignSystem/CYDesignTokens.swift. The rule card is
docs/design/type-and-chrome.md. Text scan only; it does not compile Swift.
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# token: (pt, weight, mini-program line-height, Dynamic Type style it scales with, rpx)
SCALE = {
    'display': (28, 'bold', 1.15, 'largeTitle', 56),
    'pageTitle': (29, 'bold', 1.2, 'largeTitle', 58),
    'sheetTitle': (22, 'bold', 1.3, 'title2', 44),
    'sectionTitle': (18, 'bold', 1.25, 'title3', 36),
    'cardTitle': (16, 'semibold', 1.3, 'callout', 32),
    'button': (16, 'bold', 1.3, 'callout', 32),
    'body': (14, 'regular', 1.6, 'body', 28),
    'bodyMedium': (14, 'semibold', 1.6, 'body', 28),
    'bodyCompact': (14, 'regular', 1.3, 'subheadline', 28),
    'label': (12, 'medium', 1.35, 'caption', 24),
    'meta': (12, 'regular', 1.35, 'caption', 24),
    'caption': (11, 'regular', 1.45, 'caption2', 22),
    'micro': (10, 'medium', 1.3, 'caption2', 20),
    'numericBody': (14, 'semibold', 1.3, 'body', 28),
    'numericTitle': (20, 'semibold', 1.25, 'title3', 40),
    'dataXL': (32, 'bold', 1.05, 'largeTitle', 64),
    'data2XL': (42, 'bold', 1.05, 'largeTitle', 84),
}
NUMERIC = {'numericBody', 'numericTitle', 'dataXL', 'data2XL'}
CJK_NATURAL = 1.4

TEXT_STYLES = ('largeTitle', 'title', 'title2', 'title3', 'headline', 'subheadline', 'body',
               'callout', 'footnote', 'caption', 'caption2')
STYLE_RE = '|'.join(sorted(TEXT_STYLES, key=len, reverse=True))

# Raw SwiftUI text style -> token (default, before weight/context). Comment = Apple default size.
STYLE_MAP = {
    'largeTitle': 'pageTitle',     # 34 -> 29
    'title': 'display',            # 28 -> 28
    'title2': 'sheetTitle',        # 22 -> 22
    'title3': 'sectionTitle',      # 20 -> 18
    'headline': 'cardTitle',       # 17 sb -> 16 sb
    'body': 'body',                # 17 -> 14
    'callout': 'body',             # 16 -> 14 (bold callout -> cardTitle / button)
    'subheadline': 'body',         # 15 -> 14
    'footnote': 'bodyCompact',     # 13 -> 14 tight (tertiary / time context -> meta 12)
    'caption': 'meta',             # 12 -> 12
    'caption2': 'caption',         # 11 -> 11
}

# Theme.Font member -> token (same names).
THEME_FONT_MAP = {name: name for name in (
    'pageTitle', 'sheetTitle', 'sectionTitle', 'cardTitle', 'button', 'body', 'label', 'caption', 'micro',
    'display', 'dataXL', 'data2XL')}

WEIGHTS = ('ultraLight', 'thin', 'light', 'regular', 'medium', 'semibold', 'bold', 'heavy', 'black')
EMPHASIS = {'semibold', 'bold', 'heavy', 'black'}


def size_token(size, weight):
    """Fixed point size -> nearest token. None when it is decorative (>= 48) or below the floor."""
    if size >= 48:
        return None
    heavy = weight in EMPHASIS
    if size <= 10:
        return 'micro'
    if size <= 11:
        return 'caption'
    if size <= 13:
        return 'label' if weight == 'medium' else 'meta'
    if size <= 15:
        return 'bodyMedium' if heavy or weight == 'medium' else 'body'
    if size <= 17:
        return 'cardTitle' if heavy or weight == 'medium' else 'body'
    if size <= 20:
        return 'sectionTitle'
    if size <= 24:
        return 'sheetTitle'
    if size <= 30:
        return 'pageTitle' if size >= 29 else 'display'
    if size <= 36:
        return 'dataXL'
    return 'data2XL'


def apply_weight(token, weight):
    """Fold an explicit weight into the token. Returns (token, weight_override_or_None)."""
    if weight is None:
        return token, None
    base_weight = SCALE[token][1]
    if weight == base_weight:
        return token, None
    if token in ('body', 'bodyCompact') and weight in ('medium', 'semibold', 'bold'):
        return 'bodyMedium', None
    if token == 'bodyMedium' and weight in ('medium', 'bold'):
        return 'bodyMedium', None
    if token == 'meta' and weight == 'medium':
        return 'label', None
    if token == 'label' and weight == 'regular':
        return 'meta', None
    if token == 'cardTitle' and weight == 'bold':
        return 'cardTitle', None          # mini-program card title is 600; bold folds to it
    if token in ('sectionTitle', 'sheetTitle', 'pageTitle', 'display') and weight in ('semibold', 'heavy', 'black'):
        return token, None                # titles are 700 in the mini-program
    if token == 'micro' and weight in ('regular', 'semibold'):
        return 'micro', None
    return token, weight


# ---------------------------------------------------------------- expression parsing

def balanced(text, open_index):
    """Index just past the ')' matching text[open_index] == '('. None if unbalanced."""
    depth = 0
    i = open_index
    in_str = False
    while i < len(text):
        c = text[i]
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == '(':
            depth += 1
        elif c == ')':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return None


SUFFIX_RE = re.compile(r'\.(weight\(\s*\.(\w+)\s*\)|bold\(\)|monospacedDigit\(\)|monospaced\(\)|italic\(\)|leading\(\s*\.\w+\s*\)|smallCaps\(\)|width\(\s*\.\w+\s*\))')


def parse_suffixes(rest):
    """Parse trailing `.weight(.x)` / `.bold()` / `.monospacedDigit()`. Returns (weight, mono, unsupported) or None."""
    weight = None
    mono = False
    unsupported = []
    pos = 0
    rest = rest.strip()
    while pos < len(rest):
        m = SUFFIX_RE.match(rest, pos)
        if not m:
            return None
        part = m.group(1)
        if part.startswith('weight'):
            weight = m.group(2)
        elif part == 'bold()':
            weight = 'bold'
        elif part == 'monospacedDigit()':
            mono = True
        else:
            unsupported.append(part)
        pos = m.end()
    return weight, mono, unsupported


SYSTEM_STYLE_RE = re.compile(rf'^(?:Font)?\.system\(\s*\.({STYLE_RE})\s*((?:,\s*\w+\s*:\s*\.\w+\s*)*)\)')
SYSTEM_SIZE_RE = re.compile(r'^(?:Font)?\.system\(\s*size\s*:\s*(\d+(?:\.\d+)?)\s*((?:,\s*\w+\s*:\s*\.\w+\s*)*)\)')
PLAIN_STYLE_RE = re.compile(rf'^(?:Font)?\.({STYLE_RE})\b')
THEME_RE = re.compile(r'^Theme\.Font\.(\w+)\b')
TOKEN_RE = re.compile(r'^CYTypography\.(\w+)\b')


def named_args(text):
    return dict(re.findall(r'(\w+)\s*:\s*\.(\w+)', text or ''))


class Parsed:
    """A recognised font expression."""
    def __init__(self, kind, source, weight=None, mono=False, design=None, size=None, unsupported=()):
        self.kind = kind            # 'style' | 'theme' | 'size' | 'token'
        self.source = source        # style name / Theme.Font member / point size / token
        self.weight = weight
        self.mono = mono
        self.design = design
        self.size = size
        self.unsupported = list(unsupported)


def parse_font_expr(expr):
    """Parse the argument of `.font(...)`. Returns Parsed or None (dynamic / unknown expression)."""
    e = expr.strip()
    for regex, kind in ((SYSTEM_STYLE_RE, 'style'), (SYSTEM_SIZE_RE, 'size')):
        m = regex.match(e)
        if m:
            args = named_args(m.group(2))
            suffix = parse_suffixes(e[m.end():])
            if suffix is None:
                return None
            weight, mono, unsupported = suffix
            weight = weight or args.get('weight')
            design = args.get('design')
            if kind == 'style':
                return Parsed('style', m.group(1), weight, mono, design, unsupported=unsupported)
            return Parsed('size', float(m.group(1)), weight, mono, design, size=float(m.group(1)), unsupported=unsupported)
    for regex, kind in ((THEME_RE, 'theme'), (TOKEN_RE, 'token'), (PLAIN_STYLE_RE, 'style')):
        m = regex.match(e)
        if m:
            suffix = parse_suffixes(e[m.end():])
            if suffix is None:
                return None
            weight, mono, unsupported = suffix
            return Parsed(kind, m.group(1), weight, mono, unsupported=unsupported)
    return None


# ---------------------------------------------------------------- context

ICON_HEAD = re.compile(r'\bImage\s*\(\s*systemName|\bImage\s*\(\s*"|\bImage\s*\(\s*decorative|systemImage\s*:')
TERTIARY_HINT = re.compile(r'textTertiary|\.tertiary\b|textPlaceholder|formatted\(|Date|time|Time|日期|时间')
BUTTON_HINT = re.compile(r'\bButton\b|label\s*:|CYPillButton')


def chain_head(lines, index, col):
    """Text of the modifier chain that `.font(` at lines[index][col] belongs to (head line + this line prefix)."""
    parts = [lines[index][:col]]
    i = index
    while i > 0 and lines[i].lstrip().startswith('.') and len(parts) < 12:
        i -= 1
        parts.insert(0, lines[i])
    return '\n'.join(parts)


def is_icon(lines, index, col):
    head = chain_head(lines, index, col)
    # The nearest view constructor before the chain decides; `Label` with systemImage counts as text.
    if re.search(r'\bLabel\s*\(', head):
        return False
    return bool(ICON_HEAD.search(head))


def context_text(lines, index, before=3, after=3):
    lo = max(0, index - before)
    hi = min(len(lines), index + after + 1)
    return '\n'.join(lines[lo:hi])


def map_parsed(parsed, lines, index, col):
    """Return (token, weight_override, mono, confidence, note) or (None, reason) for a human."""
    if parsed.kind == 'token':
        return None, 'already a token'
    if 'monospaced()' in parsed.unsupported:
        return None, 'monospaced (code / ID / receipt text); keep, or use `.cyText(.meta)` + `.monospaced()` by hand'
    if parsed.unsupported:
        return None, 'unsupported modifier ' + ', '.join(parsed.unsupported)
    ctx = context_text(lines, index)
    if parsed.kind == 'theme':
        token = THEME_FONT_MAP.get(parsed.source)
        if token is None:
            return None, 'unknown Theme.Font member'
        token, weight = apply_weight(token, parsed.weight)
        return token, weight, parsed.mono, 'exact', 'Theme.Font.%s' % parsed.source
    if parsed.kind == 'size':
        if parsed.design == 'monospaced':
            return None, 'monospaced design (code / ticket number)'
        token = size_token(parsed.size, parsed.weight or 'regular')
        if token is None:
            return None, 'decorative size %g pt (illustration / emoji / glyph); keep or use an image' % parsed.size
        if parsed.design == 'rounded' or parsed.mono:
            if token in ('body', 'bodyMedium', 'bodyCompact'):
                token = 'numericBody'
            elif token in ('display', 'pageTitle', 'dataXL'):
                token = 'dataXL'
        token, weight = apply_weight(token, parsed.weight)
        if token in NUMERIC:
            weight = None
        exact = SCALE[token][0] == int(parsed.size)
        return token, weight, parsed.mono and token not in NUMERIC, 'exact' if exact else 'nearest', '%g pt' % parsed.size
    # raw text style
    style = parsed.source
    token = STYLE_MAP[style]
    confidence = 'default'
    if style == 'footnote' and TERTIARY_HINT.search(ctx):
        token, confidence = 'meta', 'context'
    if style == 'callout' and parsed.weight in EMPHASIS:
        token, confidence = ('button', 'context') if BUTTON_HINT.search(ctx) else ('cardTitle', 'default')
    if style == 'body' and parsed.weight in EMPHASIS:
        token = 'cardTitle'
    if style in ('subheadline', 'body') and parsed.weight in EMPHASIS and token == 'body':
        token = 'bodyMedium'
    if parsed.design == 'monospaced':
        return None, 'monospaced design (code / ticket number)'
    if parsed.design == 'rounded' or parsed.mono:
        if token in ('body', 'bodyMedium', 'bodyCompact'):
            token, confidence = 'numericBody', 'context'
        elif token in ('pageTitle', 'display', 'sheetTitle'):
            token, confidence = 'dataXL', 'context'
        elif parsed.design == 'rounded':
            return None, 'rounded design on .%s (number?)' % style
    if parsed.design not in (None, 'default', 'rounded'):
        return None, 'design .%s' % parsed.design
    if token == 'cardTitle' and parsed.weight is None and style == 'headline':
        weight = None
    else:
        token, weight = apply_weight(token, parsed.weight) if token not in NUMERIC else (token, None)
    if style in ('caption', 'caption2', 'title2', 'title') and confidence == 'default':
        confidence = 'exact'
    return token, weight, parsed.mono and token not in NUMERIC, confidence, '.%s' % style


def render_cytext(token, weight, mono):
    args = ['.' + token]
    if weight:
        args.append('weight: .' + weight)
    if mono:
        args.append('monospacedDigit: true')
    return '.cyText(%s)' % ', '.join(args)


# ---------------------------------------------------------------- scanning helpers

def swift_files(root, include_design_system=True):
    app = root / 'App'
    out = []
    for path in sorted(app.rglob('*.swift')):
        rel = path.relative_to(root).as_posix()
        if rel.startswith('App/Theme/') or rel == 'App/DesignSystem/CYDesignTokens.swift':
            continue
        if not include_design_system and rel.startswith('App/DesignSystem/'):
            continue
        out.append((rel, path))
    return out


def strip_line_comment(line):
    """Remove a trailing // comment that is not inside a string literal."""
    in_str = False
    i = 0
    while i < len(line):
        c = line[i]
        if in_str:
            if c == '\\':
                i += 2
                continue
            if c == '"':
                in_str = False
        elif c == '"':
            in_str = True
        elif c == '/' and line.startswith('//', i):
            return line[:i] + ' ' * (len(line) - i)
        i += 1
    return line


def code_lines(text):
    """Lines with // comments and /* */ blocks blanked (keeps line numbers)."""
    text = re.sub(r'/\*.*?\*/', lambda m: re.sub(r'[^\n]', ' ', m.group(0)), text, flags=re.S)
    return [strip_line_comment(line) for line in text.split('\n')]
