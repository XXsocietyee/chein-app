import json
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
VIEW = ROOT / 'App/ExternalGameImportView.swift'
CJK = re.compile(r'[㐀-鿿]')
RESOURCE = re.compile(r'LocalizedStringResource\(\s*"([A-Za-z0-9_.]+)",\s*defaultValue:\s*"((?:[^"\\]|\\.)*)"')


class ExternalGameImportLocalizationTests(unittest.TestCase):
    def setUp(self):
        self.catalog = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text(encoding='utf8'))['strings']
        self.resources = RESOURCE.findall(VIEW.read_text(encoding='utf8'))

    def test_view_declares_localized_resources(self):
        self.assertGreaterEqual(len(self.resources), 30)

    def test_every_key_has_a_latin_english_and_a_chinese_simplified_value(self):
        problems = []
        for key, _ in self.resources:
            entry = self.catalog.get(key)
            if entry is None:
                problems.append(f'{key}: no catalog entry')
                continue
            locs = entry['localizations']
            en = locs.get('en', {}).get('stringUnit', {}).get('value', '')
            zh = locs.get('zh-Hans', {}).get('stringUnit', {}).get('value', '')
            if not en.strip() or CJK.search(en):
                problems.append(f'{key}: en is empty or contains Chinese')
            if not zh.strip() or not CJK.search(zh):
                problems.append(f'{key}: zh-Hans is empty or has no Chinese')
        self.assertEqual([], problems)

    def test_source_default_values_are_the_english_catalog_values(self):
        problems = []
        for key, default in self.resources:
            en = self.catalog[key]['localizations']['en']['stringUnit']['value']
            if CJK.search(default) or default.replace('\\"', '"').replace('\\\\', '\\') != en:
                problems.append(f'{key}: defaultValue {default!r} != en {en!r}')
        self.assertEqual([], problems)


if __name__ == '__main__':
    unittest.main()
