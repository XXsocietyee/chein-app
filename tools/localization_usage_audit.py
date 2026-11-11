#!/usr/bin/env python3
"""Localization usage audit: every string-catalog key a SwiftUI/Foundation call
looks up must exist, with non-empty `en` and `zh-Hans`, in the catalog (table)
that the call actually reads.

A call with no `tableName:`/`table:` reads `Localizable`. Findings:
  key_missing_everywhere      key exists in no catalog
  key_in_other_catalog        key exists, but not in the table the call reads
                              (the raw key renders at runtime)
  english_literal_not_in_catalog
                              English prose used as an implicit Text/Button/Label key
                              with no Localizable entry (zh-Hans users would see English)
  incomplete_entries          catalog entry missing/empty en or zh-Hans

Fixture/harness/preview files are developer-only surfaces and are skipped.
Calls whose table is computed (e.g. `tableName: table`) are not resolvable here.
usage: python3 tools/localization_usage_audit.py   (exit 1 when any finding)
"""
import glob
import json
import os
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FIXTURE_FILE = re.compile(r'Fixture|Harness|Preview|Sample|Stub|Demo|Mock')
CJK = re.compile(r'[\u3400-\u9fff\uff00-\uffef\u3000-\u303f]')
CJKH = re.compile(r'[\u3400-\u9fff]')
LOC_KEY_CALLEES = {
    'Text', 'Button', 'Label', 'Toggle', 'Section', 'navigationTitle', 'LocalizedStringKey',
    'LocalizedStringResource', 'NSLocalizedString', 'TextField', 'SecureField', 'Picker', 'Link', 'Menu',
    'DisclosureGroup', 'ContentUnavailableView', 'ProgressView', 'Stepper', 'DatePicker', 'TabItem',
    'LabeledContent', 'accessibilityLabel', 'accessibilityHint', 'accessibilityValue', 'help',
    'confirmationDialog', 'alert', 'navigationBarTitle', 'badge', 'prompt'}

# ---- Swift string-literal lexer (comments skipped; plain, triple-quoted, raw strings, interpolation)


@dataclass
class Lit:
    file: str; line: int; text: str          # text with interpolations replaced by \x00
    interp: bool
    stack: list = field(default_factory=list)  # [(callee, argIndex, label)] outermost->innermost
    prev: str = ''                              # preceding ~80 chars of code
    args: list = field(default_factory=list)   # sibling literal args of innermost call (filled later)

IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')

def lex(path, src):
    i, n, line = 0, len(src), 1
    stack = []   # entries: dict(callee, idx, label, open)
    lits = []
    last_ident = ''; last_ident_chain = ''; pending_label = ''
    code_hist = []
    def hist(): return ''.join(code_hist)[-90:]
    def read_string(i, line):
        # returns (text, interp, newi, newline, nested_lits)
        hashes = 0
        j = i
        while src[j] == '#': hashes += 1; j += 1
        assert src[j] == '"'
        multi = src.startswith('"""', j)
        j += 3 if multi else 1
        closer = ('"""' if multi else '"') + '#' * hashes
        esc = '\\' + '#' * hashes
        buf = []; interp = False; nested = []
        startline = line
        while j < n:
            if src.startswith(closer, j):
                j += len(closer); break
            if src.startswith(esc, j):
                k = j + len(esc)
                if k < n and src[k] == '(':
                    interp = True; buf.append('\x00')
                    depth = 1; k += 1; s = k
                    while k < n and depth:
                        c = src[k]
                        if c == '(': depth += 1
                        elif c == ')': depth -= 1
                        elif c == '"':
                            # nested string inside interpolation
                            try:
                                t, ip, k2, line2, _ = read_string(k, line)
                                nested.append((t, ip, line)); k = k2; line = line2; continue
                            except Exception: pass
                        elif c == '\n': line += 1
                        k += 1
                    j = k; continue
                else:
                    buf.append(src[j:k+1]); j = k + 1
                    if k < n and src[k] == '\n': line += 1
                    continue
            if src[j] == '\n':
                line += 1
            buf.append(src[j]); j += 1
        return ''.join(buf), interp, j, line, nested
    while i < n:
        c = src[i]
        if c == '\n': line += 1; i += 1; code_hist.append(' '); continue
        if src.startswith('//', i):
            j = src.find('\n', i); i = n if j < 0 else j; continue
        if src.startswith('/*', i):
            depth = 1; j = i + 2
            while j < n and depth:
                if src.startswith('/*', j): depth += 1; j += 2
                elif src.startswith('*/', j): depth -= 1; j += 2
                else:
                    if src[j] == '\n': line += 1
                    j += 1
            i = j; continue
        if c == '"' or (c == '#' and re.match(r'#+"', src[i:i+8])):
            sl = line
            try:
                t, ip, j, line, nested = read_string(i, line)
            except Exception:
                i += 1; continue
            lit = Lit(path, sl, t, ip, [(s['callee'], s['idx'], s['label']) for s in stack], hist(), [])
            lit.label = pending_label if hasattr(lit, 'label') else None
            lit.label = pending_label
            lit.argidx = stack[-1]['idx'] if stack else -1
            lit.call_labels = [st['labels'] for st in stack]
            lit.opens = tuple(st['open'] for st in stack)
            if stack: stack[-1]['lits'].append(lit)
            lits.append(lit)
            for t2, ip2, l2 in nested:
                nl = Lit(path, l2, t2, ip2, [(s['callee'], s['idx'], s['label']) for s in stack] + [('<interp>', 0, '')], hist(), [])
                nl.label = ''; nl.argidx = -1; nl.call_labels = []; lits.append(nl)
            code_hist.append('"S"'); pending_label = ''
            i = j; continue
        m = IDENT.match(src, i)
        if m:
            w = m.group(0); i = m.end()
            # label?  ident followed by ':'
            k = i
            while k < n and src[k] in ' \t': k += 1
            if k < n and src[k] == ':' and not src.startswith('::', k) and stack:
                pending_label = w; stack[-1]['labels'].add(w)
            last_ident = w; code_hist.append(w); continue
        if c == '(':
            callee = last_ident if code_hist and re.fullmatch(r'[A-Za-z_]\w*', code_hist[-1] or '') else ''
            if code_hist and code_hist[-1] in ('?','!'): callee = ''
            prevw = code_hist[-1] if code_hist else ''
            stack.append(dict(callee=callee if re.fullmatch(r'[A-Za-z_]\w*', prevw) else '', idx=0, label='', lits=[], labels=set(), open=i))
            pending_label = ''; code_hist.append('('); i += 1; continue
        if c == ')':
            if stack:
                s = stack.pop()
                for l in s['lits']: l.args = s['lits']
            code_hist.append(')'); i += 1; pending_label = ''; continue
        if c == ',' and stack:
            stack[-1]['idx'] += 1; pending_label = ''
        if c == ':' and pending_label == '' : pass
        code_hist.append(c); i += 1
    return lits


# ---- catalog + usage scan
def load_catalogs(root=ROOT):
    tables = {}
    for path in sorted(glob.glob(os.path.join(root, 'Resources', '*.xcstrings'))):
        with open(path, encoding='utf-8') as handle:
            tables[os.path.basename(path)[:-len('.xcstrings')]] = json.load(handle)['strings']
    return tables


def _entry_value(entry, lang):
    unit = (entry.get('localizations', {}).get(lang) or {})
    if 'stringUnit' in unit:
        return unit['stringUnit'].get('value')
    if 'variations' in unit:
        return json.dumps(unit['variations'], ensure_ascii=False)
    return None


def incomplete_entries(tables):
    bad = []
    for table, strings in tables.items():
        for key, entry in strings.items():
            if entry.get('shouldTranslate') is False:
                continue
            for lang in ('en', 'zh-Hans'):
                value = _entry_value(entry, lang)
                if value is None or not value.strip():
                    bad.append((table, key, lang))
    return bad


def _is_key_shaped(text):
    return (not text.startswith('.') and not text.isupper()
            and bool(re.fullmatch(r'[A-Za-z0-9_.\-]+(?: %[@dlLqu0-9$]+)*(?: [%@lLdq0-9$]+)*', text))
            and ('.' in text or '_' in text))


def scan(root=ROOT):
    tables = load_catalogs(root)
    all_keys = set().union(*(set(s) for s in tables.values()))
    found = defaultdict(list)
    paths = sorted(glob.glob(os.path.join(root, 'App', '**', '*.swift'), recursive=True))
    for path in paths:
        if FIXTURE_FILE.search(os.path.basename(path)):
            continue
        rel = os.path.relpath(path, root)
        with open(path, encoding='utf-8', errors='replace') as handle:
            src = handle.read()
        for lit in lex(rel, src):
            callee = lit.stack[-1][0] if lit.stack else ''
            text = lit.text
            is_key_call = (
                (callee in LOC_KEY_CALLEES and lit.argidx == 0 and not lit.label)
                or (callee in ('LocalizedStringResource', 'LocalizedStringKey') and lit.argidx == 0)
                or (callee == 'localized' and lit.label == 'localized')
                or (callee == 'String' and lit.label == 'localized')
                or (callee == 'NSLocalizedString' and lit.argidx == 0))
            if not is_key_call or lit.interp or not text or CJKH.search(text):
                continue
            table = None
            for arg in lit.args:
                if arg.label in ('tableName', 'table'):
                    table = arg.text
            dynamic_table = any({'tableName', 'table'} & labels for labels in lit.call_labels[-3:])
            if _is_key_shaped(text):
                if text.endswith('.'):
                    continue  # dynamic key prefix
                if dynamic_table and not table:
                    continue
                table = table or 'Localizable'
                if table not in tables:
                    found['key_table_missing'].append((rel, lit.line, text, table))
                elif text not in tables[table]:
                    if text in all_keys:
                        found['key_in_other_catalog'].append((rel, lit.line, text, table))
                    else:
                        found['key_missing_everywhere'].append((rel, lit.line, text, table))
            elif (callee in ('Text', 'Button', 'Label') and lit.argidx == 0 and not lit.label
                  and re.search(r'[A-Za-z]{3,} [A-Za-z]{2,}', text)
                  and text not in tables['Localizable']
                  # A same-line Chinese sibling branch (`zh ? "中文" : "English"`) is an explicit bilingual pair, not an implicit key.
                  and not CJKH.search(src.splitlines()[lit.line - 1])):
                found['english_literal_not_in_catalog'].append((rel, lit.line, text, 'Localizable'))
    found['incomplete_entries'] = incomplete_entries(tables)
    return found


FINDING_KINDS = ('key_missing_everywhere', 'key_in_other_catalog', 'key_table_missing',
                 'english_literal_not_in_catalog', 'incomplete_entries')


def main():
    found = scan()
    status = 0
    for kind in FINDING_KINDS:
        rows = found.get(kind, [])
        print(f'{kind}: {len(rows)}')
        for row in rows[:50]:
            print('  ', *row)
        status |= bool(rows)
    return status


if __name__ == '__main__':
    sys.exit(main())
