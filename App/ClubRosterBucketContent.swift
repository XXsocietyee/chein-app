import SwiftUI

@MainActor enum ClubRosterInteraction {
    static func formRoute(_ target: ClubRosterCorrectionRoute, snapshot: ClubGovernanceSnapshot?, context: ClubGovernanceReadContext,
                          snapshotGeneration: UInt64, readGeneration: UInt64, access: any ClubGovernanceAccess) -> ClubGovernanceFormRoute? {
        guard access.isConfigured, context.identity?.isSignedIn == true, context.identity == access.identity,
              context.authorizationGeneration == access.authorizationGeneration, context.accessIdentity == ObjectIdentifier(access),
              snapshotGeneration == readGeneration,
              target.isCurrent(snapshot: snapshot, context: context, snapshotGeneration: snapshotGeneration, namespace: access.storageNamespace) else { return nil }
        return .init(operation: .correctAttendance, scope: target.scope,
                     seed: ["expectedVersion": .integer(target.version), "arrived": .bool(target.arrived)])
    }
}

@MainActor struct ClubRosterBucketContent: View {
    let roster: ClubRosterPresentation
    let context: ClubGovernanceReadContext
    let snapshotGeneration: UInt64
    let namespace: String
    @Binding var selected: ClubRosterBucket
    let openCorrection: (ClubRosterCorrectionRoute) -> Void
    @Environment(\.locale) private var locale
    var body: some View {
        // verify-r1 2.6 / MC-25: the roster card (count and who signed up, with status) heads 报名名册.
        Section {
            ClubRosterCard(model: .roster(roster, locale: locale), coverSeed: "roster-\(roster.scope.activityID ?? 0)")
                .accessibilityIdentifier("club.roster.card")
        }
        Section {
            Text("clubOpsEvent.roster.title \(roster.rosterTotal)", tableName: "ClubOpsEvent").cyText(.cardTitle)
                .accessibilityIdentifier("club.roster.total")
            Text("club.roster.totalNote").cyText(.bodyCompact).foregroundStyle(.secondary)
            Text("club.roster.privacy").cyText(.bodyCompact)
            ForEach(ClubRosterBucket.allCases, id: \.self) { bucket in
                LabeledContent(LocalizedStringKey(bucket.localizationKey), value: String(roster.count(in: bucket)))
                    .accessibilityIdentifier("club.roster.count." + bucket.rawValue)
            }
            Picker("club.gov.filter", selection: $selected) {
                ForEach(ClubRosterBucket.allCases, id: \.self) { bucket in Text(LocalizedStringKey(bucket.localizationKey)).tag(bucket) }
            }.cyAdaptiveSegmented().accessibilityIdentifier("club.roster.filter")
            // Mini CU-C-73: the operable window is stated in place only while corrections are closed.
            if roster.correctionOperable == false {
                Group {
                    if let range = ClubOpsEventClock.correctionRange(start: roster.correctionStart, end: roster.correctionEnd, locale: locale) {
                        Text("clubOpsEvent.roster.window \(range)", tableName: "ClubOpsEvent")
                    } else { Text("clubOpsEvent.roster.windowGeneric", tableName: "ClubOpsEvent") }
                }.font(.subheadline).foregroundStyle(.orange).accessibilityIdentifier("club.roster.windowClosed")
            }
        }
        Section(LocalizedStringKey(selected.localizationKey)) {
            if roster.members(in: selected).isEmpty { Text("clubOpsEvent.roster.emptyBucket", tableName: "ClubOpsEvent").accessibilityIdentifier("club.roster.emptyBucket") }
            ForEach(roster.members(in: selected)) { member in
                VStack(alignment: .leading, spacing: 8) {
                    if let name = member.nickname { Text(verbatim: name).cyText(.cardTitle) } else { Text("club.roster.unnamed").cyText(.cardTitle) }
                    Text("club.memberNumber \(member.id)").cyText(.meta).foregroundStyle(.secondary)
                    if let phone = member.phone, let url = URL(string: "tel:\(phone)") {
                        Link(destination: url) { Text(verbatim: phone) }
                            .accessibilityIdentifier("club.roster.call.\(member.id)")
                    }
                    if let state = member.waitlistState { Text(verbatim: state) }
                    if let route = roster.correctionRoute(memberID: member.id, bucket: selected, context: context,
                                                          snapshotGeneration: snapshotGeneration, namespace: namespace) {
                        Button { openCorrection(route) } label: { correctionLabel(route.arrived) }
                            .buttonStyle(.borderless).accessibilityIdentifier("club.roster.correct.\(member.id)")
                    } else if let arrived = ClubOpsEventAttendance.arrivedTarget(selected), roster.correctionOperable == false {
                        Button {} label: { correctionLabel(arrived) }.buttonStyle(.borderless).disabled(true)
                            .accessibilityIdentifier("club.roster.correct.\(member.id)")
                        Text("clubOpsEvent.roster.closed", tableName: "ClubOpsEvent").cyText(.meta).foregroundStyle(.secondary)
                    } else if selected != .waitlist && member.correctionVersion == nil {
                        Text("club.roster.versionUnknown").cyText(.bodyCompact).accessibilityIdentifier("club.roster.versionUnknown")
                    }
                }.accessibilityIdentifier("club.roster.member.\(member.id)")
            }
        }
    }
    private func correctionLabel(_ arrived: Bool) -> Text {
        Text(arrived ? "clubOpsEvent.roster.markArrived" : "clubOpsEvent.roster.markAbsent", tableName: "ClubOpsEvent")
    }
}
