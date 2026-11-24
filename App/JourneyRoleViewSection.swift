import SwiftUI

/// Renders only the validated encounter projection. There is no role picker,
/// team-order inference or fallback to author configuration in player UI.
@MainActor struct JourneyRoleViewSection: View {
    @Bindable var model: JourneyRoleViewCoordinator
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Group {
            switch model.status {
            case .idle, .absent: EmptyView()
            case .loading:
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYSectionHeader("roleView.title")
                        Text("roleView.loading")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                        CYSkeleton()
                            .accessibilityElement(children: .ignore)
                            .accessibilityLabel(Text("roleView.loading"))
                    }
                    .listRowInsets(Self.gutter)
                }
            case .closed:
                Button("roleView.open") { Task { await model.refresh() } }
                    .buttonStyle(CYPillButtonStyle())
                    .accessibilityIdentifier("roleView.reopen")
                    .listRowInsets(Self.gutter)
                    .listRowBackground(Color.clear)
            case .unavailable:
                Section {
                    VStack(alignment: .leading, spacing: CYSpacing.md) {
                        CYSectionHeader("roleView.title")
                        Text("roleView.unavailable")
                            .cyText(.body)
                            .foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityIdentifier("roleView.unavailable")
                    }
                    .listRowInsets(Self.gutter)
                    Button("roleView.refresh") { Task { await model.refresh() } }
                        .buttonStyle(CYPillButtonStyle())
                        .accessibilityIdentifier("roleView.refresh")
                        .e1ActionRow()
                }
            case .ready:
                if let projection = model.projection {
                    Section {
                        VStack(alignment: .leading, spacing: CYSpacing.md) {
                            CYSectionHeader("roleView.title")
                            readyBody(projection)
                        }
                        .listRowInsets(Self.gutter)
                        Button("roleView.refresh") { Task { await model.refresh() } }
                            .buttonStyle(CYPillButtonStyle())
                            .accessibilityIdentifier("roleView.refresh")
                            .e1ActionRow()
                        Button("roleView.close") { model.dismiss() }
                            .buttonStyle(CYPillButtonStyle(style: .tertiary))
                            .accessibilityIdentifier("roleView.close")
                            .e1ActionRow()
                    }
                    .privacySensitive()
                }
            }
        }
    }

    @ViewBuilder private func readyBody(_ projection: JourneyRoleProjection) -> some View {
        if projection.assignment == .missing {
            CYEmptyState(
                systemImage: "person.crop.circle.badge.questionmark",
                "roleView.missing",
                detail: "roleView.missingDetail",
                messageIdentifier: "roleView.missing"
            )
        } else {
            Group {
                if let own = projection.roleLabel { Text("roleView.yourRole \(own)") }
                else { Text(LocalizedStringKey("roleView.assignment." + projection.assignment.rawValue)) }
            }
            .font(.headline)
            .foregroundStyle(CYColor.textPrimary)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("roleView.assignment")
            if !projection.otherRoleLabels.isEmpty {
                LabeledContent("roleView.otherRole") {
                    Text(verbatim: projection.otherRoleLabels.joined(separator: "、"))
                }
                .font(.body)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityIdentifier("roleView.otherRoles")
            }
            ForEach(projection.views) { view in
                roleCard(view, solo: projection.assignment == .solo)
            }
            if projection.assignment != .solo {
                Text("roleView.teammatesOther")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("roleView.teammatesOther")
            }
        }
        Text("roleView.serverAssigned")
            .cyText(.meta)
            .foregroundStyle(CYColor.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private func roleCard(_ view: JourneyRoleContent, solo: Bool) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            if solo {
                Group {
                    if let label = view.label { Text(verbatim: label) }
                    else { Text(LocalizedStringKey("roleView.assignment." + view.roleID)) }
                }
                .font(.headline)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("roleView.heading." + view.roleID)
            }
            if !view.title.isEmpty {
                Text(verbatim: view.title)
                    .cyText(.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("roleView.title." + view.roleID)
            }
            if !view.body.isEmpty {
                Text(verbatim: view.body)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("roleView.body." + view.roleID)
            }
            ForEach(view.items) { item in
                CYListRow(
                    verbatim: item.label.trimmingCharacters(in: .whitespacesAndNewlines),
                    meta: item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : item.text,
                    trailing: .none
                ) {
                    CYRowIcon(systemImage: "text.alignleft")
                }
                .accessibilityIdentifier("roleView.item." + view.roleID + "." + String(item.id))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, typeSize.isAccessibilitySize ? CYSpacing.sm : 0)
    }

    private static var gutter: EdgeInsets {
        EdgeInsets(top: CYSpacing.md, leading: CYSpacing.pageHorizontal, bottom: CYSpacing.sm, trailing: CYSpacing.pageHorizontal)
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
        VStack(alignment: .leading, spacing: CYSpacing.md) { JourneyRoleViewSection(model: model) }
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
