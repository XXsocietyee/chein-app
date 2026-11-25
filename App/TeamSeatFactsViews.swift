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
            CYCard(padding: CYSpacing.md) {
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    ForEach(rows) { row in
                        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                            Text(LocalizedStringKey(row.labelKey))
                                .cyText(.body)
                                .foregroundStyle(row.warning ? CYColor.dangerText : CYColor.textSecondary)
                            Spacer(minLength: CYSpacing.sm)
                            Text(verbatim: String(row.value))
                                .cyText(.numericBody).monospacedDigit()
                                .foregroundStyle(row.warning ? CYColor.dangerText : CYColor.textPrimary)
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("teamSeats.row.\(row.id)")
                    }
                    if let invite { inviteLine(invite) }
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("teamSeats.card")
        }
    }
    @ViewBuilder private func inviteLine(_ line: TeamSeatPresentation.InviteLine) -> some View {
        switch line {
        case .unavailable:
            Label("team.invite.unavailable", systemImage: "clock.badge.xmark")
                .cyText(.meta).foregroundStyle(CYColor.warningText)
                .accessibilityIdentifier("teamSeats.invite")
        case .expires(let raw):
            let chinese = locale.language.languageCode?.identifier == "zh"
            if let text = TeamPagePresentation.startText(raw, chinese: chinese) {
                Label { Text("team.invite.expires \(text)") } icon: { Image(systemName: "clock") }
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
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
                CYStatusChip(LocalizedStringKey(duty), tone: duty == "team.viewer.captain" ? .info : .neutral,
                             systemImage: duty == "team.viewer.captain" ? "crown" : "person")
                    .accessibilityIdentifier("teamViewer.duty")
                Text("team.viewer.dutyScope")
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if invitation, let status = TeamSeatPresentation.applicationKey(detail.viewer) {
                Text(LocalizedStringKey(status))
                    .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamViewer.application")
            }
            if invitation, detail.joined != true, let hint = TeamSeatPresentation.blockerKey(detail.viewer, entry: .join) {
                Label(LocalizedStringKey(hint), systemImage: "exclamationmark.circle")
                    .cyText(.meta).foregroundStyle(CYColor.warningText)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("teamViewer.joinHint")
            }
        }
    }
}

/// C-J6 (MP team/join wxml:39-42, team-seats.js joinedSeats/openSeats): one row of seats on the join page.
/// Joined seats are filled, open seats dashed; each side is capped at 12. Open seats come from the server's
/// `seats.available`, else `maxMembers − joinedCount`; unknown counts draw nothing. Seats pop in 70 ms apart;
/// Reduce Motion shows them at once.
struct TeamJoinSeatRow: View {
    let detail: TeamDetail
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false
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
                            Circle().fill(CYColor.brand.opacity(0.14))
                        } else {
                            Circle().strokeBorder(CYColor.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        }
                        Image(systemName: on ? "person.fill" : "plus")
                            .foregroundStyle(on ? CYColor.brand : CYColor.textSecondary)
                    }
                    .frame(width: seat, height: seat)
                    .opacity(shown || reduceMotion ? 1 : 0)
                    .scaleEffect(shown || reduceMotion ? 1 : 0.6)
                    .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.6).delay(Double(index) * 0.07), value: shown)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("fixr3.team.seats.a11y \(joined) \(open)"))
            .accessibilityIdentifier("teamJoin.seats")
            .onAppear { shown = true }
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
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false
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
                ForEach(Array(members.enumerated()), id: \.offset) { index, member in
                    VStack(spacing: CYSpacing.xs) {
                        MPAsset.AvatarDefault.dProfile
                            .resizable()
                            .scaledToFill()
                            .frame(width: seat, height: seat)
                            .clipShape(Circle())
                            .accessibilityHidden(true)
                        if member.isCaptain {
                            Text("fixr3.team.seat.captain").cyText(.caption, weight: .semibold).foregroundStyle(CYColor.brand)
                        }
                    }
                    .seatPop(shown: shown, reduceMotion: reduceMotion, index: index)
                }
                ForEach(0..<open, id: \.self) { index in
                    ZStack {
                        Circle().strokeBorder(CYColor.textSecondary, style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
                        Image(systemName: "plus").foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
                    }
                    .frame(width: seat, height: seat)
                    .seatPop(shown: shown, reduceMotion: reduceMotion, index: members.count + index)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("fixr3.team.seats.a11y \(members.count) \(open)"))
            .accessibilityIdentifier("teamDetail.seats")
            .onAppear { shown = true }
        }
    }
}

private extension View {
    func seatPop(shown: Bool, reduceMotion: Bool, index: Int) -> some View {
        opacity(shown || reduceMotion ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .animation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.6).delay(Double(index) * 0.07), value: shown)
    }
}
