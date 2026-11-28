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
        if typeSize.isAccessibilitySize || !hasArt { rowLayout } else { coverLayout }
    }
    /// mp-home r3 (21:20 sweep, P18): no cover and no MP template art → a text row, never an empty image frame.
    private var hasCoverURL: Bool { QuestifyCardArtwork.safeURL(row.imageURL) != nil }
    private var hasArt: Bool {
        hasCoverURL || (row.kind != .topicTemplate && TemplateShelfArt.interactionIcon(row.title) != nil)
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
            if hasCoverURL {
                DiscoveryTopicCoverThumb(urlString: row.imageURL, seed: row.title)
            }
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
    @Environment(\.cyPalette) private var palette
    /// R7-PC-A4-2 (r1 PC-A-4-3): MP result page draws topics and activities as cover cards; clubs and merchants keep rows.
    /// mp-home r3 (21:20 sweep, P18): a result with no loadable cover is a text row — no empty image frame.
    private var coverURL: URL? { offline ? nil : QuestifyCardArtwork.safeURL(row.imageURL) }
    private var usesCoverCard: Bool { (row.kind == .topic || row.kind == .activity) && !typeSize.isAccessibilitySize && coverURL != nil }
    var body: some View {
        if usesCoverCard { coverCard } else { rowCard }
    }
    /// One plain header image above the row text (no card chrome); the List row draws the chevron.
    private var coverCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            coverImage
            textColumn
        }
        .accessibilityElement(children: .combine)
    }
    /// mp-home r3 (19:50 sweep; MP search2/result wxml:31-32, 67-69): no cover = the kind icon on the subtle surface,
    /// never a grey block with a generic glyph.
    private var coverImage: some View {
        AsyncImage(url: coverURL) { phase in
            if let image = phase.image { image.resizable().scaledToFill() }
            else {
                palette.bgSurfaceSubtle
                    .overlay { Image(systemName: row.kind.symbol).font(.title2).foregroundStyle(.secondary).accessibilityHidden(true) }
            }
        }
        .frame(height: 160).frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .accessibilityHidden(true)
    }
    private var rowCard: some View {
        HStack(alignment: .center, spacing: 12) {
            if !typeSize.isAccessibilitySize, coverURL != nil {
                DiscoveryTopicCoverThumb(urlString: row.imageURL, seed: row.title)
            }
            textColumn
        }
        .accessibilityElement(children: .combine)
    }
    private var textColumn: some View {
        Group {
            VStack(alignment: .leading, spacing: 2) {
                // mp-home r3 (02:10 sweep d2-search-results; MP result wxml `result-card__type` / `__detail`): kind and
                // detail are plain text lines, so every row's title, kind and area start on one leading edge.
                Text(row.kind.titleKey)
                    .font(.caption).foregroundStyle(.secondary)
                Group {
                    if row.title.isEmpty { Text("searchMap.untitled") } else { Text(verbatim: row.title) }
                }
                .font(.body).foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
                if let detail = row.detail, !detail.isEmpty {
                    // P18: an activity's second line is its area (native detail = addressName ?? address).
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
        write(next, namespace: namespace)
        return next
    }
    /// P18: one recent search removed by swipe or its trailing delete button; an emptied list deletes the item.
    func remove(_ keyword: String, namespace: String?, current: [String]) -> [String] {
        failed = false
        let next = current.filter { !$0.utf8.elementsEqual(keyword.utf8) }
        guard let namespace else { return next }
        if next.isEmpty { return clear(namespace: namespace) ? next : current }
        write(next, namespace: namespace)
        return next
    }
    private func write(_ next: [String], namespace: String) {
        guard let data = try? JSONEncoder().encode(next) else { failed = true; return }
        let base = query(namespace)
        let status = SecItemUpdate(base as CFDictionary, [kSecValueData as String: data] as CFDictionary)
        if status == errSecItemNotFound {
            var item = base; item[kSecValueData as String] = data
            item[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            failed = SecItemAdd(item as CFDictionary, nil) != errSecSuccess
        } else { failed = status != errSecSuccess }
    }
    func clear(namespace: String?) -> Bool {
        failed = false
        guard let namespace else { return true }
        let status = SecItemDelete(query(namespace) as CFDictionary)
        failed = status != errSecSuccess && status != errSecItemNotFound
        return !failed
    }
}

/// MP `utils/category-icon.js` (UI-13): the backend icon column is one shared placeholder, so the glyph comes from
/// the category name. Same keyword rules in the same order; unknown names fall back to the neutral shop glyph.
enum SearchCategorySymbol {
    /// MP `utils/category-icon.js` rules (Chinese, same order). mp-home r3 (continue 32): the US market and the en
    /// fixture send English category names, which all fell back to `storefront`; each rule also matches the English
    /// word starts (case-insensitive, `\b` so "Party" is not "art" and "Brunch" is not "run").
    private static let rules: [(String, String)] = [
        ("运动|健身|体育|\\b(sport|fitness|gym)", "figure.run"),
        ("徒步|骑行|跑步|户外|\\b(hik|cycl|bik|running|outdoor)", "point.topleft.down.to.point.bottomright.curvepath"),
        ("摄影|相机|\\b(photo|camera)", "camera"),
        ("科技|数码|电子|设备|\\b(tech|digital|electronic|device)", "desktopcomputer"),
        ("美食|餐饮|烹饪|餐厅|食堂|\\b(food|dining|cook|restaurant)", "fork.knife"),
        ("咖啡|烘焙|甜品|\\b(coffee|caf|bak|dessert)", "cup.and.saucer"),
        ("娱乐|演艺|演出|电影|音乐|游戏|达人|竞猜|\\b(entertain|perform|show|movie|film|music|game|quiz)", "play.circle"),
        ("衣物|洗护|服装|服饰|鞋包|穿搭|\\b(cloth|laundry|apparel|outfit)", "tshirt"),
        ("家政|维修|家居|清洁|整理|搬家|\\b(housekeep|repair|home|clean|moving)", "wrench.and.screwdriver"),
        ("出行|交通|\\b(transport|commut)", "car"),
        ("旅行|旅游|路线|漫游|\\b(travel|tour|route|roam)", "point.topleft.down.to.point.bottomright.curvepath"),
        ("生活|美学|美妆|时尚|艺术|\\b(lifestyle|aesthetic|beauty|fashion|art)", "paintpalette"),
        ("探索|城市|地图|街区|\\b(explor|city|map|street|neighbo)", "map"),
        ("文化|叙事|故事|历史|读书|\\b(cultur|story|histor|read|book)", "book"),
        ("亲子|协作|团队|组队|社交|交友|俱乐部|\\b(family|kid|team|social|friend|club)", "person.2"),
        ("解谜|谜题|推理|机关|\\b(puzzle|mystery|riddle|escape)", "lock"),
        ("夜游|夜生活|夜|\\b(night)", "star"),
    ]
    static func name(for categoryName: String) -> String {
        let text = categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "storefront" }
        for (pattern, symbol) in rules where text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
            return symbol
        }
        return "storefront"
    }
}
