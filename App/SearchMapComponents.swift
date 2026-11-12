import SwiftUI
import Security

extension GlobalSearchKind {
    var titleKey: LocalizedStringKey { LocalizedStringKey("searchMap.kind." + rawValue) }
    var symbol: String {
        switch self { case .topic: return "point.topleft.down.to.point.bottomright.curvepath"
        case .activity: return "calendar"; case .club: return "person.3"; case .merchant: return "storefront" }
    }
}
struct SearchMapIssue: View {
    let key: String
    var retry: (() -> Void)? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(LocalizedStringKey(key), systemImage: key.contains("unauthorized") ? "lock" : "exclamationmark.circle")
                .font(.subheadline.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
            if let retry {
                Button(action: retry) { Text("searchMap.retry").frame(minHeight: 44) }
                    .buttonStyle(.bordered)
            }
        }.padding(16).frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))
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
    var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            if !typeSize.isAccessibilitySize {
                E1CoverArt(seed: row.title, symbol: row.kind.symbol, imageURL: offline ? nil : row.imageURL, debugLabel: false)
                    .frame(width: 84, height: 84)
                    .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs + 2) {
                Label(row.kind.titleKey, systemImage: row.kind.symbol)
                    .font(CYTypography.caption.weight(.semibold)).foregroundStyle(CYColor.textSecondary)
                    .padding(.horizontal, CYSpacing.sm + 2).padding(.vertical, 3)
                    .searchNightPill()
                Group {
                    if row.title.isEmpty { Text("searchMap.untitled") } else { Text(verbatim: row.title) }
                }
                .font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary).lineLimit(2)
                if let detail = row.detail, !detail.isEmpty {
                    Text(verbatim: detail).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).lineLimit(2)
                }
                if !row.tags.isEmpty {
                    Text(verbatim: row.tags.joined(separator: " · ")).font(CYTypography.caption).foregroundStyle(CYColor.textTertiary).lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Image(systemName: "chevron.forward").font(.footnote.weight(.semibold)).foregroundStyle(CYColor.textTertiary).accessibilityHidden(true)
        }
        .padding(CYSpacing.md)
        .background(CYNight.glassFill, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1).allowsHitTesting(false))
        .accessibilityElement(children: .combine)
    }
}

extension View {
    /// Night glass capsule. Selected pills use violet, which is reserved for selection.
    func searchNightPill(selected: Bool = false) -> some View {
        background(Capsule(style: .continuous).fill(selected ? CYNight.violet : CYNight.glassFill))
            .overlay(Capsule(style: .continuous).strokeBorder(selected ? Color.clear : CYNight.glassEdgeTop, lineWidth: 1))
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
