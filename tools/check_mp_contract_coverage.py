#!/usr/bin/env python3
"""List mini-program request( calls against Core endpoints and Core tests.

Scans production JavaScript under chengyinhub-xcx (public repo
liboyang42-cpu/hengyin). A row is a call whose callee identifier is
request, including receiver.request(. function request( definitions are
not rows. sendRequest( and req( are different identifiers and are not
counted.

This extracts literal arguments only. It does not parse JavaScript.
A path, method, or field list that is not a literal is left unknown, and
the row stays MISSING. Same-file request helpers are used only when the
helper body contains one literal /api URL or one literal method.

Columns, tab-separated:
  MP file:line    Core symbol or MISSING    test or MISSING

A Core symbol is a type.member in Core/ whose string literal is that path.
A test pins the row only when one Tests/CoreTests function contains the
path, the method, and every literal field name. Unknown fields are not
treated as pinned.

usage:
  python3 tools/check_mp_contract_coverage.py --mp-root /path/to/chengyinhub-xcx
exit 0 always when the scan runs. exit 2 when no request( calls are found.
"""
from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys

SKIP_DIRS = {
    "node_modules", "miniprogram_npm", "tests", "docs", "artifacts",
    "images", "scripts", ".git",
}
METHODS = {"GET", "POST", "PUT", "PATCH", "DELETE", "HEAD"}
TYPE_RE = re.compile(
    r"\b(?:public\s+|private\s+|internal\s+|open\s+|final\s+|actor\s+)*"
    r"(?:struct|enum|class|extension|actor)\s+([A-Za-z_][A-Za-z0-9_]*)"
)
FUNC_RE = re.compile(r"\bfunc\s+(test[A-Za-z0-9_]*)\s*\(")
CLASS_RE = re.compile(r"\b(?:final\s+)?class\s+([A-Za-z_][A-Za-z0-9_]*)")
def strip_comments(text):
    out = []
    i, n = 0, len(text)
    while i < n:
        c, d = text[i], text[i + 1] if i + 1 < n else ""
        if c == "/" and d == "/":
            while i < n and text[i] != "\n":
                out.append(" ")
                i += 1
            continue
        if c == "/" and d == "*":
            out.extend("  ")
            i += 2
            while i < n and not (text[i] == "*" and i + 1 < n and text[i + 1] == "/"):
                out.append("\n" if text[i] == "\n" else " ")
                i += 1
            if i < n:
                out.extend("  ")
                i += 2
            continue
        out.append(c)
        i += 1
    return "".join(out)


def match_bracket(text, open_at):
    pairs = {"(": ")", "{": "}", "[": "]"}
    close = pairs.get(text[open_at])
    if not close:
        return -1
    depth, i, n, quote = 0, open_at, len(text), ""
    while i < n:
        if quote == '"""':
            if text.startswith('"""', i):
                quote = ""
                i += 3
                continue
            i += 1
            continue
        if quote:
            if text[i] == "\\":
                i += 2
                continue
            if text[i] == quote:
                quote = ""
            i += 1
            continue
        if text.startswith('"""', i):
            quote = '"""'
            i += 3
            continue
        c = text[i]
        if c in "\"'`":
            quote = c
            i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "/":
            while i < n and text[i] != "\n":
                i += 1
            continue
        if c == "/" and i + 1 < n and text[i + 1] == "*":
            i += 2
            while i + 1 < n and not (text[i] == "*" and text[i + 1] == "/"):
                i += 1
            i = min(n, i + 2)
            continue
        if c == text[open_at]:
            depth += 1
        elif c == close:
            depth -= 1
            if depth == 0:
                return i
        i += 1
    return -1


def split_top(text, delimiter):
    parts, start, depth, quote, i, n = [], 0, 0, "", 0, len(text)
    while i < n:
        c = text[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = ""
            i += 1
            continue
        if c in "\"'`":
            quote = c
        elif c in "([{":
            depth += 1
        elif c in ")]}":
            depth -= 1
        elif c == delimiter and depth == 0:
            parts.append(text[start:i])
            start = i + 1
        i += 1
    parts.append(text[start:])
    return parts


def string_literal(expr):
    text = expr.strip()
    if len(text) < 2 or text[0] not in "\"'":
        return None
    quote, i = text[0], 1
    while i < len(text):
        if text[i] == "\\":
            i += 2
            continue
        if text[i] == quote:
            return text[1:i] if i == len(text) - 1 else None
        i += 1
    return None


def object_keys(expr):
    """Top-level keys of one object literal. None when the expression is not closed."""
    text = expr.strip()
    if not text.startswith("{") or not text.endswith("}"):
        return None
    body = text[1:-1]
    keys = []
    for part in split_top(body, ","):
        piece = part.strip()
        if not piece:
            continue
        if piece.startswith("..."):
            return None
        key, sep, _value = piece.partition(":")
        key = key.strip()
        if not sep:
            if re.fullmatch(r"[A-Za-z_$][\w$]*", key):
                keys.append(key)
                continue
            return None
        if key.startswith("[") or key.startswith("..."):
            return None
        literal = string_literal(key)
        if literal is None:
            if re.fullmatch(r"[A-Za-z_$][\w$]*", key):
                literal = key
            else:
                return None
        keys.append(literal)
    return keys


def path_pattern(expr):
    """Return (pattern, templated) or None. pattern has no leading slash; {} is an unparsed piece."""
    text = expr.strip()
    literal = string_literal(text)
    if literal is not None:
        return normalize_path(literal), False
    if text.startswith("`") and text.endswith("`"):
        inner = text[1:-1]
        if "${" in inner:
            parts = re.split(r"\$\{.*?\}", inner)
            if not any(parts):
                return None
            pattern = "{}".join(parts)
            return normalize_path(pattern), True
        return normalize_path(inner), False
    pieces, templated = [], False
    for part in split_top(text, "+"):
        bit = part.strip()
        if not bit:
            return None
        literal = string_literal(bit)
        if literal is None:
            pieces.append("{}")
            templated = True
        else:
            pieces.append(literal)
    if not pieces or pieces == ["{}"]:
        return None
    pattern = "".join(pieces)
    if not pattern.startswith("/api/") and not pattern.startswith("api/"):
        return None
    return normalize_path(pattern), templated


def normalize_path(value):
    path = value.split("?")[0].split("#")[0]
    if path.startswith("/"):
        path = path[1:]
    return path.rstrip("/")


def is_api(pattern):
    return bool(pattern) and (pattern.startswith("api/") or pattern.startswith("{}/api/"))


def call_facts(args_src):
    args = [part.strip() for part in split_top(args_src, ",") if part.strip()]
    path, templated, method, fields = None, False, None, None
    option = None
    for arg in args:
        if arg.startswith("{") and arg.endswith("}"):
            keys = object_keys(arg)
            if keys and ("url" in keys or "method" in keys or "data" in keys):
                option = arg
                continue
    chosen = option or ""
    if chosen:
        for part in split_top(chosen[1:-1], ","):
            piece = part.strip()
            key, sep, value = piece.partition(":")
            if not sep:
                continue
            key = key.strip().strip("\"'")
            value = value.strip()
            if key == "url":
                found = path_pattern(value)
                if found and is_api(found[0]):
                    path, templated = found
            elif key == "method":
                literal = string_literal(value)
                if literal in METHODS:
                    method = literal
            elif key == "data":
                fields = fields_from_data(value)
    else:
        for arg in args:
            literal = string_literal(arg)
            if literal in METHODS and method is None:
                method = literal
                continue
            found = path_pattern(arg)
            if path is None and found and is_api(found[0]):
                path, templated = found
                continue
        fields = data_argument(args)
    return path, templated, method, fields


OPTION_ONLY = {"json", "header", "hideLoading", "silentError", "autoErrorToast", "write", "auth",
               "success", "fail", "complete", "current"}


def data_argument(args):
    candidates = []
    for arg in args:
        if string_literal(arg) in METHODS:
            continue
        found = path_pattern(arg)
        if found and is_api(found[0]):
            continue
        keys = object_keys(arg) if arg.strip().startswith("{") else None
        if keys and set(keys) <= OPTION_ONLY:
            continue
        candidates.append(arg)
    if not candidates:
        return None
    return fields_from_data(candidates[-1])


def fields_from_data(expr):
    text = expr.strip()
    if text in ("{}", "Object.assign({}, {})"):
        return []
    keys = object_keys(text)
    if keys is not None:
        return keys
    if text.startswith("Object.assign"):
        open_at = text.find("(")
        close = match_bracket(text, open_at) if open_at >= 0 else -1
        if close < 0:
            return None
        parts = [part.strip() for part in split_top(text[open_at + 1:close], ",")]
        collected = []
        for part in parts:
            if part in ("{}", ""):
                continue
            found = object_keys(part)
            if found is None:
                return None
            collected.extend(found)
        return collected
    if "?" in text and ":" in text:
        arms = []
        for part in split_top(text, ":"):
            question = part.rfind("?")
            candidate = part[question + 1:].strip() if question >= 0 else part.strip()
            keys = object_keys(candidate)
            if keys is None:
                continue
            arms.append(keys)
        if len(arms) >= 2:
            merged = []
            for keys in arms:
                for key in keys:
                    if key not in merged:
                        merged.append(key)
            return merged
    return None


def line_of(text, index):
    return text.count("\n", 0, index) + 1


def find_calls(text):
    raw = strip_comments(text)
    calls, i, n, quote = [], 0, len(raw), ""
    while i < n:
        c = raw[i]
        if quote:
            if c == "\\":
                i += 2
                continue
            if c == quote:
                quote = ""
            i += 1
            continue
        if c in "\"'`":
            quote = c
            i += 1
            continue
        if raw.startswith("request", i) and (i == 0 or not (raw[i - 1].isalnum() or raw[i - 1] in "_$")):
            j = i + len("request")
            while j < n and raw[j] in " \t\r\n":
                j += 1
            if j < n and raw[j] == "(":
                close = match_bracket(raw, j)
                if close < 0:
                    i = j + 1
                    continue
                prefix = raw[max(0, i - 24):i]
                after = close + 1
                while after < n and raw[after] in " \t\r\n":
                    after += 1
                if re.search(r"function\s*$", prefix) or (after < n and raw[after] == "{"):
                    i = close + 1
                    continue
                calls.append((line_of(raw, i), raw[j + 1:close], i))
                i = close + 1
                continue
        i += 1
    return calls


def helper_bodies(text):
    """Bodies of request definitions in this file. A definition is request(...) { ... }."""
    raw = strip_comments(text)
    bodies, i, n = [], 0, len(raw)
    while i < n:
        at = raw.find("request", i)
        if at < 0:
            break
        if at and (raw[at - 1].isalnum() or raw[at - 1] in "_$"):
            i = at + 7
            continue
        j = at + 7
        while j < n and raw[j] in " \t\r\n":
            j += 1
        if j >= n or raw[j] != "(":
            i = at + 7
            continue
        close = match_bracket(raw, j)
        if close < 0:
            break
        k = close + 1
        while k < n and raw[k] in " \t\r\n":
            k += 1
        if k < n and raw[k] == "{":
            end = match_bracket(raw, k)
            if end < 0:
                break
            bodies.append(raw[k + 1:end])
            i = end + 1
            continue
        i = close + 1
    return bodies


def helper_bindings(text):
    """One literal URL and one literal method on the same-file request helper, if present."""
    bodies = helper_bodies(text)
    if len(bodies) != 1:
        return None, None
    body = bodies[0]
    urls = re.findall(r"""url\s*:\s*(['"])(/api/[^'"]+)\1""", body)
    methods = re.findall(r"""method\s*:\s*(['"])(GET|POST|PUT|PATCH|DELETE|HEAD)\1""", body)
    passes_method = re.search(r"\bmethod\s*[,}]", body) is not None
    url = urls[0][1] if len(urls) == 1 else None
    method = methods[0][1] if len(methods) == 1 and not passes_method else None
    return url, method


def iter_js(root):
    for dirpath, dirs, files in os.walk(root):
        dirs[:] = [name for name in dirs if name not in SKIP_DIRS and not name.startswith(".")]
        for name in files:
            if name.endswith(".js"):
                yield os.path.join(dirpath, name)


def swift_string_literals(text):
    literals = []
    i, n, = 0, len(text)
    while i < n:
        if text[i] != '"':
            i += 1
            continue
        if text.startswith('"""', i):
            end = text.find('"""', i + 3)
            if end < 0:
                break
            literals.append((i, text[i + 3:end], True))
            i = end + 3
            continue
        j, buf = i + 1, []
        while j < n:
            if text[j] == "\\":
                buf.append(text[j:j + 2])
                j += 2
                continue
            if text[j] == '"':
                break
            buf.append(text[j])
            j += 1
        literals.append((i, "".join(buf), False))
        i = j + 1
    return literals


def interpolation_pattern(literal):
    return re.sub(r"\\\((?:[^()]|\([^()]*\))*\)", "{}", literal)


def walk_types(text):
    """Yield (type_name, start, end, function ranges, let-initializer ranges)."""
    headers = []
    for match in TYPE_RE.finditer(text):
        brace = text.find("{", match.end())
        if brace < 0:
            continue
        close = match_bracket(text, brace)
        if close < 0:
            continue
        headers.append((match.group(1), match.start(), close))
    func_re = re.compile(r"\bfunc\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(")
    let_re = re.compile(r"\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\b(?:\s*:\s*[^=\n]{0,160})?\s*=\s*([\[{])")
    spans = []
    for name, start, end in headers:
        body = text[start:end]
        funcs = []
        for match in func_re.finditer(body):
            brace = text.find("{", start + match.end())
            if brace < 0 or brace > end:
                continue
            close = match_bracket(text, brace)
            if close < 0 or close > end:
                continue
            funcs.append((match.group(1), brace, close))
        lets = []
        for match in let_re.finditer(body):
            open_at = start + match.end() - 1
            close = match_bracket(text, open_at)
            if close < 0 or close > end:
                continue
            lets.append((match.group(1), open_at, close))
        spans.append((name, start, end, funcs, lets))
    return spans


def index_core(core_root):
    exact, templated = {}, {}
    for dirpath, dirs, files in os.walk(core_root):
        dirs[:] = [name for name in dirs if name != ".git"]
        for name in files:
            if not name.endswith(".swift"):
                continue
            path = os.path.join(dirpath, name)
            text = open(path, encoding="utf-8", errors="replace").read()
            types = walk_types(text)
            for index, literal, _multi in swift_string_literals(text):
                owner, func, member = "", "", ""
                for type_name, start, end, funcs, lets in types:
                    if not (start <= index <= end):
                        continue
                    owner, func, member = type_name, "", ""
                    for let_name, let_at, let_end in lets:
                        if let_at <= index <= let_end:
                            member = let_name
                    if not member:
                        assigned = re.search(
                            r"\b([A-Za-z_][A-Za-z0-9_]*)\s*(?::[^=\n]{0,80})?=\s*$",
                            text[max(start, index - 180):index])
                        if assigned and assigned.group(1) != "_":
                            member = assigned.group(1)
                    if not member:
                        for func_name, func_at, func_end in funcs:
                            if func_at <= index <= func_end:
                                func = func_name
                symbol_member = member or func
                if not owner:
                    continue
                symbol = owner + (("." + symbol_member) if symbol_member else "")
                if "\\(" not in literal and not literal.endswith("/"):
                    normalized = normalize_path(literal)
                    if normalized.startswith("api/") and "{" not in normalized:
                        exact.setdefault(normalized, []).append(symbol)
                pattern = normalize_path(interpolation_pattern(literal))
                if "{}" in pattern and pattern.startswith("api/"):
                    templated.setdefault(pattern, []).append(symbol)
    return exact, templated


def choose_symbol(symbols, pattern):
    if not symbols:
        return None
    segment = ""
    if pattern:
        segment = [part for part in pattern.split("/") if part and part != "{}"][-1].lower()

    def rank(symbol):
        type_name, _, member = symbol.partition(".")
        catalog = 1 if type_name == "ChinaReviewedRouteCapability" else 0
        segment_hit = 0 if segment and segment in member.lower() else 1
        pathish = 0 if member in {"path", "paths"} or member.endswith("Path") else 1
        return (catalog, segment_hit, pathish, symbol.count("."), len(symbol), symbol)

    return sorted(set(symbols), key=rank)[0]


def path_boundary(haystack, needle):
    path_chars = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_/"
    tail_chars = path_chars + "-"
    start = 0
    while True:
        at = haystack.find(needle, start)
        if at < 0:
            return False
        before_ok = at == 0 or haystack[at - 1] not in path_chars
        after_at = at + len(needle)
        after_ok = after_at >= len(haystack) or haystack[after_at] not in tail_chars
        if before_ok and after_ok:
            return True
        start = at + 1


def test_pins(body, pattern, templated, method, fields):
    if not pattern or not method or fields is None:
        return False
    if templated:
        segments = [segment for segment in pattern.split("{}") if segment]
        if not segments or not all(segment in body for segment in segments):
            return False
    elif not (path_boundary(body, pattern) or path_boundary(body, "/" + pattern)):
        return False
    if '"%s"' % method not in body and "'%s'" % method not in body:
        return False
    for field in fields:
        if '"%s"' % field not in body and "'%s'" % field not in body:
            return False
    return True


def index_tests(test_root):
    functions = []
    if not os.path.isdir(test_root):
        return functions
    for dirpath, dirs, files in os.walk(test_root):
        dirs[:] = [name for name in dirs if name != ".git"]
        for name in files:
            if not name.endswith(".swift"):
                continue
            text = open(os.path.join(dirpath, name), encoding="utf-8", errors="replace").read()
            matches = list(FUNC_RE.finditer(text))
            for index, match in enumerate(matches):
                end = matches[index + 1].start() if index + 1 < len(matches) else len(text)
                owner = ""
                for found in CLASS_RE.finditer(text[:match.start()]):
                    owner = found.group(1)
                functions.append((owner, match.group(1), text[match.start():end]))
    return functions


def matching_test(functions, pattern, templated, method, fields):
    hits = []
    for owner, name, body in functions:
        if test_pins(body, pattern, templated, method, fields):
            hits.append(owner + "." + name if owner else name)
    return sorted(hits)[0] if hits else None


def collect(mp_root, core_root, test_root):
    exact, templated_index = index_core(core_root)
    tests = index_tests(test_root)
    rows = []
    for path in sorted(iter_js(mp_root)):
        text = open(path, encoding="utf-8", errors="replace").read()
        helper_url, helper_method = helper_bindings(text)
        rel = os.path.relpath(path, mp_root).replace(os.sep, "/")
        for line, args, _at in find_calls(text):
            pattern, templated, method, fields = call_facts(args)
            if pattern is None and helper_url:
                pattern, templated = normalize_path(helper_url), False
            if method is None and helper_method and "method" not in args:
                method = helper_method
            symbol = None
            if pattern and not templated:
                symbol = choose_symbol(exact.get(pattern, []), pattern)
            elif pattern and templated:
                symbol = choose_symbol(templated_index.get(pattern, []), pattern)
            pinned = matching_test(tests, pattern, templated, method, fields) if pattern else None
            rows.append({
                "where": "%s:%d" % (rel, line),
                "symbol": symbol or "MISSING",
                "test": pinned or "MISSING",
                "pattern": pattern or "",
                "method": method or "",
                "fields": fields,
                "templated": templated,
            })
    return rows


def commit_of(root):
    try:
        return subprocess.check_output(
            ["git", "-C", root, "rev-parse", "HEAD"], text=True, stderr=subprocess.DEVNULL
        ).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def main(argv):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--mp-root", required=True, help="chengyinhub-xcx directory")
    parser.add_argument("--core", default="")
    parser.add_argument("--tests", default="")
    args = parser.parse_args(argv)
    repo = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    core = args.core or os.path.join(repo, "Core")
    tests = args.tests or os.path.join(repo, "Tests", "CoreTests")
    if not os.path.isdir(args.mp_root):
        print("mp root not found: " + args.mp_root, file=sys.stderr)
        return 2
    rows = collect(args.mp_root, core, tests)
    if not rows:
        print("no request( calls", file=sys.stderr)
        return 2
    matched = sum(row["symbol"] != "MISSING" and row["test"] != "MISSING" for row in rows)
    missing_endpoint = sum(row["symbol"] == "MISSING" for row in rows)
    missing_test = sum(row["test"] == "MISSING" for row in rows)
    sha = commit_of(args.mp_root)
    print("# hengyin %s" % (sha or "unknown"))
    print("# total %d matched %d missing_endpoint %d missing_test %d" % (
        len(rows), matched, missing_endpoint, missing_test))
    print("MP file:line\tCore symbol or MISSING\ttest or MISSING")
    for row in rows:
        print("%s\t%s\t%s" % (row["where"], row["symbol"], row["test"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
