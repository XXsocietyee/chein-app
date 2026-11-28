import SwiftUI
import MapKit

/// Mini `square/components/route-map`: numbered stops plus one verified road segment per chapter.
/// Chapters are not joined. Missing or unverified geometry hides the live map (a post snapshot can
/// still show). The card does not draw a straight line through the stops.
struct CYSquareRouteMapCard: View {
    let topicID: Int
    var height: CGFloat = 200
    /// Static snapshot already attached to the post (MAP_SNAPSHOT); shown while there is no live provider.
    var snapshotURL: String? = nil
    /// Mini detail `goSportTopic`: the link under the map back to the topic.
    var onOpenTopic: (() -> Void)? = nil
    @Environment(\.squareRouteMap) private var provider
    @State private var phase: Phase = .idle
    @State private var selected: Int?
    private enum Phase: Equatable { case idle, loading, ready(CYSquareRoutePreview), empty }

    // r10 N-24 (rest): MP square/components/route-map is a plain map under the post. Native: a MapKit `Map` with
    // numbered `Marker`s and the road `MapPolyline`s, system loading `ProgressView`, no night palette, stroke or card.
    var body: some View {
        Group {
            switch phase {
            case .ready(let route): card { map(route) } caption: { Text("route.road", tableName: "SocialParity") }
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: height)
                    .accessibilityIdentifier("square.routeMap.loading")
            case .idle, .empty:
                if let snapshotURL, let url = URL(string: snapshotURL), url.scheme == "https" {
                    card {
                        AsyncImage(url: url) { image in
                            if let loaded = image.image { loaded.resizable().scaledToFill() } else { Color(uiColor: .secondarySystemFill) }
                        }
                    } caption: { Text("route.snapshot", tableName: "SocialParity") }
                }
            }
        }
        .task(id: topicID) { await load() }
    }

    private func card<M: View, C: View>(@ViewBuilder _ media: () -> M, @ViewBuilder caption: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            media()
                .frame(height: height).frame(maxWidth: .infinity)
                .clipped()
            HStack(spacing: 8) {
                caption().font(.caption).foregroundStyle(.secondary)
                Spacer(minLength: 0)
                if let onOpenTopic {
                    Button(action: onOpenTopic) {
                        Text("route.openTopic", tableName: "SocialParity")
                            .frame(minHeight: CYSpacing.minTouchTarget)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderless)
                    .font(.footnote)
                    .accessibilityIdentifier("square.routeMap.openTopic")
                }
            }
        }
        .accessibilityIdentifier("square.routeMap")
    }

    private func map(_ route: CYSquareRoutePreview) -> some View {
        let segments = route.roadSegments.filter { $0.count >= 2 }
        let region = CYMapRegion.boundingRegion(
            coordinates: segments.flatMap { $0.map(\.coordinate) } + route.nodes.map(\.coordinate)
        )
        return Map(initialPosition: .region(region), interactionModes: [.zoom, .pan], selection: $selected) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.map(\.coordinate)).stroke(.tint, lineWidth: 4)
            }
            ForEach(Array(route.nodes.enumerated()), id: \.element.id) { index, node in
                Marker(node.title, monogram: Text(verbatim: "\(index + 1)"), coordinate: node.coordinate)
                    .tag(node.id)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
    }

    private func load() async {
        guard let provider, topicID > 0 else { phase = .empty; return }
        phase = .loading
        do {
            let route = try await provider.route(topicID: topicID)
            try Task.checkCancellation()
            phase = route.isRoad ? .ready(route) : .empty
        } catch is CancellationError {
        } catch { phase = .empty }
    }
}
