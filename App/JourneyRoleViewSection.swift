import SwiftUI

/// Renders only the validated encounter projection. There is no role picker,
/// team-order inference or fallback to author configuration in player UI.
@MainActor struct JourneyRoleViewSection: View {
    @Bindable var model: JourneyRoleViewCoordinator
    var body: some View {
        Group {
            switch model.status {
            case .idle, .absent: EmptyView()
            case .loading:
                Section("roleView.title") { CYSkeleton().accessibilityLabel(Text("roleView.loading")) }
            case .closed:
                CYPillButton("roleView.open", style: .secondary) { Task { await model.refresh() } }.listRowBackground(Color.clear).accessibilityIdentifier("roleView.reopen")
            case .unavailable:
                Section("roleView.title") {
                    Text("roleView.unavailable").accessibilityIdentifier("roleView.unavailable")
                    CYPillButton("roleView.refresh", style: .secondary) { Task { await model.refresh() } }.listRowBackground(Color.clear).accessibilityIdentifier("roleView.refresh")
                }
            case .ready:
                if let projection = model.projection {
                    Section("roleView.title") {
                        if projection.assignment == .missing {
                            CYStatusChip("roleView.missing", tone: .neutral, systemImage: "person.crop.circle.badge.questionmark")
                                .accessibilityIdentifier("roleView.missing")
                            Text("roleView.missingDetail").font(.footnote)
                        } else {
                            Text(LocalizedStringKey("roleView.assignment." + projection.assignment.rawValue)).font(.headline)
                                .accessibilityAddTraits(.isHeader)
                                .accessibilityIdentifier("roleView.assignment")
                            if let other = projection.otherRoleLabel {
                                LabeledContent("roleView.otherRole") { Text(verbatim: other) }
                            }
                            ForEach(projection.views) { view in
                                VStack(alignment: .leading, spacing: 8) {
                                    if projection.assignment == .solo { Text(LocalizedStringKey("roleView.assignment." + view.roleID)).font(.headline).accessibilityAddTraits(.isHeader) }
                                    if !view.title.isEmpty { Text(verbatim: view.title).font(.title3).accessibilityAddTraits(.isHeader).accessibilityIdentifier("roleView.title." + view.roleID) }
                                    if !view.body.isEmpty { Text(verbatim: view.body).accessibilityIdentifier("roleView.body." + view.roleID) }
                                    ForEach(view.items) { item in
                                        VStack(alignment: .leading, spacing: 4) { Text(verbatim: item.label).font(.headline); Text(verbatim: item.text) }
                                            .accessibilityElement(children: .combine)
                                            .accessibilityIdentifier("roleView.item." + view.roleID + "." + String(item.id))
                                    }
                                }.padding(.vertical, 4)
                            }
                        }
                        Text("roleView.serverAssigned").font(.caption).foregroundStyle(.secondary)
                        CYPillButton("roleView.refresh", style: .secondary) { Task { await model.refresh() } }.listRowBackground(Color.clear).accessibilityIdentifier("roleView.refresh")
                        CYPillButton("roleView.close", style: .tertiary) { model.dismiss() }.listRowBackground(Color.clear).accessibilityIdentifier("roleView.close")
                    }.privacySensitive()
                }
            }
        }
    }
}

/// Stable, node-scoped host for chapter-inline gameplay. Its task is attached to
/// an actual stack, never an initially empty conditional Group.
@MainActor struct JourneyRoleViewInlineHost: View {
    @Bindable var model: JourneyRoleViewCoordinator
    let sessionIdentity: String?
    let runID: Int?
    let stateVersion: Int?
    @Environment(\.scenePhase) private var scenePhase
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { JourneyRoleViewSection(model: model) }
            .frame(maxWidth: .infinity, alignment: .leading)
            .privacySensitive()
            .task(id: [sessionIdentity, runID.map(String.init), stateVersion.map(String.init)]) {
                await model.load(expectedRunID: runID, minimumStateVersion: stateVersion)
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await model.load(expectedRunID: runID, minimumStateVersion: stateVersion) } }
                else { model.close() }
            }
            .onDisappear { model.close() }
    }
}
