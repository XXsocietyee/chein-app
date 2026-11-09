import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Read client for UG-05 help and UG-07 receipts.
/// Transport is injected. A production endpoint is refused and no live session is opened.
/// There is no baked response. A feature with no capability grant does not send.
/// Help use, skip, hangman submit, and accusation submit are not available: the pack is NOT_RUN.
public struct UGGameplayReader {
    public static let contractExecution = UGGameplay.contractExecution
    public let capabilities: UGCapability
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public enum EndpointClass: String, Equatable, Sendable {
        case production
        case nonProduction
    }

    public init(configuration: APIConfiguration, transport: any HTTPTransport, endpointClass: EndpointClass,
                capabilities: UGCapability) throws {
        let host = configuration.baseURL.host ?? ""
        guard endpointClass != .production, !UGProductionBoundary.isProductionHost(host) else {
            throw UGRefusal.productionEndpoint
        }
        self.configuration = configuration
        self.transport = transport
        self.capabilities = capabilities
    }

    public func help(runID: String, nodeID: String, token: String, scope: UGSessionScope,
                     currentScope: @escaping () -> UGSessionScope?) async throws -> UGPresentation<UGHelpView> {
        try await perform(feature: .hintLadder, token: token, scope: scope, currentScope: currentScope,
                          request: { try self.scopedGET("api/play/help", items: [URLQueryItem(name: "runId", value: try Self.identifier(runID)),
                                                                                URLQueryItem(name: "nodeId", value: try Self.identifier(nodeID))], token: token) },
                          decode: UGHelp.decodeView)
    }

    public func receipt(runID: String, nodeID: String, token: String, scope: UGSessionScope,
                        currentScope: @escaping () -> UGSessionScope?) async throws -> UGPresentation<UGHelpReceiptFact> {
        try await perform(feature: .helpReceipt, token: token, scope: scope, currentScope: currentScope,
                          request: { try self.scopedGET("api/play/help/receipt", items: [URLQueryItem(name: "runId", value: try Self.identifier(runID)),
                                                                                        URLQueryItem(name: "nodeId", value: try Self.identifier(nodeID))], token: token) },
                          decode: UGHelpReceipt.decode)
    }

    public func advancedReceipt(sessionID: String, nodeID: String, token: String, scope: UGSessionScope,
                                currentScope: @escaping () -> UGSessionScope?) async throws -> UGPresentation<UGHelpReceiptFact> {
        try await perform(feature: .helpReceipt, token: token, scope: scope, currentScope: currentScope,
                          request: { try self.scopedGET("api/play/help/advanced/receipt", items: [URLQueryItem(name: "sessionId", value: try Self.identifier(sessionID)),
                                                                                                 URLQueryItem(name: "nodeId", value: try Self.identifier(nodeID))], token: token) },
                          decode: UGHelpReceipt.decode)
    }

    public func useHelp(runID: String, nodeID: String, level: Int, requestID: String, token: String) throws -> Never {
        _ = (runID, nodeID, level, requestID, token)
        throw UGRefusal.writesNotAvailable
    }

    public func skip(runID: String, nodeID: String, requestID: String, token: String) throws -> Never {
        _ = (runID, nodeID, requestID, token)
        throw UGRefusal.writesNotAvailable
    }

    public func submitHangman(requestID: String, token: String) throws -> Never {
        _ = (requestID, token)
        throw UGRefusal.writesNotAvailable
    }

    public func submitAccusation(requestID: String, token: String) throws -> Never {
        _ = (requestID, token)
        throw UGRefusal.writesNotAvailable
    }

    private func perform<Ready>(feature: UGFeature, token: String, scope: UGSessionScope,
                                currentScope: @escaping () -> UGSessionScope?,
                                request: () throws -> URLRequest,
                                decode: (Data, Int) -> UGServerFact<Ready>) async throws -> UGPresentation<Ready> {
        guard capabilities.allows(feature), feature.serverKeys.allSatisfy(capabilities.supportedServerKeys.contains) else {
            return .loading(clientCapabilityPresent: false)
        }
        guard currentScope() == scope else {
            return UGPresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        }
        guard AuthRequestBuilder.isValidToken(token) else { throw UGRefusal.invalidRequest }
        switch try await send(try request(), scope: scope, currentScope: currentScope) {
        case .discarded:
            return UGPresentation(clientCapabilityPresent: true, serverFactPresent: false, phase: nil)
        case .failed:
            return UGPresentation(clientCapabilityPresent: true, serverFactPresent: true,
                                  phase: .error(UGErrorFact(httpStatus: nil, businessCode: nil, message: nil)))
        case .received(let data, let status):
            return UGGate.presentation(feature: feature, capability: capabilities, compatibility: nil, fact: decode(data, status))
        }
    }

    private enum SendOutcome {
        case discarded
        case failed
        case received(Data, Int)
    }

    private func send(_ request: URLRequest, scope: UGSessionScope, currentScope: @escaping () -> UGSessionScope?) async throws -> SendOutcome {
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

    private func scopedGET(_ path: String, items: [URLQueryItem], token: String) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw UGRefusal.invalidRequest }
        var parts = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        parts?.queryItems = items
        guard let url = parts?.url else { throw UGRefusal.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 20
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private static func identifier(_ raw: String) throws -> String {
        guard !raw.isEmpty, raw.count <= 18, raw.allSatisfy(\.isNumber), raw.first != "0" else { throw UGRefusal.invalidRequest }
        return raw
    }
}

public struct UGSessionScope: Equatable, Sendable {
    public let accountID: Int
    public let epoch: UInt64
    public let namespace: String

    /// Account 0 is rejected. It is not a stand-in for an unknown account.
    public init(accountID: Int, epoch: UInt64, namespace: String) throws {
        guard accountID > 0, !namespace.isEmpty, namespace.utf8.count <= 128,
              namespace.unicodeScalars.allSatisfy({ $0.value >= 32 && $0.value != 127 }) else {
            throw UGRefusal.invalidRequest
        }
        self.accountID = accountID
        self.epoch = epoch
        self.namespace = namespace
    }
}

enum UGProductionBoundary {
    static func isProductionHost(_ host: String) -> Bool {
        let host = host.lowercased()
        if host == "47.103.124.64" { return true }
        if host == "chengyinhub.com" || host.hasSuffix(".chengyinhub.com") { return true }
        if host == "chengyinhub.cn" || host.hasSuffix(".chengyinhub.cn") { return true }
        return false
    }
}
