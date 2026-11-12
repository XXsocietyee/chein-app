import Foundation

/// Send states and the failed-resend path from `subpackageB/pages/im/chat/index.js`
/// (`_sendMessage`, `onResend`, `_readReceipt`, `recoverPending`, `_mergeMessages`).
/// A failed or uncertain send is never posted again by itself.
/// Recovery is `POST api/im/send-receipt`. A second `POST api/im/send` happens
/// only when the user retries and that receipt says `found === false`.
public enum IMSendReceiptMerge {
    public static let receiptPath = "api/im/send-receipt"
    public static let sendPath = "api/im/send"
    public static let cardContent = "[卡片]"

    public static func receiptFields(conversation: String, clientMessageID: String) -> [String: String] {
        ["conversation_id": conversation, "client_message_id": clientMessageID]
    }

    public static func positiveServerID(_ raw: String) -> Bool {
        guard let first = raw.utf8.first, first != 48, raw.utf8.allSatisfy({ (48...57).contains($0) }) else { return false }
        guard raw.count <= 16, let value = Int(raw), value > 0, value <= 9_007_199_254_740_991 else { return false }
        return String(value) == raw
    }
}

public struct IMOutgoingPayload: Equatable {
    public enum Kind: Equatable {
        case text(String)
        case card(String)
    }

    public let clientMessageID: String
    public let kind: Kind

    public init(clientMessageID: String, kind: Kind) {
        self.clientMessageID = clientMessageID
        self.kind = kind
    }

    public var messageType: Int {
        switch kind {
        case .text: return 1
        case .card: return 3
        }
    }

    /// Card content is rebuilt by the server. The local placeholder is not authority.
    public var content: String {
        switch kind {
        case .text(let text): return text
        case .card: return IMSendReceiptMerge.cardContent
        }
    }

    public var extraJSON: String? {
        if case .card(let json) = kind { return json }
        return nil
    }
}

public enum IMLocalSendState: Equatable {
    case sending
    case failed
}

public struct IMLocalSend: Equatable {
    public let temporaryID: String
    public let payload: IMOutgoingPayload
    public var state: IMLocalSendState

    public init(temporaryID: String, payload: IMOutgoingPayload, state: IMLocalSendState) {
        self.temporaryID = temporaryID
        self.payload = payload
        self.state = state
    }
}

public enum IMReceiptAnswer: Equatable {
    /// `found === true` with a positive id, the same owner, and the same client id.
    case found(serverID: String, senderID: String, clientMessageID: String)
    /// `found === false`. This is the only answer that may authorize another send, and only on an explicit retry.
    case notFound
    /// Transport loss, a non-200 envelope, or `found === true` that does not match. Not a miss.
    case unconfirmed
}

public enum IMReceiptNext: Equatable {
    /// Replace the optimistic row with the server message. Do not send.
    case merge(serverID: String)
    /// Explicit retry after a real miss. Same client id, same payload.
    case sendOriginal(IMOutgoingPayload)
    /// Stay where you are. Do not send.
    case hold
}

/// One conversation's optimistic sends plus the receipt ledger.
public struct IMSendTranscript: Equatable {
    public private(set) var ledger = IMSendRecoveryLedger()
    public private(set) var locals: [IMLocalSend] = []
    public private(set) var sendCount = 0

    public init() {}

    /// Source `invalidate`. Outstanding receipt handles stop being current, so their callbacks cannot send.
    public mutating func invalidate() { ledger.invalidate() }

    /// First send. Stores the id, then counts one `POST api/im/send`. A second start for the same id does nothing.
    public mutating func start(owner: String, conversation: String, payload: IMOutgoingPayload) -> IMSendRecoveryLedger.Receipt? {
        guard !locals.contains(where: { $0.payload.clientMessageID == payload.clientMessageID }) else { return nil }
        guard let receipt = ledger.begin(owner: owner, conversation: conversation, id: payload.clientMessageID) else { return nil }
        locals.append(IMLocalSend(temporaryID: "tmp_\(payload.clientMessageID)", payload: payload, state: .sending))
        sendCount += 1
        return receipt
    }

    /// The send call returned. Success completes the ledger. Anything else is `.failed` and does not send again.
    public mutating func finish(receipt: IMSendRecoveryLedger.Receipt, accepted: Bool, serverID: String?) {
        guard ledger.current(receipt), let index = locals.firstIndex(where: { $0.payload.clientMessageID == receipt.id }) else { return }
        if accepted, let serverID, IMSendReceiptMerge.positiveServerID(serverID) {
            _ = ledger.complete(receipt)
            locals.remove(at: index)
            return
        }
        locals[index].state = .failed
    }

    /// `recoverPending`. Queries the receipt. A miss or an uncertain answer does not send.
    public mutating func recover(receipt: IMSendRecoveryLedger.Receipt, answer: IMReceiptAnswer) -> IMReceiptNext {
        apply(receipt: receipt, answer: answer, explicitRetry: false)
    }

    /// `onResend`. The receipt is read first. The original payload is sent only for `found === false`.
    public mutating func retry(receipt: IMSendRecoveryLedger.Receipt, answer: IMReceiptAnswer) -> IMReceiptNext {
        apply(receipt: receipt, answer: answer, explicitRetry: true)
    }

    /// The receipt handle a failed row may query. Nil unless that row is failed and still pending.
    public func resendReceipt(owner: String, conversation: String, temporaryID: String) -> IMSendRecoveryLedger.Receipt? {
        guard let row = locals.first(where: { $0.temporaryID == temporaryID }), row.state == .failed else { return nil }
        return ledger.pending(owner: owner, conversation: conversation).first { $0.id == row.payload.clientMessageID }
    }

    private mutating func apply(receipt: IMSendRecoveryLedger.Receipt, answer: IMReceiptAnswer, explicitRetry: Bool) -> IMReceiptNext {
        guard ledger.current(receipt) else { return .hold }
        switch answer {
        case .found(let serverID, let sender, let clientID):
            guard sender == receipt.owner, clientID == receipt.id, IMSendReceiptMerge.positiveServerID(serverID) else { return .hold }
            _ = ledger.complete(receipt)
            locals.removeAll { $0.payload.clientMessageID == receipt.id }
            return .merge(serverID: serverID)
        case .notFound:
            guard explicitRetry, let index = locals.firstIndex(where: { $0.payload.clientMessageID == receipt.id && $0.state == .failed }) else {
                return .hold
            }
            let payload = locals[index].payload
            locals[index].state = .sending
            sendCount += 1
            return .sendOriginal(payload)
        case .unconfirmed:
            return .hold
        }
    }
}

/// `_mergeMessages`. A later copy with the same id, or the same client id and sender, replaces the row.
/// History (`prepend`) never replaces a row already on screen.
public struct IMMergeRow: Equatable {
    public let id: String
    public let clientMessageID: String?
    public let senderID: String

    public init(id: String, clientMessageID: String?, senderID: String) {
        self.id = id
        self.clientMessageID = clientMessageID
        self.senderID = senderID
    }
}

public enum IMMessageMerge {
    public static func merge(existing: [IMMergeRow], incoming: [IMMergeRow], prepend: Bool) -> [IMMergeRow] {
        var list = prepend ? incoming : existing
        let additions = prepend ? existing : incoming
        for message in additions {
            if let index = list.firstIndex(where: { row in
                row.id == message.id || (message.clientMessageID != nil && row.clientMessageID == message.clientMessageID && row.senderID == message.senderID)
            }) {
                if !prepend { list[index] = message }
            } else {
                list.append(message)
            }
        }
        return list
    }
}

/// `_readReceipt`: automatic recovery and an explicit retry share one in-flight query.
/// The same purpose keeps a single consumer. A late callback does not clear the flight that replaced it.
public struct IMReceiptQueryShare: Equatable {
    public enum Purpose: String, Equatable, Hashable { case recover, retry }
    public enum Join: Equatable { case start(token: Int), attach(token: Int) }

    public struct Delivery: Equatable {
        public let purposes: Set<Purpose>
        /// Source shows the unconfirmed tip only when a retry consumer is waiting.
        public let unconfirmedTip: Bool
        public init(purposes: Set<Purpose>, unconfirmedTip: Bool) {
            self.purposes = purposes
            self.unconfirmedTip = unconfirmedTip
        }
    }

    private var flights: [String: (token: Int, purposes: Set<Purpose>)] = [:]
    private var nextToken = 0

    public init() {}

    public mutating func join(key: String, purpose: Purpose, flightStillCurrent: Bool) -> Join {
        if flightStillCurrent, var flight = flights[key] {
            flight.purposes.insert(purpose)
            flights[key] = flight
            return .attach(token: flight.token)
        }
        nextToken += 1
        flights[key] = (nextToken, [purpose])
        return .start(token: nextToken)
    }

    /// `found === false` or a valid `found === true` delivers to every consumer.
    /// Anything else delivers to nobody and tips only a retry consumer.
    public mutating func finish(key: String, token: Int, foundFalse: Bool, foundValid: Bool) -> Delivery? {
        guard let flight = flights[key], flight.token == token else { return nil }
        flights[key] = nil
        if foundFalse || foundValid {
            return Delivery(purposes: flight.purposes, unconfirmedTip: false)
        }
        return Delivery(purposes: [], unconfirmedTip: flight.purposes.contains(.retry))
    }
}
