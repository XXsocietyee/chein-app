import SwiftUI

/// Tracks whether a screen currently presented inside a deep-link landing sheet has unsaved edits.
@MainActor final class DeepLinkDirtyTracker: ObservableObject {
    @Published var isDirty = false
}

private struct DeepLinkDirtyTrackerKey: EnvironmentKey {
    static var defaultValue: DeepLinkDirtyTracker? { nil }
}

/// Environment closures connecting member-area popups to reviewed Core services without expanding `AppSession.swift`.
struct MemberPopupEnvironmentActions {
    var disablePresence: (@MainActor () async -> RoamPresenceDisableOutcome)?
    var loadOwnedClubs: (@MainActor () async -> SettingsClubPickerOutcome)?
    var makeNPCDataCoordinator: (@MainActor () -> NPCChatDataCoordinator)?
    var exportNPCChatTranscript: (@MainActor () async -> String?)?
    var clearNPCChatLogs: (@MainActor () async -> NPCChatLogDeletionOutcome?)?
    var loadCoopInviteTopics: (@MainActor () async -> [(id: Int, title: String)])?
    var loadCoopInviteChapters: (@MainActor (_ topicID: Int) async -> [TopicInviteChapter])?
}

private struct MemberPopupEnvironmentActionsKey: EnvironmentKey {
    static var defaultValue: MemberPopupEnvironmentActions { .init() }
}

extension EnvironmentValues {
    var deepLinkDirtyTracker: DeepLinkDirtyTracker? {
        get { self[DeepLinkDirtyTrackerKey.self] }
        set { self[DeepLinkDirtyTrackerKey.self] = newValue }
    }

    var memberPopupActions: MemberPopupEnvironmentActions {
        get { self[MemberPopupEnvironmentActionsKey.self] }
        set { self[MemberPopupEnvironmentActionsKey.self] = newValue }
    }
}

extension AppSession {
    /// `GET /api/roam/presence-visibility` for the latest local roam session. Nil stays unknown and does not hide the off control.
    func readRoamPresenceVisibility() async -> Bool? {
        guard isConfigured, isSignedIn, let config = regionalConfiguration?.apiConfiguration else { return nil }
        let sessionID = (try? roamExperienceReader.history())?.compactMap(\.serverSessionID).last
        guard let sessionID, sessionID > 0 else { return nil }
        return await RoamPresenceVisibilityService(configuration: config, transport: compositionTransport)
            .readPresence(token: token, sessionID: sessionID)
    }

    /// ROAM-r11-5: mid-session presence switch for the live roam tools sheet. Nil = not confirmed.
    func setRoamPresenceVisibility(sessionID: Int?, visible: Bool) async -> Bool? {
        guard isConfigured, isSignedIn, let config = regionalConfiguration?.apiConfiguration else { return nil }
        return await RoamPresenceVisibilityService(configuration: config, transport: compositionTransport)
            .setPresence(token: token, sessionID: sessionID, visible: visible, consentAccepted: visible)
    }

    /// Turns off approximate nearby roam presence via `POST /api/roam/presence-visibility` (`visible=false`).
    func disableRoamPresenceVisibility() async -> RoamPresenceDisableOutcome {
        guard isConfigured, isSignedIn,
              let config = regionalConfiguration?.apiConfiguration else { return .unavailable }
        return await RoamPresenceVisibilityService(configuration: config, transport: compositionTransport)
            .disablePresence(token: token)
    }

    /// Queries owned clubs via `POST /api/club/my` when opening the Settings club-host entry.
    func loadSettingsClubEntry() async -> SettingsClubPickerOutcome {
        guard isConfigured, isSignedIn,
              let config = regionalConfiguration?.apiConfiguration else { return .applyForHost }
        return await SettingsClubPickerService(configuration: config, transport: compositionTransport)
            .resolveEntry(token: token)
    }

    /// Captures reviewed member-area popup actions for SwiftUI environment injection.
    func memberPopupActions() -> MemberPopupEnvironmentActions {
        let makeNPCDataCoordinator: (@MainActor () -> NPCChatDataCoordinator) = { [weak self] in
            guard let self else {
                return NPCChatDataCoordinator(current: { nil }, available: { _ in false }, read: { _ in throw NPCChatDataFailure.unavailable })
            }
            return self.makeNPCChatDataReadCoordinator()
        }
        guard isConfigured && isSignedIn else {
            return MemberPopupEnvironmentActions(makeNPCDataCoordinator: makeNPCDataCoordinator)
        }
        var actions = MemberPopupEnvironmentActions(makeNPCDataCoordinator: makeNPCDataCoordinator)
        actions.disablePresence = { [weak self] in
            guard let self else { return .unavailable }
            return await self.disableRoamPresenceVisibility()
        }
        actions.loadOwnedClubs = { [weak self] in
            guard let self else { return .applyForHost }
            return await self.loadSettingsClubEntry()
        }
        actions.exportNPCChatTranscript = { [weak self] in
            guard let self else { return nil }
            let coordinator = self.makeNPCChatDataReadCoordinator()
            coordinator.appear(active: true)
            await coordinator.load()
            let transcript = coordinator.data.map { NPCChatDataExportFormatter.formatTranscript(from: $0) }
            coordinator.invalidate()
            return transcript
        }
        actions.clearNPCChatLogs = { [weak self] in
            guard let self else { return nil }
            let coordinator = self.makeNPCChatDataReadCoordinator()
            coordinator.appear(active: true)
            await coordinator.load()
            guard coordinator.canRequestDeletion else {
                coordinator.invalidate()
                return nil
            }
            coordinator.requestDeletion()
            await coordinator.confirmDeletion()
            let outcome = coordinator.deletion
            coordinator.invalidate()
            switch outcome {
            case .deleted(let count): return .deleted(count: count)
            case .unknown: return .unknown
            default: return nil
            }
        }
        actions.loadCoopInviteTopics = { [weak self] in
            guard let self,
                  let config = self.regionalConfiguration?.apiConfiguration,
                  let accountID = self.account?.id,
                  let token = self.token,
                  let coopSession = try? CoopFlowSession(accountID: accountID, epoch: self.sessionRevision, token: token) else { return [] }
            let service = CoopFlowService(configuration: config, transport: self.compositionTransport)
            guard let json = try? await service.read(.ownedTopics(kind: .merchant, scope: nil, page: 1), session: coopSession),
                  let rows = json["rows"].rows else { return [] }
            return rows.compactMap { row in
                guard let id = row["id"].integer, id > 0 else { return nil }
                let title = row["title"].text ?? row["name"].text ?? "#\(id)"
                return (id: id, title: title)
            }
        }
        actions.loadCoopInviteChapters = { [weak self] topicID in
            guard let self,
                  topicID > 0,
                  let config = self.regionalConfiguration?.apiConfiguration else { return [] }
            let editor = TopicCreatorEditorService(
                baseURL: config.baseURL,
                transport: self.compositionTransport,
                token: { [weak self] in self?.token },
                scope: nil,
                enabled: { [weak self] in self?.isSignedIn == true }
            )
            return (try? await editor.inviteChapters(topicID: Int64(topicID))) ?? []
        }
        return actions
    }
}
