import SwiftUI

/// Club channel tools for the IM paths that the session factories cannot issue as exact routes.
/// A row shows the server payload, or the server error. It never marks a write applied on its own.
struct BeGapImDesk: View {
    let clubID: Int64
    let session: AppSession

    var body: some View {
        BeGapImDeskList(clubID: clubID, session: session)
            .navigationTitle("beGapIm.title")
            .navigationBarTitleDisplayMode(.inline)
    }
}

private struct BeGapImDeskList: View {
    let clubID: Int64
    let session: AppSession
    @State private var channel = ""
    @State private var message = ""
    @State private var record = ""
    @State private var board = ""

    var body: some View {
        List {
            BeGapImFields(channel: $channel, message: $message, record: $record, board: $board)
            BeGapImReads(clubID: clubID, session: session, channel: channel, message: message, record: record, board: board)
            BeGapImWrites(clubID: clubID, session: session, channel: channel, record: record, board: board)
        }
    }
}

private struct BeGapImFields: View {
    @Binding var channel: String
    @Binding var message: String
    @Binding var record: String
    @Binding var board: String

    var body: some View {
        Section {
            field(title: "beGapIm.channel", hint: "curA11y.beGapIm.channel.hint", text: $channel, identifier: "beGapIm.channel")
            field(title: "beGapIm.message", hint: "curA11y.beGapIm.message.hint", text: $message, identifier: "beGapIm.message")
            field(title: "beGapIm.record", hint: "curA11y.beGapIm.record.hint", text: $record, identifier: "beGapIm.record")
            field(title: "beGapIm.boardKey", hint: "curA11y.beGapIm.board.hint", text: $board, identifier: "beGapIm.board")
        } header: {
            Text("beGapIm.title")
                .accessibilityAddTraits(.isHeader)
        }
    }

    private func field(title: LocalizedStringKey, hint: LocalizedStringKey, text: Binding<String>, identifier: String) -> some View {
        CurA11yField(title: Text(title), hint: Text(hint, tableName: "CurA11y"), text: text, identifier: identifier)
            .textInputAutocapitalization(.never)
    }
}

private struct BeGapImReads: View {
    let clubID: Int64
    let session: AppSession
    let channel: String
    let message: String
    let record: String
    let board: String
    @State private var text = ""

    var body: some View {
        Section {
            read("beGapIm.audit", "beGapIm.audit") { await BeGapImCall.audit(session: session, clubID: clubID) }
            read("beGapIm.webhook", "beGapIm.webhook") { await BeGapImCall.webhookContext(session: session, clubID: clubID, channel: channel) }
            read("beGapIm.channels", "beGapIm.channels") { await BeGapImCall.channels(session: session, clubID: clubID) }
            read("beGapIm.chain", "beGapIm.chain") { await BeGapImCall.chain(session: session, channel: channel) }
            read("beGapIm.checkin", "beGapIm.checkin") { await BeGapImCall.checkin(session: session, channel: channel) }
            read("beGapIm.moderation", "beGapIm.moderation") { await BeGapImCall.moderation(session: session, clubID: clubID) }
            read("beGapIm.roles", "beGapIm.roles") { await BeGapImCall.roles(session: session, clubID: clubID) }
            read("beGapIm.media", "beGapIm.media") { await BeGapImCall.media(session: session, message: message) }
            read("beGapIm.board", "beGapIm.board") { await BeGapImCall.board(session: session, channel: channel, key: board) }
            read("beGapIm.receipts", "beGapIm.receipts") { await BeGapImCall.receipts(session: session, record: record) }
            if !text.isEmpty {
                CurA11yDashText(shown: text, font: CYTypography.meta, color: CYColor.textSecondary)
                    .textSelection(.enabled)
                    .accessibilityHint(Text("curA11y.beGapIm.result.hint", tableName: "CurA11y"))
                    .accessibilityIdentifier("beGapIm.read.result")
            }
        }
    }

    private func read(_ title: LocalizedStringKey, _ identifier: String, action: @escaping () async -> String) -> some View {
        CurA11yTextButton(
            title: Text(title),
            hint: Text("curA11y.beGapIm.read.hint", tableName: "CurA11y"),
            identifier: identifier,
            action: { Task { text = await action() } }
        )
    }
}

private struct BeGapImWrites: View {
    let clubID: Int64
    let session: AppSession
    let channel: String
    let record: String
    let board: String
    @State private var text = ""

    var body: some View {
        Section {
            CurA11yTextButton(
                title: Text("beGapIm.webhook"),
                hint: Text("curA11y.beGapIm.write.hint", tableName: "CurA11y"),
                identifier: "beGapIm.webhook.write",
                action: { Task { text = await BeGapImCall.createWebhook(session: session, clubID: clubID, channel: channel) } }
            )
            CurA11yTextButton(
                title: Text("beGapIm.appeal"),
                hint: Text("curA11y.beGapIm.write.hint", tableName: "CurA11y"),
                identifier: "beGapIm.appeal.write",
                action: { Task { text = await BeGapImCall.appealEvidence(session: session, record: record, note: board) } }
            )
            CurA11yTextButton(
                title: Text("beGapIm.send"),
                hint: Text("curA11y.beGapIm.write.hint", tableName: "CurA11y"),
                identifier: "beGapIm.send",
                action: { Task { text = await BeGapImCall.withdrawAppeal(session: session, record: record, note: board) } }
            )
            if !text.isEmpty {
                CurA11yDashText(shown: text, font: CYTypography.meta, color: CYColor.textSecondary)
                    .textSelection(.enabled)
                    .accessibilityHint(Text("curA11y.beGapIm.result.hint", tableName: "CurA11y"))
                    .accessibilityIdentifier("beGapIm.write.result")
            }
        }
    }
}

@MainActor
enum BeGapImCall {
    static let unknown = "—"

    static func audit(session: AppSession, clubID: Int64) async -> String {
        await load(session: session, method: "GET", path: "api/im/audit-log", query: [
            URLQueryItem(name: "guild_kind", value: "1"),
            URLQueryItem(name: "guild_id", value: String(clubID)),
            URLQueryItem(name: "limit", value: "50"),
            URLQueryItem(name: "verify", value: "1")
        ])
    }

    static func webhookContext(session: AppSession, clubID: Int64, channel: String) async -> String {
        guard let channelID = positive(channel) else { return missing() }
        return await load(session: session, method: "GET", path: "api/im/webhook/context", query: [
            URLQueryItem(name: "owner_id", value: String(clubID)),
            URLQueryItem(name: "channel_id", value: channelID)
        ])
    }

    static func channels(session: AppSession, clubID: Int64) async -> String {
        await load(session: session, method: "GET", path: "api/channels", query: [
            URLQueryItem(name: "guild_kind", value: "1"),
            URLQueryItem(name: "guild_id", value: String(clubID))
        ])
    }

    static func chain(session: AppSession, channel: String) async -> String {
        guard let conversation = positive(channel) else { return missing() }
        return await load(session: session, method: "GET", path: "api/im/chain/info", query: [
            URLQueryItem(name: "conversation_id", value: conversation),
            URLQueryItem(name: "limit", value: "50")
        ])
    }

    static func checkin(session: AppSession, channel: String) async -> String {
        guard let channelID = positive(channel) else { return missing() }
        return await load(session: session, method: "GET", path: "api/im/channel/checkin-status", query: [
            URLQueryItem(name: "channel_id", value: channelID)
        ])
    }

    static func moderation(session: AppSession, clubID: Int64) async -> String {
        await load(session: session, method: "GET", path: "api/im/moderation/actions", query: [
            URLQueryItem(name: "guild_kind", value: "1"),
            URLQueryItem(name: "guild_id", value: String(clubID)),
            URLQueryItem(name: "limit", value: "50")
        ])
    }

    static func roles(session: AppSession, clubID: Int64) async -> String {
        await load(session: session, method: "GET", path: "api/im/roles", query: [
            URLQueryItem(name: "guild_kind", value: "1"),
            URLQueryItem(name: "guild_id", value: String(clubID)),
            URLQueryItem(name: "include_disabled", value: "true")
        ])
    }

    static func media(session: AppSession, message: String) async -> String {
        guard let messageID = positive(message) else { return missing() }
        let attachment = await load(session: session, method: "GET", path: "api/im/message/\(messageID)/attachment")
        let fileAuth = await load(session: session, method: "GET", path: "api/im/file/message/\(messageID)/authorization")
        let filePreview = await load(session: session, method: "GET", path: "api/im/file/message/\(messageID)/preview")
        let videoAuth = await load(session: session, method: "GET", path: "api/im/video/message/\(messageID)/authorization")
        let videoPreview = await load(session: session, method: "GET", path: "api/im/video/message/\(messageID)/preview")
        let voice = await load(session: session, method: "GET", path: "api/im/voice/message/\(messageID)")
        let voiceAuth = await load(session: session, method: "GET", path: "api/im/voice/message/\(messageID)/authorization")
        return [attachment, fileAuth, filePreview, videoAuth, videoPreview, voice, voiceAuth].joined(separator: "\n")
    }

    static func board(session: AppSession, channel: String, key: String) async -> String {
        guard let channelID = positive(channel), key.range(of: "^[a-z][a-z0-9_]{0,31}$", options: .regularExpression) != nil else { return missing() }
        let listed = await load(session: session, method: "GET", path: "api/channel/\(channelID)/board")
        let version = await load(session: session, method: "GET", path: "api/channel/\(channelID)/board/\(key)/version")
        return listed + "\n" + version
    }

    static func receipts(session: AppSession, record: String) async -> String {
        let trimmed = record.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return missing() }
        let notification = await load(session: session, method: "GET", path: "api/im/notification-requests/\(trimmed)")
        let admission = await load(session: session, method: "GET", path: "api/channel-platform/admission/requests/\(trimmed)")
        let moderation = await load(session: session, method: "GET", path: "api/channel-platform/governance/moderation/requests/\(trimmed)")
        let report = await load(session: session, method: "GET", path: "api/channel-platform/governance/reports/requests/\(trimmed)")
        let governance = await load(session: session, method: "GET", path: "api/channel-platform/governance/requests/\(trimmed)")
        let platform = await load(session: session, method: "GET", path: "api/channel-platform/requests/\(trimmed)")
        return [notification, admission, moderation, report, governance, platform].joined(separator: "\n")
    }

    static func createWebhook(session: AppSession, clubID: Int64, channel: String) async -> String {
        guard let channelID = positive(channel), let channelNumber = Int64(channelID) else { return missing() }
        return await load(session: session, method: "POST", path: "api/im/webhook/subscriptions", json: [
            "request_id": UUID().uuidString.lowercased(),
            "owner_type": "CLUB",
            "owner_id": clubID,
            "channel_id": channelNumber,
            "name": "俱乐部通知",
            "events": ["message" + ".created"],
            "url": "https://hooks.example.com/club"
        ])
    }

    static func appealEvidence(session: AppSession, record: String, note: String) async -> String {
        guard let appealID = positive(record), !note.isEmpty else { return missing() }
        return await load(session: session, method: "POST", path: "api/im/appeals/\(appealID)/evidence", json: [
            "request_id": UUID().uuidString.lowercased(),
            "evidence_json": ["text": note]
        ])
    }

    static func withdrawAppeal(session: AppSession, record: String, note: String) async -> String {
        guard let appealID = positive(record), !note.isEmpty else { return missing() }
        return await load(session: session, method: "POST", path: "api/im/appeals/\(appealID)/withdraw", json: [
            "request_id": UUID().uuidString.lowercased(),
            "reason": note
        ])
    }

    private static func positive(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let number = Int64(trimmed), number > 0, String(number) == trimmed else { return nil }
        return trimmed
    }

    private static func missing() -> String {
        phrase("beGapIm.failure")
    }

    private static func load(session: AppSession, method: String, path: String, query: [URLQueryItem] = [], json: [String: Any]? = nil) async -> String {
        guard let token = session.token, let base = session.regionalConfiguration?.apiConfiguration?.baseURL else {
            return phrase("beGapIm.notSignedIn")
        }
        guard var parts = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            return phrase("beGapIm.failure")
        }
        if !query.isEmpty { parts.queryItems = query }
        guard let url = parts.url else { return phrase("beGapIm.failure") }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let json {
            guard let body = try? JSONSerialization.data(withJSONObject: json) else { return phrase("beGapIm.failure") }
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        do {
            let sent = try await URLSessionTransport().send(request)
            return describe(data: sent.0, status: sent.1)
        } catch {
            return phrase("beGapIm.failure")
        }
    }

    private static func describe(data: Data, status: Int) -> String {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return phrase("beGapIm.failure")
        }
        let code = (object["code"] as? NSNumber)?.intValue ?? -1
        if (200..<300).contains(status), code == 200, let payload = object["data"], !(payload is NSNull) {
            return render(payload)
        }
        if let message = object["msg"] as? String, !message.isEmpty { return message }
        if let err = object["err"] as? String, !err.isEmpty { return err }
        if let codeName = object["errorCode"] as? String, !codeName.isEmpty { return codeName }
        return unknown
    }

    private static func render(_ value: Any) -> String {
        if value is NSNull { return unknown }
        if let text = value as? String { return text.isEmpty ? unknown : text }
        if let number = value as? NSNumber { return number.stringValue }
        if let list = value as? [Any] {
            if list.isEmpty { return unknown }
            return list.map { render($0) }.joined(separator: ", ")
        }
        if let object = value as? [String: Any] {
            let lines = object.keys.sorted().map { key -> String in
                guard let field = object[key] else { return "\(key): \(unknown)" }
                return "\(key): \(render(field))"
            }
            return lines.isEmpty ? unknown : lines.joined(separator: "\n")
        }
        return unknown
    }

    private static func phrase(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), locale: .current))
    }
}
