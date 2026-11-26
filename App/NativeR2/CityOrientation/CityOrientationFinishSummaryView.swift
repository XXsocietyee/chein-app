import SwiftUI
import MapKit

/// S12/S14 finish summary (Fitness workout summary) with the run ranking.
/// Same reads as the medal screen it replaces: the run snapshot, the reward medals, the server
/// result word (U08-01, passed in as `titleKey`) and the existing ending/leaderboard read, which
/// is only sent when the player taps "结局与同行者榜", as before.
@MainActor struct CityOrientationFinishSummaryView: View {
    @Bindable var model: PlayExperienceCoordinator
    let titleKey: String
    let subtitle: String
    let medals: [CYMedalItem]
    let shareText: String
    let walkedMeters: Double
    var reportDestination: AnyView? = nil
    let onClose: () -> Void
    @State private var loadingBoard = false

    private struct Metric: Identifiable {
        let id: String
        let value: String
    }

    private var route: PlayRouteMapPresentation? {
        guard let snapshot = model.snapshot else { return nil }
        return PlayRouteMapPresentation(snapshot: snapshot)
    }

    /// Only values the run can read. A missing value drops its cell instead of showing a guess.
    private var metrics: [Metric] {
        var items: [Metric] = []
        let seconds = model.clock.elapsedSeconds
        if seconds > 0 { items.append(.init(id: "medalScreen.stat.time", value: PlayRunElapsedText.format(seconds))) }
        if let snapshot = model.snapshot, !snapshot.visibleNodes.isEmpty {
            let done = snapshot.visibleNodes.filter { snapshot.isDone($0) }.count
            items.append(.init(id: "medalScreen.stat.nodes", value: "\(done)/\(snapshot.visibleNodes.count)"))
        }
        if walkedMeters > 0 { items.append(.init(id: "nativeR2.city.metric.distance", value: CityOrientationFormat.distance(walkedMeters))) }
        if let me = model.leaderboard?.me {
            if let rank = me.rank { items.append(.init(id: "nativeR2.city.finish.rank", value: String(rank))) }
            items.append(.init(id: "nativeR2.city.finish.score", value: String(me.score)))
        }
        return items
    }

    var body: some View {
        NavigationStack {
            List {
                if !subtitle.isEmpty {
                    Section { Text(verbatim: subtitle).foregroundStyle(.secondary) }
                }
                if !metrics.isEmpty {
                    Section {
                        LazyVGrid(columns: [GridItem(.flexible(), alignment: .leading), GridItem(.flexible(), alignment: .leading)],
                                  alignment: .leading, spacing: 12) {
                            ForEach(metrics) { metric in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(LocalizedStringKey(metric.id)).font(.caption).foregroundStyle(.secondary)
                                    Text(verbatim: metric.value).font(.title2.monospacedDigit())
                                }
                                .accessibilityElement(children: .combine)
                            }
                        }
                        .padding(.vertical, 4)
                        .accessibilityIdentifier("nativeR2.city.finish.metrics")
                    }
                }
                if let route, !route.mappedStops.isEmpty {
                    Section { routeThumbnail(route) }
                }
                if let route { CityOrientationLegsSection(route: route) }
                if !medals.isEmpty {
                    Section("nativeR2.city.finish.medals") {
                        ForEach(medals) { medal in
                            Label {
                                Text(verbatim: medal.name)
                            } icon: {
                                if let art = medal.mpDefault, !art.isSprite {
                                    art.image.resizable().scaledToFit().frame(width: 28, height: 28)
                                } else {
                                    Image(systemName: medal.systemImage)
                                }
                            }
                        }
                    }
                }
                rankingSection
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
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
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
    }

    private func routeThumbnail(_ route: PlayRouteMapPresentation) -> some View {
        let points = route.mappedStops.compactMap(\.coordinate).map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
        return Map(initialPosition: .region(CYMapRegion.boundingRegion(coordinates: points)), interactionModes: []) {
            ForEach(route.segments) { segment in
                MapPolyline(coordinates: [CLLocationCoordinate2D(latitude: segment.start.latitude, longitude: segment.start.longitude),
                                          CLLocationCoordinate2D(latitude: segment.end.latitude, longitude: segment.end.longitude)])
                    .stroke(Color.accentColor, lineWidth: 3)
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

    /// S14 ranking (Game Center leaderboard rows): my row pinned first, then the list.
    @ViewBuilder private var rankingSection: some View {
        if let board = model.leaderboard {
            Section("nativeR2.city.finish.me") {
                rankRow(rank: board.me.rank, name: nil, score: board.me.score, mine: true)
            }
            Section("playx.leaderboard") {
                if board.entries.isEmpty {
                    Text("nativeR2.city.finish.boardEmpty").foregroundStyle(.secondary)
                }
                ForEach(board.entries) { row in
                    rankRow(rank: row.rank, name: row.name, score: row.score, mine: row.id == board.me.id)
                }
            }
            .accessibilityIdentifier("nativeR2.city.finish.board")
        } else {
            Section {
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
            Text(verbatim: rank.map(String.init) ?? "—").monospacedDigit().frame(width: 32, alignment: .leading)
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
