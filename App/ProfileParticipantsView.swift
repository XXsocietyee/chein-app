import SwiftUI

@MainActor
struct ProfileParticipantsView: View {
    let reader: any ProfileReading
    let coordinator: ParticipantMutationCoordinator?
    @State private var showsCreate = false
    @State private var refreshID = UUID()
    @State private var snapshotIdentity: ProfileReadIdentity?
    @State private var editing: ParticipantRowTarget?
    @State private var deleting: ParticipantRowTarget?
    @State private var recoveryRevision: UInt64 = 0
    @State private var recoveryIdentity: ProfileReadIdentity?
    @State private var recoveryVisible = false
    @State private var recoveryGeneration: UInt64 = 0
    @State private var recoveryIssue: ParticipantScreenIssue?
    @State private var deletedNotice: UUID?
    @Environment(\.locale) private var locale
    /// r8 A5-01: the pages/address "select" mode had no caller; 报名 keeps its one participant sheet
    /// (RegistrationSheetView 选择参与人信息), so this list only manages participants.
    /// r9 A6-01b: forwarded to the add/edit form (MP addressinfo.js:59-72 `loadBoundPhone`).
    let boundPhoneLoader: (() async -> String?)?
    init(reader: any ProfileReading, coordinator: ParticipantMutationCoordinator? = nil,
         boundPhoneLoader: (() async -> String?)? = nil) {
        self.reader = reader; self.coordinator = coordinator; self.boundPhoneLoader = boundPhoneLoader
    }
    var body: some View {
        let _ = recoveryRevision
        Group {
        if reader.identity == nil {
            ContentUnavailableView("profile.signInRequired", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("auth.expired"))
        } else if let coordinator, reader.identity == coordinator.identity,
                  case .outcomeUnknown = coordinator.state {
            Form {
                ParticipantOperationSections(state: coordinator.state, readback: coordinator.readbackState,
                    canReadAgain: reader.isConfigured, actionIssue: recoveryIssue) {
                    guard recoveryVisible, reader.isConfigured, let identity = reader.identity else { return }
                    recoveryIdentity = identity
                    let generation = recoveryGeneration
                    Task {
                        guard recoveryVisible, recoveryGeneration == generation, reader.identity == identity else { return }
                        recoveryIssue = nil; recoveryRevision &+= 1
                        let result = await coordinator.readBackUncertainOutcome()
                        guard recoveryVisible, recoveryGeneration == generation, reader.identity == identity else { return }
                        recoveryIssue = ParticipantScreenIssue.feedback(for: result)
                        recoveryRevision &+= 1
                    }
                }
            }
        } else {
        ProfileParticipantListBody(reader: reader, refreshID: refreshID, onSnapshot: { snapshotIdentity = $0 }) { page in
            List {
                if let deletedNotice {
                    // Source danger-confirm step three: the result card, not a passing toast.
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Label {
                                Text("participant.list.deletedTitle").font(.headline)
                            } icon: {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                            }
                            Text("participant.list.deletedDetail").font(.subheadline).foregroundStyle(.secondary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("participant.list.deleted")
                        .id(deletedNotice)
                    }
                }
                Section {
                    ForEach(page.cards) { card in
                        let name = card.fullName.trimmingCharacters(in: .whitespaces)
                        let rowLabel = HStack(spacing: 12) {
                            Text(verbatim: String(name.prefix(1)).uppercased())
                                .font(.headline).foregroundStyle(.secondary)
                                .frame(width: 40, height: 40)
                                .background(.quaternary, in: Circle())
                                .overlay { if name.isEmpty { Image(systemName: "person.fill").foregroundStyle(.secondary) } }
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: 2) {
                                if card.fullName.isEmpty { Text("profile.participants.unnamed").foregroundStyle(.primary) }
                                else { Text(verbatim: card.fullName).foregroundStyle(.primary) }
                                // Blank phone shows the model's em dash, never an empty line.
                                Text(verbatim: card.phoneText).font(.subheadline).monospacedDigit().foregroundStyle(.secondary)
                                    .accessibilityLabel(PageTemplateVoiceOver.spoken(card.phoneText, locale: locale))
                            }
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(.isButton)
                        HStack(spacing: 8) {
                            NavigationLink { ProfileParticipantDetailView(id: card.id, reader: reader, coordinator: coordinator) } label: { rowLabel }
                                .accessibilityIdentifier("profile.participant.\(card.id)")
                            // Mini-program pages/address row: 编辑 and × stay visible beside each participant.
                            if let coordinator, coordinator.canPrepare, reader.identity != nil {
                                Button { editing = ParticipantRowTarget(id: card.id) } label: {
                                    Text("participant.list.editShort")
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .pageTemplateControl(label: Text("participant.list.editShort"), traits: .isButton)
                                .accessibilityIdentifier("participant.list.editInline.\(card.id)")
                                Button { deleting = ParticipantRowTarget(id: card.id) } label: {
                                    Image(systemName: "xmark.circle.fill").symbolRenderingMode(.hierarchical).foregroundStyle(.secondary)
                                        .frame(minWidth: 44, minHeight: 44)
                                }
                                .buttonStyle(.borderless)
                                .pageTemplateControl(label: Text("participant.form.delete"), traits: .isButton)
                                .accessibilityIdentifier("participant.list.deleteInline.\(card.id)")
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            if let coordinator, coordinator.canPrepare, reader.identity != nil {
                                // Direct list entry only opens the existing review/confirm flows; nothing is written here.
                                Button("participant.list.deleteShort", role: .destructive) { deleting = ParticipantRowTarget(id: card.id) } // MP address.wxml 删除
                                    .accessibilityIdentifier("participant.list.delete.\(card.id)")
                                Button("participant.list.editShort") { editing = ParticipantRowTarget(id: card.id) } // MP address.wxml 编辑
                                    .tint(.blue).accessibilityIdentifier("participant.list.edit.\(card.id)")
                            }
                        }
                    }
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        // A5-05: MP pages/address purpose line (用于报名联系和到场核验) once for the list, not on every row.
                        Text("profile.participants.rowPurpose")
                            .accessibilityIdentifier("profile.participants.purpose")
                        // Table total only when the reader exposes it; the row count is never shown in its place.
                        if reader is ProfileParticipantListFactsReading {
                            Text("profile.participants.total \(page.totalText)")
                                .accessibilityIdentifier("profile.participants.total")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
        }
        }
        .cyPageTitle("profile.participants.title") // A5-03: pushed page → inline
        // Mini-program pages/address pins 新增参与人信息 as the page's primary action.
        .questifyBottomAction {
            if let coordinator, coordinator.canPrepare, reader.identity != nil {
                Button { showsCreate = true } label: { Text("participant.form.add").frame(maxWidth: .infinity) }
                    .disabled(snapshotIdentity == nil || snapshotIdentity != reader.identity)
                    .accessibilityIdentifier("participant.list.add")
            }
        }
        .onAppear { recoveryGeneration &+= 1; recoveryVisible = true }
        .onDisappear {
            recoveryGeneration &+= 1; recoveryIssue = nil
            recoveryVisible = false; snapshotIdentity = nil
            if let recoveryIdentity { coordinator?.discardReadback(expectedIdentity: recoveryIdentity) }
            recoveryIdentity = nil
        }
        .onChange(of: reader.identity) { _, _ in
            recoveryGeneration &+= 1; recoveryIssue = nil
            if let recoveryIdentity { coordinator?.discardReadback(expectedIdentity: recoveryIdentity) }
            recoveryIdentity = nil; snapshotIdentity = nil
        }
        .cySheet(isPresented: $showsCreate, onDismiss: { deletedNotice = nil; refreshID = UUID() }) { Group {
            if let coordinator {
                NavigationStack { ParticipantFormView(reader: reader, coordinator: coordinator, boundPhoneLoader: boundPhoneLoader) }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        }
        .cySheet(item: $editing, onDismiss: { deletedNotice = nil; refreshID = UUID() }) { target in Group {
            if let coordinator {
                NavigationStack { ParticipantFormView(id: target.id, reader: reader, coordinator: coordinator, boundPhoneLoader: boundPhoneLoader) }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        }
        .cySheet(item: $deleting, onDismiss: { refreshID = UUID() }) { target in Group {
            if let coordinator {
                NavigationStack { ParticipantListDeleteView(id: target.id, reader: reader, coordinator: coordinator) { deletedNotice = UUID() } }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        }
        .themeDomain(.player)
    }
}

private struct ParticipantRowTarget: Identifiable { let id: Int }

/// Blank participant text is unknown (em dash, U+2014), never "Not provided" or an empty line.
enum ProfileParticipantDisplay {
    static func text(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? ProfileParticipantListPage.unknownMark : raw
    }
}

/// pages/address list body. Reads `ProfileParticipantListCoordinator` so a refresh keeps the retained list
/// (source `refreshing` float), a first-load failure is an error (not an empty list), and malformed is unknown.
@MainActor private struct ProfileParticipantListBody<Ready: View>: View {
    let reader: any ProfileReading
    let refreshID: UUID
    let onSnapshot: (ProfileReadIdentity?) -> Void
    let ready: (ProfileParticipantListPage) -> Ready
    @State private var result: Result<ProfileParticipantListFacts, Error>?
    @State private var retained: ProfileParticipantListFacts?
    @State private var retainedIdentity: ProfileReadIdentity?
    @State private var generation: UInt64 = 0
    @State private var loadOwner = ManualMapReadTaskOwner()

    init(reader: any ProfileReading, refreshID: UUID, onSnapshot: @escaping (ProfileReadIdentity?) -> Void,
         @ViewBuilder ready: @escaping (ProfileParticipantListPage) -> Ready) {
        self.reader = reader; self.refreshID = refreshID; self.onSnapshot = onSnapshot; self.ready = ready
    }

    private var page: ProfileParticipantListPage {
        ProfileParticipantListCoordinator.project(list: result, retained: retainedIdentity == reader.identity ? retained : nil)
    }

    var body: some View {
        let page = page
        Group {
            if reader.isConfigured && page.phase == .loading {
                ProgressView("participant.form.loadingFirst") // mp-settings r3: P10 — say what is loading (参与人信息)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier("profile.participants.loading")
            } else {
            VStack(spacing: 0) {
                if page.isRefreshing {
                    // Source: 正在更新参与人信息… shows above the kept list while a newer read runs.
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("profile.participants.refreshing")
                    }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("profile.participants.refreshing")
                }
                switch page.phase {
                case .loading:
                    Color.clear
                case .empty:
                    ProfileEmptyState(title: "profile.participants.empty", hint: "profile.participants.emptyHint", symbol: "person.2", identifier: "profile.participants.empty")
                case .error:
                    failure
                case .unknown:
                    ContentUnavailableView {
                        Label("profile.participants.unknown", systemImage: "questionmark.circle")
                    } description: {
                        Text("profile.retryHint")
                    } actions: {
                        Button("action.retry") { loadOwner.start { await reload() } }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            .accessibilityIdentifier("profile.participants.retry")
                    }
                    .accessibilityIdentifier("profile.participants.unknown")
                case .ready:
                    ready(page)
                }
            }
            }
        }
        .overlay {
            if !reader.isConfigured {
                ContentUnavailableView("profile.unavailable", systemImage: "network.slash", description: Text("auth.notConfigured"))
                    .accessibilityIdentifier("profile.participants.unavailable")
            }
        }
        // A5-04 (native spec §3.1): pull to refresh is the one refresh; no duplicate toolbar button.
        .refreshable { await loadOwner.run { await reload() } }
        .task(id: ProfileParticipantListLoadKey(identity: reader.identity, refreshID: refreshID)) {
            loadOwner.activate(); await loadOwner.run { await reload() }
        }
        .onDisappear { loadOwner.deactivate(); generation &+= 1 }
    }

    @ViewBuilder private var failure: some View {
        if case .failure(let error)? = result, Self.isSignIn(error) {
            ContentUnavailableView("profile.signInRequired", systemImage: "person.crop.circle.badge.exclamationmark", description: Text("auth.expired"))
                .accessibilityIdentifier("profile.participants.signIn")
        } else {
            ContentUnavailableView {
                Label("profile.participants.loadFailed", systemImage: "exclamationmark.triangle")
            } description: {
                Text(LocalizedStringKey(Self.failureDetailKey(result)))
            } actions: {
                Button("action.retry") { loadOwner.start { await reload() } }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("profile.participants.retry")
            }
            .accessibilityIdentifier("profile.participants.error")
        }
    }

    private static func isSignIn(_ error: Error) -> Bool {
        error as? APIError == .unauthorized || (error as? ProfileReadFailure)?.isUnauthorized == true
    }

    /// Source fallbacks: network 网络异常，请重试; abnormal status 服务暂不可用，请稍后重试; otherwise 参与人信息加载失败.
    private static func failureDetailKey(_ result: Result<ProfileParticipantListFacts, Error>?) -> String {
        guard case .failure(let error)? = result else { return "profile.retryHint" }
        if error is URLError { return "profile.participants.network" }
        if let api = error as? APIError, case .httpStatus = api { return "profile.participants.serviceUnavailable" }
        return "profile.retryHint"
    }

    private func reload() async {
        generation &+= 1
        let request = generation, identity = reader.identity
        if case .success(let facts)? = result { retained = facts; retainedIdentity = identity }
        if retainedIdentity != identity { retained = nil; retainedIdentity = nil }
        result = nil
        onSnapshot(retained == nil ? nil : identity)
        guard reader.isConfigured, identity != nil else { return }
        do {
            let facts: ProfileParticipantListFacts
            if let factsReader = reader as? any ProfileParticipantListFactsReading {
                facts = try await factsReader.profileParticipantListFacts()
            } else {
                facts = ProfileParticipantListFacts(rows: try await reader.profileParticipants(), total: nil)
            }
            guard generation == request, !Task.isCancelled, reader.identity == identity else { return }
            result = .success(facts); retained = facts; retainedIdentity = identity
            onSnapshot(identity)
        } catch {
            guard generation == request, !Task.isCancelled, reader.identity == identity else { return }
            result = .failure(error)
            if retained == nil { onSnapshot(nil) }
        }
    }
}

private struct ProfileParticipantListLoadKey: Hashable {
    let identity: ProfileReadIdentity?
    let refreshID: UUID
}

/// List-initiated delete: loads the row, shows it, and requires the existing confirmation
/// alert. Cancel writes nothing; an unknown outcome offers readback only (no resend).
@MainActor
struct ParticipantListDeleteView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ParticipantFormModel
    private let onDeleted: (() -> Void)?
    init(id: Int, reader: any ProfileReading, coordinator: ParticipantMutationCoordinator, onDeleted: (() -> Void)? = nil) {
        _model = StateObject(wrappedValue: ParticipantFormModel(id: id, reader: reader, coordinator: coordinator))
        self.onDeleted = onDeleted
    }
    var body: some View {
        Group {
            if model.showsOwnedUnknown {
                Form { ParticipantOperationSections(state: model.coordinator.state, readback: model.coordinator.readbackState, canReadAgain: model.canReadBack, actionIssue: model.issue) { Task { await model.readBack() } } }
            } else if model.loading || (model.loaded && !model.hasCurrentProjection) {
                ProgressView()
            } else if !model.loaded {
                ParticipantLoadFailureView(issue: model.issue) { Task { await model.load() } }
            } else {
                Form {
                    Section("profile.participants.contact") {
                        Text(verbatim: ProfileParticipantDisplay.text(model.draft.fullName))
                        Text(verbatim: ProfileParticipantDisplay.text(model.draft.mobilePhone)).foregroundStyle(.secondary)
                    }
                    Section {
                        Button("participant.form.delete", role: .destructive) { model.prepareDelete() }
                            .disabled(!model.canMutate || model.busy || model.showConfirmation)
                            .accessibilityIdentifier("participant.list.delete.review")
                    } footer: { Text("participant.form.sharedRow") }
                    if let issue = model.issue { Section { ParticipantIssueText(issue: issue) } }
                    ParticipantOperationSections(state: model.coordinator.state, readback: model.coordinator.readbackState, canReadAgain: model.canReadBack, actionIssue: model.issue) { Task { await model.readBack() } }
                }
            }
        }
        .appNavigationTitle(key: "participant.form.delete")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("action.cancel") { model.disappear(); dismiss() }.disabled(model.busy)
            }
        }
        .interactiveDismissDisabled(model.busy)
        // Mini-program cy-danger-confirm (utils/danger-actions.js): what, why, irreversible, what stays.
        .cySheet(isPresented: $model.showConfirmation) {
            MemberParticipantDeleteConfirmSheet(
                summary: model.confirmationSummary,
                onCancel: { model.cancelConfirmation() }
            ) {
                Task { if await model.confirmMutation() { onDeleted?(); dismiss() } }
            }
            .themeDomain(.player)
        }
        .task(id: model.reader.identity) { await model.load() }
        .onDisappear { model.disappear() }
        .themeDomain(.player)
    }
}

@MainActor
struct ProfileParticipantDetailView: View {
    let id: Int
    let reader: any ProfileReading
    let coordinator: ParticipantMutationCoordinator?
    init(id: Int, reader: any ProfileReading, coordinator: ParticipantMutationCoordinator? = nil) {
        self.id = id; self.reader = reader; self.coordinator = coordinator
    }
    private var usesManagement: Bool {
        guard let coordinator else { return false }
        if coordinator.isConfigured { return true }
        guard reader.identity != nil, reader.identity == coordinator.identity else { return false }
        if case .outcomeUnknown = coordinator.state { return true }; return false
    }
    var body: some View {
        Group {
            if let coordinator, usesManagement {
                ParticipantManagementDetailView(id: id, reader: reader, coordinator: coordinator)
            } else {
                ProfileReadScreen(reader: reader, accessibilityPrefix: "profile.participant.detail", load: { try await reader.profileParticipant(id: id) }) { participant in
                    List {
                        Section("profile.participants.contact") {
                            // Blank name or phone is unknown: em dash, never an invented value.
                            LabeledContent("profile.participants.name") {
                                Text(verbatim: ProfileParticipantDisplay.text(participant.fullName)).textSelection(.enabled)
                            }
                            LabeledContent("profile.participants.phone") {
                                Text(verbatim: ProfileParticipantDisplay.text(participant.mobilePhone)).monospacedDigit().textSelection(.enabled)
                            }
                        }
                        if !participant.oneLineAddress.isEmpty {
                            Section("profile.participants.savedAddress") {
                                Text(verbatim: participant.oneLineAddress).textSelection(.enabled)
                            }
                        }
                    }
                }
                .appNavigationTitle("profile.participants.detail")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .themeDomain(.player)
    }
}
