import SwiftUI

@MainActor struct RoamHistoryView: View {
    let reader: any RoamExperienceReading
    var liveDestination: (() -> AnyView)? = nil
    /// 那年今日 / 月度回顾 reader; nil shows each tool's own "not configured" state.
    var toolsReader: (any RoamPassportToolsReading)? = nil
    /// Owner-only export; nil hides the 导出 tool.
    var privateToolsReader: (any RoamPrivateToolsServing)? = nil
    var anniversaryRouteDestination: ((String) -> AnyView)? = nil
    @State private var historyRead = RoamHistoryListRead()
    /// RHIST-3: empty / in-progress states offer the MP next step (出发第一次漫游 / 回到地图).
    @Environment(\.dismiss) private var dismissHistory
    @State private var startFirstWalk = false
    @State private var liveEntry = RoamHistoryLiveEntry()
    @State private var localWalk = RoamHistoryLocalWalkState()
    @Namespace private var hero
    @ViewBuilder private var unreadableNotice: some View {
        Label("roam.historyLocal.unreadable", systemImage: "exclamationmark.circle")
            .cyText(.meta).foregroundStyle(.secondary)
        Button("action.retry", action: load).accessibilityIdentifier("roam.historyLocal.retry")
    }
    var body: some View {
        let records = historyRead.records(for: reader)
        let error = historyRead.error(for: reader)
        let loaded = historyRead.loaded(for: reader)
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                RoamExperienceNotice(offline: reader.isOfflineExample)
                if let error {
                    if RoamHistoryErrorPresentation.resolve(error: error) == .denied {
                        Label("roam.history.denied", systemImage: "lock")
                            .cyText(.body).foregroundStyle(CYColor.textSecondary)
                            .padding(CYSpacing.lg).frame(maxWidth: .infinity, alignment: .leading)
                            .cyNightGlass(cornerRadius: CYRadius.md)
                            .accessibilityIdentifier("roam.experience.history.denied")
                    } else { RoamExperienceIssue(error: error, retry: load) }
                }
                else if !loaded { CYSkeleton().accessibilityLabel(Text("roamSub.w208.history.loading")) }
                else if records.isEmpty {
                    RoamHistoryRemoteStatusBanner()   // RHIST-2
                    if toolsReader != nil { RoamHistoryToolsRow(reader: toolsReader, privateTools: privateToolsReader, anniversaryRouteDestination: anniversaryRouteDestination) }
                    if let keys = localWalk.noticeKeys(reader: reader) {
                        CYEmptyState(systemImage: "pause.circle", LocalizedStringKey(keys.title), detail: LocalizedStringKey(keys.hint),
                                     actionTitle: "roam.historyLocal.backToMap", actionIdentifier: "roam.history.backToMap",
                                     action: { dismissHistory() })
                            .accessibilityIdentifier("roam.experience.history.unfinished")
                    } else {
                        // MP scene-roam-history: cy-empty kind="empty" (MP illustration), 还没有漫游记录, no sub, 出发第一次漫游.
                        CYEmptyState(systemImage: "tray", "roam.experience.historyEmpty",
                                     actionTitle: "roamSub.w208.history.emptyCTA", actionIdentifier: "roam.history.startFirst",
                                     actionStyle: .primary,
                                     action: { if liveDestination != nil { startFirstWalk = true } else { dismissHistory() } })
                            .navigationDestination(isPresented: $startFirstWalk) { liveDestination?() }
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("roam.experience.history.empty")
                    }
                    if localWalk.failed(reader: reader) { unreadableNotice }
                    if liveEntry.canOpen(reader: reader, hasDestination: liveDestination != nil) {
                        let presentationID = liveEntry.presentationID
                        Button("roam.experience.live", systemImage: "figure.walk") {
                            liveEntry.activate(reader: reader, hasDestination: liveDestination != nil, presentationID: presentationID)
                        }
                        .buttonStyle(.cyPrimary(fullWidth: true))
                        .accessibilityIdentifier("roam.experience.history.live.open")
                    }
                } else {
                    // RHIST-7: the local-unreadable warning also shows above existing rows (MP index.wxml:7).
                    if localWalk.failed(reader: reader) { unreadableNotice }
                    RoamHistoryRemoteStatusBanner()   // RHIST-2: server page unreadable, local rows only
                    let summary = RoamHistorySummary(records)
                    // Mini-program order: total (big km, then trips and shops), tools, then run cards.
                    RoamExperienceCard { VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Group {
                                if let distance = summary.knownKilometers, summary.tripsWithDistance > 0 {
                                    Text(distance, format: .number.precision(.fractionLength(2)))
                                } else { Text(verbatim: "—") }
                            }
                            .cyText(.data2XL).monospacedDigit().foregroundStyle(CYColor.textPrimary)
                            .contentTransition(.numericText())
                            .cyWrapText()
                            Text("roam.history.km").cyText(.cardTitle).foregroundStyle(CYColor.textSecondary)
                        }
                        .accessibilityElement(children: .combine)
                        // 次漫游 · 家店 · 用时 columns under the total, as in the mini-program.
                        RoamHistoryParityStrip(records: records)
                    } }
                    if toolsReader != nil { RoamHistoryToolsRow(reader: toolsReader, privateTools: privateToolsReader, anniversaryRouteDestination: anniversaryRouteDestination) }
                    ForEach(Array(records.enumerated()), id: \.element.id) { index, record in
                        if RoamHistoryMonthHead.isNewMonth(record, after: index > 0 ? records[index - 1] : nil), let date = record.recordedAt {
                            RoamHistoryMonthHead(date: date)
                        }
                        // Mini-program RunCard: route sketch on top, then route icon + title with dateCard, three stats, badges.
                        NavigationLink { RoamHistoryDetailView(reader: reader, timestamp: record.ts, hero: hero) } label: {
                            RoamExperienceCard {
                                VStack(alignment: .leading, spacing: 12) {
                                    RoamRouteSketchView(record: record)
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                                            .font(.subheadline.weight(.semibold)).foregroundStyle(CYColor.textPrimary).accessibilityHidden(true)
                                        RoamRunCardTitle(record: record, style: .cardTitle).foregroundStyle(CYColor.textPrimary).cyWrapText()
                                        Spacer(minLength: 8)
                                        RoamRunCardDateText(record: record)
                                    }
                                    RoamRunCardParityMeta(record: record)
                                }
                            }
                        }.buttonStyle(QuestifyCardButtonStyle())
                            .cyHeroSource(record.ts, in: hero)
                            .accessibilityLabel(record.portRunCardAccessibilityLabel)
                            .accessibilityIdentifier("roam.experience.history.record")
                    }
                }
            }.padding(CYSpacing.pageHorizontal)
        }.background(CYColor.bgPage.ignoresSafeArea()).cyPageTitle("roam.experience.history").cyHideTabBar()
            .task(id: RoamHistoryLiveOwner(reader: reader)) { load() }
            .onAppear { liveEntry.appear() }
            .onDisappear { liveEntry.disappear() }
            .onChange(of: RoamHistoryLiveOwner(reader: reader)) { _, _ in
                liveEntry.retireIfOwnerChanged(reader: reader, hasDestination: liveDestination != nil)
            }
            .onChange(of: liveDestination != nil) { _, _ in
                liveEntry.retireIfOwnerChanged(reader: reader, hasDestination: liveDestination != nil)
            }
            .navigationDestination(item: $liveEntry.target) { target in
                if liveEntry.matches(target, reader: reader, hasDestination: liveDestination != nil), let liveDestination {
                    liveDestination()
                }
            }
            .modifier(RoamPassportHistoryNavigation(localReader: reader))
            .background {
                if error == nil, loaded, !records.isEmpty {
                    RoamHostedAccessibilityAnchor(identifier: "roam.experience.history.record")
                }
            }
            // A screen-level identifier is only exposed when the screen is an accessibility container (iOS 27 SwiftUI drops
            // it otherwise); `.contain` keeps every child element as it was.
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("roam.experience.history")
    }
    private func load() {
        localWalk.invalidate()
        let snapshot = liveEntry.beginRead(reader: reader)
        guard historyRead.load(reader: reader, expected: snapshot) else { return }
        let records = historyRead.records(for: reader)
        if records.isEmpty { localWalk.load(reader: reader) }
        liveEntry.acceptRead(isEmpty: records.isEmpty, snapshot: snapshot, reader: reader)
    }
}

/// Fence the list's summary, rows and errors immediately, before a replacement
/// SwiftUI task reloads. Like detail/local-walk state, a read belongs to one owner.
@MainActor struct RoamHistoryListRead {
    private var owner: RoamHistoryLiveOwner?
    private var values: [RoamHistoryRecord] = []
    private var failure: Error?
    private var didLoad = false

    @discardableResult mutating func load(reader: any RoamExperienceReading,
                                         expected: RoamHistoryLiveOwner) -> Bool {
        owner = nil; values = []; failure = nil; didLoad = false
        guard expected == RoamHistoryLiveOwner(reader: reader) else { return false }
        do {
            let result = try reader.history()
            guard expected == RoamHistoryLiveOwner(reader: reader) else { return false }
            owner = expected; values = result; didLoad = true
            return true
        } catch {
            guard expected == RoamHistoryLiveOwner(reader: reader) else { return false }
            owner = expected; failure = error
            return false
        }
    }
    func records(for reader: any RoamExperienceReading) -> [RoamHistoryRecord] {
        owner == RoamHistoryLiveOwner(reader: reader) ? values : []
    }
    func error(for reader: any RoamExperienceReading) -> Error? {
        owner == RoamHistoryLiveOwner(reader: reader) ? failure : nil
    }
    func loaded(for reader: any RoamExperienceReading) -> Bool {
        owner == RoamHistoryLiveOwner(reader: reader) && didLoad
    }
}

/// A local read result is visible only to the exact reader/account/epoch that produced it.
@MainActor struct RoamHistoryLocalWalkState {
    private var owner: RoamHistoryLiveOwner?
    private var status: RoamLocalWalkStatus = .unavailable
    private var readFailed = false
    mutating func invalidate() { owner = nil; status = .unavailable; readFailed = false }
    mutating func load(reader: any RoamExperienceReading) {
        invalidate()
        let captured = RoamHistoryLiveOwner(reader: reader)
        guard captured.scopeKey != nil else { return }
        do {
            let value = try reader.localWalkStatus()
            guard captured == RoamHistoryLiveOwner(reader: reader) else { return }
            owner = captured; status = value
        } catch {
            guard captured == RoamHistoryLiveOwner(reader: reader) else { return }
            owner = captured; readFailed = true
        }
    }
    func failed(reader: any RoamExperienceReading) -> Bool {
        owner == RoamHistoryLiveOwner(reader: reader) && readFailed
    }
    func noticeKeys(reader: any RoamExperienceReading) -> (title: String, hint: String)? {
        guard owner == RoamHistoryLiveOwner(reader: reader), !readFailed else { return nil }
        switch status {
        case .unfinished: return ("roam.historyLocal.unfinished", "roam.historyLocal.unfinishedHint")
        case .finishPending: return ("roam.historyLocal.finishPending", "roam.historyLocal.finishPendingHint")
        case .unavailable, .none: return nil
        }
    }
}

/// This only selects the already supplied live screen. It never creates or starts a roam session.
struct RoamHistoryLiveOwner: Equatable, Hashable {
    let readerID: ObjectIdentifier
    let scopeKey: String?
    let epoch: UInt64?
    let isConfigured: Bool
    @MainActor init(reader: any RoamExperienceReading) {
        let identity = reader.identity
        readerID = ObjectIdentifier(reader)
        // storageKey preserves the exact UTF-8 namespace, market, deployment and account bytes.
        scopeKey = identity?.scope.storageKey
        epoch = identity?.epoch
        isConfigured = reader.isConfigured
    }
    var isAuthorized: Bool { scopeKey != nil && isConfigured }
}
@MainActor struct RoamHistoryLiveEntry {
    struct Target: Hashable {
        let id = UUID()
        let owner: RoamHistoryLiveOwner
    }
    private var owner: RoamHistoryLiveOwner?
    private var successfulEmptyRead = false
    private var visible = false
    private(set) var presentationID = UUID()
    var target: Target?

    mutating func beginRead(reader: any RoamExperienceReading) -> RoamHistoryLiveOwner {
        invalidate()
        let snapshot = RoamHistoryLiveOwner(reader: reader)
        owner = snapshot
        return snapshot
    }
    mutating func acceptRead(isEmpty: Bool, snapshot: RoamHistoryLiveOwner, reader: any RoamExperienceReading) {
        successfulEmptyRead = isEmpty && owner == snapshot && snapshot == RoamHistoryLiveOwner(reader: reader)
    }
    mutating func appear() { visible = true; presentationID = UUID() }
    mutating func disappear() {
        // Pushing the live screen hides this view; retain its active destination until native Back.
        visible = false; presentationID = UUID()
    }
    func canOpen(reader: any RoamExperienceReading, hasDestination: Bool) -> Bool {
        visible && target == nil && hasDestination && successfulEmptyRead && owner?.isAuthorized == true
            && owner == RoamHistoryLiveOwner(reader: reader)
    }
    mutating func activate(reader: any RoamExperienceReading, hasDestination: Bool, presentationID: UUID) {
        guard self.presentationID == presentationID, canOpen(reader: reader, hasDestination: hasDestination), let owner else { return }
        target = Target(owner: owner)
    }
    func matches(_ target: Target, reader: any RoamExperienceReading, hasDestination: Bool) -> Bool {
        self.target == target && hasDestination && target.owner.isAuthorized
            && target.owner == RoamHistoryLiveOwner(reader: reader)
    }
    mutating func retireIfOwnerChanged(reader: any RoamExperienceReading, hasDestination: Bool) {
        if owner != RoamHistoryLiveOwner(reader: reader) || !hasDestination { invalidate() }
    }
    private mutating func invalidate() {
        target = nil; owner = nil; successfulEmptyRead = false; presentationID = UUID()
    }
}
@MainActor struct RoamHistoryDetailView: View {
    let reader: any RoamExperienceReading
    let timestamp: Int64
    /// Namespace of the history list the card zoomed out of; nil (live finish, share) keeps the plain push.
    var hero: Namespace.ID? = nil
    @State private var record: RoamHistoryRecord?
    @State private var showShare = false
    @State private var selectedMedal: RoamMedalShareSelection?
    @Environment(\.dismiss) private var dismiss
    @State private var loaded = false
    @State private var error: Error?
    @State private var loadedOwner: ReadKey?
    private struct ReadKey: Hashable {
        let owner: RoamHistoryLiveOwner
        let timestamp: Int64
    }
    private var readKey: ReadKey { .init(owner: .init(reader: reader), timestamp: timestamp) }
    private var currentRecord: RoamHistoryRecord? { loadedOwner == readKey ? record : nil }
    private var currentError: Error? { loadedOwner == readKey ? error : nil }
    private var currentLoaded: Bool { loadedOwner == readKey && loaded }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                RoamExperienceNotice(offline: reader.isOfflineExample)
                if let error = currentError { RoamExperienceIssue(error: error, retry: load) }
                else if let record = currentRecord {
                    // Mini-program scene-roam-session: date · time under 本次漫游, the 本次路线 replay card,
                    // the 总距离 / 时长 / 探店 / 探索度 rows, then 解锁奖励 and 点亮地点, each with its own empty line.
                    RoamSessionParityHeader(record: record)
                    RoamExperienceCard {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .firstTextBaseline) {
                                Text("roamSub.w208.session.routeEyebrow").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                    .accessibilityAddTraits(.isHeader)
                                Spacer(minLength: 8)
                                if let date = record.recordedAt {
                                    Text(date, format: .dateTime.year().month().day().weekday(.abbreviated))
                                        .cyText(.caption).foregroundStyle(CYColor.textSecondary)
                                }
                            }
                            RoamSavedRouteReplayView(reader: reader, record: record)
                        }
                    }
                    RoamRecordedStats(record: record)
                    let medals = RoamMedalShareSelection.selections(for: record)
                    Text("roam.experience.rewards").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                    if medals.isEmpty {
                        Text("roam.experience.rewardsEmpty").foregroundStyle(CYColor.textSecondary)
                    }
                    ForEach(medals) { medal in
                        Button { showShare = false; selectedMedal = medal } label: {
                            HStack(spacing: CYSpacing.md) {
                                Image(systemName: "star").font(.title3.weight(.semibold)).foregroundStyle(CYNight.ink0)
                                    .frame(width: 52, height: 56)
                                    .background(CYNight.lantern, in: RoamHexagon())
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: medal.card.name).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                                    Text("roamSub.w208.session.medalCategory").cyText(.caption).foregroundStyle(CYColor.textSecondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "square.and.arrow.up").foregroundStyle(CYColor.textTertiary)
                            }
                            .frame(minHeight: 44, alignment: .leading)
                        }
                        .buttonStyle(QuestifyCardButtonStyle())
                        .accessibilityLabel(Text("roam.medalShare.open") + Text(verbatim: ": " + medal.card.name))
                        .accessibilityIdentifier("roam.medalShare.open." + medal.card.kind.rawValue)
                    }
                    Text("roam.experience.recordedPlaces").cyText(.sectionTitle).foregroundStyle(CYColor.textPrimary).accessibilityAddTraits(.isHeader)
                    if record.pois.isEmpty {
                        Text("roam.experience.recordedPlacesEmpty").foregroundStyle(CYColor.textSecondary)
                    }
                    ForEach(Array(record.pois.enumerated()), id: \.offset) { _, place in
                        HStack(spacing: CYSpacing.md) {
                            Image(systemName: place.cat == "merchant" ? "storefront" : "mappin").font(.title3).foregroundStyle(CYColor.textPrimary)
                                .frame(width: 52, height: 56).background(CYNight.ink2, in: RoamHexagon()).accessibilityHidden(true)
                            RoamTitle(place.name)
                        }
                    }
                    Button { showShare = true } label: {
                        Label("roam.share.title", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.questifyPrimary)
                    .accessibilityIdentifier("roam.share.open")
                } else if currentLoaded {
                    // Mini-program empty state: 找不到这次漫游 with one way back to the history list.
                    CYEmptyState(systemImage: "info.circle", "roam.experience.recordMissing",
                                 actionTitle: "roamSub.w208.session.missingBack", action: { dismiss() })
                        .accessibilityIdentifier("roam.experience.history.missing")
                } else { ProgressView("roam.loading") }
            }.padding()
        }.background(CYColor.bgPage.ignoresSafeArea())
            .modifier(RoamHistoryHeroDestination(id: timestamp, hero: hero))
            .cyPageTitle("roam.experience.session")
            .cyHideTabBar()
            .task(id: readKey) { showShare = false; selectedMedal = nil; load() }
            .onChange(of: readKey) { _, _ in showShare = false; selectedMedal = nil }
            .sheet(isPresented: $showShare) { Group { if let record = currentRecord { NavigationStack { RoamHistoryShareView(record: record, reader: reader) } } }.cySheet(detents: [.large]) }
            .sheet(item: $selectedMedal) { medal in
                Group {
                    if currentRecord == medal.record {
                        NavigationStack { RoamMedalShareView(selection: medal, reader: reader) }
                    }
                }.cySheet(detents: [.large])
            }
            .accessibilityIdentifier("roam.experience.session")
    }
    private func load() {
        record = nil; error = nil; loaded = false; loadedOwner = nil
        let captured = readKey
        do {
            let value = try reader.history().first { $0.ts == timestamp }
            guard captured == readKey else { return }
            record = value; loaded = true; loadedOwner = captured
        } catch {
            guard captured == readKey else { return }
            self.error = error; loadedOwner = captured
        }
    }
}

private struct RoamHistoryHeroDestination: ViewModifier {
    let id: Int64
    let hero: Namespace.ID?
    @ViewBuilder func body(content: Content) -> some View {
        if let hero { content.cyHeroDestination(id, in: hero) } else { content }
    }
}

/// Pointy-top hexagon behind 解锁奖励 / 点亮地点 marks (mini-program `.rw__hex`).
struct RoamHexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.25))
        path.addLine(to: CGPoint(x: rect.minX + w, y: rect.minY + h * 0.75))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.75))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + h * 0.25))
        path.closeSubpath()
        return path
    }
}
