import SwiftUI

/// Present only from an activity registration, never a nearby-team, route-ticket or club ID.
@MainActor struct TeamCreateView: View {
    let activityID: Int
    @StateObject private var model: TeamScreenModel
    @State private var size = 2
    @State private var inviteOnly = false
    @Environment(\.cyPalette) private var palette
    init(activityID: Int, coordinator: TeamCoordinator) { self.activityID = activityID; _model = StateObject(wrappedValue: TeamScreenModel(coordinator)) }
    var body: some View {
        Form {
            Section { TeamNotice(coordinator: model.coordinator) }
            if model.running { CYLoadingStateView(rows: 1).accessibilityLabel(Text("team.loading")) }
            if let context = model.coordinator.creation {
                Section("team.create.activity") { Text(verbatim: context.title).cyText(.cardTitle).foregroundStyle(palette.textPrimary).fixedSize(horizontal: false, vertical: true) }
                Section("team.create.settings") {
                    Picker("team.size", selection: $size) { ForEach(context.sizes, id: \.self) { Text(verbatim: "\($0)").tag($0) } }
                        .accessibilityIdentifier("team.create.size")
                    Toggle("team.invitationOnly", isOn: $inviteOnly).accessibilityIdentifier("team.create.inviteOnly")
                    Text(inviteOnly ? "team.create.privateHelp" : "team.create.publicHelp").cyText(.meta).foregroundStyle(palette.textSecondary)
                }.disabled(model.actionLocked)
                Section {
                    Text("team.create.consequence").fixedSize(horizontal: false, vertical: true)
                    reviewButton(context)
                    if !model.coordinator.canSubmit { leaseClosedNote }
                }
            } else if !model.coordinator.canSubmit, !model.running {
                Section {
                    leaseClosedNote
                    CYPillButton("team.create.review") { model.refuseClosedLease() }
                        .disabled(model.actionLocked)
                        .accessibilityIdentifier("team.create.review")
                }
            }
            if model.coordinator.pending != nil {
                CYPillButton("team.checkOutcome", style: .secondary) {
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
            .sheet(item: model.reviewBinding) { TeamReviewSheet(model: model, review: $0).cySheet() }
            .onDisappear { model.leave() }
        .cyDomainScreen(.player)
    }

    private func reviewButton(_ context: TeamCreationContext) -> some View {
        CYPillButton("team.create.review") {
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
            .cyText(.meta)
            .foregroundStyle(palette.textSecondary)
            .accessibilityIdentifier("team.create.leaseClosed")
    }
}
