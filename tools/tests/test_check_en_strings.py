"""The English catalog lint fails when en is missing, still Chinese, or too long."""
import json
import os
import tempfile
import textwrap
import unittest

from tools import check_en_strings as gate


def entry(english, chinese):
    def unit(value):
        return {'stringUnit': {'state': 'translated', 'value': value}}
    return {'localizations': {'en': unit(english), 'zh-Hans': unit(chinese)}}


class EnglishStringLintTests(unittest.TestCase):
    def catalog(self, root, name, strings, source='en'):
        path = os.path.join(root, 'Resources', name + '.xcstrings')
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, 'w', encoding='utf-8') as handle:
            json.dump({'sourceLanguage': source, 'strings': strings, 'version': '1.0'}, handle)

    def kinds(self, strings, source='en'):
        with tempfile.TemporaryDirectory() as root:
            self.catalog(root, 'Localizable', strings, source)
            return [row[2] for row in gate.scan(root)]

    def test_layout_length_counts_han_as_two(self):
        self.assertEqual(gate.length('Cancel'), 6)
        self.assertEqual(gate.length('取消'), 4)
        self.assertFalse(gate.too_long('Cancel', '取消'))
        self.assertTrue(gate.too_long('The redemption code is empty.', '空码'))

    def test_missing_english_fails(self):
        self.assertEqual(self.kinds({'sample.only': {'localizations': {
            'zh-Hans': {'stringUnit': {'state': 'translated', 'value': '只有中文'}},
        }}}), ['missing'])

    def test_blank_english_fails(self):
        self.assertEqual(self.kinds({'sample.blank': entry('   ', '空白')}), ['missing'])

    def test_chinese_english_fails(self):
        self.assertEqual(self.kinds({'sample.zh': entry('仍然是中文', '仍然是中文')}), ['chinese'])

    def test_long_english_fails_and_plain_label_passes(self):
        strings = {
            'sample.long': entry('The redemption code is empty.', '空码'),
            'sample.cancel': entry('Cancel', '取消'),
            'sample.ok': entry('OK', '好'),
        }
        self.assertEqual(self.kinds(strings), ['long'])

    def test_untranslated_key_is_skipped(self):
        strings = {
            'brand': {
                'shouldTranslate': False,
                'localizations': {'en': {'stringUnit': {'state': 'translated', 'value': '城瘾'}}},
            },
        }
        self.assertEqual(self.kinds(strings), [])

    def test_plural_form_that_is_too_long_fails(self):
        strings = {
            'sample.count': {
                'localizations': {
                    'en': {'variations': {'plural': {
                        'one': {'stringUnit': {'state': 'translated', 'value': 'You have created one club already'}},
                        'other': {'stringUnit': {'state': 'translated', 'value': 'Clubs'}},
                    }}},
                    'zh-Hans': {'stringUnit': {'state': 'translated', 'value': '俱乐部'}},
                },
            },
        }
        self.assertEqual(self.kinds(strings), ['long'])

    def test_source_language_key_counts_as_english(self):
        self.assertEqual(self.kinds({'Open': {}}, source='en'), [])
        self.assertEqual(self.kinds({'打开': {
            'localizations': {'zh-Hans': {'stringUnit': {'state': 'translated', 'value': '打开'}}},
        }}, source='zh-Hans'), ['missing'])

    def test_repository_catalogs_pass(self):
        found = gate.scan(gate.ROOT)
        self.assertEqual(found, [], textwrap.shorten(repr(found[:5]), width=240))


if __name__ == '__main__':
    unittest.main()
