#!/usr/bin/env python3
"""Validate the owner story script and keep it out of SwiftUI views.

  python3 -B tools/check_story_content.py

Every Resources/Story/*.json content file must match
docs/release/story-content.schema.json: schemaVersion 1, a non-blank revision,
bilingual en + zh-Hans lines, and guide prompts with unique ids. StoryGuide.json
must also carry every StoryContentKey and one prompt for each surface. Those
keys and the surface/weather enums are read from Core/StoryContent.swift and
must match the schema.

A production leak is a Swift string literal in App/ or Core/ equal to a script
line. Views read the file through StoryContentCatalog / AIStoryContent.

Six narrative literals remain in lane-owned fixture, preview, and safety
screens. They are listed in docs/release/receipts/k29-story-data.md. This gate
checks that those six are still the ones present, and does not rewrite them.
"""
from __future__ import annotations

import json
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SCHEMA_PATH = ROOT / 'docs/release/story-content.schema.json'
STORY_DIR = ROOT / 'Resources/Story'
CATALOG_NAME = 'StoryGuide.json'
SWIFT_ENUMS = ROOT / 'Core/StoryContent.swift'

# Narrative still compiled into a view. Lane-owned; this gate does not edit those screens.
# docs/release/receipts/k29-story-data.md lists the same six.
REMAINING = (
    ('App/ShopNPCFixtureView.swift',
     'Ah, a fellow wanderer! The tea house has stood here since 1920. Look for the third red lantern near the courtyard: the stamp is tucked behind it. 欢迎来到老茶馆，印章就在第三盏红灯笼后面。'),
    ('App/ShopNPCFixtureView.swift',
     'Welcome, traveller! Ask me anything about this place.'),
    ('App/ClubStoryFixtureHost.swift',
     'Follow the lanterns through the courtyard. This synthetic chapter has a longer story to exercise expansion and independent chapter selection. The second chapter has another story and a different play. No walk-time estimate is provided.'),
    ('App/ClubStoryFixtureHost.swift',
     'A separate synthetic chapter story.'),
    ('App/StoryRuleEditorView.swift',
     'A quiet corner of the square.'),
    ('App/NPCAISceneGuardSectionView.swift',
     'Tea is still warm. Keep your voice low near the window.'),
)


def load_json(path: Path):
    raw = path.read_bytes()
    try:
        text = raw.decode('utf-8')
    except UnicodeDecodeError as exc:
        raise SystemExit(f'FAIL {path.relative_to(ROOT)}: not utf-8 ({exc})')
    if text.startswith('\ufeff'):
        raise SystemExit(f'FAIL {path.relative_to(ROOT)}: byte-order mark is not allowed')

    def pairs(items):
        seen = {}
        for key, value in items:
            if key in seen:
                raise ValueError(f'duplicate key {key!r}')
            seen[key] = value
        return seen

    try:
        return json.loads(text, object_pairs_hook=pairs)
    except (json.JSONDecodeError, ValueError) as exc:
        raise SystemExit(f'FAIL {path.relative_to(ROOT)}: {exc}')


def enum_cases(source: str, name: str) -> list[str]:
    match = re.search(rf'public enum {name}\b[^{{]*\{{', source)
    if not match:
        raise SystemExit(f'FAIL Core/StoryContent.swift: missing enum {name}')
    body = []
    depth = 1
    i = match.end()
    while i < len(source) and depth:
        if source[i] == '{':
            depth += 1
        elif source[i] == '}':
            depth -= 1
        if depth:
            body.append(source[i])
        i += 1
    text = ''.join(body)
    found = []
    for line in text.splitlines():
        line = line.split('//', 1)[0].strip()
        if not line.startswith('case '):
            continue
        rest = line[len('case '):].strip().rstrip(',')
        if '=' in rest:
            raw = rest.split('=', 1)[1].strip()
            if len(raw) < 2 or raw[0] != '"' or raw[-1] != '"':
                raise SystemExit(f'FAIL Core/StoryContent.swift: {name} case is not a string literal')
            found.append(raw[1:-1])
        else:
            found.extend(part.strip() for part in rest.split(',') if part.strip())
    if not found:
        raise SystemExit(f'FAIL Core/StoryContent.swift: no cases in {name}')
    return found


def blank(value) -> bool:
    return not isinstance(value, str) or not value.strip()


def check_text(value, where: str, errors: list[str]) -> None:
    if not isinstance(value, dict):
        errors.append(f'{where}: text must be an object with en and zh-Hans')
        return
    extra = set(value) - {'en', 'zh-Hans'}
    if extra:
        errors.append(f'{where}: unknown language {sorted(extra)}')
    for language in ('en', 'zh-Hans'):
        if language not in value:
            errors.append(f'{where}: missing {language}')
        elif blank(value[language]):
            errors.append(f'{where}: blank {language}')


def validate_document(doc, schema, *, catalog: bool, swift_keys: list[str]) -> list[str]:
    errors = []
    if not isinstance(doc, dict):
        return ['document must be an object']
    allowed = set(schema['properties'])
    extra = set(doc) - allowed
    if extra:
        errors.append(f'unknown fields {sorted(extra)}')
    for key in schema['required']:
        if key not in doc:
            errors.append(f'missing {key}')
    version = schema['properties']['schemaVersion']['const']
    if doc.get('schemaVersion') != version or type(doc.get('schemaVersion')) is not int:
        errors.append(f'schemaVersion must be integer {version}')
    if blank(doc.get('revision', '')):
        errors.append('revision must be a non-blank string')
    if 'note' in doc and not isinstance(doc['note'], str):
        errors.append('note must be a string')

    strings_schema = schema['properties']['strings']
    strings = doc.get('strings')
    if not isinstance(strings, dict):
        errors.append('strings must be an object')
        strings = {}
    required_keys = list(strings_schema['required'])
    if required_keys != swift_keys:
        errors.append('schema required string keys differ from StoryContentKey')
    if catalog:
        for key in required_keys:
            if key not in strings:
                errors.append(f'strings missing {key}')
    for key, value in strings.items():
        if not isinstance(key, str) or not key.strip():
            errors.append('strings has a blank key')
            continue
        check_text(value, f'strings[{key}]', errors)

    prompt_schema = schema['$defs']['prompt']
    surfaces = prompt_schema['properties']['surface']['enum']
    weathers = prompt_schema['properties']['weather']['enum']
    nodes = prompt_schema['properties']['node']['enum']
    prompts = doc.get('guidePrompts')
    if not isinstance(prompts, list):
        errors.append('guidePrompts must be an array')
        prompts = []
    seen = set()
    present_surfaces = set()
    for index, prompt in enumerate(prompts):
        where = f'guidePrompts[{index}]'
        if not isinstance(prompt, dict):
            errors.append(f'{where}: must be an object')
            continue
        extra = set(prompt) - set(prompt_schema['properties'])
        if extra:
            errors.append(f'{where}: unknown fields {sorted(extra)}')
        for key in prompt_schema['required']:
            if key not in prompt:
                errors.append(f'{where}: missing {key}')
        prompt_id = prompt.get('id')
        if blank(prompt_id):
            errors.append(f'{where}: blank id')
        elif prompt_id in seen:
            errors.append(f'{where}: duplicate id {prompt_id!r}')
        else:
            seen.add(prompt_id)
        if 'surface' in prompt:
            if prompt['surface'] not in surfaces:
                errors.append(f'{where}: surface {prompt["surface"]!r} is not {surfaces}')
            else:
                present_surfaces.add(prompt['surface'])
        if 'weather' in prompt and prompt['weather'] not in weathers:
            errors.append(f'{where}: weather {prompt["weather"]!r} is not {weathers}')
        if 'node' in prompt and prompt['node'] not in nodes:
            errors.append(f'{where}: node {prompt["node"]!r} is not {nodes}')
        if 'text' in prompt:
            check_text(prompt['text'], f'{where}.text', errors)
    if catalog:
        for surface in surfaces:
            if surface not in present_surfaces:
                errors.append(f'catalog has no {surface} guide prompt')
    return errors


def swift_literals(source: str) -> list[str]:
    """Quoted Swift strings, skipping comments. Interpolations stay inside the literal."""
    out = []
    i = 0
    n = len(source)
    while i < n:
        if source.startswith('//', i):
            end = source.find('\n', i)
            i = n if end < 0 else end + 1
            continue
        if source.startswith('/*', i):
            end = source.find('*/', i + 2)
            i = n if end < 0 else end + 2
            continue
        if source[i] == '#':
            hashes = 0
            j = i
            while j < n and source[j] == '#':
                hashes += 1
                j += 1
            if j < n and source[j] == '"':
                closer = '"' + ('#' * hashes)
                end = source.find(closer, j + 1)
                if end < 0:
                    i += 1
                    continue
                out.append(source[j + 1:end])
                i = end + len(closer)
                continue
        if source.startswith('"""', i):
            end = source.find('"""', i + 3)
            if end < 0:
                i += 1
                continue
            out.append(source[i + 3:end])
            i = end + 3
            continue
        if source[i] == '"':
            k = i + 1
            buf = []
            while k < n:
                if source[k] == '\\' and k + 1 < n:
                    buf.append(source[k + 1])
                    k += 2
                    continue
                if source[k] == '"':
                    out.append(''.join(buf))
                    i = k + 1
                    break
                buf.append(source[k])
                k += 1
            else:
                i += 1
            continue
        i += 1
    return out


def script_lines(doc) -> set[str]:
    lines = set()
    for value in doc.get('strings', {}).values():
        if isinstance(value, dict):
            lines.update(v for v in value.values() if isinstance(v, str) and v.strip())
    for prompt in doc.get('guidePrompts', []):
        if isinstance(prompt, dict) and isinstance(prompt.get('text'), dict):
            lines.update(v for v in prompt['text'].values() if isinstance(v, str) and v.strip())
    return lines


def production_leaks(lines: set[str]) -> list[str]:
    hits = []
    for folder in ('App', 'Core'):
        for path in sorted((ROOT / folder).rglob('*.swift')):
            literals = set(swift_literals(path.read_text(encoding='utf-8')))
            found = sorted(literals & lines)
            for line in found:
                hits.append(f'{path.relative_to(ROOT)}: {line[:80]}')
    return hits


def check_remaining() -> list[str]:
    errors = []
    seen = set()
    for rel, text in REMAINING:
        if (rel, text) in seen:
            errors.append(f'duplicate remaining entry {rel}')
        seen.add((rel, text))
        path = ROOT / rel
        if not path.is_file():
            errors.append(f'remaining story file missing: {rel}')
            continue
        if path.read_text(encoding='utf-8').count(text) != 1:
            errors.append(f'remaining story string changed in {rel}: {text[:60]}')
    return errors


def schema_matches_swift(schema, source: str) -> list[str]:
    errors = []
    keys = enum_cases(source, 'StoryContentKey')
    if keys != schema['properties']['strings']['required']:
        errors.append(
            'StoryContentKey cases '
            f'{keys} differ from schema strings.required {schema["properties"]["strings"]["required"]}'
        )
    prompt = schema['$defs']['prompt']['properties']
    surfaces = enum_cases(source, 'StoryGuideSurface')
    weathers = enum_cases(source, 'StoryGuideWeather')
    if surfaces != prompt['surface']['enum']:
        errors.append(f'StoryGuideSurface {surfaces} differs from schema {prompt["surface"]["enum"]}')
    if weathers != prompt['weather']['enum']:
        errors.append(f'StoryGuideWeather {weathers} differs from schema {prompt["weather"]["enum"]}')
    languages = schema['$defs']['text']['required']
    if languages != ['en', 'zh-Hans']:
        errors.append(f'schema text languages must be en, zh-Hans, found {languages}')
    if schema['properties']['schemaVersion']['const'] != 1:
        errors.append('schemaVersion const must be 1')
    return errors


def self_check(schema, swift_keys) -> None:
    good = {
        'schemaVersion': 1,
        'revision': 'test',
        'strings': {key: {'en': 'en ' + key, 'zh-Hans': '中' + key} for key in swift_keys},
        'guidePrompts': [
            {'id': 'roam.a', 'surface': 'roam', 'weather': 'any', 'text': {'en': 'Walk.', 'zh-Hans': '走。'}},
            {'id': 'play.a', 'surface': 'play', 'weather': 'rain', 'node': 'shop',
             'text': {'en': 'Rain.', 'zh-Hans': '雨。'}},
        ],
    }
    if validate_document(good, schema, catalog=True, swift_keys=swift_keys):
        raise SystemExit('FAIL story validator self-check rejected a valid document')
    broken = json.loads(json.dumps(good))
    broken['guidePrompts'][1]['text']['zh-Hans'] = '  '
    broken['schemaVersion'] = '1'
    if not validate_document(broken, schema, catalog=True, swift_keys=swift_keys):
        raise SystemExit('FAIL story validator self-check missed a blank line and a string schemaVersion')


def main() -> int:
    schema = load_json(SCHEMA_PATH)
    source = SWIFT_ENUMS.read_text(encoding='utf-8')
    problems = schema_matches_swift(schema, source)
    swift_keys = enum_cases(source, 'StoryContentKey')
    self_check(schema, swift_keys)
    files = sorted(p for p in STORY_DIR.glob('*.json') if not p.name.endswith('.schema.json'))
    if not files:
        problems.append(f'{STORY_DIR.relative_to(ROOT)} has no content json')
    lines = set()
    catalog_found = False
    for path in files:
        doc = load_json(path)
        catalog = path.name == CATALOG_NAME
        catalog_found = catalog_found or catalog
        for error in validate_document(doc, schema, catalog=catalog, swift_keys=swift_keys):
            problems.append(f'{path.relative_to(ROOT)}: {error}')
        lines |= script_lines(doc)
    if not catalog_found:
        problems.append(f'Resources/Story/{CATALOG_NAME} is missing')
    for hit in production_leaks(lines):
        problems.append(f'hardcoded story line in {hit}')
    problems.extend(check_remaining())
    if problems:
        for line in problems:
            print('FAIL ' + line)
        return 1
    print(
        f'PASS story content: {len(files)} file(s), {len(swift_keys)} string keys, '
        f'hardcoded story strings remaining {len(REMAINING)}'
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
