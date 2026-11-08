import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

final class Port1ClubGroupCodeTests: XCTestCase {
    func testSessionLabelAppendsStartOnlyWhenBothPartsParse() {
        XCTAssertEqual(ClubGroupCodePort.sessionLabel(id: 7, name: "夜游", startDate: "2026-09-06", startTime: "9:05"), "夜游 · 9月6日 09:05")
        XCTAssertEqual(ClubGroupCodePort.sessionLabel(id: 7, name: nil, startDate: "2026-09-06 18:30", startTime: nil), "场次 7 · 9月6日 18:30")
        XCTAssertEqual(ClubGroupCodePort.sessionLabel(id: 7, name: " A ", startDate: "2026-13-06", startTime: "10:00"), "A")
        XCTAssertEqual(ClubGroupCodePort.sessionLabel(id: 7, name: "A", startDate: "2026-09-06", startTime: "25:00"), "A")
    }
    func testSessionIDsDropInvalid() {
        XCTAssertEqual(ClubGroupCodePort.sessionIDs([1, nil, 0, -3, 9]), [1, 9])
    }
    func testPermissionDenialIsTerminal() {
        XCTAssertEqual(ClubGroupCodePort.classify(code: 403, message: nil), .noPermission)
        XCTAssertEqual(ClubGroupCodePort.classify(code: 500, message: "您没有该场次的团码核销权限"), .noPermission)
        XCTAssertEqual(ClubGroupCodePort.classify(code: 500, message: "出码失败"), .retryable)
        XCTAssertEqual(ClubGroupCodePort.classify(.forbidden), .noPermission)
        XCTAssertEqual(ClubGroupCodePort.classify(.rejected(code: 403, message: nil)), .noPermission)
        XCTAssertEqual(ClubGroupCodePort.classify(.busy), .retryable)
    }
    func testReissueAtExpiry() {
        let t = Date(timeIntervalSince1970: 1000)
        XCTAssertFalse(ClubGroupCodePort.needsReissue(expiresAt: t, now: t.addingTimeInterval(-1)))
        XCTAssertTrue(ClubGroupCodePort.needsReissue(expiresAt: t, now: t))
    }
}
#endif
