#!/usr/bin/env python3
"""Static accessibility lint for SwiftUI Button and Image values.

This is a text scan, not a Swift compiler or a VoiceOver pass. It flags only
controls whose source proves the gap:

- A Button whose label has no .accessibilityLabel, no accessibility
  representation, and no visible text VoiceOver would speak.
- An Image VoiceOver can land on that has none of those, and is not
  Image(decorative:) or accessibilityHidden(true).
- A tap target (Button, NavigationLink, Link, Menu, ShareLink, or a view with
  onTapGesture / TapGesture) whose own frame declares a dimension under 44pt.

A custom view, a system control whose label is not in this file (Toggle,
Slider, Picker, TextField, EditButton, …), and anything the scan cannot see
are left alone. An image inside a Button is not a separate element; the
Button is judged instead. An image next to text is still flagged when
VoiceOver would focus it on its own. Combined or ignored accessibility
containers that already have a spoken label are not flagged.

The current tree is the ratchet. tools/a11y_lint_baseline.txt lists one
signature per existing finding. The check fails only when a signature shows
up more times than the baseline. Fixing a finding (its signature disappears)
passes. Do not add baseline lines to hide a new violation.

If the baseline file is absent, the check prints SKIP and exits 0 so a gates
job can call it before the baseline is merged.

    python3 -B tools/check_a11y_lint.py
    python3 -B tools/check_a11y_lint.py --report
    python3 -B tools/check_a11y_lint.py --write-baseline

Gates step, once this file is on the branch the gates job checks out:

    python3 -B tools/check_a11y_lint.py
"""
from __future__ import annotations

import argparse
import sys
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASELINE_PATH = ROOT / 'tools' / 'a11y_lint_baseline.txt'
BASELINE_NAME = 'tools/a11y_lint_baseline.txt'
MIN_TAP = 44.0
SCAN_ROOTS = ('App',)

TEXT_VIEWS = {'Text', 'Label', 'LabeledContent'}
CONTAINERS = {
    'HStack', 'VStack', 'ZStack', 'Group', 'Grid', 'GridRow',
    'LazyVStack', 'LazyHStack', 'LazyVGrid', 'LazyHGrid',
    'ScrollView', 'ViewThatFits', 'GeometryReader',
    'Section', 'Form', 'List', 'ForEach',
    'ToolbarItem', 'ToolbarItemGroup', 'ControlGroup',
    'NavigationStack', 'NavigationSplitView', 'NavigationView', 'TabView',
    'overlay', 'background', 'mask', 'sheet', 'fullScreenCover', 'popover',
    'safeAreaInset', 'toolbar', 'navigationDestination', 'safeAreaBar',
    'Preview', 'View',
}
NON_TEXT = {
    'Image', 'Spacer', 'Divider', 'EmptyView', 'Color', 'Circle', 'Capsule',
    'Rectangle', 'RoundedRectangle', 'Ellipse', 'UnevenRoundedRectangle',
    'LinearGradient', 'RadialGradient', 'AngularGradient', 'ProgressView',
    'Path', 'Canvas', 'CYColor',
}
ABSORBING = {'Button', 'NavigationLink', 'Link', 'Menu', 'ShareLink', 'Label'}
TAP_CONTROLS = {'Button', 'NavigationLink', 'Link', 'Menu', 'ShareLink'}
SYSTEM_SKIP = {
    'Toggle', 'Slider', 'Stepper', 'Picker', 'DatePicker', 'ProgressView',
    'Gauge', 'ColorPicker', 'EditButton', 'PasteButton', 'RenameButton',
    'SecureField', 'TextField', 'TextEditor', 'UIButton', 'UISwitch',
    'UISlider', 'UIDatePicker',
}
NON_VIEW = {
    'onTapGesture', 'onLongPressGesture', 'onAppear', 'onDisappear', 'task',
    'onChange', 'onSubmit', 'onReceive', 'onContinuousHover', 'onHover',
    'accessibilityAction', 'accessibilityAdjustableAction', 'accessibilityScrollAction',
    'refreshable', 'onDrop', 'onDrag', 'simultaneousGesture', 'highPriorityGesture',
    'gesture', 'swipeActions', 'animation', 'transaction', 'withAnimation',
}
KEYWORDS = {
    'if', 'else', 'switch', 'case', 'default', 'guard', 'for', 'while', 'do',
    'return', 'let', 'var', 'func', 'struct', 'class', 'enum', 'protocol',
    'extension', 'import', 'where', 'in', 'as', 'is', 'try', 'throw', 'throws',
    'catch', 'true', 'false', 'nil', 'self', 'Self', 'some', 'any', 'associatedtype',
    'typealias', 'init', 'deinit', 'subscript', 'operator', 'precedencegroup',
    'inout', 'fallthrough', 'continue', 'break', 'defer', 'repeat', 'await',
}

# Point sizes this tree actually declares. Unknown names are not guessed.
KNOWN_POINTS = {
    'CYSpacing.xxs': 2, 'CYSpacing.xs': 4, 'CYSpacing.s1_5': 6, 'CYSpacing.sm': 8,
    'CYSpacing.s2_5': 10, 'CYSpacing.md': 12, 'CYSpacing.s3_5': 14, 'CYSpacing.lg': 16,
    'CYSpacing.xl': 20, 'CYSpacing.xxl': 24, 'CYSpacing.xxxl': 32, 'CYSpacing.hero': 40,
    'CYSpacing.jumbo': 48, 'CYSpacing.pageHorizontal': 16, 'CYSpacing.minTouchTarget': 44,
    'Theme.Space.s1': 4, 'Theme.Space.s1_5': 6, 'Theme.Space.s2': 8, 'Theme.Space.s2_5': 10,
    'Theme.Space.s3': 12, 'Theme.Space.s3_5': 14, 'Theme.Space.s4': 16, 'Theme.Space.s5': 24,
    'Theme.Space.s6': 32, 'Theme.Space.s7': 40, 'Theme.Space.s8': 48, 'Theme.Space.pageX': 16,
    'Theme.MiniProgramChrome.minHit': 44,
    'Theme.MiniProgramChrome.tabIconSize': 32,
    'Theme.MiniProgramChrome.tabBarContentHeight': 52,
    'CurA11y.hit': 44,
    'EditorKitMetric.hit': 44, 'EditorKitMetric.fieldHeight': 44,
    'EditorKitMetric.areaHeight': 88, 'EditorKitMetric.rowMinHeight': 50,
    'EditorKitMetric.numberFieldWidth': 132,
}

HOT_SYMBOLS = (
    'xmark', 'ellipsis', 'trash', 'bell', 'plus', 'gearshape', 'gear',
    'paperplane', 'square.and.arrow.up', 'magnifyingglass', 'pencil',
    'chevron.left', 'chevron.right', 'chevron.backward', 'info.circle',
    'pin', 'arrow.clockwise', 'minus.circle', 'arrow.up', 'arrow.down',
    'star', 'heart', 'bag', 'bubble',
)


class Tok:
    __slots__ = ('kind', 'value', 'start', 'end', 'line')

    def __init__(self, kind, value, start, end, line):
        self.kind = kind
        self.value = value
        self.start = start
        self.end = end
        self.line = line


class Finding:
    __slots__ = ('kind', 'path', 'line', 'detail', 'signature', 'symbol', 'points')

    def __init__(self, kind, path, line, detail, signature, symbol='', points=None):
        self.kind = kind
        self.path = path
        self.line = line
        self.detail = detail
        self.signature = signature
        self.symbol = symbol
        self.points = points


def scan_string(text, i):
    """Return the index just past a Swift string starting at i, or None."""
    n = len(text)
    h = 0
    while i + h < n and text[i + h] == '#':
        h += 1
    q = i + h
    if q >= n or text[q] != '"':
        return None
    triple = text.startswith('"""', q)
    qlen = 3 if triple else 1
    j = q + qlen
    end_mark = '"' * qlen + '#' * h
    while j < n:
        if text[j] == '\\':
            k = j + 1
            hashes = 0
            while k < n and text[k] == '#':
                hashes += 1
                k += 1
            if hashes == h and k < n and text[k] == '(':
                j = skip_balanced_any(text, k)
                continue
            j = min(n, j + 2)
            continue
        if text.startswith(end_mark, j):
            return j + len(end_mark)
        j += 1
    return n


def skip_balanced_any(text, i):
    """i points at '('. Return the index just past the matching ')'."""
    n = len(text)
    stack = ['(']
    i += 1
    opens = {'(': ')', '[': ']', '{': '}'}
    closes = {')': '(', ']': '[', '}': '{'}
    while i < n and stack:
        c = text[i]
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            nl = text.find('\n', i)
            i = n if nl < 0 else nl
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            end = text.find('*/', i + 2)
            i = n if end < 0 else end + 2
            continue
        if c == '#':
            end = scan_string(text, i)
            if end is not None and end > i:
                i = end
                continue
        if c == '"':
            end = scan_string(text, i)
            i = n if end is None else end
            continue
        if c in opens:
            stack.append(c)
            i += 1
            continue
        if c in closes:
            if stack and stack[-1] == closes[c]:
                stack.pop()
            i += 1
            if not stack:
                return i
            continue
        i += 1
    return i


def tokenize(text):
    tokens = []
    i = 0
    n = len(text)
    line = 1
    multi = ('...', '..<', '->', '??', '==', '!=', '<=', '>=', '&&', '||', '+=', '-=', '?.')
    while i < n:
        c = text[i]
        if c in ' \t\r':
            i += 1
            continue
        if c == '\n':
            line += 1
            i += 1
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '/':
            j = text.find('\n', i)
            i = n if j < 0 else j
            continue
        if c == '/' and i + 1 < n and text[i + 1] == '*':
            j = text.find('*/', i + 2)
            line += text.count('\n', i, n if j < 0 else j + 2)
            i = n if j < 0 else j + 2
            continue
        if c == '#' or c == '"':
            end = scan_string(text, i)
            if end is not None and end > i:
                tokens.append(Tok('str', text[i:end], i, end, line))
                line += text.count('\n', i, end)
                i = end
                continue
        if c == '#' and i + 1 < n and (text[i + 1].isalpha() or text[i + 1] == '_'):
            j = i + 1
            while j < n and (text[j].isalnum() or text[j] == '_'):
                j += 1
            tokens.append(Tok('id', text[i + 1:j], i, j, line))
            i = j
            continue
        if c.isalpha() or c == '_':
            j = i + 1
            while j < n and (text[j].isalnum() or text[j] == '_'):
                j += 1
            tokens.append(Tok('id', text[i:j], i, j, line))
            i = j
            continue
        if c.isdigit():
            j = i + 1
            while j < n and (text[j].isdigit() or text[j] == '_'):
                j += 1
            if j < n and text[j] == '.' and j + 1 < n and text[j + 1].isdigit():
                j += 1
                while j < n and (text[j].isdigit() or text[j] == '_'):
                    j += 1
            tokens.append(Tok('num', text[i:j].replace('_', ''), i, j, line))
            i = j
            continue
        matched = False
        for op in multi:
            if text.startswith(op, i):
                tokens.append(Tok('op', op, i, i + len(op), line))
                i += len(op)
                matched = True
                break
        if matched:
            continue
        tokens.append(Tok('op', c, i, i + 1, line))
        i += 1
    return tokens


def is_op(tok, value):
    return tok is not None and tok.kind == 'op' and tok.value == value


def skip_bracket(tokens, i, limit, open_ch, close_ch):
    depth = 0
    while i < limit:
        if is_op(tokens[i], open_ch):
            depth += 1
        elif is_op(tokens[i], close_ch):
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return i


def parse_arg_list(tokens, i, limit):
    """tokens[i] is '('. Return (args, index after ')')."""
    if i >= limit or not is_op(tokens[i], '('):
        return [], i
    i += 1
    args = []
    while i < limit and not is_op(tokens[i], ')'):
        label = None
        if (tokens[i].kind == 'id' and i + 1 < limit and is_op(tokens[i + 1], ':')
                and tokens[i].value not in KEYWORDS):
            label = tokens[i].value
            i += 2
        start = i
        depth_p = depth_b = depth_k = 0
        while i < limit:
            v = tokens[i].value if tokens[i].kind == 'op' else ''
            if v == '(' :
                depth_p += 1
            elif v == ')':
                if depth_p == 0 and depth_b == 0 and depth_k == 0:
                    break
                depth_p -= 1
            elif v == '{':
                depth_b += 1
            elif v == '}':
                depth_b -= 1
            elif v == '[':
                depth_k += 1
            elif v == ']':
                depth_k -= 1
            elif v == ',' and depth_p == depth_b == depth_k == 0:
                break
            i += 1
        args.append((label, start, i))
        if i < limit and is_op(tokens[i], ','):
            i += 1
    if i < limit and is_op(tokens[i], ')'):
        i += 1
    return args, i


def parse_trailing(tokens, i, limit):
    closures = []
    while i < limit:
        label = None
        k = i
        if (tokens[k].kind == 'id' and k + 2 < limit and is_op(tokens[k + 1], ':')
                and is_op(tokens[k + 2], '{') and tokens[k].value not in KEYWORDS):
            label = tokens[k].value
            k += 2
        if k < limit and is_op(tokens[k], '{'):
            end = skip_bracket(tokens, k, limit, '{', '}')
            closures.append((label, k, end - 1 if end > k else k))
            i = end
            continue
        break
    return closures, i


def parse_modifiers(tokens, i, limit):
    mods = []
    while i + 1 < limit and is_op(tokens[i], '.') and tokens[i + 1].kind == 'id':
        name = tokens[i + 1].value
        j = i + 2
        args = []
        if j < limit and is_op(tokens[j], '('):
            args, j = parse_arg_list(tokens, j, limit)
        closures, j = parse_trailing(tokens, j, limit)
        mods.append((name, args, closures, i, j))
        i = j
    return mods, i


def parse_call(tokens, i, limit):
    """Parse a call whose name is tokens[i]. Return dict or None."""
    if i >= limit or tokens[i].kind != 'id':
        return None
    name = tokens[i].value
    name_i = i
    j = i + 1
    args = []
    if j < limit and is_op(tokens[j], '('):
        args, j = parse_arg_list(tokens, j, limit)
    closures, j = parse_trailing(tokens, j, limit)
    if j == i + 1 and not args and not closures:
        return None
    mods, j = parse_modifiers(tokens, j, limit)
    return {
        'name': name,
        'name_i': name_i,
        'args': args,
        'closures': closures,  # (label, open_i, close_i)
        'mods': mods,          # (name, args, closures, start, end)
        'end': j,
    }


def is_word_call(tokens, i):
    if i < 0 or i >= len(tokens) or tokens[i].kind != 'id':
        return False
    if tokens[i].value in KEYWORDS:
        return False
    if i > 0 and is_op(tokens[i - 1], '.'):
        return False
    if i + 1 >= len(tokens):
        return False
    nxt = tokens[i + 1]
    return is_op(nxt, '(') or is_op(nxt, '{')


def arg_is_closure(tokens, arg):
    _label, start, end = arg
    return start < end and is_op(tokens[start], '{')


def string_contents(tok):
    raw = tok.value
    h = 0
    while h < len(raw) and raw[h] == '#':
        h += 1
    body = raw[h:]
    if body.startswith('"""'):
        body = body[3:]
        if body.endswith('#' * h) and h:
            body = body[:-h]
        if body.endswith('"""'):
            body = body[:-3]
    elif body.startswith('"'):
        body = body[1:]
        if body.endswith('#' * h) and h:
            body = body[:-h]
        if body.endswith('"'):
            body = body[:-1]
    if '\\(' in body or '\\#' in body:
        return None
    return body


def literal_is_blank(tokens, start, end):
    toks = [t for t in tokens[start:end] if not (t.kind == 'op' and t.value in (',',))]
    if len(toks) == 1 and toks[0].kind == 'str':
        contents = string_contents(toks[0])
        return contents is not None and contents.strip() == ''
    return False


def modifier_supplies_label(mod, tokens):
    name, args, closures, _start, _end = mod
    if name == 'accessibilityRepresentation':
        return True
    # pageTemplateControl / pageTemplateGroupedCard apply .accessibilityLabel.
    if name in ('accessibilityLabel', 'pageTemplateControl', 'pageTemplateGroupedCard'):
        if name == 'accessibilityLabel' and args and literal_is_blank(tokens, args[0][1], args[0][2]) and len(args) == 1:
            return False
        return True
    return False


def modifier_hides(mod, tokens):
    name, args, _closures, _start, _end = mod
    if name != 'accessibilityHidden' or not args:
        return False
    _label, start, end = args[0]
    return start < end and tokens[start].kind == 'id' and tokens[start].value == 'true' and end == start + 1


def element_behavior(mod, tokens):
    name, args, _closures, _start, _end = mod
    if name != 'accessibilityElement':
        return None
    for label, start, end in args:
        if label == 'children':
            piece = ''.join(t.value for t in tokens[start:end])
            if 'contain' in piece:
                return 'contain'
            if 'combine' in piece:
                return 'combine'
            if 'ignore' in piece:
                return 'ignore'
    return 'ignore'


def chain_supplies_label(mods, tokens):
    return any(modifier_supplies_label(m, tokens) or modifier_hides(m, tokens) for m in mods)


def closure_body(closure):
    _label, open_i, close_i = closure
    return open_i + 1, close_i


def find_closure(closures, label):
    for c in closures:
        if c[0] == label:
            return c
    return None


def norm(text):
    collapsed = ' '.join(text.split())
    if len(collapsed) > 180:
        return collapsed[:177] + '...'
    return collapsed


def signature(kind, path, snippet):
    return f'{kind}\t{path}\t{norm(snippet)}'


def source_slice(text, tokens, start, end):
    if start >= end or start >= len(tokens):
        return ''
    a = tokens[start].start
    b = tokens[end - 1].end if end - 1 < len(tokens) else tokens[-1].end
    return text[a:b]


def system_symbol(text):
    marker = 'systemName:'
    at = text.find(marker)
    if at < 0:
        marker = 'systemImage:'
        at = text.find(marker)
    if at < 0:
        return ''
    rest = text[at + len(marker):]
    quote = rest.find('"')
    if quote < 0:
        return ''
    rest = rest[quote + 1:]
    stop = rest.find('"')
    if stop < 0:
        return ''
    return rest[:stop]


# --- point values -----------------------------------------------------------

INFINITE = object()


def eval_range(tokens, start, end):
    """Return a float, INFINITE, or None when the expression is not a known size."""
    toks = tokens[start:end]
    if not toks:
        return None
    if len(toks) == 2 and is_op(toks[0], '.') and toks[1].kind == 'id' and toks[1].value == 'infinity':
        return INFINITE
    if len(toks) == 1 and toks[0].kind == 'id' and toks[0].value == 'infinity':
        return INFINITE
    value, pos = parse_sum(toks, 0)
    if value is None or pos != len(toks):
        return None
    return value


def parse_sum(toks, i):
    left, i = parse_prod(toks, i)
    if left is None:
        return None, i
    while i < len(toks) and toks[i].kind == 'op' and toks[i].value in ('+', '-'):
        op = toks[i].value
        right, i = parse_prod(toks, i + 1)
        if right is None or left is INFINITE or right is INFINITE:
            return None, i
        left = left + right if op == '+' else left - right
    return left, i


def parse_prod(toks, i):
    left, i = parse_unary(toks, i)
    if left is None:
        return None, i
    while i < len(toks) and toks[i].kind == 'op' and toks[i].value in ('*', '/'):
        op = toks[i].value
        right, i = parse_unary(toks, i + 1)
        if right is None or left is INFINITE or right is INFINITE or (op == '/' and right == 0):
            return None, i
        left = left * right if op == '*' else left / right
    return left, i


def parse_unary(toks, i):
    if i >= len(toks):
        return None, i
    if toks[i].kind == 'op' and toks[i].value in ('+', '-'):
        value, i = parse_unary(toks, i + 1)
        if value is None or value is INFINITE:
            return None, i
        return (value if toks[i - 1].value == '+' else -value), i
    return parse_primary(toks, i)


def parse_primary(toks, i):
    if i >= len(toks):
        return None, i
    tok = toks[i]
    if tok.kind == 'num':
        return float(tok.value), i + 1
    if tok.kind == 'id' and tok.value in ('CGFloat', 'Double', 'Float', 'Int') and i + 1 < len(toks) and is_op(toks[i + 1], '('):
        depth = 0
        j = i + 1
        while j < len(toks):
            if is_op(toks[j], '('):
                depth += 1
            elif is_op(toks[j], ')'):
                depth -= 1
                if depth == 0:
                    inner, pos = parse_sum(toks, i + 2)
                    if inner is None or pos != j:
                        return None, j + 1
                    return inner, j + 1
            j += 1
        return None, len(toks)
    if tok.kind == 'id' and tok.value in ('min', 'max') and i + 1 < len(toks) and is_op(toks[i + 1], '('):
        # min(a, b) / max(a, b) with two known arguments.
        close = i + 1
        depth = 0
        while close < len(toks):
            if is_op(toks[close], '('):
                depth += 1
            elif is_op(toks[close], ')'):
                depth -= 1
                if depth == 0:
                    break
            close += 1
        parts = split_top_commas(toks, i + 2, close)
        if len(parts) != 2:
            return None, close + 1
        a, apos = parse_sum(toks, parts[0][0])
        b, bpos = parse_sum(toks, parts[1][0])
        if a is None or b is None or a is INFINITE or b is INFINITE or apos != parts[0][1] or bpos != parts[1][1]:
            return None, close + 1
        return (a if (a < b) == (tok.value == 'min') else b), close + 1
    if tok.kind == 'id':
        j = i
        name = []
        while j < len(toks):
            if toks[j].kind != 'id':
                break
            name.append(toks[j].value)
            if j + 2 < len(toks) and is_op(toks[j + 1], '.') and toks[j + 2].kind == 'id':
                j += 2
                continue
            j += 1
            break
        key = '.'.join(name)
        if key in KNOWN_POINTS:
            return KNOWN_POINTS[key], j
        return None, j
    if is_op(tok, '.') and i + 1 < len(toks) and toks[i + 1].kind == 'id' and toks[i + 1].value == 'infinity':
        return INFINITE, i + 2
    return None, i + 1


def split_top_commas(toks, start, end):
    parts = []
    depth_p = depth_b = depth_k = 0
    cur = start
    i = start
    while i < end:
        v = toks[i].value if toks[i].kind == 'op' else ''
        if v == '(':
            depth_p += 1
        elif v == ')':
            depth_p -= 1
        elif v == '{':
            depth_b += 1
        elif v == '}':
            depth_b -= 1
        elif v == '[':
            depth_k += 1
        elif v == ']':
            depth_k -= 1
        elif v == ',' and depth_p == depth_b == depth_k == 0:
            parts.append((cur, i))
            cur = i + 1
        i += 1
    parts.append((cur, end))
    return parts


def frame_dims(mod, tokens):
    name, args, _closures, _start, _end = mod
    if name != 'frame':
        return {}
    dims = {}
    for label, start, end in args:
        if label not in ('width', 'height', 'minWidth', 'minHeight', 'maxWidth', 'maxHeight'):
            continue
        dims[label] = eval_range(tokens, start, end)
    return dims


def is_points(value):
    return value is not INFINITE and isinstance(value, (int, float)) and not isinstance(value, bool)


def small_dimensions(frames):
    """frames are inner to outer. A later frame replaces the dimensions it sets.

    A minimum of 44 clears a smaller fixed size inside it. An explicit value
    under 44 that nothing outer expands is a declared small tap target.
    Unknown sizes are not treated as small.
    """
    fixed = {'width': None, 'height': None}
    minimum = {'width': None, 'height': None}
    maximum = {'width': None, 'height': None}

    def axis_of(key):
        return 'width' if 'idth' in key or key == 'width' else 'height'

    for dims in frames:
        for key, value in dims.items():
            axis = axis_of(key)
            if value is None:
                if key.startswith('max'):
                    maximum[axis] = None
                elif key.startswith('min'):
                    minimum[axis] = None
                else:
                    fixed[axis] = None
                continue
            if value is INFINITE:
                if key.startswith('max'):
                    maximum[axis] = INFINITE
                continue
            if not is_points(value):
                continue
            if key in ('width', 'height'):
                fixed[key] = float(value)
            elif key in ('minWidth', 'minHeight'):
                minimum[axis] = float(value)
            elif key in ('maxWidth', 'maxHeight'):
                maximum[axis] = float(value)
    small = []
    for axis in ('width', 'height'):
        if is_points(maximum[axis]) and maximum[axis] < MIN_TAP:
            small.append(('maxWidth' if axis == 'width' else 'maxHeight', maximum[axis]))
            continue
        floor = None
        if is_points(minimum[axis]):
            floor = minimum[axis]
        if is_points(fixed[axis]):
            floor = fixed[axis] if floor is None else max(floor, fixed[axis])
        if floor is not None and floor < MIN_TAP:
            if is_points(minimum[axis]) and (not is_points(fixed[axis]) or minimum[axis] >= fixed[axis]):
                label = 'minWidth' if axis == 'width' else 'minHeight'
            else:
                label = 'width' if axis == 'width' else 'height'
            small.append((label, floor))
    return small


# --- view classification ----------------------------------------------------

def skip_decl(tokens, i, limit):
    i += 1
    while i < limit and not is_op(tokens[i], '='):
        if is_op(tokens[i], '{'):
            i = skip_bracket(tokens, i, limit, '{', '}')
        elif is_op(tokens[i], '('):
            i = skip_bracket(tokens, i, limit, '(', ')')
        elif is_op(tokens[i], '['):
            i = skip_bracket(tokens, i, limit, '[', ']')
        elif tokens[i].kind == 'id' and tokens[i].value in ('var', 'let'):
            break
        else:
            i += 1
    if i < limit and is_op(tokens[i], '='):
        _kind, frames, i = classify_expr(tokens, i + 1, limit)
        return i, frames
    return i, []


def classify_body(tokens, start, end):
    """Return ('text'|'unknown'|'unlabeled', frames of the sole root expression)."""
    rank = {'empty': 0, 'unlabeled': 1, 'unknown': 2, 'text': 3}
    result = 'empty'
    i = start
    root_frames = []
    saw_view = 0
    while i < end:
        tok = tokens[i]
        if tok.kind == 'id' and tok.value in ('let', 'var'):
            i, _frames = skip_decl(tokens, i, end)
            continue
        if tok.kind == 'id' and tok.value == 'return':
            i += 1
            continue
        if tok.kind == 'id' and tok.value == 'if':
            kind, i = classify_if(tokens, i, end)
            result = kind if rank[kind] > rank[result] else result
            saw_view += 1
            if result == 'text':
                return 'text', []
            continue
        if tok.kind == 'id' and tok.value in ('switch', 'guard', 'for', 'while', 'do'):
            return 'unknown', []
        if is_op(tok, '}'):
            break
        kind, frames, nxt = classify_expr(tokens, i, end)
        if nxt <= i:
            i += 1
            continue
        saw_view += 1
        if saw_view == 1:
            root_frames = frames
        else:
            root_frames = []
        result = kind if rank[kind] > rank[result] else result
        i = nxt
        if result == 'text':
            return 'text', []
    if result == 'empty':
        return 'unlabeled', root_frames
    if saw_view != 1:
        root_frames = []
    return result, root_frames


def classify_if(tokens, i, limit):
    """Merge every branch. Text or unknown in any branch wins (do not flag)."""
    rank = {'empty': 0, 'unlabeled': 1, 'unknown': 2, 'text': 3}
    result = 'empty'
    # Walk forward consuming if / else if / else and the braces we can see.
    while i < limit and tokens[i].kind == 'id' and tokens[i].value in ('if', 'else'):
        if tokens[i].value == 'else' and i + 1 < limit and tokens[i + 1].kind == 'id' and tokens[i + 1].value == 'if':
            i += 1
        i += 1
        if i < limit and tokens[i].kind == 'id' and tokens[i].value == 'if':
            continue
        # skip the condition until a brace when this is `if`
        if tokens[i - 1].value == 'if' or (i >= 2 and tokens[i - 1].value == 'if'):
            while i < limit and not is_op(tokens[i], '{'):
                if is_op(tokens[i], '('):
                    i = skip_bracket(tokens, i, limit, '(', ')')
                else:
                    i += 1
                    if i > limit:
                        return 'unknown', i
        if i >= limit or not is_op(tokens[i], '{'):
            return 'unknown', i
        close = skip_bracket(tokens, i, limit, '{', '}')
        kind, _frames = classify_body(tokens, i + 1, close - 1)
        result = kind if rank[kind] > rank[result] else result
        i = close
        if i < limit and tokens[i].kind == 'id' and tokens[i].value == 'else':
            continue
        break
    return result, i


def classify_expr(tokens, i, limit):
    if i >= limit:
        return 'unknown', [], i
    # Ternary and other expressions we do not fully see: do not flag.
    kind = 'unknown'
    frames = []
    if tokens[i].kind == 'id' and is_word_call(tokens, i):
        call = parse_call(tokens, i, limit)
        if call is None:
            return 'unknown', [], i + 1
        kind = kind_of_call(call, tokens)
        frames = expr_frames(call, tokens)
        if chain_supplies_label(call['mods'], tokens):
            kind = 'text'
        return kind, frames, call['end']
    if tokens[i].kind == 'id' and tokens[i].value in ('Color', 'CYColor') and i + 1 < limit and is_op(tokens[i + 1], '.'):
        _mods, end = parse_modifiers(tokens, i + 1, limit)
        # Color.red starts with `.` after the name; parse_modifiers expects the dot.
        return 'unlabeled', [], end
    # Bare name or member: the view type is not visible here.
    end = i + 1
    while end < limit and is_op(tokens[end], '.') and end + 1 < limit and tokens[end + 1].kind == 'id':
        end += 2
        if end < limit and is_op(tokens[end], '('):
            _args, end = parse_arg_list(tokens, end, limit)
        closures, end = parse_trailing(tokens, end, limit)
        if closures:
            break
    return 'unknown', [], end


def kind_of_call(call, tokens):
    name = call['name']
    if name in TEXT_VIEWS:
        if text_call_is_blank(call, tokens):
            return 'unlabeled'
        return 'text'
    if name in ABSORBING:
        # A nested control contributes its own label when it has one.
        if control_is_labeled(call, tokens):
            return 'text'
        return 'unknown'
    if name in NON_TEXT:
        return 'unlabeled'
    if name in CONTAINERS or name in ('Group',):
        rank = {'empty': 0, 'unlabeled': 1, 'unknown': 2, 'text': 3}
        result = 'empty'
        interesting = [c for c in call['closures'] if c[0] in (None, 'content')]
        if not interesting:
            interesting = call['closures'][:1]
        for closure in interesting:
            body_s, body_e = closure_body(closure)
            kind, _frames = classify_body(tokens, body_s, body_e)
            result = kind if rank[kind] > rank[result] else result
        if result == 'empty':
            return 'unlabeled'
        return result
    return 'unknown'


def text_call_is_blank(call, tokens):
    if not call['args']:
        return False
    texts = []
    for label, start, end in call['args']:
        if label in ('tableName', 'comment', 'bundle'):
            continue
        if literal_is_blank(tokens, start, end):
            texts.append(True)
        elif start < end and tokens[start].kind == 'str':
            contents = string_contents(tokens[start])
            if contents is None:
                return False
            texts.append(contents.strip() == '')
        else:
            return False
    return bool(texts) and all(texts)


def expr_frames(call, tokens):
    """Frames that size this expression, inner first."""
    own = [frame_dims(m, tokens) for m in call['mods'] if m[0] == 'frame']
    name = call['name']
    if name in CONTAINERS:
        closures = [c for c in call['closures'] if c[0] in (None, 'content')] or call['closures'][:1]
        if len(closures) == 1:
            body_s, body_e = closure_body(closures[0])
            _kind, inner = classify_body(tokens, body_s, body_e)
            if inner:
                return inner + own
    if name in NON_TEXT or name in TEXT_VIEWS or name in ABSORBING:
        return own
    return own


def control_is_labeled(call, tokens):
    """True unless the control's label is provably empty of spoken text.

    An unknown view (commerceText(...), CustomIcon()) is not provably
    unlabeled: VoiceOver may already speak whatever that view provides.
    """
    if chain_supplies_label(call['mods'], tokens):
        return True
    if call['name'] == 'Button':
        title = button_title(call, tokens)
        if title == 'text':
            return True
        if title == 'blank':
            return False
        closure = button_label_closure(call)
        if closure is None:
            return True
        kind, _frames = classify_body(tokens, *closure_body(closure))
        return kind != 'unlabeled'
    if call['name'] == 'Label':
        return label_control_labeled(call, tokens)
    closure = generic_label_closure(call)
    if closure is not None:
        kind, _frames = classify_body(tokens, *closure_body(closure))
        if kind != 'unlabeled':
            return True
    title = leading_title(call, tokens)
    return title == 'text'


def button_title(call, tokens):
    if find_closure(call['closures'], 'label') is not None:
        return None
    labels = {a[0] for a in call['args']}
    if 'action' in labels or 'intent' in labels:
        return None
    if not call['args'] or call['args'][0][0] is not None:
        return None
    if arg_is_closure(tokens, call['args'][0]):
        return None
    if literal_is_blank(tokens, call['args'][0][1], call['args'][0][2]):
        return 'blank'
    return 'text'


def button_label_closure(call):
    labeled = find_closure(call['closures'], 'label')
    if labeled is not None:
        return labeled
    labels = {a[0] for a in call['args']}
    if 'action' in labels or 'intent' in labels:
        unlabeled = [c for c in call['closures'] if c[0] is None]
        if len(unlabeled) == 1:
            return unlabeled[0]
    return None


def leading_title(call, tokens):
    """A string/title argument that is the visible name of Link, Menu, NavigationLink."""
    if not call['args']:
        return None
    label, start, end = call['args'][0]
    if label not in (None, 'title', 'titleKey'):
        return None
    if arg_is_closure(tokens, call['args'][0]):
        return None
    if literal_is_blank(tokens, start, end):
        return 'blank'
    return 'text'


def generic_label_closure(call):
    """The closure VoiceOver uses as this control's name, when it is not a Button."""
    labeled = find_closure(call['closures'], 'label')
    if labeled is not None:
        return labeled
    name = call['name']
    labels = {a[0] for a in call['args']}
    unlabeled = [c for c in call['closures'] if c[0] is None]
    if name == 'NavigationLink':
        # NavigationLink("Title") { destination } keeps the title and shows the
        # destination. Only destination:/value:/isActive: put the name in the
        # trailing closure.
        if ('value' in labels or 'isActive' in labels or 'destination' in labels) and len(unlabeled) == 1:
            return unlabeled[0]
        return None
    if name == 'Menu':
        # Menu("Title") { items } — the closure is the menu, not the name.
        return None
    if name == 'Link':
        if 'destination' in labels and len(unlabeled) == 1:
            return unlabeled[0]
        return None
    if name == 'ShareLink':
        if 'item' in labels and len(unlabeled) == 1:
            return unlabeled[0]
        return None
    return None


def label_control_labeled(call, tokens):
    if chain_supplies_label(call['mods'], tokens):
        return True
    if leading_title(call, tokens) == 'text':
        return True
    title = find_closure(call['closures'], None)
    # Label { title } icon: { icon } — first unlabeled closure is the title.
    unlabeled = [c for c in call['closures'] if c[0] is None]
    if unlabeled:
        kind, _frames = classify_body(tokens, *closure_body(unlabeled[0]))
        if kind != 'unlabeled':
            return True
    return False


def label_spans_for(call, tokens):
    """Token ranges that are the accessible label of this control, plus whether the control is labeled."""
    name = call['name']
    labeled = control_is_labeled(call, tokens)
    spans = []
    if name == 'Button':
        closure = button_label_closure(call)
        if closure is not None:
            spans.append((closure[1], closure[2], 'Button', labeled))
        return spans
    if name == 'Label':
        for closure in call['closures']:
            if closure[0] in (None, 'icon', 'title'):
                spans.append((closure[1], closure[2], 'Label', labeled))
        return spans
    closure = generic_label_closure(call)
    if closure is not None:
        spans.append((closure[1], closure[2], name, labeled))
    return spans


def button_action_snippet(call, text, tokens):
    action = find_closure(call['closures'], None)
    if action is None:
        for label, start, end in call['args']:
            if label in ('action', 'intent'):
                return source_slice(text, tokens, start, end)
        return ''
    return source_slice(text, tokens, action[1], action[2] + 1)


# --- file analysis ----------------------------------------------------------

def brace_index(tokens):
    parent = {}
    closes = {}
    opens_at = [None] * len(tokens)
    stack = []
    for i, tok in enumerate(tokens):
        if is_op(tok, '}') and stack:
            stack.pop()
        opens_at[i] = stack[-1] if stack else None
        if is_op(tok, '{'):
            parent[i] = stack[-1] if stack else None
            stack.append(i)
        elif is_op(tok, '}') and i:
            # close maps were recorded when we popped; rebuild from parent keys
            pass
    stack = []
    for i, tok in enumerate(tokens):
        if is_op(tok, '{'):
            stack.append(i)
        elif is_op(tok, '}') and stack:
            closes[stack.pop()] = i
    return opens_at, parent, closes


def closure_owner_from_paren(tokens, close_paren):
    depth = 0
    j = close_paren
    while j >= 0:
        if is_op(tokens[j], ')'):
            depth += 1
        elif is_op(tokens[j], '('):
            depth -= 1
            if depth == 0:
                if j > 0 and tokens[j - 1].kind == 'id':
                    return tokens[j - 1].value
                return None
        j -= 1
    return None


def ancestor_covers(tokens, index, opens_at, parent, closes):
    open_i = opens_at[index]
    seen = 0
    while open_i is not None and seen < 30:
        seen += 1
        close_i = closes.get(open_i)
        if close_i is not None:
            mods, _end = parse_modifiers(tokens, close_i + 1, len(tokens))
            if any(modifier_hides(m, tokens) for m in mods):
                return True
            if any(modifier_supplies_label(m, tokens) for m in mods):
                return True
            for mod in mods:
                behavior = element_behavior(mod, tokens)
                if behavior == 'ignore':
                    return True
                if behavior == 'combine':
                    if range_has_spoken_text(tokens, open_i + 1, close_i):
                        return True
                    if any(modifier_supplies_label(m, tokens) for m in mods):
                        return True
        owner = None
        if open_i > 0:
            owner = owner_of_brace(tokens, open_i, closes)
        if owner in NON_VIEW:
            # A non-view closure hides the image only when no view builder
            # sits between the image and that closure. The innermost brace is
            # checked first; if it is non-view, the image is not on screen.
            if seen == 1:
                return 'nonview'
        open_i = parent.get(open_i)
    return False


def owner_of_brace(tokens, open_i, closes):
    prev = open_i - 1
    if prev < 0:
        return None
    if tokens[prev].kind == 'id' and not (prev > 0 and is_op(tokens[prev - 1], '.')):
        return tokens[prev].value
    if is_op(tokens[prev], ')'):
        return closure_owner_from_paren(tokens, prev)
    if is_op(tokens[prev], ':') and prev > 0 and tokens[prev - 1].kind == 'id':
        label_i = prev - 1
        if label_i > 0 and is_op(tokens[label_i - 1], '}'):
            close_i = label_i - 1
            for open_b, close_b in closes.items():
                if close_b == close_i:
                    return owner_of_brace(tokens, open_b, closes)
        if label_i > 0 and is_op(tokens[label_i - 1], ')'):
            return closure_owner_from_paren(tokens, label_i - 1)
        return tokens[label_i].value
    return None


def range_has_spoken_text(tokens, start, end):
    i = start
    while i < end:
        tok = tokens[i]
        if tok.kind == 'id' and tok.value in TEXT_VIEWS and is_word_call(tokens, i):
            call = parse_call(tokens, i, end)
            if call and not text_call_is_blank(call, tokens):
                return True
            i = call['end'] if call else i + 1
            continue
        if is_op(tok, '.') and i + 1 < end and tokens[i + 1].kind == 'id' and tokens[i + 1].value in (
            'accessibilityLabel', 'accessibilityRepresentation',
        ):
            return True
        i += 1
    return False


def in_view_builder(tokens, index, opens_at, parent, closes):
    open_i = opens_at[index]
    seen = 0
    while open_i is not None and seen < 30:
        seen += 1
        owner = owner_of_brace(tokens, open_i, closes)
        if owner in NON_VIEW and seen == 1:
            return False
        if owner in VIEW_BUILDER_NAMES or owner == 'View':
            return True
        if owner in ABSORBING:
            return True
        open_i = parent.get(open_i)
    return False


VIEW_BUILDER_NAMES = CONTAINERS | {
    'overlay', 'background', 'mask', 'sheet', 'fullScreenCover', 'popover',
    'safeAreaInset', 'toolbar', 'navigationDestination', 'safeAreaBar', 'Preview',
}


# Parenthesized arguments that still put an Image on screen.
DISPLAY_ARGUMENT_CALLS = {'overlay', 'background', 'mask'}


def image_is_decorative(call, tokens):
    if call['args'] and call['args'][0][0] == 'decorative':
        return True
    return False


def image_argument_owner(tokens, index):
    """Call that takes this Image as a parenthesized argument, or None.

    ShareLink(item: Image(...)) passes a value into a system control. That
    image is not an accessibility element. overlay(Image(...)) is on screen.
    A view-builder `{ Image(...) }` returns None so the normal rules apply.
    """
    depth_p = 0
    depth_b = 0
    j = index - 1
    while j >= 0:
        value = tokens[j].value if tokens[j].kind == 'op' else ''
        if value == ')':
            depth_p += 1
        elif value == '(':
            if depth_p == 0 and depth_b == 0:
                name_i = j - 1
                if name_i >= 0 and tokens[name_i].kind == 'id':
                    return tokens[name_i].value
                return ''
            depth_p = max(0, depth_p - 1)
        elif value == '}':
            depth_b += 1
        elif value == '{':
            if depth_b == 0 and depth_p == 0:
                return None
            depth_b = max(0, depth_b - 1)
        j -= 1
    return None


def image_has_tap(call, tokens, text):
    for mod in call['mods']:
        if mod[0] == 'onTapGesture':
            return True
        if mod[0] in ('gesture', 'highPriorityGesture', 'simultaneousGesture'):
            if 'TapGesture' in source_slice(text, tokens, mod[3], mod[4]):
                return True
    return False


def button_action_spans(call):
    """Closures that run the button, not the label VoiceOver reads."""
    if call['name'] != 'Button':
        return []
    label = button_label_closure(call)
    label_open = label[1] if label is not None else None
    return [(c[1], c[2]) for c in call['closures'] if c[1] != label_open]


def span_hit(spans, index):
    """Innermost recorded label span containing index."""
    hit = None
    for open_i, close_i, owner, labeled in spans:
        if open_i <= index <= close_i:
            if hit is None or (close_i - open_i) < (hit[1] - hit[0]):
                hit = (open_i, close_i, owner, labeled)
    return hit


def dims_text(small):
    return ' '.join(f'{name}={value:g}' for name, value in small)


def add_small(findings, path, line, small, snippet, symbol=''):
    if not small:
        return
    points = min(value for _name, value in small)
    detail = dims_text(small)
    findings.append(Finding(
        'small-tap', path, line, detail,
        signature('small-tap', path, detail + ' ' + snippet),
        symbol=symbol, points=points,
    ))


def analyze(text, path):
    tokens = tokenize(text)
    opens_at, parent, closes = brace_index(tokens)
    findings = []
    spans = []
    action_spans = []
    n = len(tokens)
    i = 0
    while i < n:
        tok = tokens[i]
        if tok.kind == 'id' and tok.value in ABSORBING and is_word_call(tokens, i):
            call = parse_call(tokens, i, n)
            if call is None:
                i += 1
                continue
            spans.extend(label_spans_for(call, tokens))
            action_spans.extend(button_action_spans(call))
            if call['name'] == 'Button':
                judge_button(call, tokens, text, path, findings)
            else:
                judge_tap_control(call, tokens, text, path, findings)
            i = max(call['name_i'] + 1, i + 1)
            continue
        i += 1

    i = 0
    while i < n:
        tok = tokens[i]
        if tok.kind == 'id' and tok.value == 'Image' and is_word_call(tokens, i):
            call = parse_call(tokens, i, n)
            if call is None:
                i += 1
                continue
            judge_image(call, tokens, text, path, findings, spans, action_spans, opens_at, parent, closes)
            i = max(i + 1, call['name_i'] + 1)
            continue
        i += 1

    judge_tap_gestures(tokens, text, path, findings, closes)
    return findings


def judge_button(call, tokens, text, path, findings):
    line = tokens[call['name_i']].line
    labeled = control_is_labeled(call, tokens)
    closure = button_label_closure(call)
    label_src = ''
    frames = [frame_dims(m, tokens) for m in call['mods'] if m[0] == 'frame']
    if closure is not None:
        body_s, body_e = closure_body(closure)
        label_src = source_slice(text, tokens, body_s, body_e)
        if not frames:
            _kind, inner = classify_body(tokens, body_s, body_e)
            frames = inner
    elif button_title(call, tokens) == 'blank':
        label_src = '""'
    if not labeled:
        action = button_action_snippet(call, text, tokens)
        snippet = 'label=' + norm(label_src) + ' action=' + norm(action)
        symbol = system_symbol(label_src)
        findings.append(Finding(
            'unlabeled-button', path, line,
            norm(label_src) or '(empty)',
            signature('unlabeled-button', path, snippet),
            symbol=symbol,
        ))
    receiver = source_slice(text, tokens, call['name_i'], min(call['end'], call['name_i'] + 8))
    add_small(findings, path, line, small_dimensions(frames), receiver, system_symbol(label_src))


def judge_tap_control(call, tokens, text, path, findings):
    if call['name'] not in TAP_CONTROLS:
        return
    frames = [frame_dims(m, tokens) for m in call['mods'] if m[0] == 'frame']
    if not frames:
        return
    line = tokens[call['name_i']].line
    receiver = source_slice(text, tokens, call['name_i'], min(call['end'], call['name_i'] + 6))
    add_small(findings, path, line, small_dimensions(frames), receiver)


def judge_image(call, tokens, text, path, findings, spans, action_spans, opens_at, parent, closes):
    if image_is_decorative(call, tokens):
        return
    if chain_supplies_label(call['mods'], tokens):
        return
    index = call['name_i']
    owner = image_argument_owner(tokens, index)
    if owner is not None and owner not in DISPLAY_ARGUMENT_CALLS:
        return
    for open_i, close_i in action_spans:
        if open_i <= index <= close_i:
            return
    hit = span_hit(spans, index)
    if hit is not None:
        _o, _c, owner, labeled = hit
        if owner == 'Button' or labeled:
            return
        # The image is the accessible name of a Menu, Link, NavigationLink,
        # ShareLink, or Label, and that control has no spoken label.
    else:
        covered = ancestor_covers(tokens, index, opens_at, parent, closes)
        if covered is True or covered == 'nonview':
            return
        if not image_has_tap(call, tokens, text) and not in_view_builder(tokens, index, opens_at, parent, closes):
            return
    line = tokens[index].line
    snippet = source_slice(text, tokens, call['name_i'], call['end'])
    symbol = system_symbol(snippet)
    findings.append(Finding(
        'unlabeled-image', path, line, norm(snippet),
        signature('unlabeled-image', path, snippet),
        symbol=symbol,
    ))


def judge_tap_gestures(tokens, text, path, findings, closes):
    n = len(tokens)
    seen = set()
    for i, tok in enumerate(tokens):
        if tok.kind != 'id' or tok.value not in ('onTapGesture', 'gesture', 'highPriorityGesture', 'simultaneousGesture'):
            continue
        if i == 0 or not is_op(tokens[i - 1], '.'):
            continue
        if tok.value != 'onTapGesture':
            # Only TapGesture, and only when the receiver is not a system control.
            window = source_slice(text, tokens, i, min(n, i + 12))
            if 'TapGesture' not in window:
                continue
        chain_start = rewind_chain(tokens, i - 1)
        if chain_start in seen:
            continue
        seen.add(chain_start)
        mods, _end = parse_modifiers(tokens, chain_start, n)
        if not any(m[0] == 'onTapGesture' or (
            m[0] in ('gesture', 'highPriorityGesture', 'simultaneousGesture')
            and 'TapGesture' in source_slice(text, tokens, m[3], m[4])
        ) for m in mods):
            continue
        receiver = receiver_before(tokens, chain_start, closes)
        if receiver in SYSTEM_SKIP or receiver in TAP_CONTROLS:
            continue
        frames = [frame_dims(m, tokens) for m in mods if m[0] == 'frame']
        small = small_dimensions(frames)
        if not small:
            continue
        line = tokens[chain_start].line if chain_start < n else tok.line
        snippet = receiver or 'onTapGesture'
        add_small(findings, path, line, small, snippet + ' ' + dims_text(small))


def matching_open(tokens, close_i, open_ch, close_ch):
    depth = 0
    j = close_i
    while j >= 0:
        if is_op(tokens[j], close_ch):
            depth += 1
        elif is_op(tokens[j], open_ch):
            depth -= 1
            if depth == 0:
                return j
        j -= 1
    return None


def rewind_chain(tokens, dot_i):
    """First '.' of the modifier chain that contains dot_i."""
    i = dot_i
    while i > 0 and is_op(tokens[i], '.'):
        prev = i - 1
        open_i = None
        if is_op(tokens[prev], ')'):
            open_i = matching_open(tokens, prev, '(', ')')
        elif is_op(tokens[prev], '}'):
            open_i = matching_open(tokens, prev, '{', '}')
        if open_i is not None and open_i > 0 and tokens[open_i - 1].kind == 'id' and is_op(tokens[open_i - 2], '.'):
            i = open_i - 2
            continue
        if tokens[prev].kind == 'id' and prev > 0 and is_op(tokens[prev - 1], '.'):
            i = prev - 1
            continue
        break
    return i


def receiver_before(tokens, chain_start, closes):
    if chain_start <= 0:
        return None
    return _receiver(tokens, chain_start, closes)


def _receiver(tokens, chain_start, closes):
    i = chain_start - 1
    if i < 0:
        return None
    if is_op(tokens[i], '}'):
        for open_b, close_b in closes.items():
            if close_b == i:
                return owner_of_brace(tokens, open_b, closes)
        return None
    if is_op(tokens[i], ')'):
        return closure_owner_from_paren(tokens, i)
    if tokens[i].kind == 'id':
        return tokens[i].value
    return None


def scan_tree(root):
    findings = []
    files = []
    for folder in SCAN_ROOTS:
        base = root / folder
        if not base.is_dir():
            continue
        for path in sorted(base.rglob('*.swift')):
            files.append(path)
    for path in files:
        text = path.read_text(encoding='utf-8')
        rel = path.relative_to(root).as_posix()
        findings.extend(analyze(text, rel))
    return findings, len(files)


def read_baseline(path):
    counts = Counter()
    if not path.exists():
        return None
    for line in path.read_text(encoding='utf-8').splitlines():
        if not line or line.startswith('#'):
            continue
        counts[line] += 1
    return counts


def write_baseline(findings, path, allow_increase):
    current = Counter(item.signature for item in findings)
    existing = read_baseline(path)
    if existing is not None and not allow_increase:
        raised = [(sig, existing[sig], current[sig]) for sig in current if current[sig] > existing.get(sig, 0)]
        if raised:
            print(f'FAIL accessibility lint: --write-baseline would raise {len(raised)} signature(s).')
            print('The baseline records the tree it was introduced with. Do not add lines to hide a new violation.')
            for sig, old, new in raised[:20]:
                print(f'  {old} -> {new}  {sig}')
            return 1
    lines = ['# a11y lint baseline for tools/check_a11y_lint.py',
             '# One signature per finding on the tree this file was introduced with.',
             '# The checker fails only when a signature occurs more often than it does here.',
             '# A missing file makes the checker print SKIP and exit 0.',
             '# Do not add lines to hide a new violation. Counts may fall when a finding is fixed.',
             '# kind<TAB>path<TAB>signature']
    for sig, count in sorted(current.items()):
        lines.extend([sig] * count)
    path.write_text('\n'.join(lines) + '\n', encoding='utf-8')
    print(f'WROTE {BASELINE_NAME}: {sum(current.values())} finding(s), {len(current)} signature(s)')
    return 0


def compare(findings, baseline):
    current = Counter(item.signature for item in findings)
    new_items = []
    used = Counter()
    for item in findings:
        used[item.signature] += 1
        if used[item.signature] > baseline.get(item.signature, 0):
            new_items.append(item)
    removed = 0
    for sig, count in baseline.items():
        removed += max(0, count - current.get(sig, 0))
    counts = Counter(item.kind for item in findings)
    summary = (
        f'{len(new_items)} new, {len(findings)} current '
        f'(unlabeled-button {counts["unlabeled-button"]}, '
        f'unlabeled-image {counts["unlabeled-image"]}, '
        f'small-tap {counts["small-tap"]}), '
        f'{sum(baseline.values())} baselined, {removed} removed'
    )
    if new_items:
        for item in new_items:
            print(f'{item.path}:{item.line}: {item.kind}: {item.detail}')
        print(f'FAIL accessibility lint: {summary}')
        return 1, summary
    print(f'PASS accessibility lint: {summary}')
    return 0, summary


def report(findings, limit):
    buttons = [item for item in findings if item.kind == 'unlabeled-button']

    def rank(item):
        symbol = item.symbol.split('.')[0] if item.symbol else ''
        hot = next((n for n, name in enumerate(HOT_SYMBOLS) if item.symbol.startswith(name) or symbol == name.split('.')[0]), len(HOT_SYMBOLS))
        return (hot, item.points if item.points is not None else 99, item.path, item.line)

    buttons.sort(key=rank)
    print(f'WORST unlabeled buttons ({min(limit, len(buttons))} of {len(buttons)}):')
    for item in buttons[:limit]:
        symbol = item.symbol or 'no-symbol'
        print(f'  {item.path}:{item.line}: {symbol}: {item.detail}')
    taps = sorted((item for item in findings if item.kind == 'small-tap'), key=lambda item: (item.points or 99, item.path, item.line))
    print(f'WORST small tap targets ({min(limit, len(taps))} of {len(taps)}):')
    for item in taps[:limit]:
        print(f'  {item.path}:{item.line}: {item.detail}')


def self_test():
    cases = [
        ('Button("Save") { save() }', []),
        ('Button("settings.title", systemImage: "gearshape") { go() }', []),
        ('Button(action: onSignIn) { Text("mp.common.signIn") }', []),
        ('Button { destination = .login(role) } label: { Text(title) }', []),
        ('Button { go() } label: { Image(systemName: "xmark").accessibilityLabel(Text("action.close")) }', []),
        ('Button { go() } label: { Image(systemName: "xmark") }.accessibilityLabel(Text("action.close"))', []),
        ('Button { go() } label: { Image(systemName: "xmark") }.accessibilityRepresentation { Button("Close") {} }', []),
        ('Button { go() } label: { Image(systemName: "xmark") }', ['unlabeled-button']),
        ('Button(action: onClose) { Image(systemName: "xmark") }', ['unlabeled-button']),
        ('Button(role: .cancel) { dismiss() } label: { Image(systemName: "xmark") }', ['unlabeled-button']),
        ('Button { go() } label: { HStack { Image(systemName: "star"); Text("Fav") } }', []),
        ('Button { go() } label: { commerceText("cancel") }', []),
        ('Button { go() } label: { CustomIcon() }', []),
        ('VStack { Image(decorative: "bg") }', []),
        ('VStack { Image(systemName: "star").accessibilityHidden(true) }', []),
        ('VStack { Image(systemName: "star").accessibilityLabel("Favorite") }', []),
        ('VStack { Image(systemName: "star"); Text("Fav") }', ['unlabeled-image']),
        ('VStack { Image(systemName: "star"); Text("Fav") }.accessibilityElement(children: .combine)', []),
        ('VStack { Image(systemName: "star") }.accessibilityHidden(true)', []),
        ('Label { Text("Fav") } icon: { Image(systemName: "star") }', []),
        ('Menu { Button("A") { } } label: { Image(systemName: "ellipsis.circle").accessibilityLabel(Text("settings.title")) }', []),
        ('Menu { Button("A") { } } label: { Image(systemName: "ellipsis.circle") }', ['unlabeled-image']),
        ('Button("OK") { go() }.frame(width: 32, height: 32)', ['small-tap']),
        ('Button("OK") { go() }.frame(minWidth: 44, minHeight: 44)', []),
        ('Button("OK") { go() }.frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)', []),
        ('Button { go() } label: { Image(systemName: "x").frame(width: 24, height: 24) }', ['unlabeled-button', 'small-tap']),
        ('Button { go() } label: { Image(systemName: "x").frame(width: 24, height: 24) }.frame(minWidth: 44, minHeight: 44)', ['unlabeled-button']),
        ('VStack { Image(systemName: "star").frame(width: 16, height: 16) }', ['unlabeled-image']),
        ('var body: some View { Image(systemName: "star").frame(width: 16, height: 16).onTapGesture { go() } }', ['unlabeled-image', 'small-tap']),
        ('Toggle("On", isOn: $on).frame(width: 51, height: 31)', []),
        ('EditButton()', []),
        ('// Button { Image(systemName: "xmark") }\n', []),
        ('let s = "Button { Image(systemName: \\"x\\") }"\n', []),
        ('HStack { Image(systemName: "checkmark.square.fill"); Text(consent) }.accessibilityRepresentation { Toggle(isOn: $on) { Text("label") } }', []),
        ('Button { go() } label: { if ok { Text("OK") } else { Image(systemName: "x") } }', []),
        ('var body: some View { Image(systemName: "star") }', ['unlabeled-image']),
        ('Button("") { go() }', ['unlabeled-button']),
        ('Button { showingMore = true } label: { Image(systemName: "ellipsis").frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget) }.accessibilityLabel(Text("more"))', []),
        ('HStack { Text("row") }.frame(minHeight: CYSpacing.minTouchTarget).onTapGesture { toggle() }', []),
        ('HStack { Text("row") }.frame(minHeight: 22).onTapGesture { toggle() }', ['small-tap']),
        ('NavigationLink("Title") { Image(systemName: "star") }', ['unlabeled-image']),
        ('NavigationLink { Image(systemName: "star") } label: { Text("Go") }', ['unlabeled-image']),
        ('Button { let icon = Image(systemName: "x") } label: { Text("Go") }', []),
        ('Link(destination: url) { Image(systemName: "safari") }', ['unlabeled-image']),
        ('Link("Apple", destination: url)', []),
        ('Button { } label: { Image(systemName: "x").frame(width: 32, height: 32).frame(minWidth: Theme.MiniProgramChrome.minHit, minHeight: Theme.MiniProgramChrome.minHit) }.accessibilityLabel(label)', []),
        ('Button { } label: { Image(systemName: "xmark") }.pageTemplateControl(label: Text("action.close"), traits: .isButton)', []),
        ('VStack { Image(systemName: "star"); Text("A") }.pageTemplateGroupedCard(label: Text("card"), traits: .isStaticText)', []),
        ('Button { } label: { Capsule().frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget / 2) }.accessibilityLabel(Text("step"))', ['small-tap']),
        ('ShareLink(item: Image(uiImage: rendered), preview: SharePreview(Text("t"), image: Image(uiImage: rendered))) { Label("share", systemImage: "square.and.arrow.up") }', []),
        ('VStack { Color.clear.overlay(Image(systemName: "photo")) }', ['unlabeled-image']),
    ]
    failed = 0
    for source, expect in cases:
        got = [item.kind for item in analyze(source, 'App/Sample.swift')]
        if sorted(got) != sorted(expect):
            failed += 1
            print('SELF-TEST FAIL')
            print('  source:', ' '.join(source.split()))
            print('  expect:', expect)
            print('  got:   ', got)
    if failed:
        print(f'SELF-TEST FAIL: {failed} case(s)')
        return False
    print(f'SELF-TEST PASS: {len(cases)} case(s)')
    return True


def main(argv):
    parser = argparse.ArgumentParser(description='Lint unlabeled SwiftUI buttons, images, and sub-44pt tap targets.')
    parser.add_argument('--self-test', action='store_true', help='run the built-in cases and exit')
    parser.add_argument('--report', action='store_true', help='print the worst current findings')
    parser.add_argument('--write-baseline', action='store_true', help='write tools/a11y_lint_baseline.txt from the current tree')
    parser.add_argument('--allow-increase', action='store_true', help='permit --write-baseline to record new signatures')
    parser.add_argument('--report-limit', type=int, default=40)
    args = parser.parse_args(argv)
    if not self_test():
        return 1
    if args.self_test:
        return 0
    if not args.report and not args.write_baseline and not BASELINE_PATH.exists():
        print(
            'SKIP accessibility lint: tools/a11y_lint_baseline.txt is absent; '
            'exiting 0 so a gates job can run before the baseline is merged'
        )
        return 0
    findings, files = scan_tree(ROOT)
    if args.report:
        counts = Counter(item.kind for item in findings)
        print(
            f'REPORT accessibility lint: {len(findings)} current '
            f'(unlabeled-button {counts["unlabeled-button"]}, '
            f'unlabeled-image {counts["unlabeled-image"]}, '
            f'small-tap {counts["small-tap"]}) across {files} Swift files'
        )
        report(findings, args.report_limit)
    if args.write_baseline:
        return write_baseline(findings, BASELINE_PATH, args.allow_increase)
    baseline = read_baseline(BASELINE_PATH)
    if baseline is None:
        print(
            'SKIP accessibility lint: tools/a11y_lint_baseline.txt is absent; '
            'exiting 0 so a gates job can run before the baseline is merged'
        )
        return 0
    code, _summary = compare(findings, baseline)
    return code


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
