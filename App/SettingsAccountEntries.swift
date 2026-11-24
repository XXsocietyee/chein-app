import SwiftUI

/// Mini-program pages/shezhi rows that need a signed-in account: identity applications
/// (成为俱乐部主理人 / 成为商家) right after the profile row, and 退出账号 at the end.
@MainActor struct SettingsIdentityApplicationEntries: View {
    @ObservedObject var session: AppSession
    /// B-SZ-05: fresh `isClubLeader` from `POST /api/user/info` (SettingsView reads it on appear); false until then.
    var isClubLeader = false
    /// B-SZ-14-r7: the freshly read role when the page has one; nil falls back to the session role.
    var roleOverride: String? = nil
    @Environment(\.locale) private var locale
    @State private var loadingClubs = false
    @State private var pushesHostStatus = false
    @State private var managedClubID: Int?
    @State private var showsCreateClub = false
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .info

    var body: some View {
        if SettingsIdentityApplications.isOffered(toRole: roleOverride ?? session.account?.effectiveRole, isClubLeader: isClubLeader) {
            Section {
                Button {
                    guard !loadingClubs else { return }
                    loadingClubs = true
                    Task {
                        // MP shezhi `pickClub`: an owned club opens its 管理 tab, a leader without one creates, others apply.
                        let route = await session.resolveSettingsClubHostRoute(isClubLeader: isClubLeader)
                        loadingClubs = false
                        switch route {
                        case .applyForHost:
                            pushesHostStatus = true
                        case .createClub:
                            if session.clubManagementContext.operations != nil { showsCreateClub = true } else { pushesHostStatus = true }
                        case .openManage(let club):
                            managedClubID = club.id
                        case .failed(let message):
                            toastTone = .warning
                            toastMessage = LocalizedStringKey(message)
                        }
                    }
                } label: { Label { Text("settings.becomeClubHost") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconFlagBlue) } }
                    .disabled(loadingClubs)
                    .accessibilityIdentifier("settings.becomeClubHost")
                NavigationLink {
                    MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)
                } label: { Label { Text("settings.becomeMerchant") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconShop) } }
                    .accessibilityIdentifier("settings.becomeMerchant")
            }
            .navigationDestination(isPresented: $pushesHostStatus) {
                ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: session.clubIdentity,
                                       access: session.clubGovernanceAccess, coordinator: session.clubGovernanceCoordinator)
            }
            .navigationDestination(item: $managedClubID) { clubID in
                ClubDetailView(id: clubID, reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                               management: session.clubManagementContext, community: session.clubCommunityContext,
                               publicRoster: session.clubPublicRosterReader,
                               requestedTab: ClubDetailTab(rawValue: SettingsClubHostRoute.manageTab))
            }
            .sheet(isPresented: $showsCreateClub) {
                if let operations = session.clubManagementContext.operations {
                    NavigationStack {
                        ClubOperationsWorkspaceView(target: .create, identity: session.clubIdentity, access: operations.access,
                                                    coordinator: operations.coordinator, hostApplication: session.clubManagementContext.governance)
                    }
                    .cySheet(detents: [.large])
                }
            }
            .cyToast(message: $toastMessage, tone: toastTone)
        }
    }
}

@MainActor struct SettingsSignOutEntry: View {
    @ObservedObject var session: AppSession
    var onSignedOut: () -> Void
    @Environment(\.locale) private var locale
    @State private var confirms = false
    @State private var confirmation: AuthChannelSessionSnapshot?
    @State private var failed = false
    @State private var working = false
    var body: some View {
        if session.account != nil {
        if let accountID = session.account?.id {
            Section {
                Button {
                    confirmation = session.signOutConfirmation(accountID: accountID)
                    confirms = confirmation != nil
                } label: {
                    Label { Text("settings.signOut") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconLogout) }
                        .frame(maxWidth: .infinity).foregroundStyle(CYColor.textPrimary)
                }
                    .disabled(working)
                    .accessibilityIdentifier("settings.signOut")
                // B-SZ-02: the server did not confirm; the account stays signed in and the row retries.
                if failed {
                    Text("settings.signOut.failed").cyText(.meta).foregroundStyle(CYColor.dangerText)
                        .accessibilityIdentifier("settings.signOut.failed")
                }
            }
            .sheet(isPresented: $confirms) {
                if let expected = confirmation {
                    CYConfirmSheet(title: appLocalized("auth.signOutConfirm", locale: locale),
                                   message: appLocalized("settings.signOut.message", locale: locale),
                                   confirmTitle: appLocalized("auth.signOut", locale: locale),
                                   isDestructive: true, confirmIdentifier: "settings.signOut.confirm") {
                        confirmation = nil; confirms = false
                        working = true; failed = false
                        Task {
                            let done = await session.logout(matching: expected)
                            working = false
                            if done { onSignedOut() } else if session.account != nil { failed = true }
                        }
                    }
                    .presentationDetents([.medium])
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
