import SwiftUI

/// Public collaboration progress from the existing PLAYER projection. This view
/// has no member navigation, location, evidence, completion or invitation action.
struct PlayPlayerTeamStatusView: View {
    let state: PlayPlayerTeamState
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
                            if let name = member.displayName { Text(verbatim: name).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                            else { Text("playerTeam.teammate").font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary) }
                            if let role = member.roleCode {
                                LabeledContent("playerTeam.role") { Text(verbatim: role) }.font(CYTypography.meta)
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
    }
}
