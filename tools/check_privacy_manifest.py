#!/usr/bin/env python3
"""Structural check of Resources/PrivacyInfo.xcprivacy against the source tree.

Checks: valid plist, no tracking, required-reason API categories declared when
the code uses them, reasons are Apple-listed codes, collected types carry the
expected flags, the manifest is a bundled resource of the app target.
Local source scan only; this is not Apple's validator and does not build.
"""
import pathlib, plistlib, re, sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
MANIFEST = ROOT / 'Resources/PrivacyInfo.xcprivacy'
errors = []

def fail(msg):
    errors.append(msg)

if not MANIFEST.exists():
    raise SystemExit('Privacy manifest check failed: Resources/PrivacyInfo.xcprivacy is missing')
try:
    data = plistlib.loads(MANIFEST.read_bytes())
except Exception as exc:
    raise SystemExit(f'Privacy manifest check failed: not a valid plist ({exc})')

# Tracking
if data.get('NSPrivacyTracking') is not False:
    fail('NSPrivacyTracking must be false')
if data.get('NSPrivacyTrackingDomains') != []:
    fail('NSPrivacyTrackingDomains must be an empty array')

# Collected data types
P = 'NSPrivacyCollectedDataType'
PURPOSE_OK = {
    'NSPrivacyCollectedDataTypePurposeAppFunctionality',
    'NSPrivacyCollectedDataTypePurposeAnalytics',
    'NSPrivacyCollectedDataTypePurposeProductPersonalization',
    'NSPrivacyCollectedDataTypePurposeDeveloperAdvertising',
    'NSPrivacyCollectedDataTypePurposeThirdPartyAdvertising',
    'NSPrivacyCollectedDataTypePurposeOther',
}
collected = {}
for item in data.get('NSPrivacyCollectedDataTypes', []):
    kind = item.get(P)
    if not kind or not kind.startswith('NSPrivacyCollectedDataType'):
        fail(f'bad collected type entry: {kind!r}')
        continue
    if kind in collected:
        fail(f'duplicate collected type {kind}')
    collected[kind] = item
    if item.get('NSPrivacyCollectedDataTypeTracking') is not False:
        fail(f'{kind}: Tracking must be false')
    if not isinstance(item.get('NSPrivacyCollectedDataTypeLinked'), bool):
        fail(f'{kind}: Linked must be a boolean')
    purposes = item.get('NSPrivacyCollectedDataTypePurposes') or []
    if not purposes or any(p not in PURPOSE_OK for p in purposes):
        fail(f'{kind}: purposes missing or unknown')
    if any('Advertising' in p for p in purposes):
        fail(f'{kind}: advertising purpose is not allowed (no tracking)')

# Types the app is known to send (docs/release/app-store-pack.md evidence table)
for required in ('PreciseLocation', 'UserID', 'PurchaseHistory', 'PhoneNumber'):
    if 'NSPrivacyCollectedDataType' + required not in collected:
        fail(f'collected type {required} is not declared')

# Required-reason APIs: scan first-party source
CODE = [p for d in ('App', 'Core') for p in (ROOT / d).rglob('*.swift')]
text = {p: p.read_text(errors='ignore') for p in CODE}
def used(pattern):
    rx = re.compile(pattern)
    return any(rx.search(t) for t in text.values())

CATEGORY = {
    'NSPrivacyAccessedAPICategoryUserDefaults': r'\bUserDefaults\b|@AppStorage\b',
    'NSPrivacyAccessedAPICategoryFileTimestamp':
        r'contentModificationDateKey|creationDateKey|contentAccessDateKey|\.contentModificationDate\b|\.creationDate\b|attributesOfItem|\bfstat\(|\bst_[mac]time|getattrlist',
    'NSPrivacyAccessedAPICategorySystemBootTime': r'systemUptime|mach_absolute_time|kern\.boottime|clock_gettime',
    'NSPrivacyAccessedAPICategoryDiskSpace':
        r'volumeAvailableCapacity|volumeTotalCapacity|systemFreeSize|NSFileSystemFreeSize|\bstatfs\b|\bstatvfs\b',
}
REASONS = {
    'NSPrivacyAccessedAPICategoryUserDefaults': {'CA92.1', '1C8F.1', 'C56D.1', 'AC6B.1'},
    'NSPrivacyAccessedAPICategoryFileTimestamp': {'DDA9.1', 'C617.1', '3B52.1', '0A2A.1'},
    'NSPrivacyAccessedAPICategorySystemBootTime': {'35F9.1', '8FFB.1', '3D61.1'},
    'NSPrivacyAccessedAPICategoryDiskSpace': {'85F4.1', 'E174.1', '7D9E.1', 'B728.1'},
}
declared = {}
for item in data.get('NSPrivacyAccessedAPITypes', []):
    cat = item.get('NSPrivacyAccessedAPIType')
    reasons = item.get('NSPrivacyAccessedAPITypeReasons') or []
    declared[cat] = reasons
    if cat not in REASONS:
        fail(f'unknown API category {cat}')
        continue
    if not reasons or any(r not in REASONS[cat] for r in reasons):
        fail(f'{cat}: reasons missing or not valid for this category: {reasons}')
for cat, pattern in CATEGORY.items():
    if used(pattern) and cat not in declared:
        fail(f'{cat} is used in source but not declared')
    if cat in declared and not used(pattern):
        fail(f'{cat} is declared but no use was found in App/ or Core/ (drop it or cite the use)')

# Bundled in the app target (generator + checked-in project)
gen = (ROOT / 'tools/generate_project.py').read_text()
if 'Resources/PrivacyInfo.xcprivacy' not in gen:
    fail('tools/generate_project.py does not bundle Resources/PrivacyInfo.xcprivacy')
pbx = (ROOT / 'Questify.xcodeproj/project.pbxproj').read_text()
m = re.search(r'"(\w+)" = \{\s*"isa" = "PBXFileReference";[^}]*PrivacyInfo\.xcprivacy', pbx)
if not m:
    fail('project.pbxproj has no file reference for PrivacyInfo.xcprivacy')
elif not re.search(r'"isa" = "PBXBuildFile";\s*"fileRef" = "%s"' % m.group(1), pbx):
    fail('PrivacyInfo.xcprivacy has no PBXBuildFile (not in a target)')

if errors:
    print('Privacy manifest check failed:')
    for e in errors:
        print(' -', e)
    sys.exit(1)
print(f'PASS privacy manifest: tracking off, {len(collected)} collected types, {len(declared)} required-reason categories match source')
