import SwiftUI

@MainActor
struct ParticipantManagementDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var model: ParticipantFormModel
    @State private var showsEditor = false

    init(id: Int, reader: any ProfileReading, coordinator: ParticipantMutationCoordinator) {
        _model = StateObject(wrappedValue: ParticipantFormModel(id: id, reader: reader, coordinator: coordinator))
    }

    var body: some View {
        Group {
            if model.reader.identity == nil || model.coordinator.identity == nil {
                CYEmptyState(systemImage: "person.crop.circle.badge.exclamationmark", "profile.signInRequired", detail: "auth.expired")
            } else if model.showsOwnedUnknown {
                Form {
                    ParticipantOperationSections(state: model.coordinator.state, readback: model.coordinator.readbackState, canReadAgain: model.canReadBack, actionIssue: model.issue) {
                        Task { await model.readBack() }
                    }
                }
            } else if !model.reader.isConfigured || !model.coordinator.isConfigured {
                CYEmptyState(systemImage: "network.slash", "profile.unavailable", detail: "auth.notConfigured", kind: .offline)
            } else if model.loading || (model.loaded && !model.hasCurrentProjection) {
                CYLoadingStateView(rows: 2).accessibilityLabel(Text("profile.loading")).accessibilityIdentifier("participant.detail.loading")
            } else if !model.loaded {
                ParticipantLoadFailureView(issue: model.issue) { Task { await model.load() } }
            } else {
                List {
                    Section { CYHeroHeader("profile.participants.detail") }.e1HeroRow()
                    Section("profile.participants.contact") {
                        LabeledContent("profile.participants.name") { Text(verbatim: ProfileParticipantDisplay.text(model.draft.fullName)).textSelection(.enabled) }
                        LabeledContent("profile.participants.phone") { Text(verbatim: ProfileParticipantDisplay.text(model.draft.mobilePhone)).monospacedDigit().textSelection(.enabled) }
                    }
                    if let province = model.draft.province, !province.isEmpty {
                        Section("profile.participants.savedAddress") {
                            Text(verbatim: [province, model.draft.detailAddress].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " "))
                                .textSelection(.enabled)
                        }
                    } else if let address = model.draft.detailAddress, !address.isEmpty {
                        Section("profile.participants.savedAddress") { Text(verbatim: address).textSelection(.enabled) }
                    }
                    Section {
                        CYPillButton("participant.form.edit", systemImage: "pencil") { showsEditor = true }
                            .disabled(!model.canMutate).accessibilityIdentifier("participant.detail.edit").e1ActionRow()
                        Button("participant.form.delete", role: .destructive) { model.prepareDelete() }
                            .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                            .disabled(!model.canMutate).accessibilityIdentifier("participant.detail.delete")
                    } footer: { Text("participant.form.sharedRow") }
                    if let issue = model.issue { Section { ParticipantIssueText(issue: issue) } }
                    ParticipantOperationSections(state: model.operation, readback: model.readback, canReadAgain: model.canReadBack, actionIssue: model.issue) {
                        Task { await model.readBack() }
                    }
                }
                .listStyle(.insetGrouped)
                .cyGroupedSurface()
            }
        }
        .cyHeroScreen()
        // T&C §3: the system back stays while a delete runs; the operation lives in the shared
        // ParticipantMutationCoordinator, so leaving does not drop its outcome.
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("profile.refresh", systemImage: "arrow.clockwise") { Task { await model.load() } }
                    .disabled(model.loading || model.busy || model.operation == .awaitingConfirmation)
                    .accessibilityIdentifier("participant.detail.refresh")
            }
        }
        .cySheet(isPresented: $showsEditor, onDismiss: { Task { await model.load() } }) { Group {
            NavigationStack {
                ParticipantFormView(id: model.id, reader: model.reader, coordinator: model.coordinator)
            }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .alert("participant.form.confirmDelete", isPresented: $model.showConfirmation) {
            Button("participant.form.delete", role: .destructive) {
                Task { if await model.confirmMutation() { dismiss() } }
            }
            Button("action.cancel", role: .cancel) { model.cancelConfirmation() }
        } message: {
            Text(verbatim: model.confirmationSummary + "\n") + Text("participant.form.confirmDeleteHint")
        }
        .task(id: model.reader.identity) { await model.load() }
        .onDisappear { model.disappear() }
        .cyDomainScreen(.player)
    }
}
