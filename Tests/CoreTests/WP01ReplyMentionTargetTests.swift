import XCTest
@testable import QuestifyCore

final class WP01ReplyMentionTargetTests: XCTestCase {
    private func id(_ raw: String) -> NativeChannelMessageID { NativeChannelMessageID(rawValue: raw)! }
    private func quote(_ json: String) throws -> NativeChannelMessageQuote { try JSONDecoder().decode(NativeChannelMessageQuote.self, from: Data(json.utf8)) }
    private var members: [NativeChannelMentionTargets.Member] { [.init(id: id("11"), name: "A"), .init(id: id("22"), name: "B")] }

    func testReplyTargetsRepliedToSenderMemberID() throws {
        let q = try quote(#"{"id":"5","state":"VISIBLE","summary":"hi","senderId":"22"}"#)
        XCTAssertEqual(NativeChannelMentionTargets.replyMentionTarget(for: q, viewerMemberID: id("11"), members: members), id("22"))
    }
    func testReplyToSelfProducesNoMention() throws {
        let q = try quote(#"{"id":"5","state":"VISIBLE","summary":"hi","senderId":"11"}"#)
        XCTAssertNil(NativeChannelMentionTargets.replyMentionTarget(for: q, viewerMemberID: id("11"), members: members))
    }
    func testReplyToUnknownSenderProducesNoMention() throws {
        let unlisted = try quote(#"{"id":"5","state":"VISIBLE","senderId":"99"}"#)
        XCTAssertNil(NativeChannelMentionTargets.replyMentionTarget(for: unlisted, viewerMemberID: id("11"), members: members))
        let recalled = try quote(#"{"id":"5","state":"RECALLED","senderId":"22"}"#)
        XCTAssertNil(NativeChannelMentionTargets.replyMentionTarget(for: recalled, viewerMemberID: id("11"), members: members))
        XCTAssertNil(NativeChannelMentionTargets.replyMentionTarget(for: nil, viewerMemberID: id("11"), members: members))
    }
}
