import XCTest
@testable import QuestifyCore

final class IMChatSessionPageTests: XCTestCase {
    func testConversationKindsStayOnTheExistingContract() {
        XCTAssertEqual(MessagingConversationKind(rawValue: 1), .direct)
        XCTAssertEqual(MessagingConversationKind(rawValue: 2), .system)
        XCTAssertEqual(MessagingConversationKind(rawValue: 3), .merchant)
        XCTAssertEqual(MessagingConversationKind(rawValue: 4), .group)
        XCTAssertEqual(MessagingConversationKind(rawValue: nil), .unknown)
        XCTAssertEqual(MessagingConversationKind(rawValue: 5), .unknown)
        XCTAssertEqual(MessagingConversationKind(rawValue: 99), .unknown)
        let direct = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":1}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(direct.kind, .direct)
        let system = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":2}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(system.kind, .system)
        let merchant = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":3}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(merchant.kind, .merchant)
        let group = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":4}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(group.kind, .group)
        let textual = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":"1"}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(textual.kind, .unknown)
        let channel = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":5}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(channel.kind, .unknown)
    }

    func testUnknownCountsStayAnEmDashAndLiteralZeroStaysZero() {
        let missing = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(missing.unread.literal, nil)
        XCTAssertEqual(missing.unreadDisplay, "—")
        XCTAssertEqual(missing.messageCountDisplay, "0")
        XCTAssertEqual(missing.phase, .empty)
        let zero = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":0}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(zero.unread.literal, 0)
        XCTAssertEqual(zero.unreadDisplay, "0")
        let token = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":"UNKNOWN"}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertNil(token.unread.literal)
        XCTAssertEqual(token.unreadDisplay, "—")
        let stringZero = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":"0"}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertNil(stringZero.unread.literal)
        XCTAssertEqual(stringZero.unreadDisplay, "—")
        let nullUnread = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":null}"#.utf8), messagesJSON: emptyEnvelope)
        XCTAssertEqual(nullUnread.unreadDisplay, "—")
        let missingList = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":4}"#.utf8), messagesJSON: Data(#"{"code":200,"data":{"hasMore":false}}"#.utf8))
        XCTAssertEqual(missingList.phase, .unknown)
        XCTAssertEqual(missingList.messageCount.literal, nil)
        XCTAssertEqual(missingList.messageCountDisplay, "—")
        XCTAssertEqual(missingList.unreadDisplay, "4")
    }

    func testReadyEmptyErrorAndUnknownDoNotGuessACount() {
        let ready = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":2}"#.utf8), messagesJSON: readyEnvelope)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.messageCountDisplay, "1")
        XCTAssertEqual(ready.unreadDisplay, "2")
        let wrongRoom = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1}"#.utf8), messagesJSON: Data(#"{"code":200,"data":{"list":[{"id":10,"conversationId":7}],"hasMore":false}}"#.utf8))
        XCTAssertEqual(wrongRoom.phase, .unknown)
        XCTAssertEqual(wrongRoom.messageCountDisplay, "—")
        let closed = IMChatSessionWire.project(conversationJSON: nil, messagesJSON: Data(#"{"code":409,"errorCode":"HANGOUT_CLOSED"}"#.utf8))
        XCTAssertEqual(closed.phase, .error)
        XCTAssertEqual(closed.messageCountDisplay, "—")
        XCTAssertEqual(closed.kind, .unknown)
        let garbage = IMChatSessionWire.project(conversationJSON: nil, messagesJSON: Data("[]".utf8))
        XCTAssertEqual(garbage.phase, .unknown)
        XCTAssertEqual(garbage.messageCountDisplay, "—")
    }

    func testSendReadReceiptAndPollStayHiddenUnlessAnExistingSendGrantApplies() {
        let ready = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1,"unread":1}"#.utf8), messagesJSON: readyEnvelope)
        XCTAssertFalse(ready.sendVisible)
        XCTAssertFalse(ready.readReceiptVisible)
        XCTAssertFalse(ready.pollVisible)
        let granted = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":1}"#.utf8), messagesJSON: readyEnvelope, sendGranted: true)
        XCTAssertTrue(granted.sendVisible)
        XCTAssertFalse(granted.readReceiptVisible)
        XCTAssertFalse(granted.pollVisible)
        let system = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":2}"#.utf8), messagesJSON: readyEnvelope, sendGranted: true)
        XCTAssertFalse(system.sendVisible)
        let unknownKind = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":"1"}"#.utf8), messagesJSON: readyEnvelope, sendGranted: true)
        XCTAssertFalse(unknownKind.sendVisible)
        let blocked = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":3}"#.utf8), messagesJSON: Data(#"{"code":200,"data":{"list":[{"id":10,"conversationId":901}],"hasMore":false,"blocked":true,"blockedByMe":false}}"#.utf8), sendGranted: true)
        XCTAssertEqual(blocked.kind, .merchant)
        XCTAssertFalse(blocked.sendVisible)
        let group = IMChatSessionWire.project(conversationJSON: Data(#"{"conversationId":901,"type":4}"#.utf8), messagesJSON: emptyEnvelope, sendGranted: true)
        XCTAssertEqual(group.phase, .empty)
        XCTAssertTrue(group.sendVisible)
        XCTAssertFalse(group.pollVisible)
        XCTAssertEqual(IMChatCountFact.unknownDisplay, "—")
        XCTAssertEqual(IMChatSessionPage.unknownAccessibilityIdentifier, "messaging.history.unknown")
    }

    func testDecodedReaderPageKeepsLiteralZeroAndDoesNotTreatMalformedAsEmpty() throws {
        let conversation = try JSONDecoder().decode(MessagingConversation.self, from: Data(#"{"conversationId":901,"type":1,"unread":0}"#.utf8))
        let empty = try JSONDecoder().decode(MessagingPage.self, from: Data(#"{"list":[],"hasMore":false}"#.utf8))
        let page = IMChatSessionWire.fromReader(conversation: conversation, page: empty)
        XCTAssertEqual(page.phase, .empty)
        XCTAssertEqual(page.messageCountDisplay, "0")
        XCTAssertEqual(page.unreadDisplay, "0")
        XCTAssertEqual(page.kind, .direct)
        let failed = IMChatSessionWire.failed(APIError.malformedResponse, conversation: conversation)
        XCTAssertEqual(failed.phase, .unknown)
        XCTAssertEqual(failed.messageCountDisplay, "—")
        XCTAssertEqual(failed.unreadDisplay, "0")
        let denied = IMChatSessionWire.failed(MessagingReadFailure(httpStatus: 403, code: 403), conversation: conversation)
        XCTAssertEqual(denied.phase, .error)
        XCTAssertEqual(denied.messageCountDisplay, "—")
        XCTAssertFalse(denied.sendVisible)
    }

    @MainActor
    func testCoordinatorReadsMessagesOnlyAndHidesAMissingCapability() async throws {
        let idle = ScriptReader(configured: false, identity: nil, result: .success(try emptyPage()))
        let hidden = IMChatSessionCoordinator(conversationID: 901, reader: idle)
        XCTAssertEqual(hidden.page.phase, .hidden)
        XCTAssertEqual(hidden.page.messageCountDisplay, "—")
        await hidden.reload()
        XCTAssertEqual(hidden.page.phase, .hidden)
        XCTAssertTrue(idle.messageCalls.isEmpty)
        XCTAssertEqual(idle.conversationCalls, 0)

        let reader = ScriptReader(result: .success(try readyPage()))
        let conversation = try JSONDecoder().decode(MessagingConversation.self, from: Data(#"{"conversationId":901,"type":1,"unread":2}"#.utf8))
        let coordinator = IMChatSessionCoordinator(conversationID: 901, conversation: conversation, reader: reader, sendGranted: true)
        XCTAssertEqual(coordinator.page.phase, .loading)
        XCTAssertEqual(coordinator.page.messageCountDisplay, "—")
        XCTAssertEqual(coordinator.page.unreadDisplay, "2")
        await coordinator.reload()
        XCTAssertEqual(reader.messageCalls.map { "\($0.0):\($0.1)" }, ["901:0"])
        XCTAssertEqual(reader.conversationCalls, 0)
        XCTAssertEqual(coordinator.page.phase, .ready)
        XCTAssertEqual(coordinator.page.messageCountDisplay, "1")
        XCTAssertTrue(coordinator.page.sendVisible)
        XCTAssertFalse(coordinator.page.readReceiptVisible)
        XCTAssertFalse(coordinator.page.pollVisible)
    }

    @MainActor
    func testCoordinatorMapsClosedAndMalformedWithoutAZeroCount() async throws {
        let closed = ScriptReader(result: .failure(MessagingReadFailure(code: 409, errorCode: "HANGOUT_CLOSED")))
        let closedOwner = IMChatSessionCoordinator(conversationID: 901, reader: closed)
        await closedOwner.reload()
        XCTAssertEqual(closedOwner.page.phase, .error)
        XCTAssertEqual(closedOwner.page.messageCountDisplay, "—")
        let malformed = ScriptReader(result: .failure(APIError.malformedResponse))
        let unknown = IMChatSessionCoordinator(conversationID: 901, reader: malformed)
        await unknown.reload()
        XCTAssertEqual(unknown.page.phase, .unknown)
        XCTAssertEqual(unknown.page.messageCountDisplay, "—")
        XCTAssertEqual(unknown.page.unreadDisplay, "—")
    }

    @MainActor
    func testStaleLoadDoesNotPublishThePreviousAccount() async throws {
        let reader = PauseReader()
        let coordinator = IMChatSessionCoordinator(conversationID: 901, reader: reader)
        let task = Task { await coordinator.reload() }
        for _ in 0..<50 {
            if reader.continuation != nil { break }
            await Task.yield()
        }
        let continuation = try XCTUnwrap(reader.continuation)
        reader.identity = MessagingReadIdentity(accountID: 8, epoch: 2)
        continuation.resume(returning: try readyPage())
        await task.value
        XCTAssertEqual(coordinator.page.phase, .hidden)
        XCTAssertEqual(coordinator.page.messageCountDisplay, "—")
        XCTAssertEqual(coordinator.page.unreadDisplay, "—")
        XCTAssertEqual(reader.messageCalls.map { "\($0.0):\($0.1)" }, ["901:0"])
    }

    #if DEBUG
    func testDebugFixtureDataProjectsReadyEmptyUnknownAndClosed() throws {
        let ready = IMChatSessionWire.project(conversationJSON: IMChatSessionFixtureData.directConversation, messagesJSON: IMChatSessionFixtureData.readyMessages, sendGranted: true)
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.kind, .direct)
        XCTAssertEqual(ready.unreadDisplay, "2")
        XCTAssertEqual(ready.messageCountDisplay, "1")
        XCTAssertTrue(ready.sendVisible)
        let zero = IMChatSessionWire.project(conversationJSON: IMChatSessionFixtureData.zeroUnreadConversation, messagesJSON: IMChatSessionFixtureData.emptyMessages)
        XCTAssertEqual(zero.phase, .empty)
        XCTAssertEqual(zero.unreadDisplay, "0")
        XCTAssertEqual(zero.messageCountDisplay, "0")
        let unknown = IMChatSessionWire.project(conversationJSON: IMChatSessionFixtureData.unknownUnreadConversation, messagesJSON: IMChatSessionFixtureData.missingListMessages)
        XCTAssertEqual(unknown.phase, .unknown)
        XCTAssertEqual(unknown.unreadDisplay, "—")
        XCTAssertEqual(unknown.messageCountDisplay, "—")
        let stringZero = IMChatSessionWire.project(conversationJSON: IMChatSessionFixtureData.stringZeroUnreadConversation, messagesJSON: IMChatSessionFixtureData.emptyMessages)
        XCTAssertEqual(stringZero.unreadDisplay, "—")
        XCTAssertEqual(stringZero.messageCountDisplay, "0")
        let system = IMChatSessionWire.project(conversationJSON: IMChatSessionFixtureData.systemConversation, messagesJSON: IMChatSessionFixtureData.readyMessages, sendGranted: true)
        XCTAssertEqual(system.kind, .system)
        XCTAssertFalse(system.sendVisible)
        let closed = IMChatSessionWire.project(conversationJSON: IMChatSessionFixtureData.directConversation, messagesJSON: IMChatSessionFixtureData.closedMessages)
        XCTAssertEqual(closed.phase, .error)
        XCTAssertEqual(closed.messageCountDisplay, "—")
        let page = try IMChatSessionFixtureData.messagingPage(IMChatSessionFixtureData.readyMessages)
        XCTAssertEqual(page.messages.map(\.id), [10])
        XCTAssertFalse(page.hasMore)
    }
    #endif

    private var emptyEnvelope: Data { Data(#"{"code":200,"data":{"list":[],"hasMore":false}}"#.utf8) }
    private var readyEnvelope: Data { Data(#"{"code":200,"data":{"list":[{"id":10,"conversationId":901,"status":0,"content":"Synthetic received text"}],"hasMore":false}}"#.utf8) }
    private func emptyPage() throws -> MessagingPage {
        try JSONDecoder().decode(MessagingPage.self, from: Data(#"{"list":[],"hasMore":false}"#.utf8))
    }
    private func readyPage() throws -> MessagingPage {
        try JSONDecoder().decode(MessagingPage.self, from: Data(#"{"list":[{"id":10,"conversationId":901,"status":0,"content":"Synthetic received text"}],"hasMore":false}"#.utf8))
    }
}

@MainActor
private final class ScriptReader: MessagingReading {
    var isConfigured: Bool
    var identity: MessagingReadIdentity?
    var messageCalls: [(Int, Int)] = []
    var conversationCalls = 0
    var result: Result<MessagingPage, Error>
    init(configured: Bool = true, identity: MessagingReadIdentity? = MessagingReadIdentity(accountID: 7, epoch: 1), result: Result<MessagingPage, Error>) {
        isConfigured = configured
        self.identity = identity
        self.result = result
    }
    func messagingConversations() async throws -> [MessagingConversation] {
        conversationCalls += 1
        return []
    }
    func messagingMessages(conversationID: Int, cursor: Int) async throws -> MessagingPage {
        messageCalls.append((conversationID, cursor))
        return try result.get()
    }
}

@MainActor
private final class PauseReader: MessagingReading {
    var isConfigured = true
    var identity: MessagingReadIdentity? = MessagingReadIdentity(accountID: 7, epoch: 1)
    var messageCalls: [(Int, Int)] = []
    var continuation: CheckedContinuation<MessagingPage, Error>?
    func messagingConversations() async throws -> [MessagingConversation] { [] }
    func messagingMessages(conversationID: Int, cursor: Int) async throws -> MessagingPage {
        messageCalls.append((conversationID, cursor))
        return try await withCheckedThrowingContinuation { continuation = $0 }
    }
}
