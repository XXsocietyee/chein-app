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
                VStack(alignment: .leading, spacing: CYSpacing.sm) {
                    if isSignup {
                        CYStatusChip("im.card.signupFlag", tone: .success, systemImage: "checkmark.seal")
                    }
                    CYImageCard(
                        title: Text(verbatim: displayName(detail.name)),
                        meta: summary(detail),
                        imageURL: coverURL(detail),
                        style: .hero
                    )
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("im.card.route.loaded")
            } else if failed {
                CYEmptyState(
                    systemImage: "exclamationmark.triangle",
                    "im.card.routeUnavailable",
                    messageIdentifier: "im.card.route.unavailable",
                    actionTitle: "messaging.retry",
                    actionIdentifier: "im.card.route.retry",
                    kind: .failure
                ) { Task { await load() } }
                .disabled(loading)
            } else {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    Text("im.card.routeLoading")
                        .cyText(.body)
                        .foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                    CYSkeleton().accessibilityHidden(true)
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
    /// HTTPS cover only. Anything else falls through to generated art inside `CYImageCard`.
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
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Color.clear
                .aspectRatio(16.0 / 10.0, contentMode: .fit)
                .overlay {
                    Map(initialPosition: .region(CYMapRegion.region(center: coordinate, span: 0.01))) {
                        Marker(title ?? "", coordinate: coordinate)
                    }
                    .mapStyle(.standard(elevation: .flat, emphasis: .muted))
                    .environment(\.colorScheme, .light)
                    .background { CYMapPlaceholder(fog: false) }
                    .accessibilityHidden(true)
                }
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("im.card.locationMap"))
                .accessibilityIdentifier("im.card.locationMap")
            Text(verbatim: trimmed.isEmpty ? "—" : trimmed)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
