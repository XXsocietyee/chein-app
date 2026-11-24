import SwiftUI

@MainActor struct ClubActivityListContent: View {
    let rows: [ClubActivityRow]
    let canOpen: Bool
    let open: (ClubActivityRow) -> Void
    var report: ((ClubActivityRow) -> AnyView)? = nil
    /// CLB-detail-19: inside the club page's 活动 tab the list has no 当前活动 header, no time-zone helper line and no
    /// ended activities (MP P-14: 已结束的不在这里出).
    var embedded = false
    init(overview: ClubActivityOverview, canOpen: Bool, open: @escaping (ClubActivityRow) -> Void,
         report: ((ClubActivityRow) -> AnyView)? = nil) {
        self.init(rows: overview.rows, canOpen: canOpen, open: open, report: report)
    }
    /// Display rows do not imply a governance snapshot or any mutation authority.
    init(rows: [ClubActivityRow], canOpen: Bool, open: @escaping (ClubActivityRow) -> Void,
         report: ((ClubActivityRow) -> AnyView)? = nil, embedded: Bool = false) {
        self.rows = rows; self.canOpen = canOpen; self.open = open; self.report = report; self.embedded = embedded
    }
    private var currentRows: [ClubActivityRow] { rows.filter { $0.status != .ended } }
    private var endedRows: [ClubActivityRow] { rows.filter { $0.status == .ended } }
    var body: some View {
        if embedded {
            Section {
                if currentRows.isEmpty { Text("club.calendar.noEvents").accessibilityIdentifier("club.calendar.empty") }
                ForEach(currentRows) { row in item(row) }
            }
        } else {
        Section("club.activityList.current") {
            Text("club.activityList.timeZone").cyText(.meta).foregroundStyle(.secondary)
            if rows.isEmpty { Text("club.calendar.noEvents").accessibilityIdentifier("club.calendar.empty") }
            else if currentRows.isEmpty { Text("club.activityList.noCurrent").accessibilityIdentifier("club.activityList.current.empty") }
            ForEach(currentRows) { row in item(row) }
        }
        if !endedRows.isEmpty {
            Section("club.activityList.ended") { ForEach(endedRows) { row in item(row) } }
        }
        }
    }
    @ViewBuilder private func item(_ row: ClubActivityRow) -> some View {
        if canOpen {
            Button { open(row) } label: { ClubActivityCard(row: row) }
                .buttonStyle(.plain).accessibilityHint("roamEvent.openTopic")
                .accessibilityIdentifier("club.calendar.topic.\(row.id)")
        } else { ClubActivityCard(row: row) }
        if let report { report(row) }
    }
}

private struct ClubActivityCard: View {
    let row: ClubActivityRow
    @Environment(\.locale) private var locale
    var body: some View {
        // CLB-detail-39 (MP detail wxml:166-212, `.ev-*`): a card surface whose cover (130 pt) carries the status chip
        // at its top-left; text below uses the type tokens only.
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .topLeading) {
                Group {
                    if let cover = row.cover {
                        SquareImage(source: cover)
                    } else {
                        // Round 2 MP asset: the MP event card falls back to `route_free_cover.png` (club/detail wxml:169).
                        MPAsset.BannerCover.routeFreeCover.resizable().scaledToFill()
                    }
                }
                .frame(maxWidth: .infinity).frame(height: 130).clipped().accessibilityHidden(true)
                CYStatusChip(LocalizedStringKey("club.activityList.status." + row.status.rawValue),
                             tone: row.status == .live ? .success : (row.status == .ended ? .neutral : .info))
                    .padding(CYSpacing.sm)
                    .accessibilityIdentifier("club.activityList.status.\(row.id)")
            }
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                if let name = row.name { Text(verbatim: name).cyText(.cardTitle) }
                else { Text("club.calendar.untitled").cyText(.cardTitle) }
                if let value = timeText { Text(verbatim: value).cyText(.body) }
                else { Text("club.calendar.dateUnknown").cyText(.body) }
                if let address = row.address {
                    Label { Text(verbatim: address) } icon: { Image(systemName: "mappin") }
                        .cyText(.meta).foregroundStyle(CYColor.textSecondary)
                }
                Text(LocalizedStringKey("club.activityList.category." + row.category.rawValue)).cyText(.meta).foregroundStyle(.secondary)
                if row.signups != nil || row.stations != nil || row.mileageKM != nil {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 20) { stats }
                        VStack(alignment: .leading, spacing: 8) { stats }
                    }
                }
            }
            .padding(CYSpacing.md)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CYColor.bgRaised)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
        .padding(.vertical, CYSpacing.xs)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var stats: some View {
        if let count = row.signups { stat(count, title: "club.activityList.signups") }
        if let count = row.stations { stat(count, title: "club.activityList.stations") }
        if let distance = row.mileageKM { stat(distance, title: "club.activityList.kilometers") }
    }
    private func stat(_ value: Double, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value, format: .number).cyText(.cardTitle)
            Text(title).cyText(.meta).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
    private var timeText: String? {
        guard let date = row.start else { return row.sourceStart.map { String($0.prefix(16)).replacingOccurrences(of: "T", with: " ") } }
        let formatter = DateFormatter(); formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.setLocalizedDateFormatFromTemplate(row.dateOnly ? "EEE MMMd" : "EEE MMMd HHmm")
        return formatter.string(from: date)
    }
}
