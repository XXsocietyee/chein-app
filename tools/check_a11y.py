#!/usr/bin/env python3
"""Accessibility lint for the screens added since 04b244ff9.

This is a text scan, not a Swift compiler, VoiceOver pass, or Dynamic Type render.
It checks only the screens in this pass. Other App views are counted and left alone
so a pre-existing gap cannot turn the tree red.

Wired from tools/check_scaffold.py the same way as tools/check_design_lint.py.
"""
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
HELPER = 'App/CurA11y.swift'
MARKERS = (
    'CurA11yTextButton',
    'CurA11yLink',
    'CurA11yField',
    'CurA11yNotice',
    'CurA11yDashText',
    'CurA11yLabeled',
    'CurA11yPair',
    'CurA11yActions',
)
# Public screens in the commit range, plus the helper that holds the shared rules.
SCOPED = (
    'App/BeGapImDesk.swift',
    'App/BeGapMerchantScreens.swift',
    'App/ClubGapSurfaces.swift',
    'App/ExternalGameReviewScreens.swift',
    'App/IMRecipientPreviewRow.swift',
    'App/DesignFixtures/IMRecipientPreviewFixtures.swift',
    'App/PlayGapMiscSurfaces.swift',
    'App/PlayTeamBackpackView.swift',
    'App/PlayTeamBackpackFixtureSupport.swift',
    'App/SessionTeamCreateFixtureSupport.swift',
    HELPER,
)
SLICE_FROM = {
    'App/PlayTeamBackpackView.swift': '@MainActor struct PlayTeamBackpackView',
}
# View types added in the range that are not screens and were not edited.
LEFT = (
    'ExternalGameCatalogLaunch',
    'CYFloatingTabBarClearance',
)
FORBIDDEN = (
    (re.compile(r'\.lineLimit\(\s*1\s*\)'), 'lineLimit(1) clips Dynamic Type'),
    (re.compile(r'\.system\s*\(\s*size\s*:'), 'fixed font size does not scale to XXL'),
    (re.compile(r'CYColor\.textTertiary'), 'textTertiary is below the contrast used for this pass'),
    (re.compile(r'\.foregroundStyle\(\s*\.secondary\s*\)'), 'system secondary is not a CY text token'),
    (re.compile(r'\.opacity\s*\('), 'opacity lowers contrast'),
    (re.compile(r'#[0-9A-Fa-f]{3,8}\b'), 'raw hex color is outside the CY tokens'),
)
DASH = re.compile(r'\u2014|beGap\.unknown|\.dash\b')
VIEW_STRUCT = re.compile(r'\bstruct\s+([A-Za-z0-9_]+)\s*:[^{]*\bView\b')


def slice_of(relative, text):
    marker = SLICE_FROM.get(relative)
    if marker is None:
        return text
    start = text.find(marker)
    if start < 0:
        raise SystemExit('accessibility lint lost the screen slice in ' + relative)
    return text[start:]


def problems(relative, text):
    issues = []
    if relative != HELPER:
        if not any(marker in text for marker in MARKERS):
            if not all(token in text for token in ('.accessibilityLabel', '.accessibilityHint', '.accessibilityAddTraits')):
                issues.append('missing VoiceOver label, hint, and trait')
        if 'HStack' in text and 'dynamicTypeSize >= .xxLarge' not in text:
            issues.append('HStack can clip at XXL; stack with CurA11yPair or CurA11yActions')
        if DASH.search(text) and 'curA11y.unknown' not in text and 'CurA11yDashText' not in text:
            issues.append('an em dash must be spoken as Unknown')
    else:
        for token in (
            'dynamicTypeSize >= .xxLarge',
            'minHeight: CurA11y.hit',
            '.accessibilityLabel',
            '.accessibilityHint',
            '.accessibilityAddTraits',
            'curA11y.unknown',
            '.isButton',
            '.isHeader',
            '.isStaticText',
        ):
            if token not in text:
                issues.append('helper missing ' + token)
    for pattern, message in FORBIDDEN:
        if pattern.search(text):
            issues.append(message)
    return issues


def view_names(root):
    names = []
    app = root / 'App'
    if not app.is_dir():
        return names
    for path in sorted(app.rglob('*.swift')):
        text = path.read_text(encoding='utf-8')
        for match in VIEW_STRUCT.finditer(text):
            names.append(match.group(1))
    return names


def check_rules():
    clean = '''
struct Sample: View {
    var body: some View {
        CurA11yNotice(text: Text("curA11y.unknown", tableName: "CurA11y"), hint: Text("curA11y.beGap.fact.hint", tableName: "CurA11y"))
        CurA11yDashText(shown: "\u2014")
    }
}
'''
    dirty = clean + '\n.foregroundStyle(CYColor.textTertiary).lineLimit(1)\nHStack { Text("a") }\n'
    if problems('App/Sample.swift', clean):
        raise SystemExit('accessibility lint rejected a clean sample')
    if not problems('App/Sample.swift', dirty):
        raise SystemExit('accessibility lint allowed clipping or low contrast')
    helper = '''
dynamicTypeSize >= .xxLarge
minHeight: CurA11y.hit
.accessibilityLabel
.accessibilityHint
.accessibilityAddTraits
curA11y.unknown
.isButton
.isHeader
.isStaticText
'''
    if problems(HELPER, helper):
        raise SystemExit('accessibility lint rejected the helper contract')
    if not problems(HELPER, helper.replace('.isButton', '')):
        raise SystemExit('accessibility lint allowed a helper without a button trait')


def main():
    check_rules()
    issues = []
    for relative in SCOPED:
        path = ROOT / relative
        if not path.is_file():
            issues.append((relative, ['missing file']))
            continue
        found = problems(relative, slice_of(relative, path.read_text(encoding='utf-8')))
        if found:
            issues.append((relative, found))
    names = view_names(ROOT)
    scoped_names = set()
    for relative in SCOPED:
        path = ROOT / relative
        if path.is_file():
            scoped_names.update(VIEW_STRUCT.findall(slice_of(relative, path.read_text(encoding='utf-8'))))
    remainder = [name for name in names if name not in scoped_names and name not in LEFT]
    if issues:
        for relative, found in issues:
            for item in found:
                print(f'{relative}: {item}')
        print(f'FAIL accessibility lint: {len(issues)} scoped file(s)')
        return 1
    print(
        f'PASS accessibility lint: {len(SCOPED) - 1} scoped screens, helper checked, '
        f'{len(LEFT)} range views left, {len(remainder)} other App views not scanned'
    )
    print('LEFT ' + ', '.join(LEFT))
    return 0


if __name__ == '__main__':
    sys.exit(main())
