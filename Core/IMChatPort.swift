import Foundation

/// im/chat parity helpers over primitive values (no dependency on view or transport types).
public enum IMChatPort {
    /// Mini `onSend`: surrounding whitespace is trimmed and an empty message is never sent.
    public static func sendableText(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// A send is only confirmed when the server returns a positive integer message id; anything
    /// else (including a bare "success" without an id) keeps the local bubble in the failed state.
    public static func isConfirmedServerID(_ raw: String?) -> Bool {
        guard let raw, !raw.isEmpty, raw.first != "0", raw.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = Int64(raw), value > 0 else { return false }
        return true
    }

    /// Mini `cardTarget`: a card is tappable only when it has a real destination
    /// (action link, an official review result on a system message, or a broadcast id).
    public static func cardIsTappable(hasAction: Bool, hasResult: Bool, senderID: Int, hasBroadcastID: Bool) -> Bool {
        hasAction || (hasResult && senderID == 0) || hasBroadcastID
    }

    /// Generic cards without a title fall back to the message content, then to 通知.
    public static func genericCardTitle(title: String?, content: String?) -> String {
        for candidate in [title, content] {
            let value = (candidate ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty { return value }
        }
        return "通知"
    }

    /// Time divider before a message when there is no previous message or the gap exceeds five minutes.
    public static func needsDivider(previous: Date?, current: Date) -> Bool {
        guard let previous else { return true }
        return current.timeIntervalSince(previous) > 5 * 60
    }

    /// Poll results only add messages newer than the highest numeric id already shown.
    public static func freshIDs(polled: [Int], knownMax: Int) -> [Int] { polled.filter { $0 > knownMax } }

    public struct Entry: Equatable {
        public let id: String
        public let clientMessageID: String?
        public let senderID: Int
        public init(id: String, clientMessageID: String?, senderID: Int) {
            self.id = id; self.clientMessageID = clientMessageID; self.senderID = senderID
        }
    }

    /// Mini `_mergeMessages`: an incoming message replaces an existing one with the same id or the same
    /// (clientMessageId, sender) pair, otherwise it is appended. Prepending (history) never replaces.
    public static func merge(existing: [Entry], incoming: [Entry], prepend: Bool = false) -> [Entry] {
        var list = prepend ? incoming : existing
        let additions = prepend ? existing : incoming
        for message in additions {
            let index = list.firstIndex { $0.id == message.id
                || (message.clientMessageID != nil && $0.clientMessageID == message.clientMessageID && $0.senderID == message.senderID) }
            if let index { if !prepend { list[index] = message } } else { list.append(message) }
        }
        return list
    }
}
