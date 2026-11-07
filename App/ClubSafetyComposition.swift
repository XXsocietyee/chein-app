import Foundation
import SwiftUI

/// Composition factory for Club & Channel Safety/Moderation (App Store Guideline 1.2).
/// Bridges `ClubChannelMessagingHostView` and `ClubChannelMessagingView` to existing Core services
/// (`IMSafetyWriter`, `IMExpandedWriter`, `MessagingSessionReader`, `ClubManagementAccess`,
/// `ClubGovernanceAccess` / `ClubGovernanceCoordinator`, and `NativeChannelManagementCoordinator`)
/// without modifying `App/AppSession.swift` or `App/AppCompositionRoot.swift`.
///
/// Coordinator / G1 integration hook for `AppCompositionRoot` / `AppSession`:
/// `var clubChannelSafetyServiceFactory: @MainActor (AppSession, ClubRecord, ClubManagementContext?, ClubCommunityContext?) -> any ClubChannelSafetyServing = { ClubSafetyComposition.makeSafetyService(session: $0, club: $1, management: $2, community: $3) }`
@MainActor
enum ClubSafetyComposition {
    static func makeSafetyService(
        session: AppSession,
        club: ClubRecord,
        management: ClubManagementContext? = nil,
        community: ClubCommunityContext? = nil
    ) -> any ClubChannelSafetyServing {
        CoreClubChannelSafetyService(
            imSafetyWriter: { [weak session] in
                session?.imSafetyWriter
            },
            imExpandedWriter: { [weak session] in
                session?.imExpandedWriter
            },
            messageWriter: { [weak session] in
                session?.messageWriter
            },
            messagingReader: { [weak session] in
                session?.messagingReader
            },
            clubManagementAccess: {
                management?.access
            },
            clubGovernanceAccess: {
                management?.governance?.access
            },
            clubGovernanceCoordinator: {
                management?.governance?.coordinator
            },
            nativeChannelDirectoryLoader: { [weak session] clubID in
                guard clubID > 0,
                      let managementID = try? NativeChannelManagementID(String(clubID)),
                      let scope = try? NativeChannelManagementScope(guildKind: 1, guildID: managementID),
                      let coordinator = session?.makeNativeChannelManagementFlow(scope: scope),
                      coordinator.isCurrent,
                      coordinator.service.allows(.directory) else {
                    return nil
                }
                return try await coordinator.service.directory()
            },
            channelMessageDeleteDispatcher: { [weak session] _, channelID, _ in
                let hideAction = IMSafetyAction.hide(conversationID: channelID)
                guard let writer = session?.imSafetyWriter,
                      writer.permits(hideAction),
                      let identity = writer.identity else {
                    throw ChannelSafetyServiceError.serviceUnavailable(
                        endpoint: .deleteMessage(clubID: club.id, channelID: channelID, messageID: 0)
                    )
                }
                try await writer.perform(hideAction, expectedIdentity: identity)
            }
        )
    }

    static func makeRulesStore(namespace: String = "questify.club.channels") -> any ChannelRulesAcceptanceStoring {
        UserDefaultsChannelRulesAcceptanceStore(defaults: .standard, namespace: namespace)
    }

    static func makeBlockedUsersStore(namespace: String = "questify.club.channels") -> any ChannelBlockedUsersStoring {
        UserDefaultsChannelBlockedUsersStore(defaults: .standard, namespace: namespace)
    }

    static func makeHostView(
        club: ClubRecord,
        session: AppSession,
        management: ClubManagementContext? = nil,
        community: ClubCommunityContext? = nil,
        manageGrant: ClubDetailManageGrant? = nil,
        onSignIn: (() -> Void)? = nil
    ) -> ClubChannelMessagingHostView<ClubSessionReader> {
        let safetyService = makeSafetyService(
            session: session,
            club: club,
            management: management,
            community: community
        )
        return ClubChannelMessagingHostView(
            club: club,
            reader: session.clubReader,
            manageGrant: manageGrant,
            safetyService: safetyService,
            rulesStore: makeRulesStore(),
            blockedUsersStore: makeBlockedUsersStore(),
            onSignIn: onSignIn
        )
    }
}

extension AppSession {
    func makeClubChannelSafetyService(
        club: ClubRecord,
        management: ClubManagementContext? = nil,
        community: ClubCommunityContext? = nil
    ) -> any ClubChannelSafetyServing {
        ClubSafetyComposition.makeSafetyService(
            session: self,
            club: club,
            management: management,
            community: community
        )
    }
}
