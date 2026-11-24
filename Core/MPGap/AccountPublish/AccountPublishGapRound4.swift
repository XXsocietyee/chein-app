import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round 4 additions for `account-publish` (`C-F1`, `C-F5`, `C-F7`, `C-T3`, `C-D2`, `C-D11-r7`, `A4-01`, `A2-10-r7`).

/// `C-F1`: Story block drafts for `branch`, `gallery` (1-4 grid), `line` divider, and dialogue `speaker`.
public struct ProjectEditBranchOptionDraft: Identifiable, Equatable, Sendable {
    public let id: String
    public var label: String
    public var targetChapterTitle: String

    public init(id: String = UUID().uuidString, label: String = "", targetChapterTitle: String = "") {
        self.id = id
        self.label = label
        self.targetChapterTitle = targetChapterTitle
    }
}

public struct ProjectEditBranchBlockDraft: Equatable, Sendable {
    public var question: String
    public var options: [ProjectEditBranchOptionDraft]

    public init(question: String = "", options: [ProjectEditBranchOptionDraft] = [
        ProjectEditBranchOptionDraft(),
        ProjectEditBranchOptionDraft()
    ]) {
        self.question = question
        self.options = Array(options.prefix(3))
    }
}

public struct ProjectEditGalleryBlockDraft: Equatable, Sendable {
    public var imageURLs: [String]
    public var columns: Int

    public init(imageURLs: [String] = [], columns: Int = 2) {
        self.imageURLs = Array(imageURLs.prefix(4))
        self.columns = min(max(columns, 1), 4)
    }
}

/// `C-F7`: Chapter settings (`结局章`, `由工作人员开幕`, atmosphere, and `添加序章`).
public struct ProjectEditChapterSettingsDraft: Equatable, Sendable {
    public var isEndingChapter: Bool
    public var staffOpening: Bool
    public var atmosphereID: String

    public init(isEndingChapter: Bool = false, staffOpening: Bool = false, atmosphereID: String = "default") {
        self.isEndingChapter = isEndingChapter
        self.staffOpening = staffOpening
        self.atmosphereID = atmosphereID
    }
}

/// `C-T3`: Template authoring advanced completion fields (`状态不好时松一点`, `可触发的结果`, `扫完回复`, `from=citynode`).
public struct TemplateAuthoringRound4Draft: Equatable, Sendable {
    public var relaxOnLowHP: Bool
    public var relaxLevel: String
    public var triggerableOutcomes: [String]
    public var scanReplyEnabled: Bool
    public var scanReplyText: String
    public var isCityNodeMode: Bool
    public var cityNodeModeLabel: String

    public init(
        relaxOnLowHP: Bool = false,
        relaxLevel: String = "轻微放宽",
        triggerableOutcomes: [String] = [],
        scanReplyEnabled: Bool = false,
        scanReplyText: String = "",
        isCityNodeMode: Bool = false,
        cityNodeModeLabel: String = "城市节点玩法"
    ) {
        self.relaxOnLowHP = relaxOnLowHP
        self.relaxLevel = relaxLevel
        self.triggerableOutcomes = triggerableOutcomes
        self.scanReplyEnabled = scanReplyEnabled
        self.scanReplyText = scanReplyText
        self.isCityNodeMode = isCityNodeMode
        self.cityNodeModeLabel = cityNodeModeLabel
    }
}

/// `A2-10-r7`: Public profile deep-link query params (`topicId`, `chapterId`, `scope`, `preview`).
public struct UserinfoCoopEntryParams: Equatable, Sendable {
    public let userID: Int
    public let topicID: Int?
    public let chapterID: Int?
    public let scope: String?
    public let isPreview: Bool

    public init(
        userID: Int,
        topicID: Int? = nil,
        chapterID: Int? = nil,
        scope: String? = nil,
        isPreview: Bool = false
    ) {
        self.userID = userID
        self.topicID = topicID
        self.chapterID = chapterID
        self.scope = scope
        self.isPreview = isPreview
    }
}

public enum AccountPublishRound4Copy {
    public static let addPrologue = "添加序章"
    public static let endingChapterToggle = "结局章"
    public static let staffOpeningToggle = "由工作人员开幕"
    public static let branchQuestionPlaceholder = "分支提问"
    public static let addBranchOption = "添加选项"
    public static let lineDividerLabel = "分割线"
    public static let speakerPlaceholder = "说话角色名"
    public static let saveInviteImage = "保存图片"
    public static let saveInvitePrivacyNote = "保存邀请图需要访问你的相册"
    public static let relaxLevels = ["轻微放宽", "明显放宽", "直接通过"]
}

public struct AccountPublishRound4Client {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// `C-D2`: Handle applicant via `{teamId, memberId, approved}` matching `NearbyTeamHTTPWriteAdapter`.
    public func handleApplicant(teamID: Int, memberID: Int, approved: Bool, token: String) async throws {
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
