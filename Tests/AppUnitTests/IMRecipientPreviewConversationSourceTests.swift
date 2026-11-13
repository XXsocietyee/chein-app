import Foundation
import XCTest
@testable import Questify

@MainActor final class IMRecipientPreviewConversationSourceTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_763_000_000)

    func testMessageConversationIDIsTheDecodedMessageConversationID() throws {
        let source = try String(contentsOfFile: repoPath("App/IMRecipientPreviewRow.swift"), encoding: .utf8)
        let expressions = messageConversationIDExpressions(in: source)
        XCTAssertEqual(expressions, ["Int64(message.conversationID)"])
        XCTAssertTrue(source.contains("static func issuedRoute(message: MessagingMessage, lease: IMPreviewTemplateLease, now: Date)"))
        XCTAssertTrue(source.contains("IMPreviewRouteTemplates.all.map"))
        XCTAssertFalse(source.contains("messageConversationID: lease"))
        XCTAssertFalse(source.contains("messageConversationID: conversationID"))
        XCTAssertFalse(source.contains("messageConversationID: self."))
        let history = try String(contentsOfFile: repoPath("App/MessagingHistoryView.swift"), encoding: .utf8)
        let channel = try String(contentsOfFile: repoPath("App/NativeChannelMessageBubbleView.swift"), encoding: .utf8)
        XCTAssertTrue(history.contains("IMRecipientPreviewRow(message: message, input: recipientPreview)"))
        XCTAssertTrue(channel.contains("IMRecipientPreviewRow(message: snapshot.message, input: recipientPreview)"))
        XCTAssertFalse(history.contains("messageConversationID:"))
        XCTAssertFalse(channel.contains("messageConversationID:"))
    }

    func testScreenIssuesTheSixGetsForTheDecodedConversation() throws {
        let message = try message(id: 42, conversationID: 11)
        let input = IMRecipientPreviewInput(phase: .ready, leases: try leases(conversationID: 11), now: now)
        let lines = IMRecipientPreviewBoard.lines(message: message, input: input)
        XCTAssertEqual(lines.count, 6)
        XCTAssertEqual(lines.map(\.kind), Array(repeating: .issued, count: 6))
        XCTAssertEqual(lines.map(\.slot), [
            "file-authorization", "file-preview", "video-authorization", "video-preview", "voice-message", "voice-authorization"
        ])
        XCTAssertTrue(lines.allSatisfy { $0.value == expectedPath(slot: $0.slot, messageID: 42) })
        XCTAssertTrue(lines.allSatisfy { $0.value != IMRecipientPreviewLine.dash })
    }

    func testLeaseForConversationADoesNotPreviewMessageInConversationB() throws {
        let message = try message(id: 42, conversationID: 22)
        let input = IMRecipientPreviewInput(phase: .ready, leases: try leases(conversationID: 11), now: now)
        let lines = IMRecipientPreviewBoard.lines(message: message, input: input)
        XCTAssertEqual(lines.count, 6)
        XCTAssertEqual(Set(lines.map(\.kind)), [.refused])
        XCTAssertTrue(lines.allSatisfy { $0.value == IMRecipientPreviewLine.dash })
    }

    func testClosedLeaseAndNilIssueShowAnEmDash() throws {
        let message = try message(id: 42, conversationID: 11)
        let closed = IMRecipientPreviewBoard.lines(message: message, input: .closed)
        XCTAssertEqual(closed.count, 6)
        XCTAssertEqual(Set(closed.map(\.kind)), [.closed])
        XCTAssertTrue(closed.allSatisfy { $0.value == IMRecipientPreviewLine.dash })

        let expired = try leases(conversationID: 11, expiresAt: now)
        let nilIssue = IMRecipientPreviewBoard.lines(
            message: message,
            input: IMRecipientPreviewInput(phase: .ready, leases: expired, now: now)
        )
        XCTAssertEqual(nilIssue.count, 6)
        XCTAssertEqual(Set(nilIssue.map(\.kind)), [.closed])
        XCTAssertTrue(nilIssue.allSatisfy { $0.value == IMRecipientPreviewLine.dash })
        XCTAssertTrue(nilIssue.allSatisfy { $0.kind != .issued })
    }

    func testLoadingEmptyErrorAndRefusedStayVisible() throws {
        let message = try message(id: 42, conversationID: 11)
        let cases: [(IMRecipientPreviewPhase, IMRecipientPreviewKind)] = [
            (.loading, .loading),
            (.empty, .empty),
            (.error, .error),
            (.refused, .refused)
        ]
        let row = try String(contentsOfFile: repoPath("App/IMRecipientPreviewRow.swift"), encoding: .utf8)
        for key in ["im.preview.loading", "im.preview.empty", "im.preview.error", "im.preview.refused"] {
            XCTAssertTrue(row.contains("Text(\"\(key)\", tableName: \"IMRecipientPreview\")"))
        }
        for item in cases {
            let lines = IMRecipientPreviewBoard.lines(
                message: message,
                input: IMRecipientPreviewInput(phase: item.0, leases: try leases(conversationID: 11), now: now)
            )
            XCTAssertEqual(lines.count, 6, "\(item.0)")
            XCTAssertEqual(Set(lines.map(\.kind)), [item.1], "\(item.0)")
            XCTAssertTrue(lines.allSatisfy { $0.value == IMRecipientPreviewLine.dash }, "\(item.0)")
        }
    }

    private func messageConversationIDExpressions(in source: String) -> [String] {
        var results: [String] = []
        var search = source.startIndex
        let needle = "messageConversationID:"
        while let range = source.range(of: needle, range: search..<source.endIndex) {
            var index = range.upperBound
            while index < source.endIndex, source[index].isWhitespace || source[index].isNewline {
                index = source.index(after: index)
            }
            let start = index
            var depth = 0
            while index < source.endIndex {
                let character = source[index]
                if character == "(" { depth += 1 }
                if character == ")" {
                    if depth == 0 { break }
                    depth -= 1
                }
                if character == ",", depth == 0 { break }
                index = source.index(after: index)
            }
            results.append(source[start..<index].trimmingCharacters(in: .whitespacesAndNewlines))
            search = index
        }
        return results
    }

    private func message(id: Int, conversationID: Int) throws -> MessagingMessage {
        let json = #"{"id":\#(id),"conversationId":\#(conversationID),"senderId":8,"status":0,"msgType":1,"content":"preview","createTime":"12:00"}"#
        return try JSONDecoder().decode(MessagingMessage.self, from: Data(json.utf8))
    }

    private func leases(conversationID: Int64, expiresAt: Date? = nil) throws -> [IMPreviewTemplateLease] {
        let viewer = try context()
        let expiry = expiresAt ?? now.addingTimeInterval(3600)
        return try IMPreviewRouteTemplates.all.map { template in
            try XCTUnwrap(IMPreviewTemplateLease(template: template, viewer: viewer, conversationID: conversationID, expiresAt: expiry))
        }
    }

    private func context() throws -> RuntimeDependencyContext {
        let base = try XCTUnwrap(URL(string: "https://fixture.example"))
        let session = try PlayExperienceSession(accountID: 7, epoch: 1, namespace: "tests", token: "synthetic-token", role: "player")
        return RuntimeDependencyContext(market: .china, baseURL: base, role: "player", session: session)
    }

    private func expectedPath(slot: String, messageID: Int) -> String {
        switch slot {
        case "file-authorization": return "api/im/file/message/\(messageID)/authorization"
        case "file-preview": return "api/im/file/message/\(messageID)/preview"
        case "video-authorization": return "api/im/video/message/\(messageID)/authorization"
        case "video-preview": return "api/im/video/message/\(messageID)/preview"
        case "voice-message": return "api/im/voice/message/\(messageID)"
        case "voice-authorization": return "api/im/voice/message/\(messageID)/authorization"
        default: return ""
        }
    }

    private func repoPath(_ relative: String) -> String {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent(relative).path
    }
}
