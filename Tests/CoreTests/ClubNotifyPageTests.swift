import XCTest
@testable import QuestifyCore

@MainActor final class ClubNotifyPageTests: XCTestCase {
    private let emDash = "—"

    func testNotifyPageStaysHiddenWithoutTheBroadcastGrant() throws {
        let ready = ClubNotifyFixtureData.ready
        let hidden = ClubNotifyPage.project(value: ready, capability: .absent)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertNil(hidden.rows)
        XCTAssertFalse(hidden.canBroadcast)
        XCTAssertFalse(hidden.broadcastOffered)
        XCTAssertFalse(hidden.eventAudienceOffered)
        XCTAssertFalse(hidden.canAddress("ALL_MEMBERS"))
        XCTAssertFalse(ClubNotifyPage.includedInPlayerFirstEntry)
        XCTAssertFalse(ClubNotifyDeliveryPage.includedInPlayerFirstEntry)
        XCTAssertFalse(ClubNotifyPage.routeMarkedLive)
        XCTAssertFalse(ClubNotifyDeliveryPage.routeMarkedLive)
        XCTAssertFalse(ClubNotifyPage.sendMarkedLive)
        XCTAssertFalse(ClubNotifyPage.retryMarkedLive)
        XCTAssertEqual(ClubNotifyPage.readOperation, .audienceCounts)
        XCTAssertEqual(ClubNotifyPage.readOperation.path, "api/club/event-notification/audience-counts")
        XCTAssertEqual(ClubNotifyPage.broadcastSend, .sendNotification)
        XCTAssertEqual(ClubNotifyPage.broadcastSend.path, "api/club/event-notification/send")
        XCTAssertEqual(ClubNotifyPage.broadcastRetry.path, "api/club/event-notification/retry")
        XCTAssertEqual(ClubNotifyDeliveryPage.readOperation, .notificationStatus)
        XCTAssertEqual(ClubNotifyDeliveryPage.readOperation.path, "api/club/event-notification/status")
        let club = ClubNotifyFixtureData.clubScope
        let event = ClubNotifyFixtureData.eventScope
        let owner = try XCTUnwrap(ClubGovernancePermissions(value: ClubGovernanceFixtures.permissions, scope: club))
        XCTAssertTrue(ClubNotifyCapability(permissions: owner, scope: club).canBroadcast)
        XCTAssertFalse(ClubNotifyCapability(permissions: owner, scope: club).canSendEventAudience)
        XCTAssertTrue(ClubNotifyCapability(permissions: owner, scope: event).canSendEventAudience)
        let eventOnly = try XCTUnwrap(permissions(codes: [], eventOperate: true, scope: event))
        let eventCapability = ClubNotifyCapability(permissions: eventOnly, scope: event)
        XCTAssertTrue(eventCapability.canRead)
        XCTAssertFalse(eventCapability.canBroadcast)
        XCTAssertTrue(eventCapability.canSendEventAudience)
        XCTAssertFalse(ClubNotifyCapability(permissions: eventOnly, scope: club).canRead)
        let checkin = try XCTUnwrap(permissions(codes: ["club:event:checkin"], scope: event))
        XCTAssertFalse(ClubNotifyCapability(permissions: checkin, scope: event).canRead)
        XCTAssertFalse(ClubNotifyCapability(permissions: nil, scope: club).canRead)
    }

    func testAudienceLoadingEmptyReadyAndLiteralZero() throws {
        let loading = ClubNotifyPage.loading(clientCapabilityPresent: true, canBroadcast: true, canSendEventAudience: true)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertTrue(loading.hidden)
        XCTAssertNil(loading.rows)
        XCTAssertFalse(loading.broadcastOffered)
        XCTAssertFalse(loading.eventAudienceOffered)
        let owner = try capability(scope: ClubNotifyFixtureData.eventScope)
        let ready = ClubNotifyPage.project(value: ClubNotifyFixtureData.ready, capability: owner)
        XCTAssertEqual(ready.phase, .some(.ready))
        XCTAssertFalse(ready.hidden)
        XCTAssertTrue(ready.broadcastOffered)
        XCTAssertTrue(ready.canAddress("ALL_MEMBERS"))
        XCTAssertTrue(ready.canAddress("REGISTERED"))
        XCTAssertFalse(ready.canAddress("NO_SHOW"))
        XCTAssertEqual(ready.rows?.first { $0.id == "NO_SHOW" }?.count.literal, 0)
        XCTAssertEqual(ready.rows?.first { $0.id == "NO_SHOW" }?.count.displayText, "0")
        let empty = ClubNotifyPage.project(value: ClubNotifyFixtureData.empty, capability: owner)
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(empty.rows?.map(\.count.displayText), Array(repeating: "0", count: 6))
        XCTAssertFalse(empty.broadcastOffered)
        XCTAssertFalse(empty.canAddress("ALL_MEMBERS"))
        let clubOnly = try capability(scope: ClubNotifyFixtureData.clubScope)
        let withoutActivity = ClubNotifyPage.project(value: ClubNotifyFixtureData.ready, capability: clubOnly)
        XCTAssertTrue(withoutActivity.broadcastOffered)
        XCTAssertFalse(withoutActivity.canAddress("REGISTERED"))
        XCTAssertTrue(withoutActivity.canAddress("INACTIVE"))
    }

    func testUnknownAudienceCountsAreEmDashNeverZero() throws {
        let owner = try capability(scope: ClubNotifyFixtureData.eventScope)
        let mixed = ClubNotifyPage.project(value: ClubNotifyFixtureData.mixed, capability: owner)
        XCTAssertEqual(mixed.phase, .some(.unknown))
        XCTAssertEqual(mixed.rows?.map(\.id), ClubOpsNotifyPresentation.audienceIDs)
        XCTAssertEqual(mixed.rows?.map(\.count.literal) ?? [], [8, 1, 8, nil, 0, nil] as [Int?])
        XCTAssertEqual(mixed.rows?.first { $0.id == "NO_SHOW" }?.count.displayText, "0")
        XCTAssertEqual(mixed.rows?.first { $0.id == "WAITLIST" }?.count.displayText, emDash)
        XCTAssertEqual(mixed.rows?.first { $0.id == "INACTIVE" }?.count.displayText, emDash)
        XCTAssertFalse(mixed.canAddress("WAITLIST"))
        XCTAssertFalse(mixed.canAddress("NO_SHOW"))
        XCTAssertTrue(mixed.canAddress("ALL_MEMBERS"))
        XCTAssertTrue(mixed.canAddress("REGISTERED"))
        let partial = ClubNotifyPage.project(value: .object(["counts": .object(["ALL_MEMBERS": .integer(8)])]), capability: owner)
        XCTAssertEqual(partial.phase, .some(.unknown))
        XCTAssertEqual(partial.rows?.first { $0.id == "ALL_MEMBERS" }?.count.displayText, "8")
        XCTAssertEqual(partial.rows?.first { $0.id == "ADMINS" }?.count.displayText, emDash)
        XCTAssertNotEqual(partial.rows?.first { $0.id == "ADMINS" }?.count.displayText, "0")
        let blank = ClubNotifyPage.project(value: .object(["counts": .object([:])]), capability: owner)
        XCTAssertEqual(blank.phase, .some(.unknown))
        XCTAssertEqual(blank.rows?.map(\.count.displayText), Array(repeating: emDash, count: 6))
        let broken = ClubNotifyPage.project(value: .object([:]), capability: owner)
        XCTAssertEqual(broken.phase, .some(.error(.malformed)))
        XCTAssertNil(broken.rows)
        XCTAssertEqual(ClubNotifyCount.parse(.string("0")).displayText, emDash)
        XCTAssertNil(ClubNotifyCount.parse(.string("0")).literal)
        XCTAssertNil(ClubNotifyCount.parse(.string("UNKNOWN")).literal)
        XCTAssertNil(ClubNotifyCount.parse(.null).literal)
        XCTAssertNil(ClubNotifyCount.parse(.decimal(1.5)).literal)
        XCTAssertNil(ClubNotifyCount.parse(.integer(-1)).literal)
        XCTAssertEqual(ClubNotifyCount.parse(.integer(0)).literal, 0)
        XCTAssertEqual(ClubNotifyCount.parse(.integer(0)).displayText, "0")
        XCTAssertEqual(ClubNotifyPage.previewRecipient(.object(["recipientCount": .integer(0)])).displayText, "0")
        XCTAssertEqual(ClubNotifyPage.previewRecipient(.object(["recipientCount": .string("0")])).displayText, emDash)
        XCTAssertEqual(ClubNotifyPage.previewRecipient(.object(["recipientCount": .null])).displayText, emDash)
        XCTAssertEqual(ClubOpsNotifyPresentation.previewCount(.object(["recipientCount": .integer(0)])), 0)
        XCTAssertNil(ClubOpsNotifyPresentation.previewCount(.object(["recipientCount": .string("0")])))
        let eventOnly = try XCTUnwrap(permissions(codes: [], eventOperate: true, scope: ClubNotifyFixtureData.eventScope))
        let eventPage = ClubNotifyPage.project(value: ClubNotifyFixtureData.ready, capability: ClubNotifyCapability(permissions: eventOnly, scope: ClubNotifyFixtureData.eventScope))
        XCTAssertFalse(eventPage.broadcastOffered)
        XCTAssertFalse(eventPage.canAddress("ALL_MEMBERS"))
        XCTAssertTrue(eventPage.canAddress("REGISTERED"))
        XCTAssertFalse(eventPage.canAddress("NO_SHOW"))
    }

    func testDeliveryUnknownIsEmDashWhileLiteralZeroStaysZero() throws {
        let granted = try capability(scope: ClubNotifyFixtureData.statusScope)
        let missing = ClubNotifyDeliveryPage.project(value: .object(["id": .integer(131)]), capability: granted)
        XCTAssertEqual(missing.phase, .some(.unknown))
        XCTAssertEqual(missing.total?.displayText, emDash)
        XCTAssertEqual(missing.success?.displayText, emDash)
        XCTAssertEqual(missing.failed?.displayText, emDash)
        XCTAssertEqual(missing.pending?.displayText, emDash)
        XCTAssertNotEqual(missing.total?.displayText, "0")
        XCTAssertEqual(missing.statusDisplay, emDash)
        XCTAssertNil(missing.knownStatus)
        XCTAssertFalse(missing.processing)
        XCTAssertFalse(missing.retryOffered)
        let legacy = try ClubOpsNotifyCampaign(value: .object(["id": .integer(131)]))
        XCTAssertEqual(legacy.totalCount, 0)
        XCTAssertEqual(legacy.failedCount, 0)
        XCTAssertEqual(legacy.pendingCount, 0)
        let unknownStatus = ClubNotifyDeliveryPage.project(value: .object([
            "id": .integer(131), "totalCount": .integer(8), "successCount": .integer(5),
            "failedCount": .integer(1), "status": .string("UNKNOWN")
        ]), capability: granted)
        XCTAssertEqual(unknownStatus.phase, .some(.unknown))
        XCTAssertEqual(unknownStatus.statusDisplay, emDash)
        XCTAssertNil(unknownStatus.statusKey)
        XCTAssertFalse(unknownStatus.processing)
        XCTAssertEqual(unknownStatus.pending?.literal, 2)
        XCTAssertEqual(unknownStatus.failed?.displayText, "1")
        XCTAssertFalse(unknownStatus.retryOffered)
        let numeric = ClubNotifyDeliveryPage.project(value: .object([
            "id": .integer(131), "totalCount": .string("8"), "successCount": .integer(0),
            "failedCount": .string("0"), "status": .string("COMPLETED")
        ]), capability: granted)
        XCTAssertEqual(numeric.total?.displayText, emDash)
        XCTAssertEqual(numeric.success?.displayText, "0")
        XCTAssertEqual(numeric.failed?.displayText, emDash)
        XCTAssertEqual(numeric.pending?.displayText, emDash)
        XCTAssertFalse(numeric.retryOffered)
        let ready = ClubNotifyDeliveryPage.project(value: ClubNotifyFixtureData.statusReady, capability: granted)
        XCTAssertEqual(ready.phase, .some(.ready))
        XCTAssertEqual(ready.pending?.literal, 2)
        XCTAssertEqual(ready.pending?.displayText, "2")
        XCTAssertEqual(ready.statusKey, "clubOpsJN.notify.phase.partialFailed")
        XCTAssertTrue(ready.retryOffered)
        XCTAssertFalse(ready.processing)
        let zero = ClubNotifyDeliveryPage.project(value: ClubNotifyFixtureData.statusZero, capability: granted)
        XCTAssertEqual(zero.phase, .some(.empty))
        XCTAssertEqual(zero.total?.displayText, "0")
        XCTAssertEqual(zero.success?.displayText, "0")
        XCTAssertEqual(zero.failed?.displayText, "0")
        XCTAssertEqual(zero.pending?.literal, 0)
        XCTAssertEqual(zero.pending?.displayText, "0")
        XCTAssertFalse(zero.retryOffered)
        XCTAssertFalse(zero.broadcastOffered)
        let processing = ClubNotifyDeliveryPage.project(value: .object([
            "id": .integer(131), "totalCount": .integer(4), "successCount": .integer(0),
            "failedCount": .integer(0), "status": .string("processing")
        ]), capability: granted)
        XCTAssertEqual(processing.phase, .some(.ready))
        XCTAssertTrue(processing.processing)
        XCTAssertEqual(processing.pending?.literal, 4)
        XCTAssertEqual(processing.statusKey, "clubOpsJN.notify.phase.delivering")
        XCTAssertFalse(processing.retryOffered)
        let inconsistent = ClubNotifyDeliveryPage.project(value: .object([
            "id": .integer(131), "totalCount": .integer(1), "successCount": .integer(2),
            "failedCount": .integer(0), "status": .string("COMPLETED")
        ]), capability: granted)
        XCTAssertEqual(inconsistent.phase, .some(.error(.malformed)))
        XCTAssertNil(inconsistent.pending)
        XCTAssertNil(inconsistent.total)
        let overflow = ClubNotifyDeliveryPage.project(value: .object([
            "id": .integer(131), "totalCount": .integer(Int.max), "successCount": .integer(Int.max),
            "failedCount": .integer(1), "status": .string("PROCESSING")
        ]), capability: granted)
        XCTAssertEqual(overflow.phase, .some(.error(.malformed)))
        XCTAssertNil(overflow.pending)
        let badID = ClubNotifyDeliveryPage.project(value: .object(["id": .string("131"), "totalCount": .integer(1), "successCount": .integer(1), "failedCount": .integer(0), "status": .string("COMPLETED")]), capability: granted)
        XCTAssertEqual(badID.phase, .some(.error(.malformed)))
        XCTAssertNil(badID.id)
        let eventStatus = ClubGovernanceScope(clubID: 81, activityID: 101, campaignID: 131)
        let eventOnly = try XCTUnwrap(permissions(codes: [], eventOperate: true, scope: eventStatus))
        let eventCapability = ClubNotifyCapability(permissions: eventOnly, scope: eventStatus)
        XCTAssertTrue(eventCapability.canRead)
        XCTAssertFalse(eventCapability.canBroadcast)
        let eventDelivery = ClubNotifyDeliveryPage.project(value: ClubNotifyFixtureData.statusReady, capability: eventCapability)
        XCTAssertEqual(eventDelivery.phase, .some(.ready))
        XCTAssertFalse(eventDelivery.retryOffered)
        XCTAssertFalse(eventDelivery.canBroadcast)
    }

    func testLoadUsesTheExistingReadsAndDoesNotSend() async throws {
        let granted = try capability(scope: ClubNotifyFixtureData.clubScope)
        let denied = NotifyPageAccess()
        let hidden = await ClubNotifyPage.load(access: denied, scope: ClubNotifyFixtureData.clubScope, capability: .absent)
        XCTAssertTrue(hidden.hidden)
        XCTAssertNil(hidden.phase)
        XCTAssertEqual(denied.reads, 0)
        XCTAssertEqual(denied.sends, 0)
        let access = NotifyPageAccess()
        access.payload = ClubNotifyFixtureData.ready
        let loaded = await ClubNotifyPage.load(access: access, scope: ClubNotifyFixtureData.clubScope, capability: granted)
        XCTAssertEqual(loaded.phase, .some(.ready))
        XCTAssertEqual(access.reads, 1)
        XCTAssertEqual(access.sends, 0)
        XCTAssertFalse(loaded.canAddress("REGISTERED"))
        access.failure = ClubGovernanceFailure.malformed
        let failed = await ClubNotifyPage.load(access: access, scope: ClubNotifyFixtureData.clubScope, capability: granted)
        XCTAssertEqual(failed.phase, .some(.error(.malformed)))
        XCTAssertNil(failed.rows)
        XCTAssertEqual(access.sends, 0)
        access.failure = ClubGovernanceFailure.forbidden
        let refused = await ClubNotifyPage.load(access: access, scope: ClubNotifyFixtureData.clubScope, capability: granted)
        XCTAssertTrue(refused.hidden)
        XCTAssertNil(refused.rows)
        access.failure = CancellationError()
        let cancelled = await ClubNotifyPage.load(access: access, scope: ClubNotifyFixtureData.clubScope, capability: granted)
        XCTAssertEqual(cancelled.phase, .some(.loading))
        XCTAssertTrue(cancelled.hidden)
        XCTAssertEqual(access.sends, 0)
        let missingClub = await ClubNotifyPage.load(access: access, scope: ClubGovernanceScope(), capability: granted)
        XCTAssertEqual(missingClub.phase, .some(.error(.invalidRequest)))
        let status = NotifyPageAccess()
        status.payload = ClubNotifyFixtureData.statusReady
        let delivery = await ClubNotifyDeliveryPage.load(access: status, scope: ClubNotifyFixtureData.statusScope, capability: granted)
        XCTAssertEqual(delivery.phase, .some(.ready))
        XCTAssertTrue(delivery.retryOffered)
        XCTAssertEqual(status.reads, 1)
        XCTAssertEqual(status.sends, 0)
        let eventStatus = ClubGovernanceScope(clubID: 81, activityID: 101, campaignID: 131)
        let eventOnly = try XCTUnwrap(permissions(codes: [], eventOperate: true, scope: eventStatus))
        let eventCapability = ClubNotifyCapability(permissions: eventOnly, scope: eventStatus)
        status.permissionValue = try eventPermissionValue()
        status.reads = 0
        let eventDelivery = await ClubNotifyDeliveryPage.load(access: status, scope: eventStatus, capability: eventCapability)
        XCTAssertEqual(eventDelivery.phase, .some(.ready))
        XCTAssertFalse(eventDelivery.retryOffered)
        XCTAssertFalse(eventDelivery.canBroadcast)
        XCTAssertEqual(status.reads, 1)
        XCTAssertEqual(status.sends, 0)
        let fixture = ClubGovernanceFixtureAccess()
        fixture.overrideValue[.notificationStatus] = .object(["id": .integer(131), "totalCount": .null, "successCount": .null, "failedCount": .null, "status": .string("UNKNOWN")])
        let rejected = await ClubNotifyDeliveryPage.load(access: fixture, scope: ClubNotifyFixtureData.statusScope, capability: granted)
        XCTAssertEqual(rejected.phase, .some(.error(.malformed)))
        XCTAssertNil(rejected.total)
        XCTAssertTrue(fixture.sent.isEmpty)
        let counts = ClubGovernanceFixtureAccess()
        let mixed = await ClubNotifyPage.load(access: counts, scope: ClubNotifyFixtureData.clubScope, capability: granted)
        XCTAssertEqual(mixed.phase, .some(.unknown))
        XCTAssertEqual(mixed.rows?.first { $0.id == "NO_SHOW" }?.count.displayText, "0")
        XCTAssertEqual(mixed.rows?.first { $0.id == "WAITLIST" }?.count.displayText, emDash)
        XCTAssertTrue(counts.sent.isEmpty)
    }

    private func capability(scope: ClubGovernanceScope) throws -> ClubNotifyCapability {
        let permissions = try XCTUnwrap(ClubGovernancePermissions(value: ClubGovernanceFixtures.permissions, scope: scope))
        return ClubNotifyCapability(permissions: permissions, scope: scope)
    }

    private func permissions(codes: [String], eventOperate: Bool = false, scope: ClubGovernanceScope) -> ClubGovernancePermissions? {
        var accesses: [ClubGovernanceValue] = []
        if eventOperate {
            accesses.append(.object([
                "activityId": .integer(101), "topicId": .integer(91),
                "roleCodes": .array([.string("EVENT_LEAD")]),
                "permissions": .array([.string("club:event:operate")])
            ]))
        }
        return try? ClubGovernancePermissions(value: .object([
            "active": .bool(true), "club": .object(["id": .integer(81)]),
            "roleCodes": .array([.string("CLUB_OPERATOR")]),
            "permissions": .array(codes.map(ClubGovernanceValue.string)),
            "canManageRoles": .bool(false), "eventAccesses": .array(accesses)
        ]), scope: scope)
    }

    private func eventPermissionValue() throws -> ClubGovernanceValue {
        .object([
            "active": .bool(true), "club": .object(["id": .integer(81)]),
            "roleCodes": .array([.string("EVENT_LEAD")]),
            "permissions": .array([]), "canManageRoles": .bool(false),
            "eventAccesses": .array([.object([
                "activityId": .integer(101), "topicId": .integer(91),
                "roleCodes": .array([.string("EVENT_LEAD")]),
                "permissions": .array([.string("club:event:operate")])
            ])])
        ])
    }
}

@MainActor private final class NotifyPageAccess: ClubGovernanceAccess {
    var identity: ClubReadIdentity? = .init(accountID: 701, epoch: 1)
    var isConfigured = true
    var storageNamespace = "synthetic"
    var allowsOfflineWrites = false
    var reads = 0
    var sends = 0
    var failure: Error?
    var permissionValue = ClubGovernanceFixtures.permissions
    var payload = ClubGovernanceFixtures.value(.audienceCounts)
    func canDispatch(_ command: ClubGovernanceCommand) -> Bool { false }
    func read(_ operation: ClubGovernanceRead, scope: ClubGovernanceScope, options: [String: ClubGovernanceValue]) async throws -> ClubGovernanceSnapshot {
        reads += 1
        if let failure { throw failure }
        let permissions = try ClubGovernancePermissions(value: permissionValue, scope: scope)
        return .init(operation: operation, scope: scope, permissions: permissions, value: payload)
    }
    func send(_ review: ClubGovernanceReview) async throws -> ClubGovernanceValue {
        sends += 1
        throw ClubGovernanceFailure.notConfigured
    }
}
