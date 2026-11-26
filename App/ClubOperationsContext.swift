import SwiftUI

struct ClubOperationsContext {
    let access: ClubOperationsSessionAccess
    let coordinator: ClubOperationsCoordinator
}

/// Lets governance screens (apply done state, host-apply receipt) open the create flow without
/// threading the operations context through every read view. Set once at the app root.
private struct ClubOperationsFactoryKey: EnvironmentKey {
    static let defaultValue: @MainActor () -> (operations: ClubOperationsContext, governance: ClubGovernanceContext?)? = { nil }
}
extension EnvironmentValues {
    var clubOperationsFactory: @MainActor () -> (operations: ClubOperationsContext, governance: ClubGovernanceContext?)? {
        get { self[ClubOperationsFactoryKey.self] }
        set { self[ClubOperationsFactoryKey.self] = newValue }
    }
}

/// CLB-apply-01: MP apply done state → 「创建我的俱乐部」 (apply/index.wxml:184-186, js:461).
@MainActor struct ClubCreateMyClubLink: View {
    let identity: ClubReadIdentity?
    /// Round 4 copy: the payout-receiver empty state says 创建俱乐部 (MP wxml:11); apply keeps 创建我的俱乐部.
    var titleKey: LocalizedStringKey = "club.host.done.create"
    @Environment(\.clubOperationsFactory) private var factory
    var body: some View {
        if let context = factory() {
            NavigationLink {
                ClubOperationsWorkspaceView(target: .create, identity: identity, access: context.operations.access,
                                            coordinator: context.operations.coordinator, hostApplication: context.governance)
            } label: {
                Text(titleKey).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("club.host.done.create")
        }
    }
}
