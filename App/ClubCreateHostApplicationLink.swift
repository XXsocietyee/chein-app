import SwiftUI

/// club/create → club/apply: opens the existing host-status read, whose form submits
/// `api/club/become-leader` through the reviewed governance command path.
struct ClubCreateHostApplicationLink: View {
    let identity: ClubReadIdentity?
    let governance: ClubGovernanceContext
    var body: some View {
        NavigationLink {
            ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: identity, access: governance.access, coordinator: governance.coordinator)
                .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
        } label: { Label("club.ops.applyHost", systemImage: "person.badge.plus") }
            .accessibilityIdentifier("club.ops.applyHost")
    }
}

/// CLB-r9-create-02 (MP create js:114-118, 192-200): a signed-in non-host is sent on to the host application
/// (正在前往主理人申请, `wx.redirectTo` apply). Native pushes the same host-status page once per visit; back returns
/// to the create page, which still offers 前往申请 (`ClubCreateHostApplicationLink`).
struct ClubCreateHostAutoOpen: ViewModifier {
    let active: Bool
    let identity: ClubReadIdentity?
    let governance: ClubGovernanceContext?
    @State private var opened = false
    @State private var didOpen = false
    func body(content: Content) -> some View {
        content
            .navigationDestination(isPresented: $opened) { destination }
            .onChange(of: active, initial: true) { _, now in
                guard now, !didOpen, governance != nil else { return }
                didOpen = true
                opened = true
            }
    }
    @ViewBuilder private var destination: some View {
        if let governance {
            ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: identity, access: governance.access, coordinator: governance.coordinator)
                .environment(\.clubEnrollmentProfile, governance.enrollmentProfile)
        }
    }
}
