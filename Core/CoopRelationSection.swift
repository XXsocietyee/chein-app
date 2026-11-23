import Foundation

/// Top-level segments of the merchant cooperation tab (mini-program `pages/merchant/relation`):
/// 合作商户 (merchants) is the default segment sourced from `api/merchant/relation-home`, followed by 俱乐部 and optional 帖子.
public enum CoopRelationSection: String, CaseIterable, Hashable {
    case merchants, clubs, posts

    /// Source pages/merchant/relation: tabs 帖子 (default) / 俱乐部. The 商家 tab was removed 2026-10-22
    /// (merchants no longer browse other merchants); without a feed only 俱乐部 remains.
    public static func effective(selected: CoopRelationSection?, feedAvailable: Bool) -> CoopRelationSection {
        let tabs = available(feedAvailable: feedAvailable)
        if let selected, tabs.contains(selected) { return selected }
        return tabs[0]
    }

    public static func available(feedAvailable: Bool) -> [CoopRelationSection] {
        feedAvailable ? [.posts, .clubs] : [.clubs]
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
