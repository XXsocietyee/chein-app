#!/usr/bin/env python3
"""CB46 source gate: design fixtures and their registry stay out of Release.

This reads the Questify app target and projects each compiled Swift file as it
would be seen when DEBUG is unset. It does not run xcodebuild and it does not
compile Release. Exit 0 when the fixture symbols are absent from that
projection. Exit 1 when a symbol would be compiled, a design-fixture file is
missing from the Release exclusion list, or a design-fixture file has
Release-visible source.
"""
import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FIXTURE_DIR = Path('App/DesignFixtures')
AUDIT_NAME = 'DesignFixtureReleaseExclusionAudit.swift'
DEMO_EXCLUSION = 'AppStoreReviewDemoAccountAndFixtureSectionView.swift'
TYPE_RE = re.compile(
    r'^(?:@\w+(?:\([^)\n]*\))?\s+)*'
    r'(?:(?:public|open|internal|fileprivate|private|final|nonisolated)\s+)*'
    r'(?:struct|enum|class|actor)\s+([A-Za-z_][A-Za-z0-9_]*)\b',
    re.M,
)
SYMBOL_LIST_RE = re.compile(
    r'static let symbols: \[String\] = \[([\s\S]*?)\]',
)


def parse_project(text):
    """OpenStep subset emitted by tools/generate_project.py."""
    text = re.sub(r'^//.*$', '', text, flags=re.M)
    tokens = re.findall(r'"(?:\\.|[^"\\])*"|\d+|[{}()=;,]', text)
    index = 0

    def take(expected=None):
        nonlocal index
        value = tokens[index]
        index += 1
        if expected is not None and value != expected:
            raise AssertionError((value, expected))
        return value

    def value():
        token = take()
        if token == '{':
            result = {}
            while tokens[index] != '}':
                key = json.loads(take())
                take('=')
                result[key] = value()
                take(';')
            take('}')
            return result
        if token == '(':
            result = []
            while tokens[index] != ')':
                result.append(value())
                take(',')
            take(')')
            return result
        return json.loads(token)

    result = value()
    if index != len(tokens):
        raise AssertionError('trailing project tokens')
    return result


def strip_comments(line, in_block):
    """Drop comments. Keep string literals so a fixture name in one still counts."""
    if in_block:
        end = line.find('*/')
        if end < 0:
            return '', True
        line = line[end + 2:]
        in_block = False
    out = []
    i = 0
    in_string = False
    while i < len(line):
        if in_string:
            out.append(line[i])
            if line[i] == '\\' and i + 1 < len(line):
                out.append(line[i + 1])
                i += 2
                continue
            if line[i] == '"':
                in_string = False
            i += 1
            continue
        if line.startswith('//', i):
            break
        if line.startswith('/*', i):
            end = line.find('*/', i + 2)
            if end < 0:
                return ''.join(out), True
            i = end + 2
            continue
        if line[i] == '"':
            in_string = True
        out.append(line[i])
        i += 1
    return ''.join(out), in_block


def _debug_only(condition):
    # `#if DEBUG` and `#if DEBUG && …` are absent from Release.
    # `#if DEBUG || …` and `#if !DEBUG` are not.
    if '||' in condition:
        return False
    return 'DEBUG' in [part.strip() for part in condition.split('&&')]


def release_active_lines(text):
    """Lines compiled when DEBUG is unset, as (number, comment-stripped code, raw)."""
    stack = []
    in_block = False
    active = []
    errors = []
    for number, raw in enumerate(text.splitlines(), 1):
        code, in_block = strip_comments(raw, in_block)
        stripped = code.strip()
        if stripped.startswith('#if'):
            outer = bool(stack and stack[-1])
            stack.append(_debug_only(stripped[3:].strip()) or outer)
            continue
        if stripped.startswith('#elseif'):
            if not stack:
                errors.append(f'{number}: #elseif without #if')
                continue
            outer = bool(len(stack) > 1 and stack[-2])
            stack[-1] = _debug_only(stripped[len('#elseif'):].strip()) or outer
            continue
        if stripped.startswith('#else'):
            if not stack:
                errors.append(f'{number}: #else without #if')
                continue
            stack[-1] = bool(len(stack) > 1 and stack[-2])
            continue
        if stripped.startswith('#endif'):
            if not stack:
                errors.append(f'{number}: #endif without #if')
                continue
            stack.pop()
            continue
        if stack and stack[-1]:
            continue
        if stripped:
            active.append((number, stripped, raw.rstrip()))
    if stack:
        errors.append('unterminated #if')
    if in_block:
        errors.append('unterminated block comment')
    return active, errors


def symbol_pattern(symbol):
    return re.compile(r'(?<![A-Za-z0-9_])' + re.escape(symbol) + r'(?![A-Za-z0-9_])')


def symbol_hits(text, symbols):
    active, errors = release_active_lines(text)
    patterns = [(symbol, symbol_pattern(symbol)) for symbol in symbols]
    hits = [f'{number}: {symbol} in Release projection: {raw}'
            for number, code, raw in active
            for symbol, pattern in patterns if pattern.search(code)]
    return hits + errors


def release_visible_code(text):
    active, errors = release_active_lines(text)
    return '\n'.join(code for _, code, _ in active), errors


def declared_types(text):
    return TYPE_RE.findall(text)


def audit_symbols(text):
    match = SYMBOL_LIST_RE.search(text)
    if not match:
        return None
    return re.findall(r'"([^"]+)"', match.group(1))


def exclusion_tokens(value):
    return [token for token in value.split() if token != '$(inherited)']


def app_target(project):
    objects = project['objects']
    apps = [obj for obj in objects.values()
            if obj.get('isa') == 'PBXNativeTarget'
            and obj.get('name') == 'Questify'
            and obj.get('productType') == 'com.apple.product-type.application']
    if len(apps) != 1:
        raise AssertionError(f'expected one Questify app target, found {len(apps)}')
    return objects, apps[0]


def configuration(objects, target, name):
    configs = objects[target['buildConfigurationList']]['buildConfigurations']
    found = [objects[item] for item in configs if objects[item].get('name') == name]
    if len(found) != 1:
        raise AssertionError(f'expected one {name} configuration')
    return found[0]


def app_swift_sources(objects, target):
    paths = []
    for phase_id in target['buildPhases']:
        phase = objects[phase_id]
        if phase.get('isa') != 'PBXSourcesBuildPhase':
            continue
        for build_id in phase['files']:
            ref = objects[objects[build_id]['fileRef']]
            if ref.get('lastKnownFileType') == 'sourcecode.swift':
                paths.append(ref['path'])
    return paths


def check(root=ROOT):
    findings = []
    fixture_root = root / FIXTURE_DIR
    fixture_paths = sorted(fixture_root.glob('*.swift'))
    if not fixture_paths:
        return [f'{FIXTURE_DIR}: no design-fixture sources']
    names = [path.name for path in fixture_paths]
    audit_path = fixture_root / AUDIT_NAME
    if not audit_path.is_file():
        findings.append(f'{FIXTURE_DIR / AUDIT_NAME}: missing #if DEBUG audit')
        return findings

    audit_text = audit_path.read_text()
    if not audit_text.startswith('#if DEBUG\n') or not audit_text.rstrip().endswith('#endif'):
        findings.append(f'{FIXTURE_DIR / AUDIT_NAME}: audit must be wrapped in #if DEBUG')
    symbols = audit_symbols(audit_text)
    if not symbols:
        findings.append(f'{FIXTURE_DIR / AUDIT_NAME}: missing symbols inventory')
        symbols = []
    declared = []
    for path in fixture_paths:
        relative = path.relative_to(root)
        text = path.read_text()
        declared.extend(declared_types(text))
        visible, errors = release_visible_code(text)
        for error in errors:
            findings.append(f'{relative}: {error}')
        if visible.strip():
            findings.append(f'{relative}: Release-visible source outside #if DEBUG')
    if symbols and sorted(symbols) != sorted(set(declared)):
        findings.append(
            'audit symbols differ from App/DesignFixtures declarations: '
            f'audit={sorted(symbols)} declared={sorted(set(declared))}'
        )
    if len(symbols) != len(set(symbols)):
        findings.append(f'{FIXTURE_DIR / AUDIT_NAME}: duplicate audit symbols')

    generator = (root / 'tools/generate_project.py').read_text()
    for snippet in (
        "design_fixture_sources = sorted(ROOT.glob('App/DesignFixtures/*.swift'))",
        "design_fixture_names = ' '.join(path.name for path in design_fixture_sources)",
        "if design_fixture_names:",
        "release_excluded_names += ' '+design_fixture_names",
        "settings['EXCLUDED_SOURCE_FILE_NAMES']='$(inherited) '+release_excluded_names",
    ):
        if snippet not in generator:
            findings.append(f'tools/generate_project.py: missing Release exclusion wiring: {snippet}')

    project = parse_project((root / 'Questify.xcodeproj/project.pbxproj').read_text())
    objects, target = app_target(project)
    release = configuration(objects, target, 'Release')
    debug = configuration(objects, target, 'Debug')
    release_excluded = exclusion_tokens(release['buildSettings'].get('EXCLUDED_SOURCE_FILE_NAMES', ''))
    debug_excluded = exclusion_tokens(debug['buildSettings'].get('EXCLUDED_SOURCE_FILE_NAMES', ''))
    if DEMO_EXCLUSION not in release_excluded:
        findings.append(f'Release exclusion dropped {DEMO_EXCLUSION}')
    for name in names:
        if name not in release_excluded:
            findings.append(f'Release compile still includes {FIXTURE_DIR / name}')
        if name in debug_excluded:
            findings.append(f'Debug compile excludes {FIXTURE_DIR / name}')
    compiled = app_swift_sources(objects, target)
    for name in names:
        relative = str(FIXTURE_DIR / name)
        if relative not in compiled:
            findings.append(f'{relative}: not a Questify app compile source')

    excluded = set(release_excluded)
    if symbols:
        for relative in compiled:
            if Path(relative).name in excluded:
                continue
            path = root / relative
            if not path.is_file():
                findings.append(f'{relative}: app compile source is missing')
                continue
            for hit in symbol_hits(path.read_text(), symbols):
                findings.append(f'{relative}: {hit}')
    return findings


def main():
    findings = check()
    if findings:
        print('CB46 design-fixture release exclusion failed. Source check only; Release was not compiled.')
        for finding in findings:
            print(finding)
        return 1
    fixture_count = len(list((ROOT / FIXTURE_DIR).glob('*.swift')))
    print('CB46 design-fixture release exclusion: source check only.')
    print('Release was not compiled. xcodebuild was not run.')
    print(f'App target Release excludes {fixture_count} design-fixture sources.')
    print('Release projection contains none of the audited fixture symbols.')
    return 0


if __name__ == '__main__':
    sys.exit(main())
