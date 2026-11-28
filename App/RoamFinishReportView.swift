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
        // mp-roam r3 (OWNER RULE, MP settle order pages/roam/index.wxml:893-948): date line → zone · 自由漫游 → rule →
        // 处到达 hero → six cells → 这段足迹 → stamp strip → (native P8 medals) → route map with 查看漫游数据 → bottom CTA.
        // P30: the result is a moment, then a door — Share (bordered capsule) beside the primary Done in the bottom bar,
        // a success haptic once on appear, 漫游记录 as the minor exit under them.
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                head
                Divider().padding(.top, CYSpacing.md)
                    .accessibilityHidden(true)
                bigNumber
                grid.padding(.top, CYSpacing.xl)
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
                RoamFinishStampStrip(photos: report.record?.photos ?? [])
                medalsStrip
                reachedPlaces
                mapPanel.padding(.top, CYSpacing.xl).padding(.horizontal, -CYSpacing.lg)
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.bottom, CYSpacing.xl)
        }
        // native-r3-b: system background — the semantic text colours above were unreadable on forced black in light mode.
        .background(.background)
        .safeAreaInset(edge: .bottom) { bottomBar }
        // OWNER RULE 2: inline nav bar, system back kept; the actions live in the bottom bar (P30).
        .toolbar(.visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .sensoryFeedback(.success, trigger: revealed, condition: CYHapticTransition.isOn)
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

    /// P30 bottom bar: Share (bordered capsule, MP 分享 CTA) beside the one primary Done (MP ✕), then the MP minor
    /// exits. Identifiers kept.
    private var bottomBar: some View {
        // a11y-dt r3: at accessibility sizes the half-width capsules cut "Share" / "完成" (lineLimit 1); they stack full-width.
        let pair = dynamicTypeSize.isAccessibilitySize ? AnyLayout(VStackLayout(spacing: CYSpacing.sm)) : AnyLayout(HStackLayout(spacing: CYSpacing.sm))
        return VStack(spacing: CYSpacing.xs) {
            pair {
                shareButton
                doneButton
            }
            actions
        }
        .padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.md).padding(.bottom, CYSpacing.xs)
        .background(.bar)
    }
    private var shareButton: some View {
        Button { showShare = true } label: {
            Label("u10.roamFinish.share", systemImage: "square.and.arrow.up")
                .lineLimit(1)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.bordered).buttonBorderShape(.capsule).controlSize(.large)
        .disabled(report.record == nil)
        .accessibilityLabel(Text("u10.roamFinish.shareLabel"))
        .accessibilityIdentifier("roam.finishReport.share")
    }
    private var doneButton: some View {
        Button { dismiss() } label: {
            Text("action.done").lineLimit(1).frame(maxWidth: .infinity, minHeight: 44)
        }
            .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
            .accessibilityHint(Text("u10.roamFinish.close"))
            .accessibilityIdentifier("roam.finishReport.close")
    }
    private var head: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            // MP settle__meta first: date · place. Place is the settle chip address when the live session passed one.
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
            titleText
                .cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
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
                .dynamicTypeSize(max(dynamicTypeSize, DynamicTypeSize.accessibility3))
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
    /// MP `settle__places` (wxml:932, index.js:4861): the reached places of this walk (done, not demo), names only,
    /// in walk order, before the route map. Unnamed or repeated places are skipped.
    @ViewBuilder private var reachedPlaces: some View {
        let names = reachedPlaceNames
        if !names.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                ForEach(names, id: \.self) { name in
                    Text(verbatim: name).cyText(.body).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.top, CYSpacing.xl)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("roam.finishReport.places")
        }
    }
    private var reachedPlaceNames: [String] {
        var seen = Set<String>()
        var names: [String] = []
        for place in report.record?.pois ?? [] where !place.isDemoEntry {
            let name = place.name.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty, seen.insert(name).inserted { names.append(name) }
        }
        return names
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
    /// Minor exits under Share / Done: 漫游记录 (MP settle__minor) and, when medals were earned, the badge wall
    /// (P8: a kept medal has a share and a collection exit).
    private var actions: some View {
        VStack(spacing: CYSpacing.sm) {
            if history.identity != nil {
                if report.medals > 0 {
                    NavigationLink { RoamBadgeWallDestination(roamReader: history).cyPushedChrome() } label: {
                        Label("design.roam.medals.collection", systemImage: "square.grid.2x2")
                            .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderless)
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
