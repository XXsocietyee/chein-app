import XCTest
#if canImport(QuestifyCore)
@testable import QuestifyCore

/// club/group-code: issuing for a picked session sends exactly `{activityId}` to `api/verify/groupcode/issue`.
final class ClubGroupCodeSessionIssueTests: XCTestCase {
    func testPickedSessionBuildsExactIssueBody() throws {
        let scope = ClubGovernanceScope(clubID: 81, topicID: 91, activityID: 101)
        let command = try ClubGovernanceFormDraft(operation: .issueGroupCode, scope: scope).command()
        XCTAssertEqual(command.operation.path, "api/verify/groupcode/issue")
        XCTAssertEqual(command.fields["activityId"], .integer(101))
        XCTAssertNil(command.fields["requestId"])
        XCTAssertEqual(command.fields.count, 1)
    }
    func testTopicWithoutPickedSessionCannotIssue() {
        let scope = ClubGovernanceScope(clubID: 81, topicID: 91)
        XCTAssertThrowsError(try ClubGovernanceFormDraft(operation: .issueGroupCode, scope: scope).command())
    }
}
#endif
