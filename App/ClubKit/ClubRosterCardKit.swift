import SwiftUI

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

    var countText: String {
        "\(registered.map(String.init) ?? "—") / \(capacity.map(String.init) ?? "—")"
    }

    /// 0…1 fill of the capacity bar; nil when either side is unknown.
    var fill: Double? {
        guard let registered, let capacity, capacity > 0 else { return nil }
        return min(1, max(0, Double(registered) / Double(capacity)))
    }
}

struct ClubRosterCard: View {
    let model: ClubRosterCardModel
    var coverSeed: String = ""
    @State private var expanded = false
    @State private var shownFill: Double = 0
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Button {
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) { expanded.toggle() }
            } label: {
                HStack(alignment: .top, spacing: CYSpacing.md) {
                    CYCoverArt(seed: coverSeed.isEmpty ? model.title : coverSeed, showsDebugLabel: false)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text(verbatim: clubR1Value(model.title))
                            .font(CYTypography.body.weight(.semibold))
                            .foregroundStyle(palette.textPrimary)
                        Text(verbatim: clubR1Value(model.dateText))
                            .font(CYTypography.meta)
                            .foregroundStyle(palette.textSecondary)
                        HStack(spacing: CYSpacing.sm) {
                            capacityBar
                            Text(verbatim: model.countText)
                                .font(CYTypography.meta.monospacedDigit())
                                .foregroundStyle(palette.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    Image(systemName: "chevron.down")
                        .font(CYTypography.label.weight(.semibold))
                        .foregroundStyle(palette.textTertiary)
                        .rotationEffect(.degrees(expanded ? 180 : 0))
                        .accessibilityHidden(true)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(Text(verbatim: model.countText))
            .accessibilityHint(Text(verbatim: clubR1(expanded ? "roster.collapse" : "roster.expand", locale)))
            if expanded {
                HStack(spacing: CYSpacing.md) {
                    money("roster.received", model.received)
                    money("roster.refunded", model.refunded)
                    money("roster.net", model.net)
                }
                ForEach(model.attendees) { attendee in
                    HStack {
                        Text(verbatim: clubR1Value(attendee.name))
                            .font(CYTypography.body)
                            .foregroundStyle(palette.textPrimary)
                        Spacer(minLength: CYSpacing.sm)
                        ClubR1StatusTag(status: attendee.status, text: attendee.statusText)
                    }
                    .frame(minHeight: 44)
                }
            }
        }
        .padding(CYSpacing.lg)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.bgElevated))
        .onAppear {
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.4)) { shownFill = model.fill ?? 0 }
        }
    }

    private var capacityBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(palette.bgRaised)
                Capsule().fill(palette.textPrimary).frame(width: proxy.size.width * shownFill)
            }
        }
        .frame(width: 72, height: 4)
        .accessibilityHidden(true)
    }

    private func money(_ key: String, _ raw: String?) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(verbatim: clubR1Value(raw))
                .font(CYTypography.numericBody)
                .foregroundStyle(palette.textPrimary)
            Text(verbatim: clubR1(key, locale))
                .font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}
