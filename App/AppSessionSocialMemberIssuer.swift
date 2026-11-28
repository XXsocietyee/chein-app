import Foundation

/// 1128 gap #10 (M-17c/d; MP subpackageMember/components/cy/profile/index.js onFollow / onStartChat): the public
/// profile 关注 / 取消关注 and 私信 used to resolve to `SocialDisabledActionAccess` in Release because
/// `socialMemberActionApprovals` was empty. The reviewed China deployment with player writes now issues one exact,
/// short-lived approval per member and operation. The follow is confirmed by re-reading the profile and the chat by
/// finding the direct conversation (SocialMemberActionAccess), and the profile page re-reads the relation counts.
@MainActor extension AppSession {
    func issueSocialMemberApproval(_ context: RuntimeDependencyContext, _ operation: SocialMemberActionOperation,
                                   _ memberID: Int) -> SocialMemberActionApproval? {
        guard let reviewed = composition.reviewed, Self.releaseIssuesSocialMemberActions(reviewed),
              currentRuntimeDependencyContext == context else { return nil }
        return SocialMemberActionReleaseIssuer.approval(context, operation: operation, memberID: memberID)
    }

    /// Only the reviewed China deployment with production gates and player writes issues member actions.
    nonisolated static func releaseIssuesSocialMemberActions(_ reviewed: ReviewedAppDeployment) -> Bool {
        reviewed.productionGatesEnabled && reviewed.playerWritesEnabled && reviewed.regional.market == .china
    }
}
