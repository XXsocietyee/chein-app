import SwiftUI

/// Public collaboration progress from the existing PLAYER projection. This view
/// has no member navigation, location, evidence, completion or invitation action.
struct PlayPlayerTeamStatusView: View {
    let state: PlayPlayerTeamState
    /// R-island: the run's team id; when set, member changes feed the shared team-status Live Activity.
    var planScope: String? = nil
    var body: some View {
        Group {
            switch state {
            case .empty: EmptyView()
            case .unconfirmed:
                Section("playerTeam.title") {
                    CYStatusChip("playerTeam.unconfirmed", tone: .neutral, systemImage: "questionmark.circle")
                        .accessibilityIdentifier("playerTeam.unconfirmed")
                }
            case .members(let members):
                Section {
                    ForEach(members) { member in
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            if let name = member.displayName { Text(verbatim: name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                            else { Text("playerTeam.teammate").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary) }
                            if let role = member.roleCode {
                                LabeledContent("playerTeam.role") { Text(verbatim: role) }.cyText(.meta)
                            }
                            CYStatusChip(LocalizedStringKey(member.status.titleKey), tone: .info)
                                .accessibilityIdentifier("playerTeam.status." + member.status.rawValue.lowercased())
                        }.fixedSize(horizontal: false, vertical: true)
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("playerTeam.member.\(member.id)")
                    }
                } header: {
                    Text("playerTeam.title")
                } footer: {
                    Text("playerTeam.privacy")
                }
            }
        }.privacySensitive().accessibilityIdentifier("playerTeam.readback")
        .onChange(of: state, initial: true) { _, value in
            guard let planScope, case .members(let members) = value else { return }
            QuestPlanActivityCenter.shared.teamStatus(scope: planScope, title: nil, members: members)
        }
        .onDisappear { if let planScope { QuestPlanActivityCenter.shared.teamStatus(scope: planScope, title: nil, members: nil) } }
    }
}
