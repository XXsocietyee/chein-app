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
    private var coverLayout: some View {
        VStack(alignment: .leading, spacing: 0) {
            E1CoverArt(seed: row.title, symbol: row.kind == .topicTemplate ? "map" : "puzzlepiece.extension",
                       imageURL: row.imageURL, debugLabel: false)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
            textColumn.padding(CYSpacing.md)
        }
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    private var rowLayout: some View {
        HStack(alignment: .top, spacing: CYSpacing.md) {
            DiscoveryTopicCoverThumb(urlString: row.imageURL, seed: row.title)
            textColumn
            Spacer(minLength: 0)
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
    private var textColumn: some View {
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                Text(row.kind == .topicTemplate ? "searchMap.kind.topicTemplate" : "searchMap.kind.playTemplate")
                    .cyText(.caption).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: row.title).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail, !detail.isEmpty {
                    Text(verbatim: detail).cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary).lineLimit(2)
                }
                if row.previewOnly { Text("searchMap.template.previewOnly").cyText(.caption).foregroundStyle(CYColor.textSecondary) }
            }
    }
}
struct SearchMapIssue: View {
    let key: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey(key), systemImage: key.contains("unauthorized") ? "lock" : "exclamationmark.circle")
                .cyText(.bodyMedium)
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(action: retry) { Text("searchMap.retry").frame(minHeight: 44) }
                    .buttonStyle(.cySecondary(fullWidth: false))
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
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
    private var coverCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            E1CoverArt(seed: row.title, symbol: row.kind.symbol, imageURL: offline ? nil : row.imageURL, debugLabel: false)
                .frame(maxWidth: .infinity)
                .frame(height: 160)
                .clipped()
            textColumn.padding(CYSpacing.md)
        }
        .background(CYColor.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    private var rowCard: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            if !typeSize.isAccessibilitySize {
                E1CoverArt(seed: row.title, symbol: row.kind.symbol, imageURL: offline ? nil : row.imageURL, debugLabel: false)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            }
            textColumn
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textSecondary).accessibilityHidden(true)
        }
        .padding(CYSpacing.md)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
    private var textColumn: some View {
        Group {
            VStack(alignment: .leading, spacing: CYSpacing.xs + 2) {
                Label(row.kind.titleKey, systemImage: row.kind.symbol)
                    .cyText(.caption, weight: .semibold).foregroundStyle(CYColor.textSecondary)
                    .padding(.horizontal, CYSpacing.sm + 2).padding(.vertical, 3)
                    .searchNightPill()
                Group {
                    if row.title.isEmpty { Text("searchMap.untitled") } else { Text(verbatim: row.title) }
                }
                .cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail, !detail.isEmpty {
                    Text(verbatim: detail).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !row.tags.isEmpty {
                    // Mini-program result card: tags are small filled chips, at most three, and they wrap.
                    HStack(spacing: CYSpacing.xs) {
                        ForEach(Array(row.tags.prefix(3).enumerated()), id: \.offset) { _, tag in
                            Text(verbatim: tag).cyText(.caption).foregroundStyle(CYColor.textSecondary).cyWrapText()
                                .padding(.horizontal, CYSpacing.sm).padding(.vertical, 3)
                                .background(Capsule(style: .continuous).fill(CYColor.bgSurfaceSubtle))
                        }
                    }
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
