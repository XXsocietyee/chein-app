import SwiftUI

/// CLB-governance-01 (MP pages/club/governance/index.wxml:89-122): the manage page is one page — 治理记录 on top,
/// then the 对成员执行 card: 选择成员 → 选择期限 → 封禁原因 (填写原因并封禁) and, for the owner, 转让主理人.
/// The card reads the same `.members` governance read the members page uses. Ban and transfer still open the
/// reviewed command form (reason, confirm, server write), seeded with the picked member and duration.
/// A failed members read keeps the old 成员 link so the actions stay reachable.
@MainActor struct ClubOpsMemberActionCard: View {
    let clubID: Int?
    let identity: ClubReadIdentity?
    let access: any ClubGovernanceAccess
    let ban: (ClubOpsGovernanceMember, Int) -> AnyView
    let transfer: (ClubOpsGovernanceMember) -> AnyView
    let fallback: AnyView
    @Environment(\.clubFocusMemberID) private var focusMemberID
    @State private var roster: ClubOpsGovernanceMembers?
    @State private var canBan = false
    @State private var failed = false
    @State private var selectedID: Int?
    @State private var days = String(ClubGovernanceFormDraft.defaultBanDays)
    private var selected: ClubOpsGovernanceMember? { roster?.members.first { $0.id == selectedID } }
    private var banDays: Int { Int(days) ?? ClubGovernanceFormDraft.defaultBanDays }
    var body: some View {
        Group {
            if let roster, !roster.members.isEmpty {
                // MP wxml:91 wx:if members.length — the card is hidden when there is nobody to act on.
                Section {
                    Picker(selection: $selectedID) {
                        Text("club.rolePicker.unselected").tag(Int?.none)
                        ForEach(roster.members) { member in
                            ClubOpsGovernanceCopy.member(member.nickname, id: member.id).tag(Int?.some(member.id))
                        }
                    } label: { Text("club.rolePicker.member") }
                    .accessibilityIdentifier("clubOpsGov.card.member")
                    if canBan {
                        ClubOpsBanDurationPicker(days: $days)
                        LabeledContent {
                            if let selected {
                                ban(selected, banDays)
                            } else {
                                Text("clubOpsGov.card.banAction").foregroundStyle(.tertiary)
                            }
                        } label: { Text("clubOpsGov.card.banReason") }
                        .accessibilityIdentifier("clubOpsGov.card.ban")
                    }
                    if roster.viewerIsOwner {
                        LabeledContent {
                            if let selected {
                                transfer(selected)
                            } else {
                                Text("club.rolePicker.member").foregroundStyle(.tertiary)
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                                Text("club.gov.action.transferOwner")
                                ClubOpsGovernanceCopy.text("clubOpsGov.transfer.hint").font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                        .accessibilityIdentifier("clubOpsGov.card.transfer")
                    }
                } header: { ClubOpsGovernanceCopy.text("clubOpsGov.members.title") }
                .accessibilityIdentifier("clubOpsGov.card")
            } else if failed {
                Section { fallback }
            }
        }
        .task(id: TaskKey(clubID: clubID, identity: identity, authorization: access.authorizationGeneration)) { await load() }
    }
    private struct TaskKey: Equatable {
        let clubID: Int?
        let identity: ClubReadIdentity?
        let authorization: UUID?
    }
    private func load() async {
        roster = nil; failed = false
        guard let clubID, clubID > 0, identity?.isSignedIn == true, identity == access.identity, access.isConfigured else {
            failed = true; return
        }
        let expected = identity, generation = access.authorizationGeneration
        let scope = ClubGovernanceScope(clubID: clubID)
        do {
            let snapshot = try await access.read(.members, scope: scope, options: [:]) {
                guard expected == access.identity, generation == access.authorizationGeneration, !Task.isCancelled else { throw CancellationError() }
            }
            guard snapshot.operation == .members, snapshot.scope == scope else { failed = true; return }
            let members = try ClubOpsGovernanceMembers(snapshot: snapshot)
            roster = members
            canBan = snapshot.permissions?.canGovernMembers == true
            // CLB-G16: a `memberId` link preselects that member (MP governance js onLoad).
            if let focusMemberID, members.members.contains(where: { $0.id == focusMemberID }) { selectedID = focusMemberID }
        } catch is CancellationError {
            return
        } catch {
            failed = true
        }
    }
}
