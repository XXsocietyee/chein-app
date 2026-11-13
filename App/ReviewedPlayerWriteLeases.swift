import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension ReviewedProductionFormMutationRoute {
    /// Admits one owner-approved player write when that writer was constructed for this viewer.
    @MainActor static func acceptsPlayerWrite(_ request: URLRequest, baseURL: URL, token: String?,
                                              context: RuntimeDependencyContext, grant: ReviewedPlayerWriteGrant) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              let url = request.url, url.fragment == nil, url.user == nil, url.password == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port,
              let method = request.httpMethod else { return false }
        let relative = relativePath(url, baseURL: baseURL)
        if method != "GET", url.query != nil { return false }
        guard !relative.isEmpty, !ReleaseMoneyWriteSwitch.blocks("/" + relative),
              ChinaReviewedRouteCapability.forcedOff("/" + relative) == nil else { return false }
        if relative == "api/roam/presence" || relative == "api/roam/presence-visibility" { return false }
        if relative.hasPrefix("api/club/roles/") || relative.hasPrefix("api/merchant/") || relative.hasPrefix("api/mod-commerce") { return false }
        if relative == "api/registration/create" {
            return method == "POST" && grant.registration.paths.contains(relative) && freeRegistrationBody(request)
        }
        if let channel = NativeChannelTextRoute(request: request, baseURL: baseURL) {
            let approval = channel.operation == .send ? grant.channelTextSend : grant.channelTextReceipt
            let path = channel.operation == .send ? "api/im/send" : "api/im/send-receipt"
            return grant.imSend.paths.contains(path) && approval.matches(context, operation: channel.operation, conversationID: channel.conversationID)
        }
        if grant.clubAdmission.allowsWrites, grant.clubAdmission.matches(context),
           (ClubOrdinaryAdmissionRoute.accepts(request, baseURL: baseURL) || simpleClubMembership(request, baseURL: baseURL)) {
            return true
        }
        if let orientScore = orientScoreReviewDecision(request, relative: relative, reports: grant.reports) {
            return orientScore
        }
        if relative.hasPrefix("api/v1/community/"), grant.square.paths.contains(where: { $0.hasPrefix("api/v1/community/") }) {
            if method == "GET" { return request.httpBody == nil || request.httpBody?.isEmpty == true }
            guard ["POST", "PATCH", "DELETE"].contains(method) else { return false }
            if relative == "api/v1/community/notification-preferences" { return true }
            return stableCommunityRequestID(request)
        }
        if relative == "api/play/theme/state" {
            return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true)
        }
        if relative == "api/play/theme/replay" {
            return method == "POST" && covers(relative, grant.play) && themeReplayBody(request)
        }
        if ReviewedProductionGateLeases.playRuntimeReadPaths.contains(relative) {
            // G1 play runtime reads: GET with a query and no body. A POST to a read path is not this grant.
            // The game session view is the player's own projection only; CLUB / MERCHANT perspectives are not this grant.
            if relative == "api/game/session/view", playerPerspective(url) == false { return false }
            return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true) && covers(relative, grant.play)
        }
        if method == "GET" {
            if covers(relative, grant.friends.endpoint) { return true }
            return covers(relative, grant.play) && (request.httpBody == nil || request.httpBody?.isEmpty == true)
        }
        if relative == "api/user/player-code" { return method == "POST" && covers(relative, grant.play) }
        guard method == "POST", request.httpBody?.isEmpty == false else { return false }
        if ReviewedProductionGateLeases.teamCommandPaths.contains(relative) {
            return covers(relative, grant.team) && teamRequestID(request)
        }
        return covers(relative, grant.clubCommunity) || covers(relative, grant.profile)
            || covers(relative, grant.team) || covers(relative, grant.play) || covers(relative, grant.roamExtras)
            || covers(relative, grant.likes) || covers(relative, grant.reports) || covers(relative, grant.friends.endpoint)
    }

    /// `perspective=PLAYER` exactly once, as `game-session-client.js loadProjection('player')` sends it.
    static func playerPerspective(_ url: URL) -> Bool {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = items.filter { $0.name == "perspective" }.map(\.value)
        return values == ["PLAYER"]
    }

    static func covers(_ relative: String, _ approval: OperationEndpointApproval) -> Bool {
        if approval.paths.contains(relative) { return true }
        let key = ChinaReviewedRouteCapability.normalized("/" + relative)
        return approval.paths.contains { ChinaReviewedRouteCapability.normalized("/" + $0) == key }
    }

    private struct ThemeReplayBody: Decodable { let sessionId: Int }

    /// Replay is `{sessionId}` only. A price, channel, or extra field is not this write.
    static func themeReplayBody(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              Set(object.keys) == ["sessionId"],
              let session = try? JSONDecoder().decode(ThemeReplayBody.self, from: body).sessionId,
              session > 0 else { return false }
        return true
    }

    /// A create with `payChannel` or a positive amount is a payment step and stays closed.
    static func freeRegistrationBody(_ request: URLRequest) -> Bool {
        guard let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              object["payChannel"] == nil else { return false }
        for key in ["payAmount", "price", "amount", "payableAmount"] {
            if let number = object[key] as? NSNumber, number.doubleValue > 0 { return false }
        }
        return true
    }

    static func stableCommunityRequestID(_ request: URLRequest) -> Bool {
        guard let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        for key in ["requestId", "clientRequestId", "uploadRequestId", "request_id"] {
            if let value = object[key] as? String, !value.isEmpty { return true }
        }
        return false
    }

    static func teamRequestID(_ request: URLRequest) -> Bool {
        guard let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let value = object["requestId"] as? String, value.count == 32,
              value.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) }) else { return false }
        return true
    }

    static func simpleClubMembership(_ request: URLRequest, baseURL: URL) -> Bool {
        guard request.httpMethod == "POST",
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let url = request.url, let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let id = object["id"] as? NSNumber, id.intValue > 0 else { return false }
        let join = url == baseURL.appendingPathComponent("api/club/join")
        let quit = url == baseURL.appendingPathComponent("api/club/quit")
        guard join || quit else { return false }
        let keys = Set(object.keys)
        if quit { return keys == ["id"] }
        if keys == ["id"] { return true }
        guard keys == ["id", "joinMessage"], let message = object["joinMessage"] as? String, !message.isEmpty else { return false }
        return true
    }

    static func relativePath(_ url: URL, baseURL: URL) -> String {
        let base = baseURL.path.hasSuffix("/") ? String(baseURL.path.dropLast()) : baseURL.path
        let path = url.path
        guard path == base || path.hasPrefix(base + "/") else { return "" }
        return String(path.dropFirst(base.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }
}

@MainActor final class ReviewedProductionGateLeases {
    private var walletHistoryByContext: [String: WalletHistoryReadApproval] = [:]
    private var messagingHistoryByContext: [String: MessagingHistoryReadApproval] = [:]
    private var ownedOrderByContext: [String: OwnedOrderReadApproval] = [:]
    private var profileOwnedCouponByContext: [String: ProfileOwnedCouponReadAccess] = [:]
    private var profileFavoritesByContext: [String: ProfileFavoritesReadAccess] = [:]
    private var profileFavoriteTopicByContext: [String: ProfileFavoriteTopicReadAccess] = [:]
    private var profileFavoriteDetailByContext: [String: ProfileFavoriteDetailAccess] = [:]
    private var profileFavoriteRemovalByScope: [String: [ProfileFavoriteRemovalAccess]] = [:]
    private var profileParticipantByContext: [String: ProfileParticipantAccess] = [:]
    private var topicUnlikeByContext: [String: TopicUnlikeApproval] = [:]
    private var couponReadByContext: [String: CouponManagementReadApproval] = [:]
    private var couponWriteByContext: [String: CouponManagementWriteApproval] = [:]
    private var roamLiveWriteByContext: [String: OperationEndpointApproval] = [:]
    private var roamLiveByContext: [String: RoamLiveApproval] = [:]
    private var roamPrivateToolsWriteByContext: [String: RoamPrivateToolsAccess] = [:]
    private var roamPassportToolsByContext: [String: RoamPassportToolsReadAccess] = [:]
    private var roamPassportHistoryByContext: [String: RoamPassportHistoryReadAccess] = [:]
    private var teamReadByContext: [String: TeamReadApproval] = [:]
    private var nearbyTeamReadByContext: [String: OperationEndpointApproval] = [:]
    private var merchantOperationsWriteByContext: [String: OperationEndpointApproval] = [:]
    private var nearbyTeamWriteByContext: [String: OperationEndpointApproval] = [:]
    private var cityVoucherIssueByContext: [String: VerificationCodeApproval] = [:]
    private var playerWritesEnabled = false
    private var playerWritersByContext: [String: ReviewedPlayerWriteGrant] = [:]
    private var playConfigurationByContext: [String: RuntimeDependencyConfiguration] = [:]

    // player-write-paths-begin
    static let imPaths: Set<String> = ["api/im/send", "api/im/send-receipt"]
    static let clubCommunityPaths: Set<String> = [
        "api/club/post/create", "api/club/post/update", "api/club/post/like", "api/club/post/report",
        "api/club/post/delete", "api/club/post/comment/create", "api/club/post/comment/delete",
        "api/club/post/comment/report", "api/club/post/repost", "api/club/post/repost/undo"
    ]
    static let squarePaths: Set<String> = [
        "api/v1/community/guidelines/active", "api/v1/community/guidelines/ack", "api/v1/community/media/register",
        "api/v1/community/drafts", "api/v1/community/posts", "api/v1/community/reports", "api/v1/community/appeals",
        "api/v1/community/capabilities"
    ]
    static let profilePaths: Set<String> = ["api/user/update", "api/common/uploadOSS"]
    static let registrationPaths: Set<String> = ["api/registration/create"]
    static let teamCommandPaths: Set<String> = ["api/team/command", "api/team/command/query", "api/team/command/cancel"]
    static let playPaths: Set<String> = [
        "api/play/arrive", "api/play/answer", "api/play/checkin", "api/play/photo", "api/play/sensor-result",
        "api/play/puzzle/reveal", "api/play/action-context", "api/play/action-receipt", "api/play/help",
        "api/play/help/use", "api/play/help/skip", "api/play/help/receipt", "api/play/help/advanced/receipt", "api/play/advanced/start", "api/play/advanced/action",
        "api/topic/chapter/finish", "api/play/run-session/save", "api/play/journey/opening/complete",
        "api/play/orient/session", "api/play/orient/session/start", "api/play/orient/session/abandon",
        "api/play/orient/session/prepare", "api/play/orient/session/receipt",
        "api/play/orient/session/task/{}/result", "api/play/scan-entry", "api/play/nodes", "api/play/route-state",
        "api/play/theme/replay",
        // G7/G8 owner-approved non-money player routes (PlayerGapService.paths).
        "api/official/active-for-roam", "api/official/signup-command", "api/official/signup-command/query",
        "api/official/signup-command/cancel", "api/team/invite-qrcode", "api/team/trail/state",
        "api/team/trail/consent", "api/team/trail/sync", "api/registration/join_info", "api/city/nodes/favorites",
        "api/city/nodes/merchant/{}", "api/activity/publish_precheck", "api/media/asset/attribution",
        "api/object-card/rename", "api/user/player-code", "api/club/event-ops/host/request",
        "api/club/lead/arrive", "api/club/lead/broadcast", "api/club/post/like-state",
        // G1 play runtime (owner-approved, non-money): server-rolled checks, shared team help, run clear,
        // personal gameplay preview/action, the player-side shared preview, and circle record/answer.
        "api/play/check/roll", "api/play/check/reroll", "api/play/check/settle", "api/play/help/shared",
        "api/play/run-session/clear", "api/play/theme/gameplay-action", "api/play/theme/gameplay-preview",
        "api/game/session/shared/preview", "api/circle-theme/session/answer", "api/circle-theme/session/record",
        // g-partials: the circle page's own player reads and open/join, so answer/record reach production.
        // `circle-theme/instance/configure` (merchant host write) stays out.
        "api/circle-theme/instance/{}/offers", "api/circle-theme/session", "api/circle-theme/session/join",
        "api/circle-theme/session/{}/card"
    ].union(playRuntimeReadPaths)
    /// G1 play runtime GET reads. Host control/export and circle instance configure are not here.
    static let playRuntimeReadPaths: Set<String> = [
        "api/play/encounter", "api/play/check/receipt", "api/play/advanced/receipt", "api/play/history",
        "api/play/setup", "api/play/contact",
        // g-partials: TEAM backpack projection, `perspective=PLAYER` only (see `playerPerspective`).
        "api/game/session/view"
    ]
    static let roamExtraPaths: Set<String> = [
        "api/roam/checkin", "api/roam/stamp/create", "api/roam/stamp/exchange", "api/roam/finish",
        "api/roam/shop/visit", "api/roam/poi/discover", "api/roam/reveal",
        "api/roam/passport/record", "api/city/nodes/{}/favorite", "api/city/nodes/{}/complete"
    ]
    static let likePaths: Set<String> = ["api/topic/like", "api/comment/like", "api/creativesquare/like"]
    static let reportPaths: Set<String> = [
        "api/v1/community/reports", "api/v1/community/appeals", "api/comment/report", "api/topic/report",
        "api/template/report", "api/creativesquare/report", "api/im/report", "api/club/post/report",
        "api/club/post/comment/report", "api/club/governance/cases/report", "api/club/governance/cases/appeal",
        "api/orient/scoring/appeal", "api/orient/scoring/dispute"
    ]
    static let playCapabilities: Set<PlayExperienceCapability> = [
        .reads, .classicCompletion, .hints, .advanced, .playerCommands, .runPersistence, .journeyOpening
    ]
    // player-write-paths-end

    func notePlayerWrites(_ enabled: Bool) { playerWritesEnabled = enabled }

    func playerWriters(_ context: RuntimeDependencyContext) -> ReviewedPlayerWriteGrant? {
        guard playerWritesEnabled, context.market == .china, context.role == "player" || context.role == "club" else { return nil }
        let key = contextKey(context)
        if let existing = playerWritersByContext[key] { return existing }
        guard let grant = makePlayerGrant(context) else { return nil }
        playerWritersByContext[key] = grant
        return grant
    }

    private func makePlayerGrant(_ context: RuntimeDependencyContext) -> ReviewedPlayerWriteGrant? {
        let expires = Date().addingTimeInterval(3600)
        guard let im = makeEndpoint(context, paths: Self.imPaths),
              let clubCommunity = makeEndpoint(context, paths: Self.clubCommunityPaths),
              let square = makeEndpoint(context, paths: Self.squarePaths),
              let profile = makeEndpoint(context, paths: Self.profilePaths),
              let registration = makeEndpoint(context, paths: Self.registrationPaths),
              let team = makeEndpoint(context, paths: Self.teamCommandPaths),
              let play = makeEndpoint(context, paths: Self.playPaths),
              let roamExtras = makeEndpoint(context, paths: Self.roamExtraPaths),
              let likes = makeEndpoint(context, paths: Self.likePaths),
              let reports = makeEndpoint(context, paths: Self.reportPaths),
              let friendEndpoints = makeEndpoint(context, paths: NativeFriendApproval.readPaths.union(NativeFriendApproval.writePaths)),
              let friends = try? NativeFriendApproval(endpoint: friendEndpoints, expiresAt: expires),
              let avatar = try? ProfileAvatarApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                  accountID: context.session.accountID, approvedOrigins: [context.baseURL.absoluteString], nativePicker: true),
              let clubAdmission = try? ClubOrdinaryAdmissionApproval(context: context, allowsWrites: true),
              let channelTextSend = try? NativeChannelTextApproval(context: context, operation: .send, conversationIDs: [],
                  expiresAt: expires, allowsAnyPositiveConversation: true),
              let channelTextReceipt = try? NativeChannelTextApproval(context: context, operation: .receipt, conversationIDs: [],
                  expiresAt: expires, allowsAnyPositiveConversation: true) else { return nil }
        return ReviewedPlayerWriteGrant(imSend: im, clubAdmission: clubAdmission, clubCommunity: clubCommunity, square: square,
            profile: profile, avatar: avatar, registration: registration, team: team, play: play, roamExtras: roamExtras,
            likes: likes, reports: reports, friends: friends, channelTextSend: channelTextSend, channelTextReceipt: channelTextReceipt)
    }

    private func contextKey(_ context: RuntimeDependencyContext) -> String {
        "\(context.market.rawValue)|\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)|\(context.role)"
    }

    private func makeEndpoint(_ context: RuntimeDependencyContext, paths: Set<String>) -> OperationEndpointApproval? {
        try? .init(baseURL: context.baseURL, namespace: context.session.namespace,
                   accountID: context.session.accountID, paths: paths)
    }

    func roamLiveWrite(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = roamLiveWriteByContext[key] { return existing }
        guard let approval = makeEndpoint(context, paths: RoamLiveWriteTransport.writeApprovalPaths) else { return nil }
        roamLiveWriteByContext[key] = approval
        return approval
    }

    func roamLive(_ context: RuntimeDependencyContext) -> RoamLiveApproval? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = roamLiveByContext[key] { return existing }
        guard let endpoints = makeEndpoint(context, paths: RoamLiveApproval.requiredPaths) else { return nil }
        let approval = RoamLiveApproval(endpoints: endpoints, foregroundLocation: true, presence: false)
        roamLiveByContext[key] = approval
        return approval
    }

    func roamPrivateToolsWrite(_ context: RuntimeDependencyContext) -> RoamPrivateToolsAccess? {
        guard context.market == .china, context.role == "player" else { return nil }
        let key = contextKey(context)
        if let existing = roamPrivateToolsWriteByContext[key], existing.matches(context) { return existing }
        roamPrivateToolsWriteByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: RoamPrivateToolsAccess.universe),
              let access = try? RoamPrivateToolsAccess(context: context, approval: endpoints) else { return nil }
        roamPrivateToolsWriteByContext[key] = access
        return access
    }

    func roamPassportTools(_ context: RuntimeDependencyContext) -> RoamPassportToolsReadAccess? {
        guard context.market == .china, context.role == "player" else { return nil }
        let key = contextKey(context)
        if let existing = roamPassportToolsByContext[key], existing.matches(context) { return existing }
        roamPassportToolsByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: Set(RoamPassportToolsService.paths)),
              let access = try? RoamPassportToolsReadAccess(context: context, approval: endpoints) else { return nil }
        roamPassportToolsByContext[key] = access
        return access
    }

    func roamPassportHistory(_ context: RuntimeDependencyContext) -> RoamPassportHistoryReadAccess? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = roamPassportHistoryByContext[key], existing.matches(context) { return existing }
        roamPassportHistoryByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: RoamPassportHistoryReadRoute.paths),
              let access = try? RoamPassportHistoryReadAccess(context: context, approval: endpoints) else { return nil }
        roamPassportHistoryByContext[key] = access
        return access
    }

    func teamRead(_ context: RuntimeDependencyContext) -> TeamReadApproval? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = teamReadByContext[key], existing.matches(context) { return existing }
        teamReadByContext[key]?.revoke()
        guard let approval = try? TeamReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        teamReadByContext[key] = approval
        return approval
    }

    func merchantOperationsWrite(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard context.market == .china, context.role == "merchant" else { return nil }
        let key = contextKey(context)
        if let existing = merchantOperationsWriteByContext[key] { return existing }
        guard let approval = makeEndpoint(context, paths: ReviewedMerchantOperationsRoute.writePaths) else { return nil }
        merchantOperationsWriteByContext[key] = approval
        return approval
    }

    func nearbyTeamWrite(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = nearbyTeamWriteByContext[key] { return existing }
        guard let approval = makeEndpoint(context, paths: ReviewedNearbyTeamWriteRoute.approvalPaths) else { return nil }
        nearbyTeamWriteByContext[key] = approval
        return approval
    }

    func cityVoucherIssue(_ context: RuntimeDependencyContext) -> VerificationCodeApproval? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = cityVoucherIssueByContext[key] { return existing }
        guard let endpoints = makeEndpoint(context, paths: ["api/verify/citynode/issue"]) else { return nil }
        let approval = VerificationCodeApproval(market: .china, endpoints: endpoints, kinds: [.cityVoucher])
        cityVoucherIssueByContext[key] = approval
        return approval
    }

    func nearbyTeamRead(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = nearbyTeamReadByContext[key] { return existing }
        guard let approval = makeEndpoint(context, paths: ReviewedNearbyTeamReadRoute.approvalPaths) else { return nil }
        nearbyTeamReadByContext[key] = approval
        return approval
    }

    func walletHistory(_ context: RuntimeDependencyContext) -> WalletHistoryReadApproval? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = walletHistoryByContext[key], !existing.isRevoked { return existing }
        guard let approval = try? WalletHistoryReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        walletHistoryByContext[key] = approval
        return approval
    }

    func messagingHistory(_ context: RuntimeDependencyContext) -> MessagingHistoryReadApproval? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = messagingHistoryByContext[key], !existing.isRevoked { return existing }
        guard let approval = try? MessagingHistoryReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        messagingHistoryByContext[key] = approval
        return approval
    }

    func ownedOrder(_ context: RuntimeDependencyContext) -> OwnedOrderReadApproval? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = ownedOrderByContext[key], !existing.isRevoked { return existing }
        guard let approval = try? OwnedOrderReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        ownedOrderByContext[key] = approval
        return approval
    }

    func profileOwnedCoupon(_ context: RuntimeDependencyContext) -> ProfileOwnedCouponReadAccess? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = profileOwnedCouponByContext[key], !existing.isRevoked { return existing }
        guard let endpoints = makeEndpoint(context, paths: [ProfileOwnedCouponReadRoute.path]),
              let access = try? ProfileOwnedCouponReadAccess(context: context, approval: endpoints) else { return nil }
        profileOwnedCouponByContext[key] = access
        return access
    }

    func profileFavorites(_ context: RuntimeDependencyContext) -> ProfileFavoritesReadAccess? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = profileFavoritesByContext[key], !existing.isRevoked { return existing }
        guard let endpoints = makeEndpoint(context, paths: ProfileFavoritesReadRoute.paths),
              let access = try? ProfileFavoritesReadAccess(context: context, approval: endpoints) else { return nil }
        profileFavoritesByContext[key] = access
        return access
    }

    func profileFavoriteTopic(_ context: RuntimeDependencyContext) -> ProfileFavoriteTopicReadAccess? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = profileFavoriteTopicByContext[key], !existing.isRevoked { return existing }
        guard let endpoints = makeEndpoint(context, paths: [ProfileFavoriteTopicReadRoute.path]),
              let access = try? ProfileFavoriteTopicReadAccess(context: context, approval: endpoints) else { return nil }
        profileFavoriteTopicByContext[key] = access
        return access
    }

    func profileFavoriteDetail(_ context: RuntimeDependencyContext) -> ProfileFavoriteDetailAccess? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = profileFavoriteDetailByContext[key], !existing.isRevoked { return existing }
        guard let endpoints = makeEndpoint(context, paths: ProfileFavoriteDetailRoute.paths),
              let access = try? ProfileFavoriteDetailAccess(context: context, approval: endpoints) else { return nil }
        profileFavoriteDetailByContext[key] = access
        return access
    }

    func profileFavoriteRemoval(_ context: RuntimeDependencyContext, scope: UUID) -> [ProfileFavoriteRemovalAccess] {
        guard context.market == .china else { return [] }
        let key = "\(contextKey(context))|\(scope.uuidString)"
        if let existing = profileFavoriteRemovalByScope[key], existing.allSatisfy({ !$0.isRevoked }) { return existing }
        let identity = SocialAccountIdentity(accountID: context.session.accountID, epoch: context.session.epoch, role: context.role)
        guard let endpoint = makeEndpoint(context, paths: ProfileFavoriteRemovalApproval.paths),
              let approval = try? ProfileFavoriteRemovalApproval(endpoint: endpoint, identity: identity,
                  postID: 1, expiresAt: Date().addingTimeInterval(3600), allowsAnyPositivePostID: true),
              let access = try? ProfileFavoriteRemovalAccess(context: context, collectionScope: scope, approval: approval) else { return [] }
        profileFavoriteRemovalByScope[key] = [access]
        return [access]
    }

    func profileParticipant(_ context: RuntimeDependencyContext) -> ProfileParticipantAccess? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = profileParticipantByContext[key], !existing.isRevoked { return existing }
        guard let access = try? ProfileParticipantAccess(context: context, permitsWrites: true, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        profileParticipantByContext[key] = access
        return access
    }

    func topicUnlike(_ context: RuntimeDependencyContext) -> TopicUnlikeApproval? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = topicUnlikeByContext[key] { return existing }
        guard let endpoint = makeEndpoint(context, paths: TopicUnlikeApproval.paths),
              let approval = try? TopicUnlikeApproval(endpoint: endpoint, accountID: context.session.accountID, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        topicUnlikeByContext[key] = approval
        return approval
    }

    func couponRead(_ context: RuntimeDependencyContext) -> CouponManagementReadApproval? {
        guard context.market == .china, context.role == "merchant" else { return nil }
        let key = contextKey(context)
        if let existing = couponReadByContext[key], !existing.isRevoked { return existing }
        guard let approval = try? CouponManagementReadApproval(context: context, merchantID: context.session.accountID, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        couponReadByContext[key] = approval
        return approval
    }

    func couponWrite(_ context: RuntimeDependencyContext) -> CouponManagementWriteApproval? {
        guard context.market == .china, context.role == "merchant" else { return nil }
        let key = contextKey(context)
        if let existing = couponWriteByContext[key], !existing.isRevoked { return existing }
        let actions = Set(CouponManagementWriteApproval.Action.allCases)
        guard let approval = try? CouponManagementWriteApproval(context: context, merchantID: context.session.accountID, actions: actions, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        couponWriteByContext[key] = approval
        return approval
    }

    func sessionDependencies(_ context: RuntimeDependencyContext) -> NativeRuntimeDependencies {
        guard context.market == .china else { return .dormant }
        let couponPaths: Set<String> = ["api/coupon/qr-token", "api/coupon/status"]
        let couponEndpoints = makeEndpoint(context, paths: couponPaths)
        let couponCodeApproval = couponEndpoints.map {
            CouponCodeApproval(market: .china, endpoints: $0, imageOrigins: [context.baseURL.absoluteString])
        }
        let orderConfiguration = try? OrderLifecycleProductionConfiguration(
            market: .china, baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, role: context.role,
            sourceRevision: OrderLifecycleSourceContract.revision, approvals: [],
            externalCheckoutApproved: false, devicePaymentApproved: false,
            allowsReviewedCancellationAndRefund: true
        )
        let imRoutes: [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] = [
            .imDelete: Set([try? BusinessRuntimeRoute.post("api/im/delete")].compactMap { $0 }),
            .imReport: Set([try? BusinessRuntimeRoute.post("api/im/report")].compactMap { $0 }),
            .imBlock: Set([try? BusinessRuntimeRoute.post("api/im/block")].compactMap { $0 }),
            .imUnblock: Set([try? BusinessRuntimeRoute.post("api/im/unblock")].compactMap { $0 }),
            .imMute: Set([try? BusinessRuntimeRoute.post("api/im/mute")].compactMap { $0 }),
            .imRead: Set([try? BusinessRuntimeRoute.post("api/im/read")].compactMap { $0 }),
            .imStart: Set([try? BusinessRuntimeRoute.post("api/im/start")].compactMap { $0 }),
            .imSend: Set([try? BusinessRuntimeRoute.post("api/im/send"), try? BusinessRuntimeRoute.post("api/im/send-receipt")].compactMap { $0 }),
            .imUnreadTotal: Set([try? BusinessRuntimeRoute.post("api/im/unread-total")].compactMap { $0 }),
            .clubChat: Set([try? BusinessRuntimeRoute.post("api/club/chat")].compactMap { $0 })
        ]
        let businessConfiguration = try? BusinessRuntimeConfiguration(
            market: .china, baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, routes: imRoutes
        )
        return NativeRuntimeDependencies(
            configuration: playConfiguration(context),
            businessConfiguration: businessConfiguration,
            couponCodeApproval: couponCodeApproval,
            orderLifecycleConfiguration: orderConfiguration
        )
    }

    private func playConfiguration(_ context: RuntimeDependencyContext) -> RuntimeDependencyConfiguration? {
        guard playerWritesEnabled, context.role == "player" || context.role == "club",
              let endpoints = makeEndpoint(context, paths: Self.playPaths) else { return nil }
        let key = contextKey(context)
        if let existing = playConfigurationByContext[key] { return existing }
        let configuration = RuntimeDependencyConfiguration(market: .china, endpoints: endpoints, play: Self.playCapabilities,
            playReadApprovalID: UUID())
        playConfigurationByContext[key] = configuration
        return configuration
    }
}
