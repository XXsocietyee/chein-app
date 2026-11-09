import XCTest
@testable import QuestifyCore

final class ClubOpsGovernancePageTests: XCTestCase {
    private let scope = ClubOpsGovernancePageFixtureData.scope
    private let manage = ClubOpsGovernanceCapability(manageMembers: true, readCases: true, viewerIsOwner: true, activeMember: true)
    private let casesOnly = ClubOpsGovernanceCapability(manageMembers: false, readCases: true, viewerIsOwner: false, activeMember: true)

    func testGovernancePageStaysHiddenWithoutCapabilityAndOffPlayerEntry() throws {
        let hidden = ClubOpsGovernancePage.project(bans: ClubOpsGovernancePageFixtureData.bans, cases: ClubOpsGovernancePageFixtureData.cases, members: ClubOpsGovernancePageFixtureData.members, scope: scope, capability: .absent)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertNil(hidden.counts)
        XCTAssertNil(hidden.bans)
        XCTAssertNil(hidden.cases)
        XCTAssertNil(hidden.members)
        XCTAssertFalse(hidden.canAppeal)
        XCTAssertFalse(hidden.canReport)
        XCTAssertFalse(ClubOpsGovernancePage.includedInPlayerFirstEntry)
        XCTAssertFalse(ClubOpsGovernancePage.routeMarkedLive)
        XCTAssertFalse(ClubOpsGovernancePage.performsWrites)
        XCTAssertEqual(ClubOpsGovernancePage.bansRead.path, "api/club/governance/list")
        XCTAssertEqual(ClubOpsGovernancePage.casesRead.path, "api/club/governance/cases/mine")
        XCTAssertEqual(ClubOpsGovernancePage.membersRead.path, "api/club/members")
        XCTAssertEqual(ClubOpsGovernancePage.reads(for: .absent), [])
        let owner = try permissions(roles: ["CLUB_OWNER"], codes: ["club:member:manage"])
        let granted = ClubOpsGovernanceCapability(permissions: owner, scope: scope)
        XCTAssertTrue(granted.manageMembers)
        XCTAssertTrue(granted.readCases)
        XCTAssertTrue(granted.viewerIsOwner)
        XCTAssertEqual(ClubOpsGovernancePage.reads(for: granted), [.bans, .members, .cases])
        XCTAssertEqual(ClubOpsGovernancePage.reads(for: granted.narrowed(to: .appeal)), [.cases])
        XCTAssertEqual(ClubOpsGovernancePage.reads(for: granted.narrowed(to: .report(type: .club, targetID: 81, label: "Club"))), [.cases])
        let staff = try permissions(roles: ["EVENT_CHECKIN"], codes: ["club:event:checkin"])
        let eventOnly = ClubOpsGovernanceCapability(permissions: staff, scope: scope)
        XCTAssertFalse(eventOnly.manageMembers)
        XCTAssertTrue(eventOnly.readCases)
        XCTAssertEqual(ClubOpsGovernancePage.reads(for: eventOnly), [.cases])
        let inactive = ClubOpsGovernanceCapability(permissions: nil, scope: scope, inactiveOwnCases: true)
        XCTAssertFalse(inactive.manageMembers)
        XCTAssertTrue(inactive.readCases)
        XCTAssertFalse(ClubOpsGovernanceCapability(permissions: nil, scope: scope).granted)
        let loading = ClubOpsGovernancePage.loading(clientCapabilityPresent: true)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertTrue(loading.hidden)
        XCTAssertNil(loading.counts)
    }

    func testGovernancePageLoadingEmptyReadyAndLiteralZero() {
        let ready = ClubOpsGovernancePage.project(bans: ClubOpsGovernancePageFixtureData.bans, cases: ClubOpsGovernancePageFixtureData.cases, members: ClubOpsGovernancePageFixtureData.members, scope: scope, capability: manage)
        XCTAssertEqual(ready.phase, .some(.ready))
        XCTAssertFalse(ready.hidden)
        XCTAssertEqual(ready.counts?.bans?.literal, 1)
        XCTAssertEqual(ready.counts?.bans?.displayText, "1")
        XCTAssertEqual(ready.counts?.cases?.literal, 1)
        XCTAssertEqual(ready.counts?.members?.literal, 1)
        XCTAssertEqual(ready.bans?.rows.count, 1)
        XCTAssertEqual(ready.members?.members.map(\.id), [704])
        XCTAssertTrue(ready.members?.viewerIsOwner == true)
        XCTAssertTrue(ready.canReport)
        XCTAssertFalse(ready.canAppeal)
        XCTAssertNil(ready.counts?.activeBan)
        let empty = ClubOpsGovernancePage.project(bans: ClubOpsGovernancePageFixtureData.emptyBans, cases: ClubOpsGovernancePageFixtureData.emptyCases, members: ClubOpsGovernancePageFixtureData.emptyMembers, scope: scope, capability: manage)
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(empty.counts?.bans?.literal, 0)
        XCTAssertEqual(empty.counts?.bans?.displayText, "0")
        XCTAssertEqual(empty.counts?.cases?.displayText, "0")
        XCTAssertEqual(empty.counts?.members?.displayText, "0")
        XCTAssertEqual(empty.counts?.activeBan?.literal, 0)
        XCTAssertEqual(empty.counts?.activeBan?.displayText, "0")
        XCTAssertEqual(empty.bans?.rows.count, 0)
        XCTAssertFalse(empty.canAppeal)
        let bareCases = ClubOpsGovernancePage.project(cases: .array([]), scope: scope, capability: casesOnly)
        XCTAssertEqual(bareCases.phase, .some(.empty))
        XCTAssertEqual(bareCases.counts?.cases?.displayText, "0")
        XCTAssertNil(bareCases.counts?.activeBan)
        XCTAssertNil(bareCases.counts?.bans)
        XCTAssertNil(bareCases.counts?.members)
        XCTAssertTrue(bareCases.canReport)
        let literal = ClubOpsGovernancePage.project(bans: ClubOpsGovernancePageFixtureData.literalZero, cases: .integer(0), members: .integer(0), scope: scope, capability: manage)
        XCTAssertEqual(literal.phase, .some(.empty))
        XCTAssertEqual(literal.counts?.bans?.literal, 0)
        XCTAssertEqual(literal.counts?.cases?.displayText, "0")
        XCTAssertEqual(literal.counts?.members?.displayText, "0")
        XCTAssertNil(literal.bans)
        XCTAssertNil(literal.cases)
        let missingClub = ClubOpsGovernancePage.project(bans: .array([]), scope: ClubGovernanceScope(), capability: manage)
        XCTAssertEqual(missingClub.phase, .some(.error(.invalidRequest)))
        XCTAssertNil(missingClub.counts)
    }

    func testGovernanceUnknownCountsAreEmDashNeverZero() {
        let unknown = ClubOpsGovernancePage.project(bans: ClubOpsGovernancePageFixtureData.unknownBans, cases: ClubOpsGovernancePageFixtureData.emptyCases, members: ClubOpsGovernancePageFixtureData.emptyMembers, scope: scope, capability: manage)
        XCTAssertEqual(unknown.phase, .some(.unknown))
        XCTAssertFalse(unknown.hidden)
        XCTAssertNil(unknown.bans)
        XCTAssertNil(unknown.counts?.bans?.literal)
        XCTAssertEqual(unknown.counts?.bans?.displayText, "—")
        XCTAssertNotEqual(unknown.counts?.bans?.displayText, "0")
        XCTAssertEqual(unknown.counts?.cases?.displayText, "0")
        XCTAssertEqual(unknown.counts?.members?.displayText, "0")
        XCTAssertEqual(unknown.counts?.activeBan?.displayText, "0")
        let numericString = ClubOpsGovernancePage.project(bans: ClubOpsGovernancePageFixtureData.numericStringZero, members: .null, cases: .object(["data": .string("0"), "activeBan": .null]), scope: scope, capability: manage)
        XCTAssertEqual(numericString.phase, .some(.unknown))
        XCTAssertNil(numericString.counts?.bans?.literal)
        XCTAssertEqual(numericString.counts?.bans?.displayText, "—")
        XCTAssertEqual(numericString.counts?.members?.displayText, "—")
        XCTAssertEqual(numericString.counts?.cases?.displayText, "—")
        XCTAssertEqual(numericString.counts?.activeBan?.displayText, "0")
        let looseBan = ClubOpsGovernancePage.project(cases: .object(["data": .array([]), "activeBan": .string("UNKNOWN")]), scope: scope, capability: casesOnly)
        XCTAssertEqual(looseBan.phase, .some(.unknown))
        XCTAssertEqual(looseBan.counts?.cases?.displayText, "0")
        XCTAssertEqual(looseBan.counts?.activeBan?.displayText, "—")
        XCTAssertNil(looseBan.counts?.activeBan?.literal)
        XCTAssertNil(looseBan.cases)
        XCTAssertFalse(looseBan.canAppeal)
        for value in [ClubGovernanceValue.string("0"), .string("UNKNOWN"), .null, .decimal(0), .bool(false), .integer(-1)] {
            XCTAssertNil(ClubOpsGovernanceCount.parse(value).literal)
            XCTAssertEqual(ClubOpsGovernanceCount.parse(value).displayText, "—")
            XCTAssertNotEqual(ClubOpsGovernanceCount.parse(value).displayText, "0")
        }
        XCTAssertEqual(ClubOpsGovernanceCount.parse(.integer(0)).literal, 0)
        XCTAssertEqual(ClubOpsGovernanceCount.parse(.integer(0)).displayText, "0")
        let missingFact = ClubOpsGovernancePage.project(members: .array([]), cases: .array([]), scope: scope, capability: manage)
        XCTAssertEqual(missingFact.phase, .some(.unknown))
        XCTAssertEqual(missingFact.counts?.bans?.displayText, "—")
        XCTAssertNotEqual(missingFact.counts?.bans?.displayText, "0")
        let broken = ClubOpsGovernancePage.project(bans: .array([.object(["id": .integer(1)])]), members: .array([]), scope: scope, capability: manage)
        XCTAssertEqual(broken.phase, .some(.error(.malformed)))
        XCTAssertNil(broken.counts)
        XCTAssertNil(broken.members)
        let extra = ClubOpsGovernancePage.project(cases: .object(["data": .array([]), "activeBan": .null, "extra": .null]), scope: scope, capability: casesOnly)
        XCTAssertEqual(extra.phase, .some(.error(.malformed)))
        XCTAssertNil(extra.counts)
    }

    @MainActor func testGovernanceLoadUsesExistingReadsAndHidesADeniedGrant() async {
        let denied = GovernancePageReadLog()
        let hidden = await ClubOpsGovernancePage.load(access: denied, scope: scope, capability: .absent)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertEqual(denied.operations, [])
        let appeal = ClubOpsGovernanceCapability(manageMembers: false, readCases: true, viewerIsOwner: false, activeMember: true)
        let casesLog = GovernancePageReadLog()
        let casesPage = await ClubOpsGovernancePage.load(access: casesLog, scope: scope, capability: appeal)
        XCTAssertEqual(casesLog.operations, [.cases])
        XCTAssertEqual(casesPage.phase, .some(.ready))
        XCTAssertNil(casesPage.counts?.bans)
        XCTAssertEqual(casesPage.counts?.cases?.literal, 1)
        XCTAssertTrue(casesPage.canReport)
        let access = GovernancePageReadLog()
        let loaded = await ClubOpsGovernancePage.load(access: access, scope: scope, capability: manage)
        XCTAssertEqual(access.operations, [.bans, .members, .cases])
        XCTAssertEqual(loaded.phase, .some(.ready))
        XCTAssertEqual(loaded.counts?.bans?.literal, 1)
        XCTAssertEqual(loaded.counts?.members?.literal, 1)
        XCTAssertEqual(loaded.counts?.cases?.displayText, "1")
        XCTAssertNil(loaded.counts?.activeBan)
        access.inner.readFailure = .malformed
        let failed = await ClubOpsGovernancePage.load(access: access, scope: scope, capability: manage)
        XCTAssertEqual(failed.phase, .some(.error(.malformed)))
        XCTAssertNil(failed.counts)
        XCTAssertNil(failed.bans)
        access.inner.readFailure = .forbidden
        let refused = await ClubOpsGovernancePage.load(access: access, scope: scope, capability: manage)
        XCTAssertTrue(refused.hidden)
        XCTAssertNil(refused.counts)
        access.inner.readFailure = nil
        access.inner.overrideValue[.bans] = .string("UNKNOWN")
        let rejected = await ClubOpsGovernancePage.load(access: access, scope: scope, capability: manage)
        XCTAssertEqual(rejected.phase, .some(.error(.malformed)))
        XCTAssertNil(rejected.counts?.bans)
        access.inner.overrideValue[.bans] = ClubOpsGovernancePageFixtureData.emptyBans
        access.inner.overrideValue[.members] = ClubOpsGovernancePageFixtureData.emptyMembers
        access.inner.overrideValue[.cases] = ClubOpsGovernancePageFixtureData.emptyCases
        let empty = await ClubOpsGovernancePage.load(access: access, scope: scope, capability: manage)
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(empty.counts?.bans?.displayText, "0")
        XCTAssertEqual(empty.counts?.cases?.displayText, "0")
        XCTAssertEqual(empty.counts?.members?.displayText, "0")
        XCTAssertEqual(empty.counts?.activeBan?.displayText, "0")
        let inactiveLog = GovernancePageReadLog()
        inactiveLog.inner.permissionValue = .object([
            "active": .bool(false), "club": .object(["id": .integer(81)]),
            "permissions": .array([]), "roleCodes": .array([])
        ])
        inactiveLog.inner.overrideValue[.cases] = .object([
            "data": .array([]),
            "activeBan": .object(["id": .integer(9), "clubId": .integer(81), "status": .string("ACTIVE"), "sourceType": .string("CLUB"), "banReason": .string("Synthetic")])
        ])
        let inactive = ClubOpsGovernanceCapability(permissions: nil, scope: scope, inactiveOwnCases: true)
        let appealPage = await ClubOpsGovernancePage.load(access: inactiveLog, scope: scope, capability: inactive)
        XCTAssertEqual(inactiveLog.operations, [.cases])
        XCTAssertEqual(appealPage.phase, .some(.ready))
        XCTAssertTrue(appealPage.canAppeal)
        XCTAssertFalse(appealPage.canReport)
        XCTAssertEqual(appealPage.counts?.activeBan?.literal, 1)
        XCTAssertEqual(appealPage.counts?.cases?.displayText, "0")
        XCTAssertNil(appealPage.counts?.bans)
    }

    private func permissions(roles: [String], codes: [String]) throws -> ClubGovernancePermissions {
        try ClubGovernancePermissions(value: .object([
            "active": .bool(true), "club": .object(["id": .integer(81)]),
            "roleCodes": .array(roles.map(ClubGovernanceValue.string)),
            "permissions": .array(codes.map(ClubGovernanceValue.string)),
            "canManageRoles": .bool(false)
        ]), scope: scope)
    }
}

@MainActor private final class GovernancePageReadLog: ClubGovernanceAccess {
    let inner = ClubGovernanceFixtureAccess()
    private(set) var operations: [ClubGovernanceRead] = []
    var identity: ClubReadIdentity? { inner.identity }
    var isConfigured: Bool { inner.isConfigured }
    var storageNamespace: String { inner.storageNamespace }
    var allowsOfflineWrites: Bool { false }
    func canDispatch(_ command: ClubGovernanceCommand) -> Bool { false }
    func read(_ operation: ClubGovernanceRead, scope: ClubGovernanceScope, options: [String: ClubGovernanceValue]) async throws -> ClubGovernanceSnapshot {
        operations.append(operation)
        return try await inner.read(operation, scope: scope, options: options)
    }
    func send(_ review: ClubGovernanceReview) async throws -> ClubGovernanceValue {
        throw ClubGovernanceFailure.notConfigured
    }
}
