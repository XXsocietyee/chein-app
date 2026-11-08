#!/usr/bin/env python3
"""FP-X1 lint: no `print(` / `debugPrint(` / `NSLog(` / `dump(` in shipped App/ or Core/ code outside `#if DEBUG`.

Exit 0 when clean, 1 with `path:line: text` findings. Comments and string literals are ignored; `#if DEBUG ... #endif`
nesting is tracked, and `#else` of a DEBUG block counts as release code.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CALL = re.compile(r'(?<![\w.])(print|debugPrint|NSLog|dump)\s*\(')


def strip_line(line):
    """Remove string literals and trailing // comments so only code remains."""
    out, i, in_str = [], 0, False
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
        elif line.startswith('//', i):
            break
        else:
            out.append(c)
        i += 1
    return ''.join(out)


def findings_for(text):
    stack = []  # each entry: True when the current branch is DEBUG-only
    found = []
    in_block_comment = False
    for number, raw in enumerate(text.split('\n'), 1):
        line = raw.strip()
        if in_block_comment:
            if '*/' in line:
                in_block_comment = False
            continue
        if line.startswith('/*') and '*/' not in line:
            in_block_comment = True
            continue
        if line.startswith('#if'):
            cond = line[3:].strip()
            debug_only = '||' not in cond and 'DEBUG' in [part.strip() for part in cond.split('&&')]
            stack.append(debug_only or bool(stack and stack[-1]))
            continue
        if line.startswith('#elseif'):
            stack[-1] = bool(len(stack) > 1 and stack[-2])
            continue
        if line.startswith('#else'):
            # `#else` of `#if DEBUG` is release code unless an outer block is already DEBUG-only.
            stack[-1] = bool(len(stack) > 1 and stack[-2])
            continue
        if line.startswith('#endif'):
            if stack:
                stack.pop()
            continue
        if stack and stack[-1]:
            continue
        if CALL.search(strip_line(raw)):
            found.append((number, raw.strip()))
    return found


def main():
    bad = 0
    for folder in ('App', 'Core'):
        for path in sorted((ROOT / folder).rglob('*.swift')):
            for number, text in findings_for(path.read_text()):
                print(f'{path.relative_to(ROOT)}:{number}: {text}')
                bad += 1
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
