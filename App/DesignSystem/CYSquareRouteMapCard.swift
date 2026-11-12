import SwiftUI
import MapKit

/// Mini `square/components/route-map`: topic chapter nodes as numbered markers plus one route line.
/// Road geometry only when the supplier verified it; otherwise the nodes are joined directly and the
/// caption says so. The card renders nothing until the route is ready (mini `wx:if="{{routeReady}}"`).
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
            case .ready(let route): card { map(route) } caption: { Text(route.isRoad ? "route.road" : "route.direct", tableName: "SocialParity") }
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
                caption().font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
                Spacer(minLength: 0)
                if let onOpenTopic {
                    Button(action: onOpenTopic) {
                        HStack(spacing: CYSpacing.xxs) {
                            Text("route.openTopic", tableName: "SocialParity")
                            Image(systemName: "chevron.right")
                        }
                        .font(CYTypography.label).foregroundStyle(CYColor.textSecondary)
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
        let line = route.roadPolyline ?? route.nodes
        return Map(initialPosition: .automatic, interactionModes: [.zoom, .pan]) {
            if line.count >= 2 {
                MapPolyline(coordinates: line.map(\.coordinate)).stroke(CYNight.lantern, lineWidth: 4)
            }
            ForEach(Array(route.nodes.enumerated()), id: \.element.id) { index, node in
                Annotation(node.title, coordinate: node.coordinate) {
                    Button { selected = selected == node.id ? nil : node.id } label: {
                        Text(verbatim: "\(index + 1)")
                            .font(CYTypography.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(CYNight.ink0)
                            .frame(width: 28, height: 28)
                            .background(Circle().fill(CYNight.lantern))
                            .overlay(Circle().strokeBorder(CYNight.lanternHot, lineWidth: 2))
                            .scaleEffect(selected == node.id && !reduceMotion ? 1.15 : 1)
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .accessibilityLabel(Text(verbatim: node.title))
                }
                .annotationTitles(selected == node.id ? .visible : .hidden)
            }
        }
        .mapStyle(.standard(pointsOfInterest: .excludingAll))
        .environment(\.colorScheme, .dark)
    }

    private func load() async {
        guard let provider, topicID > 0 else { phase = .empty; return }
        phase = .loading
        do {
            let route = try await provider.route(topicID: topicID)
            try Task.checkCancellation()
            phase = route.ready ? .ready(route) : .empty
        } catch is CancellationError {
        } catch { phase = .empty }
    }
}
