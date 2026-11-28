import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// fix-1128-publish (audit P0-7, P1-27, P1-29). Owner MP-first rule for the 发布 writes the mini-program already sends:
/// - 互动 template authoring (MP `pages/publish/temp` → `api/template/draft` / `api/template/publish`), sent once through the
///   r3 original-request envelope `api/template/author-requests/submit|read` (ApiAppGapsOriginalRequestController).
/// - Topic-editor media (MP `uploadOSS`: story image, story audio, node photo) and the owned-cover author sheet
///   (`api/topic/cover/*`, ApiAppGapsTopicController), the same origins the working cover / gallery field accepts.
/// - The 我的项目 → 模板 shelf read (MP `pages/publishkit` my-list).
/// Built only for a reviewed China deployment with player writes on. The server still checks the account and role.
/// No pay, refund, payout or pricing route is admitted here.
@MainActor enum MPFirstPublishApprovals {
    /// The envelope read path; the reader never submits.
    static let templateAuthoringReadPaths: Set<String> = [TemplateAuthoringRequestReceipt.readPath]
    /// The envelope submit path plus the two original writes it may carry (`canSubmit(path:)` checks both).
    static let templateAuthoringSubmitPaths: Set<String> = [
        TemplateAuthoringRequestReceipt.submitPath, "api/template/draft", "api/template/publish"
    ]
    /// The owned-cover sheet: read the current cover, read its asset, upload, select and read the selection status.
    static let ownedCoverOperations: Set<OwnedTopicCoverOperation> = [.readCurrent, .readAsset, .upload, .select, .status]
    /// One shelf lease lasts at most a day (TemplateShelfReadApproval limit); a fresh one is issued after it lapses.
    static let shelfLeaseDuration: TimeInterval = 12 * 60 * 60

    private static var nodeImageApprovals: [String: ProjectNodeImageUploadApproval] = [:]
    private static var shelfApprovals: [String: TemplateShelfReadApproval] = [:]

    /// Reviewed China deployment with player writes on (same switch as the MP-first club writes).
    static func enabled(_ deployment: AppCompositionRoot.DeploymentState) -> Bool {
        guard case .reviewed(let reviewed) = deployment else { return false }
        return reviewed.productionGatesEnabled && reviewed.playerWritesEnabled && reviewed.regional.market == .china
    }

    /// AppCompositionRoot glue (kept here for the root's size ratchet): an injected approval always wins; otherwise the
    /// MP-first issuer runs only when `enabled(deployment)`. Fixtures and unconfigured builds keep their nil default.
    static func fallback<Approval>(_ injected: @escaping @MainActor (RuntimeDependencyContext) -> Approval?,
                                   _ deployment: AppCompositionRoot.DeploymentState,
                                   _ issue: @escaping @MainActor (RuntimeDependencyContext) -> Approval?) -> @MainActor (RuntimeDependencyContext) -> Approval? {
        let on = enabled(deployment)
        return { context in injected(context) ?? (on ? issue(context) : nil) }
    }

    static func templateAuthoringRead(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        endpoint(context, paths: templateAuthoringReadPaths)
    }

    static func templateAuthoringSubmit(_ context: RuntimeDependencyContext) -> OperationEndpointApproval? {
        endpoint(context, paths: templateAuthoringSubmitPaths)
    }

    /// Upload-result origins: the API origin plus the deployment's `CYStampImageOrigins` (cover / gallery use the same set).
    static func uploadOrigins(_ context: RuntimeDependencyContext) -> Set<String> {
        RetainedImageOrigin.configured(apiBase: context.baseURL,
            extra: Bundle.main.object(forInfoDictionaryKey: "CYStampImageOrigins") as? String)
    }

    static func storyImage(_ context: RuntimeDependencyContext) -> ProjectStoryImageUploadApproval? {
        guard isSignedInChina(context) else { return nil }
        return try? ProjectStoryImageUploadApproval(baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, approvedOrigins: uploadOrigins(context), nativePicker: true)
    }

    static func storyAudio(_ context: RuntimeDependencyContext) -> ProjectStoryAudioUploadApproval? {
        guard isSignedInChina(context) else { return nil }
        return try? ProjectStoryAudioUploadApproval(baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, approvedOrigins: uploadOrigins(context), nativePicker: true)
    }

    /// The node photo is a 4:3 JPEG within the retained-image limits. One approval per session identity so the client's
    /// `currentApproval() == approval` check stays true for the whole editor session (the approval carries an id).
    static func nodeImage(_ context: RuntimeDependencyContext) -> ProjectNodeImageUploadApproval? {
        guard isSignedInChina(context) else { return nil }
        let key = identityKey(context)
        if let cached = nodeImageApprovals[key] { return cached }
        guard let policy = try? ProjectNodeImageMediaPolicy(maximumJPEGBytes: RetainedSelectedImage.maximumBytes,
                                                             maximumDimension: RetainedSelectedImage.maximumDimension,
                                                             maximumReferenceBytes: 8192),
              let approval = try? ProjectNodeImageUploadApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                  accountID: context.session.accountID, approvedOrigins: uploadOrigins(context), policy: policy, nativePicker: true)
        else { return nil }
        nodeImageApprovals[key] = approval
        return approval
    }

    static func ownedCover(_ context: RuntimeDependencyContext) -> OwnedTopicCoverApproval? {
        guard isSignedInChina(context) else { return nil }
        return try? OwnedTopicCoverApproval(baseURL: context.baseURL, namespace: context.session.namespace,
            accountID: context.session.accountID, operations: ownedCoverOperations, nativePicker: true)
    }

    /// 我的项目 → 模板. Reuses the live lease for the same session; a lapsed or revoked one is replaced.
    static func templateShelf(_ context: RuntimeDependencyContext, now: Date = Date()) -> TemplateShelfReadApproval? {
        guard isSignedInChina(context) else { return nil }
        let key = identityKey(context)
        if let cached = shelfApprovals[key], cached.matches(context, now: now) { return cached }
        shelfApprovals[key]?.revoke()
        guard let fresh = try? TemplateShelfReadApproval(context: context, expiresAt: now.addingTimeInterval(shelfLeaseDuration)) else {
            shelfApprovals[key] = nil
            return nil
        }
        shelfApprovals[key] = fresh
        return fresh
    }

    private static func isSignedInChina(_ context: RuntimeDependencyContext) -> Bool {
        context.market == .china && context.session.accountID > 0 && !context.session.namespace.isEmpty
    }

    private static func identityKey(_ context: RuntimeDependencyContext) -> String {
        "\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)|\(context.role)"
    }

    private static func endpoint(_ context: RuntimeDependencyContext, paths: Set<String>) -> OperationEndpointApproval? {
        guard isSignedInChina(context) else { return nil }
        return try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                                              accountID: context.session.accountID, paths: paths)
    }
}
