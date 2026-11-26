import SwiftUI
import MapKit

/// Mini-program im/chat `fetchTopics`: a route/signup card carries only a topic ID
/// and its display is read fresh from `/api/topic/info-to-user` (TopicReading.topicDetail).
/// Values the server omits stay hidden; nothing (mileage, point count) defaults to 0.
/// Unlike the source, a failed read is not reported as 已下架: only a successful
/// read proves anything, so failure shows an unavailable state with retry.
@MainActor struct IMRouteCardPreview: View {
    let topicID: Int
    let isSignup: Bool
    let reader: any TopicReading
    @State private var detail: TopicDetail?
    @State private var failed = false
    @State private var loading = false
    @State private var loadedScope: UUID?
    var body: some View {
        Group {
            if let detail, loadedScope == reader.scope {
                VStack(alignment: .leading) {
                    if isSignup {
                        Label {
                            Text("im.card.signupFlag")
                        } icon: {
                            Image(systemName: "checkmark.seal").foregroundStyle(.green)
                        }
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    }
                    Color.clear
                        .aspectRatio(16.0 / 9.0, contentMode: .fit)
                        .overlay {
                            if let url = coverURL(detail) {
                                AsyncImage(url: url) { phase in
                                    if let image = phase.image {
                                        image.resizable().scaledToFill()
                                    } else {
                                        // MP im/chat/index.wxml:92: no cover shows `/images/cover-route.svg`.
                                        MPAsset.BannerCover.coverRoute.resizable().scaledToFill()
                                    }
                                }
                            } else {
                                MPAsset.BannerCover.coverRoute.resizable().scaledToFill()
                            }
                        }
                        .clipped()
                        .accessibilityHidden(true)
                    Text(verbatim: displayName(detail.name))
                        .font(.headline)
                    if let meta = summary(detail) {
                        meta
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("im.card.route.loaded")
            } else if failed {
                ContentUnavailableView {
                    Label("im.card.routeUnavailable", systemImage: "exclamationmark.triangle")
                } description: {
                    EmptyView()
                } actions: {
                    Button("messaging.retry") { Task { await load() } }
                        .buttonStyle(.bordered)
                        .accessibilityIdentifier("im.card.route.retry")
                }
                .disabled(loading)
                .accessibilityIdentifier("im.card.route.unavailable")
            } else {
                HStack {
                    Text("im.card.routeLoading")
                        .foregroundStyle(.secondary)
                    Spacer()
                    ProgressView()
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("im.card.route.loading")
            }
        }
        .task(id: reader.scope) { await load() }
    }
    private func displayName(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "—" : name
    }
    /// HTTPS cover only. Anything else falls back to the MP route cover.
    private func coverURL(_ detail: TopicDetail) -> URL? {
        let candidates = [detail.imageURL].compactMap { $0 } + detail.images
        for raw in candidates {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard let url = URL(string: trimmed), url.scheme?.lowercased() == "https" else { continue }
            return url
        }
        return nil
    }
    /// "x km · N 个点" with only the parts the server actually returned.
    private func summary(_ detail: TopicDetail) -> Text? {
        var mileage: Text?
        if let value = detail.totalMileage, value.isFinite, value >= 0 {
            mileage = Text(verbatim: value.formatted(.number.precision(.fractionLength(0...1))) + " km")
        }
        var points: Text?
        if let count = detail.locationCount, count >= 0 { points = Text("im.card.pointCount \(count)") }
        switch (mileage, points) {
        case let (m?, p?): return m + Text(verbatim: " · ") + p
        case let (m?, nil): return m
        case let (nil, p?): return p
        default: return nil
        }
    }
    private func load() async {
        guard reader.isConfigured, !loading else { failed = !reader.isConfigured; return }
        let scope = reader.scope
        loading = true; failed = false
        defer { loading = false }
        do {
            let value = try await reader.topicDetail(id: topicID)
            guard !Task.isCancelled, reader.scope == scope, value.id == topicID else { return }
            detail = value; loadedScope = scope
        } catch {
            guard !Task.isCancelled, reader.scope == scope else { return }
            detail = nil; failed = true
        }
    }
}

/// Mini-program `onLocationTap` opens an in-app map at the card's coordinates.
/// iOS shows a static MapKit preview; no device location is requested or shown.
struct IMLocationCardMap: View {
    let title: String?
    let latitude: Double
    let longitude: Double
    var body: some View {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        VStack(alignment: .leading) {
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay {
                    Map(initialPosition: .region(CYMapRegion.region(center: coordinate, span: 0.01))) {
                        Marker(title ?? "", coordinate: coordinate)
                    }
                    .mapStyle(.standard)
                    .accessibilityHidden(true)
                }
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("im.card.locationMap"))
                .accessibilityIdentifier("im.card.locationMap")
            Text(verbatim: trimmed.isEmpty ? "—" : trimmed)
                .font(.headline)
                .foregroundStyle(.primary)
        }
    }
}
