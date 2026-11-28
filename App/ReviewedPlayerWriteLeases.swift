import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Same paths as `ChinaReviewedRouteCapability.ownerDecisionGuardGrant`.
/// Reads are admitted. Payout writes follow the payout switch, including www.chengyinhub.com.
/// Merchant content writes stay closed on that host.
enum OwnerDecisionGuardLease {
    static let paths: Set<String> = [
        "api/club/personal-receiver/status",
        "api/club/personal-receiver/unbind",
        "api/merchant/payout-account"
    ]

    static func admits(relative: String, method: String, body: Data?, host: String?) -> Bool {
        guard paths.contains(relative) else { return false }
        if relative == "api/club/personal-receiver/status" {
            return method == "GET" && (body == nil || body?.isEmpty == true)
        }
        if relative == "api/merchant/payout-account" {
            return method == "POST" && (body == nil || body?.isEmpty == true)
        }
        guard !ReleaseMoneyWriteSwitch.blocks("/" + relative), ReviewedAreaSwitch.payout(host: host) else { return false }
        if relative.hasPrefix("api/merchant/") {
            guard ReviewedAreaSwitch.merchantWrites(host: host) else { return false }
        }
        return method == "POST" && body?.isEmpty == false
    }
}

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
        if relative == "api/workshop/purchased" || relative == "api/reward-pledge/versions"
            || relative == "api/friend/channel-invite" || relative == "api/friend/team-invite" { return false }
        if ReviewedProductionGateLeases.wp07CommercePaths.contains(relative) {
            return wp07CommerceAllows(request, relative: relative, method: method, baseURL: baseURL, grant: grant)
        }
        if let wp06 = ReviewedProductionGateLeases.wp06PartialPageDecision(method: method, relative: relative, request: request, url: url) {
            return wp06
        }
        if admitsRewardPledgeWrite(relative) {
            if method == "GET" { return request.httpBody == nil || request.httpBody?.isEmpty == true }
            return method == "POST"
        }
        if relative == "api/roam/presence" { return false }
        if relative == RoamPresenceVisibilityContract.path {
            return roamPresenceDisableAllowed(request, url: url, grant: grant)
        }
        if MerchantOpsWp03Lease.admits(relative: relative, method: method, host: url.host) {
            let reading = relative == MerchantOpsWp03Catalog.claimsStatus || relative == MerchantOpsWp03Catalog.npcReview
            if reading { return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true) }
            return method == "POST" && request.httpBody?.isEmpty == false
        }
        if OwnerDecisionGuardLease.admits(relative: relative, method: method, body: request.httpBody, host: url.host) {
            return true
        }
        if relative.hasPrefix("api/club/roles/") || relative.hasPrefix("api/merchant/") || relative.hasPrefix("api/mod-commerce") { return false }
        // fix-1128b-social #4/#27: 发布 tab, club 发布活动 and 我的项目 activity 编辑 (POST, MP pages/publish/*).
        if let publishing = MPFirstSocialApprovals.publishingDecision(relative: relative, method: method, request: request) { return publishing }
        // fix/1128c-ai-showcase: the player/club AI creation calls (theme draft, quota, club design, template fill, safety).
        if let aiCreation = AICreationReleaseApprovals.decision(relative: relative, method: method, request: request) { return aiCreation }
        if let reportRead = MPFirstSocialApprovals.reportReadDecision(relative: relative, method: method, request: request) { return reportRead }
        if let official = officialParticipationDecision(request, relative: relative, method: method, url: url) {
            return official
        }
        if AppCompositionRoot.registrationWaitlistPaths.contains(relative) {
            // Gap #8: the player waitlist rides on the registration grant; JSON exactly `{activityId, ticketId}`.
            return method == "POST" && grant.registration.paths.contains("api/registration/create") && waitlistScopeBody(request)
        }
        if relative == "api/registration/create" {
            return method == "POST" && grant.registration.paths.contains(relative)
                && registrationCreateBody(request, paymentsOpen: ReleaseMoneyWriteSwitch.paymentEnabled)
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
        if relative == "api/verify/dyncode/issue" {
            // E2E rerun 3 (R8): the signed-in owner's own ticket entry code, shown from the wallet or Present pass. Exactly one
            // multipart field `registrationId` > 0; the server checks the registration's owner. Issuing a code moves no money.
            return method == "POST" && covers("api/registration/create", grant.registration)
                && singlePositiveFormField(request, url: url, key: "registrationId", token: token)
        }
        if relative == "api/play/theme/state" {
            return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true)
        }
        if relative == PlayerGapService.editionEmptyReasonPath {
            // WP-02: the compensation editions empty reason. Money area: open only where `moneyPayments` opens (TEST/DEBUG
            // hosts), never on the production host. JSON exactly `{"clubId": <positive>}`, as edition-empty-reason.js sends.
            guard method == "POST", ReviewedAreaSwitch.moneyPayments(apiHost: context.baseURL.host),
                  request.value(forHTTPHeaderField: "Content-Type") == "application/json", let body = request.httpBody,
                  let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
                  Set(object.keys) == ["clubId"], let id = object["clubId"] as? Int, id > 0 else { return false }
            return true
        }
        if relative == ReviewedProductionGateLeases.clubLeadSettlePath {
            // mp-club r3 J-18: 全团结算 redeems the team's bought tickets into settlement. Open only where money payments
            // open; the form body carries the activity id alone (MP pages/play/index.js:5966).
            guard method == "POST", ReviewedAreaSwitch.moneyPayments(apiHost: context.baseURL.host),
                  request.httpBody?.isEmpty == false else { return false }
            return covers(relative, grant.play)
        }
        if relative == "api/club/chat" {
            // E2E R3: enter a club's group chat. ClubChatService sends JSON exactly {"id": <club id>}.
            guard method == "POST", covers(relative, grant.clubCommunity), request.value(forHTTPHeaderField: "Content-Type") == "application/json",
                  let body = request.httpBody, let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
                  Set(object.keys) == ["id"], let id = object["id"] as? Int, id > 0 else { return false }
            return true
        }
        if relative == "api/play/theme/replay" {
            return method == "POST" && covers(relative, grant.play) && themeReplayBody(request)
        }
        if relative == "api/media/asset/attribution" {
            return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true)
                && covers(relative, grant.templateAdoption)
        }
        if let creator = creatorEditorDecision(request, relative: relative, method: method, grant: grant) { return creator }
        if ReviewedProductionGateLeases.playRuntimeReadPaths.contains(relative) {
            // G1 play runtime reads: GET with a query and no body. A POST to a read path is not this grant.
            // The game session view is the player's own projection only; CLUB / MERCHANT perspectives are not this grant.
            if relative == "api/game/session/view", playerPerspective(url) == false { return false }
            return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true) && covers(relative, grant.play)
        }
        if ReviewedProductionGateLeases.creatorStudioPaths.contains(String(ChinaReviewedRouteCapability.normalized("/" + relative).dropFirst())) {
            return creatorStudioRequest(request, relative: relative, method: method, grant: grant.play)
        }
        if relative.hasPrefix("api/external-game/") {
            return admitsExternalGame(method: method, relative: relative, request: request, grant: grant)
        }
        if let surface = hostTipSurfaceDecision(method: method, relative: relative, request: request, paths: grant.play.paths) {
            return surface
        }
        if method == "GET" {
            let emptyBody = request.httpBody?.isEmpty ?? true
            // Admission receipts use the client's own `adm-<uuid>` request ids (contract §0.3 management form).
            let receipt = "api/channel-platform/admission/requests/"
            if relative.hasPrefix(receipt), grant.admission.paths.contains(receipt + "{}") {
                return emptyBody && relative.dropFirst(receipt.count).range(of: "^[A-Za-z0-9_.:-]{8,64}$", options: .regularExpression) != nil
            }
            // Admission first reads the channel detail for the current catalog (`ChannelDirectoryCatalogProducer`).
            if ChinaReviewedRouteCapability.normalized("/" + relative) == "/api/channels/{}", grant.admission.paths.contains(receipt + "{}") {
                return emptyBody
            }
            if ClubGapProductionLease.allows(relative: relative, method: method, body: request.httpBody) { return true }
            if covers(relative, grant.friends.endpoint) || covers(relative, grant.admission) || covers(relative, grant.teamPool) { return true }
            // G4/G5 capability reads and the other play-grant reads (parity-a): GET with no body.
            return covers(relative, grant.play) && emptyBody
        }
        if ReviewedProductionGateLeases.isBodilessPlayTagWrite(relative) {
            // fix-1128b #19 (J-09e): tag confirm/revoke are bodiless POSTs (PlayExperienceService `postWithoutBody`);
            // the server checks the tag owner. `correct` carries JSON and takes the generic POST rule below.
            return method == "POST" && (request.httpBody?.isEmpty ?? true) && covers(relative, grant.play)
        }
        if relative == "api/user/player-code" { return method == "POST" && covers(relative, grant.play) }
        // `share/revoke` and the personal `publish_precheck` are the mini-program's `data: {}` form posts: an empty body is that call.
        guard method == "POST", request.httpBody?.isEmpty == false || ["api/roam/share/revoke", "api/activity/publish_precheck"].contains(relative) else { return false }
        if relative == "api/topic/chapter/supply-terms" {
            // REVSHARE carries the per-head fee a club would pay; only PERK and TRAFFIC terms are this grant.
            return covers(relative, grant.play) && supplyTermsBody(request)
        }
        if ReviewedProductionGateLeases.teamCommandPaths.contains(relative) {
            return covers(relative, grant.team) && teamRequestID(request)
        }
        if relative == "api/team/create" {
            return covers(relative, grant.team) && teamCreateBody(request)
        }
        if relative == "api/game/session/command" {
            return covers(relative, grant.play) && teamItemCommandBody(request)
        }
        if relative == "api/game/session/view" || relative == "api/game/session/receipt" {
            return false
        }
        if relative == "api/preset/gameplay/draft" {
            return covers(relative, grant.play) && gameplayPresetDraftBody(request)
        }
        if relative == "api/preset/gameplay/list" || relative == "api/preset/gameplay/info" {
            return false
        }
        if ClubGapProductionLease.allows(relative: relative, method: method, body: request.httpBody) { return true }
        return covers(relative, grant.clubCommunity) || covers(relative, grant.profile)
            || covers(relative, grant.team) || covers(relative, grant.play) || covers(relative, grant.roamExtras)
            || covers(relative, grant.likes) || covers(relative, grant.reports) || covers(relative, grant.friends.endpoint)
            || covers(relative, grant.templateAdoption)
            || covers(relative, grant.admission) || covers(relative, grant.teamPool)
    }

    /// One multipart form field `key` holding a positive integer, byte-equal to the canonical `AuthRequestBuilder` form.
    static func singlePositiveFormField(_ request: URLRequest, url: URL, key: String, token: String) -> Bool {
        guard request.httpBodyStream == nil, url.query == nil,
              let type = request.value(forHTTPHeaderField: "Content-Type"), type.hasPrefix("multipart/form-data; boundary="),
              let body = request.httpBody, body.count <= 1024, let text = String(data: body, encoding: .utf8) else { return false }
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        let marker = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
        guard let range = text.range(of: marker), let end = text[range.upperBound...].range(of: "\r\n") else { return false }
        let raw = String(text[range.upperBound..<end.lowerBound])
        guard let id = Int(raw), id > 0, String(id) == raw,
              let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: [key: raw], token: token, boundary: boundary) else { return false }
        return canonical.httpBody == body
    }

    /// HTML/JS external games. Package upload remains monetization=NONE; post-publish monetization & result callbacks use dedicated routes.
    static func admitsExternalGame(method: String, relative: String, request: URLRequest, grant: ReviewedPlayerWriteGrant) -> Bool {
        guard grant.play.paths.isSuperset(of: ReviewedProductionGateLeases.externalGamePaths) else { return false }
        let key = ChinaReviewedRouteCapability.externalGameGrantKey(ChinaReviewedRouteCapability.normalized("/" + relative))
        let folded = key.hasPrefix("/") ? String(key.dropFirst()) : key
        // Paid order creation/confirm is TEST-only behind moneyPayments + ReleaseMoneyWriteSwitch.
        if folded == "api/external-game/orders" || folded == "api/external-game/orders/{}/confirm-test" {
            guard method == "POST",
                  !ReleaseMoneyWriteSwitch.blocks("/" + folded),
                  ReviewedAreaSwitch.moneyPayments(apiHost: request.url?.host),
                  request.value(forHTTPHeaderField: "Content-Type") == "application/json",
                  let body = request.httpBody, !body.isEmpty else { return false }
            return true
        }
        guard ReviewedProductionGateLeases.externalGamePaths.contains(folded) else { return false }
        if method == "GET" {
            return request.httpBody == nil || request.httpBody?.isEmpty == true
        }
        if method == "DELETE" {
            return folded == "api/external-game/nodes/{}/binding"
        }
        if method == "PUT" {
            return (folded == "api/external-game/catalog/{}/monetization" || folded == "api/external-game/nodes/{}/binding")
                && request.value(forHTTPHeaderField: "Content-Type") == "application/json"
                && request.httpBody?.isEmpty == false
        }
        guard method == "POST", let body = request.httpBody, !body.isEmpty else { return false }
        let jsonPostRoutes: Set<String> = [
            "api/external-game/reports",
            "api/external-game/submissions/{}/cancel",
            "api/external-game/sessions/start",
            "api/external-game/sessions/{}/result"
        ]
        if jsonPostRoutes.contains(folded) {
            return request.value(forHTTPHeaderField: "Content-Type") == "application/json"
        }
        let text = String(decoding: body, as: UTF8.self)
        if text.contains("\"price\"") || text.contains("\"iap\"") || text.contains("StoreKit") { return false }
        guard let contentType = request.value(forHTTPHeaderField: "Content-Type"), contentType.hasPrefix("multipart/form-data") else { return false }
        return text.contains("name=\"monetization\"") && text.contains("NONE") && !text.contains("name=\"monetization\"\r\n\r\nPAID")
    }

    /// G3 creator editor GETs and PUTs. Nil leaves the request to the other player-write rules.
    @MainActor static func creatorEditorDecision(_ request: URLRequest, relative: String, method: String,
                                      grant: ReviewedPlayerWriteGrant) -> Bool? {
        let emptyBody = request.httpBody == nil || request.httpBody?.isEmpty == true
        if method == "GET", ReviewedProductionGateLeases.creatorEditorReadPaths.contains(relative) {
            return covers(relative, grant.play) && emptyBody && creatorEditorTopicQuery(request)
        }
        guard method == "PUT" else { return nil }
        if relative == "api/topic/play-setup" { return covers(relative, grant.play) && creatorEditorJSONTopic(request) }
        let prefix = "api/topic/state-keys/"
        if relative.hasPrefix(prefix), ChinaReviewedRouteCapability.isTopicStateKey(String(relative.dropFirst(prefix.count))) {
            return grant.play.paths.contains("api/topic/state-keys/{}") && creatorEditorJSONTopic(request)
        }
        return false
    }

    /// `?topicId=<positive>` with at most a `scope` beside it.
    static func creatorEditorTopicQuery(_ request: URLRequest) -> Bool {
        guard let url = request.url, let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems,
              Set(items.map(\.name)).isSubset(of: ["topicId", "scope"]),
              let topic = items.first(where: { $0.name == "topicId" })?.value, let id = Int64(topic), id > 0 else { return false }
        return true
    }

    /// JSON with a positive `topicId`. A price, channel, or amount field is not this write.
    static func creatorEditorJSONTopic(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json", let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let topic = object["topicId"] as? NSNumber, topic.int64Value > 0 else { return false }
        return ["payChannel", "payAmount", "price", "amount", "maxPerHeadFee"].allSatisfy { object[$0] == nil }
    }

    /// `perspective=PLAYER` exactly once, as `game-session-client.js loadProjection('player')` sends it.
    static func playerPerspective(_ url: URL) -> Bool {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        let values = items.filter { $0.name == "perspective" }.map(\.value)
        return values == ["PLAYER"]
    }

    /// Turning off nearby presence sharing never carries consentVersion or visible=true.
    private static func roamPresenceDisableAllowed(_ request: URLRequest, url: URL, grant: ReviewedPlayerWriteGrant) -> Bool {
        guard request.httpMethod == "POST", url.query == nil, request.httpBodyStream == nil,
              grant.roamExtras.paths.contains("api/roam/session/records"),
              request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/x-www-form-urlencoded") == true,
              let body = request.httpBody, body.count <= 512,
              let text = String(data: body, encoding: .utf8), !text.isEmpty else { return false }
        var parts = URLComponents(); parts.percentEncodedQuery = text
        guard let items = parts.queryItems else { return false }
        let fields = Dictionary(uniqueKeysWithValues: items.compactMap { item in item.value.map { (item.name, $0) } })
        guard fields["visible"] == "false", (fields["consentVersion"] ?? "").isEmpty,
              Set(fields.keys).isSubset(of: ["sessionId", "visible", "consentVersion"]) else { return false }
        return true
    }

    static func coversCapabilityRead(_ relative: String) -> Bool {
        let key = ChinaReviewedRouteCapability.normalized("/" + relative)
        return ReviewedProductionGateLeases.capabilityReadPaths.contains { ChinaReviewedRouteCapability.normalized("/" + $0) == key }
    }

    /// U08-03/U08-04: reads are body-less GETs; the two writes are JSON POSTs with a request id and no money field.
    static func creatorStudioRequest(_ request: URLRequest, relative: String, method: String, grant: OperationEndpointApproval) -> Bool {
        guard covers(relative, grant) else { return false }
        let key = ChinaReviewedRouteCapability.normalized("/" + relative)
        let write = key == "/api/creator/maintenance/tickets/{}/close" || (key == "/api/creator/maintenance/tickets" && method == "POST")
        guard write else { return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true) }
        guard method == "POST", request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let requestID = object["requestId"] as? String, !requestID.isEmpty else { return false }
        return object.keys.allSatisfy { !ReviewedPlayerReadRoute.moneyKeys.contains($0) }
    }

    /// Exact roots from `rewardPledgePaths`, plus their id children. Coupon children stay out.
    static func admitsRewardPledgeWrite(_ relative: String) -> Bool {
        if relative == "api/coupon" { return true }
        if relative.hasPrefix("api/coupon/") { return false }
        if relative == "api/reward-pledge/versions" { return false }
        if relative == "api/rewards/noncash/subjects" || relative == "api/rewards/noncash/versions" { return false }
        if ReviewedProductionGateLeases.rewardPledgePaths.contains(relative) { return true }
        return ReviewedProductionGateLeases.rewardPledgePaths.contains { root in
            root != "api/coupon" && relative.hasPrefix(root + "/")
        }
    }

    /// Nil when the path is not a WP-08 surface. False refuses a payment field or a missing grant.
    static func hostTipSurfaceDecision(method: String, relative: String, request: URLRequest, paths: Set<String>) -> Bool? {
        let key = ChinaReviewedRouteCapability.normalized("/" + relative)
        guard ChinaReviewedRouteCapability.hostTipSurfaceGrant.contains(key) else { return nil }
        guard paths.contains(where: { ChinaReviewedRouteCapability.normalized("/" + $0) == key }) else { return false }
        if method == "GET" { return request.httpBody == nil || request.httpBody?.isEmpty == true }
        guard method == "POST" else { return false }
        if key == "/api/host-tip/intent/{}/cancel" { return true }
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody, !body.isEmpty,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        let money = ["payChannel", "payAmount", "price", "payableAmount", "hostSharePercent"]
        if object.keys.contains(where: { money.contains($0) }) { return false }
        if key != "/api/host-tip/prepare", object["amount"] != nil { return false }
        if (object["status"] as? String) == "APPROVED" { return false }
        return true
    }

    static func covers(_ relative: String, _ approval: OperationEndpointApproval) -> Bool {
        if approval.paths.contains(relative) { return true }
        let key = ChinaReviewedRouteCapability.normalized("/" + relative)
        return approval.paths.contains { ChinaReviewedRouteCapability.normalized("/" + $0) == key }
    }

    /// Group quote and coupon usability only. Create and activate stay false while the commerce gate
    /// or the money switch is off. A card number or a client amount is never this grant.
    static func wp07CommerceAllows(_ request: URLRequest, relative: String, method: String,
                                   baseURL: URL, grant: ReviewedPlayerWriteGrant) -> Bool {
        guard method == "POST", covers(relative, grant.play), request.url?.query == nil else { return false }
        switch relative {
        case "api/marketing/group-checkout/quote":
            return wp07QuoteBody(request)
        case "api/coupon/usability":
            return request.httpBody == nil || request.httpBody?.isEmpty == true
        case "api/marketing/group-checkout/create", "api/marketing/product/activate":
            let open = ReviewedAreaSwitch.moneyPayments(host: baseURL.host)
            return open && wp07WriteBody(request, relative: relative)
        default:
            return false
        }
    }

    /// `{productId, quantity?}`. No price, amount, or card.
    static func wp07QuoteBody(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let product = object["productId"] as? NSNumber, CFGetTypeID(product) != CFBooleanGetTypeID(),
              product.intValue > 0, product.doubleValue == Double(product.intValue) else { return false }
        let allowed: Set<String> = ["productId", "quantity", "isUsePoint", "offerCode", "participateDate"]
        guard Set(object.keys).isSubset(of: allowed) else { return false }
        if let quantity = object["quantity"] {
            guard let number = quantity as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID(),
                  number.doubleValue == Double(number.intValue), (1...100).contains(number.intValue) else { return false }
        }
        return true
    }

    /// Create and activate bodies. No card, no client total. Activate is `{topicId}` only.
    static func wp07WriteBody(_ request: URLRequest, relative: String) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        let banned = ["price", "amount", "payAmount", "catalogCashPrice", "payChannel", "card", "pan", "cvv"]
        guard banned.allSatisfy({ object[$0] == nil }) else { return false }
        if relative == "api/marketing/product/activate" {
            guard Set(object.keys) == ["topicId"], let topic = object["topicId"] as? NSNumber,
                  CFGetTypeID(topic) != CFBooleanGetTypeID(), topic.intValue > 0 else { return false }
            return true
        }
        guard let product = object["productId"] as? NSNumber, product.intValue > 0 else { return false }
        return true
    }

    private struct ThemeReplayBody: Decodable { let sessionId: Int }

    /// OWN-21.1. The preset draft body. A payment field is not this write and is not sent.
    static func gameplayPresetDraftBody(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        return GameplayPresetDraftBody.allows(object)
    }

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

    static func supplyTermsBody(_ request: URLRequest) -> Bool {
        guard let body = request.httpBody, let text = String(data: body, encoding: .utf8),
              let items = URLComponents(string: "?" + text)?.queryItems else { return false }
        let names = Set(items.map(\.name))
        guard names.isSubset(of: ["chapterId", "termsMode", "maxMerchant", "perkMinValue", "scope"]),
              let mode = items.first(where: { $0.name == "termsMode" })?.value else { return false }
        return mode == "PERK" || mode == "TRAFFIC"
    }

    /// fix/1128-cn-pay P0-1: `POST api/registration/create` (backend `RegistrationRequest`, JSON body).
    /// A free create carries no channel. A paid create carries `payChannel` = `APP` (WeChat APP prepay, backend
    /// `RegistrationCheckoutServiceImpl.isAppChannel`) and is admitted only while the payment switch is on.
    /// Any other channel (MP JSAPI, XPAY) and any client-side amount stay refused: the server prices from `quoteSign`.
    static func registrationCreateBody(_ request: URLRequest, paymentsOpen: Bool) -> Bool {
        guard let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        for key in ["payAmount", "price", "amount", "payableAmount"] where object[key] != nil {
            guard let number = object[key] as? NSNumber, number.doubleValue <= 0 || paymentsOpen else { return false }
        }
        guard let channel = object["payChannel"] else { return true }
        return paymentsOpen && (channel as? String) == "APP"
    }

    static func stableCommunityRequestID(_ request: URLRequest) -> Bool {
        guard let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        for key in ["requestId", "clientRequestId", "uploadRequestId", "request_id"] {
            if let value = object[key] as? String, !value.isEmpty { return true }
        }
        return false
    }

    /// Gap #17: the bodies `OfficialActionService.request` sends for the player participation routes. Nil when `relative`
    /// is not one of them. Signup / complete / organizer replies carry no body (or `{reason}`), a party reply `{}` or
    /// `{reason}`, an arrival exactly the `OfficialArrivalEvidence` keys.
    static func officialParticipationDecision(_ request: URLRequest, relative: String, method: String, url: URL) -> Bool? {
        let template = OfficialActionProductionApproval.template(relative)
        guard OfficialActionProductionApproval.playerTargetPaths.contains(template),
              ["signup", "complete", "arrivals", "ACCEPT", "DECLINE", "WITHDRAW", "accept", "decline"].contains(where: { template.hasSuffix("/" + $0) }) else { return nil }
        guard method == "POST", url.query == nil, request.httpBodyStream == nil else { return false }
        let body = request.httpBody ?? Data()
        if body.isEmpty { return !template.hasSuffix("/arrivals") }
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json", body.count <= 1024,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] else { return false }
        if template.hasSuffix("/arrivals") {
            return Set(object.keys) == ["missionCode", "latitude", "longitude", "accuracyM", "sessionId", "requestId"]
        }
        if template.hasSuffix("/signup") || template.hasSuffix("/complete") { return false }
        return object.isEmpty || (Set(object.keys) == ["reason"] && object["reason"] is String)
    }

    /// `RegistrationWaitlistService` body: exactly two positive JSON integers `activityId` and `ticketId`.
    static func waitlistScopeBody(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json", let body = request.httpBody, body.count <= 128,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any], Set(object.keys) == ["activityId", "ticketId"],
              let activity = object["activityId"] as? NSNumber, let ticket = object["ticketId"] as? NSNumber,
              CFGetTypeID(activity as CFTypeRef) != CFBooleanGetTypeID(), CFGetTypeID(ticket as CFTypeRef) != CFBooleanGetTypeID(),
              activity.intValue > 0, ticket.intValue > 0,
              activity.doubleValue == Double(activity.intValue), ticket.doubleValue == Double(ticket.intValue) else { return false }
        return true
    }

    static func teamRequestID(_ request: URLRequest) -> Bool {
        guard let body = request.httpBody,
              let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
              let value = object["requestId"] as? String, value.count == 32,
              value.allSatisfy({ ("0"..."9").contains($0) || ("a"..."f").contains($0) }) else { return false }
        return true
    }

    /// `POST api/team/create` body from `TeamWriteContract`: ownerType 2, ownerId, maxMembers, optional joinMode 1.
    static func teamCreateBody(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody else { return false }
        return TeamCreateWriteBody.accepts(body)
    }

    /// TEAM backpack commands only: ITEM_USE, ITEM_DISCARD, ITEM_RECEIVE.
    static func teamItemCommandBody(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let body = request.httpBody else { return false }
        return PlayTeamItemCommandBody.accepts(body)
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

/// Owner approval 2026-11-12 (E2E-20261112 F4/F5 and the live-route sweep): signed-in player reads that
/// `ChinaReviewedRouteCapability` marks live but the shipped China composition had no admission for. Exact paths only; each
/// still has to be a live, wired, non-money production route. Bodies are the flat shapes the read services send: none, a
/// JSON object, a canonical multipart form, or a URL-encoded form. Nested values and money fields are not a read.
/// `api/club/members` (polish-d-r1, TEST 2026-11-16): the members screen reads detail then members with the same session;
/// without this entry the composition refused the second read (`notConfigured`) and 查看成员 always showed 俱乐部加载失败.
enum ReviewedPlayerReadRoute {
    // player-read-paths-begin
    static let paths: Set<String> = [
        "api/club/home", "api/club/my", "api/club/detail", "api/club/members", "api/club/access/me", "api/coop/list", "api/user/info", "api/project/my",
        "api/config/features", "api/medal/wall", "api/badge/wall-v2", "api/growth/leaderboard",
        "api/object-card/list", "api/registration/my-joined", "api/registration/info", "api/play/my-completed", "api/registration/quote",
        // R11-MEM-17-1: MP scene-member-order-detail/index.js:833-835 reads 探店图鉴/通关奖励 for a paid explore order.
        "api/registration/explore-completion"
    ]
    // player-read-paths-end
    static let moneyKeys: Set<String> = ["payAmount", "payChannel", "amount", "price", "payableAmount"]

    static func accepts(_ request: URLRequest, baseURL: URL, token: String?) -> Bool {
        guard let token, AuthRequestBuilder.isValidToken(token),
              request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Authorization")?.utf8.elementsEqual(token.utf8) == true,
              request.value(forHTTPHeaderField: "Cookie") == nil,
              request.value(forHTTPHeaderField: "Proxy-Authorization") == nil,
              let url = request.url, url.query == nil, url.fragment == nil, url.user == nil, url.password == nil,
              url.scheme == baseURL.scheme, url.host == baseURL.host, url.port == baseURL.port else { return false }
        let relative = ReviewedProductionFormMutationRoute.relativePath(url, baseURL: baseURL)
        guard paths.contains(relative), ChinaReviewedRouteCapability.mark(for: "/" + relative) == .liveInProduction,
              ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + relative) else { return false }
        let body = request.httpBody ?? Data()
        guard body.count <= 4096, let fields = flatFields(body, type: request.value(forHTTPHeaderField: "Content-Type")) else { return false }
        // E2E R11: a player's own projects; the MERCHANT-scoped list stays with the merchant route.
        if relative == "api/project/my", String(decoding: body, as: UTF8.self).contains("MERCHANT") { return false }
        return fields.allSatisfy { !moneyKeys.contains($0) }
    }

    /// Field names of a flat read body, or nil when the body is not one of the read shapes.
    private static func flatFields(_ body: Data, type: String?) -> [String]? {
        guard let type else { return body.isEmpty ? [] : nil }
        if type == "application/json" {
            guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
                  object.values.allSatisfy({ $0 is String || $0 is NSNumber }) else { return nil }
            return Array(object.keys)
        }
        if type.hasPrefix("application/x-www-form-urlencoded") {
            guard let text = String(data: body, encoding: .utf8) else { return nil }
            if text.isEmpty { return [] }
            var parts = URLComponents(); parts.percentEncodedQuery = text
            guard let items = parts.queryItems, Set(items.map(\.name)).count == items.count else { return nil }
            return items.map(\.name)
        }
        let prefix = "multipart/form-data; boundary="
        guard type.hasPrefix(prefix), let text = String(data: body, encoding: .utf8) else { return nil }
        let boundary = String(type.dropFirst(prefix.count))
        let terminator = "--\(boundary)--\r\n"
        guard !boundary.isEmpty, text.hasSuffix(terminator) else { return nil }
        let parts = String(text.dropLast(terminator.count)).components(separatedBy: "--\(boundary)\r\n")
        guard parts.first == "" else { return nil }
        var fields: [String: String] = [:]
        let header = "Content-Disposition: form-data; name=\""
        for part in parts.dropFirst() {
            guard part.hasPrefix(header), part.hasSuffix("\r\n"), let separator = part.range(of: "\"\r\n\r\n") else { return nil }
            let name = String(part[part.index(part.startIndex, offsetBy: header.count)..<separator.lowerBound])
            guard !name.isEmpty, fields[name] == nil else { return nil }
            fields[name] = String(part[separator.upperBound...].dropLast("\r\n".count))
        }
        return Array(fields.keys)
    }
}

@MainActor final class ReviewedProductionGateLeases {
    private var walletHistoryByContext: [String: WalletHistoryReadApproval] = [:]
    private var messagingHistoryByContext: [String: MessagingHistoryReadApproval] = [:]
    private var ownedOrderByContext: [String: OwnedOrderReadApproval] = [:]
    private var exploreCompletionByContext: [String: ExploreCompletionReadApproval] = [:]
    private var profileOwnedCouponByContext: [String: ProfileOwnedCouponReadAccess] = [:]
    private var profileFavoritesByContext: [String: ProfileFavoritesReadAccess] = [:]
    private var profileInviteHistoryByContext: [String: ProfileInviteHistoryReadAccess] = [:]
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
    private var roamEntryNearbyByContext: [String: RoamEntryNearbyReadAccess] = [:]
    private var roamNearbyPlayersByContext: [String: RoamNearbyPlayersReadAccess] = [:]
    private var roamNearbyEventsByContext: [String: RoamNearbyEventsReadAccess] = [:]
    private var roamReceivedStampByContext: [String: RoamReceivedStampReadAccess] = [:]
    private var roamAlbumMetadataByContext: [String: RoamAlbumMetadataReadAccess] = [:]
    private var roamTileMemoryByContext: [String: RoamTileMemoryReadAccess] = [:]
    private var roamSessionFactByContext: [String: RoamSessionFactReadAccess] = [:]
    private var teamReadByContext: [String: TeamReadApproval] = [:]
    private var growthNormalReadByContext: [String: GrowthNormalReadApproval] = [:]
    private var nearbyTeamReadByContext: [String: OperationEndpointApproval] = [:]
    private var merchantOperationsWriteByContext: [String: OperationEndpointApproval] = [:]
    private var nearbyTeamWriteByContext: [String: OperationEndpointApproval] = [:]
    private var teamMembershipWriteByContext: [String: OperationEndpointApproval] = [:]
    private var cityVoucherIssueByContext: [String: VerificationCodeApproval] = [:]
    private var playerWritesEnabled = false
    private var playerWritersByContext: [String: ReviewedPlayerWriteGrant] = [:]
    private var playConfigurationByContext: [String: RuntimeDependencyConfiguration] = [:]
    private var cityGameByContext: [String: CityGameCapabilityLease] = [:]
    private var clubPublicTopicsByKey: [ClubPublicTopicsKey: ClubPublicTopicsApproval] = [:]
    private struct ClubPublicTopicsKey: Hashable { let context: ClubPublicTopicsContext; let clubID: Int }
    /// E2E-20261113: a club's public activities/topics are a read for any China viewer once the reviewed player grant is on.
    /// The approval is cached per viewer context and club so the transport's equality fence stays stable.
    func clubPublicTopics(_ context: ClubPublicTopicsContext, clubID: Int) -> ClubPublicTopicsApproval? {
        guard playerWritesEnabled, clubID > 0 else { return nil }
        let key = ClubPublicTopicsKey(context: context, clubID: clubID)
        if let existing = clubPublicTopicsByKey[key] { return existing }
        let issued = ClubPublicTopicsApproval(context: context, clubID: clubID, revision: UUID())
        clubPublicTopicsByKey[key] = issued
        return issued
    }
    private var socialWritersByContext: [String: ReviewedSocialWriteGrant] = [:]
    private var blacklistByContext: [String: NativeBlacklistApproval] = [:]
    private var clubCommunityReadByContext: [String: ClubCommunityReadApproval] = [:]
    private var imPreviewLeaseByKey: [String: IMPreviewTemplateLease] = [:]
    private var workshopPurchasedByContext: [String: WorkshopPurchasedReadApproval] = [:]
    private var friendChannelInviteByKey: [String: NativeFriendChannelInviteApproval] = [:]
    private var friendTeamInviteByKey: [String: NativeFriendTeamInviteApproval] = [:]
    private var friendChannelSourceByKey: [String: NativeFriendChannelSourceApproval] = [:]
    private var channelManagementByKey: [String: NativeChannelManagementApproval] = [:]

    // player-write-paths-begin
    static let imPaths: Set<String> = ["api/im/send", "api/im/send-receipt"]
    static let clubCommunityPaths: Set<String> = [
        "api/club/post/create", "api/club/post/update", "api/club/post/like", "api/club/post/report",
        "api/club/post/delete", "api/club/post/pin", "api/club/post/comment/create", "api/club/post/comment/delete",
        "api/club/post/comment/report", "api/club/post/repost", "api/club/post/repost/undo", "api/club/chat"
    ]
    static let squarePaths: Set<String> = [
        "api/v1/community/guidelines/active", "api/v1/community/guidelines/ack", "api/v1/community/media/register",
        "api/v1/community/drafts", "api/v1/community/posts", "api/v1/community/reports", "api/v1/community/appeals",
        "api/v1/community/capabilities"
    ]
    static let profilePaths: Set<String> = ["api/user/update", "api/common/uploadOSS"]
    static let registrationPaths: Set<String> = ["api/registration/create"]
    static let teamCommandPaths: Set<String> = ["api/team/command", "api/team/command/query", "api/team/command/cancel"]
    /// `POST api/team/create` for an owned activity registration. Not a command receipt.
    static let teamCreatePaths: Set<String> = ["api/team/create"]
    /// HANDOVER 37 WP-08. Same paths as `ChinaReviewedRouteCapability.hostTipSurfaceGrant`.
    /// Host-tip prepare may name an amount. It does not name a pay channel, and it is not a payout.
    static let wp08Paths: Set<String> = Set(ChinaReviewedRouteCapability.hostTipSurfaceGrant.map { String($0.dropFirst()) })
    static let playPaths: Set<String> = Set<String>([
        "api/play/arrive", "api/play/answer", "api/play/checkin", "api/play/photo", "api/play/sensor-result",
        "api/play/puzzle/reveal", "api/play/action-context", "api/play/action-receipt", "api/play/help",
        "api/play/help/use", "api/play/help/skip", "api/play/help/receipt", "api/play/help/advanced/receipt", "api/play/advanced/start", "api/play/advanced/action",
        "api/topic/chapter/finish", "api/play/run-session", "api/play/run-session/save", "api/play/journey/opening/complete",
        "api/play/orient/session", "api/play/orient/session/start", "api/play/orient/session/abandon",
        "api/play/orient/session/prepare", "api/play/orient/session/receipt",
        "api/play/orient/session/task/{}/result", "api/play/scan-entry", "api/play/nodes", "api/play/route-state",
        "api/play/theme/replay", "api/play/feedback/submit",
        // G2 (owner-approved 2026-11-13): invoices are tax documents, not payments. Reads and the
        // requestId-receipted non-money writes the mini-program's subpackageMember/invoice* pages send.
        "api/invoice/list", "api/invoice/detail", "api/invoice/orders/eligible", "api/invoice/apply",
        "api/invoice/request", "api/invoice/cancel", "api/invoice/titles", "api/invoice/titles/save",
        "api/invoice/titles/save-request", "api/invoice/titles/request", "api/invoice/titles/delete",
        "api/order-center/detail",
        // G3: creator topic editor (pages/publish/fabu, pages/member, the host workbench QR and PERK/TRAFFIC terms).
        "api/topic/attribute-binding", "api/topic/author-edit-detail", "api/topic/author-saved-detail",
        "api/topic/play-setup", "api/topic/publish-draft", "api/topic/share-code", "api/topic/state-keys",
        "api/topic/state-keys/named", "api/topic/state-keys/{}", "api/topic/invite-chapters",
        "api/topic/chapter/supply-terms", "api/topic/host-qrcode",
        // G4/G5 (capability-graph section 1): community trust, roam extras, templates, map/search, bundle swap.
        "api/community-trust/contributions/submit", "api/community-trust/safety/ratings", "api/community-trust/reports/appeal",
        "api/roam/session/records", "api/roam/share/revoke", "api/roam/shop/visitors",
        "api/template/adopt-draft", "api/template/author-info", "api/template/author-myinfo",
        "api/template/topic-template/binding", "api/template/topic-template/binding-status",
        "api/template/topic-template/save-as", "api/template/{}/market-submit",
        "api/map/geocode", "api/map/place-search", "api/search/unified", "api/free-explore/bundle/exit-decision",
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
        // `circle-theme/instance/configure` is granted below (parity-b) for the personal host only (scope "").
        "api/circle-theme/instance/{}/offers", "api/circle-theme/session", "api/circle-theme/session/join",
        "api/circle-theme/session/{}/card",
        // Owner approval 2026-11-13: the player TEAM backpack command (mini-program game-session-client.js:395,
        // theme-backpack.js:494). Non-money; the server checks the run, team and perspective.
        "api/game/session/command",
        // parity-b (PlayerGapService.parityBPaths): organiser shared-run control/export/anchor, the lead's group
        // member ticket scan and its seat receipt, editor orient alternatives with their author readback,
        // the circle host's project read + instance configure, and the analytics batch. No money path.
        "api/game/session/shared/control", "api/game/session/shared/export", "api/game/session/shared/export/anchor",
        "api/registration/scan_group_member_ticket", "api/verify/seat/receipt",
        "api/orient/task/alternative", "api/topic/author-saved-detail",
        "api/circle-theme/instance/configure", "api/project/home", "api/analytics/events/batch",
        // G6 (owner-approved): AI theme draft V2 prepare/execute with its journal and recovery list.
        "api/ai/theme/draft/prepare", "api/ai/theme/draft/execute",
        // Handover 18 external games. Monetization NONE. Append-only.
        "api/external-game/submissions", "api/external-game/submissions/mine", "api/external-game/submissions/{}",
        "api/external-game/submissions/{}/cancel", "api/external-game/submissions/{}/resubmit",
        "api/external-game/catalog", "api/external-game/catalog/{}", "api/external-game/catalog/{}/package",
        "api/external-game/signing-key", "api/external-game/reports",
        // WP-04: invite read receipts and the author's own square post. Not money and not api/merchant.
        "api/coop/invite/read",
        "api/coop/invite/request",
        "api/coop/invite/requests",
        "api/coop/supply-stations",
        "api/creativesquare/delete",
        // OWN-21.1 / OWN-21.2. Preset list and info are reads. Draft is a personal template id, not a payment.
        "api/preset/gameplay/list", "api/preset/gameplay/info", "api/preset/gameplay/draft",
        // WP-02 (PlayerGapService.creatorTailPaths): the author's own audit timeline, content appeal and its receipt,
        // and the original-run guard reference, appeal and receipt. Non-money; the server checks the author/run owner.
        "api/audit/timeline", "api/audit/appeal", "api/audit/appeal/receipt",
        "api/audit/guard/reference", "api/audit/guard/appeal", "api/audit/guard/appeal/receipt",
        // Final sweep: non-money creator project list mutations (`api/activity/cancel` stays behind ReviewedAreaSwitch.moneyPayments).
        "api/activity/update_publish_status", "api/topic/update_user_status",
        "api/activity/delete", "api/topic/delete", "api/template/delete", "api/template/updateLibraryStatus",
        // Popup parity closure: beta topic graduation, club transfer, and attendance commands (non-money).
        "api/topic/beta/graduate", "api/topic/transfer-to-club", "api/club/my",
        // C-F6 MP-first: the author's 到访方式 read/save (fabu/theme-fe-visit.js:40, :87). Not money.
        "api/topic/free-explore/visit-config"
    ]).union(capabilityReadPaths).union(playRuntimeReadPaths).union(wp07CommercePaths).union(wp08Paths).union(publisherLifecyclePaths)
        .union(playFinishAndProfilePaths).union(clubLeadWritePaths)
    /// MP-first (owner 2026-11-25, R7-PC-B4-1 / R7-PC-B1-2): pages/topic/pricing preview + confirm (a final-price save that moves
    /// the topic to PRICING for sale review, not a payment) and the publisher reads it needs. Cancel-with-refund stays off.
    static let publisherLifecyclePaths: Set<String> = [
        "api/topic/pricing/preview", "api/topic/pricing/confirm", "api/topic/xp-budget",
        "api/topic/cancel_preview", "api/activity/cancel_preview", "api/club/detail"
    ]
    /// A play-grant path, templated segments normalized. The composition lets such a GET carry its query (G1/G7/G8/parity-b
    /// reads such as `team/trail/state?activityId=`); the lease still checks method, body and grant.
    static func isPlayGrantPath(_ relative: String) -> Bool {
        if playPaths.contains(relative) { return true }
        let key = ChinaReviewedRouteCapability.normalized("/" + relative)
        return playPaths.contains { ChinaReviewedRouteCapability.normalized("/" + $0) == key }
    }
    /// G4/G5 GET reads. The play grant admits a GET only for these (body empty).
    nonisolated static let capabilityReadPaths: Set<String> = [
        "api/community-trust/contributions/taxonomy", "api/community-trust/safety/taxonomy",
        "api/community-trust/safety/merchants/{}", "api/template/adoption-source", "api/template/adoption-receipt",
        "api/template/adoption-detail", "api/map/weather", "api/search/unified", "api/free-explore/bundle/exit-options",
        "api/free-explore/bundle/order/receipt",
        // G6 player reads on the same reviewed gate. Money, attribution, and order reads are not here.
        "api/ai/npc/profile", "api/ai/npc/event", "api/ai/theme/draft/recovery",
        "api/marketing/promotions/catalog", "api/marketing/revenue/author/mine", "api/marketing/product/{}"
    ]
    /// G1 play runtime GET reads. Host control/export and circle instance configure are not here.
    static let playRuntimeReadPaths: Set<String> = [
        "api/play/encounter", "api/play/check/receipt", "api/play/advanced/receipt", "api/play/history",
        "api/play/setup", "api/play/contact",
        // g-partials: TEAM backpack projection, `perspective=PLAYER` only (see `playerPerspective`).
        "api/game/session/view",
        // cur-team-u0802: the TEAM command receipt re-read.
        "api/game/session/receipt",
        // E2E-20261113b (coordinator): the paused-run read restoreRun needs before Start can run.
        "api/play/run-session",
        // Popup parity closure: player & organizer event attendance readback.
        "api/official/events/{}/attendance", "api/official/events/{}/attendance/manage",
        // mp-club r3 J-15: the club topic director's session recap export (`PlayDirectorRecap`, GET `activityId`, no body).
        // A read; the server checks that the caller directs the activity (BE ApiGameSessionController.java:83).
        "api/game/session/recap/export",
        // mp-club r3 J-18 / P2-4: the club-lead bar's team read and the chapter-release receipt re-read (MP pages/play/index.js:5604,5881).
        "api/club/lead/team-progress", "api/club/lead/unlock-chapter-receipt"
    ]
    /// mp-club r3 J-18 / P2-4: the club-lead tools the MP play page sends (pages/play/index.js:5741,5845,5882,5966; topic-detail
    /// index.js:530). The server admits only the activity's lead (BE ApiClubLeadController). `settle` (全团结算, ticket
    /// redemption into settlement) is admitted only where `moneyPayments` opens; see `clubLeadSettlePath`.
    static let clubLeadWritePaths: Set<String> = [
        "api/club/lead/start", "api/club/lead/unlock-chapter", "api/club/lead/release-station", "api/club/lead/edit-ops",
        "api/club/lead/settle"
    ]
    static let clubLeadSettlePath = "api/club/lead/settle"
    nonisolated static let externalGamePaths: Set<String> = [
        "api/external-game/submissions", "api/external-game/submissions/mine", "api/external-game/submissions/{}",
        "api/external-game/submissions/{}/cancel", "api/external-game/submissions/{}/resubmit",
        "api/external-game/catalog", "api/external-game/catalog/{}", "api/external-game/catalog/{}/package",
        "api/external-game/catalog/{}/monetization", "api/external-game/creator/summary",
        "api/external-game/entitlements/mine", "api/external-game/nodes/{}/binding",
        "api/external-game/sessions/start", "api/external-game/sessions/{}/result",
        "api/external-game/signing-key", "api/external-game/reports"
    ]
    /// G2 invoice writes. A grant without every one of them leaves the invoice write entries hidden.
    static let invoiceWritePaths: Set<String> = [
        "api/invoice/apply", "api/invoice/request", "api/invoice/cancel", "api/invoice/titles/save",
        "api/invoice/titles/save-request", "api/invoice/titles/request", "api/invoice/titles/delete"
    ]
    /// G3 reads the editor sends as GET with a `topicId`/`scope` query and no body.
    static let creatorEditorReadPaths: Set<String> = ["api/topic/attribute-binding", "api/topic/play-setup", "api/topic/state-keys"]
    static let roamExtraPaths: Set<String> = [
        "api/roam/checkin", "api/roam/stamp/create", "api/roam/stamp/exchange", "api/roam/finish",
        "api/roam/shop/visit", "api/roam/poi/discover", "api/roam/reveal",
        "api/roam/passport/record", "api/city/nodes/{}/favorite", "api/city/nodes/{}/complete"
    ]
    /// H1 template adoption: copy, place to-do status and binding are form POSTs; image credit is one GET.
    static let templateAdoptionPaths: Set<String> = [
        "api/template/topic-template/use", "api/template/topic-template/binding-status",
        "api/template/topic-template/binding", "api/media/asset/attribution"
    ]
    static let likePaths: Set<String> = ["api/topic/like", "api/comment/like", "api/creativesquare/like"]
    static let reportPaths: Set<String> = [
        "api/v1/community/reports", "api/v1/community/appeals", "api/comment/report", "api/topic/report",
        "api/template/report", "api/template/personal-report", "api/creativesquare/report", "api/im/report",
        "api/club/post/report", "api/club/post/comment/report", "api/club/governance/cases/report",
        "api/club/governance/cases/appeal", "api/orient/scoring/appeal", "api/orient/scoring/dispute",
        "api/external-game/reports", "api/merchant/reviews/report", "api/team/report",
        "api/community-trust/reports/taxonomy", "api/community-trust/reports/mine",
        "api/native/blacklist/list",
        "api/ai/safety/precheck"
    ]
    /// Space admission (contract §6.10). Approve/reject/pause/revoke are owner/admin writes the backend checks.
    static let admissionPaths: Set<String> = [
        "api/join-request/submit", "api/join-request/cancel", "api/join-request/approve", "api/join-request/reject",
        "api/space/leave", "api/space/join-pause", "api/invite/revoke", "api/channel-platform/admission/requests/{}"
    ]
    /// Team shared resource pool (contract §4). Hints and skips spend the team's pool, never points or money.
    static let teamPoolPaths: Set<String> = [
        "api/team/pool", "api/team/pool/hint", "api/team/pool/skip", "api/team/pool/timer/start", "api/team/pool/requests/{}"
    ]
    /// U08-03 creator feedback and maintenance tickets, U08-04 creator post-game outcome (owner approval,
    /// backend-app-r2). Carried on the play grant; author-only reads and two ticket writes, no money.
    static let creatorStudioPaths: Set<String> = [
        "api/creator/feedback", "api/creator/maintenance/tickets", "api/creator/maintenance/tickets/{}",
        "api/creator/maintenance/tickets/{}/close", "api/creator/maintenance/requests/{}",
        "api/creator/analytics/post-game-outcome"
    ]
    /// HANDOVER 36, WP-07. Quote and coupon usability are reads. Create and activate stay closed
    /// unless purchases and money payments are both on, and even then the body cannot carry a card or an amount.
    static let wp07CommercePaths: Set<String> = [
        "api/marketing/group-checkout/quote",
        "api/marketing/group-checkout/create",
        "api/marketing/product/activate",
        "api/coupon/usability"
    ]
    /// fix-1128b: `.mediaUpload` (#5, play photo upload), `.preference` and `.tags` (#19, preference groups and tag
    /// confirm/correct/revoke) join the release play grant. mp-club r3 J-18: `.leader` joins for the club-lead tools; `.circle` stays with its lane.
    static let playCapabilities: Set<PlayExperienceCapability> = [
        .reads, .classicCompletion, .hints, .advanced, .playerCommands, .runPersistence, .journeyOpening, .actionContextBinding,
        .mediaUpload, .preference, .tags, .leader
    ]
    /// fix-1128b #19: `api/play/tag/{id}/confirm` and `/revoke`, the two bodiless tag writes.
    static func isBodilessPlayTagWrite(_ relative: String) -> Bool {
        let key = ChinaReviewedRouteCapability.normalized("/" + relative)
        return key == "/api/play/tag/{}/confirm" || key == "/api/play/tag/{}/revoke"
    }
    /// fix-1128b #5: the device kinds a play node may ask for (MP vm 2 photo, vm 4 scan, GPS arrive, shake).
    static let playDevices: Set<PlayDeviceKind> = [.photo, .scan, .location, .motion]
    /// fix-1128b #22: bare hosts (what `PlayKitCameraAssets.approvedURL` compares) of the approved upload-result origins.
    /// An origin with a non-443 port is dropped because kit artwork only loads from the default https port.
    static func playArtworkHosts(apiBase: URL, extra: String? = Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String) -> Set<String> {
        let origins = RetainedImageOrigin.configured(apiBase: apiBase, extra: extra)
        return Set(origins.compactMap { origin -> String? in
            guard let url = URL(string: origin), url.port == nil || url.port == 443, let host = url.host, !host.isEmpty else { return nil }
            return host.lowercased()
        })
    }
    /// fix-1128b #16, #19, #21, #5: the finish ending/ranking reads, the templated preference/tag/人生 OS routes, the
    /// in-store consent read/write, and the play photo upload. All non-money player routes the MP sends.
    static let playFinishAndProfilePaths: Set<String> = [
        "api/play/ending", "api/play/leaderboard",
        "api/play/preference/{}", "api/play/preference/{}/submit",
        "api/play/tag/{}/confirm", "api/play/tag/{}/correct", "api/play/tag/{}/revoke", "api/play/os/{}",
        "api/compliance/consents", "api/compliance/consents/latest",
        "api/common/uploadOSS",
        // mp-journey r3 (plan audit J-09a / J-10b): the stop hint ladder (MP pages/play/index.js useHint → puzzle/hint
        // {session, nodeId, level}) and the points hint unlock after the 解锁提示 confirm (unlockHint → hint/unlock
        // {session, nodeId}). Points, not money; the server checks the run.
        "api/play/puzzle/hint", "api/play/hint/unlock"
    ]
    /// Handover 35, WP-06. Same paths as `ChinaReviewedRouteCapability.wp06PartialPagesOwnerGrant`.
    /// Address, invoice, roam, and passport calls stay on their dedicated transports: this set does not
    /// let the generic root send them. The history share read stays on its existing reader (BK E06-17),
    /// so this file does not name that path. Complaint report is the one new generic admit. Coupon publish and
    /// stop are money-adjacent and stay closed unless `ReviewedAreaSwitch.merchantWrites` is open.
    static let wp06PartialPagePaths: Set<String> = [
        "api/user/address/list", "api/user/address/info", "api/user/address/action",
        "api/user/address/delete", "api/user/address/setDefault",
        "api/publish/home", "api/ai/theme/draft/quota",
        "api/coop/complaint/topics", "api/coop/complaint/mine", "api/coop/complaint/report",
        "api/coupon/mypublishlist", "api/coupon/publish", "api/coupon/stop",
        "api/invoice/list", "api/invoice/detail", "api/invoice/orders/eligible", "api/invoice/titles",
        "api/invoice/apply", "api/invoice/request",
        "api/exploration-anniversary", "api/monthly-recap",
        "api/personal-exploration-export/prepare", "api/personal-exploration-export/page",
        "api/roam/passport/history", "api/roam/stamp/create", "api/roam/stamp/exchange",
        "api/common/uploadOSS"
    ]
    static let wp06MoneyPaths: Set<String> = ["api/coupon/publish", "api/coupon/stop"]
    /// Nil leaves the request to the other player-write rules. False refuses it.
    /// Address and the other dedicated reads return nil so the generic root still cannot borrow them.
    static func wp06PartialPageDecision(method: String, relative: String, request: URLRequest, url: URL) -> Bool? {
        guard wp06PartialPagePaths.contains(relative) else { return nil }
        if wp06MoneyPaths.contains(relative) {
            guard ReviewedAreaSwitch.merchantWrites(apiHost: url.host) else { return false }
            guard method == "POST",
                  request.value(forHTTPHeaderField: "Content-Type") == "application/json",
                  let body = request.httpBody, !body.isEmpty,
                  (try? JSONSerialization.jsonObject(with: body)) is [String: Any] else { return false }
            return true
        }
        if relative == "api/coop/complaint/report" {
            guard method == "POST", let body = request.httpBody, !body.isEmpty else { return false }
            return true
        }
        return nil
    }
    /// Handover 21. Non-cash pledge, claim and the exact coupon root. Cash refund is not in this set.
    nonisolated static let rewardPledgePaths: Set<String> = [
        "api/reward-pledge", "api/reward-pledge/awards", "api/reward-pledge/drafts",
        "api/reward-pledge/fulfilment/awards", "api/reward-pledge/fulfilment/expire",
        "api/reward-pledge/fulfilment/preview", "api/reward-pledge/fulfilment/redeem",
        "api/reward-pledge/fulfilment/resolve", "api/reward-pledge/ops", "api/reward-pledge/pledges",
        "api/reward-pledge/review",
        "api/rewards/noncash", "api/rewards/noncash/cases", "api/rewards/noncash/claims",
        "api/rewards/noncash/claims/recover",
        "api/coupon"
    ]
    // player-write-paths-end

    func notePlayerWrites(_ enabled: Bool) { playerWritesEnabled = enabled }

    /// CITY board lease: owner-approved non-money player writes, China production host, and a
    /// build-configured region. Reissued when the hour-long approvals lapse or the session changes.
    func cityGame(_ context: RuntimeDependencyContext, region: String? = ReviewedProductionGateLeases.cityGameRegion) -> CityGameCapabilityLease? {
        guard playerWritesEnabled, context.role == "player" || context.role == "club",
              let lease = Self.cityGameLease(context: context, region: region) else { return nil }
        let key = contextKey(context)
        if let existing = cityGameByContext[key], existing.lease == lease, existing.matches(context) { return existing }
        cityGameByContext[key]?.revoke()
        cityGameByContext[key] = nil
        guard let issued = CityGameCapabilityLease(context: context, lease: lease) else { return nil }
        cityGameByContext[key] = issued
        return issued
    }

    private var invoiceByContext: [String: InvoiceLaunchReadApproval] = [:]
    /// G2. The invoice reader for a granted player, cached per context so its revision stays stable.
    /// Apply and title saves read their original receipts (`request`, `titles/request`); delete and
    /// cancel use the legacy routes the mini-program sends, so the #725 command receipts stay off.
    func playerInvoiceApproval(_ context: RuntimeDependencyContext) -> InvoiceLaunchReadApproval? {
        guard let grant = playerWriters(context), grant.play.paths.isSuperset(of: Self.invoiceReadPaths) else { return nil }
        let key = contextKey(context)
        if let existing = invoiceByContext[key], existing.matches(context) { return existing }
        guard let approval = try? InvoiceLaunchReadApproval(context: context, originalReceipts: true, commandReceiptRead: false) else { return nil }
        invoiceByContext[key] = approval
        return approval
    }
    static let invoiceReadPaths: Set<String> = ["api/invoice/list", "api/invoice/detail", "api/invoice/orders/eligible", "api/invoice/titles"]
    static func grantsInvoiceWrites(_ grant: ReviewedPlayerWriteGrant) -> Bool {
        grant.play.paths.isSuperset(of: invoiceWritePaths)
    }

    func playerWriters(_ context: RuntimeDependencyContext) -> ReviewedPlayerWriteGrant? {
        guard playerWritesEnabled, context.market == .china, context.role == "player" || context.role == "club" else { return nil }
        let key = contextKey(context)
        if let existing = playerWritersByContext[key], Self.isLive(existing) { return existing }
        guard let grant = makePlayerGrant(context) else { return nil }
        playerWritersByContext[key] = grant
        return grant
    }

    /// E2E-20261112 F4: the channel-text and friend leases expire after an hour. A session signed in for longer must get a
    /// fresh grant for the same context instead of a cached, expired one that refuses every `api/im/send`.
    private static func isLive(_ grant: ReviewedPlayerWriteGrant, now: Date = Date()) -> Bool {
        !grant.channelTextSend.isRevoked && !grant.channelTextReceipt.isRevoked
            && now < grant.channelTextSend.expiresAt && now < grant.channelTextReceipt.expiresAt && now < grant.friends.expiresAt
    }

    private func makePlayerGrant(_ context: RuntimeDependencyContext) -> ReviewedPlayerWriteGrant? {
        let expires = Date().addingTimeInterval(3600)
        guard let im = makeEndpoint(context, paths: Self.imPaths),
              let clubCommunity = makeEndpoint(context, paths: Self.clubCommunityPaths),
              let square = makeEndpoint(context, paths: Self.squarePaths),
              let profile = makeEndpoint(context, paths: Self.profilePaths),
              let registration = makeEndpoint(context, paths: Self.registrationPaths),
              let team = makeEndpoint(context, paths: Self.teamCommandPaths.union(Self.teamCreatePaths)),
              let play = makeEndpoint(context, paths: Self.playPaths.union(Self.creatorStudioPaths)),
              let roamExtras = makeEndpoint(context, paths: Self.roamExtraPaths),
              let likes = makeEndpoint(context, paths: Self.likePaths),
              let reports = makeEndpoint(context, paths: Self.reportPaths),
              let templateAdoption = makeEndpoint(context, paths: Self.templateAdoptionPaths),
              let friendEndpoints = makeEndpoint(context, paths: NativeFriendApproval.readPaths.union(NativeFriendApproval.writePaths)),
              let friends = try? NativeFriendApproval(endpoint: friendEndpoints, expiresAt: expires),
              let avatar = try? ProfileAvatarApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                  accountID: context.session.accountID, approvedOrigins: RetainedImageOrigin.configured(apiBase: context.baseURL, // A3-01: uploadOSS returns an OSS/CDN url
                      extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String), nativePicker: true),
              let clubAdmission = try? ClubOrdinaryAdmissionApproval(context: context, allowsWrites: true),
              let channelTextSend = try? NativeChannelTextApproval(context: context, operation: .send, conversationIDs: [],
                  expiresAt: expires, allowsAnyPositiveConversation: true),
              let channelTextReceipt = try? NativeChannelTextApproval(context: context, operation: .receipt, conversationIDs: [],
                  expiresAt: expires, allowsAnyPositiveConversation: true),
              let admission = makeEndpoint(context, paths: Self.admissionPaths),
              let teamPool = makeEndpoint(context, paths: Self.teamPoolPaths) else { return nil }
        return ReviewedPlayerWriteGrant(imSend: im, clubAdmission: clubAdmission, clubCommunity: clubCommunity, square: square,
            profile: profile, avatar: avatar, registration: registration, team: team, play: play, roamExtras: roamExtras,
            likes: likes, reports: reports, templateAdoption: templateAdoption, friends: friends, channelTextSend: channelTextSend, channelTextReceipt: channelTextReceipt,
            admission: admission, teamPool: teamPool)
    }

    private func contextKey(_ context: RuntimeDependencyContext) -> String {
        "\(context.market.rawValue)|\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)|\(context.role)"
    }

    private func makeEndpoint(_ context: RuntimeDependencyContext, paths: Set<String>) -> OperationEndpointApproval? {
        try? .init(baseURL: context.baseURL, namespace: context.session.namespace,
                   accountID: context.session.accountID, paths: paths)
    }

    /// Audit P1-8 (MP pages/topic/index/index.js:1246-1268, scene-play-activity-detail/index.js:644):
    /// 写评价 posts `api/comment/add` for any topic / activity the signed-in player opens; the writer
    /// re-reads the detail first and only reports success on the inserted row the server returns.
    static let contextualReviewPaths: Set<String> = ["api/comment/add", "api/topic/info-to-user", "api/activity/info"]

    func contextualReview(_ context: RuntimeDependencyContext) -> ContextualReviewApproval? {
        guard socialRole(context), context.session.accountID > 0,
              let endpoints = makeEndpoint(context, paths: Self.contextualReviewPaths) else { return nil }
        return try? ContextualReviewApproval(market: .china, endpoints: endpoints, targets: [], allowsAnyPositiveTarget: true)
    }

    // MARK: Channels + friends social writes (owner approval: non-money player/club social writes)

    /// Gap #17: the official participation lease (player / club only; merchant routes stay off).
    func officialPlayerActions(_ context: RuntimeDependencyContext) -> OfficialActionProductionApproval? {
        guard socialRole(context),
              let endpoints = makeEndpoint(context, paths: OfficialActionProductionApproval.playerTargetPaths) else { return nil }
        return try? OfficialActionProductionApproval(playerMarket: .china, endpoints: endpoints,
                                                     reviewedPolicyVersion: "mp-official-participation-1128")
    }

    private func socialRole(_ context: RuntimeDependencyContext) -> Bool {
        playerWritesEnabled && context.market == .china && (context.role == "player" || context.role == "club")
    }

    /// Contract §8.1 (fourth pass, item 16): the blacklist list/current/receipt reads and the unblock/settle writes are served.
    /// Adding to the list stays on `api/im/block`. Cached per context so the session's equality fence holds for the hour.
    func blacklist(_ context: RuntimeDependencyContext) -> NativeBlacklistApproval? {
        guard socialRole(context) else { return nil }
        let key = contextKey(context)
        if let existing = blacklistByContext[key], Date() < existing.expiresAt { return existing }
        guard let endpoint = makeEndpoint(context, paths: NativeBlacklistApproval.readPaths.union([NativeBlacklistApproval.unblockPath, NativeBlacklistApproval.settlePath])),
              let issued = try? NativeBlacklistApproval(endpoint: endpoint, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        blacklistByContext[key] = issued
        return issued
    }

    /// E2E R5: club post lists, feed, comment lists and history for signed-in China players and clubs. Read-only; cached per
    /// context and reissued when the hour-long lease lapses or is revoked.
    /// Owner 2026-11-13 (money ON for TEST/DEBUG only): the signed-in account's own purchased packages. Open only where
    /// `ReviewedAreaSwitch.moneyPayments(apiHost:)` opens, so www.chengyinhub.com stays closed.
    func workshopPurchasedRead(_ context: RuntimeDependencyContext) -> WorkshopPurchasedReadApproval? {
        guard playerWritesEnabled, context.market == .china, ["player", "club", "merchant"].contains(context.role),
              ReviewedAreaSwitch.moneyPayments(apiHost: context.baseURL.host) else { return nil }
        let key = contextKey(context)
        if let existing = workshopPurchasedByContext[key], existing.matches(context) { return existing }
        guard let issued = try? WorkshopPurchasedReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        workshopPurchasedByContext[key] = issued
        return issued
    }

    func clubCommunityRead(_ context: RuntimeDependencyContext) -> ClubCommunityReadApproval? {
        guard socialRole(context) else { return nil }
        let key = contextKey(context)
        if let existing = clubCommunityReadByContext[key], !existing.isRevoked, Date() < existing.expiresAt { return existing }
        guard let issued = try? ClubCommunityReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        clubCommunityReadByContext[key] = issued
        return issued
    }

    private var clubPostImageUploadByKey: [String: ClubPostImageUploadApproval] = [:]
    /// P1-13 (MP pages/club/detail post composer → `api/common/uploadOSS`, `bizType=club_post_image`): the club post
    /// image upload, issued per viewer context and club with the same OSS/CDN origins as the avatar upload. Cached so
    /// the transport's equality fence holds. Not money.
    func clubPostImageUpload(_ context: RuntimeDependencyContext, clubID: Int) -> ClubPostImageUploadApproval? {
        guard socialRole(context), clubID > 0 else { return nil }
        let key = contextKey(context) + "|club:\(clubID)"
        if let existing = clubPostImageUploadByKey[key] { return existing }
        let origins = RetainedImageOrigin.configured(apiBase: context.baseURL,
            extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String)
        guard let issued = try? ClubPostImageUploadApproval(baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, clubID: clubID, approvedOrigins: origins, nativePicker: true) else { return nil }
        clubPostImageUploadByKey[key] = issued
        return issued
    }

    /// Friend metadata/removal/directory/progress plus the space welcome and onboarding payloads (contract §8, §6.11).
    func socialWriters(_ context: RuntimeDependencyContext) -> ReviewedSocialWriteGrant? {
        guard socialRole(context) else { return nil }
        let key = contextKey(context)
        if let existing = socialWritersByContext[key], Date() < existing.expiresAt { return existing }
        let expires = Date().addingTimeInterval(3600)
        guard let metadataEndpoint = makeEndpoint(context, paths: NativeFriendMetadataApproval.allowedPaths),
              let metadata = try? NativeFriendMetadataApproval(endpoint: metadataEndpoint, expiresAt: expires,
                  allowsStarChanges: true, allowsGroupChanges: true, allowsProgressChanges: true),
              let removalEndpoint = makeEndpoint(context, paths: NativeFriendRemovalApproval.readPaths.union([NativeFriendRemovalApproval.removePath])),
              let removal = try? NativeFriendRemovalApproval(endpoint: removalEndpoint, expiresAt: expires),
              let directoryEndpoint = makeEndpoint(context, paths: NativeFriendDirectoryApproval.paths),
              let directory = try? NativeFriendDirectoryApproval(endpoint: directoryEndpoint, expiresAt: expires),
              let progressEndpoint = makeEndpoint(context, paths: [NativeFriendProgressApproval.path]),
              let progress = try? NativeFriendProgressApproval(endpoint: progressEndpoint, expiresAt: expires),
              let welcomeEndpoint = makeEndpoint(context, paths: [NativeChannelWelcomeApproval.path]),
              let welcome = try? NativeChannelWelcomeApproval(endpoint: welcomeEndpoint, expiresAt: expires),
              let onboardingEndpoint = makeEndpoint(context, paths: [NativeChannelOnboardingApproval.read,
                  NativeChannelOnboardingApproval.submit, NativeChannelOnboardingApproval.receipts]),
              let onboarding = try? NativeChannelOnboardingApproval(endpoint: onboardingEndpoint, expiresAt: expires) else { return nil }
        let grant = ReviewedSocialWriteGrant(expiresAt: expires, friendMetadata: metadata, friendRemoval: removal,
            friendDirectory: directory, friendProgress: progress, welcome: welcome, onboarding: onboarding)
        socialWritersByContext[key] = grant
        return grant
    }

    func friendChannelInvite(_ context: RuntimeDependencyContext, mode: NativeFriendChannelInviteMode) -> NativeFriendChannelInviteApproval? {
        guard socialRole(context), mode.valid else { return nil }
        let key = contextKey(context) + "|\(mode)"
        if let existing = friendChannelInviteByKey[key], existing.mode == mode, Date() < existing.expiresAt { return existing }
        guard let endpoint = makeEndpoint(context, paths: NativeFriendChannelInviteApproval.reads.union(NativeFriendChannelInviteApproval.writes)),
              let approval = try? NativeFriendChannelInviteApproval(endpoint: endpoint, mode: mode,
                  expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        friendChannelInviteByKey[key] = approval
        return approval
    }

    func friendTeamInvite(_ context: RuntimeDependencyContext, mode: NativeFriendTeamInviteMode) -> NativeFriendTeamInviteApproval? {
        guard socialRole(context), mode.valid else { return nil }
        let key = contextKey(context) + "|\(mode)"
        if let existing = friendTeamInviteByKey[key], existing.mode == mode, Date() < existing.expiresAt { return existing }
        guard let endpoint = makeEndpoint(context, paths: NativeFriendTeamInviteApproval.paths),
              let approval = try? NativeFriendTeamInviteApproval(endpoint: endpoint, mode: mode, allowWrites: true,
                  expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        friendTeamInviteByKey[key] = approval
        return approval
    }

    func friendChannelSource(_ context: RuntimeDependencyContext, channelID: Int64) -> NativeFriendChannelSourceApproval? {
        guard socialRole(context), channelID > 0 else { return nil }
        let key = contextKey(context) + "|\(channelID)"
        if let existing = friendChannelSourceByKey[key], Date() < existing.expiresAt { return existing }
        guard let endpoint = makeEndpoint(context, paths: ["api/channels/\(channelID)/members"]),
              let approval = try? NativeFriendChannelSourceApproval(endpoint: endpoint, channelID: channelID,
                  expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        friendChannelSourceByKey[key] = approval
        return approval
    }

    /// Channel directory/detail reads for every member, plus the management writes. A write is still sent only after the
    /// server's own `my_permissions_list` shows MANAGE_CHANNEL (or MANAGE_ROLE for overwrites), which only the space
    /// owner and club admins hold (contract §0.4); the coordinator checks that before it builds a write, and the backend
    /// refuses everyone else. Hangouts (guild kind 2) have no channels (contract §7.7).
    func channelManagement(_ context: RuntimeDependencyContext, viewerRevision: UInt64,
                           scope: NativeChannelManagementScope) -> NativeChannelManagementApproval? {
        guard socialRole(context), scope.guildKind == 1 || scope.guildKind == 3 else { return nil }
        let key = contextKey(context) + "|\(viewerRevision)|\(scope.guildKind)|\(scope.guildID.rawValue)"
        if let existing = channelManagementByKey[key], existing.matches(context, viewerRevision: viewerRevision, scope: scope) { return existing }
        channelManagementByKey[key]?.revoke()
        guard let approval = try? NativeChannelManagementApproval(context: context, viewerRevision: viewerRevision, scope: scope,
            operations: Self.channelManagementOperations, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        channelManagementByKey[key] = approval
        return approval
    }

    static let channelManagementOperations: Set<NativeChannelManagementAccess> = [
        .directory, .detail, .managementInventory, .metadataCommand, .metadataReceipt, .permissionsRead, .permissionCommand, .governanceReceipt
    ]

    /// Owner approval 2026-11-12 (all non-money player writes): players author and publish their own topics as in the
    /// mini-program (pages/publish/*), so the shipped China player gets the project editor reads, writes and publication
    /// reads. Pricing, paid listing, sales, revenue, platform-pass and merchant-scoped routes are not in these features.
    /// A route the China production host does not serve yet (edit-requests/*, publish-status) is only granted against a
    /// non-production host such as TEST, so its UI stays hidden in production instead of failing.
    static func projectEditorRoutes(baseURL: URL) -> [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] {
        let production = ChinaReviewedRouteCapability.targetsChinaProduction(baseURL)
        func served(_ method: String, _ paths: [String]) -> Set<BusinessRuntimeRoute> {
            Set(paths.filter { !production || ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + $0) }
                .compactMap { try? BusinessRuntimeRoute(method: method, path: $0) })
        }
        return [
            .projectRead: served("POST", ["api/publish/home", "api/topic/edit-detail", ProjectEditRequestContract.readPath])
                .union(served("GET", [FreeExplorationVisitConfigService.path])), // C-F6 MP-first
            .projectWrite: served("POST", ["api/topic/create", "api/topic/update", "api/topic/v2/create", "api/topic/v2/update",
                                           ProjectEditRequestContract.submitPath, ProjectEditRequestContract.resumePostProcessingPath,
                                           FreeExplorationVisitConfigService.path]),
            .projectPublicationRead: served("GET", [TopicPublicationPath.check, TopicPublicationPath.status])
        ]
    }

    /// IM voice/video/file attach (contract §6.14): upload, receipt, scan, policy and the `api/im/send` card.
    /// Recipient previews stay out of this exact table. `imPreviewLease` issues one concrete GET
    /// for one template, one viewer, and one conversation (contract §7 item 18).
    static func imMediaRoutes() -> [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] {
        func post(_ path: String) -> BusinessRuntimeRoute? { try? BusinessRuntimeRoute.post(path) }
        func get(_ path: String) -> BusinessRuntimeRoute? { try? BusinessRuntimeRoute(method: "GET", path: path) }
        let table: [BusinessRuntimeFeature: [BusinessRuntimeRoute?]] = [
            .imFileUpload: [post("api/im/file/upload")], .imFileUploadReceipt: [get("api/im/file/receipt")],
            .imFileScan: [post("api/im/file/scan")], .imFileSend: [post("api/im/send")], .imFileReceipt: [post("api/im/send-receipt")],
            .imVideoUpload: [post("api/im/video/upload")], .imVideoUploadReceipt: [get("api/im/video/receipt")],
            .imVideoPolicy: [get("api/im/video/policy")], .imVideoSend: [post("api/im/send")], .imVideoReceipt: [post("api/im/send-receipt")],
            .imVoiceUpload: [post("api/im/voice/upload")], .imVoiceUploadReceipt: [get("api/im/voice/receipt")],
            .imVoiceSend: [post("api/im/send")], .imVoiceReceipt: [post("api/im/send-receipt")]
        ]
        return table.mapValues { Set($0.compactMap { $0 }) }
    }

    /// The six recipient-preview templates. A template that is not in this list is not issued.
    static let imPreviewTemplates: [BusinessRuntimeRouteTemplate] = IMPreviewRouteTemplates.all

    /// One lease per template, viewer, and conversation. An expired cached lease is dropped and not returned.
    func imPreviewLease(_ context: RuntimeDependencyContext, conversationID: Int64,
                        template: BusinessRuntimeRouteTemplate, now: Date = Date()) -> IMPreviewTemplateLease? {
        guard socialRole(context), conversationID > 0, Self.imPreviewTemplates.contains(template) else { return nil }
        let key = contextKey(context) + "|\(conversationID)|\(template.method)|\(template.path)"
        if let cached = imPreviewLeaseByKey[key], now < cached.expiresAt, cached.viewer == context,
           cached.conversationID == conversationID, cached.template == template {
            return cached
        }
        imPreviewLeaseByKey.removeValue(forKey: key)
        guard let issued = IMPreviewTemplateLease(template: template, viewer: context, conversationID: conversationID,
                                                  expiresAt: now.addingTimeInterval(3600)) else { return nil }
        imPreviewLeaseByKey[key] = issued
        return issued
    }

    /// Static IM routes for audit, chain, check-in, moderation and role create. The poll create-receipt read is not
    /// granted: the MP has no such call, the poll `create` reply / `result` read is the record.
    /// Per-message and per-record routes are not issued here; the channel tools screen calls them.
    static func beGapImRoutes() -> [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] {
        func post(_ path: String) -> BusinessRuntimeRoute? { try? BusinessRuntimeRoute.post(path) }
        func get(_ path: String) -> BusinessRuntimeRoute? { try? BusinessRuntimeRoute(method: "GET", path: path) }
        let table: [BusinessRuntimeFeature: [BusinessRuntimeRoute?]] = [
            .imChannelAuditRead: [get("api/im/audit-log")],
            .imChainCreate: [post("api/im/chain/create")], .imChainJoin: [post("api/im/chain/join")],
            .imChainWithdraw: [post("api/im/chain/withdraw")], .imChainClose: [post("api/im/chain/close")],
            .imChainRead: [get("api/im/chain/info")], .imChainReceipt: [get("api/im/interaction/request")],
            .imCheckinWrite: [post("api/im/channel/checkin")], .imCheckinStatus: [get("api/im/channel/checkin-status")],
            .imCheckinRank: [get("api/im/channel/checkin-rank")], .imCheckinReceipt: [get("api/im/channel/checkin-request")],
            .imChannelModerationRead: [get("api/im/moderation/actions")],
            .imChannelModerationWrite: [post("api/im/moderation/timeout"), post("api/im/moderation/kick"), post("api/im/moderation/ban")],
            .imChannelRoleRead: [get("api/im/roles")], .imChannelRoleWrite: [post("api/im/roles")],
            .imChannelAppealRead: [get("api/im/moderation/me")], .imChannelAppealWrite: [post("api/im/appeals")]
        ]
        return table.mapValues { Set($0.compactMap { $0 }) }
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
        // P1-18: MP _reportPresence (30 s POST /api/roam/presence) runs only after the separate presence consent.
        guard let endpoints = makeEndpoint(context, paths: RoamLiveApproval.requiredPaths.union(["api/roam/presence"])) else { return nil }
        let approval = RoamLiveApproval(endpoints: endpoints, foregroundLocation: true, presence: true)
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

    /// ROAM-7: `GET /api/roam/entry/nearby`. China player/club/merchant only. A public guest uses the composition path, not this lease.
    func roamEntryNearby(_ context: RuntimeDependencyContext) -> RoamEntryNearbyReadAccess? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = roamEntryNearbyByContext[key], existing.matches(context) { return existing }
        roamEntryNearbyByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: [RoamEntryNearbyRoute.path]),
              let issued = try? RoamEntryNearbyReadAccess(context: context, approval: endpoints) else { return nil }
        roamEntryNearbyByContext[key] = issued
        return issued
    }

    /// ROAM-7: `POST /api/roam/nearby-runners`. Signed-in China player/club/merchant. Not a guest read.
    func roamNearbyPlayers(_ context: RuntimeDependencyContext) -> RoamNearbyPlayersReadAccess? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = roamNearbyPlayersByContext[key], existing.matches(context) { return existing }
        roamNearbyPlayersByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: [RoamNearbyPlayersReadRoute.path]),
              let issued = try? RoamNearbyPlayersReadAccess(context: context, approval: endpoints) else { return nil }
        roamNearbyPlayersByContext[key] = issued
        return issued
    }

    /// Function audit P1-23 (mp-roam): the roam reads below had a reader but no lease, so they stayed "not configured" in
    /// Release. Same shape as `roamNearbyPlayers`: signed-in China player/club/merchant, one exact path, re-issued per context.
    private func roamRoleAllowed(_ context: RuntimeDependencyContext) -> Bool {
        context.market == .china && ["player", "club", "merchant"].contains(context.role)
    }

    /// MP subpackageRoam/nearby `GET /api/roam/hangout/nearby` (地点玩法 layer of the roam browser).
    func roamNearbyEvents(_ context: RuntimeDependencyContext) -> RoamNearbyEventsReadAccess? {
        guard roamRoleAllowed(context) else { return nil }
        let key = contextKey(context)
        if let existing = roamNearbyEventsByContext[key], existing.matches(context) { return existing }
        roamNearbyEventsByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: [RoamNearbyEventsReadRoute.path]),
              let issued = try? RoamNearbyEventsReadAccess(context: context, approval: endpoints) else { return nil }
        roamNearbyEventsByContext[key] = issued
        return issued
    }

    /// MP scene-roam-stamp-album tab 收到的 `/api/roam/stamp/received`.
    func roamReceivedStamp(_ context: RuntimeDependencyContext) -> RoamReceivedStampReadAccess? {
        guard roamRoleAllowed(context) else { return nil }
        let key = contextKey(context)
        if let existing = roamReceivedStampByContext[key], existing.matches(context) { return existing }
        roamReceivedStampByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: [RoamReceivedStampReadRoute.path]),
              let issued = try? RoamReceivedStampReadAccess(context: context, approval: endpoints) else { return nil }
        roamReceivedStampByContext[key] = issued
        return issued
    }

    /// MP scene-roam-stamp-album tab 我的 `/api/roam/stamp/list`.
    func roamAlbumMetadata(_ context: RuntimeDependencyContext) -> RoamAlbumMetadataReadAccess? {
        guard roamRoleAllowed(context) else { return nil }
        let key = contextKey(context)
        if let existing = roamAlbumMetadataByContext[key], existing.matches(context) { return existing }
        roamAlbumMetadataByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: [RoamAlbumMetadataReadRoute.path]),
              let issued = try? RoamAlbumMetadataReadAccess(context: context, approval: endpoints) else { return nil }
        roamAlbumMetadataByContext[key] = issued
        return issued
    }

    /// MP pages/roam/index history fog `/api/roam/tiles/page`.
    func roamTileMemory(_ context: RuntimeDependencyContext) -> RoamTileMemoryReadAccess? {
        guard roamRoleAllowed(context) else { return nil }
        let key = contextKey(context)
        if let existing = roamTileMemoryByContext[key], existing.matches(context) { return existing }
        roamTileMemoryByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: [RoamTileMemoryReadRoute.path]),
              let issued = try? RoamTileMemoryReadAccess(context: context, approval: endpoints) else { return nil }
        roamTileMemoryByContext[key] = issued
        return issued
    }

    /// MP subpackageRoam/session `GET /api/roam/session` (one walk's facts).
    func roamSessionFact(_ context: RuntimeDependencyContext) -> RoamSessionFactReadAccess? {
        guard roamRoleAllowed(context) else { return nil }
        let key = contextKey(context)
        if let existing = roamSessionFactByContext[key], existing.matches(context) { return existing }
        roamSessionFactByContext[key]?.revoke()
        guard let endpoints = makeEndpoint(context, paths: [RoamSessionFactReadRoute.path]),
              let issued = try? RoamSessionFactReadAccess(context: context, approval: endpoints) else { return nil }
        roamSessionFactByContext[key] = issued
        return issued
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

    /// F-12: the Growth Center's own three reads (api/growth/center, api/play/growth, api/play/my-completed) are
    /// `.liveInProduction` non-money reads. They were never wired, so the reader always answered `growth.notConfigured`.
    /// Issued with the reviewed production gate bundle like the other own-account reads; one hour, then re-issued.
    func growthNormalRead(_ context: RuntimeDependencyContext) -> GrowthNormalReadApproval? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = growthNormalReadByContext[key], existing.matches(context) { return existing }
        growthNormalReadByContext[key]?.revoke()
        guard let approval = try? GrowthNormalReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        growthNormalReadByContext[key] = approval
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

    /// P0-8: join by code, quit, kick, disband and join-mode (`ReviewedTeamMembershipWriteRoute`). The server checks
    /// membership and captaincy; `TeamHTTPService` still re-reads `/api/team/info` and journals the operation first.
    func teamMembershipWrite(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        let key = contextKey(context)
        if let existing = teamMembershipWriteByContext[key] { return existing }
        guard let approval = makeEndpoint(context, paths: ReviewedTeamMembershipWriteRoute.approvalPaths) else { return nil }
        teamMembershipWriteByContext[key] = approval
        return approval
    }

    func cityVoucherIssue(_ context: RuntimeDependencyContext) -> VerificationCodeApproval? {
        guard context.market == .china, ["player", "club", "merchant"].contains(context.role) else { return nil }
        // E2E R8: with the reviewed player grant, the signed-in owner can also show their own registration/ticket entry code
        // (api/verify/dyncode/issue reads the owner's registration via api/registration/info). Issuing a code moves no money.
        let tickets = playerWritesEnabled
        let key = contextKey(context) + (tickets ? "|ticket" : "")
        if let existing = cityVoucherIssueByContext[key] { return existing }
        let paths: Set<String> = tickets ? ["api/verify/citynode/issue", "api/verify/dyncode/issue", "api/registration/info"] : ["api/verify/citynode/issue"]
        guard let endpoints = makeEndpoint(context, paths: paths) else { return nil }
        let approval = VerificationCodeApproval(market: .china, endpoints: endpoints, kinds: tickets ? [.cityVoucher, .ticket] : [.cityVoucher])
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

    /// R11-MEM-17-1: read lease for `api/registration/explore-completion` (MP scene-member-order-detail/index.js:833-835).
    func exploreCompletion(_ context: RuntimeDependencyContext) -> ExploreCompletionReadApproval? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = exploreCompletionByContext[key], !existing.isRevoked, existing.matches(context) { return existing }
        guard let approval = try? ExploreCompletionReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        exploreCompletionByContext[key] = approval
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

    /// 1128 gap #29 (O-14b; MP scene-member-invite-history/index.js:245): 我的邀请 reads `api/user/invite_list`
    /// and the first reward-ledger page `api/user/points/list`. One stable access per signed-in context (the composition
    /// transport re-checks identity with `===`). Read only; 填写邀请人 (P1-15) is a separate write.
    func profileInviteHistory(_ context: RuntimeDependencyContext) -> ProfileInviteHistoryReadAccess? {
        guard context.market == .china else { return nil }
        let key = contextKey(context)
        if let existing = profileInviteHistoryByContext[key], !existing.isRevoked { return existing }
        guard let endpoints = makeEndpoint(context, paths: ProfileInviteHistoryReadRoute.paths),
              let access = try? ProfileInviteHistoryReadAccess(context: context, approval: endpoints) else { return nil }
        profileInviteHistoryByContext[key] = access
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
            // fix/1128-cn-pay P0-2: order-detail Pay runs through RegistrationPaySection (`pay/app` → WeChat SDK → one
            // `registration/info` read); the review-sheet payment stays closed (externalCheckoutApproved false, no payment
            // approval) and is not shown (P1-4). Gap #9 (1128 plan): device payment is approved in Release; the WeChat
            // SDK path is gated by its own build flag (`WeChatPaymentBuildSettings`) and the pay route by
            // `ReleaseMoneyWriteSwitch` in the composition firewall. Cancel / cancel-refund are the reviewed order actions.
            externalCheckoutApproved: false, devicePaymentApproved: true,
            allowsReviewedCancellationAndRefund: true
        )
        var imRoutes: [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] = [
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
        if socialRole(context) { imRoutes.merge(Self.imMediaRoutes()) { $0.union($1) } }
        // P1-28 (MP chat/index.js chooseMedia → uploadOSS → im/send msg_type image): the chat image row now works.
        if socialRole(context) { imRoutes[.imUpload] = Set([try? BusinessRuntimeRoute.post("api/common/uploadOSS")].compactMap { $0 }) }
        if socialRole(context) { imRoutes.merge(Self.projectEditorRoutes(baseURL: context.baseURL)) { $0.union($1) } }
        if socialRole(context) { imRoutes.merge(Self.beGapImRoutes()) { $0.union($1) } }
        // fix-1128b-social #4 (audit H-06a, H-13a): the 发布 tab "+" and club 发布活动 need `publishingService`.
        if socialRole(context) { imRoutes.merge(MPFirstSocialApprovals.publishingRoutes(baseURL: context.baseURL)) { $0.union($1) } }
        // fix/1128c-ai-showcase: AI theme draft + quota (player, club); club design, template fill, safety precheck (club).
        if socialRole(context) { imRoutes.merge(AICreationReleaseApprovals.routes(baseURL: context.baseURL, role: context.role)) { $0.union($1) } }
        let businessConfiguration = try? BusinessRuntimeConfiguration(
            market: .china, baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, routes: imRoutes,
            imMediaOrigins: RetainedImageOrigin.configured(apiBase: context.baseURL,
                extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String),
            imImageSelection: socialRole(context)
        )
        let rewardPledge = context.market == .china
        return NativeRuntimeDependencies(
            // Gap #17 (1128 plan, G-10b): official v1 报名 / 完成, v2 到达 and inbox 接受 / 拒绝 for the signed-in player.
            officialActionApproval: officialPlayerActions(context),
            configuration: playConfiguration(context),
            businessConfiguration: businessConfiguration,
            weChatPaymentConfiguration: WeChatPaymentBuildSettings.current,
            couponCodeApproval: couponCodeApproval,
            contextualReviewApproval: contextualReview(context),
            // CLB-r11-checkin-detail-01 (MP checkin-detail/index.js:143-200): the owner 清退并退款.
            ownerRefundApproval: playerWritesEnabled ? MPFirstClubApprovals.ownerRefund(context) : nil,
            clubGovernanceApproval: playerWritesEnabled ? MPFirstClubApprovals.governance(context) : nil,
            merchantBusinessApproval: MPFirstMerchantApprovals.business(context),
            merchantEngagementApproval: MPFirstMerchantApprovals.engagement(context),
            orderLifecycleConfiguration: orderConfiguration,
            nonCashRewardApproved: rewardPledge, nonCashRewardClaimApproved: rewardPledge,
            nonCashRewardPreviewApproved: rewardPledge, nonCashRewardRedeemApproved: rewardPledge,
            nonCashRewardDraftApproved: rewardPledge, nonCashRewardFreezeApproved: rewardPledge,
            nonCashRewardHoldApproved: rewardPledge, nonCashRewardWithdrawApproved: rewardPledge,
            nonCashRewardExpireApproved: rewardPledge, nonCashRewardReturnApproved: rewardPledge,
            nonCashRewardCaseApproved: rewardPledge, nonCashRewardStatsApproved: rewardPledge,
            nonCashRewardCatalogApproved: rewardPledge, nonCashRewardManageApproved: rewardPledge
        )
    }

    private func playConfiguration(_ context: RuntimeDependencyContext) -> RuntimeDependencyConfiguration? {
        guard playerWritesEnabled, context.role == "player" || context.role == "club",
              let endpoints = makeEndpoint(context, paths: Self.playPaths) else { return nil }
        let key = contextKey(context)
        if let existing = playConfigurationByContext[key] { return existing }
        // fix-1128b #5 (J-06d/J-12b/J-11c): photo, scan, location and shake device kinds are on, so photo nodes, the filter
        // camera and the in-store photo step can capture → uploadOSS → `api/play/photo`. #22 (J-07 #2/#6/#7): kit artwork
        // loads from the same upload-result origins the avatar approval uses (API origin + `CYStampImageOrigins`).
        let configuration = RuntimeDependencyConfiguration(market: .china, endpoints: endpoints, play: Self.playCapabilities,
            publisherReads: true, devices: Self.playDevices, artworkHosts: Self.playArtworkHosts(apiBase: context.baseURL),
            playReadApprovalID: UUID())
        playConfigurationByContext[key] = configuration
        return configuration
    }
}

/// Writers the shipped China composition constructs. Admission is `ReviewedProductionFormMutationRoute`.
struct ReviewedPlayerWriteGrant {
    let imSend: OperationEndpointApproval
    let clubAdmission: ClubOrdinaryAdmissionApproval
    let clubCommunity: OperationEndpointApproval
    let square: OperationEndpointApproval
    let profile: OperationEndpointApproval
    let avatar: ProfileAvatarApproval
    let registration: OperationEndpointApproval
    let team: OperationEndpointApproval
    let play: OperationEndpointApproval
    let roamExtras: OperationEndpointApproval
    let likes: OperationEndpointApproval
    let reports: OperationEndpointApproval
    let templateAdoption: OperationEndpointApproval
    let friends: NativeFriendApproval
    let channelTextSend: NativeChannelTextApproval
    let channelTextReceipt: NativeChannelTextApproval
    let admission: OperationEndpointApproval
    let teamPool: OperationEndpointApproval
}

/// Channel/friend social leases the shipped China composition issues to player and club accounts.
struct ReviewedSocialWriteGrant {
    let expiresAt: Date
    let friendMetadata: NativeFriendMetadataApproval
    let friendRemoval: NativeFriendRemovalApproval
    let friendDirectory: NativeFriendDirectoryApproval
    let friendProgress: NativeFriendProgressApproval
    let welcome: NativeChannelWelcomeApproval
    let onboarding: NativeChannelOnboardingApproval
}

extension AppCompositionRoot {
    /// Friends, welcome/onboarding, invites and channel management for the reviewed China player grant.
    mutating func installSocialWriteApprovals(_ gates: ReviewedProductionGateLeases) {
        nativeFriendMetadataApproval = { [gates] context in gates.socialWriters(context)?.friendMetadata }
        nativeFriendRemovalApproval = { [gates] context in gates.socialWriters(context)?.friendRemoval }
        nativeFriendDirectoryApproval = { [gates] context in gates.socialWriters(context)?.friendDirectory }
        nativeFriendProgressApproval = { [gates] context in gates.socialWriters(context)?.friendProgress }
        nativeChannelWelcomeApproval = { [gates] context in gates.socialWriters(context)?.welcome }
        nativeChannelOnboardingApproval = { [gates] context in gates.socialWriters(context)?.onboarding }
        nativeFriendChannelInviteApproval = { [gates] context, mode in gates.friendChannelInvite(context, mode: mode) }
        nativeFriendTeamInviteApproval = { [gates] context, mode in gates.friendTeamInvite(context, mode: mode) }
        nativeFriendChannelSourceApproval = { [gates] context, channelID in gates.friendChannelSource(context, channelID: channelID) }
        clubCommunityReadApproval = { [gates] context in gates.clubCommunityRead(context) }
        clubPostImageUploadApproval = { [gates] context, clubID in gates.clubPostImageUpload(context, clubID: clubID) }
        nativeChannelManagementApproval = { [gates] context, viewer, scope in
            gates.channelManagement(context, viewerRevision: viewer, scope: scope)
        }
    }
}

enum ClubGapProductionLease {
    /// Same paths as `clubAndMerchantCoopOwnerGrant`. Settlement export is not a player write.
    private static let paths: Set<String> = [
        "api/club-compensation/quality/evidence",
        "api/club/activity/cancel",
        "api/club/activity/detail",
        "api/club/activity/join",
        "api/club/channels",
        "api/club/events",
        "api/club/events/Checkin",
        "api/club/events/proxy-enroll",
        "api/club/events/save",
        "api/club/group-code",
        "api/club/group-code/save",
        "api/club/join-requests/apply",
        "api/club/lead",
        "api/club/notices",
        "api/club/notices/send",
        "api/club/post",
        "api/club/post/operation",
        "api/club/post/operation/comment",
        "api/club/roles",
        "api/club/workbench",
        "api/coop"
    ]

    static func allows(relative: String, method: String, body: Data?) -> Bool {
        guard paths.contains(relative) else { return false }
        if method == "GET" {
            return relative == "api/club/lead" && (body == nil || body?.isEmpty == true)
        }
        return method == "POST" && body?.isEmpty == false
    }
}

/// HANDOVER 22. Appended path grant only. Money prefixes are not production writes.
enum WorkshopModRouteGrant {
    static let readPaths: Set<String> = [
        "api/mod-installation",
        "api/mod-owned-report",
        "api/mod-upgrade",
        "api/workshop/creator/pending-packages",
        "api/workshop/creator/public-theme-use",
        "api/workshop/owned",
        "api/workshop/purchased/professional-targets",
        "api/workshop/purchased/professional-operations"
    ]
    static let moneyPaths: Set<String> = [
        "api/workshop/v2/purchased/list",
        "api/workshop/v2/purchased/detail",
        "api/workshop/purchased/install",
        "api/mod-settlement/mine",
        "api/mod-settlement/mine/income"
    ]
}

/// HANDOVER 33 WP-03. Appended after the workshop grant. Money and merchant writes follow ReviewedAreaSwitch.
enum MerchantOpsWp03Lease {
    static func admits(relative: String, method: String, host: String?) -> Bool {
        guard MerchantOpsWp03Catalog.paths.contains(relative), method == MerchantOpsWp03Catalog.method(for: relative) else { return false }
        if MerchantOpsWp03Catalog.money.contains(relative) { return ReviewedAreaSwitch.moneyPayments(apiHost: host) }
        if MerchantOpsWp03Catalog.writes.contains(relative) { return ReviewedAreaSwitch.merchantWrites(apiHost: host) }
        return true
    }
}

/// WP-01 / WP-05, owner 2026-11-13 (money ON for TEST/DEBUG only). The app sends these only while the payout
/// (or payment) area switch is open; Core `ReleaseMoneyWriteSwitch` and `ChinaReviewedRouteCapability.moneyAreaOwnerGrant`
/// refuse them again on the production host.
enum PayoutReceiverRouteGrant {
    static let readPaths: Set<String> = [
        "api/club/settlement/mine",
        "api/club/settlement/summary",
        "api/club/personal-receiver/status",
        "api/club-direct-merchant/club",
        "api/club-direct-merchant/merchant",
        "api/merchant/payout-account"
    ]
    static let moneyPaths: Set<String> = [
        "api/club/personal-receiver/bind",
        "api/club/personal-receiver/unbind"
    ]
    static let paymentReadPaths: Set<String> = ["api/registration/payment-readiness"]

    static func admits(_ route: PayoutReceiverRoute) -> Bool {
        readPaths.contains(route.rawValue) || moneyPaths.contains(route.rawValue)
    }
}

extension ReviewedProductionFormMutationRoute {
    /// Admits my-project list mutations (`MyProjectHTTPMutator`). Canceling an activity refunds paid
    /// registrations and goes through `ReviewedAreaSwitch.moneyPayments`; merchant-scoped actions go
    /// through `ReviewedAreaSwitch.merchantWrites`.
    static func acceptsMyProjectMutation(_ request: URLRequest, baseURL: URL, token: String) -> Bool {
        guard let url = request.url,
              let type = request.value(forHTTPHeaderField: "Content-Type"),
              type.hasPrefix("multipart/form-data; boundary="),
              let body = request.httpBody, body.count <= 1024,
              let text = String(data: body, encoding: .utf8) else { return false }
        let boundary = String(type.dropFirst("multipart/form-data; boundary=".count))
        let requiredKeys: Set<String>
        let positiveKey: String
        var expectedStatus: Set<String>?
        var isActivityCancel = false
        switch url.absoluteString {
        case baseURL.appendingPathComponent("api/activity/update_publish_status").absoluteString,
             baseURL.appendingPathComponent("api/activity/delete").absoluteString,
             baseURL.appendingPathComponent("api/topic/delete").absoluteString:
            requiredKeys = ["id", "scope"]; positiveKey = "id"
        case baseURL.appendingPathComponent("api/topic/update_user_status").absoluteString:
            requiredKeys = ["id", "scope", "expectedUserStatus"]; positiveKey = "id"; expectedStatus = ["0", "1"]
        case baseURL.appendingPathComponent("api/activity/cancel").absoluteString:
            requiredKeys = ["id", "reason", "scope"]; positiveKey = "id"; isActivityCancel = true
        case baseURL.appendingPathComponent("api/template/delete").absoluteString:
            requiredKeys = ["template_id", "scope"]; positiveKey = "template_id"
        case baseURL.appendingPathComponent("api/template/updateLibraryStatus").absoluteString:
            requiredKeys = ["template_id", "status", "scope"]; positiveKey = "template_id"; expectedStatus = ["1", "3"]
        default:
            return false
        }
        var fields: [String: String] = [:]
        for key in requiredKeys {
            let marker = "--\(boundary)\r\nContent-Disposition: form-data; name=\"\(key)\"\r\n\r\n"
            guard let range = text.range(of: marker),
                  let end = text[range.upperBound...].range(of: "\r\n") else { return false }
            fields[key] = String(text[range.upperBound..<end.lowerBound])
        }
        guard let rawID = fields[positiveKey], let id = Int(rawID), id > 0, String(id) == rawID else { return false }
        let scope = fields["scope"] ?? ""
        guard scope.isEmpty || scope == "MERCHANT" else { return false }
        if scope == "MERCHANT" {
            guard ReviewedAreaSwitch.merchantWrites(apiHost: url.host) else { return false }
        }
        if isActivityCancel {
            guard ReviewedAreaSwitch.moneyPayments(apiHost: url.host),
                  let reason = fields["reason"], !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  reason.count <= 200 else { return false }
        }
        if let expectedStatus {
            let actual = (fields["expectedUserStatus"] ?? fields["status"]) ?? ""
            guard expectedStatus.contains(actual) else { return false }
        }
        guard let canonical = try? AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: token, boundary: boundary) else {
            return false
        }
        return canonical.httpBody == body
    }
}
