import SwiftUI

@MainActor
final class DiscoveryLoader<Value>: ObservableObject {
    @Published private(set) var value: Value?
    @Published private(set) var isLoading = false
    @Published private(set) var error: Error?
    private var generation = 0

    func load(onUnauthorized: @MainActor () -> Void = {},
              _ operation: @MainActor () async throws -> Value) async {
        generation += 1
        let current = generation
        isLoading = true
        value = nil
        error = nil
        defer { if generation == current { isLoading = false } }
        do {
            let result = try await operation()
            guard current == generation, !Task.isCancelled else { return }
            value = result
        } catch is CancellationError { }
        catch {
            guard current == generation, !Task.isCancelled else { return }
            self.error = error
            // Visible result and session side effects share the same owner generation.
            if error as? APIError == .unauthorized { onUnauthorized() }
        }
    }
}

struct DiscoveryErrorView: View {
    let error: Error
    /// Round 4 copy: the page's own MP failure title (玩法没能打开 / 主题模板没能打开); nil keeps 加载失败.
    var failureTitle: LocalizedStringKey? = nil
    let retry: () -> Void
    private var reason: DiscoveryTemplateUnavailable? { error as? DiscoveryTemplateUnavailable }
    private var isUnauthorized: Bool { (error as? APIError) == .unauthorized }
    private var title: LocalizedStringKey {
        if isUnauthorized { return "discovery.signInRequired" }
        switch reason {
        case .notFound, .deleted: return "discovery.templateMissing"
        case .underReview: return "discovery.templateReview"
        case .offline: return "discovery.templateOffline"
        default: return failureTitle ?? "discovery.loadFailed"
        }
    }
    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: isUnauthorized ? "person.crop.circle.badge.exclamationmark" : "exclamationmark.circle")
        } description: {
            if isUnauthorized { Text("discovery.signInHint") }
            else if reason == .underReview { Text("discovery.templateReviewHint") }
            else if reason == .offline { Text("discovery.templateOfflineHint") }
            else if reason == .notFound || reason == .deleted { Text("discovery.templateMissingHint") }
        } actions: {
            if !isUnauthorized && (reason?.retryable ?? true) {
                Button("action.retry", action: retry).accessibilityIdentifier("discovery.retry")
            }
        }
    }
}

/// Artwork URLs are screened and never receive session credentials. Relative/HTTP URLs remain placeholders.
struct DiscoveryArtwork: View {
    let source: String?
    var height: CGFloat = 160
    private var url: URL? {
        guard let source, let parts = URLComponents(string: source), parts.scheme == "https",
              parts.host != nil, parts.user == nil, parts.password == nil else { return nil }
        return parts.url
    }
    var body: some View {
        AsyncImage(url: url) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else { DiscoveryArtPlaceholder(systemImage: "sparkles.rectangle.stack") }
        }
        .frame(height: height).frame(maxWidth: .infinity)
        .clipped()
        .accessibilityHidden(true)
    }
}

/// Native r2: the system artwork placeholder (fill + secondary SF Symbol), replacing generated gradient cover art.
struct DiscoveryArtPlaceholder: View {
    var systemImage = "photo"
    var body: some View {
        Rectangle().fill(.quaternary)
            .overlay {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
    }
}

/// Server-authored titles stay verbatim; only the empty-title fallback is a catalog key.
struct DiscoveryTitle: View {
    let text: String
    let fallback: LocalizedStringKey
    var body: some View {
        if text.isEmpty { Text(fallback) }
        else { Text(text) }
    }
}

/// Native list row text: title, one secondary meta line, two-line description. The List/NavigationLink draws the chevron.
struct DiscoveryPlayRow: View {
    let item: DiscoveryPlayTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            DiscoveryTitle(text: item.title, fallback: "discovery.untitledPlay").font(.body)
                .foregroundStyle(.primary)
            metaLine
            if let text = item.description, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(text).lineLimit(2).font(.subheadline).foregroundStyle(.secondary)
            }
        }
    }
}

extension DiscoveryPlayRow {
    /// One quiet line: pack · players · minutes. Unknown parts are skipped, never shown as 0.
    @ViewBuilder fileprivate var metaLine: some View {
        let parts: [Text] = [
            item.pack.map { Text($0.label) },
            item.playersText.map { Text(verbatim: $0) },
            item.durationMinutes.map { Text("discovery.minutes \($0)") }
        ].compactMap { $0 }
        if let first = parts.first {
            parts.dropFirst().reduce(first) { $0 + Text(verbatim: " · ") + $1 }
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct DiscoveryPlayMetadata: View {
    let item: DiscoveryPlayTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pack = item.pack { Text(pack.label).font(.subheadline).foregroundStyle(.secondary) }
            if let players = item.playersText {
                LabeledContent("discovery.players", value: players)
            }
            if let minutes = item.durationMinutes {
                LabeledContent("discovery.duration") { Text("discovery.minutes \(minutes)") }
            }
            if let difficulty = item.difficulty, !difficulty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LabeledContent("discovery.difficulty", value: difficulty)
            }
        }
    }
}

struct DiscoveryTopicMetadata: View {
    let item: DiscoveryTopicTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if item.chapterCount > 0 { Text("discovery.chapters \(item.chapterCount)") }
            TopicTotalStops(count: item.locationCount, identifier: "discovery.totalStops.\(item.id)")
            if let seconds = item.totalTime { LabeledContent("discovery.publicSeconds", value: String(seconds)) }
            // Screens r4 · Figma 243:1964 (SR2-20): monochrome, text-only status in the meta line (no flask glyph).
            if item.previewOnly { Text("discovery.preview").foregroundStyle(.tertiary) }
            else if !item.isVerified { Text("discovery.experimental").foregroundStyle(.tertiary) }
        }.font(.subheadline).foregroundStyle(.secondary)
    }
}

extension DiscoveryPackType {
    var label: LocalizedStringKey {
        switch self {
        case .single: return "discovery.pack.single"
        case .story: return "discovery.pack.story"
        case .shop: return "discovery.pack.shop"
        }
    }
}

extension DiscoveryVerification {
    var label: LocalizedStringKey {
        switch self {
        case .none: return "discovery.verification.none"
        case .text: return "discovery.verification.text"
        case .photo: return "discovery.verification.photo"
        case .choice: return "discovery.verification.choice"
        case .shopQR: return "discovery.verification.shopQR"
        case .gps: return "discovery.verification.gps"
        case .preferences: return "discovery.verification.preferences"
        case .sensor: return "discovery.verification.sensor"
        case .other: return "discovery.verification.other"
        }
    }
}

/// Native r2: detail-page List rows keep the system inset-grouped row background, separators and label colour.
/// Kept as a pass-through so existing call sites stay unchanged.
struct DiscoveryCardRow: ViewModifier {
    func body(content: Content) -> some View { content }
}
extension View {
    func discoveryCardRow() -> some View { modifier(DiscoveryCardRow()) }
}
struct DiscoverySectionHeader: View {
    let title: LocalizedStringKey
    /// MP `xb-section-ico` art (templatedetail.wxml), drawn before the title. Nil keeps the plain header.
    var art: Image? = nil
    init(_ title: LocalizedStringKey, art: Image? = nil) { self.title = title; self.art = art }
    var body: some View {
        if let art {
            Label {
                Text(title)
            } icon: {
                art.resizable().scaledToFit().frame(width: 20, height: 20).accessibilityHidden(true)
            }
        } else {
            Text(title)
        }
    }
}
