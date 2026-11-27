#!/usr/bin/env python3
"""Release identity gate check. Reads files only; never invokes xcodebuild.

Verifies Config/Release.xcconfig carries the owner-approved values, that only the app
target's Release configuration uses it, that the generated project holds the fail-closed
Run Script phase, and that the exact script fails on empty or placeholder inputs while
passing the real ones. Debug must skip the gate.
"""
import json, os, pathlib, re, subprocess, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
EXPECTED = {
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.chengyinhub.chengyinApp',
    'DEVELOPMENT_TEAM': '9VHY8N755R',
    'QUESTIFY_SESSION_REALM': 'cn-prod',
    # Owner decision 2026-11-27 (US launch r1, one-app): one binary serves CN and US; CN is only the
    # default/fallback market. The per-user market is resolved at runtime (Core/UserMarket.swift).
    'QUESTIFY_MARKET': 'CN',
    'QUESTIFY_API_BASE_URL': 'https:/$()/www.chengyinhub.com/prod-api/',
}
GOOD = {
    'CONFIGURATION': 'Release',
    'QUESTIFY_API_BASE_URL': 'https://www.chengyinhub.com/prod-api/',
    'QUESTIFY_SESSION_REALM': 'cn-prod',
    'PRODUCT_BUNDLE_IDENTIFIER': 'com.chengyinhub.chengyinApp',
}


def run_gate(script, **overrides):
    env = {'PATH': os.environ.get('PATH', '/usr/bin:/bin'), **GOOD, **overrides}
    done = subprocess.run(['/bin/sh', '-c', script], env=env, capture_output=True, text=True)
    return done.returncode, done.stderr


def main():
    failures = []
    text = (ROOT / 'Config/Release.xcconfig').read_text()
    assigned = {}
    for line in text.splitlines():
        match = re.match(r'^\s*([A-Z0-9_]+)\s*=\s*(.*?)\s*$', line)
        if match: assigned[match.group(1)] = match.group(2)
    for key, value in EXPECTED.items():
        if assigned.get(key) != value:
            failures.append(f'Config/Release.xcconfig {key} must be {value!r}, found {assigned.get(key)!r}')
    for key in ('MARKETING_VERSION', 'CURRENT_PROJECT_VERSION'):
        if key in assigned: failures.append(f'{key} belongs in Config/Base.xcconfig only')
    code_lines = '\n'.join(l for l in text.splitlines() if not l.lstrip().startswith('//'))
    if re.search(r'(?i)secret|token|password|api[_-]?key', code_lines):
        failures.append('Config/Release.xcconfig must not hold secrets')

    # Base keeps the debug-safe defaults.
    base = (ROOT / 'Config/Base.xcconfig').read_text()
    if 'PRODUCT_BUNDLE_IDENTIFIER = invalid.example.questify.ios' not in base:
        failures.append('Base.xcconfig must keep the placeholder bundle id for Debug')
    if not re.search(r'^QUESTIFY_API_BASE_URL =\s*$', base, re.M):
        failures.append('Base.xcconfig must keep an empty QUESTIFY_API_BASE_URL')

    # Reviewed host in Swift matches the xcconfig URL.
    swift = (ROOT / 'Core/RegionalConfiguration.swift').read_text()
    match = re.search(r'chinaProductionBaseURL = "([^"]+)"', swift)
    if not match or match.group(1) != GOOD['QUESTIFY_API_BASE_URL']:
        failures.append('ReviewedMarketLaunch.chinaProductionBaseURL differs from the Release URL')
    if not re.search(r'approvedBaseURLs[^=]*=\s*\[\s*\.china:\s*\[chinaProductionBaseURL\]\s*\]', swift):
        failures.append('ReviewedMarketLaunch.approvedBaseURLs must list only chinaProductionBaseURL for .china')

    # Project wiring.
    document = json.loads(subprocess.run(
        ['plutil', '-convert', 'json', '-o', '-', str(ROOT / 'Questify.xcodeproj/project.pbxproj')],
        capture_output=True, text=True, check=True).stdout) if sys.platform == 'darwin' else None
    script = None
    if document:
        objects = document['objects']
        release_refs = [k for k, o in objects.items() if o.get('path') == 'Config/Release.xcconfig']
        target = next(o for o in objects.values() if o.get('isa') == 'PBXNativeTarget' and o['name'] == 'Questify')
        for config in objects[target['buildConfigurationList']]['buildConfigurations']:
            cfg = objects[config]
            using = cfg.get('baseConfigurationReference') in release_refs
            if using != (cfg['name'] == 'Release'):
                failures.append(f"app {cfg['name']} configuration has the wrong base xcconfig")
        for o in objects.values():
            if o.get('isa') == 'XCBuildConfiguration' and o.get('baseConfigurationReference') in release_refs \
                    and o['name'] != 'Release':
                failures.append('Release.xcconfig used by a non-Release configuration')
        phases = [objects[p] for p in target['buildPhases']]
        if not phases or phases[0].get('isa') != 'PBXShellScriptBuildPhase':
            failures.append('Release Identity Gate must be the first app build phase')
        else:
            script = phases[0]['shellScript']
    if script:
        code, err = run_gate(script)
        if code != 0: failures.append('gate rejects the real Release values: ' + err.strip())
        for label, override in {
            'empty URL': {'QUESTIFY_API_BASE_URL': ''},
            'http URL': {'QUESTIFY_API_BASE_URL': 'http://127.0.0.1:8099'},
            'empty realm': {'QUESTIFY_SESSION_REALM': '   '},
            'empty bundle': {'PRODUCT_BUNDLE_IDENTIFIER': ''},
            'invalid. bundle': {'PRODUCT_BUNDLE_IDENTIFIER': 'invalid.example.questify.ios'},
            'example bundle': {'PRODUCT_BUNDLE_IDENTIFIER': 'com.example.app'},
            'unresolved bundle': {'PRODUCT_BUNDLE_IDENTIFIER': '$(FOO)'},
        }.items():
            code, err = run_gate(script, **override)
            if code == 0 or 'error: Release build blocked' not in err:
                failures.append(f'gate must fail closed for {label}')
        code, _ = run_gate(script, CONFIGURATION='Debug', QUESTIFY_API_BASE_URL='',
                           QUESTIFY_SESSION_REALM='', PRODUCT_BUNDLE_IDENTIFIER='invalid.example.questify.ios')
        if code != 0: failures.append('gate must skip Debug')
    elif document:
        failures.append('Release Identity Gate script missing')

    if failures:
        print('Release config check failed:\n  ' + '\n  '.join(failures)); return 1
    print('Release config check passed')
    return 0


if __name__ == '__main__':
    sys.exit(main())
