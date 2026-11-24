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
                E1CoverArt(seed: source ?? "discovery", symbol: "sparkles.rectangle.stack", debugLabel: false)
            }
        }
        .frame(height: height).frame(maxWidth: .infinity)
        .clipped().clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
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
                DiscoveryTitle(text: item.title, fallback: "discovery.untitledPlay").cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                metaLine
                if let text = item.description, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(text).lineLimit(2).cyText(.bodyCompact).foregroundStyle(palette.textSecondary)
                }
            }
            Spacer(minLength: CYSpacing.sm)
            Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).foregroundStyle(palette.textSecondary).accessibilityHidden(true)
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
                .cyText(.meta).foregroundStyle(palette.textSecondary)
        }
    }
}

struct DiscoveryPlayMetadata: View {
    let item: DiscoveryPlayTemplate
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let pack = item.pack { Text(pack.label).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            if let players = item.playersText {
                LabeledContent("discovery.players", value: players)
            }
            if let minutes = item.durationMinutes {
                LabeledContent("discovery.duration") { Text("discovery.minutes \(minutes)") }
            }
            if let difficulty = item.difficulty, !difficulty.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                LabeledContent("discovery.difficulty", value: difficulty)
            }
        }.cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
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
            if item.previewOnly { Text("discovery.preview").foregroundStyle(CYColor.textTertiary) }
            else if !item.isVerified { Text("discovery.experimental").foregroundStyle(CYColor.textTertiary) }
        }.cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
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
    /// MP `xb-section-ico` art (templatedetail.wxml), drawn before the title. Nil keeps the plain header.
    var art: Image? = nil
    init(_ title: LocalizedStringKey, art: Image? = nil) { self.title = title; self.art = art }
    var body: some View {
        if let art {
            HStack(alignment: .center, spacing: CYSpacing.sm) {
                art.resizable().scaledToFit().frame(width: 22, height: 22).accessibilityHidden(true)
                CYSectionHeader(title).textCase(nil)
            }
            .padding(.top, CYSpacing.sm)
        } else {
            CYSectionHeader(title).textCase(nil).padding(.top, CYSpacing.sm)
        }
    }
}
