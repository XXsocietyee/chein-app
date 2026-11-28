import SwiftUI

/// Present only from an activity registration, never a nearby-team, route-ticket or club ID.
@MainActor struct TeamCreateView: View {
    let activityID: Int
    @StateObject private var model: TeamScreenModel
    @State private var size = 2
    @State private var inviteOnly: Bool
    /// MP `teamStarted`: the session has started, so the switch is gone and the team is invite-only.
    let sessionStarted: Bool
    init(activityID: Int, coordinator: TeamCoordinator, sessionStarted: Bool = false) {
        self.activityID = activityID
        self.sessionStarted = sessionStarted
        _inviteOnly = State(initialValue: sessionStarted)
        _model = StateObject(wrappedValue: TeamScreenModel(coordinator))
    }
    var body: some View {
        Form {
            Section { TeamNotice(coordinator: model.coordinator) }
            if model.running { ProgressView { Text("team.loading") }.frame(maxWidth: .infinity) }
            if let context = model.coordinator.creation {
                Section("team.create.activity") { Text(verbatim: context.title).font(.headline).fixedSize(horizontal: false, vertical: true) }
                Section {
                    Picker("team.size", selection: $size) { ForEach(context.sizes, id: \.self) { Text(verbatim: "\($0)").tag($0) } }
                        .accessibilityIdentifier("team.create.size")
                    if !sessionStarted {
                        Toggle("team.invitationOnly", isOn: $inviteOnly).accessibilityIdentifier("team.create.inviteOnly")
                    }
                } header: { Text("team.create.settings") } footer: {
                    Text(LocalizedStringKey(sessionStarted ? "orderDetail.team.started" : (inviteOnly ? "team.create.privateHelp" : "team.create.publicHelp")))
                }.disabled(model.actionLocked)
                Section {
                    Text("team.create.consequence").fixedSize(horizontal: false, vertical: true)
                    reviewButton(context)
                    if !model.coordinator.canSubmit { leaseClosedNote }
                }
            } else if !model.coordinator.canSubmit, !model.running {
                Section {
                    leaseClosedNote
                    Button("team.create.review") { model.refuseClosedLease() }
                        .disabled(model.actionLocked)
                        .accessibilityIdentifier("team.create.review")
                }
            }
            if model.coordinator.pending != nil {
                Button("team.checkOutcome") {
                    let permit = model.captureRun()
                    Task { await model.run(permit: permit) { await model.coordinator.checkOutcome() } }
                }
                    .disabled(model.running || !model.coordinator.canSimulate).accessibilityIdentifier("team.checkOutcome")
            }
        }.cyPageTitle("team.create")
            .task { await model.run { await model.coordinator.loadCreation(ownerID: activityID) } }
            .onChange(of: model.coordinator.creation?.sizes ?? [], initial: true) { _, sizes in
                // Keep a still-valid draft choice. Never invent a capacity while
                // eligibility is loading, absent or no permitted size exists.
                guard !sizes.contains(size), let first = sizes.first else { return }
                size = first
            }
            .cySheet(item: model.reviewBinding) { TeamReviewSheet(model: model, review: $0).cySheet() }
            .onDisappear { model.leave() }
        .themeDomain(.player)
    }

    private func reviewButton(_ context: TeamCreationContext) -> some View {
        Button("team.create.review") {
            if model.coordinator.canSubmit {
                model.prepare(.create(context: context, size: size, inviteOnly: inviteOnly))
            } else {
                model.refuseClosedLease()
            }
        }
        .disabled(model.actionLocked || !context.sizes.contains(size))
        .accessibilityIdentifier("team.create.review")
    }

    private var leaseClosedNote: some View {
        Text("team.create.leaseClosed")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("team.create.leaseClosed")
    }
}
