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
            Text("club.activityList.timeZone").font(.footnote).foregroundStyle(.secondary)
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
            Button { open(row) } label: { ClubActivityCard(row: row).foregroundStyle(.primary) }
                .accessibilityHint("roamEvent.openTopic")
                .accessibilityIdentifier("club.calendar.topic.\(row.id)")
        } else { ClubActivityCard(row: row) }
        if let report { report(row) }
    }
}

private struct ClubActivityCard: View {
    let row: ClubActivityRow
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        // CLB-detail-39 (MP detail wxml:166-212, `.ev-*`): the cover (130 pt), then the status and details as plain
        // system text. The list row is the card.
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let cover = row.cover {
                    SquareImage(source: cover)
                } else {
                    // Round 2 MP asset: the MP event card falls back to `route_free_cover.png` (club/detail wxml:169).
                    MPAsset.BannerCover.routeFreeCover.resizable().scaledToFill()
                }
            }
            .frame(maxWidth: .infinity).frame(height: 130)
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.inner, style: .continuous))
            .accessibilityHidden(true)
            Label {
                Text(LocalizedStringKey("club.activityList.status." + row.status.rawValue))
            } icon: {
                Image(systemName: "circle.fill").imageScale(.small)
                    .foregroundStyle(row.status == .live ? CYColor.successText : (row.status == .ended ? Color.secondary : CYColor.infoText))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .accessibilityIdentifier("club.activityList.status.\(row.id)")
            // a11y-dt r3: VoiceOver reads the activity name first, then its status and facts (visual order unchanged).
            Group {
                if let name = row.name { Text(verbatim: name).font(.headline) }
                else { Text("club.calendar.untitled").font(.headline) }
            }
            .accessibilitySortPriority(1)
            if let value = timeText { Text(verbatim: value) }
            else { Text("club.calendar.dateUnknown") }
            if let start = soonStart {
                // Design pass P2 / P1: inside the last hour the start time is a live 距开始 mm:ss (system timer text,
                // same clock as the Live Activity), and reads 进行中 once it passes.
                // a11y-dt r3: system orange text was ~2:1 on white → `CYColor.warningText` (≥ 4.5:1); the label and the
                // timer stack at accessibility sizes instead of running off the row.
                let startsLayout = typeSize.isAccessibilitySize
                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
                    : AnyLayout(HStackLayout(spacing: 4))
                startsLayout {
                    Text("comp.kit.startsIn")
                    CYCountdown(until: start, style: nil, tint: nil, endedKey: "comp.kit.countdown.started")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(CYColor.warningText)
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("club.activityList.startsIn.\(row.id)")
            }
            if let address = row.address {
                Label { Text(verbatim: address) } icon: { Image(systemName: "mappin") }
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Text(LocalizedStringKey("club.activityList.category." + row.category.rawValue)).font(.subheadline).foregroundStyle(.secondary)
            if row.signups != nil || row.stations != nil || row.mileageKM != nil {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 20) { stats }
                    VStack(alignment: .leading, spacing: 8) { stats }
                }
            }
        }
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
    @ViewBuilder private var stats: some View {
        if let count = row.signups { stat(count, title: "club.activityList.signups") }
        if let count = row.stations { stat(count, title: "club.activityList.stations") }
        if let distance = row.mileageKM { stat(LocaleDisplay.roadNumber(kilometers: distance, locale: locale), title: LocaleDisplay.usesMiles(locale) ? "club.activityList.miles" : "club.activityList.kilometers") }
    }
    private func stat(_ value: Double, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            // Design pass P2: counts roll when a refresh changes them.
            Text(value, format: .number).font(.headline).monospacedDigit()
                .contentTransition(.numericText(value: value))
                .animation(reduceMotion ? nil : .snappy, value: value)
            Text(title).font(.footnote).foregroundStyle(.secondary)
        }.accessibilityElement(children: .combine)
    }
    /// The start date when a recruiting activity starts within the hour (date-only starts never count down).
    private var soonStart: Date? {
        guard row.status == .recruiting, !row.dateOnly, let start = row.start else { return nil }
        let left = start.timeIntervalSinceNow
        return left > 0 && left <= 3600 ? start : nil
    }
    private var timeText: String? {
        guard let date = row.start else { return row.sourceStart.map { LocaleDisplay.civil(String($0.prefix(16)).replacingOccurrences(of: "T", with: " "), locale: locale) } }
        let formatter = DateFormatter(); formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian); formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        formatter.setLocalizedDateFormatFromTemplate(row.dateOnly ? "EEE MMMd" : "EEE MMMd jmm")
        return formatter.string(from: date)
    }
}
