import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Map read grants the Release deployment already carries. Kept here so the composition root stays inside its line ceiling.
enum ReleasePlayerReadGrant {
    static func allows(_ deployment: AppCompositionRoot.DeploymentState, _ grant: ReviewedAppDeployment.ReadGrant) -> Bool {
        guard case .reviewed(let reviewed) = deployment else { return false }
        return reviewed.reads.contains(grant)
    }

    /// Public layers are admitted when either map grant is present, matching the transport.
    static func allowsMapLayers(_ deployment: AppCompositionRoot.DeploymentState) -> Bool {
        guard case .reviewed(let reviewed) = deployment else { return false }
        return !reviewed.reads.isDisjoint(with: [.publicMapLayers, .manualMap])
    }
}

/// K13: player reads the Release composition left nil even though the paths are live.
/// One cached approval per context so transport identity fences (`===`, revision) stay stable.
/// An injected closure still wins. These issuers run only when production gates are on.
@MainActor final class ReleasePlayerReadLeases {
    private var weeklyPointsByContext: [String: ProfileWeeklyPointsReadApproval] = [:]
    private var publicInfoByContext: [String: ProfilePublicInfoReadAccess] = [:]
    private var guideByContext: [String: ProfileGuideReadAccess] = [:]
    private var memberRoleByContext: [String: MemberRoleInfoReadApproval] = [:]
    private var ownMediaByContext: [String: OwnMediaReadApproval] = [:]
    private var manualMapByContext: [String: ManualMapReadApproval] = [:]
    private var publicLayerByContext: [String: MapPublicLayerReadApproval] = [:]
    private var ownerDraftByContext: [String: OwnerDraftReadApproval] = [:]
    private var socialReaderByContext: [String: SocialReaderProductionApproval] = [:]

    private func key(_ context: RuntimeDependencyContext) -> String {
        "\(context.market.rawValue)|\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)|\(context.role)"
    }

    /// Own-account reads for a signed-in China player, club host, or merchant-role account.
    /// This does not open the merchant center.
    private func ownAccount(_ context: RuntimeDependencyContext) -> Bool {
        context.market == .china && context.session.accountID > 0
            && ["player", "club", "merchant"].contains(context.role)
            && AuthRequestBuilder.isValidToken(context.session.token)
    }

    private func endpoint(_ context: RuntimeDependencyContext, paths: Set<String>) -> OperationEndpointApproval? {
        try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                                       accountID: context.session.accountID, paths: paths)
    }

    func weeklyPoints(_ context: RuntimeDependencyContext) -> ProfileWeeklyPointsReadApproval? {
        guard ownAccount(context) else { return nil }
        let id = key(context)
        if let existing = weeklyPointsByContext[id], existing.matches(context) { return existing }
        guard let issued = try? ProfileWeeklyPointsReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        weeklyPointsByContext[id] = issued
        return issued
    }

    func publicInfo(_ context: RuntimeDependencyContext) -> ProfilePublicInfoReadAccess? {
        guard ownAccount(context), let approval = endpoint(context, paths: [ProfilePublicInfoReadRoute.path]) else { return nil }
        let id = key(context)
        if let existing = publicInfoByContext[id], existing.matches(context) { return existing }
        guard let issued = try? ProfilePublicInfoReadAccess(context: context, approval: approval) else { return nil }
        publicInfoByContext[id] = issued
        return issued
    }

    func guide(_ context: RuntimeDependencyContext) -> ProfileGuideReadAccess? {
        guard ownAccount(context), let approval = endpoint(context, paths: ProfileGuideReadRoute.paths) else { return nil }
        let id = key(context)
        if let existing = guideByContext[id], existing.matches(context) { return existing }
        guard let issued = try? ProfileGuideReadAccess(context: context, approval: approval) else { return nil }
        guideByContext[id] = issued
        return issued
    }

    func memberRole(_ context: RuntimeDependencyContext) -> MemberRoleInfoReadApproval? {
        guard ownAccount(context) else { return nil }
        let id = key(context)
        if let existing = memberRoleByContext[id], existing.matches(context) { return existing }
        guard let issued = try? MemberRoleInfoReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        memberRoleByContext[id] = issued
        return issued
    }

    /// GET list only. Status and retry stay off (`allowsStatus` false).
    func ownMediaList(_ context: RuntimeDependencyContext) -> OwnMediaReadApproval? {
        guard ownAccount(context) else { return nil }
        let id = key(context)
        if let existing = ownMediaByContext[id], existing.matches(context), !existing.allowsStatus { return existing }
        guard let issued = try? OwnMediaReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600), allowsStatus: false) else { return nil }
        ownMediaByContext[id] = issued
        return issued
    }

    func manualMap(_ context: RuntimeDependencyContext) -> ManualMapReadApproval? {
        guard context.market == .china, context.session.accountID > 0,
              !context.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let id = key(context)
        if let existing = manualMapByContext[id], existing.matches(context) { return existing }
        guard let issued = try? ManualMapReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        manualMapByContext[id] = issued
        return issued
    }

    func publicLayers(_ context: RuntimeDependencyContext) -> MapPublicLayerReadApproval? {
        guard context.market == .china, context.session.accountID > 0,
              !context.role.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        let id = key(context)
        if let existing = publicLayerByContext[id], existing.matches(context) { return existing }
        guard let issued = try? MapPublicLayerReadApproval(context: context, expiresAt: Date().addingTimeInterval(3600)) else { return nil }
        publicLayerByContext[id] = issued
        return issued
    }

    /// Personal list and restore only. Save and delete stay off.
    func ownerDrafts(_ context: RuntimeDependencyContext) -> OwnerDraftReadApproval? {
        guard ownAccount(context) else { return nil }
        let id = key(context)
        if let existing = ownerDraftByContext[id], existing.matches(context) { return existing }
        guard let grant = try? ContentDraftRouteGrant(
            context: context, ownerMemberID: Int64(context.session.accountID), scope: .personal,
            routes: [.list, .restore], expiresAt: Date().addingTimeInterval(3600)),
              let issued = try? OwnerDraftReadApproval(grant: grant) else { return nil }
        ownerDraftByContext[id] = issued
        return issued
    }

    func socialReader(_ context: RuntimeDependencyContext, endpoints: OperationEndpointApproval) -> SocialReaderProductionApproval? {
        guard context.market == .china else { return nil }
        let id = key(context)
        if let existing = socialReaderByContext[id], existing.matches(context) { return existing }
        let raw = RetainedImageOrigin.configured(apiBase: context.baseURL,
            extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String)
        let origins = Set(raw.compactMap { ObjectCardMediaPolicy.origin($0) })
        let issued = SocialReaderProductionApproval(market: .china, endpoints: endpoints,
            objectCards: true, messageImages: !origins.isEmpty, imageOrigins: origins)
        socialReaderByContext[id] = issued
        return issued
    }
}
