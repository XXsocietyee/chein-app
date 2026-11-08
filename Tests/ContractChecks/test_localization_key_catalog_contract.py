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


if __name__ == '__main__':
    unittest.main()
