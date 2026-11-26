import SwiftUI

/// Mini-program pages/shezhi rows that need a signed-in account: identity applications
/// (成为俱乐部主理人 / 成为商家) right after the profile row, and 退出账号 at the end.
@MainActor struct SettingsIdentityApplicationEntries: View {
    @ObservedObject var session: AppSession
    /// Fresh settings profile. The apply rows stay hidden until this read says the viewer is not a club leader.
    var profile: SettingsAccountProfile?
    @State private var loadingClubs = false
    @State private var pushesHostStatus = false
    @State private var pushesClubCreate = false
    @State private var selectedClubID: Int?
    @State private var hostRouter: SettingsClubHostRouter?
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .info

    var body: some View {
        if let profile, SettingsIdentityApplications.isOffered(toRole: profile.role, isClubLeader: profile.isClubLeader) {
            Section {
                Button {
                    openClubHost(isClubLeader: profile.isClubLeader)
                } label: { Label { Text("settings.becomeClubHost") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconFlagBlue) } }
                    .disabled(loadingClubs)
                    .accessibilityIdentifier("settings.becomeClubHost")
                if PlayerLaunch.merchantCenterEnabled { // Lane G: 成为商家 (merchant onboarding) is hidden in Release
                NavigationLink {
                    MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)
                } label: { Label { Text("settings.becomeMerchant") } icon: { AccountPublishMPGlyph(MPAsset.FeatureIcon.iconShop) } }
                    .accessibilityIdentifier("settings.becomeMerchant")
                }
            }
            .navigationDestination(isPresented: $pushesHostStatus) {
                ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: session.clubIdentity,
                                       access: session.clubGovernanceAccess, coordinator: session.clubGovernanceCoordinator)
            }
            .navigationDestination(isPresented: $pushesClubCreate) {
                clubCreate
            }
            .navigationDestination(item: $selectedClubID) { clubID in
                ClubDetailView(id: clubID, reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                               management: session.clubManagementContext, community: session.clubCommunityContext,
                               publicRoster: session.clubPublicRosterReader,
                               requestedTab: ClubDetailTab(rawValue: SettingsClubHostRoute.manageTab))
            }
            .cyToast(message: $toastMessage, tone: toastTone)
        }
    }

    /// `SettingsClubHostRouter.resolve`: a second tap is dropped while `POST /api/club/my` is in flight.
    private func openClubHost(isClubLeader: Bool) {
        guard !loadingClubs, let config = session.regionalConfiguration?.apiConfiguration else { return }
        let router = hostRouter ?? SettingsClubHostRouter(configuration: config, transport: session.compositionTransport)
        hostRouter = router
        guard !router.isLoading else { return }
        loadingClubs = true
        Task {
            let route = await router.resolve(token: session.token, isClubLeader: isClubLeader)
            loadingClubs = false
            guard let route else { return }
            switch route {
            case .applyForHost:
                pushesHostStatus = true
            case .createClub:
                pushesClubCreate = true
            case .openManage(let club):
                selectedClubID = club.id
            case .failed(let message):
                toastTone = .warning
                toastMessage = LocalizedStringKey(message)
            }
        }
    }

    @ViewBuilder private var clubCreate: some View {
        if let operations = session.clubManagementContext.operations {
            ClubOperationsWorkspaceView(target: .create, identity: session.clubIdentity, access: operations.access,
                                        coordinator: operations.coordinator, hostApplication: session.clubManagementContext.governance)
        } else {
            ContentUnavailableView("mp.route.unavailable", systemImage: "tray")
                .accessibilityIdentifier("mp.route.unavailable")
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
                        .foregroundStyle(.red)
                }
                    .disabled(working)
                    .accessibilityIdentifier("settings.signOut")
                // B-SZ-02: the server did not confirm; the account stays signed in and the row retries.
                if failed {
                    Text("settings.signOut.failed").font(.footnote).foregroundStyle(.red)
                        .accessibilityIdentifier("settings.signOut.failed")
                }
            }
            .cySheet(isPresented: $confirms) {
                if let expected = confirmation {
                    MemberConfirmSheet(title: appLocalized("auth.signOutConfirm", locale: locale),
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
