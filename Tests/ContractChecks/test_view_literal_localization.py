import json, pathlib, re, unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
CJK = re.compile(r'[一-鿿]')
CALLS = re.compile(
    r'\b(?:Text|Button|Label|Section|Toggle|TextField|SecureField|TextEditor|Picker|Menu|NavigationLink|'
    r'ProgressView|Link|DisclosureGroup|LabeledContent|ContentUnavailableView)\(\s*"((?:[^"\\]|\\.)*)"'
    r'|\.(?:navigationTitle|accessibilityLabel|accessibilityHint|alert|confirmationDialog|help)\(\s*"((?:[^"\\]|\\.)*)"')
# Literals that intentionally stay as written: a language's own name.
NATIVE_NAMES = {'简体中文'}


def literal_view_strings():
    """Plain (non-interpolated, non-concatenated) Chinese literals handed to
    SwiftUI LocalizedStringKey overloads in App/ views."""
    found = {}
    for path in sorted((ROOT / 'App').rglob('*.swift')):
        if 'Fixture' in path.name:
            continue  # synthetic fixture data, not product copy
        for number, line in enumerate(path.read_text(encoding='utf8').splitlines(), 1):
            if line.lstrip().startswith('//'):
                continue
            for match in CALLS.finditer(line):
                group = 1 if match.group(1) else 2
                text = match.group(group)
                if not text or not CJK.search(text) or '\\' in text or text in NATIVE_NAMES:
                    continue
                if line[match.end(group) + 1:].lstrip().startswith('+'):
                    continue  # String concatenation never reaches the catalog
                found.setdefault(text, f'{path.relative_to(ROOT)}:{number}')
    return found


class ViewLiteralLocalizationTests(unittest.TestCase):
    def test_every_plain_chinese_view_literal_has_a_distinct_english_translation(self):
        catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text(encoding='utf8'))['strings']
        problems = []
        for text, where in literal_view_strings().items():
            entry = catalog.get(text)
            if entry is None:
                problems.append(('missing catalog key', text, where))
                continue
            loc = entry['localizations']
            en = loc.get('en', {}).get('stringUnit', {}).get('value', '')
            zh = loc.get('zh-Hans', {}).get('stringUnit', {}).get('value', '')
            if not en.strip() or CJK.search(en):
                problems.append(('English value empty or contains Chinese', text, where))
            if not zh.strip():
                problems.append(('zh-Hans value empty', text, where))
            if set(loc) != {'en', 'zh-Hans'}:
                problems.append(('only en and zh-Hans are allowed', text, where))
        self.assertEqual(problems, [])


if __name__ == '__main__':
    unittest.main()
