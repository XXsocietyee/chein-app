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
    let retry: () -> Void
    private var reason: DiscoveryTemplateUnavailable? { error as? DiscoveryTemplateUnavailable }
    private var isUnauthorized: Bool { (error as? APIError) == .unauthorized }
    private var title: LocalizedStringKey {
        if isUnauthorized { return "discovery.signInRequired" }
        switch reason {
        case .notFound, .deleted: return "discovery.templateMissing"
        case .underReview: return "discovery.templateReview"
        case .offline: return "discovery.templateOffline"
        default: return "discovery.loadFailed"
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
            else {
                ZStack {
                    Color.secondary.opacity(0.08)
                    Image(systemName: "sparkles.rectangle.stack").font(.largeTitle).foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: height).frame(maxWidth: .infinity)
        .clipped().clipShape(RoundedRectangle(cornerRadius: 14))
        .accessibilityHidden(true)
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

struct DiscoveryPlayRow: View {
    let item: DiscoveryPlayTemplate
    @Environment(\.cyPalette) private var palette
    var body: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                DiscoveryTitle(text: item.title, fallback: "discovery.untitledPlay").font(CYTypography.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                metaLine
                if let text = item.description, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(text).lineLimit(2).font(CYTypography.bodyCompact).foregroundStyle(palette.textSecondary)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textTertiary).accessibilityHidden(true)
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
                .font(CYTypography.meta).foregroundStyle(palette.textTertiary)
        }
    }
}

struct DiscoveryPlayMetadata: View {
    let item: DiscoveryPlayTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pack = item.pack { Text(pack.label).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary) }
            if let players = item.playersText {
                LabeledContent("discovery.players", value: players)
            }
            if let minutes = item.durationMinutes {
                LabeledContent("discovery.duration") { Text("discovery.minutes \(minutes)") }
            }
            if let difficulty = item.difficulty, !difficulty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LabeledContent("discovery.difficulty", value: difficulty)
            }
        }.font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
    }
}

struct DiscoveryTopicMetadata: View {
    let item: DiscoveryTopicTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if item.chapterCount > 0 { Text("discovery.chapters \(item.chapterCount)") }
            TopicTotalStops(count: item.locationCount, identifier: "discovery.totalStops.\(item.id)")
            if let seconds = item.totalTime { LabeledContent("discovery.publicSeconds", value: String(seconds)) }
            if item.previewOnly { Label("discovery.preview", systemImage: "flask") }
            else if !item.isVerified { Label("discovery.experimental", systemImage: "flask") }
        }.font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
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

/// Kit styling for system List sections on the detail pages: surface row background, hairline separators, kit header.
struct DiscoveryCardRow: ViewModifier {
    @Environment(\.cyPalette) private var palette
    func body(content: Content) -> some View {
        content.listRowBackground(palette.bgSurface).listRowSeparatorTint(palette.borderSubtle)
            .foregroundStyle(palette.textPrimary)
    }
}
extension View {
    func discoveryCardRow() -> some View { modifier(DiscoveryCardRow()) }
}
struct DiscoverySectionHeader: View {
    let title: LocalizedStringKey
    init(_ title: LocalizedStringKey) { self.title = title }
    var body: some View {
        CYSectionHeader(title).textCase(nil).padding(.top, CYSpacing.sm)
    }
}
