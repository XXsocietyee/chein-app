import csv
import importlib.util
import pathlib
import tempfile
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('check_page_map_gated', ROOT / 'tools/check_page_map_gated.py')
checker = importlib.util.module_from_spec(spec)
spec.loader.exec_module(checker)


def write(rows):
    handle = tempfile.NamedTemporaryFile('w', suffix='.csv', delete=False, newline='')
    writer = csv.writer(handle)
    writer.writerow(['mini_path', 'feature', 'target_native_screen', 'status', 'owner_track', 'notes'])
    for row in rows:
        writer.writerow(row)
    handle.close()
    return pathlib.Path(handle.name)


class PageMapGatedStatus(unittest.TestCase):
    def test_repository_page_map_is_clean(self):
        self.assertEqual(checker.check(), [])

    def test_exists_row_with_gated_live_action_fails(self):
        path = write([['pages/a', 'f', 'App/A.swift', 'exists', 'w', 'Implemented; live publish gated.']])
        self.assertEqual([m for m, _ in checker.check(path)], ['pages/a'])

    def test_gated_row_passes_and_gated_without_reason_fails(self):
        ok = write([['pages/a', 'f', 'App/A.swift', 'gated', 'w', 'Implemented; live publish gated.']])
        self.assertEqual(checker.check(ok), [])
        bad = write([['pages/a', 'f', 'App/A.swift', 'gated', 'w', 'Implemented.']])
        self.assertEqual(len(checker.check(bad)), 1)

    def test_unknown_status_fails(self):
        self.assertEqual(len(checker.check(write([['pages/a', 'f', 's', 'done', 'w', 'n']]))), 1)


if __name__ == '__main__':
    unittest.main()
