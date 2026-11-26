import SwiftUI

/// CLB-G13a (MP topic-detail index.wxml:212-236, director.js openGenericOps / inputGenericOps / confirmGenericOps,
/// utils/generic-director-ops.js): one 通用玩法 action in a half sheet. The fields come from `PlaySharedRunOps.fields`,
/// the footer says 时间为北京时间 and lists the manual ledger rows (MANUAL_* / STAFF_MANUAL_SIGN read `shared/export`
/// first, and fill the hashes or the next sequence), the toolbar is 取消 / 确认并提交, and the confirm alert copy is
/// MP `showDirectorModal` (此操作不可撤销 or 将按本局规则核验并应用本次操作。 + 原因). Submit goes through
/// `popupCloseActions.submitSharedRunAction` (`POST /api/game/session/command`).
struct ClubTopicGenericOpsSelection: Identifiable, Equatable {
    let action: String
    var id: String { action }
}

@MainActor struct ClubTopicGenericOpsSheet: View {
    let activityID: Int
    let action: String
    /// The `shared/control` snapshot the action row was offered from.
    let control: PlayWireValue
    let writeLocked: Bool
    let onSubmitted: () -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.playerGapService) private var service
    @Environment(\.popupCloseActions) private var actions
    @State private var draft: [String: String] = [:]
    @State private var failure: PlaySharedRunOps.Failure?
    @State private var notice: LocalizedStringKey?
    @State private var serverMessage: String?
    @State private var ledger: [PlaySharedRunOps.LedgerRow] = []
    @State private var pendingPayload: [String: PlayWireValue]?
    @State private var confirming = false
    @State private var busy = false

    private static let beijing = TimeZone(identifier: "Asia/Shanghai") ?? .current
    private var revision: Int? { control["revision"].integer }
    private var epoch: Int? { control["run"]["authorityEpoch"].integer }
    private var fields: [PlaySharedRunOps.Field] { PlaySharedRunOps.fields(action: action, draft: draft) }
    private var title: LocalizedStringKey { LocalizedStringKey("club.topic.genericOps.action." + action) }

    var body: some View {
        NavigationStack {
            form
                .navigationTitle(Text(title))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
        }
        .presentationDetents([.medium, .large])
        .task(id: action) { await readLedger() }
        .alert(confirmTitle, isPresented: $confirming, presenting: pendingPayload) { payload in
            Button("common.cancel", role: .cancel) {}
            Button("club.topic.genericOps.confirmSubmit") { Task { await submit(payload) } }
        } message: { payload in
            confirmMessage(payload)
        }
    }

    private var form: some View {
        Form {
            Section {
                ForEach(fields) { field in
                    fieldRow(field)
                }
            } footer: {
                footer
            }
        }
        .disabled(writeLocked || busy)
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("common.cancel") { dismiss() }
                .accessibilityIdentifier("club.topic.genericOps.cancel")
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("club.topic.genericOps.submit") { prepare() }
                .disabled(writeLocked || busy)
                .accessibilityIdentifier("club.topic.genericOps.submit")
        }
    }

    @ViewBuilder private var footer: some View {
        VStack(alignment: .leading, spacing: 4) {
            // MP wxml:215 时间为北京时间.
            Text("club.topic.genericOps.beijingTime")
            ForEach(ledger, id: \.self) { row in
                ledgerText(row).textSelection(.enabled)
            }
            if let failure { failureText(failure).foregroundStyle(.red) }
            if let serverMessage { Text(verbatim: serverMessage).foregroundStyle(.red) }
            if let notice { Text(notice).foregroundStyle(.red) }
        }
    }

    @ViewBuilder private func fieldRow(_ field: PlaySharedRunOps.Field) -> some View {
        if !field.options.isEmpty {
            Picker(selection: binding(field.key)) {
                Text("club.topic.genericOps.choose").tag("")
                ForEach(field.options, id: \.self) { option in
                    Text(Self.optionKey(field.key, option)).tag(option)
                }
            } label: {
                Text(Self.fieldKey(field.key))
            }
            .accessibilityIdentifier("club.topic.genericOps.field." + field.key)
        } else if field.boolean {
            Toggle(isOn: boolBinding(field.key)) { Text(Self.fieldKey(field.key)) }
                .accessibilityIdentifier("club.topic.genericOps.field." + field.key)
        } else if field.timestamp {
            DatePicker(selection: dateBinding(field.key), displayedComponents: [.date, .hourAndMinute]) {
                Text(Self.fieldKey(field.key))
            }
            .environment(\.timeZone, Self.beijing)
            .accessibilityIdentifier("club.topic.genericOps.field." + field.key)
        } else {
            TextField(text: limitedBinding(field.key, max: field.maxLength), axis: field.multiline ? .vertical : .horizontal) {
                Text(Self.fieldKey(field.key))
            }
            .lineLimit(field.multiline ? 3 : 1, reservesSpace: false)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .accessibilityIdentifier("club.topic.genericOps.field." + field.key)
        }
    }

    // MARK: bindings

    private func binding(_ key: String) -> Binding<String> {
        Binding(get: { draft[key] ?? "" }, set: { draft[key] = $0; failure = nil; notice = nil; serverMessage = nil })
    }

    private func limitedBinding(_ key: String, max: Int) -> Binding<String> {
        Binding(get: { draft[key] ?? "" }, set: { draft[key] = String($0.prefix(max)); failure = nil; notice = nil; serverMessage = nil })
    }

    private func boolBinding(_ key: String) -> Binding<Bool> {
        Binding(get: { draft[key] == "true" }, set: { draft[key] = $0 ? "true" : ""; failure = nil })
    }

    /// MP `toTimestamp`: the draft keeps epoch milliseconds; an empty draft shows now and stays empty until changed.
    private func dateBinding(_ key: String) -> Binding<Date> {
        Binding(get: {
            guard let ms = Int(draft[key] ?? "") else { return Date() }
            return Date(timeIntervalSince1970: TimeInterval(ms) / 1000)
        }, set: { draft[key] = String(Int(($0.timeIntervalSince1970 * 1000).rounded())); failure = nil })
    }

    // MARK: labels

    static func fieldKey(_ key: String) -> LocalizedStringKey { LocalizedStringKey("club.topic.genericOps.field." + key) }

    static func optionKey(_ field: String, _ option: String) -> LocalizedStringKey {
        field == "reviewKind" ? LocalizedStringKey("club.topic.genericOps.review." + option)
            : LocalizedStringKey("club.topic.genericOps.action." + option)
    }

    private func failureText(_ failure: PlaySharedRunOps.Failure) -> Text {
        switch failure {
        case .confirm(let key): return Text("club.topic.genericOps.error.confirm") + Text(Self.fieldKey(key))
        case .notOffered: return Text("club.topic.genericOps.error.notOffered")
        case .nonce: return Text("club.topic.genericOps.error.nonce")
        case .target: return Text("club.topic.genericOps.error.target")
        case .signedAction: return Text("club.topic.genericOps.error.signedAction")
        case .originalPair: return Text("club.topic.genericOps.error.originalPair")
        case .anchorStale: return Text("club.topic.genericOps.error.anchorStale")
        case .hashes: return Text("club.topic.genericOps.error.hashes")
        case .unknownFormat: return Text("club.topic.genericOps.error.unknownFormat")
        case .unknownItems: return Text("club.topic.genericOps.error.unknownItems")
        case .anchorFirst: return Text("club.topic.genericOps.error.anchorFirst")
        case .reviewKind: return Text("club.topic.genericOps.error.reviewKind")
        }
    }

    /// MP director.js openGenericOps ledger lines.
    private func ledgerText(_ row: PlaySharedRunOps.LedgerRow) -> Text {
        switch row {
        case let .signature(id, sequence, action, used):
            let state = used ? Text("club.topic.genericOps.ledger.used") : Text("club.topic.genericOps.ledger.pending")
            return Text("club.topic.genericOps.ledger.signature \(id) \(sequence.map(String.init) ?? "—") \(action)") + Text(verbatim: " · ") + state
        case let .request(memberID, requestID, outcome):
            return Text("club.topic.genericOps.ledger.request \(memberID.map(String.init) ?? "—") \(requestID) \(outcome)")
        }
    }

    private var confirmTitle: Text { Text("club.topic.genericOps.confirmTitle") + Text(title) }

    private func confirmMessage(_ payload: [String: PlayWireValue]) -> Text {
        let lead = PlaySharedRunOps.isIrreversible(action) ? Text("club.topic.genericOps.irreversible") : Text("club.topic.genericOps.applyNotice")
        if let reason = payload["reason"]?.text { return lead + Text("club.topic.genericOps.reasonPrefix \(reason)") }
        return lead + Text("club.topic.genericOps.checkInput")
    }

    // MARK: actions

    /// MP openGenericOps: the MANUAL_* / STAFF_MANUAL_SIGN forms read `shared/export` for the same revision and epoch.
    private func readLedger() async {
        guard PlaySharedRunOps.ledgerActions.contains(action), let service else { return }
        guard case .ready(let snapshot) = await service.sharedExport(activityID: activityID) else {
            notice = "club.topic.genericOps.ledgerFailed"; return
        }
        guard snapshot["revision"].integer == revision, snapshot["authorityEpoch"].integer == epoch else {
            notice = "club.topic.genericOps.versionChanged"; return
        }
        if action == "MANUAL_BEGIN" {
            draft["highWaterHash"] = snapshot["highWaterHash"].text
            draft["configHash"] = snapshot["configHash"].text
        }
        if action == "STAFF_MANUAL_SIGN", let next = snapshot["manual"]["nextSequence"].integer { draft["sequence"] = String(next) }
        ledger = PlaySharedRunOps.ledgerRows(snapshot)
    }

    private func prepare() {
        guard !writeLocked, !busy else { return }
        do {
            pendingPayload = try PlaySharedRunOps.payload(action: action, draft: draft, control: control)
            failure = nil
            confirming = true
        } catch let error as PlaySharedRunOps.Failure {
            failure = error
        } catch {
            failure = .notOffered
        }
    }

    /// MP confirmGenericOps success: the revision, epoch and offer must be unchanged, then `executeAction`.
    private func submit(_ payload: [String: PlayWireValue]) async {
        guard !writeLocked, !busy, let revision, let send = actions.submitSharedRunAction, let service else {
            notice = "club.topic.genericOps.unavailable"; return
        }
        busy = true
        defer { busy = false }
        guard case .ready(let fresh) = await service.sharedControl(activityID: activityID),
              fresh["revision"].integer == revision, fresh["run"]["authorityEpoch"].integer == epoch,
              PlaySharedRunOps.offered(fresh).contains(action) else {
            notice = "club.topic.genericOps.versionChanged"; return
        }
        switch await send(activityID, revision, action, payload) {
        case .success:
            onSubmitted()
            dismiss()
        case .failure(let error):
            if case PlayExperienceError.rejected(_, let message) = error, let message, !message.isEmpty {
                serverMessage = message
            } else {
                notice = "club.topic.genericOps.failed"
            }
        }
    }
}
