import Foundation

/// MP `pages/club/topic-detail/index` (`CLB-G12`, `CLB-G13`):
/// Pure state & copy model for the embedded 导演台 (topic director) sections,
/// K8 unknown-write recovery banner, rejected re-edit action, and 更多 menu.
public struct ClubTopicDirectorSummary: Equatable, Sendable {
    public let readyStations: Int
    public let totalStations: Int
    public let activeTeams: Int
    public let caption: String?
    public let leaderboardHidden: Bool
    public let hasUnknownWrite: Bool
    public let unknownWriteLabel: String?

    public init(
        readyStations: Int,
        totalStations: Int,
        activeTeams: Int,
        caption: String? = nil,
        leaderboardHidden: Bool = false,
        hasUnknownWrite: Bool = false,
        unknownWriteLabel: String? = nil
    ) {
        self.readyStations = readyStations
        self.totalStations = totalStations
        self.activeTeams = activeTeams
        self.caption = caption
        self.leaderboardHidden = leaderboardHidden
        self.hasUnknownWrite = hasUnknownWrite
        self.unknownWriteLabel = unknownWriteLabel
    }
}

public enum ClubTopicDirectorToolKind: String, CaseIterable, Identifiable, Sendable {
    case chapterRelease
    case teamProgress
    case roleAssignment
    case liveEvents
    case targetedBroadcast

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .chapterRelease: return "章节放行"
        case .teamProgress: return "队伍进度"
        case .roleAssignment: return "角色分配"
        case .liveEvents: return "现场事件"
        case .targetedBroadcast: return "定向广播"
        }
    }

    public var systemImage: String {
        switch self {
        case .chapterRelease: return "lock.open"
        case .teamProgress: return "flag.2.crossed"
        case .roleAssignment: return "person.2.badge.gearshape"
        case .liveEvents: return "bolt.badge.clock"
        case .targetedBroadcast: return "megaphone"
        }
    }
}

public enum ClubTopicDirectorCopy {
    public static let prepOverviewTitle = "准备总览"
    public static let directorToolsTitle = "导演工具"
    public static let leaderboardTitle = "排行榜"
    public static let hideLeaderboard = "隐藏榜单"
    public static let showLeaderboard = "显示榜单"
    public static let unknownWriteTitle = "上一次操作结果未确认"
    public static let confirmResult = "确认结果"
    public static let retryOriginalAction = "重试原操作"
    public static let resubmitRejected = "修改并重新提交"
    public static let moreMenuTitle = "更多"
    public static let editTopicContent = "编辑主题内容"
    public static let confirmFinalPrice = "确认终价"
    public static let reviewUndertake = "承接审核"
    public static let selectSessionTitle = "选择导演场次"
}
