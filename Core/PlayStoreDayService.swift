import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Marker for the injected offline DEBUG harness transport. Never a production capability.
public protocol PlayStoreDayOfflineTransport: HTTPTransport {}

public struct PlayStoreDaySession: Equatable {
    public let accountID: Int
    public let epoch: UInt64
    let token: String
    public init(accountID: Int, epoch: UInt64, token: String) throws {
        guard accountID > 0, AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        self.accountID = accountID; self.epoch = epoch; self.token = token
    }
}
public enum PlayStoreDayFailure: Error, Equatable {
    case unavailable, staleSession, signedOut, malformed, failed
    case rejected(String?)
}
/// Source request(): 2xx code 200 confirmed; 5xx/408/no response unknown (readback only); else definite rejection.
public enum PlayStoreDayWriteOutcome: Equatable {
    case confirmed(message: String?, data: PlayWireValue)
    case rejected(String?)
    case unknown
    /// HTTP 5xx or 408 that still carried a server sentence. The write stays unproven; the sentence is shown beside readback.
    case notedUnknown(String)
}
/// pages/play/merchant `arriveRefusal`: why `/api/play/arrive` refused, and which retry the CTA becomes.
public enum PlayStoreDayArriveRefusal: Equatable {
    case tooFar(meters: Int?), accuracyLow, locationMissing, scanRequired
    /// 重新定位 for a location refusal, 扫码解锁 when the store needs its code.
    public var retry: PlayStoreDayArriveRetry { self == .scanRequired ? .scan : .locate }
    static func resolve(errorCode: String?, data: PlayWireValue, root: PlayWireValue) -> Self? {
        switch errorCode ?? "" {
        case "ARRIVE_TOO_FAR":
            let raw = data["distanceMeters"].double ?? root["distanceMeters"].double
            return .tooFar(meters: raw.flatMap { $0.isFinite && $0 > 0 ? Int($0.rounded()) : nil })
        case "ARRIVE_ACCURACY_LOW": return .accuracyLow
        case "ARRIVE_LOCATION_MISSING": return .locationMissing
        case "VISIT_SCAN_REQUIRED": return .scanRequired
        default: return nil
        }
    }
}
public enum PlayStoreDayArriveRetry: String, Equatable { case locate, scan }
public enum PlayStoreDayArriveOutcome: Equatable {
    case write(PlayStoreDayWriteOutcome)
    case refused(PlayStoreDayArriveRefusal)
}

/// Store-day page endpoints exactly as pages/play/merchant: GET api/play/nodes, POST api/play/checkin,
/// api/play/photo, api/play/answer (form) and POST api/compliance/consents(/latest) (JSON).
@MainActor public final class PlayStoreDayService {
    public enum Execution: Equatable { case disabled, injectedOfflineHarness }
    public static let nodesPath = "api/play/nodes"
    public static let checkinPath = "api/play/checkin"
    /// PLAYM-1: F08 「我已到店」 — one foreground GCJ-02 fix; the server judges the 300 m radius.
    public static let arrivePath = "api/play/arrive"
    public static let photoPath = "api/play/photo"
    public static let answerPath = "api/play/answer"
    public static let actionContextPath = "api/play/action-context"
    public static let consentLatestPath = "api/compliance/consents/latest"
    public static let consentWritePath = "api/compliance/consents"
    private let configuration: APIConfiguration?
    private let transport: any HTTPTransport
    private let market: RegionalMarket
    private let gates: MerchantCityNPCParityGates
    private let execution: Execution
    private let readsEnabled: Bool
    private let currentSession: () -> PlayStoreDaySession?
    private let onUnauthorized: (PlayStoreDaySession) -> Void
    public init(configuration: APIConfiguration?, transport: any HTTPTransport, market: RegionalMarket,
                gates: MerchantCityNPCParityGates = .disabled, execution: Execution = .disabled, readsEnabled: Bool = false,
                currentSession: @escaping () -> PlayStoreDaySession?, onUnauthorized: @escaping (PlayStoreDaySession) -> Void = { _ in }) {
        self.configuration = configuration; self.transport = transport; self.market = market; self.gates = gates
        self.execution = execution; self.readsEnabled = readsEnabled; self.currentSession = currentSession; self.onUnauthorized = onUnauthorized
    }
    private var offline: Bool { execution == .injectedOfflineHarness && transport is any PlayStoreDayOfflineTransport }
    public var isConfigured: Bool { configuration != nil }
    public var permitsReads: Bool { configuration != nil && (readsEnabled || offline) }
    public var permitsProofWrites: Bool {
        guard configuration != nil else { return false }
        if offline { return true }
        return gates.storeDayProofWrites && [Self.checkinPath, Self.photoPath, Self.answerPath].allSatisfy { gates.allows($0, market: market) }
    }
    public var permitsConsentWrites: Bool {
        guard configuration != nil else { return false }
        if offline { return true }
        return gates.storeDayConsentWrites && gates.allows(Self.consentWritePath, market: market)
    }
    public var session: PlayStoreDaySession? { currentSession() }

    // MARK: Reads
    /// Authoritative row for one node; nil when the current nodes response no longer lists it.
    public func node(scope: PlaySessionScope, nodeID: Int) async throws -> PlayStoreDayNode? {
        guard permitsReads else { throw PlayStoreDayFailure.unavailable }
        guard scope.isValid, nodeID > 0, let session = currentSession() else { throw PlayStoreDayFailure.staleSession }
        let request = try makeRequest(Self.nodesPath, query: scope.fields, session: session)
        let (bytes, status) = try await transport.send(request)
        try ensure(session)
        if status == 401 { onUnauthorized(session); throw PlayStoreDayFailure.signedOut }
        guard (200..<300).contains(status) else { throw PlayStoreDayFailure.failed }
        let envelope = try decodeEnvelope(bytes)
        if envelope.code == 401 { onUnauthorized(session); throw PlayStoreDayFailure.signedOut }
        guard envelope.code == 200 else { throw PlayStoreDayFailure.rejected(envelope.message) }
        let rows = envelope.data["nodes"].array ?? envelope.data.array ?? []
        return rows.first { $0["nodeId"].tolerantInteger == nodeID }.flatMap(PlayStoreDayNode.init(row:))
    }
    /// `pages/play/merchant` `_readbackConsent`: JSON `{docType, scene, scopeType, scopeId}`.
    public static func consentLatestContract(merchantID: Int) -> [String: Any]? {
        guard merchantID > 0 else { return nil }
        return try? PlayStoreDayConsent.subject(merchantID: merchantID).fields()
    }
    /// `_writeAndReadbackConsent`: that subject plus `eventType` and `requestId`.
    public static func consentWriteContract(merchantID: Int, event: ComplianceEvent, requestID: String) -> [String: Any]? {
        guard merchantID > 0, !requestID.isEmpty, requestID.count <= 64,
              var body = consentLatestContract(merchantID: merchantID) else { return nil }
        body["eventType"] = event.rawValue
        body["requestId"] = requestID
        return body
    }
    public func latestConsent(merchantID: Int) async throws -> ComplianceConsent? {
        guard permitsReads else { throw PlayStoreDayFailure.unavailable }
        guard let body = Self.consentLatestContract(merchantID: merchantID), let session = currentSession() else { throw PlayStoreDayFailure.staleSession }
        let request = try makeJSONRequest(Self.consentLatestPath, body: body, session: session)
        let (bytes, status) = try await transport.send(request)
        try ensure(session)
        if status == 401 { onUnauthorized(session); throw PlayStoreDayFailure.signedOut }
        guard (200..<300).contains(status) else { throw PlayStoreDayFailure.failed }
        let envelope = try decodeEnvelope(bytes)
        guard envelope.code == 200 else { throw PlayStoreDayFailure.rejected(envelope.message) }
        guard let object = envelope.data.object, !object.isEmpty, object["eventType"]?.text != nil else { return nil }
        do { return try envelope.data.decoded(ComplianceConsent.self) } catch { throw PlayStoreDayFailure.malformed }
    }

    // MARK: Writes (dispatched only when permitted; never retried here)
    public func checkin(scope: PlaySessionScope, nodeID: Int, code: String) async -> PlayStoreDayWriteOutcome {
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nodeID > 0, !trimmed.isEmpty else { return .rejected(nil) }
        // A1 (acceptance-r3): the backend binds a checkin to the node the player is on (`nodeId`) and
        // refuses it without the run identity; the code still names the store server-side.
        return await proofWrite(Self.checkinPath, scope: scope, nodeID: nodeID, fields: ["nodeId": String(nodeID), "code": trimmed])
    }
    /// MP `requestArrive`: nodeId + longitude / latitude (GCJ-02) + accuracy on the same run identity as the other proofs.
    public func arrive(scope: PlaySessionScope, nodeID: Int, longitude: Double, latitude: Double, accuracy: Double?) async -> PlayStoreDayArriveOutcome {
        guard nodeID > 0, longitude.isFinite, latitude.isFinite, abs(longitude) <= 180, abs(latitude) <= 90 else { return .write(.rejected(nil)) }
        guard offline || gates.allows(Self.arrivePath, market: market) else { return .write(.rejected(nil)) }
        var fields = ["nodeId": String(nodeID), "longitude": String(longitude), "latitude": String(latitude)]
        if let accuracy, accuracy.isFinite, accuracy >= 0 { fields["accuracy"] = String(accuracy) }
        var refusal: PlayStoreDayArriveRefusal?
        let outcome = await proofWrite(Self.arrivePath, scope: scope, nodeID: nodeID, fields: fields) { root in
            refusal = PlayStoreDayArriveRefusal.resolve(errorCode: root["errorCode"].text, data: root["data"], root: root)
        }
        if case .rejected = outcome, let refusal { return .refused(refusal) }
        return .write(outcome)
    }
    /// `pages/play/merchant` `uploadProof` → `requestPhoto`: form `activityId` or `topicId`, plus `nodeId` and `picUrl`.
    /// The live `photo` write still attaches the action-context identity when proof writes are permitted.
    public static func photoContract(scope: PlaySessionScope, nodeID: Int, pictureURL: String) -> [String: String]? {
        guard scope.isValid, nodeID > 0, let url = URL(string: pictureURL), url.scheme == "https", url.host?.isEmpty == false else { return nil }
        var fields = scope.fields
        fields["nodeId"] = String(nodeID)
        fields["picUrl"] = pictureURL
        return fields
    }
    public func photo(scope: PlaySessionScope, nodeID: Int, pictureURL: String) async -> PlayStoreDayWriteOutcome {
        guard nodeID > 0, let url = URL(string: pictureURL), url.scheme == "https", url.host?.isEmpty == false else { return .rejected(nil) }
        return await proofWrite(Self.photoPath, scope: scope, nodeID: nodeID, fields: ["nodeId": String(nodeID), "picUrl": pictureURL])
    }
    public func answer(scope: PlaySessionScope, nodeID: Int, answer: String) async -> PlayStoreDayWriteOutcome {
        let trimmed = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard nodeID > 0, !trimmed.isEmpty else { return .rejected(nil) }
        return await proofWrite(Self.answerPath, scope: scope, nodeID: nodeID, fields: ["nodeId": String(nodeID), "answer": trimmed])
    }
    public func consent(merchantID: Int, event: ComplianceEvent, requestID: String) async -> PlayStoreDayWriteOutcome {
        guard permitsConsentWrites, let session = currentSession(),
              let body = Self.consentWriteContract(merchantID: merchantID, event: event, requestID: requestID),
              let request = try? makeJSONRequest(Self.consentWritePath, body: body, session: session) else { return .rejected(nil) }
        return await dispatch(request, session: session)
    }
    private func proofWrite(_ path: String, scope: PlaySessionScope, nodeID: Int, fields: [String: String],
                            inspect: ((PlayWireValue) -> Void)? = nil) async -> PlayStoreDayWriteOutcome {
        guard permitsProofWrites, scope.isValid, let session = currentSession(), let configuration else { return .rejected(nil) }
        // A1 (acceptance-r3): read the run identity first. Nothing is written when it cannot be read.
        let context: PlayBasicActionContext
        switch await actionContext(scope: scope, nodeID: nodeID, session: session) {
        case .success(let value): context = value
        case .failure(let refusal): return refusal
        }
        var identity = ["routeActionId": UUID().uuidString, "expectedRouteVersion": String(context.expectedRouteVersion),
                        "routeSessionId": String(context.routeSessionID)]
        if let instance = context.runtimeInstance, let epoch = context.authorityEpoch {
            identity["runtimeInstance"] = instance; identity["authorityEpoch"] = String(epoch)
        }
        let all = scope.fields.merging(fields) { _, new in new }.merging(identity) { _, new in new }
        guard let request = try? AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(path), fields: all, token: session.token) else { return .rejected(nil) }
        return await dispatch(request, session: session, inspect: inspect)
    }
    private enum ContextRead { case success(PlayBasicActionContext), failure(PlayStoreDayWriteOutcome) }
    /// `GET api/play/action-context`. A read: every failure here is a definite "not sent".
    private func actionContext(scope: PlaySessionScope, nodeID: Int, session: PlayStoreDaySession) async -> ContextRead {
        var query = scope.fields; query["nodeId"] = String(nodeID)
        guard nodeID > 0, let request = try? makeRequest(Self.actionContextPath, query: query, session: session) else { return .failure(.rejected(nil)) }
        guard let response = try? await transport.send(request), currentSession() == session else { return .failure(.rejected(nil)) }
        let (bytes, status) = response
        if status == 401 { onUnauthorized(session); return .failure(.rejected(nil)) }
        guard (200..<300).contains(status), let envelope = try? decodeEnvelope(bytes) else { return .failure(.rejected(nil)) }
        guard envelope.code == 200 else { return .failure(.rejected(envelope.message)) }
        guard let context = try? PlayBasicActionContext(raw: envelope.data) else { return .failure(.rejected(nil)) }
        return .success(context)
    }
    private func dispatch(_ request: URLRequest, session: PlayStoreDaySession, inspect: ((PlayWireValue) -> Void)? = nil) async -> PlayStoreDayWriteOutcome {
        let response: (Data, Int)
        do { response = try await transport.send(request) } catch { return .unknown }
        let (bytes, status) = response
        if let inspect, let root = try? JSONDecoder().decode(PlayWireValue.self, from: bytes) { inspect(root) }
        guard currentSession() == session else { return .unknown }
        if status == 401 { onUnauthorized(session); return .rejected(nil) }
        if status >= 500 || status == 408, let note = serverSentence(bytes) { return .notedUnknown(note) }
        if status >= 500 || status == 408 { return .unknown }
        guard (200..<300).contains(status), let envelope = try? decodeEnvelope(bytes) else { return (200..<300).contains(status) ? .unknown : .rejected(nil) }
        return envelope.code == 200 ? .confirmed(message: envelope.message, data: envelope.data) : .rejected(envelope.message)
    }

    // MARK: Plumbing
    private func serverSentence(_ bytes: Data) -> String? {
        let root = try? JSONDecoder().decode(PlayWireValue.self, from: bytes)
        return PlayerGapReply.sentence(root?["msg"].text)
    }
    private struct Envelope { let code: Int; let message: String?; let data: PlayWireValue }
    private func decodeEnvelope(_ bytes: Data) throws -> Envelope {
        guard let root = try? JSONDecoder().decode(PlayWireValue.self, from: bytes), let code = root["code"].tolerantInteger else { throw PlayStoreDayFailure.malformed }
        return Envelope(code: code, message: root["msg"].text, data: root["data"])
    }
    private func ensure(_ session: PlayStoreDaySession) throws {
        guard !Task.isCancelled, currentSession() == session else { throw PlayStoreDayFailure.staleSession }
    }
    private func makeRequest(_ path: String, query: [String: String], session: PlayStoreDaySession) throws -> URLRequest {
        guard let configuration, var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else { throw PlayStoreDayFailure.unavailable }
        components.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        guard let url = components.url else { throw PlayStoreDayFailure.malformed }
        var request = URLRequest(url: url); request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 20
        request.setValue(session.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }
    /// Compliance endpoints are @RequestBody: JSON with an explicit Content-Type.
    private func makeJSONRequest(_ path: String, body: [String: Any], session: PlayStoreDaySession) throws -> URLRequest {
        guard let configuration else { throw PlayStoreDayFailure.unavailable }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path)); request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 20
        request.setValue(session.token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: .sortedKeys)
        return request
    }
}
