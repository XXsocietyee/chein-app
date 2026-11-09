import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read client for P7, then P1, then P4, then P5.
/// Transport is injected. A production endpoint is refused and no live session is opened.
/// There is no baked response. A feature with no capability grant does not send.
public struct PWaveReader {
    public static let contractExecution = "NOT_RUN"
    public let capabilities: PWaveCapability
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let endpointClass: PWaveEndpointClass

    public enum PWaveEndpointClass: String, Equatable, Sendable {
        case production
        case nonProduction
    }

    public init(configuration: APIConfiguration, transport: any HTTPTransport,
                endpointClass: PWaveEndpointClass, capabilities: PWaveCapability) throws {
        let host = configuration.baseURL.host ?? ""
        guard endpointClass != .production, !PWaveProductionBoundary.isProductionHost(host) else {
            throw PWaveRefusal.productionEndpoint
        }
        self.configuration = configuration
        self.transport = transport
        self.endpointClass = endpointClass
        self.capabilities = capabilities
    }

    public func battleReport(activityID: String? = nil, topicID: String? = nil, runID: String? = nil,
                              token: String, scope: PWaveSessionScope,
                              currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveBattleReportFact> {
        try await perform(feature: .battleReport, token: token, scope: scope, currentScope: currentScope,
                          request: { try self.scopedGET("api/play/player-journey/report", activityID: activityID, topicID: topicID, runID: runID, token: token) },
                          decode: PWaveBattleReport.decode)
    }

    public func referralLanding(credential: String, token: String, scope: PWaveSessionScope,
                                currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveReferralFact> {
        try await perform(feature: .inviteLanding, token: token, scope: scope, currentScope: currentScope,
                          request: { try self.jsonPOST("api/referral/landing/referral", credential: credential, token: token) },
                          decode: PWaveInviteLanding.decodeReferral)
    }

    public func giftLanding(credential: String, token: String, scope: PWaveSessionScope,
                            currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveGiftLandingFact> {
        try await perform(feature: .inviteLanding, token: token, scope: scope, currentScope: currentScope,
                          request: { try self.jsonPOST("api/referral/landing/gift", credential: credential, token: token) },
                          decode: PWaveInviteLanding.decodeGift)
    }

    public func playModes(activityID: String? = nil, topicID: String? = nil, token: String, scope: PWaveSessionScope,
                          currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWavePlayModeFact> {
        guard capabilities.allows(.playMode) else { return .loading(clientCapabilityPresent: false) }
        guard currentScope() == scope else {
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        }
        let request = try scopedGET("api/play/player-journey/choices", activityID: activityID, topicID: topicID, runID: nil, token: token)
        switch try await send(request, scope: scope, currentScope: currentScope) {
        case .discarded:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        case .failed:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: true,
                                    phase: .error(PWaveErrorFact(httpStatus: nil, businessCode: nil, message: nil, runErrorToken: nil)))
        case .received(let data, let status):
            let decision = PWavePlayMode.decode(data: data, status: status,
                                                supportedServerCapabilities: capabilities.supportedServerCapabilities)
            return PWaveGate.presentation(clientCapabilityPresent: decision.serverCapabilitySatisfied, fact: decision.fact,
                                         unsatisfiedServerCapabilities: decision.unsatisfiedServerCapabilities,
                                         serverCapabilitiesDeclared: decision.serverCapabilitiesDeclared)
        }
    }

    public func seats(registrationID: String, token: String, scope: PWaveSessionScope,
                      currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveSeatListFact> {
        try await seatGET(path: "api/play/player-journey/seats", registrationID: registrationID, token: token,
                          scope: scope, currentScope: currentScope)
    }

    public func seatInvitations(registrationID: String, token: String, scope: PWaveSessionScope,
                                currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveSeatListFact> {
        try await seatGET(path: "api/play/seat-invitations", registrationID: registrationID, token: token,
                          scope: scope, currentScope: currentScope)
    }

    public func seatInvitation(id: String, token: String, scope: PWaveSessionScope,
                               currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveSeatListFact> {
        guard !id.isEmpty, !id.contains("/"), !id.contains("..") else { throw PWaveRefusal.invalidRequest }
        guard capabilities.allows(.ticketSeats) else { return .loading(clientCapabilityPresent: false) }
        guard currentScope() == scope else {
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        }
        guard AuthRequestBuilder.isValidToken(token) else { throw PWaveRefusal.invalidRequest }
        let request = try makeGET(configuration.baseURL.appendingPathComponent("api/play/seat-invitations").appendingPathComponent(id), token: token)
        return try await finishSeat(request, scope: scope, currentScope: currentScope)
    }

    public func invite(registrationID: String, seatNo: String? = nil, requestID: String, token: String) throws -> Never {
        _ = (registrationID, seatNo, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func claim(credential: String, requestID: String, token: String) throws -> Never {
        _ = (credential, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func cancel(invitationID: String, requestID: String, token: String) throws -> Never {
        _ = (invitationID, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func release(invitationID: String, requestID: String, token: String) throws -> Never {
        _ = (invitationID, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    private func perform<Ready>(feature: PWaveFeature, token: String, scope: PWaveSessionScope,
                                currentScope: @escaping () -> PWaveSessionScope?,
                                request: () throws -> URLRequest,
                                decode: (Data, Int) -> PWaveServerFact<Ready>) async throws -> PWavePresentation<Ready> {
        guard capabilities.allows(feature) else { return .loading(clientCapabilityPresent: false) }
        guard currentScope() == scope else {
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        }
        guard AuthRequestBuilder.isValidToken(token) else { throw PWaveRefusal.invalidRequest }
        let outcome = try await send(try request(), scope: scope, currentScope: currentScope)
        switch outcome {
        case .discarded:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        case .failed:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: true,
                                    phase: .error(PWaveErrorFact(httpStatus: nil, businessCode: nil, message: nil, runErrorToken: nil)))
        case .received(let data, let status):
            return PWaveGate.presentation(clientCapabilityPresent: true, fact: decode(data, status))
        }
    }

    private enum SendOutcome {
        case discarded
        case failed
        case received(Data, Int)
    }

    private func send(_ request: URLRequest, scope: PWaveSessionScope, currentScope: @escaping () -> PWaveSessionScope?) async throws -> SendOutcome {
        guard currentScope() == scope else { return .discarded }
        do {
            let (data, status) = try await transport.send(request)
            guard currentScope() == scope else { return .discarded }
            return .received(data, status)
        } catch {
            guard currentScope() == scope else { return .discarded }
            return .failed
        }
    }

    private func seatGET(path: String, registrationID: String, token: String, scope: PWaveSessionScope,
                         currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveSeatListFact> {
        guard capabilities.allows(.ticketSeats) else { return .loading(clientCapabilityPresent: false) }
        guard currentScope() == scope else {
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        }
        guard Self.acceptable(registrationID), AuthRequestBuilder.isValidToken(token) else { throw PWaveRefusal.invalidRequest }
        var parts = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        parts?.queryItems = [URLQueryItem(name: "registrationId", value: registrationID)]
        guard let url = parts?.url else { throw PWaveRefusal.invalidRequest }
        return try await finishSeat(try makeGET(url, token: token), scope: scope, currentScope: currentScope)
    }

    private func finishSeat(_ request: URLRequest, scope: PWaveSessionScope,
                            currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveSeatListFact> {
        let outcome = try await send(request, scope: scope, currentScope: currentScope)
        switch outcome {
        case .discarded:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        case .failed:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: true,
                                    phase: .error(PWaveErrorFact(httpStatus: nil, businessCode: nil, message: nil, runErrorToken: nil)))
        case .received(let data, let status):
            return PWaveGate.presentation(clientCapabilityPresent: true, fact: PWaveSeatRead.decode(data: data, status: status))
        }
    }

    private func scopedGET(_ path: String, activityID: String?, topicID: String?, runID: String?, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw PWaveRefusal.invalidRequest }
        let activity = try Self.identifier(activityID)
        let topic = try Self.identifier(topicID)
        let run = try Self.identifier(runID)
        let query: [URLQueryItem]
        switch (activity, topic) {
        case let (activity?, nil):
            query = [URLQueryItem(name: "activityId", value: activity)] + (run.map { [URLQueryItem(name: "runId", value: $0)] } ?? [])
        case let (nil, topic?):
            query = [URLQueryItem(name: "topicId", value: topic)] + (run.map { [URLQueryItem(name: "runId", value: $0)] } ?? [])
        default:
            throw PWaveRefusal.invalidRequest
        }
        var parts = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        parts?.queryItems = query
        guard let url = parts?.url else { throw PWaveRefusal.invalidRequest }
        return try makeGET(url, token: token)
    }

    private func jsonPOST(_ path: String, credential: String, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token), Self.acceptable(credential) else { throw PWaveRefusal.invalidRequest }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["token": credential], options: [.sortedKeys])
        return request
    }

    private func makeGET(_ url: URL, token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw PWaveRefusal.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func identifier(_ raw: String?) throws -> String? {
        guard let raw else { return nil }
        guard acceptable(raw) else { throw PWaveRefusal.invalidRequest }
        return raw
    }

    private static func acceptable(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 256 && value.unicodeScalars.allSatisfy { $0.value >= 32 && $0.value != 127 }
    }
}
