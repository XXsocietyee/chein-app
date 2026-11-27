import SwiftUI

/// A grid of day cells, oldest first, filled where the player was active (roam streak, check-in days).
/// One VoiceOver element: `label`, value "12 of 28 days". Components r1 (C3).
struct CYStreakGrid: View {
    private let days: [Bool]
    private let columns: Int
    private let tint: Color
    private let labelKey: LocalizedStringKey
    @ScaledMetric(relativeTo: .caption) private var cell: CGFloat = 12

    /// `days`: oldest first, `true` = active that day. `columns` = 7 for a week per row.
    init(days: [Bool], columns: Int = 7, tint: Color = CYColor.successText, label: LocalizedStringKey = "comp.kit.streak.label") {
        self.days = days
        self.columns = max(1, columns)
        self.tint = tint
        self.labelKey = label
    }

    /// The last `dayCount` days ending on `endingOn`, active where `activeDays` holds a date on that day.
    init(
        activeDays: [Date],
        dayCount: Int = 28,
        endingOn end: Date = .now,
        calendar: Calendar = .current,
        columns: Int = 7,
        tint: Color = CYColor.successText,
        label: LocalizedStringKey = "comp.kit.streak.label"
    ) {
        self.init(
            days: CYStreakGrid.dayFlags(activeDays: activeDays, dayCount: dayCount, endingOn: end, calendar: calendar),
            columns: columns,
            tint: tint,
            label: label
        )
    }

    var body: some View {
        Grid(horizontalSpacing: CYSpacing.xs, verticalSpacing: CYSpacing.xs) {
            ForEach(rows.indices, id: \.self) { row in
                GridRow {
                    ForEach(rows[row].indices, id: \.self) { column in
                        cellView(active: rows[row][column])
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(labelKey))
        .accessibilityValue(Text("comp.kit.streak.value \(activeCount) \(days.count)"))
    }

    private func cellView(active: Bool) -> some View {
        RoundedRectangle(cornerRadius: cell / 4, style: .continuous)
            .fill(active ? tint : tint.opacity(0.16))
            .frame(width: cell, height: cell)
    }

    private var rows: [[Bool]] {
        stride(from: 0, to: days.count, by: columns).map { start in
            Array(days[start..<min(start + columns, days.count)])
        }
    }

    private var activeCount: Int { days.filter { $0 }.count }

    /// Oldest-first flags for the `dayCount` days ending on `end`.
    static func dayFlags(activeDays: [Date], dayCount: Int, endingOn end: Date, calendar: Calendar) -> [Bool] {
        guard dayCount > 0 else { return [] }
        let today = calendar.startOfDay(for: end)
        let active: Set<Date> = Set(activeDays.map { calendar.startOfDay(for: $0) })
        return (0..<dayCount).map { index in
            let offset = index - (dayCount - 1)
            guard let day = calendar.date(byAdding: .day, value: offset, to: today) else { return false }
            return active.contains(day)
        }
    }

    /// Consecutive active days ending at the newest day.
    static func currentStreak(_ days: [Bool]) -> Int {
        var count = 0
        for active in days.reversed() {
            guard active else { break }
            count += 1
        }
        return count
    }
}

private struct CYStreakGridPreviewBody: View {
    var body: some View {
        CYStreakGrid(days: (0..<28).map { $0 % 3 != 0 })
            .padding(CYSpacing.pageHorizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .cyDomainPageBackground()
    }
}
#Preview("StreakGrid · player dark") { CYStreakGridPreviewBody().themeDomain(.player) }
