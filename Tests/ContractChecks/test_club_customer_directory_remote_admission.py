"""Public, source-only checks for the independently ported P044 directory boundary."""
import ast
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import tempfile
import unittest

from tools import club_customer_directory_admission as admission
from tools import run138_editor_readiness as readiness

ROOT = Path(__file__).resolve().parents[2]
INPUTS = set(admission.SOURCE_EDITS) | set(admission.ADDED_SUPPORT) | {
    admission.CONTRACT_PATH, 'tools/run138_editor_readiness.py'}
COMBINED_INPUTS = INPUTS | set(admission.EVOLUTION_SOURCES) | set(admission.EVOLUTION_SUPPORT) | set(admission.FLOOR_INPUTS)


def digest(raw):
    return hashlib.sha256(raw).hexdigest()


@contextmanager
def copied_admission_inputs():
    """Only bounded club and preceding admission inputs, never a repository checkout."""
    with tempfile.TemporaryDirectory(prefix='club-directory-admission-') as temporary:
        root = Path(temporary)
        for relative in sorted(COMBINED_INPUTS):
            target = root / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes((ROOT / relative).read_bytes())
        yield root


class ClubCustomerDirectoryRemoteAdmissionTests(unittest.TestCase):

    def test_pbx_package_and_spm_discovery_are_exactly_unchanged(self):
        # Whole-file pbxproj/Package.swift hashes were dropped: both files are
        # shared and moved on with every later lane. The registration facts stay.
        project = (ROOT / 'Questify.xcodeproj/project.pbxproj').read_text()
        for relative in ['Core/ClubGovernanceContracts.swift', 'Core/ClubCustomerHistoryTopicRoute.swift']:
            self.assertEqual(project.count('"path" = "' + relative + '";'), 1)
        self.assertIn('path: "Tests/CoreTests"', (ROOT / 'Package.swift').read_text())
        swift = (ROOT / 'Tests/CoreTests/ClubCustomerPermissionTests.swift').read_text()
        self.assertEqual(swift.count('    func test'), 7)
        self.assertNotIn('ClubCustomerListQuery', swift)
        self.assertIn('case .customerCount: expected = ["clubId": .integer(81)]', swift)
        self.assertIn('case .customer: expected = ["clubId": .integer(81), "memberId": .integer(704)]', swift)

    def test_no_change_to_write_selector_or_non_directory_reads(self):
        # The whole-file hashes of the club commands/service/views/form were
        # dropped (those files moved on in r9-r11 club lanes); the permission
        # selector this check protects is asserted directly instead.
        contracts = (ROOT / 'Core/ClubGovernanceContracts.swift').read_text()
        permission = contracts.split('    public var permission: String? {', 1)[1].split('\n    }\n', 1)[0]
        self.assertIn('case .checkin, .topicCustomers, .registrations: return "club:member:list:read"', permission)
        self.assertIn('case .customers, .customer, .customerCount: return "CUSTOMER_DIRECTORY" // Local preflight, never an API grant.', permission)
        self.assertIn('case .settlement: return "club:finance:read"', permission)
        self.assertIn('case .bans: return "club:member:manage"', permission)
        self.assertIn('case .stats, .editions, .dissolutionBlockers: return "OWNER"', permission)
        self.assertEqual(permission.count('CUSTOMER_DIRECTORY'), 1)
        self.assertNotIn('CHECKIN_RECEIPT', contracts)
        self.assertNotIn('TOPIC_CUSTOMERS', contracts)
        commands = (ROOT / 'Core/ClubGovernanceCommands.swift').read_text()
        # The only write that uses the directory preflight is saveCustomer.
        self.assertEqual(commands.count('"CUSTOMER_DIRECTORY"'), 1)
        self.assertIn('case .saveCustomer: return "CUSTOMER_DIRECTORY"', commands)

    def test_missing_support_and_equivalent_json_are_rejected(self):
        with copied_admission_inputs() as root:
            for relative in admission.ADDED_SUPPORT + admission.EVOLUTION_SUPPORT:
                file = root / relative
                saved = file.read_bytes()
                file.unlink()
                with self.subTest(path=relative), self.assertRaises((ValueError, FileNotFoundError)):
                    admission.historical_scan_contract(root)
                file.write_bytes(saved)
            file = root / admission.CONTRACT_PATH
            original = file.read_bytes()
            file.write_text(json.dumps(json.loads(original), sort_keys=True))
            with self.assertRaises(ValueError):
                admission.historical_scan_contract(root)

    def test_contract_and_reader_forgery_cannot_repin_an_unreviewed_input(self):
        with copied_admission_inputs() as root:
            relative = 'docs/club-customer-permissions.md'
            file = root / relative
            file.write_bytes(file.read_bytes() + b'Unreviewed text\n')
            contract_file = root / admission.CONTRACT_PATH
            prior = contract_file.read_bytes()
            value = json.loads(prior)
            value['feature_batch_support_sha256'][relative] = digest(file.read_bytes())
            updated = (json.dumps(value, ensure_ascii=False, indent=2) + '\n').encode()
            contract_file.write_bytes(updated)
            reader_file = root / 'tools/run138_editor_readiness.py'
            reader_file.write_bytes(reader_file.read_bytes().replace(digest(prior).encode(), digest(updated).encode()))
            with self.assertRaisesRegex(ValueError, 'reader changed'):
                admission.historical_scan_contract(root)


if __name__ == '__main__':
    unittest.main()
