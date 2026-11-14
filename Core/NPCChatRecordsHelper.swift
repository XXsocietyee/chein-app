import Foundation

/// Options presented in the AI chat records option sheet (`AI 对话记录`).
public enum NPCChatRecordsOption: String, CaseIterable, Identifiable {
    case view
    case export
    case clear

    public var id: String { rawValue }
}

/// Formats exported `NPCChatData` records for clipboard sharing without mutating server state.
public enum NPCChatDataExportFormatter {
    private static let maxExportBytes = 2_097_152

    /// Produces a readable transcript of the user's own NPC chat records, bounded in byte size.
    public static func formatTranscript(from data: NPCChatData) -> String {
        guard !data.records.isEmpty else { return "" }
        var lines: [String] = []
        lines.reserveCapacity(data.records.count)
        for record in data.records {
            let timestamp = record.sourceTime ?? "-"
            let prompt = record.userMessage ?? ""
            let reply = record.npcReply ?? ""
            lines.append("[\(timestamp)] #\(record.id)\nQ: \(prompt)\nA: \(reply)")
        }
        let joined = lines.joined(separator: "\n\n")
        if joined.utf8.count <= maxExportBytes { return joined }
        return String(decoding: Data(joined.utf8.prefix(maxExportBytes)), as: UTF8.self)
    }
}

/// Decision when dismissing a deep-linked scene sheet (`scene-deep-link`).
public enum DeepLinkSceneExitDecision: Equatable {
    case closeImmediately
    case confirmDiscard(DeepLinkSceneDiscardPrompt)
}

/// Confirmation copy for closing a deep-linked scene with unsaved changes.
public struct DeepLinkSceneDiscardPrompt: Equatable {
    public let title: String
    public let message: String
    public let confirmTitle: String
    public let cancelTitle: String

    public init(
        title: String = "放弃当前修改？",
        message: String = "当前内容还没有保存，关闭后会丢失。",
        confirmTitle: String = "放弃并关闭",
        cancelTitle: String = "继续编辑"
    ) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
    }
}

/// Pure policy evaluating whether closing a deep-linked container needs discard confirmation.
public enum DeepLinkSceneExitPolicy {
    public static func evaluate(isDirty: Bool) -> DeepLinkSceneExitDecision {
        isDirty ? .confirmDiscard(.init()) : .closeImmediately
    }
}
