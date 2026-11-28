#!/usr/bin/env python3
"""Offline structural checks, NOT a Swift compiler or runtime test.

Also fails closed on two merge breaks that have already shown up on a Mac
build outside the diff that introduced them: an `import QuestifyCore` in App/
that is not inside `#if canImport(QuestifyCore)`, and a top-level type name
declared twice in App/ and Core/ (one Swift module). A duplicate type is the
usual source of the "wrong argument order" errors that follow a bad merge.
"""
import hashlib, json, pathlib, re, shutil, subprocess, sys, tempfile, xml.etree.ElementTree as ET
ROOT=pathlib.Path(__file__).resolve().parents[1]
# Independent parser for the generated OpenStep subset (quoted keys/values, integers).
def parse_project(text):
    text=re.sub(r'^//.*$', '', text, flags=re.M)
    tokens=re.findall(r'"(?:\\.|[^"\\])*"|\d+|[{}()=;,]', text)
    index=0
    def take(expected=None):
        nonlocal index
        value=tokens[index]; index+=1
        if expected is not None: assert value==expected, (value,expected)
        return value
    def value():
        token=take()
        if token=='{':
            result={}
            while tokens[index]!='}':
                key=json.loads(take()); take('='); result[key]=value(); take(';')
            take('}'); return result
        if token=='(':
            result=[]
            while tokens[index]!=')': result.append(value()); take(',')
            take(')'); return result
        return json.loads(token)
    result=value(); assert index==len(tokens); return result
def validate_bilingual_catalog(catalog, table, allowed_source_languages=('en',)):
    """Keep the same complete, translated English/Simplified-Chinese contract."""
    assert catalog['sourceLanguage'] in allowed_source_languages, table
    for key,entry in catalog['strings'].items():
        assert set(entry['localizations'])=={'en','zh-Hans'}, (table,key)
        for lang in ['en','zh-Hans']:
            localization=entry['localizations'][lang]
            # i18n r1: an English count string may vary by plural (Xcode `variations.plural`); every form is translated.
            units=[form['stringUnit'] for form in localization['variations']['plural'].values()] if 'variations' in localization else [localization['stringUnit']]
            assert 'variations' not in localization or 'other' in localization['variations']['plural'], (table,key,lang)
            for unit in units:
                assert unit['state']=='translated' and unit['value'].strip(), (table,key,lang)
    return set(catalog['strings'])

def validate_literal_text_tables(source, root, objects, project_obj):
    """Validate this narrow literal Text overload, never union tables globally.

    Dynamic keys/tables, interpolation and explicit bundles are not exemptions:
    they remain in the original default-table scan. A table must be a unique
    catalog in the app's actual resource build phase, not just a file reference.
    """
    patterns=[
        re.compile(r'(?<![\w.])Text\s*\(\s*"([A-Za-z0-9]+(?:\.[A-Za-z0-9]+)+)"\s*,\s*tableName\s*:\s*"([A-Za-z0-9_]+)"\s*\)'),
        re.compile(r'(?<![\w.])LocalizedStringKey\s*\(\s*"([A-Za-z0-9]+(?:\.[A-Za-z0-9]+)+)"\s*\)\s*,\s*tableName\s*:\s*"([A-Za-z0-9_]+)"'),
    ]
    if not any(pattern.search(source) for pattern in patterns): return source
    applications=[objects[t] for t in project_obj['targets']
                  if objects[t].get('productType')=='com.apple.product-type.application']
    assert len(applications)==1, 'Explicit Text table requires one known application target'
    registered={}
    for phase_id in applications[0]['buildPhases']:
        phase=objects[phase_id]
        if phase['isa']!='PBXResourcesBuildPhase': continue
        for build_id in phase['files']:
            ref=objects[objects[build_id]['fileRef']]
            path=pathlib.PurePosixPath(ref.get('path',''))
            if path.suffix!='.xcstrings': continue
            assert ref.get('sourceTree')=='<group>' and not path.is_absolute() and '..' not in path.parts, ('Invalid catalog resource path',str(path))
            registered.setdefault(path.stem,[]).append(path)
    tables={}
    def checked(match):
        key,table=match.groups()
        if table not in tables:
            paths=registered.get(table,[])
            assert len(paths)==1, ('Explicit Text table is absent or ambiguous in app resources',table)
            path=root/paths[0]
            assert path.is_file() and path.resolve().is_relative_to(root.resolve()), ('Catalog is outside source root',table)
            tables[table]=validate_bilingual_catalog(json.loads(path.read_text()),table,('en','zh-Hans'))
        assert key in tables[table], ('Missing key in explicit Text table',table,key)
        # Mask only this validated key occurrence; an identical default Text
        # elsewhere still has to pass the original Localizable-key assertion.
        start,end=match.span(1)
        return match.group(0)[:start-match.start()]+match.group(0)[end-match.start():]
    for pattern in patterns:
        source=pattern.sub(checked,source)
    return source

def validate_literal_resource_tables(source, root, objects, project_obj):
    """Prove only a literal, locale-bound Foundation String resource lookup.

    Keep unsupported call shapes in the original default-key scan: no dynamic
    table/key, interpolation, extra bundle, qualified call or locale expression.
    All table/key/resource/bilingual checks belong to the unchanged Text helper.
    """
    pattern=re.compile(r'(?<![\w.])String\s*\(\s*localized\s*:\s*LocalizedStringResource\s*\(\s*"([A-Za-z0-9]+(?:\.[A-Za-z0-9]+)+)"\s*,\s*table\s*:\s*"([A-Za-z0-9_]+)"\s*,\s*locale\s*:\s*[A-Za-z_][A-Za-z0-9_]*\s*\)\s*\)')
    def checked(match):
        key,table=match.groups()
        literal='Text('+json.dumps(key)+', tableName: '+json.dumps(table)+')'
        assert validate_literal_text_tables(literal,root,objects,project_obj)!=literal
        # Mask this key occurrence alone. Default Text or any unproven lookup
        # using the same key must still pass the original Localizable gate.
        start,end=match.span(1)
        return match.group(0)[:start-match.start()]+match.group(0)[end-match.start():]
    return pattern.sub(checked,source)

def validate_bound_participant_issue_tables(source, root, objects, project_obj):
    """Prove one closed dynamic lookup shape; never exempt arbitrary dynamic tables.

    An immutable ParticipantScreenIssue.key is bound to a literal table in the
    same single-line switch case. Its renderer must forward those exact fields.
    Unsupported mutations/renderers fail closed. Only the proven assignment
    occurrence is masked; default Text using the same key is still checked.
    """
    declarations=list(re.finditer(r'^struct ParticipantScreenIssue\s*\{\n(?P<body>.*?)^\}', source, re.M | re.S))
    if not declarations: return source
    assert len(declarations)==1, 'Ambiguous ParticipantScreenIssue binding'
    declaration=declarations[0]; body=declaration.group('body')
    pairs=list(re.finditer(r'^\s*case\s+\.[A-Za-z0-9_]+:\s*key\s*=\s*"(?P<key>[A-Za-z0-9]+(?:\.[A-Za-z0-9]+)+)";\s*tableName\s*=\s*"(?P<table>[A-Za-z0-9_]+)"[ \t]*$', body, re.M))
    if not pairs: return source
    assert '/*' not in body and '//' not in body, 'Unsupported comments in dynamic issue binding'
    assert re.search(r'^\s*let key:\s*String\s*$',body,re.M), 'Issue key must remain immutable'
    assert re.search(r'^\s*private\(set\) var tableName:\s*String\?\s*=\s*nil\s*$',body,re.M), 'Issue table must start nil and have a private setter'
    assert len(re.findall(r'\btableName\b',body))==len(pairs)+1, 'Unproven issue table mutation or use'
    switches=list(re.finditer(r'\bswitch block\s*\{(?P<cases>[^{}]*)\}',body))
    assert len(switches)==1, 'Expected one closed issue-reason switch'
    switch=switches[0]
    case_pattern=re.compile(r'case\s+\.[A-Za-z0-9_]+:\s*key\s*=\s*"[A-Za-z0-9]+(?:\.[A-Za-z0-9]+)+"(?:;\s*tableName\s*=\s*"[A-Za-z0-9_]+")?')
    for line in switch.group('cases').splitlines():
        if line.strip(): assert case_pattern.fullmatch(line.strip()), 'Unsupported issue switch case body'
    assert all(switch.start('cases')<=pair.start('key')<switch.end('cases') for pair in pairs), 'Binding is outside the closed switch'
    renderers=list(re.finditer(r'^struct ParticipantIssueText:\s*View\s*\{\n(?P<body>.*?)^\}',source,re.M | re.S))
    assert len(renderers)==1, 'Expected one ParticipantIssueText renderer'
    renderer=renderers[0].group('body')
    assert '/*' not in renderer and '//' not in renderer, 'Unsupported comments in dynamic issue renderer'
    assert re.search(r'^\s*let issue:\s*ParticipantScreenIssue\s*$',renderer,re.M), 'Renderer must consume the bound issue type'
    call=r'(?<![\w.])Text\s*\(\s*LocalizedStringKey\s*\(\s*issue\.key\s*\)\s*,\s*tableName:\s*issue\.tableName\s*\)'
    assert len(re.findall(call,renderer))==1, 'Renderer must forward the exact key and table without another bundle'
    assert len(re.findall(r'issue\.key\b',renderer))==1 and len(re.findall(r'issue\.tableName\b',renderer))==1, 'Ambiguous dynamic issue lookup'
    spans=[]
    for pair in pairs:
        key,table=pair.group('key','table')
        # Reuse all original resource-membership, unique-table, key and complete
        # bilingual checks, without changing that validator or unioning catalogs.
        literal='Text('+json.dumps(key)+', tableName: '+json.dumps(table)+')'
        assert validate_literal_text_tables(literal,root,objects,project_obj)!=literal
        spans.append((declaration.start('body')+pair.start('key'), declaration.start('body')+pair.end('key')))
    for start,end in reversed(spans): source=source[:start]+source[end:]
    return source

def _merge_raw_open(line, index):
    """Return (hash_count, index_after_opening_quote) when `line[index:]` starts a raw string."""
    if line[index] != '#':
        return None
    count = 0
    while index + count < len(line) and line[index + count] == '#':
        count += 1
    if count and index + count < len(line) and line[index + count] == '"':
        return count, index + count + 1
    return None

def _merge_raw_end(line, index, hashes):
    """Index just after the closing `"#…` delimiter, or None when this line does not close it."""
    while index < len(line):
        if line[index] == '"':
            found = 0
            while index + 1 + found < len(line) and line[index + 1 + found] == '#':
                found += 1
            if found >= hashes:
                return index + 1 + hashes
        index += 1
    return None

def _merge_logical_lines(text):
    """Yield (line_number, code) with comments removed and literal contents dropped.

    Brace and directive scans then ignore strings. A block comment, `\"\"\"` string,
    or raw string (`#\"…\"#`) that runs past the end of the file stays open.
    """
    block = False
    triple = False
    raw_hashes = 0
    normal = False
    for number, line in enumerate(text.splitlines(), 1):
        out = []
        index = 0
        while index < len(line):
            if block:
                end = line.find('*/', index)
                if end < 0:
                    break
                block = False
                index = end + 2
                continue
            if triple:
                end = line.find('"""', index)
                if end < 0:
                    break
                triple = False
                index = end + 3
                continue
            if raw_hashes:
                end = _merge_raw_end(line, index, raw_hashes)
                if end is None:
                    break
                raw_hashes = 0
                index = end
                continue
            if normal:
                if line[index] == '\\' and index + 1 < len(line):
                    index += 2
                    continue
                if line[index] == '"':
                    normal = False
                index += 1
                continue
            if line.startswith('//', index):
                break
            if line.startswith('/*', index):
                block = True
                index += 2
                continue
            if line.startswith('"""', index):
                triple = True
                index += 3
                continue
            opened = _merge_raw_open(line, index)
            if opened is not None:
                hashes, after = opened
                end = _merge_raw_end(line, after, hashes)
                if end is None:
                    raw_hashes = hashes
                    break
                index = end
                continue
            if line[index] == '"':
                normal = True
                index += 1
                continue
            out.append(line[index])
            index += 1
        yield number, ''.join(out)

def _merge_directive(code):
    """Return (kind, expression) for a Swift `#if` / `#elseif` / `#else` / `#endif` line."""
    stripped = code.strip()
    for name in ('elseif', 'endif', 'else', 'if'):
        prefix = '#' + name
        if not stripped.startswith(prefix):
            continue
        if len(stripped) == len(prefix) or (not stripped[len(prefix)].isalnum() and stripped[len(prefix)] != '_'):
            return name, stripped[len(prefix):]
    return None, ''

def _merge_condition(expression):
    """Return (true_requires, false_requires) for `canImport(QuestifyCore)`.

    `true_requires` means the branch being active implies the module can be imported.
    `false_requires` means the branch being inactive implies that. Other atoms
    (`os(iOS)`, `compiler(>=5.9)`) imply neither. `&&` / `||` / `!` follow that.
    A condition that cannot be parsed does not count as a guard.
    """
    tokens = re.findall(r'&&|\|\||[!()]|[A-Za-z_][A-Za-z0-9_]*|\d+(?:\.\d+)?|>=|<=|==|!=|[<>*,]', expression)
    pos = 0

    def peek():
        return tokens[pos] if pos < len(tokens) else None

    def eat(expected=None):
        nonlocal pos
        token = peek()
        if token is None or (expected is not None and token != expected):
            return None
        pos += 1
        return token

    def skip_call():
        if eat('(') is None:
            return
        depth = 1
        while depth and peek() is not None:
            token = eat()
            if token == '(':
                depth += 1
            elif token == ')':
                depth -= 1

    def parse_or():
        left = parse_and()
        while peek() == '||':
            eat('||')
            right = parse_and()
            left = (left[0] and right[0], left[1] or right[1])
        return left

    def parse_and():
        left = parse_unary()
        while peek() == '&&':
            eat('&&')
            right = parse_unary()
            left = (left[0] or right[0], left[1] and right[1])
        return left

    def parse_unary():
        if peek() == '!':
            eat('!')
            inner = parse_unary()
            return (inner[1], inner[0])
        if peek() == '(':
            eat('(')
            value = parse_or()
            eat(')')
            return value
        ident = eat()
        if ident is None:
            return (False, False)
        if ident == 'canImport' and peek() == '(':
            eat('(')
            arg = eat()
            depth = 1
            while depth and peek() is not None:
                token = eat()
                if token == '(':
                    depth += 1
                elif token == ')':
                    depth -= 1
            return (arg == 'QuestifyCore', False)
        if peek() == '(':
            skip_call()
        return (False, False)

    return parse_or()

_MERGE_IMPORT = re.compile(
    r'^\s*(?:@testable\s+)?import\s+(?:(?:struct|class|enum|protocol|typealias|func|var|let)\s+)?QuestifyCore\b')
_MERGE_TYPE = re.compile(
    r'^\s*(?:@[\w.]+(?:\([^)]*\))?\s+)*'
    r'((?:(?:public|internal|private|fileprivate|open|final|indirect|nonisolated|package)\s+)*)'
    r'(struct|class|enum|protocol|actor|typealias)\s+'
    r'([A-Za-z_]\w*)(?!\s*\.)')
_MERGE_TYPE_KEYWORDS = {'func', 'var', 'let', 'subscript', 'init', 'deinit', 'typealias', 'associatedtype'}

def unguarded_questify_core_imports(text):
    """Return 1-based lines of `import QuestifyCore` outside `#if canImport(QuestifyCore)`.

    App sources are built in lanes that do not always have the Core package, so a
    bare import fails that compile. The active `#if` / `#elseif` condition must
    require `canImport(QuestifyCore)` (`&&` with other conditions still counts;
    `||` does not). `#else` counts only when every previous branch being false
    implies the module is present (`#if !canImport(QuestifyCore)` / `#else`).
    Comments and string literals are not imports.
    """
    stack = []
    hits = []
    for number, code in _merge_logical_lines(text):
        kind, expression = _merge_directive(code)
        if kind == 'if':
            stack.append({'branches': [_merge_condition(expression)], 'is_else': False})
        elif kind == 'elseif' and stack:
            stack[-1]['branches'].append(_merge_condition(expression))
            stack[-1]['is_else'] = False
        elif kind == 'else' and stack:
            stack[-1]['is_else'] = True
        elif kind == 'endif' and stack:
            stack.pop()
        if not _MERGE_IMPORT.match(code):
            continue
        guarded = False
        for frame in stack:
            if frame['is_else']:
                if frame['branches'] and all(branch[1] for branch in frame['branches']):
                    guarded = True
                    break
            elif frame['branches'] and frame['branches'][-1][0]:
                guarded = True
                break
        if not guarded:
            hits.append(number)
    return hits

def _merge_exclusive(left, right):
    """True when two `#if` stacks are different branches of the same group."""
    branches = dict(left)
    return any(key in branches and branches[key] != branch for key, branch in right)

def _merge_type_declarations(path, text):
    """Top-level type declarations in one file: name, kind, file-private, line, if-stack."""
    declarations = []
    depth = 0
    stack = []
    counter = 0
    for number, code in _merge_logical_lines(text):
        kind, _expression = _merge_directive(code)
        if kind == 'if':
            counter += 1
            stack.append([f'{path}#{counter}', 0])
        elif kind in ('elseif', 'else') and stack:
            stack[-1][1] += 1
        elif kind == 'endif' and stack:
            stack.pop()
        if depth == 0:
            match = _MERGE_TYPE.match(code)
            if match:
                access, type_kind, name = match.group(1), match.group(2), match.group(3)
                if name not in _MERGE_TYPE_KEYWORDS:
                    words = set(access.split())
                    declarations.append({
                        'name': name,
                        'kind': type_kind,
                        'file_private': 'private' in words or 'fileprivate' in words,
                        'path': path,
                        'line': number,
                        'stack': tuple(tuple(frame) for frame in stack),
                    })
        depth += code.count('{') - code.count('}')
    return declarations

def duplicate_top_level_types(files):
    """Return clash descriptions for top-level type names that cannot share one module.

    `files` is a sequence of `(relative_path, source)` covering App/ and Core/.
    A `struct` / `class` / `enum` / `protocol` / `actor` / `typealias` at file
    scope may be declared once. Two `private` or `fileprivate` copies in
    different files are allowed. A file-private copy still clashes with a
    module-visible type of the same name: that name is already in scope in the
    private file (`invalid redeclaration`), which is the merge break behind a
    later "wrong argument order" diagnostic. Nested types, extensions, comments,
    and literals are not declarations. Different branches of one file's `#if`
    group are not a clash. An `#if DEBUG` copy next to an unconditional one is.
    """
    by_name = {}
    for path, text in files:
        for declaration in _merge_type_declarations(path, text):
            by_name.setdefault(declaration['name'], []).append(declaration)
    clashes = []
    for name, rows in by_name.items():
        if len(rows) < 2:
            continue
        involved = set()
        for index, left in enumerate(rows):
            for other, right in enumerate(rows[index + 1:], index + 1):
                if _merge_exclusive(left['stack'], right['stack']):
                    continue
                if left['path'] != right['path'] and left['file_private'] and right['file_private']:
                    continue
                involved.add(index)
                involved.add(other)
        if not involved:
            continue
        places = ', '.join(
            f"{rows[index]['path']}:{rows[index]['line']} ({rows[index]['kind']})"
            for index in sorted(involved, key=lambda item: (rows[item]['path'], rows[item]['line'], rows[item]['kind'])))
        clashes.append(f'{name}: {places}')
    clashes.sort()
    return clashes

project_path=ROOT/'Questify.xcodeproj/project.pbxproj'
project=parse_project(project_path.read_text())
objects=project['objects']; project_obj=objects[project['rootObject']]
assert project_obj['isa']=='PBXProject'
refs={'baseConfigurationReference','buildConfigurationList','fileRef','mainGroup','productRefGroup','productReference','target','targetProxy','containerPortal','remoteGlobalIDString','remoteRef'}
list_refs={'buildConfigurations','buildPhases','children','dependencies','files','targets'}
for key,obj in objects.items():
    for k,v in obj.items():
        if k=='remoteGlobalIDString' and objects[obj['containerPortal']]['isa']=='PBXFileReference':
            reference=objects[obj['containerPortal']]
            assert reference.get('lastKnownFileType')=='wrapper.pb-project',reference
            upstream=(ROOT/reference['path']/'project.pbxproj').read_text()
            assert re.search(r'\b'+re.escape(v)+r'\s*/\*[^*]+\*/\s*=\s*\{',upstream),(key,k,v)
        elif k in refs: assert v in objects,(key,k,v)
        if k in list_refs:
            for ref in v: assert ref in objects,(key,k,ref)
    if obj['isa']=='PBXFileReference' and obj['sourceTree']=='<group>':
        if obj.get('lastKnownFileType')=='wrapper.pb-project':
            assert (ROOT/obj['path']/'project.pbxproj').is_file(),obj['path']
        elif obj.get('lastKnownFileType')=='folder.assetcatalog':
            assert (ROOT/obj['path']).is_dir(),obj['path']
        else: assert (ROOT/obj['path']).is_file(),obj['path']
source_paths={o['path'] for o in objects.values() if o['isa']=='PBXFileReference' and o.get('lastKnownFileType')=='sourcecode.swift'}
assert source_paths=={str(p.relative_to(ROOT)) for folder in ['App','Core','Tests/AppUITests','Tests/AppUnitTests','LiveActivityWidget'] for p in (ROOT/folder).rglob('*.swift')}
# Inspect actual target membership independently of the generator. Swift files
# sharing a basename collide in per-target localization extraction outputs.
for target_id in project_obj['targets']:
    target=objects[target_id]
    by_stem={}
    for phase_id in target['buildPhases']:
        phase=objects[phase_id]
        if phase['isa']!='PBXSourcesBuildPhase': continue
        for build_id in phase['files']:
            ref=objects[objects[build_id]['fileRef']]
            if ref.get('lastKnownFileType')!='sourcecode.swift': continue
            by_stem.setdefault(pathlib.Path(ref['path']).stem.casefold(),[]).append(ref['path'])
    duplicates=[paths for paths in by_stem.values() if len(paths)>1]
    assert not duplicates, ('Duplicate Swift basenames in target',target['name'],duplicates)
# App/ and Core/ are one Swift module. These two checks are the merge breaks that
# already failed a Mac build outside the lane diff: a bare `import QuestifyCore`
# (every App import must sit in `#if canImport(QuestifyCore)`), and a second
# top-level type of the same name (the usual cause of a follow-on argument-order
# error). No generated file is skipped: App/Theme/Theme+Generated.swift is an
# extension with nested types, so it has neither an import nor a top-level type.
_module_sources=[]
for _folder in ('App','Core'):
    _base=ROOT/_folder
    if not _base.is_dir(): continue
    for _path in sorted(_base.rglob('*.swift')):
        _module_sources.append((_path.relative_to(ROOT).as_posix(), _path.read_text()))
_unguarded_imports=[f'{_rel}:{_line}: import QuestifyCore' for _rel,_text in _module_sources if _rel.startswith('App/') for _line in unguarded_questify_core_imports(_text)]
assert not _unguarded_imports, ('Unguarded import QuestifyCore in App/; wrap it in #if canImport(QuestifyCore)', _unguarded_imports)
_duplicate_types=duplicate_top_level_types(_module_sources)
assert not _duplicate_types, ('Duplicate top-level type names across App/ and Core/', _duplicate_types)
catalog=json.loads((ROOT/'Resources/Localizable.xcstrings').read_text())
validate_bilingual_catalog(catalog,'Localizable')
ui='\n'.join(p.read_text() for p in (ROOT/'App').glob('*.swift'))
# Every dot-separated UI string is a localized key except explicit accessibility/storage IDs.
localizable_ui=re.sub(r'\.accessibilityIdentifier\("(?:\\.|[^"\\])*"\)', '', ui)
localizable_ui=re.sub(r'(?:accessibilityPrefix|identifier|messageIdentifier|actionIdentifier):\s*"(?:\\.|[^"\\])*"','',localizable_ui)
localizable_ui=re.sub(r'primaryIdentifier:[^\n]*','',localizable_ui)
localizable_ui=re.sub(r'(case\s+\.[A-Za-z]+:\s*return\s+)"[a-z0-9.]+"','',localizable_ui)  # SF Symbol names returned from symbol(for:) switches
localizable_ui=re.sub(r'(?:confirmIdentifier|icon|submitID):\s*"(?:\\.|[^"\\])*"','',localizable_ui)
localizable_ui=re.sub(r'(?<![\w.])id:\s*"(?:\\.|[^"\\])*"','',localizable_ui)
localizable_ui=re.sub(r'@AppStorage\("(?:\\.|[^"\\])*"\)', '', localizable_ui)
localizable_ui=re.sub(r'\.accessibilityIdentifier\s*=\s*"(?:\\.|[^"\\])*"', '', localizable_ui)
localizable_ui=re.sub(r'(?:systemImage|systemName|symbol):\s*"(?:\\.|[^"\\])*"', '', localizable_ui)
# SF Symbol name returned for the search-map layers tile, not a localization key.
localizable_ui=localizable_ui.replace('case .layers: "square.3.layers.3d"', 'case .layers: ""')
# SF Symbol names in this status-chip ternary, not localization keys.
localizable_ui=localizable_ui.replace('systemImage: snapshot.isDone(node) ? "checkmark.seal.fill" : snapshot.isLocked(node) ? (node.weatherLocked == true ? "cloud.rain.fill" : "lock.fill") : "play.circle"', '')
# These four values are explicit nonlocalized identifiers at these exact calls.
# Do not exclude the same strings when used by Text or localization lookup.
localizable_ui=localizable_ui.replace('.accessibilityIdentifier(effectiveReduceMotion ? "roam.motion.status.reduced" : "roam.motion.status.system")', '')
localizable_ui=localizable_ui.replace('.accessibilityIdentifier(snapshot.alwaysAuthorized ? "roam.locationSettings.always.granted" : "roam.locationSettings.always.notGranted")', '')
localizable_ui=localizable_ui.replace('.accessibilityIdentifier(snapshot.servicesEnabled ? "roam.locationSettings.services.enabled" : "roam.locationSettings.services.disabled")', '')
localizable_ui=localizable_ui.replace('.accessibilityIdentifier(result == .copied ? "profile.orderNumberCopy.copied" : "profile.orderNumberCopy.failed")', '')
localizable_ui=localizable_ui.replace('.accessibilityIdentifier(openedOrderID == Int64(id) ? "profile.order.readback.opened.\\(id)" : "profile.order.readback.closed")', '')
localizable_ui=localizable_ui.replace('OfficialReadScreen(reader: reader, isPrivate: true, requestID: "merchant.officialRecruitment",', 'OfficialReadScreen(reader: reader, isPrivate: true,')
localizable_ui=localizable_ui.replace('MerchantTemplateStoryTimelineContent(timeline: timeline, prefix: "merchant.storyTimeline.review")', 'MerchantTemplateStoryTimelineContent(timeline: timeline)')
# Exact computed accessibility IDs only; identical literals in Text still require translations.
localizable_ui=localizable_ui.replace('var accessibilityID: String { switch self { case .history: return "roam.live.pausedHistory.open"; case .settings: return "roam.live.pausedSettings.open"; case .album: return "roam.live.pausedAlbum.open" } }', '')
localizable_ui=localizable_ui.replace('confirmIdentifier: "club.action.confirm"', '')
localizable_ui=localizable_ui.replace('scrollProxy.scrollTo("merchant.workbench.moreSection", anchor: .top)', '')
localizable_ui=localizable_ui.replace('.id("merchant.workbench.moreSection")', '')
localizable_ui=validate_bound_participant_issue_tables(localizable_ui,ROOT,objects,project_obj)
localizable_ui=validate_literal_text_tables(localizable_ui,ROOT,objects,project_obj)
localizable_ui=validate_literal_resource_tables(localizable_ui,ROOT,objects,project_obj)
keys=set(re.findall(r'"((?:welcome|role|registration|settings|language|action|auth|account|activity|scanner|discovery|profile|merchant|club|roam|messaging|participant|play|message|topic|region|homeFeed|usApple|ticketWallet|square|cooperation|accountCollection|creatorContent|growth|official|officialAction|projectEdit|nearby|team|orderLifecycle|templateAuthor|publishModes|wallet|couponManagement|im)\.[A-Za-z0-9.]+)"',localizable_ui))
keys={key for key in keys if not key.endswith('.')}  # Prefixes concatenate a separately validated dynamic key.
assert not keys-set(catalog['strings']),keys-set(catalog['strings'])
# SwiftUI environment locale does not implicitly change Foundation String(localized:).
# Production computed labels must use LocalizedStringResource/appLocalized for lookup.
for source in (ROOT/'App').glob('*.swift'):
    if 'Fixture' in source.name: continue  # Synthetic server messages are verbatim test data.
    assert not re.search(r'LocalizedStringKey\("[^"\n]*\\\(',source.read_text()), source.name
    missing_locale=re.findall(r'String\(localized:\s*"[^"\n]*"',source.read_text())
    assert not missing_locale,(source.name,missing_locale)
assert 'preferences.language' in ui
assert not any(p.suffix in {'.p8','.p12','.mobileprovision'} for p in ROOT.rglob('*'))
config=(ROOT/'Config/Base.xcconfig').read_text()
assert 'invalid.example.questify.ios' in config
assert 'NSAllowsArbitraryLoads' not in config
scheme=ET.parse(ROOT/'Questify.xcodeproj/xcshareddata/xcschemes/Questify.xcscheme')
for ref in scheme.iter('BuildableReference'): assert ref.attrib['BlueprintIdentifier'] in objects
def semantic_project(document):
    """Preserve every setting/member while ignoring opaque file IDs/list order."""
    objects=document['objects']; aliases={}
    for key,obj in objects.items():
        if obj['isa']=='PBXFileReference':
            aliases[key]='file:'+json.dumps(obj,sort_keys=True,separators=(',',':'))
    for key,obj in objects.items():
        if obj['isa']=='PBXBuildFile':
            stable={k:(aliases.get(v,v) if k=='fileRef' else v) for k,v in obj.items()}
            aliases[key]='build:'+json.dumps(stable,sort_keys=True,separators=(',',':'))
    assert len(set(aliases.values()))==len(aliases),'Duplicate file/build registration'
    def replace(value):
        if isinstance(value,str): return aliases.get(value,value)
        if isinstance(value,list): return [replace(v) for v in value]
        if isinstance(value,dict): return {aliases.get(k,k):replace(v) for k,v in value.items()}
        return value
    result=replace(document)
    for obj in result['objects'].values():
        field='children' if obj['isa']=='PBXGroup' else 'files' if obj['isa'] in {'PBXSourcesBuildPhase','PBXResourcesBuildPhase'} else None
        if field:
            values=obj[field];assert len(values)==len(set(values)),'Duplicate target/group member';obj[field]=sorted(values)
    return result

# Generate the expected project only in an isolated temporary directory. The
# checkout remains read-only; compare all configs, phases, references and schemes.
before=hashlib.sha256(project_path.read_bytes()).hexdigest()
with tempfile.TemporaryDirectory(prefix='questify-current-scaffold-') as directory:
    scratch=pathlib.Path(directory)
    for name in ('App','Core','Tests','Resources','LiveActivityWidget'):(scratch/name).symlink_to(ROOT/name,target_is_directory=True)
    (scratch/'tools').mkdir();shutil.copyfile(ROOT/'tools/generate_project.py',scratch/'tools/generate_project.py')
    subprocess.run(['python3','-B',str(scratch/'tools/generate_project.py')],check=True,capture_output=True)
    expected=parse_project((scratch/'Questify.xcodeproj/project.pbxproj').read_text())
    assert semantic_project(project)==semantic_project(expected),'Current project settings/targets/membership differ from generator'
    for name in ('Questify.xcscheme','QuestifyAppUnitTests.xcscheme'):
        relative='Questify.xcodeproj/xcshareddata/xcschemes/'+name
        assert ET.canonicalize((ROOT/relative).read_text())==ET.canonicalize((scratch/relative).read_text()),('Current scheme differs',name)
assert hashlib.sha256(project_path.read_bytes()).hexdigest()==before
# EN / zh-Hans coverage for every Resources/*.xcstrings catalog. Local tool
# path only; this does not add a hosted macOS workflow.
subprocess.run(['python3','-B',str(pathlib.Path(__file__).resolve().with_name('check_catalog_coverage.py'))],check=True)
subprocess.run(['python3','-B',str(pathlib.Path(__file__).resolve().with_name('check_missing_string_keys.py'))],check=True)
if subprocess.run([sys.executable,'-B',str(ROOT/'tools/check_release_config.py')]).returncode!=0:
    raise SystemExit('Release config check failed')
if subprocess.run([sys.executable,'-B',str(ROOT/'tools/check_privacy_manifest.py')]).returncode!=0:
    raise SystemExit('Privacy manifest check failed')
if subprocess.run([sys.executable,'-B',str(ROOT/'tools/check_design_lint.py')]).returncode!=0:
    raise SystemExit('Design lint failed')
if subprocess.run([sys.executable,'-B',str(ROOT/'tools/check_design_consistency.py')]).returncode!=0:
    raise SystemExit('Design consistency (one design system) failed')
if subprocess.run([sys.executable,'-B',str(ROOT/'tools/check_a11y.py')]).returncode!=0:
    raise SystemExit('Accessibility lint failed')
if subprocess.run([sys.executable,'-B',str(ROOT/'tools/check_log_redaction.py')]).returncode!=0:
    raise SystemExit('Log redaction check failed')
for gate,label in (('check_appsession_ratchet.py','AppSession ratchet'),('check_story_content.py','Story content')):
    if subprocess.run([sys.executable,'-B',str(ROOT/'tools'/gate)]).returncode!=0:
        raise SystemExit(label+' failed')
if subprocess.run([sys.executable,'-B',str(ROOT/'tools/build_page_route_table.py'),'--check']).returncode!=0:
    raise SystemExit('Page route table drift')
print(f'PASS structural checks: {len(source_paths)} Swift source files, {len(catalog["strings"])} bilingual keys, references, scheme, read-only expected project equivalence')
print('SCOPE: this script does not run Swift/Xcode, previews, simulator/device, accessibility or live backend checks; see separate evidence')
