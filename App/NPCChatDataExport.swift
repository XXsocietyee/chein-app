import SwiftUI
import UIKit

/// Settings 「AI 对话记录」 → 导出对话记录 (mini-program `chat-export.formatReadable`): the loaded records,
/// copied as readable text (title, count, retention note, then each exchange). Copies only what this
/// reader already shows; it adds no request. Hidden while nothing is loaded or there are no records.
@MainActor struct NPCChatDataExportButton: View {
    let data: NPCChatData?
    @Environment(\.locale) private var locale
    @State private var copied = 0
    var body: some View {
        if let data, !data.records.isEmpty {
            Button {
                LocalPasteboard.copy(Self.readable(data, locale: locale))
                copied &+= 1
            } label: { Label("mpd.aiChat.export", systemImage: "doc.on.doc") }
            .sensoryFeedback(.success, trigger: copied)
            .accessibilityLabel(Text("mpd.aiChat.export"))
            .accessibilityValue(Text("mpd.aiChat.exportCount \(data.records.count)"))
            .accessibilityHint(Text("mpd.aiChat.exportHint"))
            .accessibilityIdentifier("npcData.export")
        }
    }
    static func readable(_ data: NPCChatData, locale: Locale) -> String {
        func t(_ key: String.LocalizationValue) -> String { String(localized: LocalizedStringResource(key, locale: locale)) }
        var head = [t("mpd.aiChat.exportTitle"), String(format: t("mpd.aiChat.exportCount %lld"), data.records.count)]
        if let policy = data.retentionPolicy, !policy.isEmpty { head.append(String(format: t("mpd.aiChat.exportRetention %@"), policy)) }
        let body = data.records.map { record in
            let ask = (record.userMessage ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let reply = (record.npcReply ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return ["[" + (record.sourceTime ?? "—") + "]",
                    String(format: t("mpd.aiChat.exportMe %@"), ask.isEmpty ? t("mpd.aiChat.exportNoContent") : ask),
                    String(format: t("mpd.aiChat.exportAI %@"), reply.isEmpty ? t("mpd.aiChat.exportNoReply") : reply)].joined(separator: "\n")
        }
        return head.joined(separator: "\n") + "\n\n" + body.joined(separator: "\n\n")
    }
}
