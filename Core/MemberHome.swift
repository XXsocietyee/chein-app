import Foundation
import Observation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A server count. Unknown stays unknown and is never stored as 0. A literal 0 stays 0.
public enum MemberHomeCountFact: Equatable {
    case unknown
    case value(Int)

    public static let unknownDisplay = "—"
    public var literal: Int? {
        if case .value(let number) = self { return number }
        return nil
    }
    public var displayText: String {
        switch self {
        case .unknown: return Self.unknownDisplay
        case .value(let number): return String(number)
        }
    }
}

/// The mini-program self profile header (`cy-profile viewer=self`), mapped from
/// the signed-in `/api/user/info` branch. Missing counters are display zero, as
/// in the source; an unread balance stays nil so the UI never asserts 0.00.
/// Page-ready text is separate: an unknown counter is "—", and a literal 0 stays "0".
public struct MemberIdentitySnapshot: Decodable, Equatable {
    public let id: Int?
    public let nickname: String
    public let avatar: String
    /// Exact decoded self-info source; never trim or rewrite a signed URL for media reads.
    public let avatarSource: String?
    public let role: String
    public let levelID: Int?
    public let city: String
    public let friendCount: Int
    public let followCount: Int
    public let fansCount: Int
    /// Page-ready facts. Unknown is not stored as 0. `friendCount` still follows the source.
    public let friendCountFact: MemberHomeCountFact
    public let followCountFact: MemberHomeCountFact
    public let fansCountFact: MemberHomeCountFact
    public let topicCountFact: MemberHomeCountFact
    public let activityCountFact: MemberHomeCountFact
    public let likeCountFact: MemberHomeCountFact
    /// All five source counters (follow, fans, topic, activity, like) were numeric.
    public let countersReady: Bool
    public let balanceText: String?
    public var balancePreviewText: String { balanceText ?? MemberHomeCountFact.unknownDisplay }
    public var friendCountText: String { friendCountFact.displayText }
    public var followCountText: String { followCountFact.displayText }
    public var fansCountText: String { fansCountFact.displayText }
    public var topicCountText: String { topicCountFact.displayText }
    public var activityCountText: String { activityCountFact.displayText }
    public var likeCountText: String { likeCountFact.displayText }
    /// A decoded object with no identity field and no known number. Not a zeroed profile.
    public var isPageEmpty: Bool {
        id == nil && nickname.isEmpty && avatar.isEmpty && role.isEmpty && levelID == nil && city.isEmpty
            && introduction.isEmpty && interests.isEmpty && casePictures.isEmpty && joinDate == nil
            && balanceText == nil
            && [friendCountFact, followCountFact, fansCountFact, topicCountFact, activityCountFact, likeCountFact]
                .allSatisfy { $0 == .unknown }
    }
    public let joinDate: String?
    public let introduction: String
    public let interests: [String]
    public let casePictures: [String]

    enum CodingKeys: String, CodingKey {
        case id, nickname, nickName, avatar, role, levelId, city, friendNum, followNum, fansNum
        case topicNum, activityNum, likeNum, balance, createTime, introduction, sysCategoryList, casePics
    }
    private struct Category: Decodable { let categoryName: String? }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = Self.integer(c, .id)
        nickname = Self.text(c, .nickname) ?? Self.text(c, .nickName) ?? ""
        avatar = Self.text(c, .avatar) ?? ""
        avatarSource = try? c.decodeIfPresent(String.self, forKey: .avatar)
        role = Self.text(c, .role) ?? ""
        levelID = Self.integer(c, .levelId)
        city = Self.text(c, .city) ?? ""
        let follow = Self.metric(c, .followNum), fans = Self.metric(c, .fansNum), friend = Self.metric(c, .friendNum)
        let topic = Self.metric(c, .topicNum), activity = Self.metric(c, .activityNum), like = Self.metric(c, .likeNum)
        friendCount = friend ?? 0; followCount = follow ?? 0; fansCount = fans ?? 0
        friendCountFact = Self.countFact(friend); followCountFact = Self.countFact(follow); fansCountFact = Self.countFact(fans)
        topicCountFact = Self.countFact(topic); activityCountFact = Self.countFact(activity); likeCountFact = Self.countFact(like)
        countersReady = [follow, fans, topic, activity, like].allSatisfy { $0 != nil }
        balanceText = Self.balance(c)
        joinDate = Self.text(c, .createTime).map(Self.joinDate)
        introduction = Self.text(c, .introduction) ?? ""
        interests = ((try? c.decodeIfPresent([Category].self, forKey: .sysCategoryList)) ?? nil)?
            .compactMap { $0.categoryName?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty } ?? []
        casePictures = (Self.text(c, .casePics) ?? "").split(separator: ";")
            .map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    /// Source `formatJoinDate`: first ten characters with `-` replaced by `.`.
    static func joinDate(_ raw: String) -> String {
        String(raw.prefix(10)).replacingOccurrences(of: "-", with: ".")
    }
    private static func text(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> String? {
        guard let value = try? c.decodeIfPresent(String.self, forKey: key) else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
    private static func number(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Decimal? {
        if let value = try? c.decodeIfPresent(Decimal.self, forKey: key) { return value }
        if let raw = text(c, key) { return Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")) }
        return nil
    }
    private static func integer(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        if let value = try? c.decodeIfPresent(Int.self, forKey: key) { return value }
        return text(c, key).flatMap { Int($0) }
    }
    private static func countFact(_ value: Int?) -> MemberHomeCountFact {
        guard let value else { return .unknown }
        return .value(value)
    }
    /// Source `metricNumber`: finite and non-negative, otherwise unknown.
    private static func metric(_ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys) -> Int? {
        guard let value = number(c, key), value >= 0, value <= Decimal(Int32.max) else { return nil }
        return NSDecimalNumber(decimal: value).intValue
    }
    /// Source `formatBalance`: two fraction digits, or nil (rendered as "—").
    private static func balance(_ c: KeyedDecodingContainer<CodingKeys>) -> String? {
        guard var value = number(c, .balance) else { return nil }
        var rounded = Decimal()
        NSDecimalRound(&rounded, &value, 2, .plain)
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSDecimalNumber(decimal: rounded))
    }
}

/// `/api/role/info` (server `UserPermission`). Only explicit `true` unlocks a
/// capability; a null theme limit means unlimited, exactly as `buildBenefits`.
public struct MemberRoleInfo: Decodable, Equatable {
    public struct Permission: Decodable, Equatable {
        public let maxThemes: Int?
        public let canPublishCoupon: Bool?
        public let canRedeemCoupon: Bool?
        public let canBranch: Bool?
        public let canGameMechanic: Bool?
        public let canOpenAsNode: Bool?
        public let canDesignMedal: Bool?
        public let canCreateGroup: Bool?
        public let withdrawable: Bool?
        public init(maxThemes: Int? = nil, canPublishCoupon: Bool? = nil, canRedeemCoupon: Bool? = nil,
                    canBranch: Bool? = nil, canGameMechanic: Bool? = nil, canOpenAsNode: Bool? = nil,
                    canDesignMedal: Bool? = nil, canCreateGroup: Bool? = nil, withdrawable: Bool? = nil) {
            self.maxThemes = maxThemes; self.canPublishCoupon = canPublishCoupon; self.canRedeemCoupon = canRedeemCoupon
            self.canBranch = canBranch; self.canGameMechanic = canGameMechanic; self.canOpenAsNode = canOpenAsNode
            self.canDesignMedal = canDesignMedal; self.canCreateGroup = canCreateGroup; self.withdrawable = withdrawable
        }
        enum CodingKeys: String, CodingKey {
            case maxThemes, canPublishCoupon, canRedeemCoupon, canBranch, canGameMechanic, canOpenAsNode, canDesignMedal, canCreateGroup, withdrawable
        }
        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func flag(_ key: CodingKeys) -> Bool? { try? c.decodeIfPresent(Bool.self, forKey: key) }
            maxThemes = try? c.decodeIfPresent(Int.self, forKey: .maxThemes)
            canPublishCoupon = flag(.canPublishCoupon); canRedeemCoupon = flag(.canRedeemCoupon)
            canBranch = flag(.canBranch); canGameMechanic = flag(.canGameMechanic); canOpenAsNode = flag(.canOpenAsNode)
            canDesignMedal = flag(.canDesignMedal); canCreateGroup = flag(.canCreateGroup); withdrawable = flag(.withdrawable)
        }
    }
    public let role: String
    public let isClubLeader: Bool
    public let ownedClubCount: Int
    /// Missing `ownedClubs` is unknown ("—"). An empty array is 0. `ownedClubCount` stays the source integer.
    public let ownedClubCountFact: MemberHomeCountFact
    public var ownedClubCountText: String { ownedClubCountFact.displayText }
    public let permission: Permission
    enum CodingKeys: String, CodingKey { case role, isClubLeader, ownedClubs, permission }
    private struct OwnedClub: Decodable {}
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let role = ((try? c.decodeIfPresent(String.self, forKey: .role)) ?? nil)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        // The source ignores a response without a role; so does this mapping.
        guard !role.isEmpty, role.utf8.count <= 32 else { throw APIError.malformedResponse }
        self.role = role
        isClubLeader = ((try? c.decodeIfPresent(Bool.self, forKey: .isClubLeader)) ?? nil) == true || role == "club"
        if let clubs = try? c.decodeIfPresent([OwnedClub].self, forKey: .ownedClubs) {
            ownedClubCount = clubs.count
            ownedClubCountFact = .value(clubs.count)
        } else {
            ownedClubCount = 0
            ownedClubCountFact = .unknown
        }
        permission = ((try? c.decodeIfPresent(Permission.self, forKey: .permission)) ?? nil) ?? Permission()
    }
    public var benefits: [MemberBenefit] { MemberBenefit.rows(for: permission) }
}

public struct MemberBenefit: Equatable, Identifiable {
    public enum Kind: String, CaseIterable, Equatable {
        case publishRoutes, publishCoupons, redeemCoupons, branching, gameMechanics, openAsNode, medalDesign, createGroup, earnings
    }
    public enum RouteLimit: Equatable { case unlimited, limited(Int) }
    public let kind: Kind
    public let unlocked: Bool
    /// Only the route-publishing row carries a limit.
    public let routeLimit: RouteLimit?
    /// Only 我的收益 navigates, and only when unlocked.
    public var opensEarnings: Bool { kind == .earnings && unlocked }
    public var id: String { kind.rawValue }

    public static func rows(for p: MemberRoleInfo.Permission) -> [MemberBenefit] {
        let limit: RouteLimit = p.maxThemes.map { .limited(max(0, $0)) } ?? .unlimited
        let routesUnlocked = p.maxThemes.map { $0 > 0 } ?? true
        func row(_ kind: Kind, _ flag: Bool?) -> MemberBenefit { .init(kind: kind, unlocked: flag == true, routeLimit: nil) }
        return [
            .init(kind: .publishRoutes, unlocked: routesUnlocked, routeLimit: limit),
            row(.publishCoupons, p.canPublishCoupon), row(.redeemCoupons, p.canRedeemCoupon),
            row(.branching, p.canBranch), row(.gameMechanics, p.canGameMechanic),
            row(.openAsNode, p.canOpenAsNode), row(.medalDesign, p.canDesignMedal),
            row(.createGroup, p.canCreateGroup), row(.earnings, p.withdrawable)
        ]
    }
}

public enum MemberRoleInfoReadRoute {
    public static let path = "api/role/info"
    public static func accepts(_ request: URLRequest, baseURL: URL) -> Bool {
        guard let url = request.url, url.query == nil, url.fragment == nil,
              url.absoluteString.utf8.elementsEqual(baseURL.appendingPathComponent(path).absoluteString.utf8),
              request.httpMethod == "POST", request.httpBody == nil, request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Accept") == "application/json",
              request.value(forHTTPHeaderField: "Content-Type") == nil,
              let token = request.value(forHTTPHeaderField: "Authorization"),
              AuthRequestBuilder.isValidToken(token) else { return false }
        return true
    }
}

public enum MemberHomeProfileTab: String, CaseIterable, Equatable, Identifiable, Sendable {
    case mine
    case posts
    case achievements
    case about

    public var id: String { rawValue }

    public var zhTitle: String {
        switch self {
        case .mine: return "我的"
        case .posts: return "推文"
        case .achievements: return "成就"
        case .about: return "关于"
        }
    }
}

public enum MemberHomeReadFailure: Error, Equatable { case rejected(code: Int, message: String?) }

/// Read-only. The identity read is the same body-less `user/info` request the
/// session bootstrap already sends; `role/info` has its own approval route.
public struct MemberHomeService {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration; self.transport = transport
    }
    public func identity(token: String) async throws -> MemberIdentitySnapshot {
        let base: MemberIdentitySnapshot = try await read(AuthRequestBuilder(configuration: configuration).make(.userInfo, token: token))
        guard !base.countersReady, let request = try? countersRequest(token),
              let full: MemberIdentitySnapshot = try? await read(request), full.countersReady,
              base.id == nil || full.id == base.id else { return base }
        return full
    }
    /// Lane-absent production identity. Posts `userInfoRequest` (`member_id`) and decodes the same snapshot.
    public func contractIdentity(token: String, memberID: Int) async throws -> MemberIdentitySnapshot {
        guard memberID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = try AccountPublishMPContract.userInfoRequest(
            baseURL: configuration.baseURL, memberID: String(memberID), token: token)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return try await read(request)
    }
    /// Same body-less `userInfo` read as `identity`. Null or non-object data is `.unknown`, not a zeroed card.
    public func identityPage(token: String) async throws -> MemberHomePageState {
        let request = try AuthRequestBuilder(configuration: configuration).make(.userInfo, token: token)
        let base = try await page(request, classify: MemberHomePageModel.classifyIdentity)
        guard case .ready(.identity(let card)) = base, card.followText == MemberHomeCountFact.unknownDisplay,
              let counters = try? await page(countersRequest(token), classify: MemberHomePageModel.classifyIdentity),
              case .ready(.identity(let full)) = counters, full.nickname == card.nickname,
              full.followText != MemberHomeCountFact.unknownDisplay else { return base }
        return counters
    }
    /// E2E-20261113b R10: `api/userInfo` carries no counters. `api/user/info` (the profile read, an empty multipart form)
    /// carries follow, fans, friend, topic, activity, like and balance. Used only when the first read had none.
    private func countersRequest(_ token: String) throws -> URLRequest {
        var request = try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent("api/user/info"),
                                                             fields: [:], token: token, includesBody: false)
        let boundary = "MemberCounters-" + UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("--\(boundary)--\r\n".utf8)
        return request
    }
    public func roleInfo(token: String) async throws -> MemberRoleInfo {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        return try await read(roleInfoRequest(token))
    }
    /// Same `api/role/info` read as `roleInfo`. A missing role stays `.empty` and does not invent unlocks.
    public func roleInfoPage(token: String) async throws -> MemberHomePageState {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        return try await page(roleInfoRequest(token), classify: MemberHomePageModel.classifyRoleInfo)
    }
    private func roleInfoRequest(_ token: String) throws -> URLRequest {
        try AuthRequestBuilder.makeFormRequest(
            url: configuration.baseURL.appendingPathComponent(MemberRoleInfoReadRoute.path),
            fields: [:], token: token, includesBody: false)
    }
    private func page(_ request: URLRequest, classify: (Data, Int) -> MemberHomePageState) async throws -> MemberHomePageState {
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        let state = classify(data, status)
        if MemberHomePageModel.isUnauthorized(state) { throw APIError.unauthorized }
        return state
    }
    private struct Status: Decodable { let code: Int; let msg: String? }
    private struct Payload<T: Decodable>: Decodable {
        let data: T
        private enum Keys: String, CodingKey { case data, appUser }
        // E2E R10: /api/userInfo carries the user under `appUser`; other member reads use `data`.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            if try c.contains(.data) && !c.decodeNil(forKey: .data) { data = try c.decode(T.self, forKey: .data) }
            else { data = try c.decode(T.self, forKey: .appUser) }
        }
    }
    private func read<T: Decodable>(_ request: URLRequest) async throws -> T {
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        guard data.count <= 256 * 1024 else { throw APIError.malformedResponse }
        let envelope = try? JSONDecoder().decode(Status.self, from: data)
        // The source treats code 401 and code 2 as an expired login.
        if status == 401 || envelope?.code == 401 || envelope?.code == 2 { throw APIError.unauthorized }
        guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
        guard let envelope else { throw APIError.malformedResponse }
        guard envelope.code == 200 else { throw MemberHomeReadFailure.rejected(code: envelope.code, message: envelope.msg) }
        do { return try JSONDecoder().decode(Payload<T>.self, from: data).data }
        catch { throw APIError.malformedResponse }
    }
}

/// An in-memory identity fence; credentials are neither displayed nor persisted.
public struct MemberHomeSession: Equatable {
    public let accountID: Int
    public let epoch: UInt64
    public let roleInfoApproval: UUID?
    public let role: String?
    public let viewerRevision: UInt64
    let token: String
    public init(accountID: Int, epoch: UInt64, token: String, roleInfoApproval: UUID?,
                role: String? = nil, viewerRevision: UInt64 = 0) throws {
        guard accountID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        self.accountID = accountID; self.epoch = epoch; self.token = token; self.roleInfoApproval = roleInfoApproval
        self.role = role; self.viewerRevision = viewerRevision
    }
    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.accountID == rhs.accountID && lhs.epoch == rhs.epoch && lhs.roleInfoApproval == rhs.roleInfoApproval &&
            lhs.viewerRevision == rhs.viewerRevision && lhs.role.map({ Data($0.utf8) }) == rhs.role.map({ Data($0.utf8) }) &&
            lhs.token.utf8.elementsEqual(rhs.token.utf8)
    }
}

@MainActor public protocol MemberHomeReading: AnyObject {
    /// Changes whenever the account, epoch, host role/viewer lifetime or role-info approval changes.
    var scope: UUID { get }
    var isSignedIn: Bool { get }
    var isConfigured: Bool { get }
    var roleInfoAvailable: Bool { get }
    func identity() async throws -> MemberIdentitySnapshot
    func roleInfo() async throws -> MemberRoleInfo
}

@MainActor @Observable public final class MemberHomeSessionReader: MemberHomeReading {
    private let service: MemberHomeService?
    private let currentSession: () -> MemberHomeSession?
    private let onUnauthorized: (MemberHomeSession) -> Void
    @ObservationIgnored private var snapshot: MemberHomeSession?
    private var stamp = UUID()
    public var scope: UUID {
        let current = currentSession()
        if snapshot != current { snapshot = current; stamp = UUID() }
        return stamp
    }
    public var isSignedIn: Bool { currentSession() != nil }
    public var isConfigured: Bool { service != nil }
    public var roleInfoAvailable: Bool { service != nil && currentSession()?.roleInfoApproval != nil }
    public init(service: MemberHomeService?, currentSession: @escaping () -> MemberHomeSession?,
                onUnauthorized: @escaping (MemberHomeSession) -> Void = { _ in }) {
        self.service = service; self.currentSession = currentSession; self.onUnauthorized = onUnauthorized
        snapshot = currentSession()
    }
    public func identity() async throws -> MemberIdentitySnapshot {
        try await read(requiresApproval: false) { try await $0.identity(token: $1) }
    }
    /// Production header path when `AccountPublishContractLane` is absent.
    public func contractIdentity() async throws -> MemberIdentitySnapshot {
        guard let memberID = currentSession()?.accountID else { throw APIError.unauthorized }
        return try await read(requiresApproval: false) { service, token in
            try await service.contractIdentity(token: token, memberID: memberID)
        }
    }
    public func roleInfo() async throws -> MemberRoleInfo {
        try await read(requiresApproval: true) { try await $0.roleInfo(token: $1) }
    }
    public func identityPage() async -> MemberHomePageState {
        await page(requiresApproval: false) { try await $0.identityPage(token: $1) }
    }
    public func benefitsPage() async -> MemberHomePageState {
        guard roleInfoAvailable else { return .empty }
        return await page(requiresApproval: true) { try await $0.roleInfoPage(token: $1) }
    }
    private func page(requiresApproval: Bool, _ operation: (MemberHomeService, String) async throws -> MemberHomePageState) async -> MemberHomePageState {
        do { return try await read(requiresApproval: requiresApproval, operation) }
        catch is CancellationError { return .loading }
        catch let error as APIError { return MemberHomePageModel.state(for: error) }
        catch { return .error(MemberHomePageFailure(httpStatus: nil, code: nil, message: nil)) }
    }
    private func read<T>(requiresApproval: Bool, _ operation: (MemberHomeService, String) async throws -> T) async throws -> T {
        try Task.checkCancellation()
        guard let captured = currentSession() else { throw APIError.unauthorized }
        guard let service, !requiresApproval || captured.roleInfoApproval != nil else { throw APIError.notConfigured }
        do {
            let value = try await operation(service, captured.token)
            try Task.checkCancellation()
            guard currentSession() == captured else { throw CancellationError() }
            return value
        } catch {
            guard !Task.isCancelled, currentSession() == captured else { throw CancellationError() }
            if error as? APIError == .unauthorized { onUnauthorized(captured) }
            throw error
        }
    }
}

public struct MemberHomePageFailure: Equatable {
    public let httpStatus: Int?
    public let code: Int?
    public let message: String?
    public init(httpStatus: Int?, code: Int?, message: String?) {
        self.httpStatus = httpStatus
        self.code = code
        self.message = message
    }
    public var isSignedOut: Bool { httpStatus == 401 || code == 401 || code == 2 }
}

public struct MemberHomeIdentityReady: Equatable {
    public let nickname: String
    public let cityText: String
    public let levelText: String
    public let friendText: String
    public let followText: String
    public let fansText: String
    public let topicText: String
    public let activityText: String
    public let likeText: String
    public let balanceText: String
    /// Growth streak is not read on this page. Nil stays "—". A literal 0 stays "0".
    public let streakText: String

    public init(snapshot: MemberIdentitySnapshot, streakDays: Int? = nil) {
        nickname = snapshot.nickname
        cityText = snapshot.city.isEmpty ? MemberHomeCountFact.unknownDisplay : snapshot.city
        levelText = snapshot.levelID.map(String.init) ?? MemberHomeCountFact.unknownDisplay
        friendText = snapshot.friendCountText
        followText = snapshot.followCountText
        fansText = snapshot.fansCountText
        topicText = snapshot.topicCountText
        activityText = snapshot.activityCountText
        likeText = snapshot.likeCountText
        balanceText = snapshot.balancePreviewText
        if let streakDays, streakDays >= 0 { streakText = String(streakDays) }
        else { streakText = MemberHomeCountFact.unknownDisplay }
    }
}

public struct MemberHomeBenefitsReady: Equatable {
    public let rows: [MemberBenefit]
    public let ownedClubCountText: String
    /// Role-info display does not turn a money write or the merchant choice on.
    public var showsMerchantChoice: Bool { false }
    public var paymentEnabled: Bool { false }
    public var payoutEnabled: Bool { false }
    public var withdrawalEnabled: Bool { false }
    public var virtualGoodsEnabled: Bool { false }

    public init(info: MemberRoleInfo) {
        rows = info.benefits
        ownedClubCountText = info.ownedClubCountText
    }
}

public enum MemberHomePageReady: Equatable {
    case identity(MemberHomeIdentityReady)
    case benefits(MemberHomeBenefitsReady)
}

public enum MemberHomePageState: Equatable {
    case loading
    case empty
    case error(MemberHomePageFailure)
    case unknown
    case ready(MemberHomePageReady)
}

public enum MemberHomePageCapability: String, Equatable, CaseIterable {
    case identityRead
    case roleInfoRead
    case banner
    case pointsSheet
    case merchantChoice
    case payment
    case payout
    case withdrawal
    case virtualGoods
}

public enum MemberHomePageModel {
    public static let unknownDisplay = MemberHomeCountFact.unknownDisplay
    /// Existing session read. This does not add a route.
    public static let identityRoute = AuthEndpoint.userInfo.rawValue
    /// Existing approved role read. This does not add a route.
    public static let roleInfoRoute = MemberRoleInfoReadRoute.path
    public static let wiredRoutes = [identityRoute, roleInfoRoute]
    public static let accessibilityIdentifiers = [
        "member.card.name", "member.card.level", "member.card.city", "member.card.streak",
        "member.card.friends", "member.card.following", "member.card.fans", "member.card.tickets",
        "member.card.balance", "member.card.balanceValue", "member.card.loading", "member.card.empty",
        "member.card.failed", "member.card.unknown", "member.card.retry", "member.benefits.loading",
        "member.benefits.unavailable", "member.benefits.failed", "member.benefits.retry",
        "member.benefit.publishRoutes", "member.benefit.publishCoupons", "member.benefit.redeemCoupons",
        "member.benefit.branching", "member.benefit.gameMechanics", "member.benefit.openAsNode",
        "member.benefit.medalDesign", "member.benefit.createGroup", "member.benefit.earnings"
    ]

    /// Banner and the points sheet exist elsewhere in this repo. They stay hidden on this page.
    public static func isEnabled(_ capability: MemberHomePageCapability) -> Bool {
        switch capability {
        case .identityRead, .roleInfoRead: return true
        case .banner, .pointsSheet, .merchantChoice, .payment, .payout, .withdrawal, .virtualGoods:
            return false
        }
    }

    public static func isUnauthorized(_ state: MemberHomePageState) -> Bool {
        if case .error(let failure) = state { return failure.isSignedOut }
        return false
    }

    public static func state(for error: APIError) -> MemberHomePageState {
        switch error {
        case .unauthorized:
            return .error(.init(httpStatus: 401, code: 401, message: nil))
        case .notConfigured:
            return .empty
        case .malformedResponse:
            return .unknown
        case .httpStatus(let status):
            return .error(.init(httpStatus: status, code: nil, message: nil))
        case .businessCode(let code):
            return .error(.init(httpStatus: nil, code: code, message: nil))
        case .invalidRequest, .invalidConfiguration:
            return .error(.init(httpStatus: nil, code: nil, message: nil))
        }
    }

    public static func state(for snapshot: MemberIdentitySnapshot, streakDays: Int? = nil) -> MemberHomePageState {
        if snapshot.isPageEmpty { return .empty }
        return .ready(.identity(.init(snapshot: snapshot, streakDays: streakDays)))
    }

    public static func identityCopyKey(_ state: MemberHomePageState) -> String {
        switch state {
        case .loading: return "member.card.loading"
        case .empty: return "member.card.empty"
        case .error(let failure): return failure.isSignedOut ? "member.card.signedOut" : "member.card.failed"
        case .unknown: return "member.card.unknownValue"
        case .ready: return "member.card.defaultName"
        }
    }

    public static func benefitsCopyKey(_ state: MemberHomePageState) -> String {
        switch state {
        case .loading: return "member.card.loading"
        case .empty: return "member.benefits.unavailable"
        case .error: return "member.benefits.failed"
        case .unknown: return "member.card.unknownValue"
        case .ready: return "member.benefits.title"
        }
    }

    public static func classifyIdentity(data: Data, status: Int) -> MemberHomePageState {
        classify(data: data, status: status) { payload in
            guard case .object = payload else { return .unknown }
            guard let snapshot = try? JSONDecoder().decode(ObjectPayload<MemberIdentitySnapshot>.self, from: data).data else {
                return .unknown
            }
            return state(for: snapshot)
        }
    }

    public static func classifyRoleInfo(data: Data, status: Int) -> MemberHomePageState {
        classify(data: data, status: status) { payload in
            guard case .object(let fields) = payload else { return .unknown }
            let role = fields["role"]?.text.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if role.isEmpty { return .empty }
            if role.utf8.count > 32 { return .error(.init(httpStatus: status, code: nil, message: nil)) }
            guard let info = try? JSONDecoder().decode(ObjectPayload<MemberRoleInfo>.self, from: data).data else {
                return .unknown
            }
            return .ready(.benefits(.init(info: info)))
        }
    }

    private static func classify(data: Data, status: Int, accept: (JSONBox) -> MemberHomePageState) -> MemberHomePageState {
        if data.count > 256 * 1024 { return .error(.init(httpStatus: status, code: nil, message: nil)) }
        if status == 401 { return .error(.init(httpStatus: 401, code: 401, message: nil)) }
        guard let envelope = try? JSONDecoder().decode(PageEnvelope.self, from: data) else {
            guard (200..<300).contains(status) else { return .error(.init(httpStatus: status, code: nil, message: nil)) }
            return .unknown
        }
        if envelope.code == 401 || envelope.code == 2 {
            return .error(.init(httpStatus: status, code: envelope.code, message: nil))
        }
        guard (200..<300).contains(status) else {
            return .error(.init(httpStatus: status, code: envelope.code, message: envelope.msg))
        }
        guard envelope.code == 200 else {
            return .error(.init(httpStatus: status, code: envelope.code, message: envelope.msg))
        }
        guard let payload = envelope.data else { return .unknown }
        if case .null = payload { return .unknown }
        return accept(payload)
    }

    private enum JSONBox: Decodable {
        case object([String: JSONBox])
        case array([JSONBox])
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        var text: String {
            if case .string(let value) = self { return value }
            return ""
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            if container.decodeNil() { self = .null; return }
            if let value = try? container.decode([String: JSONBox].self) { self = .object(value); return }
            if let value = try? container.decode([JSONBox].self) { self = .array(value); return }
            if let value = try? container.decode(String.self) { self = .string(value); return }
            if let value = try? container.decode(Bool.self) { self = .bool(value); return }
            if let value = try? container.decode(Double.self) { self = .number(value); return }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "unsupported")
        }
    }

    private struct PageEnvelope: Decodable {
        let code: Int
        let msg: String?
        let data: JSONBox?
        private enum Keys: String, CodingKey { case code, msg, data, appUser }
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            code = try c.decode(Int.self, forKey: .code); msg = try c.decodeIfPresent(String.self, forKey: .msg)
            let hasData = try c.contains(.data) && !c.decodeNil(forKey: .data)
            let primary = hasData ? try c.decode(JSONBox.self, forKey: .data) : nil
            data = try primary ?? c.decodeIfPresent(JSONBox.self, forKey: .appUser)
        }
    }

    private struct ObjectPayload<T: Decodable>: Decodable {
        let data: T
        private enum Keys: String, CodingKey { case data, appUser }
        // E2E R10: /api/userInfo carries the user under `appUser`; other member reads use `data`.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: Keys.self)
            if try c.contains(.data) && !c.decodeNil(forKey: .data) { data = try c.decode(T.self, forKey: .data) }
            else { data = try c.decode(T.self, forKey: .appUser) }
        }
    }
}

#if DEBUG
/// Offline page-ready data for pages/member/index/index. Not part of a Release build.
public enum MemberHomeFixtureData {
    public static let readyIdentityJSON = #"{"id":81,"nickname":"Synthetic member","city":"Synthetic City","levelId":2,"role":"player","friendNum":3,"followNum":12,"fansNum":8,"topicNum":1,"activityNum":2,"likeNum":0,"balance":"1.50","createTime":"2026-01-02 08:00:00"}"#
    public static let emptyIdentityJSON = "{}"
    public static let unknownCounterJSON = #"{"nickname":"Synthetic member","friendNum":null,"followNum":"x","fansNum":-1,"topicNum":1,"activityNum":2,"likeNum":0}"#
    public static let zeroCounterJSON = #"{"nickname":"Synthetic member","friendNum":0,"followNum":0,"fansNum":0,"topicNum":0,"activityNum":0,"likeNum":0,"balance":0}"#
    public static let unknownEnvelope = #"{"code":200,"data":null}"#
    public static let arrayEnvelope = #"{"code":200,"data":[]}"#
    public static let emptyEnvelope = #"{"code":200,"data":{}}"#
    public static let rejectedEnvelope = #"{"code":500,"msg":"Synthetic rejection"}"#
    public static let readyRoleJSON = #"{"role":"player","permission":{"maxThemes":3,"canBranch":true}}"#
    public static let emptyRoleEnvelope = #"{"code":200,"data":{"permission":{}}}"#
    public static let missingClubsRoleJSON = #"{"role":"player","permission":{}}"#

    public static func readyIdentity() throws -> MemberIdentitySnapshot {
        try JSONDecoder().decode(MemberIdentitySnapshot.self, from: Data(readyIdentityJSON.utf8))
    }
    public static func readyRole() throws -> MemberRoleInfo {
        try JSONDecoder().decode(MemberRoleInfo.self, from: Data(readyRoleJSON.utf8))
    }
    public static func envelope(_ dataJSON: String) -> Data {
        Data("{\"code\":200,\"data\":\(dataJSON)}".utf8)
    }
}
#endif
