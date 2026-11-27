import SwiftUI

/// B04: the mini-program finish report (`pages/roam` settle, `screen == 'arrive'`). Read-only: every number comes from
/// the settled, archived walk this controller owns (the same gate as `RoamSummaryCelebration`). Anything the settlement
/// or the archived record does not provide stays nil and renders as an em dash; nothing is invented or counted locally.
struct RoamFinishReport: Equatable {
    let timestamp: Int64
    let recordedAt: Date?
    /// Archived zone name; nil uses the mini-program fallback 这片街区.
    let zone: String?
    let shops: Int?
    let explorePct: Int?
    let stamps: Int?
    let xp: Int?
    let medals: Int
    let story: String?
    let track: [RoamHistoryPoint]
    let record: RoamHistoryRecord?
    /// Settle chip. Nil hides it. The live session passes `RoamFinishAddress` (no endpoint).
    var currentAddress: String? = nil

    @MainActor init?(controller: RoamLiveSessionController, history: RoamFinishedHistoryReader) {
        guard RoamSummaryCelebration.settledSessionID(controller) != nil,
              let reference = controller.completedHistory,
              let result = controller.settlement?.result else { return nil }
        let record = (try? history.history())?.first { $0.ts == reference.timestamp }
        timestamp = reference.timestamp
        recordedAt = record?.recordedAt ?? (reference.timestamp > 0 ? Date(timeIntervalSince1970: Double(reference.timestamp) / 1000) : nil)
        zone = record?.meaningfulZone
        shops = result.sessionShops ?? record?.shops
        explorePct = record?.explorePct
        stamps = record.map { $0.photos.count }
        xp = result.totalXp
        let names = [result.medal, result.shopMedal?.name].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        medals = names.filter { !$0.isEmpty }.count
        story = result.routeStory
        track = controller.finishedRouteTrack ?? record?.track ?? []
        self.record = record
    }
}

@MainActor struct RoamFinishReportView: View {
    let report: RoamFinishReport
    let history: RoamFinishedHistoryReader
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @State private var showShare = false
    @State private var trackedRouteStory = false
    /// Design pass roam (P8): a medal earned on this walk opens its share card.
    @State private var selectedMedal: RoamMedalShareSelection?
    /// Design pass roam (P2/P7): the hero number rolls up from 0 once when the report appears.
    @State private var revealed = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.analyticsEventClient) private var analytics

    var body: some View {
        // design-r2-roam (P16 a finished activity is a named record): share + Done on top, the route first, then the
        // MP title (zone · 自由漫游), date · place, the MP hero (处到达) and its six cells in a 3-column grid (2 at
        // accessibility sizes), the MP stamp strip, medals with both exits (share, collection), the route story.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                mapPanel.padding(.top, CYSpacing.sm).padding(.horizontal, -CYSpacing.lg)
                head
                Divider().padding(.top, CYSpacing.md)
                    .accessibilityHidden(true)
                bigNumber
                grid.padding(.top, CYSpacing.xl)
                RoamFinishStampStrip(photos: report.record?.photos ?? [])
                medalsStrip
                if let story = report.story {
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        Text("u10.roamFinish.story").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                        Text(verbatim: story).cyText(.body).foregroundStyle(CYColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, CYSpacing.xl)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("roam.finishReport.story")
                }
                actions.padding(.top, CYSpacing.xl)
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.bottom, CYSpacing.xxl)
        }
        // native-r3-b: system background — the semantic text colours above were unreadable on forced black in light mode.
        .background(.background)
        // OWNER RULE 2: share and 完成 live in the standard nav bar (inline, system back kept), not an in-content bar.
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) { shareButton }
            ToolbarItem(placement: .confirmationAction) { doneButton }
        }
        .cySheet(isPresented: $showShare) {
            Group { if let record = report.record { NavigationStack { RoamHistoryShareView(record: record, reader: history) } } }
                .cySheet(detents: [.large])
        }
        .cySheet(item: $selectedMedal) { medal in
            Group { NavigationStack { RoamMedalShareView(selection: medal, reader: history) } }
                .cySheet(detents: [.large])
        }
        .accessibilityIdentifier("roam.finishReport")
        .task {
            guard !revealed else { return }
            if reduceMotion { revealed = true } else { withAnimation(.smooth(duration: 1.0)) { revealed = true } }
        }
        .onAppear {
            guard !trackedRouteStory, report.story?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
            trackedRouteStory = true
            MiniProgramAnalytics.track(analytics, "roam_route_story_shown", bizType: "roam", pagePath: "/pages/roam/index")
        }
        .cyDomainScreen(.player)
    }

    /// P16 top bar: share (secondary, icon) and the one Done. Identifiers kept: the MP close is now Done.
    private var shareButton: some View {
        Button { showShare = true } label: {
            Label("u10.roamFinish.share", systemImage: "square.and.arrow.up")
        }
        .disabled(report.record == nil)
        .accessibilityLabel(Text("u10.roamFinish.shareLabel"))
        .accessibilityIdentifier("roam.finishReport.share")
    }
    private var doneButton: some View {
        Button("action.done") { dismiss() }
            .accessibilityHint(Text("u10.roamFinish.close"))
            .accessibilityIdentifier("roam.finishReport.close")
    }
    private var head: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            titleText
                .cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            // P16 date · place line. Place is the settle chip address when the live session passed one.
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.xs) {
                dateLine
                if let address = report.currentAddress {
                    Text(verbatim: "·").accessibilityHidden(true)
                    Text(verbatim: address).lineLimit(2)
                }
            }
            .cyText(.bodyCompact).foregroundStyle(CYColor.textTertiary)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("roam.finishReport.dateLine")
        }
        .padding(.top, CYSpacing.lg)
    }
    private var titleText: Text {
        if let zone = report.zone { return Text("u10.roamFinish.title \(zone)") }
        return Text("u10.roamFinish.title \(appLocalized("u10.roamFinish.zoneFallback", locale: locale))")
    }
    @ViewBuilder private var dateLine: some View {
        if let date = report.recordedAt {
            if Calendar.current.isDateInToday(date) {
                Text("u10.roamFinish.today \(date.formatted(date: .omitted, time: .shortened))")
            } else {
                Text(date, format: .dateTime.month().day().hour().minute())
            }
        } else {
            Text(verbatim: "—")
        }
    }
    /// MP settle__big: 处到达 (`finish.footprints`, pages/roam/index.wxml:900-901), the archived record's unique reached
    /// places (`RoamHistoryRecord.footprintCount`). Rolls up from 0 once (P2); an unarchived record shows an em dash.
    private var footprints: Int? { report.record?.footprintCount }
    private var bigNumber: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: footprints.map { String(revealed ? $0 : 0) } ?? "—")
                .font(.system(.largeTitle, design: .default).weight(.black).italic())
                .contentTransition(.numericText(value: Double(revealed ? (footprints ?? 0) : 0)))
                .dynamicTypeSize(.accessibility3)
                .monospacedDigit()
                .foregroundStyle(CYColor.textPrimary)
            Text("design.roam.footprints").cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary)
        }
        .padding(.top, CYSpacing.xl)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("design.roam.footprints"))
        .accessibilityValue(Text(verbatim: footprints.map(String.init) ?? "—"))
        .accessibilityIdentifier("roam.finishReport.footprints")
    }
    private var grid: some View {
        // MP settle__grid: six cells, 公里 · 用时 · 探索度 · 邮票 · 探索值 · 勋章 (pages/roam/index.wxml:903-910).
        // Three columns, two rows; values shrink before they truncate (P12).
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: CYSpacing.sm, alignment: .topLeading), count: dynamicTypeSize.isAccessibilitySize ? 2 : 3),
                  alignment: .leading, spacing: CYSpacing.lg) {
            // i18n r1 locale: miles in the US, km in CN.
            cell(report.record?.distance.map { LocaleDisplay.roadNumber(kilometers: $0, locale: locale).formatted(.number.precision(.fractionLength(1)).locale(locale)) },
                 LocaleDisplay.usesMiles(locale) ? "unit.mile.abbr" : "design.roam.km", id: "distance")
            cell(report.record?.durationText, "roam.live.stat.time", id: "time")
            cell(report.explorePct.map { "\($0)%" }, "u10.roamFinish.explore", id: "explore")
            cell(report.stamps.map(String.init), "u10.roamFinish.stamps", id: "stamps")
            cell(report.xp.map { $0 > 0 ? "+\($0)" : "0" }, "u10.roamFinish.xp", id: "xp")
            cell(String(report.medals), "u10.roamFinish.medals", id: "medals")
        }
    }
    /// Design pass roam (P8 rewards are objects you keep): each medal of this walk is a tile with its name; a tap
    /// opens its share card (`RoamMedalShareView`), and 漫游记录 below keeps the collection one tap away.
    @ViewBuilder private var medalsStrip: some View {
        let medals = report.record.map { RoamMedalShareSelection.selections(for: $0) } ?? []
        if !medals.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.sm) {
                Text("roam.experience.rewards").cyText(.caption).foregroundStyle(CYColor.textTertiary)
                    .accessibilityAddTraits(.isHeader)
                ForEach(medals) { medal in
                    Button { selectedMedal = medal } label: {
                        HStack(spacing: CYSpacing.md) {
                            Image(systemName: medal.card.kind == .shop ? "storefront.circle.fill" : "medal.fill")
                                .font(.title)
                                .foregroundStyle(Color.yellow)
                                .symbolEffect(.bounce, value: revealed && !reduceMotion)
                                .frame(width: 44, height: 44)
                                .accessibilityHidden(true)
                            Text(verbatim: medal.card.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: CYSpacing.sm)
                            Image(systemName: "square.and.arrow.up").foregroundStyle(CYColor.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .padding(CYSpacing.md)
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("roam.medalShare.open") + Text(verbatim: ": " + medal.card.name))
                    .accessibilityIdentifier("roam.finishReport.medal." + medal.card.kind.rawValue)
                }
            }
            .padding(.top, CYSpacing.xl)
        }
    }
    private func cell(_ value: String?, _ label: LocalizedStringKey, id: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: value ?? "—").cyText(.dataXL).italic().foregroundStyle(CYColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(label).cyText(.bodyCompact).foregroundStyle(CYColor.textTertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roam.finishReport.\(id)")
    }
    private var mapPanel: some View {
        ZStack {
            Rectangle().fill(.background.secondary)
            if report.track.count > 1, let record = report.record {
                RoamRouteSketchView(record: record).padding(CYSpacing.lg)
            } else {
                Label("u10.roamFinish.noTrack", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                    .overlay(Capsule().strokeBorder(.separator, lineWidth: 1))
                    .accessibilityIdentifier("roam.finishReport.noTrack")
            }
        }
        .frame(minHeight: 260)
        .overlay(alignment: .bottomTrailing) {
            if history.identity != nil {
                NavigationLink {
                    RoamHistoryDetailView(reader: history, timestamp: report.timestamp)
                } label: {
                    Label("u10.roamFinish.data", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .cyText(.label).foregroundStyle(CYColor.textPrimary)
                        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
                        .background(.regularMaterial, in: Capsule()) // native-r3-b: map control on a material, reads on any map style
                }
                .buttonStyle(.plain)
                .padding(CYSpacing.lg)
                .accessibilityIdentifier("roam.finishedHistory.record.open")
            }
        }
    }
    /// Exits under the record: 漫游记录 (MP settle minor action) and, when medals were earned, the badge wall
    /// (P8: a kept medal has a share and a collection exit). Share lives in the top bar (P16).
    private var actions: some View {
        VStack(spacing: CYSpacing.sm) {
            if history.identity != nil {
                if report.medals > 0 {
                    NavigationLink { RoamBadgeWallDestination(roamReader: history).cyPushedChrome() } label: {
                        Label("design.roam.medals.collection", systemImage: "square.grid.2x2")
                            .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("roam.finishReport.collection")
                }
                NavigationLink { RoamHistoryView(reader: history) } label: {
                    Text("u10.roamFinish.history").cyText(.bodyMedium).foregroundStyle(CYColor.textSecondary)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roam.finishedHistory.history.open")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
