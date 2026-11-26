import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/club/detail/index.js` (`loadCoopPool` / `applyCoopPool`, `CLB-G04`):
/// Pure presentation state for the club manage tab's 可对接的活动 (coop pool) section.
public enum ClubCoopPoolLoadState: Equatable, Sendable {
    case idle
    case loading
    case permission(String)
    case error(String)
    case ready([ClubCoopPoolCardItem])
}

public struct ClubCoopPoolCardItem: Identifiable, Equatable, Sendable {
    public let topicID: Int
    public let name: String
    public let stateText: String
    public let isTaken: Bool
    public let merchantNick: String?
    public let subtitle: String?
    public let deadlineText: String?
    public let canApply: Bool
    public let applyID: Int?

    public var id: Int { topicID }

    public init(
        topicID: Int,
        name: String,
        stateText: String,
        isTaken: Bool,
        merchantNick: String?,
        subtitle: String?,
        deadlineText: String?,
        canApply: Bool,
        applyID: Int?
    ) {
        self.topicID = topicID
        self.name = name
        self.stateText = stateText
        self.isTaken = isTaken
        self.merchantNick = merchantNick
        self.subtitle = subtitle
        self.deadlineText = deadlineText
        self.canApply = canApply
        self.applyID = applyID
    }
}

public enum ClubCoopPoolCopy {
    public static let sectionTitle = "可对接的活动"
    public static let myCoopTitle = "我的合作"
    public static let ownerOnlyPermission = "只有主理人能看可对接的活动"
    public static let becomeOwnerPermission = "成为俱乐部主理人后才能申请承接"
    public static let loadFailed = "合作池加载失败"
    public static let networkError = "网络异常，请检查连接后重试"
    public static let emptyTitle = "暂无开放承接的主题"
    public static let applyButton = "申请带队"
    public static let submittingButton = "提交中…"
    public static let viewApplicationButton = "查看申请"
    public static let applyPlaceholder = "给商家带句话(可选)：带队经验、可带人数…"
    public static let submitApply = "提交申请"

    public static func applyModalTitle(topicName: String) -> String {
        let resolved = topicName.trimmingCharacters(in: .whitespacesAndNewlines)
        return "申请带队「\(resolved.isEmpty ? "该主题" : resolved)」"
    }
}

/// MP `CLB-G11` (`/api/club-compensation/editions/empty-reason`):
/// Fetches the server-provided explanation when a club has no ticketed editions.
public struct ClubEditionsEmptyReason: Decodable, Equatable, Sendable {
    public let reason: String?
    public let title: String?

    public init(reason: String? = nil, title: String? = nil) {
        self.reason = reason
        self.title = title
    }
}

public struct ClubEditionsEmptyReasonClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func fetchEmptyReason(clubID: Int, token: String) async throws -> ClubEditionsEmptyReason {
        guard clubID > 0 else { throw APIError.invalidRequest }
        return try await MPGapHTTP.postJSON(
            configuration: configuration,
            transport: transport,
            path: "api/club-compensation/editions/empty-reason",
            body: ["clubId": clubID],
            token: token
        )
    }
}

/// CLB-G04 (MP `pages/club/detail/index.js` applyCoopPool): 申请带队 posts
/// `{ topicId, clubId, message }` to `/api/coop/pool/apply`. The merchant answers with a formal invite,
/// so this states intent and is not a payment, refund, payout, or settlement.
public struct ClubCoopPoolApplyClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func apply(topicID: Int, clubID: Int, message: String, token: String) async throws {
        let note = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard topicID > 0, clubID > 0, note.count <= 500 else { throw APIError.invalidRequest }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/coop/pool/apply",
            body: ["topicId": topicID, "clubId": clubID, "message": note],
            token: token
        )
    }

    /// MP `decoratePool`: open, declined, and withdrawn rows can apply again. Other states stay hidden.
    public static func canApply(state: String?) -> Bool {
        ["open", "declined", "withdrawn"].contains(state ?? "")
    }
}
