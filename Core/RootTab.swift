import Foundation

/// Primary navigation, in the mini-program tab bar order (components/tabBar CONSUMER_LIST):
/// 首页 · 漫游 · 发布 · 俱乐部 · 我的. Activities are browsed inside Home (主题/活动), not as a tab.
///
/// The five cases and their `titleKey`/`systemImage` are the mini-program parity contract and the merchant bar's
/// slot map, so they stay. The player-facing four-tab bar (UX strategy W1-1) is `playerTabs` with the
/// `player*` presentation below: Explore · Roam · Clubs · Passport. Publish is not a player tab; it is an
/// Explore toolbar "+" entry (see `SessionHomeFeedView`).
public enum RootTab: Int, CaseIterable, Hashable, Sendable {
    case home, roam, publish, club, mine

    public var titleKey: String {
        switch self {
        case .home: return "tabBar.home"
        case .roam: return "tabBar.roam"
        case .publish: return "tabBar.publish"
        case .club: return "tabBar.club"
        case .mine: return "tabBar.mine"
        }
    }

    public var systemImage: String {
        switch self {
        case .home: return "house"
        case .roam: return "map"
        case .publish: return "plus.square"
        case .club: return "person.3"
        case .mine: return "person.crop.circle"
        }
    }

    /// Tabs on the player bar. `.publish` is intentionally absent.
    public static let playerTabs: [RootTab] = [.home, .roam, .club, .mine]

    public var isPlayerTab: Bool { Self.playerTabs.contains(self) }

    /// Title key on the player bar (Explore / Roam / Clubs / Passport).
    public var playerTitleKey: String {
        switch self {
        case .home: return "tabBar.explore"
        case .mine: return "tabBar.passport"
        case .roam, .publish, .club: return titleKey
        }
    }

    /// SF Symbol on the player bar (Passport is `book.closed`).
    public var playerSystemImage: String {
        switch self {
        case .home: return "sparkles"
        case .mine: return "book.closed"
        case .roam, .publish, .club: return systemImage
        }
    }
}
