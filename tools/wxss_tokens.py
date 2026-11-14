#!/usr/bin/env python3
"""Conservative WXSS custom-property inventory and deterministic Swift generation.

No dependencies. This handles flat page/theme roots, not a browser's DOM cascade.
Unsupported values remain in JSON and are never counted as generated Swift.
"""
from __future__ import annotations

import argparse
import ast
from collections import Counter, defaultdict
from decimal import Decimal, InvalidOperation
import hashlib
import json
from pathlib import Path
import re
import sys

SOURCE_COMMIT = "561cafd10214853e8b43128a3ffe419cf115cca2"
DOMAINS = {
    "player": (), "merchant": ("theme-merchant",),
    "topicEditor": ("theme-topic-editor",), "dark": ("theme-dark",),
    "game": ("theme-light", "theme-game"),
}
NUMBER = r"[+-]?(?:\d+(?:\.\d*)?|\.\d+)"
VAR_OR_STRING = re.compile(r'''"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|(\bvar\s*\()''')


def split_top(text, delimiter):
    """Split only outside strings/parentheses; preserve original offsets."""
    start, depth, quote, escape = 0, 0, None, False
    for i, ch in enumerate(text):
        if quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
        elif ch in "\"'":
            quote = ch
        elif ch == "(":
            depth += 1
        elif ch == ")":
            depth -= 1
        elif ch == delimiter and depth == 0:
            yield start, text[start:i]
            start = i + 1
    yield start, text[start:]


def strip_comments(text):
    # Comments in quoted strings are data. Keep all offsets and line numbers.
    pattern = r'''("(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*')|/\*.*?\*/'''
    return re.sub(pattern, lambda m: m[0] if m[1] else re.sub(r"[^\n]", " ", m[0]),
                  text, flags=re.S)


def parse_rules(source):
    text = strip_comments(source)
    diagnostics, rules, order = [], [], 0
    # Brace scanner avoids interpreting strings/functions as block boundaries.
    start, depth, quote, escape, opening = 0, 0, None, False, 0
    for i, ch in enumerate(text):
        if quote:
            if escape:
                escape = False
            elif ch == "\\":
                escape = True
            elif ch == quote:
                quote = None
            continue
        if ch in "\"'":
            quote = ch
        elif ch == "{":
            if depth == 0:
                opening = i
            depth += 1
        elif ch == "}":
            depth -= 1
            if depth < 0:
                raise ValueError("unmatched closing brace")
            if depth != 0:
                continue
            selector_text = text[start:opening].strip()
            body = text[opening + 1:i]
            start = i + 1
            if "{" in body or selector_text.startswith("@"):
                diagnostics.append({"kind": "unsupported-rule", "selector": selector_text})
                continue
            declarations = []
            for offset, declaration in split_top(body, ";"):
                if not declaration.strip():
                    continue
                pair = declaration.split(":", 1)
                if len(pair) != 2 or not re.fullmatch(r"--[\w-]+", pair[0].strip()):
                    continue
                name, value = pair[0].strip(), pair[1].strip()
                if not name.startswith("--cy-"):
                    continue
                line = text.count("\n", 0, opening + 1 + offset + len(declaration) - len(declaration.lstrip())) + 1
                important = bool(re.search(r"!important\s*$", value, re.I))
                value = re.sub(r"\s*!important\s*$", "", value, flags=re.I).strip()
                declarations.append({"name": name, "raw": value, "line": line,
                                     "important": important, "order": order})
                order += 1
            for _, selector in split_top(selector_text, ","):
                selector = selector.strip()
                # Only supported roots. No descendant/pseudo/attribute guesses.
                match = re.fullmatch(r"(page)?((?:\.[\w-]+)*)", selector)
                if not match or not selector:
                    diagnostics.append({"kind": "unsupported-selector", "selector": selector})
                    continue
                classes = re.findall(r"\.([\w-]+)", match[2])
                rules.append({"selector": selector, "page": bool(match[1]),
                              "classes": classes, "declarations": declarations,
                              "specificity": (len(classes), int(bool(match[1])))})
    if depth or quote:
        raise ValueError("unterminated block or string")
    if text[start:].strip():
        diagnostics.append({"kind": "unsupported-trailing-input", "value": text[start:].strip()})
    return rules, diagnostics


def scope_for(rules, domain):
    active = set(DOMAINS[domain])
    scope, ranks, duplicates = {}, {}, []
    for rule in rules:
        if not set(rule["classes"]).issubset(active):
            continue
        for decl in rule["declarations"]:
            rank = (decl["important"], *rule["specificity"], decl["order"])
            name = decl["name"]
            if name in scope and scope[name]["order"] != decl["order"]:
                duplicates.append({"name": name, "earlier_line": scope[name]["line"],
                                   "later_line": decl["line"], "domain": domain})
            if name not in ranks or rank >= ranks[name]:
                scope[name] = {**decl, "selector": rule["selector"]}
                ranks[name] = rank
    return scope, duplicates


def cyclic_names(scope):
    """CSS cycles invalidate the variable, including edges inside fallbacks."""
    graph = {}
    for name, declaration in scope.items():
        raw = declaration["raw"]
        graph[name] = []
        for match in VAR_OR_STRING.finditer(raw):
            if match[1]:
                target = re.match(r"\s*(--[\w-]+)", raw[match.end():])
                if target:
                    graph[name].append(target[1])
    invalid, visited = set(), set()

    def walk(name, path):
        if name in path:
            invalid.update(path[path.index(name):])
        elif name not in visited:
            for target in graph.get(name, []):
                walk(target, [*path, name])
            visited.add(name)

    for name in graph:
        walk(name, [])
    return invalid


def resolve_value(value, scope, stack=(), invalid=None):
    """Resolve nested var/fallback with balanced parentheses and cycle detection."""
    issues, result, cursor = [], "", 0
    while True:
        match = next((m for m in VAR_OR_STRING.finditer(value[cursor:]) if m[1]), None)
        if not match:
            return result + value[cursor:], issues
        begin = cursor + match.start()
        opening = cursor + match.end() - 1
        depth, end, quote, escape = 1, opening + 1, None, False
        while end < len(value) and depth:
            ch = value[end]
            if quote:
                if escape:
                    escape = False
                elif ch == "\\":
                    escape = True
                elif ch == quote:
                    quote = None
            elif ch in "\"'":
                quote = ch
            else:
                depth += (ch == "(") - (ch == ")")
            end += 1
        if depth:
            return None, issues + [{"kind": "malformed-var", "value": value}]
        inner = value[opening + 1:end - 1]
        parts = list(split_top(inner, ","))
        name = parts[0][1].strip()
        fallback = inner[len(parts[0][1]) + 1:] if len(parts) > 1 else None
        if not re.fullmatch(r"--[\w-]+", name):
            resolved, problem = None, [{"kind": "malformed-reference", "name": name}]
        elif name in stack or (invalid is not None and name in invalid):
            resolved, problem = None, [{"kind": "cycle", "chain": [*stack, name]}]
        elif name not in scope:
            resolved, problem = None, [{"kind": "missing", "name": name}]
        else:
            resolved, problem = resolve_value(scope[name]["raw"], scope, (*stack, name), invalid)
        if resolved is None and fallback is not None:
            # Invalid reference may use its caller's fallback; retain diagnostics.
            resolved, fallback_issues = resolve_value(fallback.strip(), scope, stack, invalid)
            problem = [{**p, "fallback_used": resolved is not None} for p in problem] + fallback_issues
        issues.extend(problem)
        if resolved is None:
            return None, issues
        result += value[cursor:begin] + resolved
        cursor = end


def calc_value(value):
    """Evaluate only dimensionally valid numeric/rpx arithmetic; never eval()."""
    expr = re.sub(r"\bcalc\s*\(", "(", value)
    expr = re.sub(r"(" + NUMBER + r")rpx\b", r"L(\1)", expr)
    tree = ast.parse(expr, mode="eval")

    def visit(node):
        if isinstance(node, ast.Constant) and type(node.value) in (int, float):
            return Decimal(str(node.value)), 0
        if isinstance(node, ast.Call) and isinstance(node.func, ast.Name) and node.func.id == "L" and len(node.args) == 1 and not node.keywords:
            number, unit = visit(node.args[0])
            if unit:
                raise ValueError("nested length")
            return number, 1
        if isinstance(node, ast.UnaryOp) and isinstance(node.op, (ast.UAdd, ast.USub)):
            number, unit = visit(node.operand)
            return (-number if isinstance(node.op, ast.USub) else number), unit
        if isinstance(node, ast.BinOp):
            left, lu = visit(node.left)
            right, ru = visit(node.right)
            if isinstance(node.op, (ast.Add, ast.Sub)) and lu == ru:
                return (left + right if isinstance(node.op, ast.Add) else left - right), lu
            if isinstance(node.op, ast.Mult) and lu + ru <= 1:
                return left * right, lu + ru
            if isinstance(node.op, ast.Div) and ru == 0 and right != 0:
                return left / right, lu
        raise ValueError("unsupported or dimensionally invalid calc")

    return visit(tree.body)


def color_value(value):
    if value == "transparent":
        return [0.0, 0.0, 0.0, 0.0]
    if re.fullmatch(r"#(?:[0-9a-fA-F]{3}|[0-9a-fA-F]{4}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})", value):
        digits = value[1:]
        if len(digits) in (3, 4):
            digits = "".join(ch * 2 for ch in digits)
        if len(digits) == 6:
            digits += "ff"
        return [int(digits[i:i + 2], 16) / 255 for i in range(0, 8, 2)]
    match = re.fullmatch(r"(rgb|rgba)\(([^()]*)\)", value)
    if match:
        parts = [p.strip() for p in match[2].split(",")]
        if len(parts) != (4 if match[1] == "rgba" else 3):
            return None
        channels = []
        for i, part in enumerate(parts):
            if not re.fullmatch(NUMBER + r"%?", part):
                return None
            maximum = 100 if part.endswith("%") else (1 if i == 3 else 255)
            number = float(part.rstrip("%"))
            if not 0 <= number <= maximum:
                return None
            channels.append(number / maximum)
        return channels if len(channels) == 4 else channels + [1.0]
    return None


def classify(value):
    if value is None:
        return "unresolved", None, "unresolved reference"
    if re.search(r"\bvar\s*\(", value):
        return "unresolved", None, "unresolved var()"
    color = color_value(value)
    if color is not None:
        return "color", color, None
    if re.fullmatch(NUMBER + "rpx", value) or value.startswith("calc("):
        try:
            number, dimension = calc_value(value)
            if not number.is_finite():
                raise ValueError("non-finite")
            return ("length", float(number / 2), None) if dimension else ("number", float(number), None)
        except (ValueError, SyntaxError, InvalidOperation, ArithmeticError):
            return "unsupported", None, "calc requires native layout or contains unsupported units/functions"
    match = re.fullmatch("(" + NUMBER + r")(ms|s)", value)
    if match and float(match[1]) >= 0:
        return "duration", float(match[1]) / (1000 if match[2] == "ms" else 1), None
    match = re.fullmatch(r"cubic-bezier\(([^()]*)\)", value)
    if match:
        parts = [p.strip() for p in match[1].split(",")]
        if len(parts) == 4 and all(re.fullmatch(NUMBER, p) for p in parts):
            numbers = [float(p) for p in parts]
            if 0 <= numbers[0] <= 1 and 0 <= numbers[2] <= 1:
                return "easing", numbers, None
    if re.fullmatch(NUMBER, value):
        return "number", float(value), None
    return "unsupported", None, ("gradient" if "gradient(" in value else
                                  "viewport length" if re.search(r"\dvh\b", value) else
                                  "CSS px needs explicit native mapping" if re.search(r"\dpx\b", value) else
                                  "composite, font family, keyword, or unsupported syntax")


def inventory(source, commit=SOURCE_COMMIT):
    rules, diagnostics = parse_rules(source)
    tokens, duplicates = {}, []
    for domain in DOMAINS:
        scope, repeated = scope_for(rules, domain)
        invalid = cyclic_names(scope)
        duplicates.extend(repeated)
        for name in sorted(scope):
            declaration = scope[name]
            if name in invalid:
                value, issues = None, [{"kind": "cycle", "name": name}]
            else:
                value, issues = resolve_value(declaration["raw"], scope, (name,), invalid)
            kind, native, reason = classify(value)
            tokens.setdefault(name, {})[domain] = {
                "raw": declaration["raw"], "resolved": value, "kind": kind,
                "native": native, "line": declaration["line"],
                "selector": declaration["selector"], "issues": issues,
                **({"reason": reason} if reason else {}),
            }
    unsupported = [{"token": name, "domain": domain, **entry}
                   for name, domains in sorted(tokens.items()) for domain, entry in domains.items()
                   if entry["kind"] in ("unsupported", "unresolved")]
    return {"schema_version": 1, "source_commit": commit,
            "source_sha256": hashlib.sha256(source.encode()).hexdigest(),
            "rpx_basis": {"design_width_pt": 375, "points_per_rpx": 0.5},
            "domains": DOMAINS, "selectors": [r["selector"] for r in rules],
            "diagnostics": diagnostics, "duplicate_declarations": duplicates,
            "tokens": dict(sorted(tokens.items())), "unsupported": unsupported,
            "counts": dict(sorted(Counter(e["kind"] for d in tokens.values() for e in d.values()).items()))}


def literal(number):
    return format(number, ".12g") + (".0" if float(number).is_integer() else "")


def swift_source(report):
    lines = ["// Generated by tools/wxss_tokens.py; DO NOT EDIT.",
             f"// hengyin {report['source_commit']} / chengyinhub-xcx/style/tokens.wxss",
             f"// Source SHA256: {report['source_sha256']}",
             "// 375pt basis: 1rpx = 0.5pt. Unsupported values are omitted, never substituted.",
             "import SwiftUI", "", "extension Theme {", "    enum Generated {"]
    for kind, return_type in (("color", "SwiftUI.Color"), ("length", "CGFloat"),
                              ("duration", "Double"), ("number", "Double"), ("easing", "[Double]")):
        lines += [f"        static func {kind}(_ name: String, in domain: ThemeDomain) -> {return_type}? {{",
                  "            switch name {"]
        for name, domains in report["tokens"].items():
            groups = defaultdict(list)
            for domain, entry in domains.items():
                if entry["kind"] == kind:
                    value = entry["native"]
                    expression = ("SwiftUI.Color(.sRGB, red: %s, green: %s, blue: %s, opacity: %s)" % tuple(map(literal, value)) if kind == "color" else
                                  "[" + ", ".join(map(literal, value)) + "]" if kind == "easing" else literal(value))
                    groups[expression].append(domain)
            if not groups:
                continue
            lines.append(f'            case "{name}":')
            if len(groups) == 1 and len(next(iter(groups.values()))) == len(DOMAINS):
                lines.append("                return " + next(iter(groups)))
            else:
                lines.append("                switch domain {")
                for expression, names in groups.items():
                    lines.append("                case " + ", ".join("." + d for d in names) + ": return " + expression)
                if sum(map(len, groups.values())) != len(DOMAINS):
                    lines.append("                default: return nil")
                lines.append("                }")
        lines += ["            default: return nil", "            }", "        }", ""]
    lines += ["    }", "}", ""]
    return "\n".join(lines)


def self_test():
    import unittest

    class Contracts(unittest.TestCase):
        def test_cascade(self):
            src = 'page {--cy-x:1rpx; --cy-x:2rpx} page.theme-light, .theme-merchant {--cy-x:4rpx} .theme-light {--cy-x:6rpx} page {--cy-y:8rpx}'
            report = inventory(src)
            self.assertEqual(report['tokens']['--cy-x']['player']['native'], 1)
            self.assertEqual(report['tokens']['--cy-x']['merchant']['native'], 2)
            self.assertIn('--cy-y', report['tokens'])
            self.assertTrue(report['duplicate_declarations'])

        def test_important(self):
            report = inventory('page {--cy-x:2rpx!important;--cy-x:4rpx} page.theme-light {--cy-x:6rpx}')
            self.assertEqual(report['tokens']['--cy-x']['merchant']['native'], 1)

        def test_nested_fallback_and_cycle(self):
            scope = {'--cy-a': {'raw': 'var(--cy-b)'}, '--cy-b': {'raw': 'var(--cy-a)'}}
            value, issues = resolve_value('var(--cy-a, var(--missing, rgba(1, 2, 3, .5)))', scope)
            self.assertEqual(value, 'rgba(1, 2, 3, .5)')
            self.assertEqual({i['kind'] for i in issues}, {'cycle', 'missing'})
            self.assertIsNone(resolve_value('var(--cy-a)', scope)[0])

        def test_dimension_math(self):
            self.assertEqual(classify('calc(58rpx * (1 + .5))')[:2], ('length', 43.5))
            for value in ('calc(2rpx * 3rpx)', 'calc(100vh - 8rpx)', 'calc(4rpx / 0)', 'calc(env(safe-area-inset-top) + 4rpx)'):
                self.assertEqual(classify(value)[0], 'unsupported')

        def test_cycle_with_internal_fallback_is_invalid(self):
            report = inventory('page {--cy-a:var(--cy-a,#fff);--cy-b:var(--cy-a,#123)}')
            self.assertEqual(report['tokens']['--cy-a']['player']['kind'], 'unresolved')
            self.assertEqual(report['tokens']['--cy-b']['player']['resolved'], '#123')

        def test_quoted_var_is_literal(self):
            scope = {'--cy-family': {'raw': '"var(--cy-family)"'}}
            self.assertFalse(cyclic_names(scope))
            self.assertEqual(resolve_value(scope['--cy-family']['raw'], scope), ('"var(--cy-family)"', []))
            self.assertEqual(resolve_value('var(--missing,"a)b")', scope)[0], '"a)b"')

        def test_color_validation(self):
            self.assertEqual(color_value('#1234')[-1], 68 / 255)
            for value in ('#12345', '#1234567', 'rgb(999,0,0)', 'rgba(0,0,0,2)'):
                self.assertIsNone(color_value(value))
            self.assertEqual(color_value('rgb(100%,0%,0%)'), [1, 0, 0, 1])

        def test_game_overlay_and_missing(self):
            report = inventory('page {--cy-x:#000} .theme-light {--cy-x:#fff} .theme-game {--cy-g:var(--cy-x);--cy-bad:var(--missing)}')
            self.assertEqual(report['tokens']['--cy-g']['game']['resolved'], '#fff')
            self.assertEqual(report['tokens']['--cy-bad']['game']['kind'], 'unresolved')
            self.assertEqual(len(report['unsupported']), 1)

        def test_syntax_and_comments(self):
            report = inventory('/* a\n b */\npage {\n--cy-x: 8rpx; --cy-family:"a;b", "/* c */";}')
            self.assertEqual(report['tokens']['--cy-x']['player']['line'], 4)
            self.assertEqual(report['tokens']['--cy-family']['player']['resolved'], '"a;b", "/* c */"')
            report = inventory('@media (x) {page {--cy-x:4rpx}} .unknown:hover {--cy-y:4rpx}')
            self.assertEqual(len(report['diagnostics']), 2)
            self.assertFalse(report['tokens'])

        def test_deterministic_and_no_fake_completion(self):
            report = inventory('page {--cy-x:var(--missing);--cy-y:calc(100vh - 1rpx);--cy-z:8rpx}')
            output = swift_source(report)
            self.assertEqual(output, swift_source(inventory('page {--cy-x:var(--missing);--cy-y:calc(100vh - 1rpx);--cy-z:8rpx}')))
            self.assertNotIn('case "--cy-x"', output)
            self.assertNotIn('case "--cy-y"', output)
            self.assertIn('case "--cy-z"', output)

    return 0 if unittest.TextTestRunner().run(unittest.defaultTestLoader.loadTestsFromTestCase(Contracts)).wasSuccessful() else 1


def main(argv=None):
    cli = argparse.ArgumentParser(description=__doc__)
    cli.add_argument('source', type=Path, nargs='?')
    cli.add_argument('output', type=Path, nargs='?')
    cli.add_argument('--swift', type=Path)
    cli.add_argument('--source-commit', default=SOURCE_COMMIT)
    cli.add_argument('--check', action='store_true', help='compare existing outputs; never write')
    cli.add_argument('--self-test', action='store_true')
    args = cli.parse_args(argv)
    if args.self_test:
        return self_test()
    if not args.source or not args.output:
        cli.error('source and output are required unless --self-test')
    if not re.fullmatch(r'[0-9a-f]{40}', args.source_commit):
        cli.error('--source-commit must be a full commit SHA')
    try:
        report = inventory(args.source.read_text(encoding='utf-8'), args.source_commit)
        outputs = [(args.output, json.dumps(report, ensure_ascii=False, indent=2) + '\n')]
        if args.swift:
            outputs.append((args.swift, swift_source(report)))
        for path, content in outputs:
            if args.check:
                if not path.is_file() or path.read_bytes() != content.encode('utf-8'):
                    print(f'drift: {path}', file=sys.stderr)
                    return 1
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(content, encoding='utf-8')
        print(json.dumps({'tokens': len(report['tokens']), 'domain_values': report['counts'],
                          'unsupported': len(report['unsupported']), 'diagnostics': len(report['diagnostics'])}))
        return 0
    except (OSError, UnicodeError, ValueError) as error:
        print(f'wxss_tokens: {error}', file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
