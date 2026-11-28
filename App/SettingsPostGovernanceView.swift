import SwiftUI

/// Settings 「帖文处置与申诉」 (mini-program `pages/shezhi/components/post-governance`): my own post and
/// account dispositions with a plain-text appeal. Data and writes go through the existing
/// `SquareGovernanceCoordinator` (GET /api/v1/community/me/enforcements, POST /api/v1/community/appeals);
/// its capability gates stay as they are. No coordinator (no regional configuration) ⇒ entry hidden.
@MainActor struct SettingsPostGovernanceEntry: View {
    @ObservedObject var session: AppSession
    @State private var presented = false
    var body: some View {
        if let coordinator = session.squareGovernance() {
            SettingsEntrySection {
                Button { presented = true } label: {
                    Label { Text("mpd.postGov.title") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLcShieldAlert) }
                }
                .accessibilityIdentifier("settings-post-governance")
            }
            .cySheet(isPresented: $presented) {
                SettingsPostGovernanceSheet(coordinator: coordinator, access: session.squareGovernanceAccess())
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            }
        }
    }
}

/// One disposition as the mini-program `enforcementRows` shows it.
struct PostGovernanceRow: Identifiable, Equatable {
    enum State: String { case reversed, upheld, appealing, active, expired, unknown }
    let id: Int
    let typeKey: String
    let isPost: Bool
    let created: String
    let ends: String
    let state: State
    let decisionReason: String
    let canAppeal: Bool

    private static let knownTypes: Set<String> = ["LABEL", "DOWNRANK", "SEARCH_EXCLUDE", "INTERACTION_LIMIT", "HIDE_PENDING_REVIEW", "REMOVE",
        "WARNING", "POST_RATE_LIMIT", "COMMENT_TIMEOUT", "READ_ONLY", "TEMP_SUSPEND", "PERMANENT_BAN"]

    /// `stateOf(status, appealStatus)`.
    static func state(status: String, appealStatus: String) -> State {
        if status == "REVERSED" || appealStatus == "REVERSED" { return .reversed }
        if appealStatus == "UPHELD" { return .upheld }
        if appealStatus == "SUBMITTED" || appealStatus == "REVIEWING" { return .appealing }
        if status == "ACTIVE" { return .active }
        if status == "EXPIRED" { return .expired }
        return .unknown
    }
    /// `timeText`: ISO strings cut to minutes, epoch millis formatted; anything else empty.
    static func time(_ value: SquareGovernanceJSON) -> String {
        if let text = value.string { return LocaleDisplay.civil(String(text.prefix(16)).replacingOccurrences(of: "T", with: " "), locale: .current) }
        if let millis = value.int, millis > 0 {
            // i18n r1: Chinese keeps `yyyy-MM-dd HH:mm`; English reads `Nov 27, 2026, 3:05 PM`.
            return LocaleDisplay.dayTime(Date(timeIntervalSince1970: Double(millis) / 1000), locale: .current)
        }
        return ""
    }
    /// Newest first; rows keep the latest appeal per enforcement (mini-program dedupe by `appeal_id`).
    static func rows(_ enforcements: [SquareEnforcement]) -> [PostGovernanceRow] {
        var byID: [Int: (SquareEnforcement, Int?)] = [:]
        for record in enforcements where record.id > 0 {
            let appealID = record.raw["appeal_id"].int.flatMap { $0 > 0 ? $0 : nil }
            if let previous = byID[record.id], appealID == nil || (previous.1 ?? 0) > (appealID ?? 0) { continue }
            byID[record.id] = (record, appealID)
        }
        return byID.values.sorted { $0.0.id > $1.0.id }.map { record, appealID in
            let status = record.status.uppercased()
            let appeal = appealID == nil ? "" : (record.appealStatus ?? "").uppercased()
            let state = state(status: status, appealStatus: appeal)
            let type = record.type.uppercased()
            let reason = (record.raw["decision_reason"].string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            return .init(id: record.id, typeKey: knownTypes.contains(type) ? type : "OTHER",
                         isPost: (record.raw["post_id"].int ?? 0) > 0,
                         created: time(record.raw["create_time"]), ends: time(record.raw["ends_at"]), state: state,
                         decisionReason: state == .upheld || state == .reversed ? reason : "",
                         canAppeal: status == "ACTIVE" && appeal.isEmpty)
        }
    }
}

@MainActor struct SettingsPostGovernanceSheet: View {
    let coordinator: SquareGovernanceCoordinator
    let access: any SquareGovernanceAccess
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .loading
    @State private var snapshot: SquareGovernanceSnapshot?
    @State private var pages = 1
    @State private var editingID: Int?
    @State private var reason = ""
    @State private var submitting = false
    @State private var notice: LocalizedStringKey?
    @State private var toastMessage: LocalizedStringKey?
    @State private var generation = UUID()
    private static let reasonMax = 500

    enum Phase: Equatable { case loading, signedOut, failed, ready }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    content
                } header: {
                    Text("mpd.postGov.intro").textCase(nil)
                }
                if let notice {
                    Section {
                        Label { Text(notice) } icon: { Image(systemName: "exclamationmark.triangle") }
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("settings.postGov.notice")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("mpd.postGov.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("action.done") { dismiss() } } }
            .refreshable { await reload() }
        }
        .task { await reload() }
        .onChange(of: notice) { _, next in
            if let next { toastMessage = next }
        }
        .cyToast(message: $toastMessage, tone: notice == "mpd.postGov.submitted" ? .success : .warning)
        .accessibilityIdentifier("settings.postGov.sheet")
    }

    @ViewBuilder private var content: some View {
        switch phase {
        case .loading:
            ProgressView("mpd.common.loading").frame(maxWidth: .infinity) // design pass me P10
                .accessibilityLabel(Text("mpd.common.loading")).accessibilityIdentifier("settings.postGov.loading")
        case .signedOut:
            ContentUnavailableView("mpd.postGov.signedOut", systemImage: "person.crop.circle.badge.questionmark")
                .accessibilityIdentifier("settings.postGov.signedOut")
        case .failed:
            ContentUnavailableView("mpd.postGov.loadFailed", systemImage: "wifi.exclamationmark")
                .accessibilityIdentifier("settings.postGov.error")
            Button("mpd.common.retry") { Task { await reload() } }.accessibilityIdentifier("settings.postGov.retry")
        case .ready:
            let rows = PostGovernanceRow.rows(snapshot?.enforcements ?? [])
            if rows.isEmpty {
                ContentUnavailableView("mpd.postGov.empty", systemImage: "checkmark.shield").accessibilityIdentifier("settings.postGov.empty")
            } else {
                ForEach(rows) { row in rowView(row) }
                if (snapshot?.enforcements.count ?? 0) >= pages * 30 {
                    Button("mpd.postGov.more") { pages += 1; Task { await reload() } }
                        .accessibilityIdentifier("settings.postGov.more")
                }
            }
        }
    }

    private func tone(_ state: PostGovernanceRow.State) -> Color {
        switch state {
        case .reversed: return .green
        case .upheld, .active: return .red
        case .appealing: return .orange
        case .expired, .unknown: return .secondary
        }
    }

    @ViewBuilder private func rowView(_ row: PostGovernanceRow) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey("mpd.postGov.type." + row.typeKey)).font(.headline)
                Spacer(minLength: 8)
                Text(LocalizedStringKey("mpd.postGov.state." + row.state.rawValue))
                    .font(.footnote).foregroundStyle(tone(row.state))
            }
            HStack(spacing: 0) {
                Text(LocalizedStringKey(row.isPost ? "mpd.postGov.target.post" : "mpd.postGov.target.account"))
                if !row.created.isEmpty { Text(verbatim: " · " + row.created) }
                if !row.ends.isEmpty { Text(verbatim: " · "); Text("mpd.postGov.until \(row.ends)") }
            }
            .font(.footnote).foregroundStyle(.secondary).monospacedDigit()
            if row.state != .expired && row.state != .unknown {
                Text(LocalizedStringKey("mpd.postGov.note." + row.state.rawValue)).font(.subheadline).foregroundStyle(.secondary)
            }
            if !row.decisionReason.isEmpty {
                Text("mpd.postGov.decision \(row.decisionReason)").font(.subheadline).foregroundStyle(.secondary)
            }
            if row.canAppeal { appealArea(row) }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.postGov.row.\(row.id)")
    }

    @ViewBuilder private func appealArea(_ row: PostGovernanceRow) -> some View {
        let action = SquareGovernanceAction.appeal(enforcementID: row.id, reason: reason.trimmingCharacters(in: .whitespacesAndNewlines))
        if editingID != row.id {
            Button("mpd.postGov.appeal") { reason = ""; notice = nil; editingID = row.id }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings.postGov.appeal.\(row.id)")
        } else {
            VStack(alignment: .leading, spacing: 8) {
                TextField("mpd.postGov.reasonPlaceholder", text: $reason, axis: .vertical)
                    .lineLimit(3...6).disabled(submitting)
                    .onChange(of: reason) { _, value in if value.count > Self.reasonMax { reason = String(value.prefix(Self.reasonMax)) } }
                    .submitLabel(.done)
                    .accessibilityIdentifier("settings.postGov.reason")
                HStack {
                    // MP pg-count: {{reason.length}}/{{reasonMax}} under the textarea.
                    Text(verbatim: "\(reason.count)/\(Self.reasonMax)")
                        .font(.footnote).monospacedDigit().foregroundStyle(.secondary)
                        .accessibilityLabel(Text("a11y.value.characters \(Int(reason.count)) \(Int(Self.reasonMax))"))
                        .accessibilityIdentifier("settings.postGov.count")
                    Spacer()
                    Button("action.cancel") { editingID = nil; reason = "" }.buttonStyle(.borderless).disabled(submitting)
                        .accessibilityIdentifier("settings.postGov.cancel")
                    Button { Task { await submit(action) } } label: {
                        Text(LocalizedStringKey(submitting ? "mpd.postGov.submitting" : "mpd.postGov.submit"))
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(submitting || !coordinator.service.allows(action))
                    .accessibilityIdentifier("settings.postGov.submit")
                }
                if !coordinator.service.allows(action) {
                    Text("mpd.postGov.liveDisabled").font(.footnote).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func reload() async {
        generation = UUID(); let ticket = generation
        guard access.identity != nil else { phase = .signedOut; return }
        if snapshot == nil { phase = .loading }
        do {
            let value = try await coordinator.load(access: access, enforcementPages: pages)
            guard ticket == generation else { return }
            snapshot = value; phase = .ready
        } catch SquareGovernanceFailure.signedOut {
            guard ticket == generation else { return }; phase = .signedOut
        } catch {
            guard ticket == generation else { return }
            // Keep the last list on a refresh failure (mini-program 「更多处置记录暂未取回」).
            if snapshot == nil { phase = .failed } else { notice = "mpd.postGov.refreshFailed" }
        }
    }

    private func submit(_ action: SquareGovernanceAction) async {
        guard case .appeal(_, let text) = action else { return }
        if text.isEmpty { notice = "mpd.postGov.reasonRequired"; return }
        guard access.identity != nil else { notice = "mpd.postGov.signInFirst"; return }
        guard let snapshot, !submitting else { return }
        submitting = true; notice = nil
        defer { submitting = false }
        do {
            let review = try coordinator.prepare(action, snapshot: snapshot, access: access)
            _ = try await coordinator.confirm(review, access: access)
            editingID = nil; reason = ""; notice = "mpd.postGov.submitted"
            await reload()
        } catch SquareGovernanceFailure.unknown, SquareGovernanceFailure.outcomeLocked {
            // Result unknown: read back first; resubmitting is idempotent server-side.
            notice = "mpd.postGov.unknown"
            await reload()
        } catch {
            notice = "mpd.postGov.submitFailed"
        }
    }
}
