import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/club/detail/index.js` (`CLB-G05`):
/// Maps `/api/registration/my-joined` items into `ClubPostRefOption` for attaching a play record to a club post.
/// `ownerType == 2` (活动) -> `refType = 1`; `ownerType == 1` (主题) -> `refType = 2`.
public struct ClubPostRefOption: Identifiable, Equatable, Sendable {
    public let refType: Int
    public let refID: Int
    public let title: String
    public let subtitle: String?

    public var id: String { "\(refType)-\(refID)" }

    public init(refType: Int, refID: Int, title: String, subtitle: String? = nil) {
        self.refType = refType
        self.refID = refID
        self.title = title
        self.subtitle = subtitle
    }

    public static func fromJoinedRecord(ownerType: Int, refID: Int, title: String, subtitle: String? = nil) -> ClubPostRefOption? {
        guard refID > 0 else { return nil }
        let refType = ownerType == 2 ? 1 : 2
        return ClubPostRefOption(refType: refType, refID: refID, title: title, subtitle: subtitle)
    }
}

public enum ClubPostRefCopy {
    public static let pickerTitle = "带上一次游玩记录"
    public static let clearSelection = "不附带记录"
    public static let loadFailed = "暂时读不到你的游玩记录"
    public static let emptyTitle = "还没有可附带的游玩记录"
}

/// MP `pages/club/detail/index.js` (`CLB-G07`, `CLB-G09`, `CLB-G10`, `CLB-G16`):
/// Deep-link `postId` scroll target, merchant viewer `.merchant` domain rule,
/// inline author follow (`POST /api/user/follow/action`), and `memberId` preselect.
public struct ClubDetailEntryContext: Equatable, Sendable {
    public let clubID: Int
    public let targetPostID: Int?
    public let openScanner: Bool
    public let isMerchantViewer: Bool
    public let preselectedMemberID: Int?

    public var usesMerchantLightDomain: Bool { isMerchantViewer }

    public init(
        clubID: Int,
        targetPostID: Int? = nil,
        openScanner: Bool = false,
        isMerchantViewer: Bool = false,
        preselectedMemberID: Int? = nil
    ) {
        self.clubID = clubID
        self.targetPostID = targetPostID
        self.openScanner = openScanner
        self.isMerchantViewer = isMerchantViewer
        self.preselectedMemberID = preselectedMemberID
    }
}

public enum ClubScanCopy {
    public static let wrongEntryTitle = "核销入口不对"
    public static let keepHere = "留在这里"
    public static let gotIt = "我知道了"
    public static let busyTitle = "核销处理中，请勿重复提交"
    public static let cameraPermission = "未能打开扫码，请检查相机权限"
    public static let scanActionTitle = "扫码核销"
    public static let undertakeTitle = "邀约承接"
}

/// MP `pages/club/topic-story/index.js` (`CLB-G14`):
/// Host node answer payload (`POST /api/topic/host-node-answer`) for merchant viewers.
public struct ClubHostNodeAnswer: Decodable, Equatable, Sendable {
    public let question: String?
    public let answerReveal: String?

    public init(question: String? = nil, answerReveal: String? = nil) {
        self.question = question
        self.answerReveal = answerReveal
    }
}

public enum ClubEventOpsGapCopy {
    public static let hostTipTitle = "主持小费"
    public static let hostTipUnavailable = "暂不可开通"
    public static let emptyTopicsTitle = "暂无可开场的主题"
    public static let publishTopicCTA = "发布主题"
    public static let callMember = "联系成员"
}

public struct ClubRemainingGapClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func toggleFollowAuthor(targetUserID: Int, follow: Bool, token: String) async throws {
        guard targetUserID > 0 else { throw APIError.invalidRequest }
        try await MPGapHTTP.postFormAction(
            configuration: configuration,
            transport: transport,
            path: "api/user/follow/action",
            fields: ["follow_member_id": String(targetUserID), "follow": follow ? "1" : "0"],
            token: token
        )
    }

    public func fetchHostNodeAnswer(topicID: Int, nodeID: Int, scope: String, token: String) async throws -> ClubHostNodeAnswer {
        guard topicID > 0, nodeID > 0 else { throw APIError.invalidRequest }
        return try await MPGapHTTP.postJSON(
            configuration: configuration,
            transport: transport,
            path: "api/topic/host-node-answer",
            body: ["topicId": topicID, "nodeId": nodeID, "scope": scope],
            token: token
        )
    }
}
