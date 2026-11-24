import SwiftUI

/// Client-side view of the read consent. `revoked`/`expired` end this screen's local copies only.
enum NPCChatDataConsentState: Equatable { case active, revoked, expired }

/// Injected by a host that holds the read approval; nil keeps the screen exactly as before.
struct NPCChatDataConsentProbe {
    let isRevoked: () -> Bool
    let expiresAt: Date
    let revoke: () -> Void
    var now: () -> Date = { Date() }
    var state: NPCChatDataConsentState {
        if isRevoked() { return .revoked }
        return now() >= expiresAt ? .expired : .active
    }
}

@MainActor final class NPCChatDataViewModel: ObservableObject {
    let coordinator: NPCChatDataCoordinator
    private let consent: NPCChatDataConsentProbe?
    /// Non-nil once revoke/expiry was observed; local copies were cleared at that moment.
    @Published private(set) var consentEnded: NPCChatDataConsentState?
    @Published private(set) var revision = 0
    @Published private(set) var loadIntent: UUID?
    /// Set only by the destructive dialog's confirm button; lifecycle exits clear it.
    @Published private(set) var deletionIntent: UUID?
    private var visible = false
    private var active = false
    init(coordinator: NPCChatDataCoordinator, consent: NPCChatDataConsentProbe? = nil) {
        self.coordinator = coordinator
        self.consent = consent
        coordinator.onChange = { [weak self] in self?.revision += 1 }
    }
    func appear(active: Bool) {
        visible = true; self.active = active
        coordinator.appear(active: active); requestLoad()
    }
    /// Re-checks consent and, if it ended, clears every local copy. Returns true while still usable.
    @discardableResult func refreshConsent() -> Bool {
        guard let consent else { return true }
        let state = consent.state
        guard state != .active else { return consentEnded == nil }
        if consentEnded == nil {
            consentEnded = state
            loadIntent = nil; deletionIntent = nil
            coordinator.invalidate() // drops records, pending confirmation and read generation
        }
        return false
    }
    func revokeConsent() {
        guard let consent, consentEnded == nil else { return }
        consent.revoke(); refreshConsent()
    }
    /// States only what the client did; the server is never claimed to have deleted anything.
    var consentNoticeKeys: [String] {
        switch consentEnded {
        case .revoked: return ["npcData.consent.revoked", "npcData.consent.localOnly"]
        case .expired: return ["npcData.consent.expired", "npcData.consent.localOnly"]
        case .active, nil: return []
        }
    }
    var canRevokeConsent: Bool { consent != nil && consentEnded == nil }
    func requestLoad() {
        guard refreshConsent(), visible, active, coordinator.canLoad else { return }
        loadIntent = UUID()
    }
    func load(_ intent: UUID?) async {
        guard !Task.isCancelled, visible, active, let intent, intent == loadIntent, refreshConsent() else { return }
        await coordinator.load()
    }
    func requestDeletion() { guard visible, active else { return }; coordinator.requestDeletion() }
    func cancelDeletion() { guard deletionIntent == nil else { return }; coordinator.cancelDeletion() }
    func confirmDeletion() {
        guard visible, active, deletionIntent == nil, coordinator.deletion == .confirming else { return }
        deletionIntent = UUID()
    }
    func runDeletion(_ intent: UUID?) async {
        guard !Task.isCancelled, visible, active, let intent, intent == deletionIntent else { return }
        await coordinator.confirmDeletion()
        if deletionIntent == intent { deletionIntent = nil }
    }
    func suspend() { active = false; loadIntent = nil; deletionIntent = nil; coordinator.suspend() }
    func foreground() { guard visible else { return }; active = true; coordinator.foreground(); refreshConsent() }
    func sessionChanged() { loadIntent = nil; deletionIntent = nil; coordinator.sessionChanged() }
    func disappear() { visible = false; active = false; loadIntent = nil; deletionIntent = nil; coordinator.invalidate() }
    var deletionFailureKey: LocalizedStringKey? {
        guard case .failed(let failure) = coordinator.deletion else { return nil }
        return LocalizedStringKey("npcLogDelete.failure." + failure.rawValue)
    }
}

struct NPCChatDataPresentation: Identifiable {
    let id = UUID()
    let coordinator: NPCChatDataCoordinator
}

/// Owns the navigation container so opening a row does not retire the list's
/// private memory; dismissing this sheet or backgrounding does retire it.
@MainActor struct NPCChatDataView: View {
    @StateObject private var model: NPCChatDataViewModel
    @State private var query = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    init(coordinator: NPCChatDataCoordinator, consent: NPCChatDataConsentProbe? = nil) {
        _model = StateObject(wrappedValue: .init(coordinator: coordinator, consent: consent))
    }
    private var coordinator: NPCChatDataCoordinator { model.coordinator }
    private var filtered: [NPCChatDataRecord] {
        Array((coordinator.data?.records ?? []).reversed()).filter { $0.matches(query) }
    }
    private var errorOwnsRetry: Bool { coordinator.failure != nil && coordinator.data == nil && coordinator.canLoad && model.consentEnded == nil }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    CYHeroHeader("npcData.title", subtitle: "npcData.boundary") {
                        NPCChatCover(seed: "npc-chat-data", symbol: "text.bubble")
                    }
                }.e1HeroRow()
                if !model.consentNoticeKeys.isEmpty {
                    Section {
                        ForEach(model.consentNoticeKeys, id: \.self) { key in
                            Label {
                                Text(LocalizedStringKey(key))
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "info.circle")
                            }
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                        }
                    }.accessibilityIdentifier("npcData.consentEnded")
                } else if model.canRevokeConsent {
                    Section {
                        Button(role: .destructive) { model.revokeConsent() } label: {
                            Text("npcData.consent.revoke")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .frame(minHeight: CYSpacing.minTouchTarget)
                        }
                        .accessibilityIdentifier("npcData.consent.revoke")
                    }
                }
                if coordinator.phase == .loading {
                    Section {
                        CYSkeleton()
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("npcData.loading"))
                    }
                }
                if let value = coordinator.data {
                    Section {
                        CYListRow("npcData.retentionDays", trailing: .value(value.retentionDays.map { String($0) } ?? "—")) {
                            CYRowIcon(systemImage: "calendar")
                        }
                        if let policy = value.retentionPolicy, !policy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(verbatim: policy)
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                                .textSelection(.enabled)
                        } else {
                            Text("npcData.policyNotReturned")
                                .cyText(.body)
                                .foregroundStyle(CYColor.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        CYListRow("npcData.recordCount", trailing: .value(String(value.records.count))) {
                            CYRowIcon(systemImage: "text.bubble")
                        }
                    } header: {
                        CYSectionHeader("npcData.policy")
                    }
                    .textCase(nil)
                    .accessibilityIdentifier("npcData.policy")
                    Section {
                        if value.records.isEmpty {
                            CYEmptyState(systemImage: "bubble.left.and.bubble.right", "npcData.empty", messageIdentifier: "npcData.empty", kind: .inbox)
                        } else if filtered.isEmpty {
                            CYEmptyState(systemImage: "magnifyingglass", "npcData.noMatches", kind: .search)
                        }
                        ForEach(filtered) { record in
                            NavigationLink { [recordID = record.id] in
                                NPCChatDataRecordView(model: model, recordID: recordID)
                            } label: {
                                recordRow(record)
                            }.accessibilityIdentifier("npcData.record." + record.id)
                        }
                    } header: {
                        CYSectionHeader("npcData.records")
                    }
                    .textCase(nil)
                }
                if let failure = coordinator.failure {
                    if errorOwnsRetry {
                        Section {
                            CYErrorState(LocalizedStringKey(failure.messageKey), retryTitle: "npcData.reload") {
                                query = ""; model.requestLoad()
                            }
                            .accessibilityIdentifier("npcData.reload")
                        }
                        .accessibilityIdentifier("npcData.failure")
                    } else {
                        Section {
                            Label {
                                Text(LocalizedStringKey(failure.messageKey))
                                    .fixedSize(horizontal: false, vertical: true)
                            } icon: {
                                Image(systemName: "exclamationmark.triangle.fill")
                            }
                            .cyText(.body)
                            .foregroundStyle(CYColor.dangerText)
                            .accessibilityIdentifier("npcData.failure")
                        }
                    }
                }
                if coordinator.canRequestDeletion || coordinator.deletion != .idle {
                    NPCChatLogDeletionSection(model: model)
                }
                if coordinator.canLoad && model.consentEnded == nil && !errorOwnsRetry {
                    Section {
                        CYPillButton("npcData.reload", systemImage: "arrow.clockwise") { query = ""; model.requestLoad() }
                            .accessibilityIdentifier("npcData.reload")
                            .e1ActionRow()
                    }
                }
            }
            .listStyle(.insetGrouped)
            .cyGroupedSurface()
            .cyHeroScreen()
            .searchable(text: $query, prompt: "npcData.search")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("action.done") { model.disappear(); query = ""; dismiss() } }
                ToolbarItem(placement: .primaryAction) { NPCChatDataExportButton(data: coordinator.data) }
            }
            .sheet(isPresented: Binding(
                get: { coordinator.deletion == .confirming && model.deletionIntent == nil },
                set: { if !$0 { model.cancelDeletion() } }
            )) {
                MemberNPCLogDeleteConfirmSheet {
                    model.confirmDeletion()
                }
                .themeDomain(.player)
            }
        }
        .privacySensitive()
        .accessibilityIdentifier("npcData.screen")
        .onAppear { model.appear(active: scenePhase == .active) }
        .task(id: model.loadIntent) { [intent = model.loadIntent] in await model.load(intent) }
        .task(id: model.deletionIntent) { [intent = model.deletionIntent] in await model.runDeletion(intent) }
        .onChange(of: coordinator.currentSession) { _, _ in query = ""; model.sessionChanged() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.foreground() }
            else { query = ""; model.suspend() }
        }
        .onDisappear { query = ""; model.disappear() }
    }

    @ViewBuilder private func recordRow(_ record: NPCChatDataRecord) -> some View {
        let time = record.sourceTime.map(cyShownValue) ?? "—"
        if let question = record.userMessage, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            CYListRow(verbatim: question, meta: time, trailing: .chevron) {
                NPCChatThumb(seed: record.id, symbol: "text.bubble")
            }
        } else {
            CYListRow("npcData.noQuestion", trailing: .chevron, verbatimMeta: time) {
                NPCChatThumb(seed: record.id, symbol: "text.bubble")
            }
        }
    }
}

/// Log deletion only (BK-EXISTING); shown only when a host injected an approved deleter.
@MainActor private struct NPCChatLogDeletionSection: View {
    @ObservedObject var model: NPCChatDataViewModel
    @Environment(\.locale) private var locale
    var body: some View {
        let coordinator = model.coordinator
        Section {
            Text("npcLogDelete.scope", tableName: "NPCChatLogDeletion")
                .cyText(.meta)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            switch coordinator.deletion {
            case .deleting:
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    CYSkeleton()
                    Text("npcLogDelete.deleting", tableName: "NPCChatLogDeletion")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
            case .deleted(let count):
                CYListRow(verbatim: npcDelete("npcLogDelete.deletedCount"), trailing: .value(String(count))) {
                    CYRowIcon(systemImage: "trash")
                }
                .accessibilityIdentifier("npcLogDelete.deleted")
                Text("npcLogDelete.deletedBoundary", tableName: "NPCChatLogDeletion")
                    .cyText(.meta)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            case .unknown:
                Text("npcLogDelete.unknown", tableName: "NPCChatLogDeletion")
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("npcLogDelete.unknown")
            case .failed:
                if let key = model.deletionFailureKey {
                    Label {
                        Text(key, tableName: "NPCChatLogDeletion")
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                    }
                    .cyText(.body)
                    .foregroundStyle(CYColor.dangerText)
                    .accessibilityIdentifier("npcLogDelete.failure")
                }
            case .idle, .confirming:
                EmptyView()
            }
            if coordinator.canRequestDeletion {
                Button(role: .destructive) { model.requestDeletion() } label: {
                    Text("npcLogDelete.action", tableName: "NPCChatLogDeletion")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                }
                .accessibilityIdentifier("npcLogDelete.action")
            }
        } header: {
            Text("npcLogDelete.title", tableName: "NPCChatLogDeletion")
                .cyText(.sectionTitle)
                .foregroundStyle(CYColor.textPrimary)
                .textCase(nil)
        }
    }

    private func npcDelete(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key), table: "NPCChatLogDeletion", locale: locale))
    }
}

@MainActor private struct NPCChatDataRecordView: View {
    @ObservedObject var model: NPCChatDataViewModel
    let recordID: String
    /// Look up by ID on every render. Never capture a private record in navigation
    /// state where it could survive the parent's account/epoch invalidation.
    private var record: NPCChatDataRecord? { model.coordinator.data?.records.first(where: { $0.id == recordID }) }
    var body: some View {
        Form {
            Section {
                CYHeroHeader("npcData.recordTitle") {
                    NPCChatCover(seed: recordID, symbol: "text.bubble")
                }
            }.e1HeroRow()
            if let record {
                Section {
                    if let text = record.userMessage, !text.isEmpty {
                        Text(verbatim: text)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    } else { Text("npcData.noQuestion").cyText(.body).fixedSize(horizontal: false, vertical: true) }
                } header: { NPCChatSectionTitle("npcData.question") }
                Section {
                    if let text = record.npcReply, !text.isEmpty {
                        Text(verbatim: text)
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .textSelection(.enabled)
                    } else { Text("npcData.noReply").cyText(.body).fixedSize(horizontal: false, vertical: true) }
                } header: { NPCChatSectionTitle("npcData.reply") }
                Section {
                    if let time = record.sourceTime {
                        Text(verbatim: cyShownValue(time))
                            .cyText(.numericBody)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else { Text("npcData.timeNotReturned").cyText(.body).fixedSize(horizontal: false, vertical: true) }
                    Text("npcData.timeBoundary")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                } header: { NPCChatSectionTitle("npcData.sourceTime") }
                Section {
                    Text("npcData.historicalBoundary")
                        .cyText(.meta)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                CYEmptyState(systemImage: "trash", "npcData.contentCleared", messageIdentifier: "npcData.contentCleared")
            }
        }
        .listStyle(.insetGrouped)
        .cyGroupedSurface()
        .cyHeroScreen()
        .privacySensitive()
    }
}

private struct NPCChatSectionTitle: View {
    let key: LocalizedStringKey
    init(_ key: LocalizedStringKey) { self.key = key }
    var body: some View {
        Text(key)
            .cyText(.sectionTitle)
            .foregroundStyle(CYColor.textPrimary)
            .textCase(nil)
            .accessibilityAddTraits(.isHeader)
    }
}

private struct NPCChatCover: View {
    let seed: String
    var symbol: String
    @ScaledMetric(relativeTo: .largeTitle) private var height: CGFloat = 168
    var body: some View {
        CYCoverArt(seed: seed, symbol: symbol, cornerRadius: CYRadius.lg)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .accessibilityHidden(true)
    }
}

private struct NPCChatThumb: View {
    let seed: String
    var symbol: String
    var body: some View {
        CYCoverArt(seed: seed.isEmpty ? "npc" : seed, symbol: symbol, showsDebugLabel: false, cornerRadius: CYRadius.sm)
            .frame(width: 40, height: 40)
            .accessibilityHidden(true)
    }
}

private func cyShownValue(_ value: String) -> String {
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty { return "—" }
    if trimmed.caseInsensitiveCompare("UNKNOWN") == .orderedSame { return "—" }
    return value
}
