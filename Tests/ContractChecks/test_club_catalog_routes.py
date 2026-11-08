"""FP-E6: ClubTabAndAdminParityCatalog lists only backend routes verified in the AN-1 route table.

`backendEndpoints` must be MATCH rows; `nativeOnlyEndpoints` are mini-program names with no backend route and
must NOT be MATCH (so a name cannot silently move to the verified list)."""
import csv
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def statuses():
    table = {}
    with open(ROOT / 'Tests/ContractChecks/fixtures/backend_route_status.csv', newline='') as handle:
        for row in csv.DictReader(handle):
            table.setdefault(row['path'], set()).add(row['status'])
    return table


class ClubCatalogRoutes(unittest.TestCase):
    def setUp(self):
        source = (ROOT / 'Core/ChannelDiscordMessaging.swift').read_text()
        self.catalog = source.split('public enum ClubTabAndAdminParityCatalog', 1)[1].split('// MARK: - Bilingual copy', 1)[0]

    def collect(self, label):
        found = []
        for match in re.finditer(label + r': \[(.*?)\]', self.catalog, re.S):
            found += re.findall(r'"(api/[^"]+)"', match.group(1))
        return found

    def test_backend_endpoints_are_verified_match_rows(self):
        table = statuses(); paths = self.collect('backendEndpoints')
        self.assertGreaterEqual(len(paths), 10)
        for path in paths:
            self.assertEqual(table.get(path), {'MATCH'}, path)

    def test_native_only_endpoints_have_no_backend_match(self):
        table = statuses(); paths = self.collect('nativeOnlyEndpoints')
        self.assertGreaterEqual(len(paths), 10)
        for path in paths:
            self.assertNotIn('MATCH', table.get(path, set()), path)

    def test_old_mini_program_names_are_gone_from_backend_lists(self):
        for old in ('api/club/roles"', 'api/club/badges', 'api/club/customers"', 'api/club/join-requests/review'):
            lists = ''.join(re.findall(r'backendEndpoints: \[(.*?)\]', self.catalog, re.S))
            self.assertNotIn(old, lists)


if __name__ == '__main__':
    unittest.main()
