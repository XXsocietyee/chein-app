import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// club/apply: the native four-step form draft must produce the exact `api/club/become-leader`
/// body the mini-program sends (0/1 flags, null sizes, comma-joined certImages, hasExperience).
final class ClubHostApplyDraftTests: XCTestCase {
    private func draft() -> ClubGovernanceFormDraft {
        ClubGovernanceFormDraft(operation: .hostApply, scope: ClubGovernanceScope())
    }
    func testUntouchedDraftIsRejectedBecauseNameAndPhoneAreRequired() {
        XCTAssertThrowsError(try draft().command()) { XCTAssertEqual($0 as? ClubGovernanceFailure, .invalidRequest) }
        var onlyName = draft(); onlyName.text["leaderName"] = "Mina"
        XCTAssertThrowsError(try onlyName.command())
    }
    func testFilledDraftMatchesMiniProgramBody() throws {
        var form = draft()
        form.text["leaderName"] = " Mina "
        form.text["phone"] = "13800000000"
        form.text["experience"] = "5-20场"
        form.text["maxEventSize"] = "40"
        form.flags["canNpc"] = true
        form.flags["hasGuideCert"] = true
        let command = try form.command()
        XCTAssertEqual(command.operation.path, "api/club/become-leader")
        XCTAssertEqual(command.fields["leaderName"], .string("Mina"))
        XCTAssertEqual(command.fields["phone"], .string("13800000000"))
        XCTAssertEqual(command.fields["experience"], .string("5-20场"))
        XCTAssertEqual(command.fields["hasExperience"], .integer(1))
        XCTAssertEqual(command.fields["maxEventSize"], .integer(40))
        XCTAssertEqual(command.fields["avgEventSize"], .null)
        XCTAssertEqual(command.fields["canNpc"], .integer(1))
        XCTAssertEqual(command.fields["canDesignRoute"], .integer(0))
        XCTAssertEqual(command.fields["hasGuideCert"], .integer(1))
        XCTAssertEqual(command.fields["certImages"], .string(""))
        XCTAssertNil(command.fields["requestId"])
    }
    func testNoExperienceMeansHasExperienceZeroAndBadSizeIsRejected() throws {
        var form = draft()
        form.text["leaderName"] = "Mina"; form.text["phone"] = "13800000000"
        XCTAssertEqual(try form.command().fields["hasExperience"], .integer(0))
        form.text["avgEventSize"] = "many"
        XCTAssertThrowsError(try form.command())
    }
}
#endif
