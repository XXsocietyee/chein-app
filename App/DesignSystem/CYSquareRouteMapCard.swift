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
    @QuestifyReduceMotion private var reduceMotion
    private enum Phase: Equatable { case idle, loading, ready(CYSquareRoutePreview), empty }

    var body: some View {
        Group {
            switch phase {
            case .ready(let route): card { map(route) } caption: { Text("route.road", tableName: "SocialParity") }
            case .loading:
                RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYNight.ink1).frame(height: height)
                    .overlay(CYSkeleton().padding(CYSpacing.lg)).accessibilityIdentifier("square.routeMap.loading")
            case .idle, .empty:
                if let snapshotURL, let url = URL(string: snapshotURL), url.scheme == "https" {
                    card {
                        AsyncImage(url: url) { image in
                            if let loaded = image.image { loaded.resizable().scaledToFill() } else { CYNight.indigo }
                        }
                    } caption: { Text("route.snapshot", tableName: "SocialParity") }
                }
            }
        }
        .animation(CYMotion.resolve(CYMotion.standard, reduceMotion: reduceMotion), value: phase)
        .task(id: topicID) { await load() }
    }

    private func card<M: View, C: View>(@ViewBuilder _ media: () -> M, @ViewBuilder caption: () -> C) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            media()
                .frame(height: height).frame(maxWidth: .infinity)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
            HStack(spacing: CYSpacing.sm) {
                caption().cyText(.caption).foregroundStyle(CYColor.textTertiary)
                Spacer(minLength: 0)
                if let onOpenTopic {
                    Button(action: onOpenTopic) {
                        HStack(spacing: CYSpacing.xxs) {
                            Text("route.openTopic", tableName: "SocialParity")
                            Image(systemName: "chevron.right")
                        }
                        .cyText(.label).foregroundStyle(CYColor.textSecondary)
                        .frame(minHeight: CYSpacing.minTouchTarget)
                    }
                    .buttonStyle(.cyPressable)
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
        return Map(initialPosition: .region(region), interactionModes: [.zoom, .pan]) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                MapPolyline(coordinates: segment.map(\.coordinate)).stroke(CYNight.lantern, lineWidth: 4)
            }
            ForEach(Array(route.nodes.enumerated()), id: \.element.id) { index, node in
                Annotation(node.title, coordinate: node.coordinate) {
                    Button { selected = selected == node.id ? nil : node.id } label: {
                        CYMapMarker(kind: .route, selected: selected == node.id)
                            .overlay {
                                Text(verbatim: "\(index + 1)")
                                    .cyText(.caption, weight: .bold, monospacedDigit: true)
                                    .foregroundStyle(CYNight.ink0)
                            }
                            .scaleEffect(selected == node.id && !reduceMotion ? 1.15 : 1)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .accessibilityLabel(Text(verbatim: node.title))
                }
                .annotationTitles(selected == node.id ? .visible : .hidden)
            }
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted))
        .environment(\.colorScheme, .light)
        .background { CYMapPlaceholder(fog: false) }
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
