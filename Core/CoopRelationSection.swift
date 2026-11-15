import Foundation

/// Top-level segments of the merchant cooperation tab (mini-program `pages/merchant/relation`):
/// 合作商户 (merchants) is the default segment sourced from `api/merchant/relation-home`, followed by 俱乐部 and optional 帖子.
public enum CoopRelationSection: String, CaseIterable, Hashable {
    case merchants, clubs, posts

    /// Merchant relations are always the default segment so opening the page shows partner relations instead of the player feed.
    public static func effective(selected: CoopRelationSection?, feedAvailable: Bool) -> CoopRelationSection {
        if let selected {
            if selected == .posts && !feedAvailable { return .merchants }
            return selected
        }
        return .merchants
    }

    public static func available(feedAvailable: Bool) -> [CoopRelationSection] {
        feedAvailable ? [.merchants, .clubs, .posts] : [.merchants, .clubs]
    }

    /// Relation reads only apply to the two relation segments.
    public var relationKind: CoopRelationDiscoveryKind? {
        switch self {
        case .posts: return nil
        case .merchants: return .merchants
        case .clubs: return .clubs
        }
    }
}
