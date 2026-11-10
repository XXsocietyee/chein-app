import Foundation
import CoreFoundation

/// Value-type reducer. A failed/invalid page cannot advance the cursor or erase history.
/// Preserves server order, deduplicates by message ID and uses the incoming copy on overlap.
public struct MessagingHistory: Equatable {
    public let conversationID: Int
    public private(set) var messages: [MessagingMessage] = []
    public private(set) var nextCursor: Int?
    public private(set) var hasMore = false
    private var consumedCursors: Set<Int> = []
    public init(conversationID: Int) { self.conversationID = conversationID }

    public mutating func replace(with page: MessagingPage) throws {
        try validate(page)
        messages = Self.unique(page.messages)
        nextCursor = page.nextCursor
        hasMore = page.hasMore
        consumedCursors = []
    }
    public mutating func prepend(_ page: MessagingPage, requestedCursor: Int) throws {
        guard hasMore, requestedCursor > 0, requestedCursor == nextCursor else { throw APIError.invalidRequest }
        try validate(page)
        // The server cursor may be unrelated to message IDs; reject cycles only.
        if page.hasMore, let next = page.nextCursor,
           next == requestedCursor || consumedCursors.contains(next) { throw APIError.malformedResponse }
        let incoming = Self.unique(page.messages)
        let incomingIDs = Set(incoming.map(\.id))
        messages = incoming + messages.filter { !incomingIDs.contains($0.id) }
        consumedCursors.insert(requestedCursor)
        nextCursor = page.nextCursor
        hasMore = page.hasMore
    }
    @MainActor public static func readExistingMessage(id: Int, conversationID: Int,
        preferredCursor: Int = 0, using reader: any MessagingReading,
        stillCurrent: () -> Bool) async throws -> (message: MessagingMessage?, cursor: Int) {
        guard id > 0, conversationID > 0, preferredCursor >= 0 else { throw APIError.invalidRequest }
        let identity = reader.identity
        func check() throws {
            try Task.checkCancellation()
            guard stillCurrent(), identity != nil, reader.identity == identity, reader.isConfigured else {
                throw CancellationError()
            }
        }
        func page(_ cursor: Int) async throws -> MessagingPage {
            try check()
            let result = try await reader.messagingMessages(conversationID: conversationID, cursor: cursor)
            try check()
            guard result.messages.allSatisfy({ $0.conversationID == conversationID }) else { throw APIError.malformedResponse }
            return result
        }
        if preferredCursor > 0 {
            let nearby = try await page(preferredCursor)
            if let message = nearby.messages.last(where: { $0.id == id }) { return (message, preferredCursor) }
        }
        var cursor = 0, consumed = Set<Int>(), pages = 0
        while true {
            pages += 1
            // A cursor that never repeats must not page forever.
            guard pages <= 1024 else { throw APIError.malformedResponse }
            guard consumed.insert(cursor).inserted else { throw APIError.malformedResponse }
            let result = try await page(cursor)
            if let message = result.messages.last(where: { $0.id == id }) { return (message, cursor) }
            guard result.hasMore else { return (nil, 0) }
            guard let next = result.nextCursor, next > 0 else { throw APIError.malformedResponse }
            cursor = next
        }
    }
    private func validate(_ page: MessagingPage) throws {
        guard conversationID > 0, page.messages.allSatisfy({ $0.conversationID == conversationID }) else {
            throw APIError.malformedResponse
        }
    }
    private static func unique(_ values: [MessagingMessage]) -> [MessagingMessage] {
        var result: [MessagingMessage] = [], positions: [Int: Int] = [:]
        for value in values {
            if let index = positions[value.id] { result[index] = value }
            else { positions[value.id] = result.count; result.append(value) }
        }
        return result
    }
}

public enum MessagingConversationScope: String, CaseIterable {
    case all, channels, direct
    public func includes(_ conversation: MessagingConversation) -> Bool {
        switch self {
        case .all: return true
        case .channels: return conversation.kind == .group
        case .direct: return conversation.kind == .direct || conversation.kind == .merchant
        }
    }
}


/// Read model for `subpackageB/pages/im/chat/index`.
/// The only network fact this type accepts is the existing `POST api/im/messages`
/// envelope (and the conversation row already returned by `POST api/im/conversations`).
/// Send, automatic read receipts, and polling stay hidden. No route is added or marked live.
public enum IMChatSessionPhase: String, Equatable {
    case hidden
    case loading
    case empty
    case error
    case unknown
    case ready
}

/// A count the server actually sent as a JSON number. Unknown is never stored as 0.
public struct IMChatCountFact: Equatable {
    public enum Storage: Equatable {
        case unknown
        case value(Int)
    }

    public let storage: Storage
    public static let unknownDisplay = "—"

    public var literal: Int? {
        if case .value(let number) = storage { return number }
        return nil
    }

    public var displayText: String {
        switch storage {
        case .unknown: return Self.unknownDisplay
        case .value(let number): return String(number)
        }
    }

    public static let unknown = IMChatCountFact(storage: .unknown)
    public static func known(_ number: Int) -> IMChatCountFact { IMChatCountFact(storage: .value(number)) }

    init(storage: Storage) { self.storage = storage }

    /// JSON integers, including 0. Null, a missing value, `UNKNOWN`, a numeric string, a bool, and an object stay unknown.
    public static func parse(_ value: Any?) -> IMChatCountFact {
        guard let value, !(value is NSNull) else { return .unknown }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return .unknown }
        if CFNumberIsFloatType(number) {
            let raw = number.doubleValue
            guard raw.isFinite, abs(raw) <= Double(Int.max) else { return .unknown }
            let int = Int(raw)
            guard Double(int) == raw else { return .unknown }
            return .known(int)
        }
        guard let int = Int(exactly: number.int64Value) else { return .unknown }
        return .known(int)
    }
}

public struct IMChatSessionPage: Equatable {
    public let phase: IMChatSessionPhase
    public let kind: MessagingConversationKind
    public let unread: IMChatCountFact
    public let messageCount: IMChatCountFact
    public let sendVisible: Bool
    /// Automatic `/api/im/read` stays off. Opening this page does not send a receipt.
    public let readReceiptVisible: Bool
    /// The 8-second visible poll is not part of this model.
    public let pollVisible: Bool
    public static let unknownAccessibilityIdentifier = "messaging.history.unknown"

    public var unreadDisplay: String { unread.displayText }
    public var messageCountDisplay: String { messageCount.displayText }

    init(phase: IMChatSessionPhase, kind: MessagingConversationKind, unread: IMChatCountFact,
         messageCount: IMChatCountFact, blocked: Bool?, sendGranted: Bool) {
        self.phase = phase
        self.kind = kind
        self.unread = unread
        self.messageCount = messageCount
        let open = phase == .ready || phase == .empty
        let replyable = kind == .direct || kind == .merchant || kind == .group
        sendVisible = sendGranted && open && replyable && blocked != true
        readReceiptVisible = false
        pollVisible = false
    }
}

/// Pure projection of the existing chat envelopes. Callers that already hold a `MessagingPage`
/// use `fromReader`. This parser does not invent fields and does not turn a bad payload into an empty list.
public enum IMChatSessionWire {
    public static func project(conversationJSON: Data?, messagesJSON: Data, sendGranted: Bool = false) -> IMChatSessionPage {
        let conversation = conversationJSON.flatMap { jsonObject($0) }
        let kind = kind(of: conversation)
        let unread = IMChatCountFact.parse(conversation?["unread"])
        guard let root = jsonObject(messagesJSON) else {
            return IMChatSessionPage(phase: .unknown, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: sendGranted)
        }
        guard let code = IMChatCountFact.parse(root["code"]).literal else {
            return IMChatSessionPage(phase: .unknown, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: sendGranted)
        }
        if code != 200 {
            return IMChatSessionPage(phase: .error, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: sendGranted)
        }
        guard let data = root["data"] as? [String: Any],
              let list = data["list"] as? [Any],
              let hasMore = jsonBool(data["hasMore"]) else {
            return IMChatSessionPage(phase: .unknown, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: sendGranted)
        }
        let blocked = jsonBool(data["blocked"])
        guard rowsBelong(list, to: conversation) else {
            return IMChatSessionPage(phase: .unknown, kind: kind, unread: unread, messageCount: .unknown, blocked: blocked, sendGranted: sendGranted)
        }
        if list.isEmpty {
            if hasMore {
                return IMChatSessionPage(phase: .unknown, kind: kind, unread: unread, messageCount: .unknown, blocked: blocked, sendGranted: sendGranted)
            }
            return IMChatSessionPage(phase: .empty, kind: kind, unread: unread, messageCount: .known(0), blocked: blocked, sendGranted: sendGranted)
        }
        return IMChatSessionPage(phase: .ready, kind: kind, unread: unread, messageCount: .known(list.count), blocked: blocked, sendGranted: sendGranted)
    }

    public static func fromReader(conversation: MessagingConversation?, page: MessagingPage, sendGranted: Bool = false) -> IMChatSessionPage {
        let kind = conversation?.kind ?? .unknown
        let unread = conversation?.unread.map(IMChatCountFact.known) ?? .unknown
        if page.messages.isEmpty {
            if page.hasMore {
                return IMChatSessionPage(phase: .unknown, kind: kind, unread: unread, messageCount: .unknown, blocked: page.blocked, sendGranted: sendGranted)
            }
            return IMChatSessionPage(phase: .empty, kind: kind, unread: unread, messageCount: .known(0), blocked: page.blocked, sendGranted: sendGranted)
        }
        return IMChatSessionPage(phase: .ready, kind: kind, unread: unread, messageCount: .known(page.messages.count), blocked: page.blocked, sendGranted: sendGranted)
    }

    public static func failed(_ error: Error, conversation: MessagingConversation?) -> IMChatSessionPage {
        let kind = conversation?.kind ?? .unknown
        let unread = conversation?.unread.map(IMChatCountFact.known) ?? .unknown
        let phase: IMChatSessionPhase
        if let api = error as? APIError, api == .malformedResponse { phase = .unknown }
        else { phase = .error }
        return IMChatSessionPage(phase: phase, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: false)
    }

    private static func kind(of conversation: [String: Any]?) -> MessagingConversationKind {
        guard let conversation, let type = IMChatCountFact.parse(conversation["type"]).literal else { return .unknown }
        return MessagingConversationKind(rawValue: type)
    }

    private static func rowsBelong(_ list: [Any], to conversation: [String: Any]?) -> Bool {
        let expected = conversation.flatMap { IMChatCountFact.parse($0["conversationId"]).literal }
        for item in list {
            guard let row = item as? [String: Any],
                  let id = IMChatCountFact.parse(row["id"]).literal, id > 0,
                  let conversationID = IMChatCountFact.parse(row["conversationId"]).literal, conversationID > 0 else { return false }
            if let expected, conversationID != expected { return false }
        }
        return true
    }

    private static func jsonObject(_ data: Data) -> [String: Any]? {
        (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }

    private static func jsonBool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }
}

/// Loads one history page through the existing `MessagingReading` contract.
/// A missing reader, identity, or conversation id stays hidden. This type never calls send, read, or poll.
@MainActor
public final class IMChatSessionCoordinator {
    public private(set) var page: IMChatSessionPage
    private let reader: any MessagingReading
    private let conversationID: Int
    private let conversation: MessagingConversation?
    private let sendGranted: Bool
    private var generation: UInt64 = 0

    public init(conversationID: Int, conversation: MessagingConversation? = nil,
                reader: any MessagingReading, sendGranted: Bool = false) {
        self.reader = reader
        self.conversationID = conversationID
        self.conversation = conversation
        self.sendGranted = sendGranted
        page = Self.gate(conversationID: conversationID, conversation: conversation, reader: reader)
    }

    public func reload() async {
        generation &+= 1
        let ticket = generation
        let identity = reader.identity
        guard reader.isConfigured, identity != nil, conversationID > 0,
              conversation == nil || conversation?.id == conversationID else {
            page = Self.closed
            return
        }
        let kind = conversation?.kind ?? .unknown
        let unread = conversation?.unread.map(IMChatCountFact.known) ?? .unknown
        page = IMChatSessionPage(phase: .loading, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: false)
        do {
            let loaded = try await reader.messagingMessages(conversationID: conversationID, cursor: 0)
            guard ticket == generation else { return }
            guard reader.isConfigured, reader.identity == identity else { page = Self.closed; return }
            page = IMChatSessionWire.fromReader(conversation: conversation, page: loaded, sendGranted: sendGranted)
        } catch is CancellationError {
            guard ticket == generation else { return }
            page = IMChatSessionPage(phase: .unknown, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: false)
        } catch {
            guard ticket == generation else { return }
            guard reader.isConfigured, reader.identity == identity else { page = Self.closed; return }
            page = IMChatSessionWire.failed(error, conversation: conversation)
        }
    }

    private static func gate(conversationID: Int, conversation: MessagingConversation?, reader: any MessagingReading) -> IMChatSessionPage {
        guard reader.isConfigured, reader.identity != nil, conversationID > 0,
              conversation == nil || conversation?.id == conversationID else { return closed }
        let kind = conversation?.kind ?? .unknown
        let unread = conversation?.unread.map(IMChatCountFact.known) ?? .unknown
        return IMChatSessionPage(phase: .loading, kind: kind, unread: unread, messageCount: .unknown, blocked: nil, sendGranted: false)
    }

    private static let closed = IMChatSessionPage(
        phase: .hidden, kind: .unknown, unread: .unknown, messageCount: .unknown, blocked: nil, sendGranted: false)
}

#if DEBUG
/// Synthetic chat bytes for DEBUG tests. No host, credential, or live route.
public enum IMChatSessionFixtureData {
    public static let directConversation = Data("""
    {"conversationId":901,"type":1,"unread":2,"counterparty":{"id":8001,"nickname":"Fixture peer"}}
    """.utf8)
    public static let zeroUnreadConversation = Data("""
    {"conversationId":901,"type":1,"unread":0}
    """.utf8)
    public static let unknownUnreadConversation = Data("""
    {"conversationId":901,"type":1,"unread":"UNKNOWN"}
    """.utf8)
    public static let stringZeroUnreadConversation = Data("""
    {"conversationId":901,"type":1,"unread":"0"}
    """.utf8)
    public static let systemConversation = Data("""
    {"conversationId":901,"type":2,"unread":0}
    """.utf8)
    public static let readyMessages = Data("""
    {"code":200,"data":{"list":[{"id":10,"conversationId":901,"status":0,"senderId":8001,"msgType":1,"content":"Synthetic received text","createTime":"2026-10-01 10:00:00"}],"hasMore":false,"blocked":false,"blockedByMe":false}}
    """.utf8)
    public static let emptyMessages = Data("""
    {"code":200,"data":{"list":[],"hasMore":false}}
    """.utf8)
    public static let missingListMessages = Data("""
    {"code":200,"data":{"hasMore":false}}
    """.utf8)
    public static let closedMessages = Data("""
    {"code":409,"errorCode":"HANGOUT_CLOSED","msg":"closed"}
    """.utf8)

    public static func messagingPage(_ envelope: Data) throws -> MessagingPage {
        guard let root = try JSONSerialization.jsonObject(with: envelope) as? [String: Any],
              let data = root["data"] else { throw APIError.malformedResponse }
        let bytes = try JSONSerialization.data(withJSONObject: data)
        return try JSONDecoder().decode(MessagingPage.self, from: bytes)
    }
}
#endif
