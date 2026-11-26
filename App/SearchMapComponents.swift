import SwiftUI
import Security

extension GlobalSearchKind {
    var titleKey: LocalizedStringKey { LocalizedStringKey("searchMap.kind." + rawValue) }
    var symbol: String {
        switch self { case .topic: return "point.topleft.down.to.point.bottomright.curvepath"
        case .activity: return "calendar"; case .club: return "person.3"; case .merchant: return "storefront" }
    }
}
/// PC-A-4-1: one template result (MP discover-search.js `tplRow`): cover, title, 主题模板 / 玩法模板 label.
struct GlobalTemplateResultRow: View {
    let row: GlobalTemplateSearchRow
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        // R7-PC-A4-2 (r8): MP search2/result draws template results as cover cards too; accessibility sizes keep the row.
        if typeSize.isAccessibilitySize { rowLayout } else { coverLayout }
    }
    /// One plain header image above the row text (no card chrome).
    private var coverLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            coverArt
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
            textColumn
        }
        .accessibilityElement(children: .combine)
    }
    /// MP: pages/search2/result/index.wxml:55 — no cover → `.tpl-big__art` (200rpx, aspectFit, centred) from utils/template-art.js via utils/discover-search.js:117.
    @ViewBuilder private var coverArt: some View {
        if row.kind != .topicTemplate, (row.imageURL ?? "").isEmpty, let art = TemplateShelfArt.interactionIcon(row.title) {
            ZStack {
                Rectangle().fill(.quaternary)
                art.resizable().scaledToFit().frame(width: 100, height: 100).accessibilityHidden(true)
            }
        } else {
            DiscoveryArtwork(source: row.imageURL, height: 160)
        }
    }
    private var rowLayout: some View {
        HStack(alignment: .top, spacing: 12) {
            DiscoveryTopicCoverThumb(urlString: row.imageURL, seed: row.title)
            textColumn
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
    private var textColumn: some View {
            VStack(alignment: .leading, spacing: 2) {
                Text(row.kind == .topicTemplate ? "searchMap.kind.topicTemplate" : "searchMap.kind.playTemplate")
                    .font(.caption).foregroundStyle(.secondary)
                Text(verbatim: row.title).font(.body).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail, !detail.isEmpty {
                    Text(verbatim: detail).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                if row.previewOnly { Text("searchMap.template.previewOnly").font(.caption).foregroundStyle(.secondary) }
            }
    }
}
struct SearchMapIssue: View {
    let key: String
    var retry: (() -> Void)? = nil
    var body: some View {
        // Native r2: the system unavailable view (symbol, title, one bordered retry) instead of a drawn card.
        ContentUnavailableView {
            Label(LocalizedStringKey(key), systemImage: key.contains("unauthorized") ? "lock" : "exclamationmark.circle")
        } description: {
            EmptyView()
        } actions: {
            if let retry {
                Button(action: retry) { Text("searchMap.retry") }
                    .buttonStyle(.bordered)
            }
        }
            .accessibilityElement(children: .contain).accessibilityIdentifier("searchMap.issue")
    }
    static func key(_ error: Error) -> String {
        switch error as? APIError {
        case .unauthorized: return "searchMap.unauthorized"
        case .notConfigured, .invalidConfiguration: return "searchMap.notConfigured"
        case .invalidRequest: return "searchMap.invalidInput"
        default: return "searchMap.failed"
        }
    }
}
struct SearchMapCard: View {
    let row: GlobalSearchRow
    let offline: Bool
    @Environment(\.dynamicTypeSize) private var typeSize
    /// R7-PC-A4-2 (r1 PC-A-4-3): MP result page draws topics and activities as cover cards; clubs and merchants keep rows.
    private var usesCoverCard: Bool { (row.kind == .topic || row.kind == .activity) && !typeSize.isAccessibilitySize }
    var body: some View {
        if usesCoverCard { coverCard } else { rowCard }
    }
    /// One plain header image above the row text (no card chrome); the List row draws the chevron.
    private var coverCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            DiscoveryArtwork(source: offline ? nil : row.imageURL, height: 160)
            textColumn
        }
        .accessibilityElement(children: .combine)
    }
    private var rowCard: some View {
        HStack(alignment: .center, spacing: 12) {
            if !typeSize.isAccessibilitySize {
                DiscoveryTopicCoverThumb(urlString: offline ? nil : row.imageURL, seed: row.title)
            }
            textColumn
        }
        .accessibilityElement(children: .combine)
    }
    private var textColumn: some View {
        Group {
            VStack(alignment: .leading, spacing: 2) {
                Label(row.kind.titleKey, systemImage: row.kind.symbol)
                    .font(.caption).foregroundStyle(.secondary)
                Group {
                    if row.title.isEmpty { Text("searchMap.untitled") } else { Text(verbatim: row.title) }
                }
                .font(.body).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail, !detail.isEmpty {
                    Text(verbatim: detail).font(.subheadline).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !row.tags.isEmpty {
                    // Mini-program result tags (at most three), as one quiet secondary line.
                    Text(verbatim: row.tags.prefix(3).joined(separator: " · "))
                        .font(.caption).foregroundStyle(.secondary).cyWrapText()
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

extension View {
    /// Borderless capsule. Selected pills use the neutral primary fill.
    func searchNightPill(selected: Bool = false) -> some View {
        background(Capsule(style: .continuous).fill(selected ? CYColor.actionPrimaryBg : CYColor.bgElevated))
    }
}
/// Match the source's local secure-storage history rather than writing queries to ordinary defaults.
/// A nil namespace (fixtures/unconfigured) is memory-only and never touches Keychain.
/// Queries and inserts set `kSecAttrSynchronizable` to false. New items stay
/// `AfterFirstUnlockThisDeviceOnly`; this file does not migrate an existing row.
@MainActor final class SearchMapLocalHistory {
    private(set) var failed = false
    private func query(_ namespace: String) -> [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: namespace + ".search.history", kSecAttrAccount as String: "recent",
         kSecAttrSynchronizable as String: false]
    }
    func read(namespace: String?) -> [String] {
        failed = false
        guard let namespace else { return [] }
        var query = query(namespace); query[kSecReturnData as String] = true; query[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return [] }
        guard status == errSecSuccess, let data = result as? Data,
              let values = try? JSONDecoder().decode([String].self, from: data) else { failed = true; return [] }
        return Array(values.prefix(10))
    }
    func add(_ keyword: String, namespace: String?, current: [String]) -> [String] {
        failed = false
        let next = SearchHistoryPolicy.adding(keyword, to: current)
        guard let namespace else { return next }
        guard let data = try? JSONEncoder().encode(next) else { failed = true; return next }
        let base = query(namespace)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            failed = SecItemAdd(item as CFDictionary, nil) != errSecSuccess
        } else { failed = status != errSecSuccess }
        return next
    }
    func clear(namespace: String?) -> Bool {
        failed = false
        guard let namespace else { return true }
        let status = SecItemDelete(query(namespace) as CFDictionary)
        failed = status != errSecSuccess && status != errSecItemNotFound
        return !failed
    }
}
