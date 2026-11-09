import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// pages/club/group-code/index: check-in capability stays hidden, and headcount unknown is an em dash.
final class ClubGroupCodePageReadyTests: XCTestCase {
    func testGroupCodePageStaysHiddenWithoutCheckInCapability() {
        let page = ClubGroupCodePage.project(value: ClubGroupCodePageFixtureData.ready, scope: ClubGroupCodePageFixtureData.scope, capability: .absent)
        XCTAssertTrue(page.hidden)
        XCTAssertNil(page.phase)
        XCTAssertNil(page.sessions)
        XCTAssertNil(page.issueCommand(activityID: 101))
        XCTAssertFalse(ClubGroupCodePage.includedInPlayerFirstEntry)
        XCTAssertFalse(ClubGroupCodePage.routeMarkedLive)
        XCTAssertFalse(ClubGroupCodePage.issuanceLive)
        XCTAssertEqual(ClubGroupCodePage.readOperation, .topicOverview)
        XCTAssertEqual(ClubGroupCodePage.readOperation.path, "api/topic/info-to-user")
        XCTAssertEqual(ClubGroupCodePage.issueOperation, .issueGroupCode)
        XCTAssertEqual(ClubGroupCodePage.issueOperation.path, "api/verify/groupcode/issue")
        let scope = ClubGroupCodePageFixtureData.scope
        XCTAssertTrue(ClubGroupCodeCapability(permissions: permissions(codes: ["club:event:checkin"], events: []), scope: scope).granted)
        XCTAssertTrue(ClubGroupCodeCapability(permissions: permissions(codes: [], events: [101]), scope: scope).granted)
        XCTAssertFalse(ClubGroupCodeCapability(permissions: permissions(codes: ["club:activity:manage"], events: []), scope: scope).granted)
        XCTAssertFalse(ClubGroupCodeCapability(permissions: permissions(codes: [], events: []), scope: scope).granted)
        XCTAssertFalse(ClubGroupCodeCapability(permissions: nil, scope: scope).granted)
        XCTAssertFalse(ClubGroupCodeCapability(permissions: permissions(codes: ["club:event:checkin"], events: []), scope: .init(clubID: 82, topicID: 91)).allows(activityID: 101))
    }

    func testGroupCodePageLoadingEmptyReadyAndLiteralZero() throws {
        let loading = ClubGroupCodePage.loading(clientCapabilityPresent: true)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertTrue(loading.hidden)
        XCTAssertNil(loading.sessions)
        let capability = ClubGroupCodeCapability(permissions: permissions(codes: ["club:event:checkin"], events: []), scope: ClubGroupCodePageFixtureData.scope)
        let ready = ClubGroupCodePage.project(value: ClubGroupCodePageFixtureData.ready, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(ready.phase, .some(.ready))
        XCTAssertFalse(ready.hidden)
        XCTAssertEqual(ready.sessions?.map(\.id), [101, 102])
        XCTAssertEqual(ready.sessions?.first?.label, "夜游 · 9月6日 09:05")
        XCTAssertEqual(ready.sessions?.first?.headcount.literal, 0)
        XCTAssertEqual(ready.sessions?.first?.headcount.displayText, "0")
        XCTAssertEqual(ready.sessions?.last?.headcount.displayText, "2")
        let command = try XCTUnwrap(ready.issueCommand(activityID: 101))
        XCTAssertEqual(command.operation.path, "api/verify/groupcode/issue")
        XCTAssertEqual(command.fields, ["activityId": .integer(101)])
        XCTAssertNil(command.fields["requestId"])
        XCTAssertNil(ready.issueCommand(activityID: 103))
        let empty = ClubGroupCodePage.project(value: ClubGroupCodePageFixtureData.emptyList, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(empty.sessions?.count, 0)
        XCTAssertNil(empty.issueCommand(activityID: 101))
        XCTAssertFalse(empty.showsSessions)
        let eventOnly = ClubGroupCodeCapability(permissions: permissions(codes: [], events: [101]), scope: ClubGroupCodePageFixtureData.scope)
        let filtered = ClubGroupCodePage.project(value: ClubGroupCodePageFixtureData.ready, scope: ClubGroupCodePageFixtureData.scope, capability: eventOnly)
        XCTAssertEqual(filtered.phase, .some(.ready))
        XCTAssertEqual(filtered.sessions?.map(\.id), [101])
        XCTAssertNil(filtered.issueCommand(activityID: 102))
        XCTAssertEqual(try XCTUnwrap(filtered.issueCommand(activityID: 101)).fields["activityId"], .integer(101))
    }

    func testGroupCodeUnknownHeadcountIsEmDashNeverZero() {
        let capability = ClubGroupCodeCapability(permissions: permissions(codes: ["club:event:checkin"], events: []), scope: ClubGroupCodePageFixtureData.scope)
        let mixed = ClubGroupCodePage.project(value: ClubGroupCodePageFixtureData.unknownHeadcount, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(mixed.phase, .some(.unknown))
        XCTAssertFalse(mixed.hidden)
        XCTAssertEqual(mixed.sessions?.first?.headcount.literal, 0)
        XCTAssertEqual(mixed.sessions?.first?.headcount.displayText, "0")
        XCTAssertNil(mixed.sessions?.last?.headcount.literal)
        XCTAssertEqual(mixed.sessions?.last?.headcount.displayText, "—")
        XCTAssertNotEqual(mixed.sessions?.last?.headcount.displayText, "0")
        let textual = ClubGroupCodePage.project(value: ClubGroupCodePageFixtureData.stringZeroHeadcount, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(textual.phase, .some(.unknown))
        XCTAssertNil(textual.sessions?.first?.headcount.literal)
        XCTAssertEqual(textual.sessions?.first?.headcount.displayText, "—")
        XCTAssertEqual(ClubGroupCodeCount.parse(.string("0")).displayText, "—")
        XCTAssertNil(ClubGroupCodeCount.parse(.string("0")).literal)
        XCTAssertNil(ClubGroupCodeCount.parse(.string("UNKNOWN")).literal)
        XCTAssertNil(ClubGroupCodeCount.parse(.null).literal)
        XCTAssertNil(ClubGroupCodeCount.parse(.decimal(0)).literal)
        XCTAssertNil(ClubGroupCodeCount.parse(.bool(false)).literal)
        XCTAssertNil(ClubGroupCodeCount.parse(.integer(-1)).literal)
        XCTAssertEqual(ClubGroupCodeCount.parse(.integer(0)).literal, 0)
        XCTAssertEqual(ClubGroupCodeCount.parse(.integer(0)).displayText, "0")
        let overview = ClubGroupCodePage.project(value: ClubGovernanceFixtures.value(.topicOverview), scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(overview.phase, .some(.unknown))
        XCTAssertEqual(overview.sessions?.map(\.id), [101])
        XCTAssertEqual(overview.sessions?.first?.headcount.displayText, "—")
        let broken = ClubGroupCodePage.project(value: ClubGovernanceFixtures.json(#"{"id":91}"#), scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(broken.phase, .some(.error(.malformed)))
        XCTAssertNil(broken.sessions)
    }

    @MainActor func testGroupCodeLoadUsesTopicOverviewAndHidesADeniedGrant() async throws {
        var reads = 0
        let denied = ClubGovernanceFixtureAccess()
        denied.onRead = { reads += 1 }
        let hidden = await ClubGroupCodePage.load(access: denied, scope: ClubGroupCodePageFixtureData.scope, capability: .absent)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertNil(hidden.sessions)
        XCTAssertEqual(reads, 0)
        XCTAssertTrue(denied.sent.isEmpty)
        let access = ClubGovernanceFixtureAccess()
        access.onRead = { reads += 1 }
        let capability = ClubGroupCodeCapability(permissions: try? ClubGovernancePermissions(value: access.permissionValue, scope: ClubGroupCodePageFixtureData.scope), scope: ClubGroupCodePageFixtureData.scope)
        let loaded = await ClubGroupCodePage.load(access: access, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(loaded.phase, .some(.unknown))
        XCTAssertEqual(loaded.sessions?.map(\.id), [101])
        XCTAssertEqual(loaded.sessions?.first?.headcount.displayText, "—")
        XCTAssertEqual(reads, 1)
        XCTAssertTrue(access.sent.isEmpty)
        let issued = try XCTUnwrap(loaded.issueCommand(activityID: 101))
        XCTAssertEqual(issued.operation, .issueGroupCode)
        XCTAssertEqual(issued.fields.count, 1)
        XCTAssertEqual(issued.fields["activityId"], .integer(101))
        XCTAssertNil(issued.fields["requestId"])
        access.overrideValue[.topicOverview] = ClubGroupCodePageFixtureData.emptyList
        let empty = await ClubGroupCodePage.load(access: access, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(empty.sessions?.count, 0)
        access.readFailure = .malformed
        let failed = await ClubGroupCodePage.load(access: access, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(failed.phase, .some(.error(.malformed)))
        XCTAssertNil(failed.sessions)
        access.readFailure = .forbidden
        let refused = await ClubGroupCodePage.load(access: access, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertTrue(refused.hidden)
        XCTAssertNil(refused.sessions)
        XCTAssertTrue(access.sent.isEmpty)
    }

    @MainActor func testGroupCodeIssueCommandUsesExistingContractAndDoesNotSend() async throws {
        let access = ClubGovernanceFixtureAccess()
        access.permissionValue = eventPermissions(activityID: 101)
        access.overrideValue[.topicOverview] = ClubGroupCodePageFixtureData.ready
        let capability = ClubGroupCodeCapability(permissions: try? ClubGovernancePermissions(value: access.permissionValue, scope: ClubGroupCodePageFixtureData.scope), scope: ClubGroupCodePageFixtureData.scope)
        let page = await ClubGroupCodePage.load(access: access, scope: ClubGroupCodePageFixtureData.scope, capability: capability)
        XCTAssertEqual(page.sessions?.map(\.id), [101])
        XCTAssertEqual(page.sessions?.first?.headcount.displayText, "0")
        XCTAssertEqual(try XCTUnwrap(page.issueCommand(activityID: 101)).fields, ["activityId": .integer(101)])
        XCTAssertNil(page.issueCommand(activityID: 102))
        XCTAssertTrue(access.sent.isEmpty)
        access.permissionValue = eventPermissions(activityID: nil)
        let player = ClubGroupCodeCapability(permissions: try? ClubGovernancePermissions(value: access.permissionValue, scope: ClubGroupCodePageFixtureData.scope), scope: ClubGroupCodePageFixtureData.scope)
        XCTAssertFalse(player.granted)
        let concealed = await ClubGroupCodePage.load(access: access, scope: ClubGroupCodePageFixtureData.scope, capability: player)
        XCTAssertTrue(concealed.hidden)
        XCTAssertNil(concealed.sessions)
        XCTAssertTrue(access.sent.isEmpty)
    }

    private func permissions(codes: [String], events: [Int]) -> ClubGovernancePermissions? {
        let rows = events.map { id in
            #"{"activityId":\#(id),"topicId":91,"roleCodes":["EVENT_CHECKIN"],"permissions":["club:event:checkin"]}"#
        }.joined(separator: ",")
        let value = ClubGovernanceFixtures.json(#"{"active":true,"club":{"id":81},"roleCodes":["CLUB_OPERATOR"],"canManageRoles":false,"permissions":[\#(codes.map { "\"\($0)\"" }.joined(separator: ","))],"eventAccesses":[\#(rows)]}"#)
        return try? ClubGovernancePermissions(value: value, scope: ClubGroupCodePageFixtureData.scope)
    }

    private func eventPermissions(activityID: Int?) -> ClubGovernanceValue {
        let events = activityID.map { id in
            #"[{"activityId":\#(id),"topicId":91,"roleCodes":["EVENT_CHECKIN"],"permissions":["club:event:checkin"]}]"#
        } ?? "[]"
        return ClubGovernanceFixtures.json(#"{"active":true,"club":{"id":81},"roleCodes":["CLUB_MEMBER"],"canManageRoles":false,"permissions":[],"eventAccesses":\#(events)}"#)
    }
}
#endif
