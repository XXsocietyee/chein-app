#!/usr/bin/env python3
"""List mini-program HTTP calls against Core endpoints and Core tests.

Scans production JavaScript under chengyinhub-xcx (public repo
liboyang42-cpu/hengyin). A row is a call whose callee is request,
sendRequest, req, or uploadFile, including wx.request( and
wx.uploadFile(. function definitions and a method shorthand name(...) {
are not rows. subscribe.request([...]) is not an HTTP row, and neither is
require("...subscribe.js").request([...]).

This extracts literal arguments only. It does not parse JavaScript.
A path or method that is not a literal is left unknown. A spread or
Object.assign source that follows a url literal can replace it, so that
literal is not kept. Same-file request helpers are used only when the
helper body contains one literal /api URL or one literal method.

A row with no path is matched-indirect when the call forwards url,
requestJson, or _request, or when the url is a ternary and every path
literal on that ternary is already a Core string literal. The symbol
column then reads INDIRECT. A concatenation such as siteBaseUrl + '/api/...'
stays missing-endpoint. A data spread that drops a path literal stays
missing-endpoint. A call that only forwards opts or options stays
missing-endpoint, unless the checker can see that the forwarded value is
url, requestJson, or _request. Both sides of a ternary must already be
literals in Core; if one side is not, the row stays missing-endpoint.
No path is invented for an indirect row. The rows this rule matches on the
pinned mini-program are recorded in tools/mp_contract_indirect_allowlist.txt.

Columns, tab-separated:
  MP file:line    Core symbol, INDIRECT, or MISSING    test or MISSING

A Core symbol is a type.member in Core/ whose string literal is that path.
A test pins the row when one Tests/CoreTests function contains the path
and the quoted method. Literal field names are still required when this
scan can read them. A body passed through jsonBody(...), JSON.stringify(...),
a forwarded data value, Object.assign, a spread, a variable, or no data
object stays unread and does not block the pin. An indirect row has no
single path, so it is not a direct match and it does not take a pin.

usage:
  python3 tools/check_mp_contract_coverage.py --mp-root /path/to/chengyinhub-xcx
exit 0 always when the scan runs. exit 2 when no contract calls are found.
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
CALLEES = ("sendRequest", "uploadFile", "request", "req")
REGEX_BEFORE = {
    "return", "throw", "case", "else", "typeof", "void", "delete",
    "in", "of", "instanceof", "yield", "await", "do", "new",
}
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


def skip_regex_literal(text, i):
    """Return the index after a /regex/flags form, or -1.

    A slash is treated as a regex only when the previous token cannot end
    an expression. This is a scan, not a JavaScript parse. A slash that does
    not close before the next newline is left alone.
    """
    n = len(text)
    if i >= n or text[i] != "/":
        return -1
    if i + 1 < n and text[i + 1] in "/*":
        return -1
    k = i - 1
    while k >= 0 and text[k] in " \t\r\n":
        k -= 1
    if k >= 0:
        prev = text[k]
        if prev in ")]}":
            return -1
        if prev.isalnum() or prev in "_$":
            end = k + 1
            while k >= 0 and (text[k].isalnum() or text[k] in "_$"):
                k -= 1
            if text[k + 1:end] not in REGEX_BEFORE:
                return -1
    j, in_class = i + 1, False
    while j < n:
        if text[j] == "\\":
            j += 2
            continue
        if text[j] == "\n":
            return -1
        if text[j] == "[" and not in_class:
            in_class = True
        elif text[j] == "]" and in_class:
            in_class = False
        elif text[j] == "/" and not in_class:
            j += 1
            while j < n and text[j].isalpha():
                j += 1
            return j
        j += 1
    return -1


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
        if c == "/":
            end = skip_regex_literal(text, i)
            if end > i:
                i = end
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
        if c == "/":
            end = skip_regex_literal(text, i)
            if end > i:
                i = end
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
    closed, loose = None, None
    for arg in args:
        if arg.startswith("{") and arg.endswith("}"):
            keys = object_keys(arg)
            if keys and ("url" in keys or "method" in keys or "data" in keys):
                closed, loose = arg, None
                continue
            if keys is None and object_effects(arg):
                closed, loose = None, arg
                continue
        elif arg.startswith("Object.assign") and assign_sets_url(arg):
            closed, loose = None, arg
    if closed:
        for part in split_top(closed[1:-1], ","):
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
        return path, templated, method, fields
    if loose:
        found = loose_facts(loose)
        if found is not None:
            return found
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


def depth0_colon(piece):
    """Split key and value on a colon that is not inside a string, bracket, or regex."""
    depth, quote, i, n = 0, "", 0, len(piece)
    while i < n:
        c = piece[i]
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
        if c == "/":
            end = skip_regex_literal(piece, i)
            if end > i:
                i = end
                continue
        if c in "([{":
            depth += 1
        elif c in ")]}" and depth:
            depth -= 1
        elif c == ":" and depth == 0:
            return piece[:i], piece[i + 1:]
        i += 1
    return None, None


def object_effects(text):
    """url, method, and data keys written on one object literal.

    A spread clears those three inside this object. A method shorthand is
    ignored. A shorthand url, method, or data has no literal value. Returns
    an empty dict when none of the three keys appear.
    """
    body = text.strip()
    if len(body) < 2 or not body.startswith("{") or not body.endswith("}"):
        return {}
    effects = {}
    for part in split_top(body[1:-1], ","):
        piece = part.strip()
        if not piece:
            continue
        if piece.startswith("..."):
            effects["url"] = (None, False)
            effects["method"] = None
            effects["data"] = None
            continue
        key, value = depth0_colon(piece)
        if key is None:
            ident = piece.strip()
            if ident == "url":
                effects["url"] = (None, False)
            elif ident == "method":
                effects["method"] = None
            elif ident == "data":
                effects["data"] = None
            continue
        key = key.strip()
        literal = string_literal(key)
        if literal is not None:
            key = literal
        elif not re.fullmatch(r"[A-Za-z_$][\w$]*", key):
            continue
        if key not in ("url", "method", "data"):
            continue
        value = value.strip()
        if key == "url":
            found = path_pattern(value)
            if found and is_api(found[0]):
                effects["url"] = found
            else:
                effects["url"] = (None, False)
        elif key == "method":
            literal = string_literal(value)
            effects["method"] = literal if literal in METHODS else None
        else:
            effects["data"] = fields_from_data(value)
    return effects


def apply_effects(effects, path, templated, method, fields):
    if "url" in effects:
        found = effects["url"]
        if found[0] is None:
            path, templated = None, False
        else:
            path, templated = found
    if "method" in effects:
        method = effects["method"]
    if "data" in effects:
        fields = effects["data"]
    return path, templated, method, fields


def assign_sets_url(text):
    open_at = text.find("(")
    close = match_bracket(text, open_at) if open_at >= 0 else -1
    if close < 0:
        return False
    for part in split_top(text[open_at + 1:close], ","):
        piece = part.strip()
        if piece.startswith("{") and piece.endswith("}") and "url" in object_effects(piece):
            return True
    return False


def loose_facts(expr):
    """Path, method, and fields from an object the closed-key reader rejected.

    Object.assign sources are applied left to right. A source that is not an
    object literal may replace url, method, and data, so an earlier literal
    is dropped. None means this expression is not an options object.
    """
    text = expr.strip()
    if text.startswith("Object.assign"):
        open_at = text.find("(")
        close = match_bracket(text, open_at) if open_at >= 0 else -1
        if close < 0 or text[close + 1:].strip():
            return None
        path, templated, method, fields = None, False, None, None
        for part in split_top(text[open_at + 1:close], ","):
            piece = part.strip()
            if not piece or piece == "{}":
                continue
            if piece.startswith("{") and piece.endswith("}"):
                path, templated, method, fields = apply_effects(
                    object_effects(piece), path, templated, method, fields)
            else:
                path, templated, method, fields = None, False, None, None
        return path, templated, method, fields
    effects = object_effects(text)
    if not effects:
        return None
    return apply_effects(effects, None, False, None, None)


def line_of(text, index):
    return text.count("\n", 0, index) + 1


def callee_at(raw, i):
    if i and (raw[i - 1].isalnum() or raw[i - 1] in "_$"):
        return ""
    for name in CALLEES:
        if not raw.startswith(name, i):
            continue
        nxt = i + len(name)
        if nxt < len(raw) and (raw[nxt].isalnum() or raw[nxt] in "_$"):
            continue
        return name
    return ""


def receiver_name(raw, ident_at):
    j = ident_at - 1
    while j >= 0 and raw[j] in " \t\r\n":
        j -= 1
    if j < 0 or raw[j] != ".":
        return ""
    end = j
    j -= 1
    while j >= 0 and (raw[j].isalnum() or raw[j] in "_$"):
        j -= 1
    return raw[j + 1:end]


def array_argument(args):
    text = args.strip()
    if not text.startswith("["):
        return False
    end = match_bracket(text, 0)
    return end == len(text) - 1


def is_subscribe_array(raw, ident_at, args):
    """subscribe.request([...]) and require('...subscribe.js').request([...])."""
    if not array_argument(args):
        return False
    if receiver_name(raw, ident_at) == "subscribe":
        return True
    return "subscribe.js" in raw[max(0, ident_at - 96):ident_at]


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
        if c == "/":
            end = skip_regex_literal(raw, i)
            if end > i:
                i = end
                continue
        name = callee_at(raw, i)
        if name:
            j = i + len(name)
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
                args = raw[j + 1:close]
                if name == "request" and is_subscribe_array(raw, i, args):
                    i = close + 1
                    continue
                calls.append((line_of(raw, i), args, i))
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
    if not pattern or not method:
        return False
    if templated:
        segments = [segment for segment in pattern.split("{}") if segment]
        if not segments or not all(segment in body for segment in segments):
            return False
    elif not (path_boundary(body, pattern) or path_boundary(body, "/" + pattern)):
        return False
    if '"%s"' % method not in body and "'%s'" % method not in body:
        return False
    for field in fields or []:
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


FORWARDERS = ("url", "requestJson", "_request")


def strip_wrapping_parens(text):
    while text.startswith("(") and match_bracket(text, 0) == len(text) - 1:
        text = text[1:-1].strip()
    return text


def depth0_has(text, op):
    """True when op sits outside strings, brackets, and regex literals."""
    depth, quote, i, n = 0, "", 0, len(text)
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
            i += 1
            continue
        if c == "/":
            end = skip_regex_literal(text, i)
            if end > i:
                i = end
                continue
        if c in "([{":
            depth += 1
        elif c in ")]}" and depth:
            depth -= 1
        elif c == op and depth == 0:
            return True
        i += 1
    return False


def split_one_ternary(text):
    """Split one conditional into (condition, true arm, false arm).

    Nested conditionals in the true arm keep their own question mark, so the
    colon that belongs to this conditional is the one that brings the nesting
    back to zero. Optional chaining and ?? are not conditionals.
    """
    depth, quote, q_at, nested, i, n = 0, "", -1, 0, 0, len(text)
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
            i += 1
            continue
        if c == "/":
            end = skip_regex_literal(text, i)
            if end > i:
                i = end
                continue
        if c in "([{":
            depth += 1
            i += 1
            continue
        if c in ")]}" and depth:
            depth -= 1
            i += 1
            continue
        if depth == 0 and c == "?" and i + 1 < n and text[i + 1] in ".?":
            i += 2
            continue
        if depth == 0 and c == "?":
            if q_at < 0:
                q_at = i
            else:
                nested += 1
            i += 1
            continue
        if depth == 0 and c == ":" and q_at >= 0:
            if nested == 0:
                cond, left, right = text[:q_at].strip(), text[q_at + 1:i].strip(), text[i + 1:].strip()
                if not cond or not left or not right:
                    return None
                return cond, left, right
            nested -= 1
        i += 1
    return None


def looks_like_function(text):
    body = text.strip()
    if body.startswith("function") or body.startswith("async "):
        return True
    return "=>" in body


def forwarder_name(expr):
    """url, requestJson, or _request, including a member such as options.url.

    The whole expression must be that name. A concatenation, a call, or a
    different identifier is not a forwarder.
    """
    text = strip_wrapping_parens(expr.strip())
    if text in FORWARDERS:
        return text
    if re.fullmatch(r"[A-Za-z_$][\w$]*(?:\.[A-Za-z_$][\w$]*)+", text):
        prop = text.rsplit(".", 1)[1]
        if prop in FORWARDERS:
            return prop
    return ""


def plain_path_literal(expr):
    text = expr.strip()
    literal = string_literal(text)
    if literal is not None:
        return literal
    if len(text) >= 2 and text[0] == "`" and text[-1] == "`" and "${" not in text:
        return text[1:-1]
    return None


def ternary_path_literals(expr):
    """Path literals of a pure conditional, or None when an arm is not one.

    A depth-0 + makes the expression a concatenation, not a conditional.
    A nested conditional contributes every leaf. One non-literal arm rejects
    the whole expression.
    """
    text = strip_wrapping_parens(expr.strip())
    if not text or looks_like_function(text) or depth0_has(text, "+"):
        return None
    parts = split_one_ternary(text)
    if parts is None:
        return None
    leaves = []
    for arm in (parts[1], parts[2]):
        arm = strip_wrapping_parens(arm.strip())
        if depth0_has(arm, "+"):
            return None
        if split_one_ternary(arm) is not None:
            nested = ternary_path_literals(arm)
            if nested is None:
                return None
            leaves.extend(nested)
            continue
        literal = plain_path_literal(arm)
        if literal is None:
            return None
        leaves.append(literal)
    return leaves or None


def key_name(key):
    text = key.strip()
    literal = string_literal(text)
    if literal is not None:
        return literal
    if re.fullmatch(r"[A-Za-z_$][\w$]*", text):
        return text
    return ""


def object_url_slot(text):
    """('expr', value) when a url key is written, else None.

    A spread does not hide a url key in the same object, and a spread with no
    url key does not take the slot. The data-spread case drops a path literal
    in call_facts; that literal is not a forwarder, so the row stays
    missing-endpoint. A later url key replaces an earlier one.
    """
    body = text.strip()
    if len(body) < 2 or not body.startswith("{") or not body.endswith("}"):
        return None
    expr = None
    seen = False
    for part in split_top(body[1:-1], ","):
        piece = part.strip()
        if not piece or piece.startswith("..."):
            continue
        key, value = depth0_colon(piece)
        if key is None:
            if piece == "url":
                seen, expr = True, "url"
            continue
        if key_name(key) != "url":
            continue
        seen, expr = True, value.strip()
    if not seen:
        return None
    return ("expr", expr)


def assign_url_slot(text):
    """Url slot after Object.assign sources, left to right.

    An object literal that does not mention url leaves the slot alone. Any
    other source replaces the whole object. opts and options therefore hide
    an earlier url unless a later literal sets the slot again.
    """
    body = text.strip()
    open_at = body.find("(")
    close = match_bracket(body, open_at) if open_at >= 0 else -1
    if close < 0 or body[close + 1:].strip() or not body.startswith("Object.assign"):
        return ("unknown", None)
    state = None
    for part in split_top(body[open_at + 1:close], ","):
        piece = part.strip()
        if not piece or piece == "{}":
            continue
        if piece.startswith("{") and piece.endswith("}"):
            inner = object_url_slot(piece)
            if inner is not None:
                state = inner
            continue
        if forwarder_name(piece):
            state = ("expr", piece)
        else:
            state = ("unknown", None)
    return state


def url_slot(args_src):
    """Expression in the url slot, or None when this call does not show one."""
    args = [part.strip() for part in split_top(args_src, ",") if part.strip()]
    slot, saw = None, False
    for arg in args:
        if arg.startswith("{") and arg.endswith("}"):
            inner = object_url_slot(arg)
            if inner is not None:
                saw, slot = True, inner
        elif arg.startswith("Object.assign"):
            saw, slot = True, assign_url_slot(arg)
    if saw:
        return slot
    for arg in args:
        if string_literal(arg) in METHODS:
            continue
        if arg.startswith("{") or arg.startswith("Object.assign") or looks_like_function(arg):
            return None
        return ("expr", arg)
    return None


def indirect_reason(args_src, exact):
    """Short reason when this call is matched-indirect, else ''.

    exact is the Core literal path index. A reason is returned only for a
    named forwarder or a ternary whose every arm is already in that index.
    """
    slot = url_slot(args_src)
    if not slot or slot[0] != "expr" or not slot[1]:
        return ""
    text = strip_wrapping_parens(slot[1].strip())
    if looks_like_function(text):
        return ""
    name = forwarder_name(text)
    if name:
        shown = text if text != name else name
        return "forwards " + shown
    leaves = ternary_path_literals(text)
    if not leaves or len(leaves) < 2:
        return ""
    paths = []
    for literal in leaves:
        path = normalize_path(literal)
        if not is_api(path) or path not in exact:
            return ""
        paths.append(path)
    return "ternary " + " | ".join(paths)


def collect(mp_root, core_root, test_root):
    exact, templated_index = index_core(core_root)
    tests = index_tests(test_root)
    rows = []
    for path in sorted(iter_js(mp_root)):
        text = open(path, encoding="utf-8", errors="replace").read()
        helper_url, helper_method = helper_bindings(text)
        rel = os.path.relpath(path, mp_root).replace(os.sep, "/")
        stripped = strip_comments(text)
        for line, args, at in find_calls(text):
            pattern, templated, method, fields = call_facts(args)
            # The same-file helper is the function named request. Other callees
            # keep only the path and method written on that call.
            if callee_at(stripped, at) == "request":
                if pattern is None and helper_url:
                    pattern, templated = normalize_path(helper_url), False
                if method is None and helper_method and "method" not in args:
                    method = helper_method
            symbol = None
            if pattern and not templated:
                symbol = choose_symbol(exact.get(pattern, []), pattern)
            elif pattern and templated:
                symbol = choose_symbol(templated_index.get(pattern, []), pattern)
            reason = ""
            if symbol is None and not pattern:
                reason = indirect_reason(args, exact)
            pinned = matching_test(tests, pattern, templated, method, fields) if pattern else None
            rows.append({
                "where": "%s:%d" % (rel, line),
                "symbol": "INDIRECT" if reason else (symbol or "MISSING"),
                "test": pinned or "MISSING",
                "pattern": pattern or "",
                "method": method or "",
                "fields": fields,
                "templated": templated,
                "indirect": reason,
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
        print("no contract calls", file=sys.stderr)
        return 2
    matched = sum(
        row["symbol"] != "MISSING" and row["symbol"] != "INDIRECT" and row["test"] != "MISSING"
        for row in rows)
    missing_endpoint = sum(row["symbol"] == "MISSING" for row in rows)
    missing_test = sum(row["test"] == "MISSING" for row in rows)
    matched_indirect = sum(row["symbol"] == "INDIRECT" for row in rows)
    sha = commit_of(args.mp_root)
    print("# hengyin %s" % (sha or "unknown"))
    print("# total %d matched %d missing_endpoint %d missing_test %d matched_indirect %d" % (
        len(rows), matched, missing_endpoint, missing_test, matched_indirect))
    print("MP file:line\tCore symbol, INDIRECT, or MISSING\ttest or MISSING")
    for row in rows:
        print("%s\t%s\t%s" % (row["where"], row["symbol"], row["test"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
