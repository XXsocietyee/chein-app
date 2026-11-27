#!/usr/bin/env python3
"""EN and zh-Hans coverage lint for Resources/*.xcstrings.

Checks every string catalog in Resources, not a single table:
  missing_keys               a lookup or docs/release/ui-strings*.json key is
                             absent from every catalog
  untranslated_values        a required en or zh-Hans unit is missing, blank,
                             or not state "translated"
  key_identifier_mismatches  the call's table does not define the key, but
                             another catalog does; or a catalog key's format
                             specifiers differ from a translated value

Dynamic key prefixes (a literal ending in ".") and unresolved table
expressions are not guesses. Fixture, harness, preview, sample, stub, demo,
and mock Swift files are skipped. This does not run Xcode or export strings.

usage: python3 -B tools/check_catalog_coverage.py
exit 1 when gaps is not 0. The last line is: gaps: N
"""
import glob
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import localization_usage_audit as audit

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LOCALES = ('en', 'zh-Hans')
SPECIFIER = re.compile(r'%(?:\d+\$)?(lld|ld|lu|zu|d|i|u|f|g|s|@)')
CONSTANT = re.compile(
    r'\b(?:let|var)\s+([A-Za-z_][A-Za-z0-9_]*)\s*(?::\s*String\s*)?=\s*"([A-Za-z0-9_]+)"')
IDENT = re.compile(r'[A-Za-z_][A-Za-z0-9_]*')
INTERP_NAME = re.compile(r'\\\(\s*([A-Za-z_][A-Za-z0-9_]*)')
TABLE_LABELS = {'tableName', 'table'}


def specifier_list(text):
    return [('%' + match.group(1)) for match in SPECIFIER.finditer(text or '')]


def normalized_key(key):
    return SPECIFIER.sub('\x00', key)


def string_units(node):
    if not isinstance(node, dict):
        return
    unit = node.get('stringUnit')
    if isinstance(unit, dict):
        yield unit.get('state'), unit.get('value')
    for name in ('variations', 'substitutions'):
        child = node.get(name)
        if isinstance(child, dict):
            for item in child.values():
                if name == 'variations' and isinstance(item, dict):
                    # variations -> plural/device -> form ("one", "other") -> node
                    for form in item.values():
                        yield from string_units(form)
                else:
                    yield from string_units(item)


def substitution_names(node):
    if not isinstance(node, dict):
        return []
    names = []
    substitutions = node.get('substitutions')
    if isinstance(substitutions, dict):
        names.extend(substitutions)
    for name in ('variations', 'substitutions'):
        child = node.get(name)
        if isinstance(child, dict):
            for item in child.values():
                names.extend(substitution_names(item))
    return names


def load_tables(root):
    tables = {}
    for path in sorted(glob.glob(os.path.join(root, 'Resources', '*.xcstrings'))):
        with open(path, encoding='utf-8') as handle:
            catalog = json.load(handle)
        tables[os.path.basename(path)[:-len('.xcstrings')]] = catalog.get('strings') or {}
    return tables


def catalog_gaps(tables):
    untranslated = []
    mismatches = []
    for table, strings in tables.items():
        for key, entry in strings.items():
            if not isinstance(entry, dict) or entry.get('shouldTranslate') is False:
                continue
            localizations = entry.get('localizations') or {}
            for lang in LOCALES:
                wrapped = localizations.get(lang)
                if not isinstance(wrapped, dict):
                    untranslated.append((table, key, lang, 'missing'))
                    continue
                units = list(string_units(wrapped))
                if not units:
                    untranslated.append((table, key, lang, 'missing-value'))
                    continue
                for state, value in units:
                    if state != 'translated':
                        untranslated.append((table, key, lang, state or 'missing-state'))
                    elif not isinstance(value, str) or not value.strip():
                        untranslated.append((table, key, lang, 'blank'))
            key_specs = specifier_list(key)
            if key_specs:
                for lang in LOCALES:
                    wrapped = localizations.get(lang)
                    if not isinstance(wrapped, dict):
                        continue
                    values = [value for _, value in string_units(wrapped) if isinstance(value, str)]
                    if 'variations' in wrapped:
                        # i18n r1: each plural form is a complete format string with the key's specifiers.
                        if any(sorted(key_specs) != sorted(specifier_list(value)) for value in values):
                            mismatches.append((table, key, 'format-identifier', lang))
                    elif values and sorted(key_specs) != sorted(specifier_list(' '.join(values))):
                        mismatches.append((table, key, 'format-identifier', lang))
            names = INTERP_NAME.findall(key)
            if names:
                for lang in LOCALES:
                    wrapped = localizations.get(lang)
                    if not isinstance(wrapped, dict):
                        continue
                    found = set(substitution_names(wrapped))
                    missing = [name for name in names if name not in found]
                    if missing:
                        mismatches.append((table, key, 'substitution-identifier', lang, ','.join(missing)))
    return untranslated, mismatches


def constants(source):
    return dict(CONSTANT.findall(source))


def skip_string(source, index):
    length = len(source)
    hashes = 0
    while index < length and source[index] == '#':
        hashes += 1
        index += 1
    if index >= length or source[index] != '"':
        return index + 1
    multi = source.startswith('"""', index)
    index += 3 if multi else 1
    closer = ('"""' if multi else '"') + ('#' * hashes)
    escape = '\\' + ('#' * hashes)
    while index < length:
        if source.startswith(closer, index):
            return index + len(closer)
        if source.startswith(escape, index):
            index += len(escape)
            if index < length and source[index] == '(':
                depth = 1
                index += 1
                while index < length and depth:
                    if source[index] == '(':
                        depth += 1
                    elif source[index] == ')':
                        depth -= 1
                    elif source[index] == '"':
                        index = skip_string(source, index)
                        continue
                    index += 1
                continue
            if index < length:
                index += 1
            continue
        index += 1
    return index


def skip_balanced(source, index, open_char, close_char):
    length = len(source)
    depth = 0
    while index < length:
        if source.startswith('//', index):
            end = source.find('\n', index)
            index = length if end < 0 else end
            continue
        if source.startswith('/*', index):
            end = source.find('*/', index + 2)
            index = length if end < 0 else end + 2
            continue
        char = source[index]
        if char == '"' or (char == '#' and re.match(r'#+"', source[index:index + 8])):
            index = skip_string(source, index)
            continue
        if char == open_char:
            depth += 1
        elif char == close_char:
            depth -= 1
            if depth == 0:
                return index + 1
        elif char == '{' and open_char != '{':
            index = skip_balanced(source, index, '{', '}')
            continue
        elif char == '[' and open_char != '[':
            index = skip_balanced(source, index, '[', ']')
            continue
        index += 1
    return index


def call_table(source, open_paren, names):
    """Direct tableName/table of the call that opens at open_paren.

    Nested calls and trailing closures belong to other lookups. '' means this
    call does not name a table. None means it names one that cannot be resolved.
    """
    index = open_paren + 1
    length = len(source)
    depth = 1
    while index < length and depth:
        if source.startswith('//', index):
            end = source.find('\n', index)
            index = length if end < 0 else end
            continue
        if source.startswith('/*', index):
            end = source.find('*/', index + 2)
            index = length if end < 0 else end + 2
            continue
        char = source[index]
        if char == '"' or (char == '#' and re.match(r'#+"', source[index:index + 8])):
            index = skip_string(source, index)
            continue
        if char == '{':
            index = skip_balanced(source, index, '{', '}')
            continue
        if char == '[':
            index = skip_balanced(source, index, '[', ']')
            continue
        if char == '(':
            depth += 1
            index += 1
            continue
        if char == ')':
            depth -= 1
            index += 1
            continue
        if depth == 1:
            match = IDENT.match(source, index)
            if match:
                word = match.group(0)
                cursor = match.end()
                while cursor < length and source[cursor] in ' \t\n':
                    cursor += 1
                if word in TABLE_LABELS and cursor < length and source[cursor] == ':' and not source.startswith('::', cursor):
                    cursor += 1
                    while cursor < length and source[cursor] in ' \t\n':
                        cursor += 1
                    if cursor < length and (source[cursor] == '"' or source[cursor] == '#'):
                        end = skip_string(source, cursor)
                        body = source[cursor:end].strip('#').strip('"')
                        return body if re.fullmatch(r'[A-Za-z0-9_]+', body) else None
                    ident = IDENT.match(source, cursor)
                    if ident:
                        return names.get(ident.group(0))
                index = match.end()
                continue
        index += 1
    return ''


def resolved_table(literal, source, names):
    """Table on this call, or on the Text/Label that wraps LocalizedStringKey.

    The table label is often written after the key. An unresolved table
    expression is skipped, not guessed as Localizable.
    """
    for arg in literal.args:
        if getattr(arg, 'label', None) in TABLE_LABELS and not arg.interp:
            return arg.text
    unresolved = False
    for open_paren in reversed(getattr(literal, 'opens', ()) or ()):
        found = call_table(source, open_paren, names)
        if found is None:
            unresolved = True
            break
        if found:
            return found
    if unresolved:
        return None
    return 'Localizable'


def is_lookup(literal):
    if not literal.stack or any(frame[0] == '<interp>' for frame in literal.stack):
        return False
    callee = literal.stack[-1][0]
    label = getattr(literal, 'label', None)
    return (
        (callee in audit.LOC_KEY_CALLEES and literal.argidx == 0 and not label)
        or (callee in ('LocalizedStringResource', 'LocalizedStringKey') and literal.argidx == 0)
        or (callee == 'localized' and label == 'localized')
        or (callee == 'String' and label == 'localized')
        or (callee == 'NSLocalizedString' and literal.argidx == 0))


def key_pattern(literal):
    text = literal.text
    if not text or audit.CJKH.search(text):
        return None
    if literal.interp:
        prefix = text.split('\x00', 1)[0]
        if prefix.endswith('.') or text.endswith('.'):
            return None
        if '.' not in prefix and '_' not in prefix:
            return None
        return text
    if not audit._is_key_shaped(text) or text.endswith('.'):
        return None
    return text


def owners_of(tables, pattern, interpolated):
    found = []
    for table, strings in tables.items():
        for key in strings:
            if interpolated:
                if normalized_key(key) == pattern:
                    found.append((table, key))
            elif key == pattern:
                found.append((table, key))
    return found


def lookup_gaps(root, tables):
    missing = []
    mismatches = []
    for base in ('App', 'Core'):
        paths = sorted(glob.glob(os.path.join(root, base, '**', '*.swift'), recursive=True))
        for path in paths:
            if audit.FIXTURE_FILE.search(os.path.basename(path)):
                continue
            with open(path, encoding='utf-8', errors='replace') as handle:
                source = handle.read()
            names = constants(source)
            relative = os.path.relpath(path, root)
            for literal in audit.lex(relative, source):
                if not is_lookup(literal):
                    continue
                pattern = key_pattern(literal)
                if pattern is None:
                    continue
                table = resolved_table(literal, source, names)
                if table is None:
                    continue
                owners = owners_of(tables, pattern, literal.interp)
                in_table = [key for owner, key in owners if owner == table]
                if in_table:
                    continue
                if owners:
                    mismatches.append((relative, literal.line, table, owners[0][1],
                                       ','.join(sorted({owner for owner, _ in owners}))))
                else:
                    missing.append((table, pattern.replace('\x00', '%@'), relative, literal.line))
    return missing, mismatches


def spec_entries(root):
    directory = os.path.join(root, 'docs', 'release')
    if not os.path.isdir(directory):
        return []
    rows = []
    for path in sorted(glob.glob(os.path.join(directory, 'ui-strings*.json'))):
        with open(path, encoding='utf-8') as handle:
            raw = json.load(handle)
        default = 'Localizable'
        items = raw
        if isinstance(raw, dict):
            default = raw.get('table') or default
            items = raw.get('strings', [])
            if isinstance(items, dict):
                items = [{'key': key, **(value if isinstance(value, dict) else {})} for key, value in items.items()]
        if not isinstance(items, list):
            continue
        for item in items:
            if isinstance(item, dict) and item.get('key'):
                rows.append((item.get('table') or default, item['key'], os.path.relpath(path, root)))
    return rows


def spec_gaps(tables, rows):
    missing = []
    mismatches = []
    for table, key, path in rows:
        owners = [name for name, strings in tables.items() if key in strings]
        if table in owners:
            continue
        if owners:
            mismatches.append((path, 0, table, key, ','.join(owners)))
        else:
            missing.append((table, key, path, 0))
    return missing, mismatches


def unique(rows):
    seen = []
    for row in rows:
        if row not in seen:
            seen.append(row)
    return seen


def gap_identity(table, key):
    return (table, normalized_key(key))


def collect(root=ROOT):
    tables = load_tables(root)
    untranslated, identifier = catalog_gaps(tables)
    missing, mismatched = lookup_gaps(root, tables)
    spec_missing, spec_mismatched = spec_gaps(tables, spec_entries(root))
    # One gap per table and format pattern. Prefer a real catalog or spec key
    # over the %@ stand-in used when an interpolation has no catalog key yet.
    chosen = {}
    for table, key, _, _ in spec_missing + missing:
        ident = gap_identity(table, key)
        current = chosen.get(ident)
        if current is None or '\x00' in current or (current.endswith('%@') and not key.endswith('%@')):
            chosen[ident] = key
    missing_keys = [(table, chosen[(table, normalized_key(key))]) for table, key in sorted(chosen)]
    return {
        'missing_keys': missing_keys,
        'untranslated_values': unique(untranslated),
        'key_identifier_mismatches': unique(identifier + mismatched + spec_mismatched),
    }


def main():
    found = collect()
    order = ('missing_keys', 'untranslated_values', 'key_identifier_mismatches')
    total = 0
    for kind in order:
        rows = found[kind]
        total += len(rows)
        print(f'{kind}: {len(rows)}')
        for row in rows[:50]:
            print('  ', *row)
    print(f'gaps: {total}')
    return 1 if total else 0


if __name__ == '__main__':
    sys.exit(main())
