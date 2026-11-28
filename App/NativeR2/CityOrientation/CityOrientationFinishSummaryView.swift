import SwiftUI
import MapKit

/// S12/S14 finish summary (Fitness workout summary) with the run ranking.
/// Same reads as the medal screen it replaces: the run snapshot, the reward medals, the server
/// result word (U08-01, passed in as `titleKey`) and the existing ending/leaderboard read.
/// fix-1128b #16 (P30): the ranking is a preview read once when the screen opens, with the player's row pinned; a
/// failed read is a quiet retry row (MP board `error`), never an error page.
@MainActor struct CityOrientationFinishSummaryView: View {
    @Bindable var model: PlayExperienceCoordinator
    let titleKey: String
    let subtitle: String
    let medals: [CYMedalItem]
    let shareText: String
    let walkedMeters: Double
    var reportDestination: AnyView? = nil
    /// mp-journey r3: MP finsheet 本局成绩 (`finish-journal-entry`, chapter finish of a mode 1 run with an orient session),
    /// right before 本局战报. Nil hides the row.
    var scoreDestination: AnyView? = nil
    /// The MP badge collection for the first medal earned here (P8: "see the collection"); nil hides the link.
    var collectionDestination: AnyView? = nil
    let onClose: () -> Void
    @State private var loadingBoard = false
    /// P-059: the route draws itself on the thumbnail and the metrics roll up from zero once, on appear.
    @State private var draw = NativeR2DrawOn()
    @State private var revealed = false
    /// OWNER RULE 3 (celebration, run finished): one confetti burst while the record reveals; never under Reduce Motion
    /// (the reveal is instant there) and `CYBurst` itself draws nothing in Low Power (`CYLightBudget`).
    @State private var burst = false
    /// design-r2-play P16: when the finish screen opened, for the record's "date · place" line.
    @State private var finishedAt = Date()
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private struct Metric: Identifiable {
        let id: String
        let value: String
    }

    private var route: PlayRouteMapPresentation? {
        guard let snapshot = model.snapshot else { return nil }
        return PlayRouteMapPresentation(snapshot: snapshot)
    }

    /// Only values the run can read. A missing value drops its cell instead of showing a guess.
    /// mp-journey r3: MP finsheet grid order (mode 1) — 点亮站点 (done count, > 0), 用时, 距离, 解谜分. The rank and
    /// score stay in the ranking section below, as in MP.
    private var metrics: [Metric] {
        var items: [Metric] = []
        if let snapshot = model.snapshot {
            let done = snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
            if done > 0 { items.append(.init(id: "playx.finish.lit", value: String(done))) }
        }
        let seconds = model.clock.elapsedSeconds
        if seconds > 0 { items.append(.init(id: "medalScreen.stat.time", value: PlayRunElapsedText.format(seconds))) }
        if walkedMeters > 0 { items.append(.init(id: "nativeR2.city.metric.distance", value: CityOrientationFormat.distance(walkedMeters, locale: locale))) }
        if let snapshot = model.snapshot {
            let puzzle = PlayPuzzleSummary(snapshot: snapshot)
            if puzzle.count > 0 { items.append(.init(id: "playx.finish.puzzleScore", value: String(puzzle.score))) }
        }
        return items
    }

    /// P16 record title: the route's name (MP topicName); the server result word stays the nav title.
    private var recordTitle: String? {
        let name = model.snapshot?.result.topicName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
    /// P16 place: where the run started (first stop's name, MP stop order).
    private var startPlace: String? {
        guard let snapshot = model.snapshot else { return nil }
        let first = snapshot.visibleNodes.min { ($0.sortID ?? Int.max) < ($1.sortID ?? Int.max) }
        let name = first?.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? nil : name
    }
    private var dateAndPlace: String {
        let day = finishedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute().locale(locale))
        return [day, startPlace].compactMap { $0 }.joined(separator: " · ")
    }
    /// 2 columns for 2 or 4 values, otherwise 3; one column at accessibility sizes (P12).
    private func metricColumns(_ count: Int, accessibility: Bool) -> [GridItem] {
        let n = accessibility ? 1 : (count == 2 || count == 4 ? 2 : min(3, max(1, count)))
        return Array(repeating: GridItem(.flexible(), alignment: .leading), count: n)
    }
    @Environment(\.dynamicTypeSize) private var typeSize

    private var doneCount: Int {
        guard let snapshot = model.snapshot else { return 0 }
        return snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
    }
    private var totalCount: Int { model.snapshot?.visibleNodes.count ?? 0 }

    var body: some View {
        NavigationStack {
            List {
                // design-r2-play P16: a finished run is a named record. Route on the map first, then the title,
                // "date · place", the stats grid; share + Done stay in the top bar.
                if let route, !route.mappedStops.isEmpty {
                    Section {
                        routeThumbnail(route)
                        replayLink(route)
                    }
                }
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: recordTitle ?? appLocalized(String.LocalizationValue(titleKey), locale: locale))
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(verbatim: dateAndPlace).font(.subheadline).foregroundStyle(.secondary)
                            .accessibilityIdentifier("nativeR2.city.finish.datePlace")
                        if !subtitle.isEmpty {
                            Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
                if !metrics.isEmpty {
                    Section {
                        LazyVGrid(columns: metricColumns(metrics.count, accessibility: typeSize.isAccessibilitySize),
                                  alignment: .leading, spacing: 12) {
                            ForEach(metrics) { metric in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey(metric.id)).font(.caption).foregroundStyle(.secondary)
                                    Text(verbatim: revealed ? metric.value : Self.zeroed(metric.value))
                                        .font(.title2.bold().monospacedDigit())
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                        .nativeR2RollingNumber(revealed ? 1 : 0)
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text(LocalizedStringKey(metric.id)))
                                .accessibilityValue(Text(verbatim: metric.value))
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("nativeR2.city.finish.metrics")
                    }
                }
                // Motion r2 R8/R11/R12: mood hero + completion flame at the finish line (P7 moment, under the record).
                MotionR2FinishHeroSection(walkedMeters: walkedMeters, elapsedSeconds: model.clock.elapsedSeconds,
                                          doneCount: doneCount, total: totalCount)
                if let route { CityOrientationLegsSection(route: route) }
                if !medals.isEmpty {
                    // Design pass roam (P8 rewards are objects you keep): each medal is a tile with its name and the
                    // fact behind it, a share exit on the row, and one link to the whole collection below.
                    Section("nativeR2.city.finish.medals") {
                        ForEach(medals) { medal in medalRow(medal) }
                        if let collectionDestination {
                            NavigationLink { collectionDestination } label: {
                                Label("design.roam.medals.collection", systemImage: "square.grid.2x2")
                            }
                            .accessibilityIdentifier("nativeR2.city.finish.collection")
                        }
                    }
                }
                rankingSection
                if let scoreDestination {
                    Section {
                        NavigationLink { scoreDestination } label: {
                            Label("playx.finish.sessionScore", systemImage: "list.number")
                        }
                        .accessibilityIdentifier("playx.finish.sessionScore")
                    }
                }
                if let reportDestination {
                    Section {
                        NavigationLink { reportDestination } label: {
                            Label("mp.entry.journeyReport", systemImage: "flag.checkered")
                        }
                        .accessibilityIdentifier("medalScreen.secondary")
                    }
                }
            }
            .navigationTitle(Text(LocalizedStringKey(titleKey)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: shareText) { Label("nativeR2.city.finish.share", systemImage: "square.and.arrow.up") }
                        .accessibilityIdentifier("medalScreen.share")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("nativeR2.city.done", action: onClose)
                        .accessibilityIdentifier("medalScreen.back")
                }
            }
        }
        .accessibilityIdentifier("medalScreen")
        .motionR2EdgeGlowOnAppear()
        .overlay { if burst { CYBurst(origin: UnitPoint(x: 0.5, y: 0.22), count: 60, duration: 1.4, style: .confetti, reach: 220) } }
        // P30: the finish moment fires one success haptic when the record is revealed (also under Reduce Motion,
        // where the reveal is instant).
        .cyHaptic(.success, trigger: revealed, where: CYHapticTransition.turnedOn)
        .task { await reveal() }
        .task { await loadBoardOnce() }
    }

    /// fix-1128b #16: one automatic ranking read per open; the retry row covers a failure.
    private func loadBoardOnce() async {
        guard model.leaderboard == nil, !loadingBoard else { return }
        loadingBoard = true
        await model.loadEndingAndLeaderboard()
        loadingBoard = false
    }

    private func medalRow(_ medal: CYMedalItem) -> some View {
        HStack(spacing: CYSpacing.md) {
            Group {
                if let art = medal.mpDefault, !art.isSprite {
                    art.image.resizable().scaledToFit()
                } else {
                    Image(systemName: medal.systemImage)
                        .font(.title2)
                        .foregroundStyle(.tint)
                        .symbolEffect(.bounce, value: revealed && !reduceMotion)
                }
            }
            .frame(width: 44, height: 44)
            .background(Circle().fill(.tint.opacity(0.12)))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: medal.name).font(.headline)
                if let subtitle = medal.subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            ShareLink(item: medal.name + " · " + shareText) {
                Label("nativeR2.city.finish.share", systemImage: "square.and.arrow.up")
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
            .accessibilityIdentifier("nativeR2.city.finish.medal.share.\(medal.id)")
        }
        .padding(.vertical, 2)
    }

    /// Reduce Motion (or the motion flag off): final values and the whole route at once.
    private func reveal() async {
        guard !revealed else { return }
        guard NativeR2Flags.motion, !reduceMotion else { revealed = true; await draw.run(reduceMotion: true); return }
        withAnimation(.smooth(duration: 1.2)) { revealed = true }
        burst = true
        await draw.run(reduceMotion: reduceMotion)
        try? await Task.sleep(for: .seconds(1.6))
        burst = false
    }

    /// The starting frame of a rolling value: every digit reads 0 ("00:12:40" → "00:00:00", "3/8" → "0/8" keeps the total).
    static func zeroed(_ value: String) -> String {
        if let slash = value.firstIndex(of: "/") {
            return zeroed(String(value[..<slash])) + String(value[slash...])
        }
        return String(value.map { $0.isNumber ? "0" : $0 })
    }

    private func routeThumbnail(_ route: PlayRouteMapPresentation) -> some View {
        let points = route.mappedStops.compactMap(\.coordinate).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return Map(initialPosition: .region(CYMapRegion.boundingRegion(coordinates: points)), interactionModes: []) {
            ForEach(route.segments) { segment in
                MapPolyline(coordinates: NativeR2RoutePath.leg(
                    CLLocationCoordinate2D(latitude: segment.start.latitude, longitude: segment.start.longitude),
                    CLLocationCoordinate2D(latitude: segment.end.latitude, longitude: segment.end.longitude),
                    index: route.segments.firstIndex(where: { $0.id == segment.id }) ?? 0,
                    count: route.segments.count, progress: draw.progress))
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
            }
            ForEach(route.mappedStops) { stop in
                if let point = stop.coordinate {
                    Marker(String(stop.order), systemImage: stop.state.symbol,
                           coordinate: CLLocationCoordinate2D(latitude: point.latitude, longitude: point.longitude))
                }
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .frame(height: 180)
        .listRowInsets(EdgeInsets())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("nativeR2.city.finish.route"))
        .accessibilityAddTraits(.isImage)
    }

    /// Motion r1: the walked legs replayed with draw-on and rolling counters.
    @ViewBuilder private func replayLink(_ route: PlayRouteMapPresentation) -> some View {
        let legs = NativeR2RouteLeg.walked(in: route, locale: locale)
        if NativeR2Flags.motion, !legs.isEmpty {
            NavigationLink {
                NativeR2RouteReplayView(legs: legs, totalSeconds: model.clock.elapsedSeconds, walkedMeters: walkedMeters)
            } label: {
                Label("nativeR2.motion.replay", systemImage: "play.circle")
            }
            .accessibilityIdentifier("nativeR2.motion.replay.open")
        }
    }

    /// S14 ranking (Game Center leaderboard rows): my row pinned first, then the list.
    @ViewBuilder private var rankingSection: some View {
        if let board = model.leaderboard {
            Section("nativeR2.city.finish.me") {
                rankRow(rank: board.me.rank, name: nil, score: board.me.score, mine: true)
            }
            Section("playx.leaderboard") {
                if board.entries.isEmpty {
                    ContentUnavailableView("nativeR2.city.finish.boardEmpty", systemImage: "list.number")
                }
                ForEach(board.entries) { row in
                    rankRow(rank: row.rank, name: row.name, score: row.score, mine: row.id == board.me.id)
                }
            }
            .motionR2RankMoves(board.entries.map(\.id))
            .accessibilityIdentifier("nativeR2.city.finish.board")
        } else {
            Section {
                if model.leaderboardUnavailable, !loadingBoard {
                    Text("playx.leaderboard.unavailable")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .accessibilityIdentifier("playx.leaderboard.unavailable")
                }
                Button {
                    loadingBoard = true
                    Task { await model.loadEndingAndLeaderboard(); loadingBoard = false }
                } label: {
                    HStack {
                        Label("playx.results.load", systemImage: "list.number")
                        Spacer()
                        if loadingBoard { ProgressView() }
                    }
                }
                .disabled(loadingBoard)
                .accessibilityIdentifier("playx.results.load")
            }
        }
    }

    private func rankRow(rank: Int?, name: String?, score: Int, mine: Bool) -> some View {
        HStack {
            Group {
                if NativeR2Flags.motion2 {
                    MotionR2RankText(rank: rank) // R14
                } else {
                    Text(verbatim: rank.map(String.init) ?? "—").monospacedDigit()
                }
            }
            .frame(minWidth: 32, alignment: .leading)
            if mine, name == nil {
                Text("playx.leaderboard.me")
            } else if let name, !name.isEmpty {
                Text(verbatim: name)
            } else {
                Text("playx.player.unnamed")
            }
            if mine { Image(systemName: "person.fill").foregroundStyle(.tint).accessibilityHidden(true) }
            Spacer()
            Text(verbatim: String(score)).monospacedDigit().foregroundStyle(.secondary)
        }
    }
}
