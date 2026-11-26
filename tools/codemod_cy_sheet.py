#!/usr/bin/env python3
"""M5 codemod: `.sheet(` / `.fullScreenCover(` -> `.cySheet(` / `.cyFullScreenCover(` over App/**/*.swift.

Mechanical and idempotent. Only the receiver name changes; arguments, trailing closures and whitespace stay
byte-for-byte. `cySheet` / `cyFullScreenCover` (App/NativeR2/Motion/CYSheet.swift) have the exact SwiftUI
signatures, so a call is rewritten only when its argument labels are a subset of Apple's
(isPresented | item, onDismiss, content) — anything else is skipped and logged as a possible type-inference
change. Calls inside comments and string literals, under any Tests/ directory and in the helper itself are
never touched. `.alert` / `.confirmationDialog` / `.popover` are out of scope.

Usage:
  python3 tools/codemod_cy_sheet.py            # rewrite in place, print counts + skip log
  python3 tools/codemod_cy_sheet.py --check    # exit 1 if any call site still needs rewriting (no writes)
  python3 tools/codemod_cy_sheet.py --json     # machine-readable summary
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
APP = ROOT / "App"
HELPER = APP / "NativeR2" / "Motion" / "CYSheet.swift"
TARGETS = {"sheet": "cySheet", "fullScreenCover": "cyFullScreenCover"}
FIRST_LABELS = {"isPresented", "item"}
ALLOWED_LABELS = FIRST_LABELS | {"onDismiss", "content"}
CALL = re.compile(r"\.(sheet|fullScreenCover)\(")
IDENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")


def code_mask(src: str) -> list[bool]:
    """True for characters that are Swift code (not inside a comment or string literal)."""
    n = len(src)
    mask = [True] * n
    i = 0
    while i < n:
        c = src[i]
        if src.startswith("//", i):
            j = src.find("\n", i)
            j = n if j < 0 else j
            for k in range(i, j):
                mask[k] = False
            i = j
        elif src.startswith("/*", i):
            depth, j = 1, i + 2
            while j < n and depth:
                if src.startswith("/*", j):
                    depth, j = depth + 1, j + 2
                elif src.startswith("*/", j):
                    depth, j = depth - 1, j + 2
                else:
                    j += 1
            for k in range(i, j):
                mask[k] = False
            i = j
        elif c == '"' or (c == "#" and re.match(r'#+"', src[i:])):
            hashes = 0
            while src[i + hashes] == "#":
                hashes += 1
            start = i
            j = i + hashes
            multi = src.startswith('"""', j)
            quote = '"""' if multi else '"'
            j += len(quote)
            close = quote + "#" * hashes
            while j < n:
                if hashes == 0 and src[j] == "\\":
                    j += 2
                    continue
                if src.startswith(close, j):
                    j += len(close)
                    break
                if not multi and src[j] == "\n":
                    break
                j += 1
            for k in range(start, min(j, n)):
                mask[k] = False
            i = j
        else:
            i += 1
    return mask


def skip_trivia(src: str, i: int, mask: list[bool]) -> int:
    while i < len(src) and (src[i].isspace() or not mask[i]):
        i += 1
    return i


def call_labels(src: str, open_paren: int, mask: list[bool]) -> tuple[list[str], int] | None:
    """Top-level argument labels of the call whose `(` is at open_paren, and the index of its `)`."""
    depth, i, labels, arg_start = 0, open_paren, [], open_paren + 1
    pairs = {"(": ")", "[": "]", "{": "}"}
    stack: list[str] = []
    while i < len(src):
        c = src[i]
        if not mask[i]:
            i += 1
            continue
        if c in pairs:
            stack.append(pairs[c])
        elif c in ")]}":
            if not stack or stack.pop() != c:
                return None
            if not stack:
                labels.append(_label(src, arg_start, i, mask))
                return labels, i
        elif c == "," and len(stack) == 1:
            labels.append(_label(src, arg_start, i, mask))
            arg_start = i + 1
        i += 1
    return None


def _label(src: str, start: int, end: int, mask: list[bool]) -> str:
    i = skip_trivia(src, start, mask)
    m = IDENT.match(src, i)
    if m and m.end() <= end:
        j = skip_trivia(src, m.end(), mask)
        if j < end and src[j] == ":" and not src.startswith("::", j):
            return m.group(0)
    return "_" if i < end else ""


def line_of(src: str, i: int) -> int:
    return src.count("\n", 0, i) + 1


def process(path: Path, write: bool) -> tuple[dict, list[dict], str]:
    src = path.read_text(encoding="utf-8")
    mask = code_mask(src)
    counts = {"sheet": 0, "fullScreenCover": 0}
    skips: list[dict] = []
    edits: list[tuple[int, int, str]] = []
    rel = str(path.relative_to(ROOT))
    for m in CALL.finditer(src):
        name = m.group(1)
        dot = m.start()
        if not mask[dot]:
            continue
        open_paren = m.end() - 1
        parsed = call_labels(src, open_paren, mask)
        where = {"file": rel, "line": line_of(src, dot), "call": "." + name + "("}
        if parsed is None:
            skips.append({**where, "reason": "unbalanced call (could not parse arguments)"})
            continue
        labels, _ = parsed
        labels = [l for l in labels if l != ""]
        if not labels or labels[0] not in FIRST_LABELS:
            # Not SwiftUI's presentation modifier (e.g. `kind.sheet(locale:)`, `Tokens.sheet(in:)`): leave silently
            # unless it looks like one.
            if labels and labels[0] in ALLOWED_LABELS:
                skips.append({**where, "reason": f"first label `{labels[0]}` is not isPresented/item"})
            continue
        extra = [l for l in labels if l not in ALLOWED_LABELS]
        if extra:
            skips.append({**where, "reason": f"labels {extra} outside Apple's signature (type inference may change)"})
            continue
        edits.append((dot + 1, dot + 1 + len(name), TARGETS[name]))
        counts[name] += 1
    if edits and write:
        out = src
        for start, end, repl in sorted(edits, reverse=True):
            out = out[:start] + repl + out[end:]
        path.write_text(out, encoding="utf-8")
    return counts, skips, rel


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="report only; exit 1 if anything still needs rewriting")
    ap.add_argument("--json", action="store_true", help="print a JSON summary")
    args = ap.parse_args()

    total = {"sheet": 0, "fullScreenCover": 0}
    files_changed: list[str] = []
    skips: list[dict] = []
    skipped_paths: list[str] = []
    for path in sorted(APP.rglob("*.swift")):
        if "Tests" in path.relative_to(ROOT).parts or path.name.endswith("Tests.swift"):
            skipped_paths.append(str(path.relative_to(ROOT)))
            continue
        if path == HELPER:
            continue
        counts, file_skips, rel = process(path, write=not args.check)
        skips += file_skips
        if counts["sheet"] or counts["fullScreenCover"]:
            files_changed.append(rel)
        for k in total:
            total[k] += counts[k]

    summary = {
        "mode": "check" if args.check else "write",
        "rewritten": total,
        "files": len(files_changed),
        "skipped_calls": skips,
        "skipped_test_paths": skipped_paths,
    }
    if args.json:
        print(json.dumps(summary, indent=2, ensure_ascii=False))
    else:
        verb = "would rewrite" if args.check else "rewrote"
        print(f"{verb}: .sheet( x{total['sheet']}, .fullScreenCover( x{total['fullScreenCover']} in {len(files_changed)} files")
        print(f"skipped test paths: {len(skipped_paths)}")
        print(f"skipped calls: {len(skips)}")
        for s in skips:
            print(f"  SKIP {s['file']}:{s['line']} {s['call']} - {s['reason']}")
    if args.check and (total["sheet"] or total["fullScreenCover"]):
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
