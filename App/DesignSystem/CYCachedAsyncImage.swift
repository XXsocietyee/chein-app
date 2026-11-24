import SwiftUI
import UIKit

/// Memory cache for cover and shelf images.
///
/// Pages keep their own image gates. This store never opens a URL session:
/// a caller hands it bytes, and an unknown reference is not stored.
final class CYCachedAsyncImageStore: @unchecked Sendable {
    static let maximumByteCount = 8 * 1024 * 1024
    /// Resident bytes across every entry. One full-size image still fits; a shelf cannot keep 32 of them.
    static let maximumTotalBytes = 8 * 1024 * 1024
    /// Shared cache for cover and shelf tiles. Tests use a private store.
    static let coversAndShelves = CYCachedAsyncImageStore(capacity: 32)

    private let capacity: Int
    private let totalByteBudget: Int
    private let lock = NSLock()
    private let flights = InFlightReadCoalescer<Data>()
    private var entries: [String: Data] = [:]
    private var order: [String] = []
    private var totalBytes = 0

    init(capacity: Int = 32, totalByteBudget: Int = maximumTotalBytes) {
        self.capacity = max(1, capacity)
        self.totalByteBudget = max(1, totalByteBudget)
    }

    /// One load for this key while an earlier load of it is still running.
    func coalesce(_ key: String, _ body: @escaping () async throws -> Data) async throws -> Data {
        try await flights.join(key, body)
    }

    func isCoalescing(_ key: String) -> Bool { flights.isInFlight(key) }

    var count: Int {
        lock.lock()
        defer { lock.unlock() }
        return entries.count
    }

    func peek(_ key: String) -> Data? {
        lock.lock()
        defer { lock.unlock() }
        return entries[key]
    }

    /// Marks a cached image as recently used. Missing keys stay missing.
    func touch(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        guard entries[key] != nil, let index = order.firstIndex(of: key) else { return }
        order.remove(at: index)
        order.append(key)
    }

    /// Keeps one decoded image. Empty, oversized, and undecodable bytes are refused.
    @discardableResult
    func insert(_ data: Data, for key: String) -> Bool {
        guard !key.isEmpty, data.count > 0, data.count <= Self.maximumByteCount, data.count <= totalByteBudget,
              UIImage(data: data) != nil else { return false }
        lock.lock()
        defer { lock.unlock() }
        if let index = order.firstIndex(of: key) {
            order.remove(at: index)
            if let old = entries.removeValue(forKey: key) { totalBytes -= old.count }
        }
        entries[key] = data
        order.append(key)
        totalBytes += data.count
        while order.count > 1 && (order.count > capacity || totalBytes > totalByteBudget) {
            if let old = entries.removeValue(forKey: order.removeFirst()) { totalBytes -= old.count }
        }
        return true
    }
}

/// Where the image sits. Cover is the wide 16:10 tile; shelf is the 3:2 card used in horizontal shelves.
enum CYCachedAsyncImageRole: Equatable {
    case cover
    case shelf

    var aspectRatio: CGFloat {
        switch self {
        case .cover: return 16.0 / 10.0
        case .shelf: return 3.0 / 2.0
        }
    }

    /// Shelf cards match `CYImageCard`'s 280pt shelf. Covers take the width they are given.
    var fixedWidth: CGFloat? {
        switch self {
        case .cover: return nil
        case .shelf: return 280
        }
    }
}

/// Placeholder until an image is known, then the cached bytes, or a failure after a load was attempted.
enum CYCachedAsyncImagePhase: Equatable {
    case placeholder
    case ready(Data)
    case failed
}

enum CYCachedAsyncImageFailure: Error, Equatable {
    case unavailable
}

/// A credential-free absolute HTTPS reference, or nothing.
/// Anything else is unknown and stays on the placeholder.
enum CYCachedAsyncImageSource {
    static let maximumUTF8Bytes = 512

    static func key(from raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty,
              trimmed.utf8.count <= maximumUTF8Bytes,
              trimmed.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 0x7F }),
              !trimmed.contains("\\"),
              !trimmed.contains(where: \.isWhitespace),
              let url = URL(string: trimmed),
              url.scheme == "https",
              let host = url.host, !host.isEmpty,
              url.user == nil,
              url.password == nil,
              url.fragment == nil
        else { return nil }
        return trimmed
    }
}

/// Supplies image bytes for one canonical key. The design-system component does not fetch on its own.
protocol CYCachedAsyncImageLoading {
    func loadImage(for key: String) async throws -> Data
}

/// Resolves a cover or shelf image without a view.
/// Unknown references and cache misses with no loader stay on `.placeholder` and do not load.
enum CYCachedAsyncImageModel {
    static func resolve(
        source: String?,
        store: CYCachedAsyncImageStore,
        loader: (any CYCachedAsyncImageLoading)?
    ) async -> CYCachedAsyncImagePhase {
        guard let key = CYCachedAsyncImageSource.key(from: source) else { return .placeholder }
        if let cached = store.peek(key) {
            store.touch(key)
            return .ready(cached)
        }
        guard let loader else { return .placeholder }
        do {
            let bytes = try await store.coalesce(key) { try await loader.loadImage(for: key) }
            if Task.isCancelled {
                return store.peek(key).map(CYCachedAsyncImagePhase.ready) ?? .placeholder
            }
            guard store.insert(bytes, for: key) else { return .failed }
            return .ready(bytes)
        } catch is CancellationError {
            return store.peek(key).map(CYCachedAsyncImagePhase.ready) ?? .placeholder
        } catch {
            if Task.isCancelled {
                return store.peek(key).map(CYCachedAsyncImagePhase.ready) ?? .placeholder
            }
            return .failed
        }
    }
}

/// Cached asynchronous image for covers and shelves.
/// An unknown image stays on the placeholder. A load that was attempted and did not produce an image shows the failure state.
struct CYCachedAsyncImage: View {
    static let placeholderAccessibilityID = "cy.cachedImage.placeholder"
    static let failureAccessibilityID = "cy.cachedImage.failure"
    static let imageAccessibilityID = "cy.cachedImage.image"

    private let source: String?
    private let role: CYCachedAsyncImageRole
    private let store: CYCachedAsyncImageStore
    private let loader: (any CYCachedAsyncImageLoading)?

    @Environment(\.cyPalette) private var palette
    @State private var phase: CYCachedAsyncImagePhase = .placeholder
    @State private var phaseKey: String?
    @State private var attempt = 0

    init(
        _ source: String?,
        role: CYCachedAsyncImageRole = .cover,
        store: CYCachedAsyncImageStore = .coversAndShelves,
        loader: (any CYCachedAsyncImageLoading)? = nil
    ) {
        self.source = source
        self.role = role
        self.store = store
        self.loader = loader
    }

    var body: some View {
        Color.clear
            .aspectRatio(role.aspectRatio, contentMode: .fit)
            .frame(width: role.fixedWidth)
            .overlay { tile }
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .task(id: loadID) { await load() }
    }

    @ViewBuilder private var tile: some View {
        switch visiblePhase {
        case .placeholder:
            placeholder
        case .failed:
            failure
        case .ready(let data):
            if let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .accessibilityLabel(Text("cy.cachedImage.placeholder"))
                    .accessibilityIdentifier(Self.imageAccessibilityID)
            } else {
                failure
            }
        }
    }

    private var placeholder: some View {
        LinearGradient(colors: [palette.bgStrong, palette.bgRaised], startPoint: .topLeading, endPoint: .bottomTrailing)
            .overlay(
                Image(systemName: "photo")
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(palette.textPlaceholder)
                    .accessibilityHidden(true)
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("cy.cachedImage.placeholder"))
            .accessibilityIdentifier(Self.placeholderAccessibilityID)
    }

    private var failure: some View {
        Button(action: { attempt += 1 }) {
            VStack(spacing: CYSpacing.xs) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(palette.textTertiary)
                    .accessibilityHidden(true)
                Text("cy.cachedImage.failed")
                    .cyText(.caption)
                    .foregroundStyle(palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                Text("action.retry")
                    .cyText(.label)
                    .foregroundStyle(palette.textPrimary)
            }
            .padding(.horizontal, CYSpacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .background(palette.bgRaised)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(Self.failureAccessibilityID)
    }

    private var visiblePhase: CYCachedAsyncImagePhase {
        guard let key = CYCachedAsyncImageSource.key(from: source) else { return .placeholder }
        if let cached = store.peek(key) { return .ready(cached) }
        if phaseKey == key { return phase }
        return .placeholder
    }

    private var loadID: String {
        let key = CYCachedAsyncImageSource.key(from: source) ?? ""
        return "\(key)\n\(attempt)"
    }

    private func load() async {
        let key = CYCachedAsyncImageSource.key(from: source)
        if let key, store.peek(key) == nil {
            phaseKey = key
            phase = .placeholder
        }
        let resolved = await CYCachedAsyncImageModel.resolve(source: source, store: store, loader: loader)
        guard !Task.isCancelled else { return }
        phaseKey = key
        phase = resolved
    }
}

private struct CYCachedAsyncImagePreviewFailure: CYCachedAsyncImageLoading {
    func loadImage(for key: String) async throws -> Data {
        throw CYCachedAsyncImageFailure.unavailable
    }
}

#Preview("Cover placeholder · player") {
    CYCachedAsyncImage(nil, role: .cover)
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.player)
}

#Preview("Cover placeholder · merchant") {
    CYCachedAsyncImage(nil, role: .cover)
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
        .themeDomain(.merchant)
}

#Preview("Shelf failure") {
    CYCachedAsyncImage(
        "https://cdn.example.invalid/preview-shelf.jpg",
        role: .shelf,
        store: CYCachedAsyncImageStore(capacity: 2),
        loader: CYCachedAsyncImagePreviewFailure()
    )
    .padding(CYSpacing.pageHorizontal)
    .frame(maxHeight: .infinity, alignment: .top)
    .cyDomainPageBackground()
    .themeDomain(.player)
}
