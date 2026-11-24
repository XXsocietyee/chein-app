import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round 4 additions for `merchant-coop` (`MC7-01..MC7-33` Gemini fix-queue items).

/// `MC7-02-2` & `MC7-02-3`: MP `MerchantClaimDTO.SubmitRequest` + `api/merchant/list` search + `claims/status`.
public struct MerchantClaimSearchCandidate: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let address: String?

    public init(id: Int, name: String, address: String? = nil) {
        self.id = id
        self.name = name
        self.address = address
    }
}

public struct MerchantClaimStatusItem: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let merchantName: String?
    public let status: String
    public let auditReason: String?

    public init(id: Int, merchantName: String? = nil, status: String, auditReason: String? = nil) {
        self.id = id
        self.merchantName = merchantName
        self.status = status
        self.auditReason = auditReason
    }
}

public struct MerchantClaimSubmitDTO: Encodable, Equatable, Sendable {
    public let merchantId: Int
    public let requestId: String
    public let contactName: String
    public let contactPhone: String
    public let statement: String
    public let proofs: [String]

    public init(
        merchantId: Int,
        requestId: String,
        contactName: String,
        contactPhone: String,
        statement: String,
        proofs: [String] = []
    ) {
        self.merchantId = merchantId
        self.requestId = requestId
        self.contactName = contactName
        self.contactPhone = contactPhone
        self.statement = statement
        self.proofs = proofs
    }
}

/// `MC7-11-2`: Daily heat grid cell + 俱乐部合作 pool card on AI Insight.
public struct MerchantAIInsightDailyHeatCell: Identifiable, Decodable, Equatable, Sendable {
    public let date: String
    public let level: Int
    public let count: Int

    public var id: String { date }

    public init(date: String, level: Int, count: Int) {
        self.date = date
        self.level = level
        self.count = count
    }
}

/// `MC7-23-2`: 3-sentence AI NPC voice recording state (write gated behind `allowsOwnerWrite`).
public struct MerchantAINPCVoiceSessionState: Equatable, Sendable {
    public static let sentencePrompts: [String] = [
        "欢迎来到本店，我是这里的店主。",
        "今天想体验哪一条城市探索路线呢？",
        "集齐印章后记得回来找我兑换小礼物。"
    ]
    public var currentSentenceIndex: Int = 0
    public var recordedFilePaths: [Int: String] = [:]
    public var isRecording: Bool = false

    public var isComplete: Bool {
        recordedFilePaths.count >= Self.sentencePrompts.count
    }

    public init() {}
}

/// `MC7-31-3` / `MC7-31-6` / `MC7-31-7`: Coop invite presets & single-select supply station.
public struct CoopInviteLockedTarget: Equatable, Sendable {
    public let type: Int
    public let toID: Int
    public let name: String

    public init(type: Int, toID: Int, name: String) {
        self.type = type
        self.toID = toID
        self.name = name
    }
}

/// `MC7-33-4`: Topic-scoped nearby invitable merchant merge.
public struct CoopNearbyTopicContext: Equatable, Sendable {
    public let topicID: Int
    public let topicName: String

    public init(topicID: Int, topicName: String) {
        self.topicID = topicID
        self.topicName = topicName
    }
}

public enum MerchantRound4Copy {
    public static let payoutVoucherPrefix = "打款凭证"
    public static let copySuccess = "已复制打款凭证号"
    public static let clubPoolSectionTitle = "俱乐部合作"
    public static let heatAxisToday = "今天"
    public static let targetLockedChip = "已锁定"
    public static let emptyTopicsTitle = "还没有可关联的主题"
    public static let publishTopicFirst = "先发布主题"
    public static let fixTermsCTA = "主题条款没配好？"
    public static let depositPayButton = "去缴纳保证金"
    public static let depositPolling = "正在确认保证金状态…"
    public static let openMicSettings = "去设置开启麦克风"
    public static let generateVoiceCTA = "确认并生成声音"
    public static let gameNodeScanPlaceholder = "输入或扫描核验码"
}

public struct MerchantRound4Client {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func searchMerchantsForClaim(keyword: String, token: String) async throws -> [MerchantClaimSearchCandidate] {
        try await MPGapHTTP.postJSON(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/list",
            body: ["keyword": keyword],
            token: token
        )
    }

    public func claimStatusList(token: String) async throws -> [MerchantClaimStatusItem] {
        try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/claims/status",
            token: token
        )
    }

    public func submitClaim(_ dto: MerchantClaimSubmitDTO, token: String) async throws {
        guard dto.merchantId > 0, !dto.requestId.isEmpty else { throw APIError.invalidRequest }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/claims/submit",
            body: [
                "merchantId": dto.merchantId,
                "requestId": dto.requestId,
                "contactName": dto.contactName,
                "contactPhone": dto.contactPhone,
                "statement": dto.statement,
                "proofs": dto.proofs
            ],
            token: token
        )
    }

    /// `MC7-29-5`: Accept operator invite via `POST api/merchant/operators/invite/accept` with `inviteToken`.
    public func acceptOperatorInvite(inviteToken: String, token: String) async throws {
        let trimmed = inviteToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.invalidRequest }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/operators/invite/accept",
            body: ["inviteToken": trimmed],
            token: token
        )
    }

    /// `MC7-30-7`: Deposit create via app path `api/coop/deposit/create/app` (TEST-only money gate).
    public func createCoopDepositApp(coopID: Int, token: String, allowsMoneyWrite: Bool) async throws -> Bool {
        guard allowsMoneyWrite else { return false }
        guard coopID > 0 else { throw APIError.invalidRequest }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/coop/deposit/create/app",
            body: ["id": coopID],
            token: token
        )
        return true
    }

    public func depositStatus(coopID: Int, token: String) async throws -> String {
        guard coopID > 0 else { throw APIError.invalidRequest }
        struct StatusPayload: Decodable { let status: String? }
        let payload: StatusPayload = try await MPGapHTTP.getJSON(
            configuration: configuration,
            transport: transport,
            path: "api/coop/deposit/status",
            queryItems: [URLQueryItem(name: "id", value: String(coopID))],
            token: token
        )
        return payload.status ?? ""
    }
}
