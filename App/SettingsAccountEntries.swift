import SwiftUI

/// Mini-program pages/shezhi rows that need a signed-in account: identity applications
/// (成为俱乐部主理人 / 成为商家) right after the profile row, and 退出账号 at the end.
@MainActor struct SettingsIdentityApplicationEntries: View {
    @ObservedObject var session: AppSession
    @Environment(\.locale) private var locale
    @State private var loadingClubs = false
    @State private var pushesHostStatus = false
    @State private var selectedClubID: Int?
    @State private var clubPickerChoices: [ClubRecord] = []
    @State private var showsClubPicker = false
    @State private var toastMessage: LocalizedStringKey?
    @State private var toastTone: CYToastTone = .info

    var body: some View {
        if SettingsIdentityApplications.isOffered(toRole: session.account?.effectiveRole) {
            Section {
                Button {
                    guard !loadingClubs else { return }
                    loadingClubs = true
                    Task {
                        let outcome = await session.loadSettingsClubEntry()
                        loadingClubs = false
                        switch outcome {
                        case .applyForHost:
                            pushesHostStatus = true
                        case .openClub(let club):
                            selectedClubID = club.id
                        case .chooseClub(let clubs):
                            clubPickerChoices = clubs
                            showsClubPicker = true
                        case .failed(let message):
                            toastTone = .error
                            toastMessage = LocalizedStringKey(message)
                        }
                    }
                } label: { Label("settings.becomeClubHost", systemImage: "flag") }
                    .disabled(loadingClubs)
                    .accessibilityIdentifier("settings.becomeClubHost")
                NavigationLink {
                    MerchantOnboardingView(session: session, coordinator: session.merchantOnboardingCoordinator)
                } label: { Label("settings.becomeMerchant", systemImage: "storefront") }
                    .accessibilityIdentifier("settings.becomeMerchant")
            }
            .navigationDestination(isPresented: $pushesHostStatus) {
                ClubGovernanceReadView(operation: .hostStatus, scope: .init(), identity: session.clubIdentity,
                                       access: session.clubGovernanceAccess, coordinator: session.clubGovernanceCoordinator)
            }
            .navigationDestination(item: $selectedClubID) { clubID in
                ClubDetailView(id: clubID, reader: session, onSignIn: {}, actionCoordinator: session.clubActionCoordinator,
                               management: session.clubManagementContext, community: session.clubCommunityContext,
                               publicRoster: session.clubPublicRosterReader)
            }
            .sheet(isPresented: $showsClubPicker) {
                MemberSettingsClubPickerSheet(clubs: clubPickerChoices, onSelect: { club in
                    showsClubPicker = false
                    selectedClubID = club.id
                }, onClose: {
                    showsClubPicker = false
                })
                .cyDomainSheet(detents: [.half])
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
    var body: some View {
        if session.account != nil {
        if let accountID = session.account?.id {
            Section {
                Button {
                    confirmation = session.signOutConfirmation(accountID: accountID)
                    confirms = confirmation != nil
                } label: {
                    Label("auth.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                        .frame(maxWidth: .infinity).foregroundStyle(CYColor.textPrimary)
                }
                    .accessibilityIdentifier("settings.signOut")
            }
            .sheet(isPresented: $confirms) {
                if let expected = confirmation {
                    CYConfirmSheet(title: appLocalized("auth.signOutConfirm", locale: locale),
                                   message: appLocalized("settings.signOut.message", locale: locale),
                                   confirmTitle: appLocalized("auth.signOut", locale: locale),
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
