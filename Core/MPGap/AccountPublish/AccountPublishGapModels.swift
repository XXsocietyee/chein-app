import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/publish/fabu/index`, `pages/publish/temp/index`, `pages/square/detail/index`,
/// `pages/team/detail/index`, `pages/team/join/index` (`AP-G01`, `AP-G02`, `AP-G10`, `AP-G11`, `AP-G14`–`AP-G16`).
public enum ProjectEditExtraStoryBlockKind: String, CaseIterable, Identifiable, Sendable {
    case branch
    case gallery
    case line

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .branch: return "分支选择"
        case .gallery: return "多图画廊"
        case .line: return "角色对白"
        }
    }
}

public struct TopicCastMemberDraft: Identifiable, Equatable, Sendable {
    public let id: String
    public var name: String
    public var roleTitle: String
    public var voiceID: String?

    public init(id: String, name: String, roleTitle: String, voiceID: String? = nil) {
        self.id = id
        self.name = name
        self.roleTitle = roleTitle
        self.voiceID = voiceID
    }
}

public enum TopicLookStyleCopy {
    public static let sectionTitle = "画面风格"
    public static let paletteTitle = "主题配色"
    public static let presets: [(id: String, name: String)] = [
        ("warm", "暖纸书卷"),
        ("night", "夜游霓虹"),
        ("classic", "经典城瘾")
    ]
}

public enum TemplateAuthoringExtraCopy {
    public static let relaxOnLowHP = "状态不好时松一点"
    public static let triggerableOutcomes = "可触发的结果"
    public static let scanReply = "扫完回复"
    public static let saveAndBind = "保存并绑定"
    public static let loadFailedAdoptUnconfirmed = "采用尚未确认"
    public static let viewMyTemplates = "查看我的玩法"
    public static let loadFailedCannotRead = "当前请求无法读取玩法"
    public static let loadFailedGeneric = "玩法详情加载失败"
    public static let supportMatrixLoading = "正在读取玩法支持范围"
}

public struct TeamApplicantItem: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let userID: Int
    public let nickname: String
    public let avatarURL: String?
    public let message: String?

    public init(id: Int, userID: Int, nickname: String, avatarURL: String? = nil, message: String? = nil) {
        self.id = id
        self.userID = userID
        self.nickname = nickname
        self.avatarURL = avatarURL
        self.message = message
    }
}

public enum TeamGapCopy {
    public static let applicantsTitle = "入队申请"
    public static let applicantsLoadFailed = "入队申请没读到"
    public static let applicantsEmpty = "暂无申请"
    public static let reject = "拒绝"
    public static let approve = "同意"
    public static let joinCodeLabel = "加入码"
    public static let joinCodePlaceholder = "粘贴队长给的加入码"
    public static let nextStep = "下一步"
    public static let buyTicketCTA = "去买这一场的票"
    public static let maxJoinCodeLength = 40
}

public enum AccountPublishGapCopy {
    public static let ownComposerPlaceholder = "有什么新鲜好玩的分享吗？"
    public static let joinDatePrefix = "加入时间"
    public static let initiateCoop = "发起合作"
    public static let playableTemplateBadge = "可直接开局的模板"
    public static let viewTemplateRemix = "看看模板"
    public static let tryPlay = "试玩"
    public static let bookmarkAdd = "收藏帖文"
    public static let bookmarkRemove = "取消收藏"
}

public struct AccountPublishGapClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func previewCastVoice(topicID: Int?, preset: String, token: String) async throws -> String {
        guard !preset.isEmpty else { throw APIError.invalidRequest }
        struct VoicePreviewPayload: Decodable { let url: String }
        var query = [URLQueryItem(name: "preset", value: preset)]
        if let topicID, topicID > 0 {
            query.append(URLQueryItem(name: "topicId", value: String(topicID)))
        }
        let payload: VoicePreviewPayload = try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: "api/topic/cast/voice",
            queryItems: query,
            token: token
        )
        return payload.url
    }

    public func remixTemplate(templateID: Int, requestID: String, token: String) async throws -> Int {
        guard templateID > 0, !requestID.isEmpty else { throw APIError.invalidRequest }
        struct RemixPayload: Decodable { let topicId: Int }
        let payload: RemixPayload = try await MPGapHTTP.postForm(
            configuration: configuration,
            transport: transport,
            path: "api/template/topic-template/use",
            fields: ["id": String(templateID), "requestId": requestID],
            token: token
        )
        return payload.topicId
    }

    public func teamApplications(teamID: Int, token: String) async throws -> [TeamApplicantItem] {
        guard teamID > 0 else { throw APIError.invalidRequest }
        return try await MPGapHTTP.postJSON(
            configuration: configuration,
            transport: transport,
            path: "api/team/applications",
            body: ["teamId": teamID],
            token: token
        )
    }

    /// `POST /api/team/handle` JSON `{ teamId, memberId, approved }`, matching `NearbyTeamService.handle`.
    public func handleTeamApplication(teamID: Int, memberID: Int, approved: Bool, token: String) async throws {
        guard teamID > 0, memberID > 0 else { throw APIError.invalidRequest }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/team/handle",
            body: ["teamId": teamID, "memberId": memberID, "approved": approved],
            token: token
        )
    }
}
