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
    @Environment(\.analyticsEventClient) private var analytics

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                head
                Rectangle().fill(CYNight.glassEdgeTop).frame(height: 1).padding(.top, CYSpacing.md)
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
                mapPanel.padding(.top, CYSpacing.xl).padding(.horizontal, -CYSpacing.lg)
                actions.padding(.top, CYSpacing.xl)
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.bottom, CYSpacing.xxl)
        }
        .background(Color.black.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .cySheet(isPresented: $showShare) {
            Group { if let record = report.record { NavigationStack { RoamHistoryShareView(record: record, reader: history) } } }
                .cySheet(detents: [.large])
        }
        .accessibilityIdentifier("roam.finishReport")
        .onAppear {
            guard !trackedRouteStory, report.story?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else { return }
            trackedRouteStory = true
            MiniProgramAnalytics.track(analytics, "roam_route_story_shown", bizType: "roam", pagePath: "/pages/roam/index")
        }
        .cyDomainScreen(.player)
    }

    private var head: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            dateLine.cyText(.bodyCompact).foregroundStyle(CYColor.textTertiary)
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.md) {
                titleText
                    .cyText(.pageTitle).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: 0)
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.title3.weight(.medium)).foregroundStyle(CYColor.textPrimary)
                        .frame(minWidth: 44, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("u10.roamFinish.close"))
                .accessibilityIdentifier("roam.finishReport.close")
            }
        }
        .padding(.top, CYSpacing.md)
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
    private var bigNumber: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(verbatim: report.shops.map(String.init) ?? "—")
                .font(.system(.largeTitle, design: .default).weight(.black).italic())
                .dynamicTypeSize(.accessibility3)
                .monospacedDigit()
                .foregroundStyle(CYColor.textPrimary)
            Text("u10.roamFinish.shops").cyText(.sheetTitle).foregroundStyle(CYColor.textPrimary)
        }
        .padding(.top, CYSpacing.xl)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("roam.finishReport.shops")
    }
    private var grid: some View {
        HStack(alignment: .top, spacing: CYSpacing.sm) {
            cell(report.explorePct.map { "\($0)%" }, "u10.roamFinish.explore", id: "explore")
            cell(report.stamps.map(String.init), "u10.roamFinish.stamps", id: "stamps")
            cell(report.xp.map { $0 > 0 ? "+\($0)" : "0" }, "u10.roamFinish.xp", id: "xp")
            cell(String(report.medals), "u10.roamFinish.medals", id: "medals")
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
            Rectangle().fill(CYNight.ink1)
            if report.track.count > 1, let record = report.record {
                RoamRouteSketchView(record: record).padding(CYSpacing.lg)
            } else {
                Label("u10.roamFinish.noTrack", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                    .cyText(.bodyCompact).foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, CYSpacing.lg).padding(.vertical, CYSpacing.sm)
                    .overlay(Capsule().strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
                    .accessibilityIdentifier("roam.finishReport.noTrack")
            }
        }
        .frame(minHeight: 300)
        .overlay(alignment: .topLeading) {
            if let address = report.currentAddress {
                Text(verbatim: address).cyText(.label).foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, CYSpacing.md).padding(.vertical, CYSpacing.sm)
                    .background(CYNight.ink0, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
                    .padding(CYSpacing.lg)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if history.identity != nil {
                NavigationLink {
                    RoamHistoryDetailView(reader: history, timestamp: report.timestamp)
                } label: {
                    Label("u10.roamFinish.data", systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                        .cyText(.label).foregroundStyle(CYColor.textPrimary)
                        .padding(.horizontal, CYSpacing.lg).frame(minHeight: 44)
                        .background(CYNight.ink0, in: Capsule())
                        .overlay(Capsule().strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(CYSpacing.lg)
                .accessibilityIdentifier("roam.finishedHistory.record.open")
            }
        }
    }
    private var actions: some View {
        VStack(spacing: CYSpacing.lg) {
            CYPillButton("u10.roamFinish.share") { showShare = true }
                .disabled(report.record == nil)
                .accessibilityLabel(Text("u10.roamFinish.shareLabel"))
                .accessibilityIdentifier("roam.finishReport.share")
            if history.identity != nil {
                NavigationLink { RoamHistoryView(reader: history) } label: {
                    Text("u10.roamFinish.history").cyText(.bodyMedium).foregroundStyle(CYColor.textSecondary)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("roam.finishedHistory.history.open")
            }
        }
        .frame(maxWidth: .infinity)
    }
}
