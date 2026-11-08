import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1ClubTopicDetailTests: XCTestCase {
    typealias P = ClubTopicDetailPort
    func testAuditState() {
        XCTAssertEqual(P.auditState(status: 0, rejectReason: nil), .reviewing)
        XCTAssertEqual(P.auditState(status: 2, rejectReason: nil), .rejected)
        XCTAssertEqual(P.auditState(status: 1, rejectReason: " 图片违规 "), .rejected)
        XCTAssertEqual(P.auditState(status: 1, rejectReason: "  "), .confirmed)
        XCTAssertEqual(P.auditState(status: nil, rejectReason: nil), .confirmed)
    }
    func testSessionOverrideKeepsAuditStatesAndFlagsCancelled() {
        XCTAssertEqual(P.display(audit: .reviewing, sessionStatus: "RUNNING").state, .reviewing)
        XCTAssertEqual(P.display(audit: .confirmed, sessionStatus: "running").state, .running)
        XCTAssertEqual(P.display(audit: .confirmed, sessionStatus: "READY").state, .preparing)
        XCTAssertEqual(P.display(audit: .confirmed, sessionStatus: "bogus").state, .confirmed)
        let cancelled = P.display(audit: .confirmed, sessionStatus: "CANCELLED")
        XCTAssertEqual(cancelled.state, .ended); XCTAssertTrue(cancelled.cancelled)
    }
    func testVerifyGateNeedsStateCapabilityAndNotCancelled() {
        let running = P.display(audit: .confirmed, sessionStatus: "RUNNING")
        XCTAssertTrue(P.showsVerify(running, canViewVerify: true))
        XCTAssertFalse(P.showsVerify(running, canViewVerify: nil))
        XCTAssertFalse(P.showsVerify(P.display(audit: .confirmed, sessionStatus: "CANCELLED"), canViewVerify: true))
        XCTAssertFalse(P.showsVerify(P.display(audit: .confirmed, sessionStatus: "DRAFT"), canViewVerify: true))
    }
    func testMetricsNeverFabricateZero() {
        XCTAssertEqual(P.verifyMetrics(pending: 3, verifiedByMe: nil, headcount: 0).map(\.value), ["3", "—", "0"])
    }
    func testPrimaryPlan() {
        func plan(_ s: P.State, dir: Bool = false, canDirect: Bool = false, manage: Bool = false, club: Bool = true, n: Int = 0, valid: Bool = true) -> P.Primary {
            P.primary(state: s, directorActive: dir, canDirect: canDirect, canManageSessions: manage, hasClub: club, sessionCount: n, singleSessionHasValidID: valid)
        }
        XCTAssertEqual(plan(.reviewing), .action(.reviewing))
        XCTAssertTrue(P.State.reviewing.primaryDisabled)
        XCTAssertEqual(plan(.preparing, dir: true, canDirect: false), .none)
        XCTAssertEqual(plan(.preparing, dir: true, canDirect: true), .action(.preparing))
        XCTAssertEqual(plan(.confirmed, canDirect: true, n: 1), .action(.confirmed))
        XCTAssertEqual(plan(.confirmed, canDirect: true, n: 2), .chooseSession)
        XCTAssertEqual(plan(.confirmed, manage: true, n: 0), .openSession)
        XCTAssertEqual(plan(.confirmed, manage: true, n: 0, club: false), .none)
        XCTAssertEqual(plan(.running), .none)
    }
    func testStructureParts() {
        XCTAssertEqual(P.structureParts(chapters: 3, nodes: 0, playMode: " 解谜 "), ["3 章", "解谜"])
        XCTAssertEqual(P.structureParts(chapters: nil, nodes: 5, playMode: nil), ["5 站"])
    }
}
#endif
