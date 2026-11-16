import XCTest
@testable import Questify

/// Acceptance R2 F-09 / F-10: club chat and DM composer.
/// F-09: the club chat handed the history a new reader on every render, so the history kept
/// reloading and the composer field stayed disabled while the user typed; Send then had no draft.
/// F-10: Send must not depend on keyboard focus (the 完成 keyboard pill was removed).
@MainActor final class AcceptanceR2ClubChatComposerTests: XCTestCase {
    private let identity = MessagingReadIdentity(accountID: 7, epoch: 1)

    private func model(_ writer: Writer) -> MessageComposerModel {
        let model = MessageComposerModel(.init(accountID: 7, conversationID: 9, writer: writer))
        model.observe(); return model
    }

    func testDraftIsAcceptedWhileHistoryLoadsAndSendWaitsForReadyHistory() async throws {
        let writer = Writer(), composer = model(writer)
        // The history has not finished its first read: typing is allowed, Send is not.
        XCTAssertTrue(composer.acceptsTyping)
        composer.draft = "Acceptance club message from 9004"
        XCTAssertNil(composer.prepare(.send(composer.draft), identity: identity, canReply: false))
        XCTAssertEqual(composer.draft, "Acceptance club message from 9004")
        XCTAssertTrue(writer.texts.isEmpty)
        // History ready: the same draft sends and the receipt is the visible state.
        let token = try XCTUnwrap(composer.prepare(.send(composer.draft), identity: identity, canReply: true))
        let accepted = await composer.perform(token, canReply: { true })
        XCTAssertTrue(accepted)
        XCTAssertEqual(writer.texts.map(\.content), ["Acceptance club message from 9004"])
        guard case .acknowledged(let receipt) = composer.state else { return XCTFail("No send receipt: \(composer.state)") }
        XCTAssertEqual(receipt.content, "Acceptance club message from 9004")
        XCTAssertEqual(composer.draft, "")
        XCTAssertTrue(composer.acceptsTyping)
    }

    func testSendDoesNotDependOnKeyboardFocus() async throws {
        // There is no focus input to the send path at all: prepare/perform take only the draft,
        // identity and the reply lease. A send issued while the field is focused succeeds.
        let writer = Writer(), composer = model(writer)
        composer.draft = "Acceptance DM from 9004"
        let token = try XCTUnwrap(composer.prepare(.send(composer.draft), identity: identity, canReply: true))
        let accepted = await composer.perform(token, canReply: { true })
        XCTAssertTrue(accepted)
        XCTAssertEqual(writer.texts.count, 1)
    }

    func testFailedSendShowsReasonAndLocksTypingUntilRetry() async throws {
        let writer = Writer(), composer = model(writer)
        writer.fail = true
        composer.draft = "Will time out"
        let token = try XCTUnwrap(composer.prepare(.send(composer.draft), identity: identity, canReply: true))
        let accepted = await composer.perform(token, canReply: { true })
        XCTAssertFalse(accepted)
        XCTAssertEqual(composer.state, .outcomeUnknown)
        XCTAssertFalse(composer.acceptsTyping)
        XCTAssertEqual(composer.coordinator.pendingText, "Will time out")
        writer.fail = false
        let clientID = try XCTUnwrap(composer.coordinator.pendingClientMessageID)
        let retry = try XCTUnwrap(composer.prepare(.retry(clientID), identity: identity, canReply: true))
        let retried = await composer.perform(retry, canReply: { true })
        XCTAssertTrue(retried)
        guard case .acknowledged = composer.state else { return XCTFail("Retry did not reach a receipt") }
        XCTAssertEqual(writer.texts.map(\.clientMessageID).count, 2)
        XCTAssertEqual(Set(writer.texts.map(\.clientMessageID)).count, 1, "Retry must reuse the client message id")
    }

    func testTypingLockedWithoutWriterOrAppearance() {
        let writer = Writer()
        writer.isConfigured = false
        XCTAssertFalse(model(writer).acceptsTyping)
        let other = Writer(), unobserved = MessageComposerModel(.init(accountID: 7, conversationID: 9, writer: other))
        XCTAssertFalse(unobserved.acceptsTyping)
        let retired = model(Writer()); retired.retire()
        XCTAssertFalse(retired.acceptsTyping)
    }

    func testClubChatHistoryKeepsOneReaderAcrossRenders() async throws {
        let container = AppSessionContainer(arguments: [IntegratedNativeAcceptanceFixture.flag, "ready"])
        let wire = try XCTUnwrap(container.integratedAcceptance)
        let defaults = try XCTUnwrap(wire.defaults), suite = wire.suiteName
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        let session = try XCTUnwrap(container.session)
        await session.authChannels.loginWithPhone(phone: "10000000000", code: "123456")
        XCTAssertEqual(session.account?.id, 7)
        // Root cause: every access builds a new reader, so a re-render was a new history input.
        XCTAssertFalse(session.messagingReader === session.messagingReader)
        // ClubChatEntryView now holds the same owner the messaging home uses.
        let owner = SessionMessagingHomeReaderOwner()
        let first = owner.reader(for: session)
        XCTAssertTrue(owner.reader(for: session) === first)
        XCTAssertTrue(owner.reader(for: session) === first)
    }

    @MainActor private final class Writer: MessageActionWriting {
        var identity: MessagingReadIdentity? = .init(accountID: 7, epoch: 1)
        var isConfigured = true, fail = false
        var texts: [MessageTextIntent] = []
        func send(_ intent: MessageTextIntent, expectedIdentity: MessagingReadIdentity) async throws -> MessagingMessage {
            texts.append(intent)
            if fail { throw URLError(.timedOut) }
            return try JSONDecoder().decode(MessagingMessage.self, from: JSONSerialization.data(withJSONObject:
                ["id": 10, "conversationId": 9, "senderId": 7, "status": 0, "msgType": 1, "content": intent.content]))
        }
    }
}
