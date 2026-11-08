import XCTest
@testable import Questify

/// Presentation-model checks only; not rendered or device evidence.
@MainActor final class WP14NPCChatDataRevokeTests: XCTestCase {
    private let session = ComplianceSession(accountID: 7, epoch: 1, market: "CN", namespace: "synthetic.invalid")
    private func data() throws -> NPCChatData {
        try .decode(Data(#"{"code":200,"data":{"retentionDays":14,"retentionPolicy":"Synthetic policy","records":[{"id":1,"userId":7,"userMsg":"Synthetic question","npcReply":"Synthetic answer","createTime":"2026-10-09 10:00:00"}]}}"#.utf8), expectedAccountID: 7)
    }
    private final class Clock { var now = Date(timeIntervalSince1970: 1_000) }
    private final class Flag { var revoked = false }
    private struct Fixture {
        let model: NPCChatDataViewModel; let flag: Flag; let clock: Clock
        let reads: () -> Int; let deletes: () -> Int
    }
    private func fixture() throws -> Fixture {
        let value = try data(), flag = Flag(), clock = Clock()
        var reads = 0, deletes = 0
        let coordinator = NPCChatDataCoordinator(current: { self.session }, available: { _ in true },
            read: { _ in reads += 1; return value },
            deletionAvailable: { _ in true }, deleteLogs: { _ in deletes += 1; return .deleted(count: 1) })
        let probe = NPCChatDataConsentProbe(isRevoked: { flag.revoked }, expiresAt: Date(timeIntervalSince1970: 2_000),
            revoke: { flag.revoked = true }, now: { clock.now })
        return Fixture(model: NPCChatDataViewModel(coordinator: coordinator, consent: probe), flag: flag, clock: clock,
            reads: { reads }, deletes: { deletes })
    }
    func testRevokeClearsLocalCopiesAndShowsRevokedState() async throws {
        let f = try fixture()
        f.model.appear(active: true); await f.model.load(f.model.loadIntent)
        XCTAssertNotNil(f.model.coordinator.data); XCTAssertTrue(f.model.canRevokeConsent)
        f.model.revokeConsent()
        XCTAssertNil(f.model.coordinator.data); XCTAssertNil(f.model.loadIntent); XCTAssertNil(f.model.deletionIntent)
        XCTAssertEqual(f.model.consentEnded, .revoked)
        XCTAssertTrue(f.model.consentNoticeKeys.contains("npcData.consent.revoked"))
        XCTAssertFalse(f.model.canRevokeConsent)
        f.model.requestLoad(); XCTAssertNil(f.model.loadIntent); XCTAssertEqual(f.reads(), 1)
    }
    func testExpiredConsentShowsExpiredState() async throws {
        let f = try fixture()
        f.model.appear(active: true); await f.model.load(f.model.loadIntent)
        XCTAssertNotNil(f.model.coordinator.data)
        f.clock.now = Date(timeIntervalSince1970: 2_000)
        f.model.foreground()
        XCTAssertNil(f.model.coordinator.data); XCTAssertEqual(f.model.consentEnded, .expired)
        XCTAssertTrue(f.model.consentNoticeKeys.contains("npcData.consent.expired"))
        f.model.requestLoad(); XCTAssertNil(f.model.loadIntent); XCTAssertEqual(f.reads(), 1)
    }
    func testRevokeDoesNotClaimServerDeletion() async throws {
        let f = try fixture()
        f.model.appear(active: true); await f.model.load(f.model.loadIntent)
        f.model.revokeConsent()
        XCTAssertEqual(f.deletes(), 0); XCTAssertEqual(f.model.coordinator.deletion, .idle)
        XCTAssertTrue(f.model.consentNoticeKeys.contains("npcData.consent.localOnly"))
        XCTAssertFalse(f.model.consentNoticeKeys.contains { $0.localizedCaseInsensitiveContains("deleted") || $0.hasPrefix("npcLogDelete") })
    }
}
