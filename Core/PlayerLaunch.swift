import Foundation

/// Lane G player release gate. The first TestFlight is the player app: merchant center, merchant onboarding and
/// cooperation (coop) entries ship hidden. One flag decides it; every entry point reads `merchantCenterEnabled`
/// (UI rows, the merchant root mode, deep links, universal links, push taps, search and the page route table).
///
/// Player money flows (payment, refund, host-cancel refund, payout and withdrawal) are not affected by this flag.
public enum PlayerLaunch {
    /// False in Release. True under DEBUG or TEST so fixtures, UI tests and the merchant console keep working.
    #if DEBUG || TEST
    public static let merchantCenterEnabled = true
    #else
    public static let merchantCenterEnabled = false
    #endif

    /// The player home page. A hidden link lands here instead of failing.
    public static let playerHomePage = "pages/index/index"

    /// Mini-program path prefixes that belong to the merchant center or cooperation. `pages/merchant/profile/index`
    /// (商家公开主页) is the public, player-facing merchant home and stays open.
    public static let merchantCenterPagePrefixes: [String] = [
        "pages/merchant/",
        "pages/coop/",
        "pages/cooperation/",
    ]

    /// Single merchant-center pages outside those prefixes: merchant onboarding on a topic and the merchant's
    /// view of a topic.
    public static let merchantCenterPages: Set<String> = [
        "pages/topic/merchantapply/index",
        "pages/topic/merchantinfo/merchantinfo",
        // Page-map duplicate of the coop settlement detail. The merchant-center gate covers it.
        "pages/topic/settlement/index",
    ]

    /// Player-facing pages under a merchant prefix that stay visible.
    public static let playerVisibleMerchantPages: Set<String> = [
        "pages/merchant/profile/index",
    ]

    /// True when `path` (leading slash and query allowed) is a merchant-center, merchant-onboarding or coop page.
    public static func isMerchantCenterPage(_ path: String) -> Bool {
        let bare = path.split(separator: "?", maxSplits: 1, omittingEmptySubsequences: false).first.map(String.init) ?? path
        let page = bare.hasPrefix("/") ? String(bare.dropFirst()) : bare
        if playerVisibleMerchantPages.contains(page) { return false }
        if merchantCenterPages.contains(page) { return true }
        return merchantCenterPagePrefixes.contains { page.hasPrefix($0) || page + "/" == $0 }
    }

    /// True when `path` is hidden for the given flag value. Tests pass `enabled: false` to pin the Release set.
    public static func isHidden(page path: String, enabled: Bool = PlayerLaunch.merchantCenterEnabled) -> Bool {
        !enabled && isMerchantCenterPage(path)
    }

    /// True when the intent opens a merchant-center, merchant-onboarding or coop surface.
    public static func isMerchantCenterIntent(_ intent: NativeEntryIntent) -> Bool {
        if case .merchantInvitation = intent { return true }
        if case .miniProgramPage(let link) = intent { return isMerchantCenterPage(link.page) }
        return false
    }

    /// The intent to present. A hidden intent becomes the player home page, so a hidden link never crashes and
    /// never shows a merchant screen. Deep links, universal links, push taps and journey links all pass here.
    public static func gate(_ intent: NativeEntryIntent, enabled: Bool = PlayerLaunch.merchantCenterEnabled) -> NativeEntryIntent {
        guard !enabled, isMerchantCenterIntent(intent) else { return intent }
        return homeIntent
    }

    /// `.miniProgramPage(pages/index/index)`, or a route error only if the home link stopped parsing.
    public static var homeIntent: NativeEntryIntent {
        if let home = MiniProgramPageLink(path: playerHomePage, query: [:]) { return .miniProgramPage(home) }
        return .routeError(.unsupported)
    }
}
