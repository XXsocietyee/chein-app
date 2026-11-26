import SwiftUI

/// CLB-event-ops-02 (MP pages/club/event-ops/index.wxml:79-113): the 本场名册 bucket tabs and member cards sit
/// inline on the hub, under the 本场名册 · N 人 row. Each card shows the name, the waitlist state or phone, a call
/// link and the 标记到场 / 更正未到 action. The correction opens the full roster page, which owns the reviewed
/// attendance write (ClubRosterBucketContent + ClubGovernanceReadView), so the hub stays read-only.
@MainActor struct ClubOpsEventInlineRoster<Correction: View>: View {
    let roster: ClubRosterPresentation
    @Binding var selected: ClubRosterBucket
    let correction: () -> Correction
    var body: some View {
        Section {
            // MP cy-tabs variant="chip" (wxml:88-89).
            Picker("club.gov.filter", selection: $selected) {
                ForEach(ClubRosterBucket.allCases, id: \.self) { bucket in
                    Text(LocalizedStringKey(bucket.localizationKey)).tag(bucket)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("clubOpsEvent.roster.tabs")
            let members = roster.members(in: selected)
            if members.isEmpty {
                // MP wxml:93 这一段暂时没有成员.
                Text("clubOpsEvent.roster.emptyBucket", tableName: "ClubOpsEvent")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("clubOpsEvent.roster.inlineEmpty")
            }
            ForEach(members) { member in card(member) }
        }
    }
    private func card(_ member: ClubRosterMember) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                if let name = member.nickname {
                    Text(verbatim: name)
                } else {
                    Text("club.roster.unnamed")
                }
                // MP wxml:98-99: waitlist tab → the waitlist state; other tabs → the phone.
                if selected == .waitlist, let state = member.waitlistState {
                    Text(verbatim: state).font(.subheadline).foregroundStyle(.secondary)
                } else if let phone = member.phone {
                    Text(verbatim: phone).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 8)
            if let phone = member.phone, let url = URL(string: "tel:" + phone) {
                // MP wxml:101-104 member-call.
                Link(destination: url) {
                    Image(systemName: "phone").imageScale(.medium)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("clubOpsEvent.roster.call"))
                .accessibilityIdentifier("clubOpsEvent.roster.call.\(member.id)")
            }
            if selected != .waitlist {
                // MP wxml:105-109: 更正未到 on the arrived tab, 标记到场 elsewhere.
                NavigationLink {
                    correction()
                } label: {
                    Text(LocalizedStringKey(selected == .arrived ? "clubOpsEvent.roster.markAbsent" : "clubOpsEvent.roster.markArrived"), tableName: "ClubOpsEvent")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .fixedSize()
                .disabled(roster.correctionOperable == false)
                .accessibilityIdentifier("clubOpsEvent.roster.correct.\(member.id)")
            }
        }
        .accessibilityIdentifier("clubOpsEvent.roster.member.\(member.id)")
    }
}
