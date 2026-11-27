import SwiftUI

// design-r2-play · P16 "A finished activity is a named record": after a game or a run the stats sit in a 2- or
// 3-column grid, small label above a big monospaced value (Strava, Runna, Gentler Streak summaries).
// One accessibility element per cell ("Score, 120"). One column at accessibility text sizes (P12).

/// One cell of a finished-activity record.
struct CYRecordStat: Identifiable {
    let id: String
    let label: LocalizedStringKey
    let value: String
    init(id: String, label: LocalizedStringKey, value: String) {
        self.id = id; self.label = label; self.value = value
    }
}

@MainActor struct CYRecordStatGrid: View {
    let stats: [CYRecordStat]
    @Environment(\.dynamicTypeSize) private var typeSize

    /// 2 columns for 2 or 4 values, otherwise 3; a single column at accessibility sizes.
    private var columnCount: Int {
        if typeSize.isAccessibilitySize { return 1 }
        return stats.count == 2 || stats.count == 4 ? 2 : min(3, max(1, stats.count))
    }
    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 16, alignment: .topLeading), count: columnCount)
    }

    var body: some View {
        if !stats.isEmpty {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 16) {
                ForEach(stats) { stat in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(stat.label)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: stat.value)
                            .font(.title2.bold())
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier(stat.id)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
