import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// fix-1128b-social (audit 1128-plan gaps #1, #2, #3, #4, #27). Owner MP-first rule: the square and 发布 writes the
/// mini-program already sends are switched on for the reviewed China player/club composition (the same switch as the
/// other non-money player writes, `ReviewedProductionGateLeases.playerWriters`). Merchant routes stay off: merchant
/// accounts never get a player-write grant, and no merchant path is in these sets.
@MainActor enum MPFirstSocialApprovals {
    /// One community write approval lasts 12 hours; the session owner re-reads it on every use.
    static let communityLeaseDuration: TimeInterval = 12 * 60 * 60

    /// Gap #4: `.publishingRead` / `.publishingWrite` routes for `BusinessRuntimeConfiguration`, so
    /// `AppSession.publishingService` is non-nil and the 发布 tab "+" and club 发布活动 open (MP pages/publish/*).
    /// A path the China production host does not serve is left out against that host, like `projectEditorRoutes`.
    static func publishingRoutes(baseURL: URL) -> [BusinessRuntimeFeature: Set<BusinessRuntimeRoute>] {
        let production = ChinaReviewedRouteCapability.targetsChinaProduction(baseURL)
        func served(_ paths: [String]) -> Set<BusinessRuntimeRoute> {
            Set(paths.filter { !production || ChinaReviewedRouteCapability.admitsChinaProductionCall("/" + $0) }
                .compactMap { try? BusinessRuntimeRoute.post($0) })
        }
        return [.publishingRead: served(PublishingTabRoutes.readPaths), .publishingWrite: served(PublishingTabRoutes.writePaths)]
    }

    /// Composition-transport admission for the publishing routes (called from `acceptsPlayerWrite`, so a live player
    /// write grant for this viewer is already required). POST only; the merchant-scoped 我的项目 list stays refused.
    /// Nil leaves the request to the other player-write rules.
    static func publishingDecision(relative: String, method: String, request: URLRequest) -> Bool? {
        guard PublishingTabRoutes.all.contains(relative) else { return nil }
        guard method == "POST", request.url?.query == nil else { return false }
        if relative == "api/project/my", let body = request.httpBody,
           String(decoding: body, as: UTF8.self).contains("MERCHANT") { return false }
        return true
    }

    /// Gap #3: the report receipt (`GET api/community-trust/reports/{id}`) and own-request lookup
    /// (`GET api/community-trust/reports/mine?requestId=`) the report sheet reads after a submit. GET, no body.
    static func reportReadDecision(relative: String, method: String, request: URLRequest) -> Bool? {
        let prefix = "api/community-trust/reports/"
        guard relative.hasPrefix(prefix) else { return nil }
        let tail = String(relative.dropFirst(prefix.count))
        let isReceipt = Int(tail).map { $0 > 0 && String($0) == tail } ?? false
        guard isReceipt || tail == "mine" else { return nil }
        return method == "GET" && (request.httpBody == nil || request.httpBody?.isEmpty == true)
    }

    /// Gaps #1-#3: the `/api/v1/community` post / comment / report / composer writer for this viewer. Issued only when
    /// the reviewed composition gave this viewer the square write grant (China player or club, player writes on).
    static func community(_ root: AppCompositionRoot, _ context: RuntimeDependencyContext,
                          now: Date = Date()) -> SquareCommunityWriteApproval? {
        guard let grant = root.playerWriteGrant(context),
              grant.square.paths.contains("api/v1/community/posts"),
              grant.square.paths.contains("api/v1/community/reports") else { return nil }
        return try? SquareCommunityWriteApproval(context: context, expiresAt: now.addingTimeInterval(communityLeaseDuration))
    }

    /// Gap #2: composer grants. `live` sends guidelines / drafts / post / publish, `media` uploads images through
    /// `api/common/uploadOSS` (covered by the player profile grant), `legal` accepts the current community guideline.
    static func workspaceGrants(_ approval: SquareCommunityWriteApproval?) -> SquareWorkspaceGrants {
        var grants = SquareWorkspaceGrants()
        guard approval != nil else { return grants }
        grants.live = true; grants.media = true; grants.legal = true
        return grants
    }
}

extension AppSession {
    /// Gaps #1-#3 glue (kept here for the `AppSession.swift` line ratchet).
    func squareCommunityWriteApproval(_ context: RuntimeDependencyContext) -> SquareCommunityWriteApproval? {
        guard currentRuntimeDependencyContext == context else { return nil }
        return MPFirstSocialApprovals.community(composition, context)
    }

    /// Gap #2: the live composer service (guidelines -> uploadOSS -> media/register -> post -> publish). Requests go
    /// through the composition transport, which admits them under this viewer's square grant.
    func squareWorkspaceLiveService() -> SquareWorkspaceService? {
        guard currentSquareCommunityWriteApproval != nil, let api = regionalConfiguration?.apiConfiguration else { return nil }
        return SquareWorkspaceService(configuration: api, transport: runtimeHTTPTransport)
    }

    /// Gap #3 (App Store 1.2): square post / comment report. Policy reads (`capabilities`, receipt, own-request lookup) and the
    /// `POST api/v1/community/reports` write are on exactly when the community writer is issued for this viewer.
    func squareReportLiveService(_ configuration: APIConfiguration) -> SquareReportService {
        let on = currentSquareCommunityWriteApproval != nil
        return SquareReportService(configuration: configuration, transport: runtimeHTTPTransport, readsEnabled: on,
                                   grant: on ? .reviewedInjection : .disabled)
    }

    /// The community approval for the signed-in viewer right now, or nil (signed out, merchant, US, writes off).
    var currentSquareCommunityWriteApproval: SquareCommunityWriteApproval? {
        guard let context = currentRuntimeDependencyContext else { return nil }
        return squareCommunityWriteApproval(context)
    }
}
