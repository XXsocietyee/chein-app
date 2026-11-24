import SwiftUI

/// No reads or retained roster state. The owning page supplies its exact row
/// renderer and existing action guards from the current authorized snapshot.
@MainActor struct MerchantOperatorRosterSections<RowContent: View>: View {
    let roster: MerchantOperatorRoster
    let access: MerchantBusinessAccess
    @Binding var detailsExpanded: Bool
    let rowContent: (MerchantBusinessRecord) -> RowContent

    init(roster: MerchantOperatorRoster, access: MerchantBusinessAccess, detailsExpanded: Binding<Bool>,
         @ViewBuilder rowContent: @escaping (MerchantBusinessRecord) -> RowContent) {
        self.roster = roster; self.access = access; self.rowContent = rowContent
        _detailsExpanded = detailsExpanded
    }

    var body: some View {
        Group {
            if access.canManageOperators {
                Section("merchant.operatorRoster.currentAccess") {
                    if let name = access.name, !name.isEmpty {
                        LabeledContent("merchant.business.field.storeName", value: name)
                    }
                    LabeledContent("merchant.business.role") {
                        Text(LocalizedStringKey("merchant.business.role." + access.role))
                    }
                    DisclosureGroup("merchant.operatorRoster.accessDetails", isExpanded: $detailsExpanded) {
                        LabeledContent("merchant.business.storeID", value: String(access.merchantID))
                        LabeledContent("merchant.business.field.roleCode", value: access.role)
                    }.accessibilityIdentifier("merchant.operatorRoster.accessDetails")
                }
                Section("merchant.operatorRoster.members") {
                    LabeledContent("merchant.operatorRoster.loadedMembers", value: String(roster.activeMembers.count))
                        .monospacedDigit()
                        .accessibilityIdentifier("merchant.operatorRoster.memberCount")
                    Text("merchant.operatorRoster.loadedScope").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    if roster.activeMembers.isEmpty {
                        Text("merchant.operatorRoster.membersEmpty").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("merchant.operatorRoster.membersEmpty")
                    }
                    ForEach(roster.activeMembers) { row in rowContent(row) }
                }
                Section("merchant.operatorRoster.invites") {
                    LabeledContent("merchant.operatorRoster.loadedInvites", value: String(roster.pendingInvites.count))
                        .monospacedDigit()
                        .accessibilityIdentifier("merchant.operatorRoster.inviteCount")
                    if roster.pendingInvites.isEmpty {
                        Text("merchant.operatorRoster.invitesEmpty").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                            .accessibilityIdentifier("merchant.operatorRoster.invitesEmpty")
                    }
                    ForEach(roster.pendingInvites) { row in rowContent(row) }
                }
                if roster.hasHistory {
                    Section("merchant.operatorRoster.history") {
                        Text("merchant.operatorRoster.historyScope").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        if !roster.previousMembers.isEmpty {
                            DisclosureGroup("merchant.operatorRoster.previousMembers") {
                                ForEach(roster.previousMembers) { row in rowContent(row) }
                            }.frame(minHeight: 44)
                                .accessibilityIdentifier("merchant.operatorRoster.previousMembers")
                        }
                        if !roster.previousInvites.isEmpty {
                            DisclosureGroup("merchant.operatorRoster.previousInvites") {
                                ForEach(roster.previousInvites) { row in rowContent(row) }
                            }.frame(minHeight: 44)
                                .accessibilityIdentifier("merchant.operatorRoster.previousInvites")
                        }
                    }
                }
            } else {
                // Parity team P1: one message per state; the self-role card already says what this role can do.
                MerchantOperatorSelfRoleCard(access: access)
            }
        }
    }
}
