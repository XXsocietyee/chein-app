"""Customer CRM preflight source checks. Neither Swift nor server Java is executed."""
import hashlib
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def assert_directory_boundary(case, core, contracts):
    body = core.split('func allowsCustomerDirectory(scope:', 1)[1]
    for token in ['guard active, clubID == scope.clubID, (scope.clubID ?? 0) > 0', 'try scope.validate()',
                  'roleCodes.contains("CLUB_OWNER")', 'roleCodes.contains("CLUB_LEGACY_ADMIN")',
                  'permissions.contains("club:member:manage")']:
        case.assertIn(token, body)
    for token in ['eventAccesses', 'club:member:list:read', 'club:event:checkin', 'CLUB_OPERATOR',
                  'CLUB_CO_OWNER', 'isOwner', 'viewerIsAdmin', 'allows(']:
        case.assertNotIn(token, body)
    selector = 'if permission == "CUSTOMER_DIRECTORY" { return allowsCustomerDirectory(scope: scope) }'
    case.assertIn(selector, contracts)
    case.assertLess(contracts.index(selector), contracts.index('if permissions.contains(permission)'))
    case.assertIn('case .customers, .customer, .customerCount: return "CUSTOMER_DIRECTORY"', contracts)


class ClubCustomerPermissionContracts(unittest.TestCase):
    def read(self, path):
        return (ROOT / path).read_text()





    def test_directory_selector_is_club_scoped_and_precedes_generic_fallback(self):
        assert_directory_boundary(self, self.read('Core/ClubCustomerHistoryTopicRoute.swift'), self.read('Core/ClubGovernanceContracts.swift'))

    def test_mutation_restoring_list_permission_is_detected(self):
        core = self.read('Core/ClubCustomerHistoryTopicRoute.swift')
        contracts = self.read('Core/ClubGovernanceContracts.swift').replace('case .customers, .customer, .customerCount: return "CUSTOMER_DIRECTORY"',
            'case .customers, .customer, .customerCount: return "club:member:list:read"')
        with self.assertRaises(AssertionError): assert_directory_boundary(self, core, contracts)

    def test_mutation_promoting_event_permission_is_detected(self):
        core = self.read('Core/ClubCustomerHistoryTopicRoute.swift')
        core = core.replace('permissions.contains("club:member:manage")', 'permissions.contains("club:member:manage") || !eventAccesses.isEmpty')
        with self.assertRaises(AssertionError): assert_directory_boundary(self, core, self.read('Core/ClubGovernanceContracts.swift'))

    def test_service_workspace_and_history_share_the_same_selector(self):
        service = self.read('Core/ClubGovernanceService.swift')
        self.assertIn('var permitted = access.allows(operation.permission, scope: scope)', service)
        self.assertLess(service.index('guard permitted else'), service.index('var value = try await post(operation'))
        view = self.read('App/ClubGovernanceViews.swift')
        self.assertIn('snapshot.permissions?.allows(read.permission, scope: scope) == true', view)
        self.assertIn('snapshot.permissions?.allows(ClubGovernanceRead.customer.permission, scope: context.scope) == true',
            self.read('Core/ClubCustomerHistoryTopicRoute.swift'))
        self.assertIn('self.viewerRevision() == viewerRevision, authorizationGeneration == authorization', service)

    def test_receipt_enrollment_and_mutation_boundaries_remain_separate(self):
        contracts = self.read('Core/ClubGovernanceContracts.swift')
        self.assertIn('case .checkin, .topicCustomers, .registrations: return "club:member:list:read"', contracts)
        self.assertIn('case .roster: return "club:event:checkin"', contracts)
        self.assertNotIn('CHECKIN_RECEIPT', contracts)
        self.assertNotIn('TOPIC_CUSTOMERS', contracts)
        self.assertIn('public var usesForm: Bool { self == .topicOverview }', contracts)
        from tools.club_customer_directory_admission import restore_product_source
        r4_uses_form = b'    /// Body format. Only the topic overview is a form; `access` (club/access/me) is JSON, as the backend serves it (E2E R4).\n    public var usesForm: Bool { self == .topicOverview }\n'
        contracts_raw = (ROOT / 'Core/ClubGovernanceContracts.swift').read_bytes()
        self.assertEqual(contracts_raw.count(r4_uses_form), 1)
        # Parity r1 CLB-customers-01: customers pages with pageNum/pageSize (MP customers/index.js:139).
        parity_paging = (b'            // CLB-customers-01: MP customers/index.js:139 pages with pageNum / pageSize (50).\n'
                         b'            allowed = ["filter", "keyword", "pageNum", "pageSize"]; fields["filter"] = .string("all"); fields["keyword"] = .string("")\n'
                         b'            fields["pageNum"] = .integer(1); fields["pageSize"] = .integer(ClubOpsCustomerListPresentation.pageSize)\n')
        pre_paging = b'            allowed = ["filter", "keyword"]; fields["filter"] = .string("all"); fields["keyword"] = .string("")\n'
        self.assertEqual(contracts_raw.count(parity_paging), 1)
        # MP pages/club/governance/index.js:270-277: club:member:manage is not enough. The page also requires
        # CLUB_OWNER or CLUB_CO_OWNER and says 仅主理人与联合主理人可进行成员治理. This tightens allows(); it is
        # reversed here so the P044 byte restore still proves every other span is the admitted source.
        governance = (
            '    /// Member governance (临时封禁) is owner or co-owner only, even when `club:member:manage` is present.\n'
            '    public var canGovernMembers: Bool {\n'
            '        permissions.contains("club:member:manage") && (roleCodes.contains("CLUB_OWNER") || roleCodes.contains("CLUB_CO_OWNER"))\n'
            '    }\n'
            '    public static let memberGovernanceDenial = "仅主理人与联合主理人可进行成员治理"\n'
        ).encode()
        manage = (
            '        if permission == "club:member:manage" {\n'
            '            let eventGrant = scope.activityID.map { activityID in\n'
            '                eventAccesses.contains { $0["activityId"].int == activityID && ($0["permissions"].array ?? []).contains(.string(permission)) }\n'
            '            } ?? false\n'
            '            let granted = permissions.contains(permission) || eventGrant\n'
            '            return granted && (roleCodes.contains("CLUB_OWNER") || roleCodes.contains("CLUB_CO_OWNER"))\n'
            '        }\n'
        ).encode()
        self.assertEqual(contracts_raw.count(governance), 1)
        self.assertEqual(contracts_raw.count(manage), 1)
        contracts_raw = contracts_raw.replace(parity_paging, pre_paging, 1).replace(governance, b'', 1).replace(manage, b'', 1)
        self.assertIsInstance(restore_product_source('Core/ClubGovernanceContracts.swift', contracts_raw.replace(r4_uses_form, b'', 1)), bytes)
        self.assertIsInstance(restore_product_source('Core/ClubCustomerHistoryTopicRoute.swift', (ROOT / 'Core/ClubCustomerHistoryTopicRoute.swift').read_bytes()), bytes)

    def test_native_allow_deny_transport_and_cancellation_matrix_is_authored(self):
        tests = self.read('Tests/CoreTests/ClubCustomerPermissionTests.swift')
        for name in ['testExactGovernorMatrixForAllCustomerDirectoryReads', 'testInvalidScopeAndLegacyFlagsCannotAuthorizeDirectory',
                     'testDeniedPreflightOnlyRequestsAccessForEachDirectoryEndpoint',
                     'testAllowedDirectoryReadsKeepExactPayloadAndServerRedaction',
                     'testServerDenialRemainsFinalForEveryAllowedDirectoryEndpoint',
                     'testBothReadStagesRetainCancellationChecks', 'testReceiptEnrollmentAndContactVisibilityRemainIndependent']:
            self.assertIn('func ' + name + '(', tests)
        self.assertIn('private let operations: [ClubGovernanceRead] = [.customers, .customer, .customerCount]', tests)
        self.assertIn('for retireAfter in [1, 2]', tests)
        self.assertIn('XCTAssertEqual(wire.requests.map { $0.url!.path }, ["/api/club/access/me"])', tests)

    def test_existing_production_fixture_changes_only_allow_evidence(self):
        from tools.club_customer_directory_admission import restore_product_source
        path = 'Tests/CoreTests/ClubGovernanceProductionTests.swift'
        raw = (ROOT / path).read_bytes()
        # 097702ffb (CLB-r9-gate-01..04, owner-approved non-money club writes in Release) added one
        # additive Core test. Strip exactly that hash-pinned method; any other fixture byte still fails.
        # r10 club-b CLB-r10-gate-05 (MP pages/club/notify, group-code/index.js:93-135, event-ops, topic-detail,
        # customer-detail) makes saveCustomer and nine more non-money ops MP-first live and adds one Core test.
        start = raw.index(b'    func testLiveCatalogPermitsNamedOperationsWithoutAPreboundTarget()')
        end = raw.index(b'    func testDefaultFactoryDoesNotDispatch()')
        self.assertEqual(hashlib.sha256(raw[start:end]).hexdigest(), '245eb85f491d5cababe0582967444ab8e2a3539d36536f2eae02e6fd6d2a557d')
        raw = raw[:start] + raw[end:]
        # MP pages/club/governance/index.js:466-476 sends durationDays (the server clock owns the expiry;
        # choices are 7/30/90). index.js:270-277 admits member governance only for CLUB_OWNER or CLUB_CO_OWNER,
        # so the ban-flow access fixture is CLUB_OWNER. Both edits reverse to the admitted P044 bytes.
        # The restored baseline hash is unchanged: any other fixture byte still fails the restore.
        self.assertEqual(raw.count(b'"durationDays": .integer(30)'), 2)
        raw = raw.replace(b'"durationDays": .integer(30)', b'"expiresAt": .string("2026-10-10")')
        owner = b'payload = "{\\"active\\":true,\\"club\\":{\\"id\\":81},\\"roleCodes\\":\\(banFlow ? "[\\"CLUB_OWNER\\"]" : "[\\"CLUB_MEMBER\\"]"),\\"permissions\\":\\(allowed ? (chapterFlow ? "[\\"club:content:manage\\"]" : (banFlow ? "[\\"club:member:manage\\"]" : "[\\"club:member:list:read\\",\\"club:member:manage\\"]")) : "[]"),\\"canManageRoles\\":false}"'
        member = b'payload = "{\\"active\\":true,\\"club\\":{\\"id\\":81},\\"roleCodes\\":[\\"CLUB_MEMBER\\"],\\"permissions\\":\\(allowed ? (chapterFlow ? "[\\"club:content:manage\\"]" : (banFlow ? "[\\"club:member:manage\\"]" : "[\\"club:member:list:read\\",\\"club:member:manage\\"]")) : "[]"),\\"canManageRoles\\":false}"'
        self.assertEqual(raw.count(owner), 1)
        raw = raw.replace(owner, member, 1)
        restored = restore_product_source(path, raw)
        self.assertEqual(hashlib.sha256(restored).hexdigest(), '7ec52b15675c3a14de89bd27b32b28b9079d28fc6da784337e2a1f16fc82aa5f')






if __name__ == '__main__':
    unittest.main()
