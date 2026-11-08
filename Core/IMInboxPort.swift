import Foundation

/// im/list parity helpers that the redacted-preview default does not cover. Nothing here changes
/// `IMConversationPreviewPolicy.defaultPolicy`; hosts opt in explicitly.
public enum IMInboxPort {
    /// Mini `fmtPreview`: type 2 is `[图片]`, type 3 falls back to `[系统卡片]` without text, others show the text.
    /// Recalled messages never expose their text.
    public static func typedPreview(messageType: Int?, text: String?, isRecalled: Bool = false) -> String {
        let trimmed = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if isRecalled { return IMConversationPreviewPolicy.redactedPlaceholderText }
        switch messageType {
        case 2?: return "[图片]"
        case 3?: return trimmed.isEmpty ? "[系统卡片]" : trimmed
        default: return trimmed
        }
    }

    public enum ReadAllOutcome: Equatable { case nothingToRead, allSucceeded, allFailed, partial(failed: Int) }

    /// Mini `onReadAll` result copy selection: success only when every conversation was acknowledged.
    public static func readAllOutcome(attempted: Int, failed: Int) -> ReadAllOutcome {
        if attempted <= 0 { return .nothingToRead }
        let f = min(max(failed, 0), attempted)
        if f == 0 { return .allSucceeded }
        return f == attempted ? .allFailed : .partial(failed: f)
    }

    /// Conversation ids a read-all must acknowledge: unread > 0 on rows that belong to a visible tab.
    public static func readAllTargets(_ rows: [(id: Int, unread: Int?, visible: Bool)]) -> [Int] {
        rows.filter { ($0.unread ?? 0) > 0 && $0.visible }.map(\.id)
    }
}
