import XCTest
@testable import QuestifyCore

/// pages/club/customers/index page-ready model. Uses the existing customers list contract.
/// Unknown counts stay an em dash. A missing directory capability stays hidden.
final class ClubCustomersIndexPageReadyTests: XCTestCase {
    private let scope = ClubGovernanceScope(clubID: 81)
    private let dash = ClubCustomersIndexModel.Count.unknownDisplay

    private func context(_ operation: ClubGovernanceRead = .customers, clubID: Int = 81, accountID: Int? = 701) -> ClubGovernanceReadContext {
        .init(operation: operation, scope: .init(clubID: clubID), identity: .init(accountID: accountID, epoch: 1),
              viewerRevision: 1, authorizationGeneration: nil)
    }

    private func permissions(roles: [String] = ["CLUB_OWNER"], grants: [String] = [], clubID: Int = 81) throws -> ClubGovernancePermissions {
        try .init(value: .object([
            "active": .bool(true),
            "club": .object(["id": .integer(clubID)]),
            "roleCodes": .array(roles.map(ClubGovernanceValue.string)),
            "permissions": .array(grants.map(ClubGovernanceValue.string)),
            "canManageRoles": .bool(false)
        ]), scope: .init(clubID: clubID))
    }

    private func model(_ value: ClubGovernanceValue, failure: ClubGovernanceFailure? = nil, loading: Bool = false,
                       filtered: Bool = false, roles: [String] = ["CLUB_OWNER"], grants: [String] = [],
                       operation: ClubGovernanceRead = .customers, acceptedClub: Int = 81, expectedClub: Int = 81,
                       accountID: Int? = 701, includeSnapshot: Bool = true) throws -> ClubCustomersIndexModel {
        let expected = context(operation, clubID: expectedClub, accountID: accountID)
        let accepted = context(.customers, clubID: acceptedClub, accountID: accountID)
        let snapshot: ClubGovernanceSnapshot? = includeSnapshot
            ? .init(operation: .customers, scope: .init(clubID: acceptedClub), permissions: try permissions(roles: roles, grants: grants, clubID: acceptedClub), value: value)
            : nil
        return .init(snapshot: snapshot, acceptedContext: includeSnapshot || failure != nil ? accepted : nil,
                     expectedContext: expected, failure: failure, loading: loading, filtered: filtered)
    }

    func testContractStaysTheExistingCustomersListAndOffThePlayerHome() {
        XCTAssertEqual(ClubCustomersIndexModel.contract, .customers)
        XCTAssertEqual(ClubCustomersIndexModel.contract.path, "api/club/crm/customers/list")
        XCTAssertEqual(ClubCustomersIndexModel.contract.permission, "CUSTOMER_DIRECTORY")
        XCTAssertFalse(ClubCustomersIndexModel.playerHomeVisible)
        XCTAssertEqual(dash, "\u{2014}")
    }

    func testFixtureDataMatchesTheExistingCustomersBody() throws {
        let list = ClubCustomersIndexFixtureData.value(ClubCustomersIndexFixtureData.list)
        XCTAssertEqual(list, ClubGovernanceFixtures.value(.customers))
        let ready = try model(list)
        guard case .ready(let presentation) = ready.state else {
            return XCTFail("Expected a ready roster")
        }
        XCTAssertEqual(presentation.rows.first?.displayName, "Fixture customer")
        XCTAssertEqual(ready.totalText, "1")
        XCTAssertEqual(ready.monthNewText, "1")
        XCTAssertEqual(ready.accessibilityIdentifier, ClubCustomersIndexModel.Accessibility.count)
    }

    func testLoadingEmptyErrorAndUnknownStayDistinct() throws {
        let loading = try model(.null, loading: true, includeSnapshot: false)
        XCTAssertEqual(loading.state, .loading)
        XCTAssertEqual(loading.totalText, dash)
        XCTAssertEqual(loading.monthNewText, dash)
        XCTAssertEqual(loading.accessibilityIdentifier, ClubCustomersIndexModel.Accessibility.loading)

        let emptyValue = ClubCustomersIndexFixtureData.value(ClubCustomersIndexFixtureData.empty)
        let empty = try model(emptyValue)
        XCTAssertEqual(empty.state, .empty)
        XCTAssertEqual(empty.totalText, "0")
        XCTAssertEqual(empty.monthNewText, "0")
        XCTAssertEqual(empty.emptyTitleKey, "clubOps.customers.empty")
        let filtered = try model(emptyValue, filtered: true)
        XCTAssertEqual(filtered.state, .empty)
        XCTAssertEqual(filtered.emptyTitleKey, "clubOps.customers.filteredEmpty")

        let failed = try model(.null, failure: .rejected(code: 503, message: nil), includeSnapshot: false)
        guard case .error(let copy) = failed.state else { return XCTFail("A failed read stays an error") }
        XCTAssertEqual(copy.titleKey, "clubOps.customers.failed")
        XCTAssertEqual(copy.retryKey, "clubOps.customers.retry")
        XCTAssertEqual(failed.totalText, dash)
        XCTAssertNotEqual(failed.totalText, "0")
        let outcomeUnknown = try model(.null, failure: .unknown(message: nil), includeSnapshot: false)
        guard case .error = outcomeUnknown.state else { return XCTFail("An unconfirmed request stays an error") }
        XCTAssertEqual(outcomeUnknown.totalText, dash)
        XCTAssertNotEqual(outcomeUnknown.accessibilityIdentifier, ClubCustomersIndexModel.Accessibility.unknown)

        let unknown = try model(ClubCustomersIndexFixtureData.value(ClubCustomersIndexFixtureData.unknownCounts))
        XCTAssertEqual(unknown.state, .unknown)
        XCTAssertEqual(unknown.totalText, dash)
        XCTAssertEqual(unknown.monthNewText, dash)
        XCTAssertEqual(unknown.accessibilityIdentifier, ClubCustomersIndexModel.Accessibility.unknown)
        XCTAssertNotEqual(unknown.state, .empty)
    }

    func testUnknownCountsNeverBecomeZeroOrTheRowCount() throws {
        let row: ClubGovernanceValue = .object([
            "memberId": .integer(704), "verifiedCount": .integer(2), "pendingCount": .integer(1),
            "displayName": .string("Fixture customer")
        ])
        let cases: [ClubGovernanceValue] = [
            .string("UNKNOWN"),
            .object(["total": .string("UNKNOWN"), "monthNew": .string("0"), "items": .array([row])]),
            .object(["total": .decimal(0), "monthNew": .integer(1), "items": .array([row])]),
            .object(["total": .bool(false), "monthNew": .null, "items": .array([row])]),
            .object(["total": .integer(0), "monthNew": .null, "items": .array([])])
        ]
        for value in cases {
            let page = try model(value)
            XCTAssertEqual(page.state, .unknown, "Unconfirmed counts stay unknown")
            XCTAssertNotEqual(page.totalText, "1")
            if case .decimal = value["total"] { XCTAssertEqual(page.totalText, dash) }
            if value["total"] == .string("UNKNOWN") || value == .string("UNKNOWN") || value["total"] == .bool(false) {
                XCTAssertEqual(page.totalText, dash)
            }
            if value["monthNew"] == .null || value["monthNew"] == .string("0") {
                XCTAssertEqual(page.monthNewText, dash)
            }
        }
        let literalZero = try model(.object(["total": .integer(0), "monthNew": .integer(0), "items": .array([])]))
        XCTAssertEqual(literalZero.state, .empty)
        XCTAssertEqual(literalZero.totalText, "0")
    }

    func testMalformedRosterIsAnErrorAndKeepsTheExistingFailClosedParser() throws {
        let bad = ClubGovernanceValue.object(["total": .integer(1), "monthNew": .integer(0), "items": .array([
            .object(["memberId": .integer(0), "verifiedCount": .integer(1), "pendingCount": .integer(0)])
        ])])
        XCTAssertThrowsError(try ClubOpsCustomerListPresentation(value: bad))
        let page = try model(bad)
        guard case .error(let copy) = page.state else { return XCTFail("A malformed roster is an error") }
        XCTAssertEqual(copy.titleKey, "clubOps.customers.failed")
        XCTAssertEqual(page.totalText, dash)
        let negative = try model(.object(["total": .integer(-1), "monthNew": .integer(0), "items": .array([])]))
        XCTAssertEqual(negative.state, page.state)
        XCTAssertEqual(negative.totalText, dash)
        XCTAssertNotEqual(negative.totalText, "0")
    }

    func testMissingDirectoryCapabilityStaysHidden() throws {
        let list = ClubCustomersIndexFixtureData.value(ClubCustomersIndexFixtureData.list)
        let member = try model(list, roles: ["CLUB_OPERATOR"], grants: ["club:member:list:read"])
        XCTAssertEqual(member.state, .hidden)
        XCTAssertEqual(member.totalText, dash)
        XCTAssertEqual(member.accessibilityIdentifier, ClubCustomersIndexModel.Accessibility.hidden)
        let forbidden = try model(list, failure: .forbidden, includeSnapshot: false)
        XCTAssertEqual(forbidden.state, .hidden)
        let signedOut = try model(list, accountID: nil)
        XCTAssertEqual(signedOut.state, .hidden)
        let otherRead = try model(list, operation: .stats)
        XCTAssertEqual(otherRead.state, .hidden)
        if case .ready = member.state { XCTFail("A hidden directory must not expose rows") }
    }

    func testStaleClubSnapshotIsNotShown() throws {
        let list = ClubCustomersIndexFixtureData.value(ClubCustomersIndexFixtureData.list)
        let stale = try model(list, acceptedClub: 81, expectedClub: 82)
        XCTAssertEqual(stale.state, .loading)
        XCTAssertEqual(stale.totalText, dash)
        XCTAssertNotEqual(stale.totalText, "1")
    }

    func testStringsFileCarriesEnglishChineseAndIdentifiers() throws {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/release/ui-strings-pages-club-customers-index.json")
        let data = try Data(contentsOf: url)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(root?["page"] as? String, "pages/club/customers/index")
        XCTAssertEqual(root?["playerHomeVisible"] as? Bool, false)
        XCTAssertEqual(root?["capability"] as? String, "CUSTOMER_DIRECTORY")
        XCTAssertEqual(root?["unknownDisplay"] as? String, dash)
        let rows = try XCTUnwrap(root?["strings"] as? [[String: Any]])
        let keys = Set(rows.compactMap { $0["key"] as? String })
        for key in ["clubOps.customers.empty", "clubOps.customers.failed", "clubOps.customers.unknown", "clubOps.customers.unknownLabel", "club.gov.customers"] {
            XCTAssertTrue(keys.contains(key), key)
        }
        let identifiers = Set(rows.compactMap { $0["accessibilityIdentifier"] as? String })
        let expectedIdentifiers = [
            ClubCustomersIndexModel.Accessibility.loading,
            ClubCustomersIndexModel.Accessibility.empty,
            ClubCustomersIndexModel.Accessibility.errorTitle,
            ClubCustomersIndexModel.Accessibility.retry,
            ClubCustomersIndexModel.Accessibility.count,
            ClubCustomersIndexModel.Accessibility.unknown,
            ClubCustomersIndexModel.Accessibility.row,
            ClubCustomersIndexModel.Accessibility.clearFilters,
            ClubCustomersIndexModel.Accessibility.displayName,
            ClubCustomersIndexModel.Accessibility.malformed,
            ClubCustomersIndexModel.Accessibility.hidden
        ]
        for identifier in expectedIdentifiers {
            XCTAssertTrue(identifiers.contains(identifier), identifier)
        }
        for row in rows {
            let en = try XCTUnwrap(row["en"] as? String)
            let zh = try XCTUnwrap(row["zh-Hans"] as? String)
            XCTAssertFalse(en.isEmpty)
            XCTAssertFalse(zh.isEmpty)
        }
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertFalse(text.contains("paymentEnabled"))
        XCTAssertFalse(text.contains("showsMerchantChoice"))
        XCTAssertFalse(text.localizedCaseInsensitiveContains("http"))
    }
}
