import Foundation

/// Mini-program search2 "推荐搜索": a fixed, local keyword list (no API). The words are
/// China-market content terms, so other markets show no recommendations rather than translations.
public enum GlobalSearchRecommendedKeywords {
    public static let china = ["骑行", "城市", "外滩", "书店", "美术馆", "摄影", "苏州河", "菜场"]

    public static func keywords(for market: RegionalMarket?) -> [String] {
        market == .china ? china : []
    }
}

/// Player entry for global search. Reads an existing `GlobalSearchResults` value.
/// Does not open a session, register a route, or add merchant copy.
/// Player lanes are topic, activity, and club. A missing or denied count is an em dash.
/// A successful lane with no rows stays `"0"`.
public enum GlobalSearchEntryReadiness {
    public static let playerKinds: [GlobalSearchKind] = [.topic, .activity, .club]
    public static let unknownCount = "\u{2014}"

    public enum Phase: Equatable {
        case loading
        case empty
        case error(String)
        case unknown
        case ready
    }

    /// Nil means the kind is outside the player scope, not a measured zero.
    public static func countText(_ results: GlobalSearchResults, kind: GlobalSearchKind) -> String? {
        guard playerKinds.contains(kind) else { return nil }
        if laneUnresolved(results, kind: kind) { return unknownCount }
        return String(results.count(kind))
    }

    /// Sum of the three player lanes. Any unresolved lane makes the total unknown.
    public static func playerTotalText(_ results: GlobalSearchResults) -> String {
        var sum = 0
        for kind in playerKinds {
            if laneUnresolved(results, kind: kind) { return unknownCount }
            sum += results.count(kind)
        }
        return String(sum)
    }

    /// `loading` is only the first read. An accepted snapshot keeps its own phase while a refresh runs.
    /// `issueKey` is used only when no snapshot exists; the caller passes a key the page already has.
    public static func phase(configured: Bool, loading: Bool, issueKey: String?, results: GlobalSearchResults?) -> Phase {
        if !configured { return .error("searchMap.notConfigured") }
        guard let results else {
            if loading { return .loading }
            let issue = issueKey?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !issue.isEmpty { return .error(issue) }
            return .ready
        }
        if results.rows.contains(where: { playerKinds.contains($0.kind) }) { return .ready }
        if playerKinds.allSatisfy({ results.gatedKinds.contains($0) }) {
            return .error("searchMap.partialSignIn")
        }
        if playerKinds.allSatisfy({ results.failedKinds.contains($0) }) {
            return .error("searchMap.allFailed")
        }
        if playerKinds.contains(where: { laneUnresolved(results, kind: $0) }) { return .unknown }
        return .empty
    }

    /// Category directory. An unread directory is unknown, not zero categories.
    public static func categoryPhase(loading: Bool, failed: Bool, loaded: Bool, count: Int) -> Phase {
        if loading { return .loading }
        if failed { return .error("searchMap.categoryFailed") }
        if loaded, count == 0 { return .empty }
        if loaded, count > 0 { return .ready }
        return .unknown
    }

    public static func categoryCountText(loading: Bool, failed: Bool, loaded: Bool, count: Int) -> String {
        switch categoryPhase(loading: loading, failed: failed, loaded: loaded, count: count) {
        case .empty: return "0"
        case .ready: return String(count)
        case .loading, .error, .unknown: return unknownCount
        }
    }

    private static func laneUnresolved(_ results: GlobalSearchResults, kind: GlobalSearchKind) -> Bool {
        results.failedKinds.contains(kind) || results.gatedKinds.contains(kind)
    }
}
