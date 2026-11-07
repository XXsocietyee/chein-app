import Foundation

/// Top-level segments of the merchant cooperation tab (mini-program `pages/merchant/relation`:
/// 帖子 is the default segment, 俱乐部 the second). Merchants stay a legacy segment of the native screen.
public enum CoopRelationSection: String, CaseIterable, Hashable {
    case posts, merchants, clubs

    /// The post feed is offered only when the host injected one; without it the screen keeps its previous default.
    public static func effective(selected: CoopRelationSection?, feedAvailable: Bool) -> CoopRelationSection {
        if let selected {
            if selected == .posts && !feedAvailable { return .merchants }
            return selected
        }
        return feedAvailable ? .posts : .merchants
    }

    public static func available(feedAvailable: Bool) -> [CoopRelationSection] {
        feedAvailable ? [.posts, .merchants, .clubs] : [.merchants, .clubs]
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
