#!/usr/bin/env python3
"""CB61 design lint. This is a text scan, not a Swift compiler or runtime test.

Fails when an App/*.swift file outside App/DesignSystem and App/Theme contains
a raw hex color, a fixed font size, or a violet color, unless that file is
allowlisted with the exact per-kind counts already present on this tree.
A new hit, including one added to an allowlisted file, fails. DesignSystem
and Theme keep the literal tokens the views are supposed to call.
"""
import re
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
EXCLUDED_PREFIXES = ('App/DesignSystem/', 'App/Theme/')
RAW_HEX = 'raw hex color'
FIXED_FONT = 'fixed font size'
VIOLET = 'violet color'
KINDS = (RAW_HEX, FIXED_FONT, VIOLET)

# Files that already violate the rule on this tree, with the hit count of
# each kind. Keyed by file so a clean file stays clean and a new hit fails.
ALLOWLIST = {
    'App/AccountComplianceViews.swift': {FIXED_FONT: 1},
    'App/AuthChannelView.swift': {FIXED_FONT: 1},
    'App/TicketWalletView.swift': {FIXED_FONT: 2, VIOLET: 1},
    'App/ChatMessageBubble.swift': {VIOLET: 1},
    'App/CityArrivalEvidenceView.swift': {FIXED_FONT: 1},
    'App/ClubComponents.swift': {RAW_HEX: 1, FIXED_FONT: 1},
    'App/ClubPostDiscussion.swift': {FIXED_FONT: 1},
    'App/CoopSettlementDetailView.swift': {FIXED_FONT: 1},
    'App/CreatorApplicationView.swift': {FIXED_FONT: 1, VIOLET: 1},
    'App/DesignFixtures/E3Fixtures.swift': {VIOLET: 1},
    'App/DiceD20View.swift': {FIXED_FONT: 1},
    'App/E1CommerceComponents.swift': {FIXED_FONT: 2},
    'App/HomeSearchTabParityViews.swift': {FIXED_FONT: 1},
    'App/IMInboxViews.swift': {FIXED_FONT: 1},
    'App/MerchantBusinessEditor.swift': {RAW_HEX: 1},
    'App/ObjectBadgeViews.swift': {FIXED_FONT: 1},
    'App/OrderLifecycleView.swift': {FIXED_FONT: 1},
    'App/PlayJourneyContentViews.swift': {FIXED_FONT: 1},
    'App/PlayKitTimedChallengeView.swift': {FIXED_FONT: 5},
    'App/ProfileComplaintPreparationView.swift': {FIXED_FONT: 1},
    'App/PublishingContextHandoffViews.swift': {RAW_HEX: 1, VIOLET: 1},
    'App/PushNotificationAndLiveActivitySectionView.swift': {VIOLET: 1},
    'App/RoamPassportToolsViews.swift': {FIXED_FONT: 1},
    'App/SearchMapComponents.swift': {VIOLET: 2},  # selected filter pill: violet is the selection colour
    'App/SettingsView.swift': {VIOLET: 4},
    'App/ShopNPCView.swift': {FIXED_FONT: 2},
    'App/SocialGuideViews.swift': {FIXED_FONT: 1},
    'App/WalletCommerceViews.swift': {FIXED_FONT: 2},
    'App/WelcomeView.swift': {FIXED_FONT: 1},
}

HEX_COLOR = re.compile(
    r'(?<![\w])(?:"#[0-9A-Fa-f]{8}"|"#[0-9A-Fa-f]{6}"|"#[0-9A-Fa-f]{3}"'
    r'|#[0-9A-Fa-f]{8}\b|#[0-9A-Fa-f]{6}\b|\b0x[0-9A-Fa-f]{6}\b)'
)
FIXED_FONT_SIZE = re.compile(
    r'\.system\s*\(\s*size\s*:'
    r'|\bsystemFont\s*\(\s*ofSize\s*:'
    r'|\bboldSystemFont\s*\(\s*ofSize\s*:'
    r'|\bitalicSystemFont\s*\(\s*ofSize\s*:'
    r'|\bmonospacedSystemFont\s*\(\s*ofSize\s*:'
    r'|\bmonospacedDigitSystemFont\s*\(\s*ofSize\s*:'
    r'|\bUIFont\s*\(\s*name\s*:'
    r'|\bFont\.custom\s*\('
    r'|\.font\s*\(\s*\.custom\s*\('
)
VIOLET_NAME = re.compile(
    r'(?<![A-Za-z0-9_])(?:system)?(?:violet|purple)(?![A-Za-z0-9_])',
    re.IGNORECASE,
)
COLOR_CALL = re.compile(r'(?<![\w.])(?:Color|UIColor)\s*\(')
NUMBER = r'(?:\d+\.\d+|\d+|\.\d+)'


class Finding:
    def __init__(self, line, kind, text):
        self.line = line
        self.kind = kind
        self.text = text


def line_number(text, index):
    return text.count('\n', 0, index) + 1


def line_text(text, index):
    start = text.rfind('\n', 0, index) + 1
    end = text.find('\n', index)
    if end < 0:
        end = len(text)
    snippet = text[start:end].strip()
    if len(snippet) > 180:
        return snippet[:177] + '...'
    return snippet


def hue_saturation_value(red, green, blue):
    maximum = max(red, green, blue)
    minimum = min(red, green, blue)
    delta = maximum - minimum
    if delta == 0:
        hue = 0.0
    elif maximum == red:
        hue = (60.0 * ((green - blue) / delta) + 360.0) % 360.0
    elif maximum == green:
        hue = 60.0 * ((blue - red) / delta) + 120.0
    else:
        hue = 60.0 * ((red - green) / delta) + 240.0
    saturation = 0.0 if maximum == 0 else delta / maximum
    return hue, saturation, maximum


def is_violet_rgb(red, green, blue):
    """Brand violet and SwiftUI purple sit around hue 245–295, not blue or pink."""
    if min(red, green, blue) < 0:
        return False
    if max(red, green, blue) > 1:
        if max(red, green, blue) > 255:
            return False
        red, green, blue = red / 255.0, green / 255.0, blue / 255.0
    hue, saturation, value = hue_saturation_value(red, green, blue)
    return 245.0 <= hue <= 295.0 and saturation >= 0.20 and value >= 0.20


def hex_digits(token):
    if token.startswith('"'):
        token = token[1:-1]
    if token.startswith('#'):
        token = token[1:]
    elif token.lower().startswith('0x'):
        token = token[2:]
    if len(token) == 3:
        token = ''.join(character * 2 for character in token)
    return token[:6]


def hex_is_violet(token):
    digits = hex_digits(token)
    red = int(digits[0:2], 16)
    green = int(digits[2:4], 16)
    blue = int(digits[4:6], 16)
    return is_violet_rgb(red, green, blue)


def component(arguments, name):
    match = re.search(
        rf'(?<![\w.]){name}\s*:\s*({NUMBER})(?:\s*/\s*({NUMBER}))?',
        arguments,
    )
    if match is None:
        return None
    value = float(match.group(1))
    if match.group(2) is not None:
        denominator = float(match.group(2))
        if denominator == 0:
            return None
        value /= denominator
    return value


def argument_list(text, open_paren):
    depth = 1
    index = open_paren + 1
    while index < len(text) and depth:
        if text[index] == '(':
            depth += 1
        elif text[index] == ')':
            depth -= 1
        index += 1
    if depth:
        return None
    return text[open_paren + 1:index - 1]


def violet_color_calls(text):
    found = []
    for match in COLOR_CALL.finditer(text):
        arguments = argument_list(text, match.end() - 1)
        if arguments is None:
            continue
        red, green, blue = component(arguments, 'red'), component(arguments, 'green'), component(arguments, 'blue')
        if None not in (red, green, blue) and is_violet_rgb(red, green, blue):
            found.append(match.start())
            continue
        hue = component(arguments, 'hue')
        saturation = component(arguments, 'saturation')
        brightness = component(arguments, 'brightness')
        if None in (hue, saturation, brightness):
            continue
        degrees = hue if hue > 1 else hue * 360.0
        if 245.0 <= degrees <= 295.0 and saturation >= 0.20 and brightness >= 0.20 and max(saturation, brightness) <= 1:
            found.append(match.start())
    return found


def findings_in(text):
    found = []
    for match in HEX_COLOR.finditer(text):
        found.append(Finding(line_number(text, match.start()), RAW_HEX, line_text(text, match.start())))
        if hex_is_violet(match.group(0)):
            found.append(Finding(line_number(text, match.start()), VIOLET, line_text(text, match.start())))
    for match in FIXED_FONT_SIZE.finditer(text):
        found.append(Finding(line_number(text, match.start()), FIXED_FONT, line_text(text, match.start())))
    for match in VIOLET_NAME.finditer(text):
        found.append(Finding(line_number(text, match.start()), VIOLET, line_text(text, match.start())))
    for index in violet_color_calls(text):
        found.append(Finding(line_number(text, index), VIOLET, line_text(text, index)))
    return found


def counts_of(items):
    counts = {}
    for item in items:
        counts[item.kind] = counts.get(item.kind, 0) + 1
    return counts


def swift_files(root):
    app = root / 'App'
    if not app.is_dir():
        return []
    files = []
    for path in app.rglob('*.swift'):
        if not path.is_file():
            continue
        relative = path.relative_to(root).as_posix()
        if relative.startswith(EXCLUDED_PREFIXES):
            continue
        files.append((relative, path))
    return sorted(files)


def scan(root):
    """Return path -> findings for files that contain at least one hit."""
    result = {}
    for relative, path in swift_files(root):
        items = findings_in(path.read_text(encoding='utf-8'))
        if items:
            result[relative] = items
    return result


def validate_allowlist():
    seen = set()
    for path, counts in ALLOWLIST.items():
        if path in seen or not path.startswith('App/') or path.startswith(EXCLUDED_PREFIXES) or not path.endswith('.swift'):
            raise SystemExit('invalid design-lint allowlist path: ' + path)
        seen.add(path)
        if type(counts) is not dict or not counts:
            raise SystemExit('design-lint allowlist entry must name at least one kind: ' + path)
        for kind, count in counts.items():
            if kind not in KINDS or type(count) is not int or count < 1:
                raise SystemExit('invalid design-lint allowlist count: ' + path)


def problems(actual, existing):
    """actual maps a path to its findings. Missing allowlisted files are skipped."""
    issues = []
    paths = sorted(set(ALLOWLIST) | set(actual))
    for path in paths:
        if path not in existing and path not in actual:
            continue
        got = counts_of(actual.get(path, []))
        expected = ALLOWLIST.get(path, {})
        if got != expected:
            issues.append((path, expected, got, actual.get(path, [])))
    return issues


def check_rules():
    def kinds(sample):
        return sorted({item.kind for item in findings_in(sample)})

    expected = {
        '#725 command': [],
        'let color = "#2E6D5A"': [RAW_HEX],
        '// local #2F6DF0': [RAW_HEX],
        '#FFFFFF': [RAW_HEX],
        '#EDE9FE': [RAW_HEX],
        '.font(.body)': [],
        '.font(.system(size: 44))': [FIXED_FONT],
        '.listSectionSpacing(.custom(20))': [],
        'percent.font = .preferredFont(forTextStyle: .headline)': [],
        'tint: .purple': [VIOLET],
        '// the old AI token is purple.': [VIOLET],
        'Color(red: 0.36, green: 0.75, blue: 0.42)': [],
        'UIColor(red: 0.40, green: 0.72, blue: 1.0, alpha: 1)': [],
        'UIColor(red: 124.0/255, green: 1, blue: 138.0/255, alpha: 0.20)': [],
        'Color(red: min(1.0, (192.0 + shade * 52.0) / 255.0), green: 0.2, blue: 0.1)': [],
    }
    for sample, want in expected.items():
        got = kinds(sample)
        if got != want:
            raise SystemExit(f'design-lint rule mismatch for {sample!r}: {got} != {want}')
    for sample in ('#7A5CFF', '0x7A5CFF', '#6A4AF0', '#C4B5FD', 'Color(red: 122.0/255, green: 92.0/255, blue: 255.0/255)'):
        got = kinds(sample)
        if VIOLET not in got:
            raise SystemExit('design-lint missed a violet color: ' + sample)
    if RAW_HEX not in kinds('#7A5CFF') or RAW_HEX not in kinds('0x7A5CFF'):
        raise SystemExit('design-lint missed a raw hex color')
    with tempfile.TemporaryDirectory() as directory:
        root = Path(directory)
        (root / 'App' / 'DesignSystem').mkdir(parents=True)
        (root / 'App' / 'Theme').mkdir()
        (root / 'App' / 'DesignSystem' / 'Token.swift').write_text('let c = "#7A5CFF"\n.font(.system(size: 40))\n', encoding='utf-8')
        (root / 'App' / 'Theme' / 'Theme.swift').write_text('let c = Color.purple\n', encoding='utf-8')
        (root / 'App' / 'Clean.swift').write_text('Text("hello").font(.body)\n', encoding='utf-8')
        (root / 'App' / 'Dirty.swift').write_text('let c = "#7A5CFF"\n', encoding='utf-8')
        found = scan(root)
        if set(found) != {'App/Dirty.swift'}:
            raise SystemExit('design-lint scanned DesignSystem, Theme, or a clean file: ' + repr(sorted(found)))
        if counts_of(found['App/Dirty.swift']) != {RAW_HEX: 1, VIOLET: 1}:
            raise SystemExit('design-lint miscounted a hex violet')
    if problems({}, set()):
        raise SystemExit('design-lint rejected a tree with no scanned hits')
    if not problems({'App/New.swift': [Finding(1, FIXED_FONT, '.system(size:')]}, {'App/New.swift'}):
        raise SystemExit('design-lint allowed a new fixed font size')
    welcome = [Finding(1, FIXED_FONT, '.system(size:')]
    if not problems({'App/WelcomeView.swift': welcome * 2}, {'App/WelcomeView.swift'}):
        raise SystemExit('design-lint allowed an extra fixed font size in an allowlisted file')
    if not problems({}, {'App/WelcomeView.swift'}):
        raise SystemExit('design-lint kept a stale allowlist entry')


def main():
    check_rules()
    validate_allowlist()
    files = swift_files(ROOT)
    actual = {}
    for relative, path in files:
        items = findings_in(path.read_text(encoding='utf-8'))
        if items:
            actual[relative] = items
    existing = {path for path in ALLOWLIST if (ROOT / path).is_file()} | set(actual)
    issues = problems(actual, existing)
    if issues:
        for path, expected, got, items in issues:
            if not items:
                print(f'{path}: allowlisted {expected} but no longer contains a raw hex color, fixed font size, or violet color')
                continue
            for item in items:
                print(f'{path}:{item.line}: {item.kind}: {item.text}')
            if path in ALLOWLIST and got != expected:
                print(f'{path}: allowlisted {expected} but found {got}')
        print(f'FAIL design lint: {len(issues)} file(s) differ from the allowlist of {len(ALLOWLIST)}')
        return 1
    hits = sum(sum(counts.values()) for counts in ALLOWLIST.values())
    print(
        f'PASS design lint: scanned {len(files)} App Swift files outside DesignSystem and Theme; '
        f'allowlist {len(ALLOWLIST)} files ({hits} existing violations)'
    )
    return 0


if __name__ == '__main__':
    sys.exit(main())
