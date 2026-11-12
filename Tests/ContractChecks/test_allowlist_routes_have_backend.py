"""FP-E7: allowlisted business routes versus the checked-in backend route status.

`fixtures/backend_route_status.csv` is the AN-1 route table (static analysis of the backend controllers at the
time of the audit; see docs/parity/fix-plan.md). It is data, not a live backend check. Two rules:

1. Default grant: every route the app grants by default in `sessionDependencies` (App/ReviewedPlayerWriteLeases.swift,
   moved out of AppCompositionRoot for the scaffold line ceiling) must be MATCH. A NO-BACKEND or MISMATCH route
   can never be granted by default.
2. Ratchet: a literal path accepted by `BusinessRuntimeFeature.accepts` that the table marks NO-BACKEND must be
   listed in `fixtures/no_backend_allowlisted_routes.txt`. Adding a new such route fails until it is
   acknowledged there (and it still has no default grant under rule 1).
"""
import csv
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXTURES = pathlib.Path(__file__).resolve().parent / 'fixtures'


def load_status():
    table = {}
    with open(FIXTURES / 'backend_route_status.csv', newline='') as handle:
        for row in csv.DictReader(handle):
            table.setdefault(row['path'], set()).add((row['method'], row['status']))
    return table


def default_grants():
    source = (ROOT / 'App/ReviewedPlayerWriteLeases.swift').read_text()
    body = source.split('func sessionDependencies(', 1)[1]
    body = body.split('let businessConfiguration = try? BusinessRuntimeConfiguration(', 1)[0]
    return re.findall(r'BusinessRuntimeRoute\.(post|get)\("(api/[^"]+)"\)', body)


class AllowlistRoutesHaveBackend(unittest.TestCase):
    def test_default_grants_exist_and_are_all_match(self):
        grants = default_grants()
        self.assertGreaterEqual(len(grants), 10, 'parser found the production imRoutes grant')
        table = load_status()
        for method, path in grants:
            statuses = {status for m, status in table.get(path, set()) if m in (method.upper(), '?', 'GET')}
            self.assertEqual(statuses, {'MATCH'}, f'{method.upper()} {path} is granted by default but the backend status is {table.get(path)}')

    def test_only_one_production_construction_site_and_it_uses_the_reviewed_grant(self):
        sites = []
        for folder in ('App', 'Core'):
            for path in (ROOT / folder).rglob('*.swift'):
                text = path.read_text()
                for match in re.finditer(r'BusinessRuntimeConfiguration\(\s*market', text):
                    sites.append((str(path.relative_to(ROOT)), text[match.start():match.start() + 260]))
        self.assertEqual([site for site, _ in sites], ['App/ReviewedPlayerWriteLeases.swift'])
        self.assertIn('routes: imRoutes', sites[0][1])

    def test_default_configuration_has_no_routes(self):
        text = (ROOT / 'Core/BusinessRuntimeConfiguration.swift').read_text()
        self.assertIn('routes: [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] = [:]', text)
        self.assertIn('No "all" mode exists', text)

    def test_no_backend_allowlist_paths_are_acknowledged(self):
        table = load_status()
        text = (ROOT / 'Core/BusinessRuntimeConfiguration.swift').read_text()
        literals = set(re.findall(r'"(api/[A-Za-z0-9_/\-]+)"', text))
        flagged = {p for p in literals if any(status in ('NO-BACKEND', 'MISMATCH') for _, status in table.get(p, set()))}
        baseline = {line.strip() for line in (FIXTURES / 'no_backend_allowlisted_routes.txt').read_text().splitlines()
                    if line.strip() and not line.startswith('#')}
        self.assertEqual(flagged - baseline, set(), 'new NO-BACKEND allowlisted route: acknowledge it in the baseline')
        self.assertEqual(baseline - flagged, set(), 'stale baseline entry: remove it')
        self.assertEqual(flagged & {p for _, p in default_grants()}, set())


if __name__ == '__main__':
    unittest.main()
