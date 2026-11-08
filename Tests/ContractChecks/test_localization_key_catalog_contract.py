import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tools'))
import localization_usage_audit as audit  # noqa: E402

FOUND = audit.scan(str(ROOT))


def describe(rows):
    return '\n'.join('  ' + ' '.join(str(part) for part in row) for row in rows[:40])


class LocalizationKeyCatalogContractTests(unittest.TestCase):
    def test_every_catalog_entry_has_nonempty_en_and_zh_hans(self):
        rows = FOUND['incomplete_entries']
        self.assertEqual([], rows, 'catalog entries without en/zh-Hans:\n' + describe(rows))

    def test_no_key_is_looked_up_in_a_table_that_does_not_define_it(self):
        rows = FOUND['key_in_other_catalog'] + FOUND['key_table_missing']
        self.assertEqual([], rows, 'raw keys would render (add tableName: or define the key):\n' + describe(rows))

    def test_no_looked_up_key_is_missing_from_every_catalog(self):
        rows = FOUND['key_missing_everywhere']
        self.assertEqual([], rows, 'keys used in Swift but defined in no catalog:\n' + describe(rows))

    def test_no_english_prose_view_literal_lacks_a_localizable_entry(self):
        rows = FOUND['english_literal_not_in_catalog']
        self.assertEqual([], rows, 'implicit English keys that zh-Hans users would see untranslated:\n' + describe(rows))

    def test_message_key_families_rendered_through_state_strings_are_defined(self):
        # These views/hosts store a key in a String (`message = "h5.invalid"`) and render it later,
        # so the call-site scan cannot see the lookup. Identifier literals are skipped.
        import re
        import json
        strings = json.loads((ROOT / 'Resources/Localizable.xcstrings').read_text(encoding='utf8'))['strings']
        sources = ['App/ChannelAdmissionGovernanceView.swift', 'App/H5DeclaredSessionView.swift',
                   'Core/H5PlatformHost.swift', 'Core/MerchantNPCDraftApprovalGate.swift',
                   'Core/H5SessionCapabilityGate.swift', 'Core/H5DeclaredSessionEntry.swift']
        pattern = re.compile(r'"((?:admission|h5|merchantNPC\.draft)\.[A-Za-z0-9_.]*[A-Za-z0-9_])"')
        missing = []
        for rel in sources:
            for number, line in enumerate((ROOT / rel).read_text(encoding='utf8').splitlines(), 1):
                if 'accessibilityIdentifier' in line:
                    continue
                for key in pattern.findall(line):
                    entry = strings.get(key)
                    if entry is None or set(entry['localizations']) < {'en', 'zh-Hans'}:
                        missing.append((rel, number, key))
        self.assertEqual([], missing, 'state-string keys without en+zh-Hans:\n' + describe(missing))

    def test_state_message_text_is_localized_not_verbatim(self):
        for rel in ('App/ChannelAdmissionGovernanceView.swift', 'App/H5DeclaredSessionView.swift'):
            source = (ROOT / rel).read_text(encoding='utf8')
            self.assertIn('Text(LocalizedStringKey(message))', source, rel)
            self.assertNotIn('Text(verbatim: message)', source, rel)

    def test_merchant_authoring_view_has_no_verbatim_chinese_labels(self):
        import re
        source = (ROOT / 'App/MerchantAuthoringView.swift').read_text(encoding='utf8')
        self.assertIsNone(re.search(r'Text\(verbatim: "[^"]*[\u3400-\u9fff]', source))


if __name__ == '__main__':
    unittest.main()
