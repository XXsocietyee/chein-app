import SwiftUI

/// Reviewed popup-closure actions injected via EnvironmentValues without growing `AppSession.swift`.
struct PopupCloseEnvironmentActions {
    var graduateBetaTopic: (@MainActor (_ topicID: Int) async -> Result<String, Error>)?
    var loadTransferClubs: (@MainActor () async -> [ClubRecord])?
    var transferTopicToClub: (@MainActor (_ topicID: Int, _ clubID: Int) async -> Result<Int?, Error>)?
    var saveUserPhoneAndName: (@MainActor (_ nickname: String, _ phone: String) async -> Result<Void, Error>)?
    var loadAttendance: (@MainActor (_ eventID: Int, _ organizer: Bool) async -> OfficialAttendanceSnapshot?)?
    var loadOfficialContact: (@MainActor (_ activityID: Int) async -> OfficialPlayContact?)?
    var sendAttendanceCommand: (@MainActor (_ eventID: Int, _ action: OfficialAttendanceAction, _ fields: [String: String]) async -> OfficialOrganizerReceipt?)?
    var loadPlanFallback: (@MainActor (_ activityID: Int, _ expectedRevision: Int) async -> PlayPlanFallbackStatus?)?
    var submitPlanFallback: (@MainActor (_ activityID: Int, _ expectedRevision: Int, _ reason: String) async -> Result<PlayPlanFallbackResult, Error>)?
    /// CLB-G13a: one 通用玩法 action (MP director.js confirmGenericOps → executeAction). Success carries the outcome.
    var submitSharedRunAction: (@MainActor (_ activityID: Int, _ expectedRevision: Int, _ action: String, _ payload: [String: PlayWireValue]) async -> Result<String, Error>)?
}

private struct PopupCloseEnvironmentActionsKey: EnvironmentKey {
    static var defaultValue: PopupCloseEnvironmentActions { .init() }
}

extension EnvironmentValues {
    var popupCloseActions: PopupCloseEnvironmentActions {
        get { self[PopupCloseEnvironmentActionsKey.self] }
        set { self[PopupCloseEnvironmentActionsKey.self] = newValue }
    }
}

extension AppSession {
    func popupCloseActions() -> PopupCloseEnvironmentActions {
        guard isConfigured && isSignedIn else { return PopupCloseEnvironmentActions() }
        var actions = PopupCloseEnvironmentActions()
        if let apiConfig = regionalConfiguration?.apiConfiguration {
            let service = OfficialAttendanceService(configuration: apiConfig, transport: compositionTransport)
            actions.loadAttendance = { [weak self] eventID, organizer in
                guard let self, self.isSignedIn else { return nil }
                return try? await service.fetchAttendance(eventID: eventID, organizer: organizer, token: self.token)
            }
            actions.loadOfficialContact = { [weak self] activityID in
                guard let self, self.isSignedIn else { return nil }
                return await service.fetchContact(activityID: activityID, token: self.token)
            }
            actions.sendAttendanceCommand = { [weak self] eventID, action, fields in
                guard let self, self.isSignedIn else { return nil }
                return try? await service.sendCommand(eventID: eventID, action: action, fields: fields, token: self.token)
            }
        }
        // PC-B-1-1 / X5: offer an owner write only when its endpoint grant is issued; otherwise the row would always fail.
        let grants = publisherLifecycleContext?.client.grants
        if grants?.graduation != nil {
        actions.graduateBetaTopic = { [weak self] topicID in
            guard let self, let context = self.publisherLifecycleContext else {
                return .failure(PublisherLifecycleError.unavailable)
            }
            do {
                _ = try PublishedResource(kind: .topic, value: topicID)
                let coordinator = context.coordinator
                let review = try await coordinator.prepare(.graduate(topicID: topicID))
                let outcome = await coordinator.confirm(review, consequentialApproval: true)
                switch outcome {
                case .acknowledged(let msg, _):
                    return .success(msg ?? "")
                case .rejected(let msg):
                    return .failure(PublisherLifecycleError.rejected(msg))
                case .notSent, .unknown:
                    return .failure(PublisherLifecycleError.unavailable)
                }
            } catch {
                return .failure(error)
            }
        }
        }
        if grants?.ownership != nil {
        actions.loadTransferClubs = { [weak self] in
            guard let self else { return [] }
            switch await self.loadSettingsClubEntry() {
            case .chooseClub(let clubs): return clubs
            case .openClub(let club): return [club]
            case .applyForHost, .failed: return []
            }
        }
        actions.transferTopicToClub = { [weak self] topicID, clubID in
            guard let self, let context = self.publisherLifecycleContext else {
                return .failure(PublisherLifecycleError.unavailable)
            }
            do {
                _ = try PublishedResource(kind: .topic, value: topicID)
                let coordinator = context.coordinator
                let review = try await coordinator.prepare(.transfer(topicID: topicID, clubID: clubID))
                let outcome = await coordinator.confirm(review, consequentialApproval: true)
                switch outcome {
                case .acknowledged(_, let newTopicID):
                    return .success(newTopicID)
                case .rejected(let msg):
                    return .failure(PublisherLifecycleError.rejected(msg))
                case .notSent, .unknown:
                    return .failure(PublisherLifecycleError.unavailable)
                }
            } catch {
                return .failure(error)
            }
        }
        }
        actions.saveUserPhoneAndName = { [weak self] realName, phone in
            guard let self, let config = self.regionalConfiguration?.apiConfiguration,
                  let token = self.token, AuthRequestBuilder.isValidToken(token) else {
                return .failure(APIError.notConfigured)
            }
            let trimmedName = realName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedPhone = phone.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedName.isEmpty, !trimmedPhone.isEmpty else {
                return .failure(APIError.invalidRequest)
            }
            var req = URLRequest(url: config.baseURL.appendingPathComponent("api/user/update"))
            req.httpMethod = "POST"
            req.timeoutInterval = 15
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue(token, forHTTPHeaderField: "Authorization")
            req.httpBody = try? JSONSerialization.data(withJSONObject: ["realName": trimmedName, "phonenumber": trimmedPhone], options: [.sortedKeys])
            do {
                let (_, status) = try await self.compositionTransport.send(req)
                return (200..<300).contains(status) ? .success(()) : .failure(APIError.httpStatus(status))
            } catch {
                return .failure(error)
            }
        }
        actions.loadPlanFallback = { [weak self] activityID, expectedRevision in
            guard let self, let api = self.regionalConfiguration?.apiConfiguration,
                  let token = self.token, AuthRequestBuilder.isValidToken(token) else { return nil }
            let service = PlayExperienceService(configuration: api, transport: self.runtimeHTTPTransport, enabled: [.reads, .directorCommands])
            return try? await service.planFallbackStatus(activityID: activityID, expectedRevision: expectedRevision, token: token)
        }
        actions.submitPlanFallback = { [weak self] activityID, expectedRevision, reason in
            guard let self, let api = self.regionalConfiguration?.apiConfiguration,
                  let token = self.token, AuthRequestBuilder.isValidToken(token) else {
                return .failure(PlayExperienceError.disabled)
            }
            let service = PlayExperienceService(configuration: api, transport: self.runtimeHTTPTransport, enabled: [.reads, .directorCommands])
            do {
                let result = try await service.submitPlanFallback(activityID: activityID, expectedRevision: expectedRevision, reason: reason, token: token)
                return .success(result)
            } catch {
                return .failure(error)
            }
        }
        actions.submitSharedRunAction = { [weak self] activityID, expectedRevision, action, payload in
            guard let self, let api = self.regionalConfiguration?.apiConfiguration,
                  let token = self.token, AuthRequestBuilder.isValidToken(token) else {
                return .failure(PlayExperienceError.disabled)
            }
            let service = PlayExperienceService(configuration: api, transport: self.runtimeHTTPTransport, enabled: [.reads, .directorCommands])
            do {
                return .success(try await service.submitSharedRunAction(activityID: activityID, expectedRevision: expectedRevision,
                                                                        action: action, payload: payload, token: token))
            } catch {
                return .failure(error)
            }
        }
        return actions
    }
}
