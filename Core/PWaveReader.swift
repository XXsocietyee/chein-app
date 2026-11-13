import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read client for P7, then P1, then P4, then P5.
/// Transport is injected. A production host is refused unless `productionLease` names that host
/// and the capability set is the player-read grant. Affiliate and city-pass reads stay refused.
/// There is no baked response. A feature with no capability grant does not send.
public struct PWaveReader {
    public static let contractExecution = "NOT_RUN"
    public let capabilities: PWaveCapability
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let endpointClass: PWaveEndpointClass
    private let productionLease: PWaveProductionReadLease?

    public enum PWaveEndpointClass: String, Equatable, Sendable {
        case production
        case nonProduction
    }

    public init(configuration: APIConfiguration, transport: any HTTPTransport,
                endpointClass: PWaveEndpointClass, capabilities: PWaveCapability,
                productionLease: PWaveProductionReadLease? = nil) throws {
        let host = (configuration.baseURL.host ?? "").lowercased()
        let production = endpointClass == .production || PWaveProductionBoundary.isProductionHost(host)
        if production {
            guard let productionLease, productionLease.host == host,
                  PWaveProductionBoundary.isProductionHost(host),
                  capabilities.granted.isSubset(of: PWaveProductionReadLease.grantedFeatures) else {
                throw PWaveRefusal.productionEndpoint
            }
            self.productionLease = productionLease
        } else {
            self.productionLease = nil
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

    public func affiliateSummary(token: String, scope: PWaveSessionScope,
                                 currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveAffiliateSummaryFact> {
        if productionLease != nil { throw PWaveRefusal.productionEndpoint }
        return try await performPresentation(feature: .affiliateCenter, token: token, scope: scope, currentScope: currentScope,
                                      request: { try self.makeGET(self.url("api/marketing/affiliate/summary", query: [URLQueryItem(name: "limit", value: String(PWaveAffiliateCenter.limit))]), token: token) },
                                      decode: { PWaveAffiliateCenter.decode(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities) })
    }

    public func issueAffiliateLink(targetType: Int, targetID: String, requestID: String, token: String) throws -> Never {
        _ = (targetType, targetID, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func themeCatalog(_ path: PWaveCatalogPath, fields: [String: String], token: String?, scope: PWaveSessionScope,
                             currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveThemeCollectionFact> {
        try await performPresentation(feature: .themeCollection, token: token, scope: scope, currentScope: currentScope,
                                      request: { try self.catalogRequest(path, fields: fields, token: token) },
                                      decode: { PWaveThemeCollection.decode(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities) })
    }

    public func remindWhenAvailable(id: String, token: String) throws -> Never {
        _ = (id, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func products(city: String? = nil, kind: String? = nil, token: String, scope: PWaveSessionScope,
                         currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveCityPassFact> {
        if productionLease != nil { throw PWaveRefusal.productionEndpoint }
        return try await performPresentation(feature: .cityPass, token: token, scope: scope, currentScope: currentScope,
                                      request: { try self.productList(city: city, kind: kind, token: token) },
                                      decode: { PWaveCityPass.decode(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities, frozenSnapshot: false) })
    }

    public func product(id: String, token: String, scope: PWaveSessionScope,
                        currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveCityPassFact> {
        if productionLease != nil { throw PWaveRefusal.productionEndpoint }
        guard Self.acceptable(id), !id.contains("/"), !id.contains("..") else { throw PWaveRefusal.invalidRequest }
        return try await performPresentation(feature: .cityPass, token: token, scope: scope, currentScope: currentScope,
                                             request: { try self.makeGET(self.url("api/marketing/product").appendingPathComponent(id), token: token) },
                                             decode: { PWaveCityPass.decode(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities, frozenSnapshot: false) })
    }

    public func productOrders(token: String, scope: PWaveSessionScope,
                              currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveCityPassFact> {
        if productionLease != nil { throw PWaveRefusal.productionEndpoint }
        return try await performPresentation(feature: .cityPass, token: token, scope: scope, currentScope: currentScope,
                                      request: { try self.makeGET(self.url("api/marketing/product/orders"), token: token) },
                                      decode: { PWaveCityPass.decode(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities, frozenSnapshot: true) })
    }

    public func quoteProduct(requestID: String, token: String) throws -> Never {
        _ = (requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func orderProduct(requestID: String, token: String) throws -> Never {
        _ = (requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func payProduct(orderNo: String, requestID: String, token: String) throws -> Never {
        _ = (orderNo, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func activateProduct(orderNo: String, topicID: String, token: String) throws -> Never {
        _ = (orderNo, topicID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func claimProductGift(credential: String, requestID: String, token: String) throws -> Never {
        _ = (credential, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func runMemory(activityID: String? = nil, topicID: String? = nil, runID: String? = nil, token: String,
                          scope: PWaveSessionScope, currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveRunMemoryFact> {
        try await performPresentation(feature: .runMemory, token: token, scope: scope, currentScope: currentScope,
                                      request: { try self.scopedGET("api/play/player-journey/memory", activityID: activityID, topicID: topicID, runID: runID, token: token) },
                                      decode: { PWaveRunMemory.decode(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities) })
    }

    public func themeHistory(topicID: String, beforeSessionID: String? = nil, limit: Int? = nil, token: String,
                             scope: PWaveSessionScope, currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveThemeHistoryFact> {
        guard Self.acceptable(topicID) else { throw PWaveRefusal.invalidRequest }
        if let beforeSessionID { guard Self.acceptable(beforeSessionID) else { throw PWaveRefusal.invalidRequest } }
        if let limit { guard limit > 0 else { throw PWaveRefusal.invalidRequest } }
        return try await performPresentation(feature: .runMemory, token: token, scope: scope, currentScope: currentScope,
                                             request: { try self.historyRequest(topicID: topicID, beforeSessionID: beforeSessionID, limit: limit, token: token) },
                                             decode: { PWaveRunMemory.decodeHistory(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities) })
    }

    public func publishMemory(runID: String, requestID: String, token: String) throws -> Never {
        _ = (runID, requestID, token, endpointClass)
        throw PWaveRefusal.writesNotAvailable
    }

    public func questBoard(scopeID: String, limit: Int? = nil, token: String, scope: PWaveSessionScope,
                           currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveQuestBoardFact> {
        guard Self.acceptable(scopeID) else { throw PWaveRefusal.invalidRequest }
        if let limit { guard limit > 0 else { throw PWaveRefusal.invalidRequest } }
        return try await performPresentation(feature: .memberBoard, token: token, scope: scope, currentScope: currentScope,
                                             request: { try self.questRequest(scopeID: scopeID, limit: limit, token: token) },
                                             decode: { PWaveBoards.decodeQuest(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities) })
    }

    public func teamRanking(ownerType: Int, ownerID: String, token: String, scope: PWaveSessionScope,
                            currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveTeamBoardFact> {
        guard ownerType == 1 || ownerType == 2, Self.acceptable(ownerID) else { throw PWaveRefusal.invalidRequest }
        return try await performPresentation(feature: .memberBoard, token: token, scope: scope, currentScope: currentScope,
                                             request: { try self.makeGET(self.url("api/orient/team/ranking", query: [
                                                URLQueryItem(name: "ownerType", value: String(ownerType)),
                                                URLQueryItem(name: "ownerId", value: ownerID)
                                             ]), token: token) },
                                             decode: { PWaveBoards.decodeTeams(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities) })
    }

    public func teamDetail(teamID: String, token: String, scope: PWaveSessionScope,
                           currentScope: @escaping () -> PWaveSessionScope?) async throws -> PWavePresentation<PWaveMemberRankFact> {
        guard Self.acceptable(teamID) else { throw PWaveRefusal.invalidRequest }
        return try await performPresentation(feature: .memberBoard, token: token, scope: scope, currentScope: currentScope,
                                             request: { try self.makeGET(self.url("api/orient/team/detail", query: [URLQueryItem(name: "teamId", value: teamID)]), token: token) },
                                             decode: { PWaveBoards.decodeMembers(data: $0, status: $1, supported: self.capabilities.supportedServerCapabilities) })
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

    private func performPresentation<Ready>(feature: PWaveFeature, token: String?, scope: PWaveSessionScope,
                                           currentScope: @escaping () -> PWaveSessionScope?,
                                           request: () throws -> URLRequest,
                                           decode: (Data, Int) -> PWavePresentation<Ready>) async throws -> PWavePresentation<Ready> {
        guard capabilities.allows(feature) else { return .loading(clientCapabilityPresent: false) }
        guard currentScope() == scope else {
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        }
        if let token, !AuthRequestBuilder.isValidToken(token) { throw PWaveRefusal.invalidRequest }
        switch try await send(try request(), scope: scope, currentScope: currentScope) {
        case .discarded:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        case .failed:
            return PWavePresentation(clientCapabilityPresent: true, serverFactPresent: true,
                                    phase: .error(PWaveErrorFact(httpStatus: nil, businessCode: nil, message: nil, runErrorToken: nil)))
        case .received(let data, let status):
            return decode(data, status)
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

    private func url(_ path: String, query: [URLQueryItem] = []) throws -> URL {
        let built = path.split(separator: "/").reduce(configuration.baseURL) { partial, part in
            partial.appendingPathComponent(String(part))
        }
        guard !query.isEmpty else { return built }
        var parts = URLComponents(url: built, resolvingAgainstBaseURL: false)
        parts?.queryItems = query
        guard let url = parts?.url else { throw PWaveRefusal.invalidRequest }
        return url
    }

    private func catalogRequest(_ path: PWaveCatalogPath, fields: [String: String], token: String?) throws -> URLRequest {
        if productionLease != nil, !PWaveProductionReadLease.catalogPaths.contains(path) {
            throw PWaveRefusal.productionEndpoint
        }
        guard fields.keys.allSatisfy({ PWaveThemeCollection.fields.contains($0) }) else { throw PWaveRefusal.invalidRequest }
        guard fields.values.allSatisfy({ Self.acceptable($0) }) else { throw PWaveRefusal.invalidRequest }
        switch path {
        case .info: if fields["id"] == nil { throw PWaveRefusal.invalidRequest }
        case .ids: if fields["ids"] == nil { throw PWaveRefusal.invalidRequest }
        case .cityList, .list, .map, .filters: break
        }
        var request = URLRequest(url: try url(path.rawValue))
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        if let token {
            guard AuthRequestBuilder.isValidToken(token) else { throw PWaveRefusal.invalidRequest }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        let body = try fields.keys.sorted().map { key -> String in
            try Self.formEscape(key) + "=" + Self.formEscape(fields[key] ?? "")
        }.joined(separator: "&")
        request.httpBody = Data(body.utf8)
        return request
    }

    private func productList(city: String?, kind: String?, token: String) throws -> URLRequest {
        if let city { guard Self.acceptable(city) else { throw PWaveRefusal.invalidRequest } }
        if let kind { guard Self.acceptable(kind) else { throw PWaveRefusal.invalidRequest } }
        var query = [URLQueryItem(name: "limit", value: String(PWaveCityPass.listLimit))]
        if let city { query.append(URLQueryItem(name: "city", value: city)) }
        if let kind { query.append(URLQueryItem(name: "kind", value: kind)) }
        return try makeGET(url("api/marketing/product/list", query: query), token: token)
    }

    private func historyRequest(topicID: String, beforeSessionID: String?, limit: Int?, token: String) throws -> URLRequest {
        var query = [URLQueryItem(name: "topicId", value: topicID)]
        if let beforeSessionID { query.append(URLQueryItem(name: "beforeSessionId", value: beforeSessionID)) }
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try makeGET(url("api/play/theme/history", query: query), token: token)
    }

    private func questRequest(scopeID: String, limit: Int?, token: String) throws -> URLRequest {
        var query = [
            URLQueryItem(name: "scope", value: "quest"),
            URLQueryItem(name: "period", value: "all"),
            URLQueryItem(name: "scopeId", value: scopeID)
        ]
        if let limit { query.append(URLQueryItem(name: "limit", value: String(limit))) }
        return try makeGET(url("api/rank/list", query: query), token: token)
    }

    private static func formEscape(_ raw: String) throws -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = raw.addingPercentEncoding(withAllowedCharacters: allowed) else { throw PWaveRefusal.invalidRequest }
        return encoded
    }
}
