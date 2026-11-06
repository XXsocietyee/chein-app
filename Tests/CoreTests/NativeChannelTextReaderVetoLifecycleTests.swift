import Foundation
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Forms the veto through the original send/receipt service, client and coordinator.
/// No withheld IDs are inserted directly; all history/message bytes are synthetic.
@MainActor final class NativeChannelTextReaderVetoLifecycleTests: XCTestCase {
    @MainActor private final class Storage: ProjectEditDataStorage {
        var values: [String: Data] = [:]
        var failRemove = false
        func read(_ key: String) throws -> Data? { values[key] }
        func write(_ data: Data, key: String) throws { values[key] = data }
        func remove(_ key: String) throws {
            if failRemove { throw NativeChannelTextJournalError.unavailable }
            values[key] = nil
        }
    }
    @MainActor private final class Owner {
        var runtime: RuntimeDependencyContext?
        var session: NativeChannelSession?
        var available = true
        init(_ context: RuntimeDependencyContext) throws {
            runtime = context
            session = try .init(accountID: context.session.accountID, epoch: context.session.epoch, token: context.session.token)
        }
    }
    @MainActor private final class Reader: MessagingReading {
        var identity: MessagingReadIdentity?
        var isConfigured = true
        let conversationID: Int
        let accountID: Int
        var calls = 0
        init(account: Int, epoch: UInt64, conversation: Int) {
            identity = .init(accountID: account, epoch: epoch); accountID = account; conversationID = conversation
        }
        func messagingConversations() async throws -> [MessagingConversation] { [] }
        func messagingMessages(conversationID: Int, cursor: Int) async throws -> MessagingPage {
            XCTAssertEqual(conversationID, self.conversationID); calls += 1
            let json = "{\"list\":[{\"id\":42,\"conversationId\":\(conversationID),\"senderId\":\(accountID),\"status\":0,\"msgType\":1,\"content\":\"older normal history\"}],\"hasMore\":false}"
            return try JSONDecoder().decode(MessagingPage.self, from: Data(json.utf8))
        }
    }
    @MainActor private final class Wire: HTTPTransport {
        let context: RuntimeDependencyContext
        var requests: [URLRequest] = []
        var original: MessageTextIntent?
        var found = true
        var proofEnabled = true
        var displayStatus = 1
        var holdReceipt = false
        var pending: CheckedContinuation<(Data, Int), Error>?
        var heldReply: Data?
        init(_ context: RuntimeDependencyContext) { self.context = context }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            guard let route = NativeChannelTextRoute(request: request, baseURL: context.baseURL) else { throw APIError.invalidRequest }
            requests.append(request)
            switch route {
            case .send(let intent):
                original = intent
                // A lost original POST is recovered only through its exact APPLIED proof.
                throw URLError(.timedOut)
            case .receipt(let conversation, let key):
                guard let original, original.conversationID == conversation,
                      original.clientMessageID == key else { throw APIError.invalidRequest }
                let body: [String: Any]
                if !found { body = ["found": false, "state": "NOT_FOUND"] }
                else {
                    var fields: [String: Any] = ["found": true, "state": "APPLIED", "facade_metadata_confirmed": true,
                        "message": ["id": 42, "conversationId": conversation, "senderId": context.session.accountID,
                                    "status": displayStatus, "msgType": 1, "content": "withheld receipt payload"]]
                    if proofEnabled {
                        fields["original_send_proof"] = ["actor_member_id": String(context.session.accountID),
                            "conversation_id": String(conversation), "request_id": original.clientMessageID,
                            "operation": "SEND", "request_hash": try XCTUnwrap(NativeChannelOriginalSendDigest.requestHash(original)),
                            "message_id": "42"]
                    }
                    body = fields
                }
                let data = try JSONSerialization.data(withJSONObject: ["code": 200, "data": body])
                if holdReceipt {
                    heldReply = data
                    return try await withCheckedThrowingContinuation { pending = $0 }
                }
                return (data, 200)
            default: throw APIError.invalidRequest
            }
        }
        func waitForReceipt() async throws {
            for _ in 0..<2000 { if pending != nil { return }; await Task.yield() }
            XCTFail("Original receipt request did not enter the underlying wire"); throw APIError.invalidRequest
        }
        func finishReceipt() {
            let continuation = pending; pending = nil
            continuation?.resume(returning: (heldReply ?? Data(), 200)); heldReply = nil
        }
        func drain() { pending?.resume(throwing: CancellationError()); pending = nil; heldReply = nil }
    }
    @MainActor private final class Rig {
        let context: RuntimeDependencyContext
        let owner: Owner
        let reader: Reader
        let wire: Wire
        let storage: Storage
        let readGrant: NativeChannelTextApproval
        let writeGrant: NativeChannelTextApproval
        let sessionClient: NativeChannelSessionClient
        let history: NativeChannelHistoryModel
        let textClient: NativeChannelTextClient
        let journal: NativeChannelTextJournal
        let flow: NativeChannelTextCoordinator
        init(account: Int = 7, epoch: UInt64 = 1, conversation: Int = 9,
             namespace: String = "veto-" + UUID().uuidString, storage: Storage? = nil) throws {
            let context = RuntimeDependencyContext(market: .china, baseURL: URL(string: "https://example.test/channel-veto")!, role: "player",
                session: try .init(accountID: account, epoch: epoch, namespace: namespace, token: "synthetic-channel-token"))
            self.context = context
            let owner = try Owner(context); self.owner = owner
            let reader = Reader(account: account, epoch: epoch, conversation: conversation); self.reader = reader
            let wire = Wire(context); self.wire = wire
            self.storage = storage ?? Storage()
            readGrant = try .init(context: context, operation: .receipt, conversationIDs: [conversation], expiresAt: Date().addingTimeInterval(60))
            writeGrant = try .init(context: context, operation: .send, conversationIDs: [conversation], expiresAt: Date().addingTimeInterval(60))
            let read = readGrant, write = writeGrant
            let transport = NativeChannelTextTransport(context: context, transport: wire, current: { owner.runtime },
                read: { read }, write: { write }, stillCurrent: { true })
            textClient = try .init(context: context, conversationID: conversation, transport: transport)
            sessionClient = .init(history: reader, currentSession: { owner.session }, isAvailable: { owner.available })
            let row = try JSONDecoder().decode(MessagingConversation.self, from: Data(
                "{\"conversationId\":\(conversation),\"type\":4,\"counterparty\":{\"bizKey\":\"club_12\"}}".utf8))
            history = .init(conversation: row, client: sessionClient)
            journal = .init(storage: self.storage, scope: textClient.scope)
            flow = try .init(history: history, client: textClient, journal: journal)
        }
        func load() async {
            history.activate(); await history.load(); flow.activate()
            XCTAssertTrue(history.loaded); XCTAssertTrue(sessionClient.isConfigured)
        }
        func formHiddenVeto(status: Int = 1, retainPending: Bool = false) async throws {
            await load(); wire.displayStatus = status; storage.failRemove = retainPending
            XCTAssertEqual(history.detailMessage(42)?.content, "older normal history")
            let accepted = await flow.sendNew("original text👩🏽‍💻")
            XCTAssertTrue(accepted); XCTAssertTrue(flow.isMessageWithheld(42))
            XCTAssertEqual(flow.visibleState, .acknowledged(messageID: 42))
            XCTAssertEqual(wire.requests.map { $0.url?.lastPathComponent }, ["send", "send-receipt"])
            XCTAssertNil(flow.authoritativeMessage); XCTAssertNil(flow.pendingText)
        }
        func close() { flow.stop(); history.stop(); readGrant.revoke(); writeGrant.revoke(); wire.drain() }
    }
    func testOriginalHiddenProofStillVetoesPushedDetailAfterBothParentLifetimesStop() async throws {
        for status in [1, 2, 99] {
            let rig = try Rig(); defer { rig.close() }
            try await rig.formHiddenVeto(status: status)
            rig.flow.stop(); rig.history.stop()
            XCTAssertFalse(rig.flow.isCurrent); XCTAssertFalse(rig.history.isCurrent)
            XCTAssertTrue(rig.sessionClient.isConfigured)
            XCTAssertEqual(rig.history.detailMessage(42)?.content, "older normal history")
            XCTAssertTrue(rig.flow.isMessageWithheld(42))
            XCTAssertFalse(rig.flow.isMessageWithheld(43)); XCTAssertNil(rig.flow.authoritativeMessage)
        }
    }
    func testOnlyUnderlyingReaderIdentityOrEpochChangeRetiresMetadataBeforeSessionClosureCatchesUp() async throws {
        let replacements: [MessagingReadIdentity?] = [.init(accountID: 8, epoch: 2), .init(accountID: 7, epoch: 2), nil]
        for replacement in replacements {
            let rig = try Rig(); defer { rig.close() }
            try await rig.formHiddenVeto(retainPending: true)
            let pending = try XCTUnwrap(rig.journal.restore()), bytes = rig.storage.values
            rig.flow.stop(); rig.history.stop(); rig.reader.identity = replacement
            XCTAssertEqual(rig.sessionClient.identity, .init(accountID: 7, epoch: 1))
            XCTAssertFalse(rig.sessionClient.isConfigured)
            XCTAssertFalse(rig.flow.isMessageWithheld(42)); XCTAssertNil(rig.history.detailMessage(42))
            XCTAssertEqual(rig.storage.values, bytes)
            XCTAssertTrue(NativeChannelTextJournal.same(try rig.journal.restore(), pending))
        }
    }
    func testUnderlyingReadGrantOrAvailabilityLossMasksVetoWithoutDeletingOriginalJournal() async throws {
        for loseReader in [true, false] {
            let rig = try Rig(); defer { rig.close() }
            try await rig.formHiddenVeto(retainPending: true)
            let bytes = rig.storage.values
            if loseReader { rig.reader.isConfigured = false } else { rig.owner.available = false }
            XCTAssertFalse(rig.sessionClient.isConfigured)
            XCTAssertFalse(rig.flow.isMessageWithheld(42)); XCTAssertNil(rig.history.detailMessage(42))
            XCTAssertNil(rig.flow.authoritativeMessage); XCTAssertEqual(rig.storage.values, bytes)
            XCTAssertFalse(rig.flow.canSendNew)
        }
    }
    func testSameOwnerReadRecoveryKeepsSafetyVetoAcrossOlderNormalHistoryWithoutResend() async throws {
        let rig = try Rig(); defer { rig.close() }
        try await rig.formHiddenVeto(retainPending: true)
        let bytes = rig.storage.values, original = try XCTUnwrap(rig.journal.restore())
        rig.flow.stop(); rig.history.stop(); rig.reader.isConfigured = false
        XCTAssertFalse(rig.flow.isMessageWithheld(42))
        rig.reader.isConfigured = true
        XCTAssertTrue(rig.flow.isMessageWithheld(42))
        rig.history.activate(); await rig.history.load(); rig.flow.activate()
        XCTAssertEqual(rig.history.detailMessage(42)?.content, "older normal history")
        XCTAssertTrue(rig.flow.isMessageWithheld(42)); XCTAssertNil(rig.flow.authoritativeMessage)
        XCTAssertNil(rig.flow.pendingText); XCTAssertFalse(rig.flow.canSendNew)
        XCTAssertEqual(rig.storage.values, bytes); XCTAssertEqual(rig.wire.requests.count, 2)
        XCTAssertTrue(NativeChannelTextJournal.same(try rig.journal.restore(), original))
    }
    func testTextWriteOrReceiptGrantDoesNotReplaceTheIndependentHistoryReadBoundary() async throws {
        let rig = try Rig(); defer { rig.close() }
        try await rig.formHiddenVeto()
        rig.flow.stop(); rig.history.stop(); rig.readGrant.revoke(); rig.writeGrant.revoke()
        XCTAssertFalse(rig.textClient.canSend); XCTAssertFalse(rig.textClient.canReadReceipt)
        XCTAssertTrue(rig.sessionClient.isConfigured); XCTAssertTrue(rig.flow.isMessageWithheld(42))
        rig.reader.isConfigured = false
        XCTAssertFalse(rig.flow.isMessageWithheld(42)); XCTAssertNil(rig.history.detailMessage(42))
    }
    func testCurrentSessionAndConversationChangesCannotConsumeAnotherScopesHiddenMetadata() async throws {
        let rig = try Rig(); defer { rig.close() }
        try await rig.formHiddenVeto()
        let other = try Rig(conversation: 10, namespace: rig.context.session.namespace, storage: rig.storage)
        defer { other.close() }; await other.load()
        XCTAssertFalse(other.flow.isMessageWithheld(42))
        XCTAssertThrowsError(try NativeChannelTextCoordinator(history: rig.history, client: other.textClient, journal: other.journal))
        rig.owner.session = try .init(accountID: 8, epoch: 2, token: "replacement")
        XCTAssertFalse(rig.flow.isMessageWithheld(42)); XCTAssertNil(rig.history.detailMessage(42))
        rig.reader.identity = .init(accountID: 8, epoch: 2)
        XCTAssertTrue(rig.sessionClient.isConfigured)
        XCTAssertFalse(rig.flow.isMessageWithheld(42)); XCTAssertNil(rig.history.detailMessage(42))
    }
    func testLateOriginalReceiptCannotInstallVetoOrSettlePendingAfterReaderOrOwnerRetirement() async throws {
        for mode in 0..<4 {
            let rig = try Rig(); defer { rig.close() }
            await rig.load(); rig.wire.holdReceipt = true
            let task = Task { await rig.flow.sendNew("late original") }
            try await rig.wire.waitForReceipt()
            let original = try XCTUnwrap(rig.journal.restore()), bytes = rig.storage.values
            XCTAssertEqual(rig.wire.requests.count, 2)
            if mode == 0 { rig.reader.identity = .init(accountID: 8, epoch: 2) }
            else if mode == 1 { rig.reader.isConfigured = false }
            else if mode == 2 { rig.flow.stop(); rig.history.stop() }
            else { rig.owner.session = try .init(accountID: 8, epoch: 2, token: "replacement") }
            rig.wire.finishReceipt(); let accepted = await task.value
            XCTAssertFalse(accepted); XCTAssertEqual(rig.storage.values, bytes)
            XCTAssertTrue(NativeChannelTextJournal.same(try rig.journal.restore(), original))
            XCTAssertFalse(rig.flow.isMessageWithheld(42)); XCTAssertNil(rig.flow.authoritativeMessage)
            let foreign = try Rig(account: 8, epoch: 2, namespace: rig.context.session.namespace, storage: rig.storage)
            defer { foreign.close() }; await foreign.load()
            XCTAssertFalse(foreign.flow.isMessageWithheld(42)); XCTAssertNil(try foreign.journal.restore())
            // Restoring the legitimate original reader does not retroactively accept that late proof.
            rig.owner.session = try .init(accountID: 7, epoch: 1, token: rig.context.session.token)
            rig.reader.identity = .init(accountID: 7, epoch: 1); rig.reader.isConfigured = true
            rig.history.activate(); await rig.history.load(); rig.flow.activate()
            XCTAssertFalse(rig.flow.isMessageWithheld(42))
            rig.wire.holdReceipt = false
            let checked = await rig.flow.checkReceipt()
            XCTAssertTrue(checked); XCTAssertTrue(rig.flow.isMessageWithheld(42))
            XCTAssertEqual(rig.wire.original?.clientMessageID, original.clientMessageID)
            XCTAssertEqual(rig.wire.requests.filter { $0.url?.lastPathComponent == "send" }.count, 1)
        }
    }
    func testColdPendingRequiresStrictOriginalProofBeforeAnyHiddenVetoCanExist() async throws {
        let rig = try Rig(); defer { rig.close() }
        await rig.load(); rig.wire.proofEnabled = false
        let sent = await rig.flow.sendNew("unconfirmed original")
        XCTAssertFalse(sent); XCTAssertFalse(rig.flow.isMessageWithheld(42)); XCTAssertFalse(rig.flow.canRetryOriginal)
        let original = try XCTUnwrap(rig.journal.restore()), bytes = rig.storage.values
        rig.flow.stop(); rig.history.stop()
        let cold = try Rig(namespace: rig.context.session.namespace, storage: rig.storage)
        defer { cold.close() }; cold.wire.original = original
        await cold.load()
        XCTAssertTrue(cold.wire.requests.isEmpty); XCTAssertEqual(cold.storage.values, bytes)
        XCTAssertFalse(cold.flow.isMessageWithheld(42)); XCTAssertEqual(cold.flow.pendingClientMessageID, original.clientMessageID)
        let recovered = await cold.flow.checkReceipt()
        XCTAssertTrue(recovered); XCTAssertTrue(cold.flow.isMessageWithheld(42))
        XCTAssertEqual(cold.wire.requests.map { $0.url?.lastPathComponent }, ["send-receipt"])
        XCTAssertNil(try cold.journal.restore()); XCTAssertNil(cold.flow.authoritativeMessage)
    }
}
