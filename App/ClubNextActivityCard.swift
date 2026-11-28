import SwiftUI

/// mp-club r3 pass 51 (P38, sweep 18:30): the club page answers "what's next" with one card: a calendar-tile date
/// (month over a big day), the topic name, its time and its meeting point. Data = the MP 活动 tab's `upcomingTopics`
/// (detail wxml:210), level B: system text styles, no ornament, the row is the button.
@MainActor struct ClubNextActivityCard: View {
    let row: ClubActivityRow
    let canOpen: Bool
    let open: () -> Void
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @ScaledMetric(relativeTo: .title2) private var tileSide: CGFloat = 56

    var body: some View {
        Group {
            if canOpen {
                Button(action: open) { content.foregroundStyle(.primary) }
                    .buttonStyle(.plain)
                    .accessibilityHint("roamEvent.openTopic")
            } else {
                content
            }
        }
        .accessibilityIdentifier("club.detail.next.card")
    }

    private var content: some View {
        let layout = typeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.sm))
            : AnyLayout(HStackLayout(alignment: .center, spacing: CYSpacing.md))
        return layout {
            dateTile
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Group {
                    if let name = row.name { Text(verbatim: name) } else { Text("club.calendar.untitled") }
                }
                .font(.headline)
                .fixedSize(horizontal: false, vertical: true)
                Group {
                    if let value = timeText { Text(verbatim: value) } else { Text("club.calendar.dateUnknown") }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                if let address = row.address {
                    Label { Text(verbatim: address) } icon: { Image(systemName: "mappin") }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            if !typeSize.isAccessibilitySize {
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary).accessibilityHidden(true)
            }
        }
        .padding(.vertical, CYSpacing.xs)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// Month over day, like a calendar page. Without a start time the tile shows a calendar symbol instead of a date.
    @ViewBuilder private var dateTile: some View {
        VStack(spacing: 0) {
            if let start = row.start {
                Text(verbatim: format(start, template: "MMM"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
                Text(verbatim: format(start, template: "d"))
                    .cyText(.numericTitle)
            } else {
                Image(systemName: "calendar").font(.title2).foregroundStyle(.secondary)
            }
        }
        .frame(minWidth: tileSide, minHeight: tileSide)
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }

    /// Same clock as the 活动 tab card (`ClubActivityCard.timeText`): server times are China time (UTC+8).
    private func format(_ date: Date, template: String) -> String {
        let formatter = DateFormatter(); formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter.string(from: date)
    }

    private var timeText: String? {
        guard let date = row.start else {
            return row.sourceStart.map { LocaleDisplay.civil(String($0.prefix(16)).replacingOccurrences(of: "T", with: " "), locale: locale) }
        }
        if row.status == .live {
            return appLocalized("club.activityList.status.live", locale: locale) + " · " + format(date, template: row.dateOnly ? "EEE MMMd" : "EEE MMMd jmm")
        }
        return format(date, template: row.dateOnly ? "EEEE" : "EEEE jmm")
    }
}
