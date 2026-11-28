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
    /// MP `cast[].color`: one of the six contract colour literals (story-cast.js COLORS), nil = not chosen yet.
    public var colorHex: String?
    /// MP `cast[].clues` (你知道的): at most 6, each 1–40 characters, unlocked at the start or at a saved chapter.
    public var clues: [TopicCastClueDraft]
    /// MP `cast[].endingLines` (结局台词) by trust band; empty lines are left out on save.
    public var endingLow: String
    public var endingMid: String
    public var endingHigh: String

    public init(id: String, name: String, roleTitle: String, voiceID: String? = nil, colorHex: String? = nil,
                clues: [TopicCastClueDraft] = [], endingLow: String = "", endingMid: String = "", endingHigh: String = "") {
        self.id = id
        self.name = name
        self.roleTitle = roleTitle
        self.voiceID = voiceID
        self.colorHex = colorHex
        self.clues = clues
        self.endingLow = endingLow
        self.endingMid = endingMid
        self.endingHigh = endingHigh
    }
}

/// One MP cast clue: text + the chapter it unlocks at (`nil` = 开局就有). `chapterID` keeps the server value as sent.
public struct TopicCastClueDraft: Identifiable, Equatable, Sendable {
    public let id: UUID
    public var text: String
    public var chapterID: ProjectEditJSON?

    public init(id: UUID = UUID(), text: String, chapterID: ProjectEditJSON? = nil) {
        self.id = id
        self.text = text
        self.chapterID = chapterID
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

    /// `POST api/team/command` via `teamHandleRequest`. `memberId` is the applicant, `targetId` is the team.
    public func handleTeamApplication(teamID: Int, memberID: Int, approved: Bool, token: String) async throws {
        guard teamID > 0, memberID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        let requestID = UUID().uuidString.replacingOccurrences(of: "-", with: "").lowercased()
        var request = try AccountPublishMPContract.teamHandleRequest(
            baseURL: configuration.baseURL,
            memberID: String(memberID),
            approved: approved,
            targetID: String(teamID),
            requestID: requestID,
            token: token)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, status) = try await transport.send(request)
        if status == 401 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any], let code = root["code"] as? Int {
            if code == 401 { throw APIError.unauthorized }
            if code != 200 { throw MPGapServerRefusal(code: code, message: root["msg"] as? String) }
        }
    }
}

/// Requests and response fields the mini-program actually sends for account info, SMS,
/// settings, deregistration, team handle, and the club post feed.
/// Source: hengyin `chengyinhub-xcx` `25eb6a0c`. A POST with no header is
/// `application/x-www-form-urlencoded;`. JSON bodies keep object-literal key order.
/// `moneyEnabled` follows the payment host switch. This type does not build a pay, withdrawal, or pass request.
/// The earnings balance read does not depend on that flag.
public enum AccountPublishMPContract {
    public static var moneyEnabled: Bool { ReleaseMoneyWriteSwitch.paymentEnabled }
    public static let formContentType = "application/x-www-form-urlencoded;"
    public static let jsonContentType = "application/json"
    public static let userInfoPath = "api/user/info"
    public static let smsSendPath = "api/sms/send"
    public static let deregisterStatusPath = "api/user/deregister/status"
    public static let deregisterPrecheckPath = "api/user/deregister/precheck"
    public static let deregisterApplyPath = "api/user/deregister/apply"
    public static let deregisterCancelPath = "api/user/deregister/cancel"
    public static let teamCommandPath = "api/team/command"
    public static let clubPostFeedPath = "api/club/post/feed"

    public enum ContractError: Error, Equatable {
        case malformed
    }

    public struct SettingsRead: Equatable, Sendable {
        public let role: String
        public let viewKeys: [String]
    }

    public enum SettingsAccess: Equatable, Sendable {
        case ready(SettingsRead)
        case signedOut
        case denied
        case failed
    }

    public struct SettingsProfileForm: Equatable, Sendable {
        public let nickname: String
        public let email: String
    }

    public struct HomeAccount: Equatable, Sendable {
        public let role: String
        public let userType: Int?
        public let isClubLeader: Bool
        public let avatar: String
        public let nickname: String
        public let greeting: String
    }

    public struct ProfileEditor: Equatable, Sendable {
        public let shownName: String
        public let phone: String
        public let phoneMasked: String
        public let avatar: String
        public let casePictures: [String]
        public let introduction: String
        public let wechat: String
    }

    public struct PublishOwner: Equatable, Sendable {
        public let id: Int
        public let nickname: String
        public let avatar: String
    }

    public struct SelfProfile: Equatable, Sendable {
        public let role: String
        public let city: String
        public let joinDate: String
        public let balanceText: String?
        public let casePictures: [String]
        public let categories: [String]
        public let friendNum: Double?
        public let followNum: Double?
        public let fanNum: Double?
        public let topicNum: Double?
        public let activityNum: Double?
        public let likeNum: Double?
        public var friendDisplay: Double { friendNum ?? 0 }
        public var followDisplay: Double { followNum ?? 0 }
        public var fanDisplay: Double { fanNum ?? 0 }
        /// Profile ready check uses follow, fans, topic, activity, and like. `friendNum` is display-only.
        public var metricsReady: Bool {
            [followNum, fanNum, topicNum, activityNum, likeNum].allSatisfy { $0 != nil }
        }
    }

    public enum EarningsBalance: Equatable, Sendable {
        case amount(String)
        case missing
        case invalid
        public var display: String? {
            switch self {
            case let .amount(text): return text
            case .missing: return "0.00"
            case .invalid: return nil
            }
        }
    }

    public struct DeregisterStatus: Equatable, Sendable {
        public let status: String
        public let executeAfter: String
    }

    public enum DeregisterStatusRead: Equatable, Sendable {
        case loginRequired
        case denied
        case ready(DeregisterStatus)
        case unreadable
    }

    public struct DeregisterPrecheck: Equatable, Sendable {
        public let status: String
        public let blockers: [String]
        public let verificationMethod: String
    }

    public enum DeregisterApplyOutcome: Equatable, Sendable {
        case pending(executeAfter: String)
        case blocked([String])
    }

    public struct ClubFeedPost: Equatable, Sendable {
        public let id: Int?
        public let clubID: Int?
        public let authorMemberID: Int?
        public let nickname: String
        public let avatar: String
        public let content: String
        public let images: [String]
        public let createTime: String
        public let formattedCreateTime: String
        public let refType: Int?
    }

    public struct ClubFeedPage: Equatable, Sendable {
        public let posts: [ClubFeedPost]
        public let hasMore: Bool?
        public let clubCount: Int?
    }

    public struct TeamHandleReceipt: Equatable, Sendable {
        public let requestID: String
        public let state: String
        public let message: String
        public let errorCode: String
        public var terminal: Bool { ["APPLIED", "REJECTED", "CANCELLED"].contains(state) }
        public var showsRecoveryCard: Bool { !terminal }
        public var rejectNotice: String { state == "REJECTED" ? message : "" }
    }

    public static func userInfoRequest(baseURL: URL, memberID: String, token: String? = nil) throws -> URLRequest {
        guard !memberID.isEmpty else { throw APIError.invalidRequest }
        return try form(baseURL: baseURL, path: userInfoPath, fields: [("member_id", memberID)], token: token)
    }

    public static func smsSendRequest(baseURL: URL, phone: String, token: String? = nil) throws -> URLRequest {
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw APIError.invalidRequest }
        return try form(baseURL: baseURL, path: smsSendPath, fields: [("phone", trimmed)], token: token)
    }

    public static func deregisterStatusRequest(baseURL: URL, token: String? = nil) throws -> URLRequest {
        try bare(baseURL: baseURL, path: deregisterStatusPath, method: "GET", contentType: jsonContentType, token: token)
    }

    public static func deregisterPrecheckRequest(baseURL: URL, token: String? = nil) throws -> URLRequest {
        try bare(baseURL: baseURL, path: deregisterPrecheckPath, method: "POST", contentType: formContentType, token: token)
    }

    /// Exactly one proof: `smscode` (bound phone), `wxcode` (mini-program WeChat) or `identityToken`
    /// (+ optional `authorizationCode`) from a fresh Sign in with Apple — the backend field names of
    /// `ApiAccountDeregistrationController.apply`.
    public static func deregisterApplyRequest(baseURL: URL, requestID: String, smsCode: String? = nil, wxCode: String? = nil,
                                              appleProof: DeregistrationAppleProof? = nil, token: String? = nil) throws -> URLRequest {
        guard !requestID.isEmpty else { throw APIError.invalidRequest }
        let sms = smsCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let wx = wxCode?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let proofs = [!sms.isEmpty, !wx.isEmpty, appleProof != nil].filter { $0 }.count
        guard proofs == 1 else { throw APIError.invalidRequest }
        var fields: [(String, String)] = [("requestId", requestID)]
        if !sms.isEmpty {
            fields.append(("smscode", sms))
        } else if !wx.isEmpty {
            fields.append(("wxcode", wx))
        } else if let appleProof {
            fields.append(("identityToken", appleProof.identityToken))
            if let code = appleProof.authorizationCode { fields.append(("authorizationCode", code)) }
        }
        return try form(baseURL: baseURL, path: deregisterApplyPath, fields: fields, token: token)
    }

    public static func deregisterCancelRequest(baseURL: URL, token: String? = nil) throws -> URLRequest {
        try bare(baseURL: baseURL, path: deregisterCancelPath, method: "POST", contentType: formContentType, token: token)
    }

    public static func teamHandleRequest(baseURL: URL, memberID: String, approved: Bool, targetID: String, requestID: String, token: String? = nil) throws -> URLRequest {
        guard exactID(memberID), exactID(targetID), requestID.range(of: "^[a-f0-9]{32}$", options: .regularExpression) != nil else {
            throw APIError.invalidRequest
        }
        let body = "{"
            + "\"memberId\":\(jsonString(memberID)),"
            + "\"approved\":\(approved ? "true" : "false"),"
            + "\"targetId\":\(jsonString(targetID)),"
            + "\"action\":\"handle\","
            + "\"requestId\":\(jsonString(requestID))"
            + "}"
        return try json(baseURL: baseURL, path: teamCommandPath, body: body, token: token)
    }

    public static func clubPostFeedRequest(baseURL: URL, limit: Int, beforeID: Int? = nil, token: String? = nil) throws -> URLRequest {
        guard (1...50).contains(limit) else { throw APIError.invalidRequest }
        var body = "{\"scope\":\"all\",\"limit\":\(limit)"
        if let beforeID {
            guard beforeID > 0 else { throw APIError.invalidRequest }
            body += ",\"beforeId\":\(beforeID)"
        }
        body += "}"
        return try json(baseURL: baseURL, path: clubPostFeedPath, body: body, token: token)
    }

    public static func ownClubPostsRequest(baseURL: URL, token: String? = nil) throws -> URLRequest {
        try json(baseURL: baseURL, path: clubPostFeedPath, body: "{\"scope\":\"all\",\"author\":\"me\",\"limit\":20}", token: token)
    }

    public static func settingsAccess(status: Int, body: Data) -> SettingsAccess {
        if status == 401 || businessCode(body) == 401 { return .signedOut }
        if status == 403 || businessCode(body) == 403 { return .denied }
        guard let object = payload(body) else { return .failed }
        let role = (object["role"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let keys = object.keys.filter { $0 != "phone" }.sorted()
        return .ready(SettingsRead(role: role, viewKeys: keys))
    }

    public static func settingsProfileForm(from body: Data) -> SettingsProfileForm? {
        guard let object = payload(body) else { return nil }
        let nickname = text(object["nickname"]).trimmingCharacters(in: .whitespacesAndNewlines)
        let name = text(object["name"]).trimmingCharacters(in: .whitespacesAndNewlines)
        return SettingsProfileForm(nickname: nickname.isEmpty ? name : nickname, email: text(object["email"]))
    }

    public static func homeAccount(from body: Data) -> HomeAccount? {
        guard let object = payload(body) else { return nil }
        let role = text(object["role"])
        let nickname = text(object["nickname"])
        return HomeAccount(
            role: role,
            userType: jsonInt(object["userType"]),
            isClubLeader: jsonBool(object["isClubLeader"]) == true || role == "club",
            avatar: text(object["avatar"]),
            nickname: nickname,
            greeting: greeting(nickname))
    }

    public static func profileEditor(from body: Data) -> ProfileEditor? {
        guard let object = payload(body) else { return nil }
        let name = object["name"] as? String
        let nickname = object["nickname"] as? String
        let shown: String
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            shown = name
        } else if let nickname {
            shown = nickname
        } else {
            shown = name ?? ""
        }
        let phone = text(object["phone"])
        return ProfileEditor(
            shownName: shown,
            phone: phone,
            phoneMasked: maskPhone(phone),
            avatar: text(object["avatar"]),
            casePictures: splitList(text(object["casePics"]), separator: ";"),
            introduction: text(object["introduction"]),
            wechat: text(object["wechat"]))
    }

    public static func boundMobile(from body: Data) -> String? {
        guard let object = payload(body) else { return nil }
        let phone = text(object["phone"])
        let mobile = text(object["mobilePhone"])
        let candidate = (phone.isEmpty ? mobile : phone).trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.range(of: "^1[3-9]\\d{9}$", options: .regularExpression) != nil else { return nil }
        return candidate
    }

    public static func deregisterPhone(from body: Data) -> String? {
        guard let object = payload(body), let phone = object["phone"] as? String else { return nil }
        let trimmed = phone.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    public static func fabuOwner(from body: Data) -> PublishOwner? {
        guard let object = payload(body), let id = jsonInt(object["id"]) else { return nil }
        return PublishOwner(id: id, nickname: text(object["nickname"]), avatar: text(object["avatar"]))
    }

    public static func activityOwner(from body: Data) -> PublishOwner? {
        guard let owner = fabuOwner(from: body), owner.id > 0,
              !owner.nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return PublishOwner(id: owner.id, nickname: owner.nickname.trimmingCharacters(in: .whitespacesAndNewlines), avatar: owner.avatar)
    }

    public static func selfProfile(from body: Data) -> SelfProfile? {
        guard let object = payload(body) else { return nil }
        let categories: [String]
        if let rows = object["sysCategoryList"] as? [[String: Any]] {
            categories = rows.compactMap { row in
                let name = text(row["categoryName"])
                return name.isEmpty ? nil : name
            }
        } else {
            categories = []
        }
        let created = text(object["createTime"])
        let join = created.isEmpty ? "—" : String(created.prefix(10)).replacingOccurrences(of: "-", with: ".")
        return SelfProfile(
            role: text(object["role"]),
            city: text(object["city"]),
            joinDate: join,
            balanceText: formatBalance(object["balance"]),
            casePictures: splitList(text(object["casePics"]), separator: ";"),
            categories: categories,
            friendNum: metric(object["friendNum"]),
            followNum: metric(object["followNum"]),
            fanNum: metric(object["fansNum"]),
            topicNum: metric(object["topicNum"]),
            activityNum: metric(object["activityNum"]),
            likeNum: metric(object["likeNum"]))
    }

    public static func earningsBalance(from body: Data) -> EarningsBalance {
        guard let object = payload(body) else { return .invalid }
        return earnings(object["balance"])
    }

    public static func deregisterStatus(status: Int, body: Data) -> DeregisterStatusRead {
        if status == 401 || businessCode(body) == 401 { return .loginRequired }
        if status == 403 || businessCode(body) == 403 { return .denied }
        guard let object = payload(body), let name = object["status"] as? String else { return .unreadable }
        let when = object["executeAfter"] as? String ?? ""
        return .ready(DeregisterStatus(status: name, executeAfter: when))
    }

    public static func deregisterPrecheck(from body: Data) -> DeregisterPrecheck? {
        guard let object = payload(body), let status = object["status"] as? String,
              status == "ELIGIBLE" || status == "BLOCKED",
              let blockers = stringList(object["blockers"]) else { return nil }
        if status == "ELIGIBLE" && !blockers.isEmpty { return nil }
        if status == "BLOCKED" && blockers.isEmpty { return nil }
        let method: String
        if object["verificationMethod"] == nil || object["verificationMethod"] is NSNull {
            method = "SMS"
        } else if let raw = object["verificationMethod"] as? String, ["SMS", "WECHAT", "APPLE", "UNAVAILABLE"].contains(raw) {
            method = raw
        } else {
            method = "UNAVAILABLE"
        }
        return DeregisterPrecheck(
            status: status,
            blockers: blockers,
            verificationMethod: status == "ELIGIBLE" ? method : "UNAVAILABLE")
    }

    public static func deregisterApply(from body: Data) -> DeregisterApplyOutcome? {
        guard let object = payload(body), let status = object["status"] as? String else { return nil }
        if status == "PENDING" {
            return .pending(executeAfter: object["executeAfter"] as? String ?? "")
        }
        if status == "BLOCKED", let blockers = stringList(object["blockers"]), !blockers.isEmpty {
            return .blocked(blockers)
        }
        return nil
    }

    /// Server refusal text of a failed apply (`{"code":500,"msg":"Apple 身份校验失败"}`), nil for success or no text.
    public static func deregisterApplyRefusal(from body: Data) -> String? {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let code = businessCode(body), code != 200 else { return nil }
        let message = (root["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return message.isEmpty ? nil : message
    }

    public static func deregisterCancel(from body: Data) -> String? {
        guard let object = payload(body), object["status"] as? String == "CANCELLED" else { return nil }
        return "CANCELLED"
    }

    public static func discoverFeed(from body: Data) throws -> ClubFeedPage {
        guard let object = payload(body), jsonBool(object["hasMore"]) != nil,
              let rows = object["rows"] as? [[String: Any]] else { throw ContractError.malformed }
        return ClubFeedPage(
            posts: rows.map { discoverPost($0) },
            hasMore: jsonBool(object["hasMore"]),
            clubCount: jsonInt(object["clubCount"]))
    }

    public static func ownClubPosts(from body: Data) -> [ClubFeedPost] {
        guard let object = payload(body), let rows = object["rows"] as? [[String: Any]] else { return [] }
        return rows.map { ownPost($0) }
    }

    public static func teamHandleReceipt(from body: Data) -> TeamHandleReceipt? {
        guard let object = payload(body), let requestID = object["requestId"] as? String, !requestID.isEmpty,
              let state = object["state"] as? String else { return nil }
        return TeamHandleReceipt(
            requestID: requestID,
            state: state,
            message: text(object["message"]),
            errorCode: text(object["errorCode"]))
    }

    private static func form(baseURL: URL, path: String, fields: [(String, String)], token: String?) throws -> URLRequest {
        let body = fields.map { key, value in "\(formEncode(key))=\(formEncode(value))" }.joined(separator: "&")
        return try encoded(baseURL: baseURL, path: path, method: "POST", contentType: formContentType, body: Data(body.utf8), token: token)
    }

    private static func bare(baseURL: URL, path: String, method: String, contentType: String, token: String?) throws -> URLRequest {
        try encoded(baseURL: baseURL, path: path, method: method, contentType: contentType, body: nil, token: token)
    }

    private static func json(baseURL: URL, path: String, body: String, token: String?) throws -> URLRequest {
        try encoded(baseURL: baseURL, path: path, method: "POST", contentType: jsonContentType, body: Data(body.utf8), token: token)
    }

    private static func encoded(baseURL: URL, path: String, method: String, contentType: String, body: Data?, token: String?) throws -> URLRequest {
        guard baseURL.scheme == "https", baseURL.host != nil else { throw APIError.invalidRequest }
        var request = URLRequest(url: baseURL.appendingPathComponent(path))
        request.httpMethod = method
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        if let token, !token.isEmpty { request.setValue(token, forHTTPHeaderField: "Authorization") }
        request.httpBody = body
        return request
    }

    private static func payload(_ body: Data) -> [String: Any]? {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any], businessCode(body) == 200,
              let data = root["data"] as? [String: Any] else { return nil }
        return data
    }

    private static func businessCode(_ body: Data) -> Int? {
        guard let root = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return nil }
        if let number = jsonInt(root["code"]) { return number }
        if let text = root["code"] as? String, let number = Int(text) { return number }
        return nil
    }

    private static func jsonBool(_ value: Any?) -> Bool? {
        guard let number = value as? NSNumber, CFGetTypeID(number) == CFBooleanGetTypeID() else { return nil }
        return number.boolValue
    }

    private static func jsonInt(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let exact = number.int64Value
        guard exact <= Int64(Int.max), exact >= Int64(Int.min) else { return nil }
        return Int(exact)
    }

    private static func text(_ value: Any?) -> String {
        if let value = value as? String { return value }
        return ""
    }

    private static func metric(_ value: Any?) -> Double? {
        if value == nil || value is NSNull { return nil }
        if let raw = value as? String {
            if raw.isEmpty { return nil }
            guard let number = Double(raw), number.isFinite, number >= 0 else { return nil }
            return number
        }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let parsed = number.doubleValue
        return parsed.isFinite && parsed >= 0 ? parsed : nil
    }

    private static func formatBalance(_ value: Any?) -> String? {
        if value == nil || value is NSNull { return nil }
        if let raw = value as? String {
            if raw.isEmpty { return nil }
            guard let number = Double(raw), number.isFinite else { return nil }
            return fixed2(number)
        }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return nil }
        let parsed = number.doubleValue
        return parsed.isFinite ? fixed2(parsed) : nil
    }

    private static func earnings(_ value: Any?) -> EarningsBalance {
        if value == nil || value is NSNull { return .missing }
        if let raw = value as? String {
            if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .missing }
            guard let number = Double(raw), number.isFinite, number >= 0 else { return .invalid }
            return .amount(fixed2(number))
        }
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return .invalid }
        let parsed = number.doubleValue
        guard parsed.isFinite, parsed >= 0 else { return .invalid }
        return .amount(fixed2(parsed))
    }

    private static func fixed2(_ value: Double) -> String {
        let cents = Int((value * 100).rounded())
        let sign = cents < 0 ? "-" : ""
        let absolute = abs(cents)
        return "\(sign)\(absolute / 100).\(String(format: "%02d", absolute % 100))"
    }

    private static func stringList(_ value: Any?) -> [String]? {
        guard let rows = value as? [Any] else { return nil }
        var list: [String] = []
        for row in rows {
            guard let text = row as? String else { return nil }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty { return nil }
            list.append(trimmed)
        }
        return list
    }

    private static func splitList(_ value: String, separator: Character) -> [String] {
        value.split(separator: separator).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private static func discoverPost(_ row: [String: Any]) -> ClubFeedPost {
        let created = text(row["createTime"])
        let formatted = created.count > 5 ? String(created.dropFirst(5).prefix(11)) : ""
        return ClubFeedPost(
            id: jsonInt(row["id"]),
            clubID: jsonInt(row["clubId"]),
            authorMemberID: jsonInt(row["authorMemberId"]),
            nickname: text(row["nickname"]),
            avatar: text(row["avatar"]),
            content: decodeDisplayText(text(row["content"])),
            images: feedImages(row["images"]),
            createTime: created,
            formattedCreateTime: formatted,
            refType: jsonInt(row["refType"]))
    }

    private static func ownPost(_ row: [String: Any]) -> ClubFeedPost {
        ClubFeedPost(
            id: jsonInt(row["id"]),
            clubID: jsonInt(row["clubId"]),
            authorMemberID: jsonInt(row["authorMemberId"]),
            nickname: text(row["nickname"]),
            avatar: text(row["avatar"]),
            content: text(row["content"]),
            images: feedImages(row["images"]),
            createTime: text(row["createTime"]),
            formattedCreateTime: "",
            refType: jsonInt(row["refType"]))
    }

    private static func feedImages(_ value: Any?) -> [String] {
        let raw: String
        if let text = value as? String {
            raw = text
        } else if value == nil || value is NSNull {
            raw = ""
        } else if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() {
            raw = number.stringValue
        } else {
            raw = ""
        }
        return raw.split { $0 == ";" || $0 == "," }.map(String.init).filter { !$0.isEmpty }.prefix(3).map { $0 }
    }

    private static func decodeDisplayText(_ value: String) -> String {
        guard value.contains("&") else { return value }
        var result = ""
        var index = value.startIndex
        while index < value.endIndex {
            if value[index] != "&" {
                result.append(value[index])
                index = value.index(after: index)
                continue
            }
            if let (replacement, next) = displayEntity(value, index) {
                result += replacement
                index = next
            } else {
                result.append("&")
                index = value.index(after: index)
            }
        }
        return result
    }

    private static func displayEntity(_ value: String, _ start: String.Index) -> (String, String.Index)? {
        guard let end = value[start...].firstIndex(of: ";"), end > start else { return nil }
        let token = String(value[value.index(after: start)..<end])
        let named = ["lt": "<", "gt": ">", "amp": "&", "quot": "\"", "#39": "'"]
        if let found = named[token] { return (found, value.index(after: end)) }
        let numeric = [60: "<", 62: ">", 38: "&", 34: "\"", 39: "'"]
        if token.hasPrefix("#x") || token.hasPrefix("#X") {
            let digits = token.dropFirst(2).drop { $0 == "0" }
            guard let code = Int(digits, radix: 16), let found = numeric[code] else { return nil }
            return (found, value.index(after: end))
        }
        if token.hasPrefix("#") {
            let digits = token.dropFirst().drop { $0 == "0" }
            guard let code = Int(digits), let found = numeric[code] else { return nil }
            return (found, value.index(after: end))
        }
        return nil
    }

    private static func greeting(_ nickname: String) -> String {
        let nick = nickname.trimmingCharacters(in: .whitespacesAndNewlines)
        if nick.isEmpty || ["城瘾用户", "微信用户", "旅人"].contains(nick) { return "你好" }
        if nick.hasPrefix("用户"), nick.dropFirst(2).allSatisfy(\.isNumber), nick.count > 2 { return "你好" }
        return "你好，" + nick
    }

    private static func maskPhone(_ raw: String) -> String {
        let digits = raw.filter(\.isNumber)
        guard digits.count >= 7 else { return "" }
        return "\(digits.prefix(3))****\(digits.suffix(4))"
    }

    private static func exactID(_ value: String) -> Bool {
        guard value.range(of: "^[1-9]\\d{0,18}$", options: .regularExpression) != nil else { return false }
        return value.count < 19 || value <= "9223372036854775807"
    }

    private static func formEncode(_ value: String) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-_.!~*'()")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }

    private static func jsonString(_ value: String) -> String {
        var out = "\""
        for scalar in value.unicodeScalars {
            switch scalar {
            case "\\": out += "\\\\"
            case "\"": out += "\\\""
            default: out.append(Character(scalar))
            }
        }
        out += "\""
        return out
    }
}
