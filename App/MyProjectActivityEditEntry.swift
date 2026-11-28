import SwiftUI

/// fix-1128b-social #27 (audit H-13b, O-11c). MP myproject long-press 编辑 (subpackageA/pages/myproject/index.js:1203-1215
/// `canEdit`, :580 `editActivity`): a published activity (running / notStarted / offline / pending / rejected) the
/// viewer runs, not a merchant-taken one, opens the activity editor (`api/activity/info` → `api/activity/update`).
private struct MyProjectActivityEditKey: EnvironmentKey { static let defaultValue: ((CreatorContentProject) -> Void)? = nil }
extension EnvironmentValues {
    /// Present only when the session has live activity-edit grants; nil hides the 编辑 row.
    var myProjectActivityEdit: ((CreatorContentProject) -> Void)? {
        get { self[MyProjectActivityEditKey.self] }
        set { self[MyProjectActivityEditKey.self] = newValue }
    }
}

enum MyProjectActivityEditRule {
    static func applies(_ project: CreatorContentProject, merchantScopeAccess: MyProjectMerchantScopeAccess) -> Bool {
        guard !merchantScopeAccess.isBrowseOnly, project.bizType == "activity", project.ownerType != "merchant",
              project.sourceID > 0 else { return false }
        return ["running", "notStarted", "offline", "pending", "rejected"].contains(project.state ?? "")
    }
}

/// The 编辑 row in `MyProjectRowOperationsMenu` (first, as in the MP ops sheet).
@MainActor struct MyProjectActivityEditButton: View {
    let project: CreatorContentProject
    @Environment(\.myProjectActivityEdit) private var edit
    @Environment(\.myProjectMerchantScopeAccess) private var merchantScopeAccess
    var body: some View {
        if let edit, MyProjectActivityEditRule.applies(project, merchantScopeAccess: merchantScopeAccess) {
            Button { edit(project) } label: { Label("myProject.op.edit", systemImage: "pencil") }
                .accessibilityIdentifier("myProject.op.editActivity.\(project.id)")
        }
    }
}

extension ProjectOwnedContentNavigation {
    /// Opens the activity editor for a row regardless of the tap route (which sends running rows to the detail).
    func openActivityEditor(_ project: CreatorContentProject, scope: UUID, reader: any CreatorContentReading,
                            merchantScopeAccess: MyProjectMerchantScopeAccess) {
        guard reader.scope == scope, reader.isAuthenticated, project.sourceID > 0 else { return }
        let request = MyProjectActivityEditorRequest(activityID: project.sourceID, readerScope: scope)
        show(.init(project: project, scope: scope, decision: .activityEditor(request), merchantScopeAccess: merchantScopeAccess))
    }
}

extension MPFirstSocialApprovals {
    private static var activityEditingByKey: [String: ActivityEditingGrants] = [:]

    /// Gap #27: `activityEditingApproval` for `AppSession` from the Release composition. One stable grant value per viewer
    /// (the transport compares `currentGrant == grants`), issued only with this viewer's player-write grant (player or
    /// club, China, player writes on). Merchant stays off.
    static func activityEditing(_ root: AppCompositionRoot) -> (RuntimeDependencyContext) -> ActivityEditingGrants {
        { context in
            guard root.playerWriteGrant(context) != nil else { return .init() }
            let key = "\(context.baseURL.absoluteString)|\(context.session.namespace)|\(context.session.accountID)|\(context.session.epoch)|\(context.role)"
            if let cached = activityEditingByKey[key] { return cached }
            guard let read = try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                      accountID: context.session.accountID, paths: [ActivityEditingService.readPath]),
                  let update = try? OperationEndpointApproval(baseURL: context.baseURL, namespace: context.session.namespace,
                      accountID: context.session.accountID, paths: [ActivityEditingService.updatePath]) else { return .init() }
            let grants = ActivityEditingGrants(read: read, update: update)
            activityEditingByKey[key] = grants
            return grants
        }
    }
}

extension Notification.Name {
    /// fix-1128b-social #27: posted once the server acknowledges an activity save; `userInfo["id"]` is the activity id.
    static let cyActivityEditSaved = Notification.Name("cy.fix1128b.activityEditSaved")
}

/// Broadcasts a server-acknowledged activity save so the activity detail behind the editor re-reads (MP editActivity
/// returns and the detail / list show the server copy).
@MainActor struct ActivityEditSavedBroadcast: View {
    @ObservedObject var controller: ActivityEditingController
    let activityID: Int
    var body: some View {
        Color.clear.frame(width: 0, height: 0)
            .onChange(of: controller.status) { _, status in
                guard MyProjectActivityEditorPolicy.isServerSaveReceipt(status) else { return }
                NotificationCenter.default.post(name: .cyActivityEditSaved, object: nil, userInfo: ["id": activityID])
            }
    }
}
