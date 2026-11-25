import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// MP `pages/merchant/{index,apply,profile,ledger,marketing,decor,relation,team}/*`
/// (`MC-G01`–`MC-G06`, `MC-G10`, `MC-G11`, `MC-G14`, `MC-G15`).
public struct MerchantWorkbenchProjectCard: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let title: String
    public let upcomingRunsCount: Int
    public let pendingVerifyCount: Int
    public let roleLabel: String?

    public init(
        id: Int,
        title: String,
        upcomingRunsCount: Int,
        pendingVerifyCount: Int,
        roleLabel: String? = nil
    ) {
        self.id = id
        self.title = title
        self.upcomingRunsCount = upcomingRunsCount
        self.pendingVerifyCount = pendingVerifyCount
        self.roleLabel = roleLabel
    }
}

public struct MerchantOwnedClubHandoverItem: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String
    public let statusText: String
    public let canTransfer: Bool

    public init(id: Int, name: String, statusText: String, canTransfer: Bool) {
        self.id = id
        self.name = name
        self.statusText = statusText
        self.canTransfer = canTransfer
    }
}

public struct MerchantOnboardingClaimRequest: Equatable, Sendable {
    public var storeName: String
    public var contactPhone: String
    public var note: String

    public init(storeName: String = "", contactPhone: String = "", note: String = "") {
        self.storeName = storeName
        self.contactPhone = contactPhone
        self.note = note
    }
}

public struct MerchantDecorContactDraft: Equatable, Sendable {
    public var contactPhone: String
    public var wechatID: String
    public var qrImageURL: String?
    public var address: String
    public var latitude: Double?
    public var longitude: Double?
    public var featuredTopicID: Int?
    public var featuredTopicName: String?

    public init(
        contactPhone: String = "",
        wechatID: String = "",
        qrImageURL: String? = nil,
        address: String = "",
        latitude: Double? = nil,
        longitude: Double? = nil,
        featuredTopicID: Int? = nil,
        featuredTopicName: String? = nil
    ) {
        self.contactPhone = contactPhone
        self.wechatID = wechatID
        self.qrImageURL = qrImageURL
        self.address = address
        self.latitude = latitude
        self.longitude = longitude
        self.featuredTopicID = featuredTopicID
        self.featuredTopicName = featuredTopicName
    }
}

public struct MerchantRelationFeedItem: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let authorName: String
    public let content: String
    public let likeCount: Int
    public let isLiked: Bool

    public init(id: Int, authorName: String, content: String, likeCount: Int = 0, isLiked: Bool = false) {
        self.id = id
        self.authorName = authorName
        self.content = content
        self.likeCount = likeCount
        self.isLiked = isLiked
    }
}

public struct MerchantPendingTeamInvite: Identifiable, Decodable, Equatable, Sendable {
    public let id: Int
    public let merchantName: String
    public let roleName: String

    public init(id: Int, merchantName: String, roleName: String) {
        self.id = id
        self.merchantName = merchantName
        self.roleName = roleName
    }
}

public enum MerchantRemainingGapCopy {
    // MC-G02
    public static let introTitle = "把你的店放进玩家的路线里"
    public static let startOnboarding = "开始入驻"
    public static let claimExistingStore = "门店已在城瘾上线？认领已有门店"
    public static let clubTransferHeader = "主理人身份处理"
    public static let clubTransferTitle = "商家账号生效前，须完成俱乐部移交"
    public static let clubTransferSub = "仅已生效的俱乐部可移交"
    public static let goTransfer = "前往移交"
    // MC-G04 / MC-G05
    public static let coopProfitEntry = "合作分润"
    public static let settleRemindTitle = "结算到账提醒"
    public static let copyPayoutVoucher = "复制打款凭证"
    // MC-G10 / MC-G11
    public static let previewPublicHome = "看公开主页"
    public static let contactOpsOpen = "联系运营开通"
    public static let contactPhoneLabel = "联系电话"
    public static let wechatLabel = "门店微信"
    public static let qrLabel = "门店二维码"
    public static let addressLabel = "店铺地址"
    public static let galleryNotOnboarded = "暂时无法上传门店相册"
    public static let coopSettingNotOnboarded = "暂时无法编辑承接设置"
    public static let goOnboardingCTA = "去商家入驻"
    public static let refreshingGallery = "正在刷新门店相册…"
    // MC-G14 / MC-G15
    public static let relationTabPosts = "帖子"
    public static let relationTabClubs = "俱乐部"
    public static let composePost = "发帖文"
    public static let refreshingRelation = "正在更新合作对象"
    public static let pendingTeamInviteTitle = "团队邀请"
    public static let acceptTeamInvite = "接受"
}

public struct MerchantRemainingGapClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func claimExistingStore(_ claim: MerchantOnboardingClaimRequest, token: String) async throws {
        guard !claim.storeName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw APIError.invalidRequest
        }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/claims/submit",
            body: [
                "storeName": claim.storeName,
                "contactPhone": claim.contactPhone,
                "note": claim.note
            ],
            token: token
        )
    }

    public func saveBrandContact(_ draft: MerchantDecorContactDraft, token: String) async throws {
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/update",
            body: [
                "phone": draft.contactPhone,
                "wechat": draft.wechatID
            ],
            token: token
        )
    }

    public func saveDecorDisplay(_ draft: MerchantDecorContactDraft, token: String) async throws {
        var body: [String: Any] = ["address": draft.address]
        if let qr = draft.qrImageURL { body["qrUrl"] = qr }
        if let lat = draft.latitude, let lng = draft.longitude {
            body["lat"] = lat
            body["lng"] = lng
        }
        try await MPGapHTTP.postAction(
            configuration: configuration,
            transport: transport,
            path: "api/merchant/decor/save",
            body: body,
            token: token
        )
    }
}

/// iOS twin of WeChat `subscribe.request(['coopSettle'])` (`utils/subscribe.js`).
/// There is no HTTP opt-in in the public tree. The settlement segment toggles this
/// preference and asks for notification permission. The template id and landing page
/// are the ones already registered for 结算到账提醒. This does not send money.
public struct MerchantSettleRemindOptIn: Equatable, Sendable {
    public static let subscribeKey = "coopSettle"
    public static let templateID = "Z10x9KV0jciDbFGTS6javEjqz0abOi-ik6x_0e_pt-o"
    public static let landingPage = "pages/merchant/ledger/index"
    public static let title = MerchantRemainingGapCopy.settleRemindTitle
    public var enabled: Bool
    public init(enabled: Bool = false) { self.enabled = enabled }
    public func setting(_ enabled: Bool) -> Self { Self(enabled: enabled) }
}
