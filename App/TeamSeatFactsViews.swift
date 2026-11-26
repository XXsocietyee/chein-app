import SwiftUI

/// U06-01 seat facts (mini `.tm-seats` chips): 持有效票 / 票已失效 / 待审申请 / 还可加入 plus the
/// invitation deadline. Every value is the server's; an unknown row is omitted, never drawn as 0.
struct TeamSeatFactsCard: View {
    let detail: TeamDetail
    @Environment(\.locale) private var locale
    private var rows: [TeamSeatPresentation.Row] { TeamSeatPresentation.rows(detail.seats) }
    private var invite: TeamSeatPresentation.InviteLine? { TeamSeatPresentation.inviteLine(detail.invite) }
    var body: some View {
        if !rows.isEmpty || invite != nil {
            // A List row of system label/value pairs (the List draws the grouped cell).
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                ForEach(rows) { row in
                    LabeledContent {
                        Text(verbatim: String(row.value))
                            .monospacedDigit()
                            .foregroundStyle(row.warning ? Color.red : Color.primary)
                    } label: {
                        Text(LocalizedStringKey(row.labelKey))
                            .foregroundStyle(row.warning ? Color.red : Color.primary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("teamSeats.row.\(row.id)")
                }
                if let invite { inviteLine(invite) }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("teamSeats.card")
        }
    }
    @ViewBuilder private func inviteLine(_ line: TeamSeatPresentation.InviteLine) -> some View {
        switch line {
        case .unavailable:
            Label("team.invite.unavailable", systemImage: "clock.badge.xmark")
                .font(.subheadline).foregroundStyle(.orange)
                .accessibilityIdentifier("teamSeats.invite")
        case .expires(let raw):
            let chinese = locale.language.languageCode?.identifier == "zh"
            if let text = TeamPagePresentation.startText(raw, chinese: chinese) {
                Label { Text("team.invite.expires \(text)") } icon: { Image(systemName: "clock") }
                    .font(.subheadline).foregroundStyle(.secondary)
                    .accessibilityIdentifier("teamSeats.invite")
            }
        }
    }
}

/// U06-01/U06-03: the viewer's own relationship, kept apart from story roles and host permissions.
/// On an invitation page this is the server's join hint; the join button stays and the write decides.
struct TeamViewerRelationshipLine: View {
    let detail: TeamDetail
    let invitation: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            if !invitation, let duty = TeamSeatPresentation.dutyKey(detail.viewer, detail: detail) {
                Label(LocalizedStringKey(duty), systemImage: duty == "team.viewer.captain" ? "crown" : "person")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(duty == "team.viewer.captain" ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    .accessibilityIdentifier("teamViewer.duty")
                Text("team.viewer.dutyScope")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if invitation, let status = TeamSeatPresentation.applicationKey(detail.viewer) {
                Text(LocalizedStringKey(status))
                    .font(.subheadline).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamViewer.application")
            }
            if invitation, detail.joined != true, let hint = TeamSeatPresentation.blockerKey(detail.viewer, entry: .join) {
                Label(LocalizedStringKey(hint), systemImage: "exclamationmark.circle")
                    .font(.subheadline).foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamViewer.joinHint")
            }
        }
    }
}

/// C-J6 (MP team/join wxml:39-42, team-seats.js joinedSeats/openSeats): one row of seats on the join page.
/// Joined seats are filled, open seats dashed; each side is capped at 12. Open seats come from the server's
/// `seats.available`, else `maxMembers − joinedCount`; unknown counts draw nothing.
struct TeamJoinSeatRow: View {
    let detail: TeamDetail
    @ScaledMetric(relativeTo: .body) private var seat: CGFloat = 44

    private var joined: Int { min(max(detail.team.joinedCount ?? 0, 0), 12) }
    private var open: Int {
        if let available = detail.seats?.available { return min(max(available, 0), 12) }
        guard let maxMembers = detail.team.maxMembers, let count = detail.team.joinedCount else { return 0 }
        return min(max(maxMembers - count, 0), 12)
    }

    var body: some View {
        if joined + open > 0 {
            FlowSeats(spacing: CYSpacing.sm) {
                ForEach(0..<(joined + open), id: \.self) { index in
                    let on = index < joined
                    ZStack {
                        if on {
                            Circle().fill(Color.accentColor.opacity(0.14))
                        } else {
                            Circle().strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        }
                        Image(systemName: on ? "person.fill" : "plus")
                            .foregroundStyle(on ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                    }
                    .frame(width: seat, height: seat)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("fixr3.team.seats.a11y \(joined) \(open)"))
            .accessibilityIdentifier("teamJoin.seats")
        }
    }
}

/// Wraps seat circles onto as many lines as the width needs.
private struct FlowSeats: Layout {
    var spacing: CGFloat
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? .infinity
        var x: CGFloat = 0, y: CGFloat = 0, row: CGFloat = 0, widest: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width { y += row + spacing; x = 0; row = 0 }
            x += size.width + spacing; row = max(row, size.height); widest = max(widest, x - spacing)
        }
        return CGSize(width: proposal.width ?? widest, height: y + row)
    }
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, row: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x > bounds.minX, x + size.width > bounds.maxX { y += row + spacing; x = bounds.minX; row = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; row = max(row, size.height)
        }
    }
}

/// Round 4 image parity (MP team/detail wxml:38-46, U06-01 `tm-seat-strip`): on the team page each member is a seat
/// showing `memberAvatar || /images/d_profile.png`, the captain's seat carries 队长, and open seats are dashed circles.
/// Core decodes no member avatar yet, so every seat shows the MP default `d_profile`. Open seats use the same server
/// facts as `TeamJoinSeatRow` (`seats.available`, else max − joined); unknown counts draw no open seat.
struct TeamDetailSeatStrip: View {
    let detail: TeamDetail
    @ScaledMetric(relativeTo: .body) private var seat: CGFloat = 44

    private var members: [TeamMember] { Array(detail.members.prefix(12)) }
    private var open: Int {
        if let available = detail.seats?.available { return min(max(available, 0), 12) }
        guard let maxMembers = detail.team.maxMembers, let count = detail.team.joinedCount else { return 0 }
        return min(max(maxMembers - count, 0), 12)
    }

    var body: some View {
        if !members.isEmpty || open > 0 {
            FlowSeats(spacing: CYSpacing.sm) {
                ForEach(Array(members.enumerated()), id: \.offset) { _, member in
                    VStack(spacing: CYSpacing.xs) {
                        MPAsset.AvatarDefault.dProfile
                            .resizable()
                            .scaledToFill()
                            .frame(width: seat, height: seat)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                        if member.isCaptain {
                            Text("fixr3.team.seat.captain").font(.caption.weight(.semibold)).foregroundStyle(.tint)
                        }
                    }
                }
                ForEach(0..<open, id: \.self) { _ in
                    ZStack {
                        Circle().strokeBorder(Color.secondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        Image(systemName: "plus").foregroundStyle(.secondary).accessibilityHidden(true)
                    }
                    .frame(width: seat, height: seat)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("fixr3.team.seats.a11y \(members.count) \(open)"))
            .accessibilityIdentifier("teamDetail.seats")
        }
    }
}
