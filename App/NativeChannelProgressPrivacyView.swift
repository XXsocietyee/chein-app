import SwiftUI

/// A settings host may inject a privacy-only coordinator. Returning from the
/// background resolves a new owner; the original command remains in its journal.
@MainActor struct NativeChannelProgressPrivacyEntry: View {
    let makeFlow: () throws -> NativeChannelProgressCoordinator?
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var owner = NativeChannelProgressVisitOwner()
    @State private var isVisible = false
    var body: some View {
        Group {
            if let model = owner.model {
                NativeChannelProgressPrivacyView(model: model, loadsOnAppear: false).id(owner.visitID)
            } else {
                List {
                    Section {
                        CYHeroHeader("privacy", tableName: "NativeChannelProgress")
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                    if owner.attempted {
                        CYEmptyState(systemImage: "hand.raised", "d7.channelProgress.closed", tableName: "NativeChannelProgress")
                    } else {
                        CYSkeleton()
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("cy.state.loading"))
                            .listRowBackground(Color.clear)
                    }
                }
                .listStyle(.insetGrouped)
                .contentMargins(.horizontal, CYSpacing.pageHorizontal, for: .scrollContent)
                .nativeChannelScreen()
                .cyHeroScreen()
            }
        }
        .onAppear { isVisible = true; reopen() }
        .onDisappear { isVisible = false; owner.retire() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { reopen() } else { owner.retire() }
        }
    }
    private func reopen() {
        guard isVisible, scenePhase == .active else { return }
        let makeFlow = makeFlow, visibility = $isVisible
        owner.open(parentCurrent: { visibility.wrappedValue }, privacyOnly: true) { sourceCurrent in
            guard sourceCurrent() else { return nil }
            return try makeFlow()
        }
    }
}

/// A confirmation binds the exact settings read, draft and visible visit. A
/// dismissed, refreshed or edited review cannot be reused by a queued Task.
@MainActor final class NativeChannelProgressPrivacyConfirmation: ObservableObject {
    struct Review: Equatable {
        let current: NativeChannelProgressPrivacy
        let values: NativeChannelProgressPrivacyValues
        let generation: UUID
    }
    @Published private(set) var review: Review?
    private var generation = UUID()
    private var visible = false
    func enter() { visible = true; invalidate() }
    func leave() { visible = false; invalidate() }
    func invalidate() { generation = UUID(); review = nil }
    func prepare(current: NativeChannelProgressPrivacy?, draft: NativeChannelProgressPrivacyValues?, canSave: Bool) {
        invalidate()
        guard visible, canSave, let current, let draft else { return }
        review = Review(current: current, values: draft, generation: generation)
    }
    func validates(_ review: Review, current: NativeChannelProgressPrivacy?,
                   draft: NativeChannelProgressPrivacyValues?, canSave: Bool) -> Bool {
        visible && canSave && generation == review.generation && current == review.current && draft == review.values
    }
    func consume(current: NativeChannelProgressPrivacy?, draft: NativeChannelProgressPrivacyValues?, canSave: Bool) -> Review? {
        guard let selected = review, validates(selected, current: current, draft: draft, canSave: canSave) else {
            invalidate(); return nil
        }
        review = nil
        return selected
    }
}

@MainActor struct NativeChannelProgressPrivacyView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var model: NativeChannelProgressCoordinator
    var loadsOnAppear = true
    @State private var draft: NativeChannelProgressPrivacyValues?
    @StateObject private var confirmation = NativeChannelProgressPrivacyConfirmation()
    @StateObject private var actions = NativeChannelProgressActionLifetime()
    @State private var showsConfirmation = false
    var body: some View {
        Form {
            Section {
                CYHeroHeader("privacy", tableName: "NativeChannelProgress")
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
            if model.busy { NativeChannelProgressPrivacyLoading() }
            if !model.isCurrent {
                CYStatusChip(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.closed"), tone: .warning, systemImage: "lock")
                    .accessibilityLabel(Text("d7.channelProgress.closed", tableName: "NativeChannelProgress"))
            }
            if model.isCurrent, let values = draft {
                NativeChannelProgressScopePickers(values: Binding(get: { draft ?? values }, set: { draft = $0 }))
                    .disabled(!model.canSavePrivacy)
            }
            if let current = model.privacy {
                Section {
                    if let effective = current.effective {
                        CYListRow(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.aggregate"), trailing: .value(NativeChannelProgressCopy.text(effective.aggregateScope.rawValue))) {
                            CYRowIcon(systemImage: "person.3")
                        }
                        CYListRow(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.detailScope"), trailing: .value(NativeChannelProgressCopy.text(effective.detailScope.rawValue))) {
                            CYRowIcon(systemImage: "list.bullet")
                        }
                    }
                    if let at = current.updatedAt {
                        CYListRow(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.updatedLabel"), trailing: .value(NativeChannelProgressDateText.text(at))) {
                            CYRowIcon(systemImage: "clock")
                        }
                    }
                } header: { NativeChannelSectionTitle(key: "d7.channelProgress.effective") }
            }
            Section {
                if let command = model.pendingCommand {
                    Text("d7.channelProgress.originalPending", tableName: "NativeChannelProgress")
                        .fixedSize(horizontal: false, vertical: true)
                    Text(verbatim: command.requestId)
                        .font(CYTypography.meta)
                        .monospaced()
                        .foregroundStyle(CYColor.textSecondary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                    CYPillButton("d7.channelProgress.checkOriginal", style: .secondary, tableName: "NativeChannelProgress") { actions.run { await model.recoverOriginal() } }
                        .disabled(model.busy)
                        .accessibilityIdentifier("channelProgress.checkOriginal")
                        .accessibilityLabel(Text("d7.channelProgress.checkOriginal", tableName: "NativeChannelProgress"))
                    CYPillButton("d7.channelProgress.retryOriginal", style: .secondary, tableName: "NativeChannelProgress") { actions.run { await model.recoverOriginal(retryOriginal: true) } }
                        .disabled(model.busy)
                        .accessibilityIdentifier("channelProgress.retryOriginal")
                        .accessibilityLabel(Text("d7.channelProgress.retryOriginal", tableName: "NativeChannelProgress"))
                }
                if model.privacyPhase == .unresolved { Text("d7.channelProgress.outcomeUnknown", tableName: "NativeChannelProgress").nativeChannelNotice(systemImage: "clock") }
                if model.privacyPhase == .conflict {
                    CYStatusChip(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.privacyConflict"), tone: .danger, systemImage: "exclamationmark.triangle")
                        .accessibilityLabel(Text("d7.channelProgress.privacyConflict", tableName: "NativeChannelProgress"))
                }
                if model.privacyPhase == .persistenceFailed {
                    CYStatusChip(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.persistenceFailed"), tone: .danger, systemImage: "exclamationmark.circle")
                        .accessibilityLabel(Text("d7.channelProgress.persistenceFailed", tableName: "NativeChannelProgress"))
                }
                if let receipt = model.receipt, receipt.status == "APPLIED" {
                    CYStatusChip(verbatim: NativeChannelProgressCopy.text("d7.channelProgress.applied"), tone: .success, systemImage: "checkmark.circle")
                        .accessibilityIdentifier("channelProgress.applied")
                        .accessibilityLabel(Text("d7.channelProgress.applied", tableName: "NativeChannelProgress"))
                }
                CYPillButton("d7.channelProgress.save", tableName: "NativeChannelProgress") {
                    confirmation.prepare(current: model.privacy, draft: draft, canSave: model.canSavePrivacy)
                    showsConfirmation = confirmation.review != nil
                }
                .disabled(!model.canSavePrivacy || draft == nil)
                .accessibilityIdentifier("channelProgress.savePrivacy")
                .accessibilityLabel(Text("d7.channelProgress.save", tableName: "NativeChannelProgress"))
            }
            NativeChannelProgressIssueView(model: model, part: "privacy")
        }
        .contentMargins(.horizontal, CYSpacing.pageHorizontal, for: .scrollContent)
        .nativeChannelScreen()
        .cyHeroScreen()
        .privacySensitive()
        .onAppear { confirmation.enter(); actions.activate() }
        .task {
            if loadsOnAppear { await model.loadPrivacy() }
            guard !Task.isCancelled, model.isCurrent else { return }
            synchronizeDraft()
        }
        .onChange(of: model.privacy) { _, _ in synchronizeDraft() }
        .onChange(of: draft) { _, _ in confirmation.invalidate(); showsConfirmation = false }
        .onChange(of: model.isCurrent) { _, current in
            if !current { confirmation.leave(); actions.retire(); draft = nil; showsConfirmation = false }
        }
        .onDisappear { confirmation.leave(); actions.retire(); draft = nil; showsConfirmation = false }
        .onChange(of: scenePhase) { _, phase in
            if phase != .active { confirmation.leave(); actions.retire(); draft = nil; showsConfirmation = false }
        }
        .refreshable { confirmation.invalidate(); showsConfirmation = false; await model.loadPrivacy() }
        .confirmationDialog(Text("d7.channelProgress.confirmPrivacy", tableName: "NativeChannelProgress"), isPresented: $showsConfirmation, titleVisibility: .visible) {
            Button { confirmSave() } label: { Text("d7.channelProgress.save", tableName: "NativeChannelProgress") }
            Button(role: .cancel) { confirmation.invalidate() } label: { Text("cancel", tableName: "NativeChannelProgress") }
        }
    }
    private func synchronizeDraft() {
        confirmation.invalidate(); showsConfirmation = false
        draft = try? model.privacy?.values()
    }
    private func confirmSave() {
        guard let review = confirmation.consume(current: model.privacy, draft: draft, canSave: model.canSavePrivacy) else { return }
        actions.run {
            // Recheck at execution, not just when the confirmation button was tapped.
            guard !Task.isCancelled, confirmation.validates(review, current: model.privacy, draft: draft, canSave: model.canSavePrivacy) else { return }
            await model.savePrivacy(review.values)
            // Current settings are synchronized by their observation, never by a
            // completion retained from a view that has already disappeared.
        }
    }
}
private struct NativeChannelProgressPrivacyLoading: View {
    var body: some View {
        CYSkeleton()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("cy.state.loading"))
            .listRowBackground(Color.clear)
    }
}

private struct NativeChannelProgressScopePickers: View {
    @Binding var values: NativeChannelProgressPrivacyValues
    var body: some View {
        Section {
            Picker(selection: $values.aggregateScope) {
                ForEach(NativeChannelProgressScope.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue), tableName: "NativeChannelProgress").tag($0) }
            } label: { Text("d7.channelProgress.aggregate", tableName: "NativeChannelProgress") }.accessibilityIdentifier("channelProgress.aggregateScope")
            Picker(selection: $values.detailScope) {
                ForEach(NativeChannelProgressScope.allCases.filter { $0 != .publicAccess }, id: \.self) { Text(LocalizedStringKey($0.rawValue), tableName: "NativeChannelProgress").tag($0) }
            } label: { Text("d7.channelProgress.detailScope", tableName: "NativeChannelProgress") }.accessibilityIdentifier("channelProgress.detailScope")
            Picker(selection: $values.photoScope) {
                ForEach(NativeChannelProgressPhotoScope.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue), tableName: "NativeChannelProgress").tag($0) }
            } label: { Text("d7.channelProgress.photo", tableName: "NativeChannelProgress") }.accessibilityIdentifier("channelProgress.photoScope")
            Picker(selection: $values.leaderboardScope) {
                ForEach(NativeChannelProgressLeaderboardScope.allCases, id: \.self) { Text(LocalizedStringKey($0.rawValue), tableName: "NativeChannelProgress").tag($0) }
            } label: { Text("d7.channelProgress.leaderboard", tableName: "NativeChannelProgress") }.accessibilityIdentifier("channelProgress.leaderboardScope")
        } header: { NativeChannelSectionTitle(key: "d7.channelProgress.whoCanSee") }
    }
}
