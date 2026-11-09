import SwiftUI

/// Mini-program pages/shezhi rows that need a signed-in account: identity applications
/// (成为俱乐部主理人 / 成为商家) right after the profile row, and 退出账号 at the end.
@MainActor struct SettingsIdentityApplicationEntries: View {
    @ObservedObject var session: AppSession
    var body: some View {
        if SettingsIdentityApplications.isOffered(toRole: session.account?.effectiveRole) {
            Section {
                NavigationLink {
                    ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: session.clubIdentity,
                                           access: session.clubGovernanceAccess, coordinator: session.clubGovernanceCoordinator)
                } label: { Label("settings.becomeClubHost", systemImage: "flag") }
                    .accessibilityIdentifier("settings.becomeClubHost")
                NavigationLink {
                    MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)
                } label: { Label("settings.becomeMerchant", systemImage: "storefront") }
                    .accessibilityIdentifier("settings.becomeMerchant")
            }
        }
    }
}

@MainActor struct SettingsSignOutEntry: View {
    @ObservedObject var session: AppSession
    var onSignedOut: () -> Void
    @State private var confirms = false
    @State private var confirmation: AuthChannelSessionSnapshot?
    var body: some View {
        if session.account != nil {
        if let accountID = session.account?.id {
            Section {
                Button {
                    confirmation = session.signOutConfirmation(accountID: accountID)
                    confirms = confirmation != nil
                } label: {
                    Label("auth.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity).foregroundStyle(CYColor.dangerText)
                }
                    .accessibilityIdentifier("settings.signOut")
            }
            .sheet(isPresented: $confirms) {
                if let expected = confirmation {
                    CYConfirmSheet(title: String(localized: "auth.signOutConfirm"),
                                   message: String(localized: "settings.signOut.message"),
                                   confirmTitle: String(localized: "auth.signOut"),
                                   isDestructive: true, confirmIdentifier: "settings.signOut.confirm") {
                        confirmation = nil; confirms = false
                        Task {
                            if await session.logout(matching: expected) { onSignedOut() }
                        }
                    }
                    .presentationDetents([.height(300)])
                }
            }
            .onChange(of: confirms) { _, visible in if !visible { confirmation = nil } }
            .onChange(of: session.authChannelSnapshot) { _, _ in
                confirmation = nil; confirms = false
            }
            .onDisappear { confirmation = nil; confirms = false }
        }
        }
    }
}
