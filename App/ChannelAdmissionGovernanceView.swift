import SwiftUI

/// Normal entry for the original admission routes. Appearance does not send.
/// Each action keeps its own request id, and recovery uses that same id.
@MainActor struct ChannelAdmissionGovernanceView: View {
    let client: ChannelAdmissionGovernanceClient
    let catalog: ChannelCatalogEntry?
    let kind: Int
    let spaceID: Int64
    @State private var reason = ""
    @State private var note = ""
    @State private var inviteID = ""
    @State private var applicationID = ""
    @State private var reasonCode = "1"
    @State private var submitID: String?
    @State private var cancelID: String?
    @State private var approveID: String?
    @State private var rejectID: String?
    @State private var leaveID: String?
    @State private var pauseOnID: String?
    @State private var pauseOffID: String?
    @State private var lastPauseID: String?
    @State private var revokeID: String?
    @State private var sending = false
    @State private var message = ""
    @Environment(\.locale) private var locale

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(verbatim: String(spaceID))
                        .monospacedDigit()
                } label: {
                    Text("admission.space")
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("admission.space"))
                .accessibilityValue(Text(verbatim: String(spaceID)))
                field("admission.reason", text: $reason)
                field("admission.note", text: $note)
                field("admission.invite", text: $inviteID)
                field("admission.application", text: $applicationID)
                field("admission.reasonCode", text: $reasonCode)
            }

            Section {
                Button { Task { await submit() } } label: {
                    Label("admission.submit", systemImage: "paperplane.fill")
                }
                .disabled(catalog == nil || sending)
                .accessibilityLabel(Text("admission.submit"))

                Menu {
                    Button("admission.cancel") { Task { await cancel() } }
                    Button("admission.approve") { Task { await approve() } }
                    Button("admission.reject") { Task { await reject() } }
                    Button("admission.leave") { Task { await leave() } }
                    Button("admission.pause") { Task { await pause(true) } }
                    Button("admission.unpause") { Task { await pause(false) } }
                    Button("admission.revokeInvite") { Task { await revoke() } }
                    Divider()
                    recoverButton("admission.recoverSubmit", submitID)
                    recoverButton("admission.recoverCancel", cancelID)
                    recoverButton("admission.recoverApprove", approveID)
                    recoverButton("admission.recoverReject", rejectID)
                    recoverButton("admission.recoverLeave", leaveID)
                    recoverButton("admission.recoverPause", lastPauseID)
                    recoverButton("admission.recoverInvite", revokeID)
                } label: {
                    Label(moreTitle, systemImage: "ellipsis.circle")
                }
                .disabled(sending)
                .accessibilityLabel(Text(verbatim: moreTitle))
            }

            Section {
                if sending {
                    ProgressView("admission.sending")
                        .accessibilityLabel(Text("admission.sending"))
                }
                if !message.isEmpty {
                    Text(LocalizedStringKey(message))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                ForEach([submitID, cancelID, approveID, rejectID, leaveID, lastPauseID, revokeID].compactMap { $0 }, id: \.self) { id in
                    Text(verbatim: shownID(id))
                        .font(.footnote)
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .themeDomain(.player)
        .navigationTitle(Text("admission.title"))
        .navigationBarTitleDisplayMode(.inline)
        .privacySensitive()
    }

    /// Menu title. Catalog key `ui.cloud05.admission.more` (docs/release/ui-strings-cloud-05.json).
    private var moreTitle: String {
        let key = "ui.cloud05.admission.more"
        let resolved = String(localized: String.LocalizationValue(stringLiteral: key))
        if resolved == key || resolved.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return CYKitCopy(locale: locale)("More actions", "更多操作")
        }
        return resolved
    }

    private func field(_ key: LocalizedStringKey, text: Binding<String>) -> some View {
        TextField(key, text: text)
    }

    private func recoverButton(_ title: LocalizedStringKey, _ requestID: String?) -> some View {
        Button(title) { Task { await recover(requestID) } }
            .disabled(requestID == nil)
    }

    private func shownID(_ id: String) -> String {
        if id.range(of: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#, options: .regularExpression) != nil { return "—" }
        return id
    }

    private func submit() async {
        guard let catalog else { message = "admission.invalid"; return }
        let id = remember(submitID) { submitID = $0 }
        await run(id) {
            _ = try await client.submit(catalog: catalog, kind: kind, spaceID: spaceID, inviteID: parsed(inviteID), message: note, requestID: id)
            message = "admission.submitted"
        }
    }

    private func cancel() async {
        guard let application = parsed(applicationID) else { message = "admission.invalid"; return }
        let id = remember(cancelID) { cancelID = $0 }
        await run(id) {
            _ = try await client.cancel(applicationID: application, requestID: id)
            message = "admission.cancelled"
        }
    }

    private func approve() async {
        guard let application = parsed(applicationID) else { message = "admission.invalid"; return }
        let id = remember(approveID) { approveID = $0 }
        await run(id) {
            _ = try await client.approve(applicationID: application, note: note, requestID: id)
            message = "admission.approved"
        }
    }

    private func reject() async {
        guard let application = parsed(applicationID), let code = Int(reasonCode), [1, 2, 3, 4, 5, 9].contains(code) else {
            message = "admission.invalid"
            return
        }
        let id = remember(rejectID) { rejectID = $0 }
        await run(id) {
            _ = try await client.reject(applicationID: application, reasonCode: code, note: note, requestID: id)
            message = "admission.rejected"
        }
    }

    private func leave() async {
        let id = remember(leaveID) { leaveID = $0 }
        await run(id) {
            _ = try await client.leave(kind: kind, spaceID: spaceID, requestID: id)
            message = "admission.left"
        }
    }

    private func pause(_ paused: Bool) async {
        let id = (paused ? pauseOnID : pauseOffID) ?? Self.freshRequestID()
        if paused { pauseOnID = id } else { pauseOffID = id }
        lastPauseID = id
        await run(id) {
            let sent = try await client.pause(kind: kind, spaceID: spaceID, paused: paused, until: nil, reason: reason, requestID: id)
            message = (sent["join_paused"] as? Bool) == paused ? "admission.paused" : "admission.unknown"
        }
    }

    private func revoke() async {
        guard let invite = parsed(inviteID) else { message = "admission.invalid"; return }
        let id = remember(revokeID) { revokeID = $0 }
        await run(id) {
            _ = try await client.revokeInvite(inviteID: invite, reason: reason, requestID: id)
            message = "admission.revoked"
        }
    }

    private func recover(_ requestID: String?) async {
        guard let requestID else { return }
        sending = true
        defer { sending = false }
        do {
            let row = try await client.recover(requestID: requestID)
            message = Self.displayMessage(row["state"] as? String ?? "admission.recovered")
        } catch {
            message = "admission.unknown"
        }
    }

    /// A server state that is not a catalogued admission key must not render as a dotted key.
    private static func displayMessage(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "admission.unknown" }
        let known = [
            "admission.invalid", "admission.submitted", "admission.cancelled", "admission.approved",
            "admission.rejected", "admission.left", "admission.paused", "admission.unknown",
            "admission.revoked", "admission.recovered"
        ]
        if known.contains(trimmed) { return trimmed }
        if trimmed.range(of: #"^[A-Za-z][A-Za-z0-9_]*(\.[A-Za-z0-9_]+)+$"#, options: .regularExpression) != nil {
            return "admission.unknown"
        }
        return trimmed
    }

    private func remember(_ current: String?, store: (String) -> Void) -> String {
        let id = current ?? Self.freshRequestID()
        store(id)
        return id
    }

    private func run(_ requestID: String, _ body: () async throws -> Void) async {
        _ = requestID
        sending = true
        defer { sending = false }
        do { try await body() } catch { message = "admission.unknown" }
    }

    private func parsed(_ raw: String) -> Int64? {
        guard let value = Int64(raw), value > 0 else { return nil }
        return value
    }

    private static func freshRequestID() -> String {
        "adm-" + UUID().uuidString.lowercased()
    }
}
