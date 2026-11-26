import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// MC-25 · Club/Roster Card: cover thumbnail, title, date, `5 / 50` with a thin capacity bar.
// Expanded: one three-number row (实收 · 已退 · 净额) at body size, then attendees with status tags.

struct ClubRosterAttendee: Identifiable, Equatable {
    let id: String
    let name: String
    let status: ClubR1Status
    let statusText: String
}

struct ClubRosterCardModel: Equatable {
    let title: String
    let dateText: String?
    let registered: Int?
    let capacity: Int?
    /// Real money stays ¥ with two decimals; nil = unknown ("—").
    let received: String?
    let refunded: String?
    let net: String?
    let attendees: [ClubRosterAttendee]
    /// False where money is not part of the roster (the members screen): the 实收 · 已退 · 净额 row is left out,
    /// rather than shown as three unknowns.
    var showsMoney = true

    /// `5 / 50`; with no capacity read, just the count (no bar).
    var countText: String {
        guard capacity != nil else { return registered.map(String.init) ?? "—" }
        return "\(registered.map(String.init) ?? "—") / \(capacity.map(String.init) ?? "—")"
    }

    /// The card expands only when it has money or attendees to show.
    var isExpandable: Bool { showsMoney || !attendees.isEmpty }

    /// 0…1 fill of the capacity bar; nil when either side is unknown.
    var fill: Double? {
        guard let registered, let capacity, capacity > 0 else { return nil }
        return min(1, max(0, Double(registered) / Double(capacity)))
    }
}

extension ClubRosterCardModel {
    /// verify-r1 2.6: MC-25's card on 报名名册, where it belongs. Count is the sign-up total (registered, arrived,
    /// no-show); the roster read carries no capacity or money, so neither is drawn rather than shown as "—".
    static func roster(_ roster: ClubRosterPresentation, locale: Locale) -> ClubRosterCardModel {
        let order: [(ClubRosterBucket, ClubR1Status)] = [(.arrived, .live), (.registered, .pending), (.noShow, .ended)]
        let attendees = order.flatMap { bucket, status in
            roster.members(in: bucket).map { member in
                ClubRosterAttendee(id: "\(bucket.rawValue)-\(member.id)",
                                   name: member.nickname ?? appLocalized("club.roster.unnamed", locale: locale),
                                   status: status,
                                   statusText: appLocalized(String.LocalizationValue(bucket.localizationKey), locale: locale))
            }
        }
        return ClubRosterCardModel(title: clubR1("roster.title", locale), dateText: nil,
                                   registered: roster.rosterTotal, capacity: nil,
                                   received: nil, refunded: nil, net: nil, attendees: attendees, showsMoney: false)
    }

    /// verify-r1 2.6: the 成员 subtitle, `创建者 1 · 管理员 1 · 成员 2`.
    static func roleSummary(_ directory: ClubMemberDirectory, locale: Locale) -> String {
        let owners = directory.members.filter(\.isOwner).count
        let admins = directory.members.filter { !$0.isOwner && $0.isAdmin }.count
        let others = directory.members.count - owners - admins
        return String(format: clubR1("roster.members.roles", locale), owners, admins, others)
    }

    /// polish-d-r1 (MC-25 on the members screen): club name, role breakdown and member count; no money, no capacity read.
    static func members(_ directory: ClubMemberDirectory, locale: Locale) -> ClubRosterCardModel {
        let owners = directory.members.filter(\.isOwner).count
        let admins = directory.members.filter { !$0.isOwner && $0.isAdmin }.count
        let others = directory.members.count - owners - admins
        return ClubRosterCardModel(title: directory.club.name,
                                   dateText: String(format: clubR1("roster.members.roles", locale), owners, admins, others),
                                   registered: directory.members.count, capacity: nil,
                                   received: nil, refunded: nil, net: nil, attendees: [], showsMoney: false)
    }
}

/// MC-25 as a system disclosure row: title, date and `5 / 50` with a capacity gauge; expanding lists the
/// 实收 · 已退 · 净额 figures and the attendees with their status.
struct ClubRosterCard: View {
    let model: ClubRosterCardModel
    var coverSeed: String = ""
    @State private var expanded = false
    @Environment(\.locale) private var locale

    var body: some View {
        if model.isExpandable {
            DisclosureGroup(isExpanded: $expanded) {
                if model.showsMoney {
                    money("roster.received", model.received)
                    money("roster.refunded", model.refunded)
                    money("roster.net", model.net)
                }
                ForEach(model.attendees) { attendee in
                    LabeledContent {
                        Text(verbatim: attendee.statusText)
                            .foregroundStyle(statusColor(attendee.status))
                    } label: {
                        Text(verbatim: clubR1Value(attendee.name))
                    }
                }
            } label: {
                summary
            }
            .accessibilityHint(Text(verbatim: clubR1(expanded ? "roster.collapse" : "roster.expand", locale)))
        } else {
            summary
        }
    }

    private var summary: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: clubR1Value(model.title))
                .font(.headline)
            Text(verbatim: clubR1Value(model.dateText))
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: CYSpacing.sm) {
                if let fill = model.fill {
                    ProgressView(value: fill)
                        .frame(width: 72)
                        .accessibilityHidden(true)
                }
                Text(verbatim: model.countText)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(verbatim: model.countText))
    }

    private func statusColor(_ status: ClubR1Status) -> Color {
        switch status {
        case .live: return .green
        case .pending: return .orange
        case .ended: return .secondary
        case .rejected: return .red
        }
    }

    private func money(_ key: String, _ raw: String?) -> some View {
        LabeledContent {
            Text(verbatim: clubR1Value(raw)).monospacedDigit()
        } label: {
            Text(verbatim: clubR1(key, locale))
        }
    }
}
