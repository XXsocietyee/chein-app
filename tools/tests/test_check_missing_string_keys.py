"""The App/Core string-key gate fails when a used key has no en or zh-Hans."""
import json
import os
import tempfile
import unittest

from tools import check_missing_string_keys as gate


def entry(en, zh):
    def unit(value):
        return {'stringUnit': {'state': 'translated', 'value': value}}
    return {'localizations': {'en': unit(en), 'zh-Hans': unit(zh)}}


class MissingStringKeyTests(unittest.TestCase):
    def write(self, root, relative, text):
        path = os.path.join(root, relative)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as handle:
            handle.write(text)

    def catalog(self, root, name, strings):
        self.write(root, os.path.join('Resources', name + '.xcstrings'),
                   json.dumps({'sourceLanguage': 'en', 'strings': strings}))

    def test_missing_key_and_missing_chinese_fail(self):
        with tempfile.TemporaryDirectory() as root:
            self.write(root, 'App/Usage.swift', 'Text("sample.missing")\nText("sample.present")\n')
            self.write(root, 'Core/Usage.swift', 'Text("sample.englishOnly")\n')
            self.catalog(root, 'Localizable', {
                'sample.present': entry('Present', '已有'),
                'sample.englishOnly': {'localizations': {'en': {'stringUnit': {'state': 'translated', 'value': 'Only'}}}},
            })
            found = gate.scan(root)
            self.assertEqual(found['missing_keys'], [('Localizable', 'sample.missing', 'App/Usage.swift', 1)])
            self.assertEqual(found['incomplete_locales'],
                             [('Localizable', 'sample.englishOnly', 'zh-Hans', 'missing', 'Core/Usage.swift', 1)])
            self.assertEqual(found['wrong_table'], [])

    def test_translated_key_passes(self):
        with tempfile.TemporaryDirectory() as root:
            self.write(root, 'App/Usage.swift', 'Text("sample.present", tableName: "Other")\n')
            self.catalog(root, 'Other', {'sample.present': entry('Present', '已有')})
            self.catalog(root, 'Localizable', {})
            found = gate.scan(root)
            self.assertEqual(found['missing_keys'], [])
            self.assertEqual(found['wrong_table'], [])
            self.assertEqual(found['incomplete_locales'], [])


if __name__ == '__main__':
    unittest.main()
