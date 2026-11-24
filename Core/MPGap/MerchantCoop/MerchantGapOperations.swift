import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/merchant/customer/index`, `aftercare/detail/index`, `decor/ai-npc/index`,
/// `coop/list/index`, `coop/invite/index`, `coop/nearby/index` (`MC-G08`, `MC-G09`, `MC-G12`, `MC-G16`–`MC-G18`).
public enum MerchantCustomerExportBannerState: Equatable, Sendable {
    case idle
    case generating
    case ready(rows: Int)
    case downloadFailed
    case expired
    case failed(String)

    public var title: String {
        switch self {
        case .idle: return ""
        case .generating: return "生成中"
        case .ready(let rows): return "已就绪 \(rows) 行"
        case .downloadFailed: return "下载失败"
        case .expired: return "已过期"
        case .failed(let msg): return msg.isEmpty ? "导出失败" : msg
        }
    }
}

public struct MerchantManualAftercareCase: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let caseNo: String
    public let statusText: String
    public let reason: String?
    public let amountText: String?

    public init(id: Int, caseNo: String, statusText: String, reason: String? = nil, amountText: String? = nil) {
        self.id = id
        self.caseNo = caseNo
        self.statusText = statusText
        self.reason = reason
        self.amountText = amountText
    }
}

public enum MerchantAftercareManualCopy {
    public static let caseNoPrefix = "工单编号"
    public static let platformHandled = "由平台处理"
    public static let contactSupport = "联系平台客服"
}

public struct CoopSupplyStation: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let address: String?

    public init(id: Int, name: String, address: String? = nil) {
        self.id = id
        self.name = name
        self.address = address
    }
}

public struct CoopInvitableMerchant: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let address: String?
    public let chapterName: String?

    public init(id: Int, name: String, address: String? = nil, chapterName: String? = nil) {
        self.id = id
        self.name = name
        self.address = address
        self.chapterName = chapterName
    }
}

public enum MerchantAINPCIntroCopy {
    public static let steps: [(title: String, detail: String)] = [
        ("创建你的店铺角色", "上传店长或门店形象照片，玩家在城市探索中会遇到他"),
        ("录制 3 句欢迎语音", "按住说话录制 3 句话，系统将生成专属店铺语音"),
        ("设置漫游落点", "选择门店在探索地图上的准确位置"),
        ("开启店铺互动", "审核通过后，玩家到店即可与你的 AI 角色对话")
    ]
    public static let prevStep = "上一步"
    public static let nextStep = "下一步"
    public static let skip = "跳过"
    public static let gotIt = "知道了"
    public static let voiceEnrollGated = "声音生成功能需等待审核开关开启"
}

public enum CoopListGapCopy {
    public static let declinePool = "拒绝"
    public static let replyInvite = "回邀约"
    public static let confirmSlot = "确认占槽"
    public static let inviteOthers = "再邀别人"
    public static let withdrawApply = "撤回申请"
    public static let goReceivedConfirm = "去收到的确认"
    public static let payDeposit = "缴纳保证金"
    public static let retryDepositRefund = "重试保证金退款"
    public static let depositTestOnlyNote = "保证金支付与退款仅在 TEST 环境开放"
    public static let supplyStationHeader = "核销据点"
    public static let noTopicsPublishCTA = "先发布主题"
    public static let fixTermsCTA = "主题条款没配好？"
    public static let nearbyReplacementTitle = "选择补位操作"
}

public struct MerchantGapOperationsClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func manualAftercareCase(id: Int, token: String) async throws -> MerchantManualAftercareCase {
        guard id > 0 else { throw APIError.invalidRequest }
        return try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/aftercare/manual-case-detail",
            queryItems: [URLQueryItem(name: "manualCaseId", value: String(id))],
            token: token
        )
    }

    public func supplyStations(topicID: Int, merchantMemberID: Int, token: String) async throws -> [CoopSupplyStation] {
        guard topicID > 0, merchantMemberID > 0 else { throw APIError.invalidRequest }
        return try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: "api/coop/supply-stations",
            queryItems: [
                URLQueryItem(name: "topicId", value: String(topicID)),
                URLQueryItem(name: "merchantMemberId", value: String(merchantMemberID))
            ],
            token: token
        )
    }

    public func invitableMerchants(
        topicID: Int,
        latitude: Double? = nil,
        longitude: Double? = nil,
        token: String
    ) async throws -> [CoopInvitableMerchant] {
        guard topicID > 0 else { throw APIError.invalidRequest }
        var body: [String: Any] = ["topicId": topicID]
        if let latitude, let longitude {
            body["latitude"] = latitude
            body["longitude"] = longitude
        }
        return try await MPGapHTTP.postJSON(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/chapter-application/invitable",
            body: body,
            token: token
        )
    }

    public func inviteChapterReplacement(
        chapterID: Int,
        merchantMemberID: Int,
        replacementOfOfferID: Int? = nil,
        message: String? = nil,
        token: String
    ) async throws {
        guard chapterID > 0, merchantMemberID > 0 else { throw APIError.invalidRequest }
        var body: [String: Any] = ["chapterId": chapterID, "merchantMemberId": merchantMemberID]
        if let replacementOfOfferID, replacementOfOfferID > 0 {
            body["replacementOfOfferId"] = replacementOfOfferID
        }
        if let message, !message.isEmpty {
            body["message"] = message
        }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/chapter-application/invite",
            body: body,
            token: token
        )
    }

    /// Money write: withheld unless `allowsMoneyWrite` is explicitly enabled (TEST-only).
    public func createDeposit(inviteID: Int, token: String, allowsMoneyWrite: Bool) async throws -> Bool {
        guard allowsMoneyWrite else { return false }
        guard inviteID > 0 else { throw APIError.invalidRequest }
        try await MPGapHTTP.postFormAction(
            configuration: configuration,
            transport: transport,
            path: "api/coop/deposit/create/app",
            fields: ["inviteId": String(inviteID)],
            token: token
        )
        return true
    }

    /// Money write: withheld unless `allowsMoneyWrite` is explicitly enabled (TEST-only).
    public func retryDepositRefund(inviteID: Int, token: String, allowsMoneyWrite: Bool) async throws -> Bool {
        guard allowsMoneyWrite else { return false }
        guard inviteID > 0 else { throw APIError.invalidRequest }
        try await MPGapHTTP.postFormAction(
            configuration: configuration,
            transport: transport,
            path: "api/coop/deposit/refund/retry",
            fields: ["inviteId": String(inviteID)],
            token: token
        )
        return true
    }
}
