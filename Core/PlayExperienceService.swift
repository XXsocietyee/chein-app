import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum PlayExperienceCapability: Hashable {
    /// `capabilityDeclaration` is dormant: it sends `PlayClientCapabilities` on `/api/play/nodes`, which lets the
    /// server refuse to create a new run this build cannot render. Enabling it is an integration acceptance gate.
    case directorCommands, reads, capabilityDeclaration, runPersistence, classicCompletion, hints, leader, advanced, playerCommands, circle, preference, tags, mediaUpload, thoughtClaims, journeyChecks, journeyEggCollection, journeyAsks, journeyOpening
    /// UG-09 / U05-03: bind each new basic command to `GET /api/play/action-context` and, after a
    /// restart, re-read the original receipt by its journaled action id. Reviewed production sets
    /// enable it; fixtures that script exact request order do not.
    case actionContextBinding
}
public enum PlayCompletionEvidence: Codable, Equatable {
    case answer(String)
    case scan(String)
    /// Provider must return GCJ-02 for the source CN arrive contract. No conversion guess.
    case location(longitude: Double, latitude: Double, coordinateSystem: String, accuracyMeters: Double? = nil, measuredAt: Date? = nil)
    case photo(uploadedURL: String)
    case sensor(type: String, payload: [String: PlayWireValue])
    /// Station tap after the run has started. Same `/api/play/arrive` channel, no coordinates.
    case stationArrival
    /// Only for a new command. Recovery encodes the immutable original evidence.
    func validateNewLocationMeasurement(now: Date = Date()) throws {
        if case .location(_, _, _, let accuracy, let time) = self {
            try PlayLocationMeasurement.validate(accuracyMeters: accuracy, measuredAt: time, now: now)
        }
    }
    var path: String {
        switch self {
        case .answer: return "answer"
        case .scan: return "checkin"
        case .location, .stationArrival: return "arrive"
        case .photo: return "photo"
        case .sensor: return "sensor-result"
        }
    }
}
/// Dormant production adapter; enabling a capability is an integration acceptance gate,
/// not user consent. Only fake transports are enabled by this migration's fixtures.
public struct PlayExperienceService {
    let configuration: APIConfiguration
    let transport: any HTTPTransport
    public let enabled: Set<PlayExperienceCapability>
    private let readLifetime: PlayInteractionLifetime?
    public init(configuration: APIConfiguration, transport: any HTTPTransport, enabled: Set<PlayExperienceCapability> = [], readLifetime: PlayInteractionLifetime? = nil) {
        self.configuration = configuration; self.transport = transport; self.enabled = enabled; self.readLifetime = readLifetime
    }
    /// Only an actual bounded reply can prove authentication loss. Malformed or
    /// over-limit envelopes remain ordinary unknown errors, never guessed 401s.
    static func isOffline(_ error: URLError) -> Bool {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .dataNotAllowed, .internationalRoamingOff,
             .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed, .timedOut:
            return true
        default: return false
        }
    }
    public static func isAuthenticationFailure(_ reply: (Data, Int)) -> Bool {
        if reply.1 == 401 { return true }
        guard reply.0.count <= 512 * 1024,
              let envelope = try? JSONDecoder().decode(PlayWireValue.self, from: reply.0) else { return false }
        return envelope["code"].tolerantInteger == 401
    }
    @MainActor public var readLifetimeID: String? { readLifetime?.identity }
    @MainActor public var hasCurrentReadLifetime: Bool { readLifetime?.isCurrent ?? true }
    @MainActor public func bound(to lifetime: PlayInteractionLifetime) -> PlayExperienceService {
        .init(configuration: configuration, transport: transport, enabled: enabled, readLifetime: lifetime)
    }
    @MainActor func checkReadLifetime() throws { try readLifetime?.check() }
    @MainActor private func checkReturnedMode(_ value: Int?) throws { try readLifetime?.checkReturnedMode(value) }
    public func nodes(scope: PlaySessionScope, token: String) async throws -> PlayExperienceDocument {
        var query = try scopeFields(scope)
        if enabled.contains(.capabilityDeclaration) {
            query.merge(PlayClientCapabilities.nodesQuery(clientVersion: PlayClientCapabilities.bundleVersion)) { current, _ in current }
        }
        let document: PlayExperienceDocument = try await request("api/play/nodes", query: query, capability: .reads, token: token).decoded()
        try await checkReturnedMode(document.base.mode)
        if case .topic(let id) = scope, let returnedID = document.base.topicID, returnedID != id { throw PlayExperienceError.malformed }
        return document
    }
    /// Expired free-exploration ticket: read-only visited chapters. Same reads capability as nodes.
    public func freeExplorationHistory(topicID: Int, activityID: Int?, token: String) async throws -> FreeExplorationHistoryDocument {
        guard topicID > 0 else { throw APIError.invalidRequest }
        let raw = try await request("api/play/history", query: ["topicId": String(topicID), "activityId": String(activityID ?? 0)], capability: .reads, token: token)
        return try FreeExplorationHistoryDocument(raw: raw)
    }
    public func route(scope: PlaySessionScope, token: String) async throws -> PlayRouteState {
        let raw = try await request("api/play/route-state", query: scopeFields(scope), capability: .reads, token: token)
        let route: PlayRouteState = try (raw["routeState"].object == nil ? raw : raw["routeState"]).decoded()
        if route.isBranch {
            guard route.nodeStates.values.allSatisfy({ ["HIDDEN", "DISCOVERED_LOCKED", "PLAYABLE", "COMPLETED"].contains($0) }) else { throw PlayExperienceError.malformed }
        }
        return route
    }
    /// Raw payload entry remains useful for sealed in-process fixture recording only.
    /// Network-capable transports require the coordinator's one-shot durable attempt.
    public func complete(scope: PlaySessionScope, nodeID: Int, evidence: PlayCompletionEvidence, advance: PlayRouteAdvance?, token: String) async throws -> PlayWireValue {
        try evidence.validateNewLocationMeasurement()
        let request = try completionRequest(scope: scope, nodeID: nodeID, evidence: evidence, advance: advance, token: token, boundary: UUID().uuidString)
        return try await send(request, capability: .classicCompletion)
    }
    /// Prefab's journal must be written only after all known pre-send checks.
    /// Freshness and synchronous persistence form one preparation step; the exact
    /// request is sent next without aging the already-journaled evidence again.
    @MainActor func completePreparingJournal(scope: PlaySessionScope, nodeID: Int, evidence: PlayCompletionEvidence,
        token: String, measurementNow: () -> Date = Date.init, persist: () throws -> Void) async throws -> PlayWireValue {
        let request = try completionRequest(scope: scope, nodeID: nodeID, evidence: evidence, advance: nil, token: token, boundary: UUID().uuidString)
        return try await send(request, capability: .classicCompletion, beforeTransport: {
            try evidence.validateNewLocationMeasurement(now: measurementNow())
            try persist()
        })
    }
    func completionRequest(scope: PlaySessionScope, nodeID: Int, evidence: PlayCompletionEvidence, advance: PlayRouteAdvance?, token: String, boundary: String, start: [String: String]? = nil) throws -> URLRequest {
        guard nodeID > 0 else { throw APIError.invalidRequest }
        var fields = try scopeFields(scope)
        fields["nodeId"] = String(nodeID)
        switch evidence {
        case .answer(let answer):
            guard !answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidRequest }
            fields["answer"] = answer
        case .scan(let code):
            guard !code.isEmpty else { throw APIError.invalidRequest }
            // A5 (acceptance-r3 wave 6): every checkin carries the reviewed `nodeId`. The backend scopes each
            // basic intent by it (`PlayBasicIntentApplication.basicIntentScope`) before reading the code and
            // refuses a checkin without it (INTENT_INPUT_INVALID "参数有误"); the code still names the store.
            // A journal sent without `nodeId` was refused before any receipt, so nothing replays that shape.
            fields["code"] = code
        case .location(let longitude, let latitude, let coordinateSystem, let accuracyMeters, let measuredAt):
            guard coordinateSystem == "GCJ02", longitude.isFinite, latitude.isFinite,
                  abs(longitude) <= 180, abs(latitude) <= 90 else { throw APIError.invalidRequest }
            // Encoding a durable retry must not refresh or age out its evidence.
            // Freshness is checked before creating a new command, not on replay.
            try PlayLocationMeasurement.validate(accuracyMeters: accuracyMeters, measuredAt: measuredAt, now: nil)
            fields["longitude"] = String(longitude); fields["latitude"] = String(latitude)
            if let accuracyMeters { fields["accuracy"] = String(accuracyMeters) }
            // §23.2: optional `locationTimestamp` (sampling time, epoch ms). Only sent on intents bound
            // to the server action context, so a journal written by an older build replays its
            // original request fingerprint unchanged.
            if advance?.isContextBound == true, let measuredAt, measuredAt.timeIntervalSince1970.isFinite {
                fields["locationTimestamp"] = String(Int64((measuredAt.timeIntervalSince1970 * 1000).rounded(.down)))
            }
        case .stationArrival:
            break
        case .photo(let url):
            guard Self.validHTTPS(url) else { throw APIError.invalidRequest }
            fields["picUrl"] = url
        case .sensor(let type, let payload):
            guard ["still", "steps", "audio_clip"].contains(type), !payload.isEmpty else { throw APIError.invalidRequest }
            var json = scopeJSON(scope); json["nodeId"] = .int(nodeID); json["sensorType"] = .string(type); json["payload"] = .object(payload)
            if let advance {
                json["routeActionId"] = .string(advance.actionID); json["expectedRouteVersion"] = .int(advance.expectedVersion)
                if let session = advance.routeSessionID { json["routeSessionId"] = .int(session) }
                if let instance = advance.runtimeInstance, let epoch = advance.authorityEpoch { json["runtimeInstance"] = .string(instance); json["authorityEpoch"] = .int(epoch) }
            }
            return try makeRequest("api/play/sensor-result", json: json, token: token)
        }
        fields.merge(advance?.fields ?? [:]) { _, new in new }
        // START-r11-1: only the first arrive carries startMode / altStationId (MP pages/play/index.js:6371).
        if let start, evidence.path == "arrive" {
            for key in ["startMode", "altStationId"] { if let value = start[key] { fields[key] = value } }
        }
        return try makeRequest("api/play/" + evidence.path, form: fields, token: token, boundary: boundary)
    }
    public func hint(scope: PlaySessionScope, nodeID: Int, level: Int?, token: String) async throws -> PlayHintReceipt {
        guard nodeID > 0 else { throw APIError.invalidRequest }
        var fields = try scopeFields(scope); fields["nodeId"] = String(nodeID)
        let path: String
        if let level {
            guard (1...2).contains(level) else { throw APIError.invalidRequest }
            fields["level"] = String(level)
            path = "api/play/puzzle/hint"
        } else { path = "api/play/hint/unlock" }
        return try PlayHintReceipt(await request(path, form: fields, capability: .hints, token: token))
    }
    public func reveal(scope: PlaySessionScope, nodeID: Int, advance: PlayRouteAdvance?, token: String) async throws -> PlayWireValue {
        guard nodeID > 0 else { throw APIError.invalidRequest }
        var fields = try scopeFields(scope); fields["nodeId"] = String(nodeID)
        fields.merge(advance?.fields ?? [:]) { _, new in new }
        return try await request("api/play/puzzle/reveal", form: fields, capability: .hints, token: token)
    }
    public func ending(scope: PlaySessionScope, token: String) async throws -> PlayEndingDocument {
        try await request("api/play/ending", query: scopeFields(scope), capability: .reads, token: token).decoded()
    }
    public func leaderboard(scope: PlaySessionScope, token: String) async throws -> PlayCompanionLeaderboard {
        try PlayCompanionLeaderboard(await request("api/play/leaderboard", query: scopeFields(scope), capability: .reads, token: token))
    }
    public func teamProgress(activityID: Int, token: String) async throws -> PlayLeadProgress {
        guard activityID > 0 else { throw APIError.invalidRequest }
        return try PlayLeadProgress(await request("api/club/lead/team-progress", query: ["activityId": String(activityID)], capability: .reads, token: token))
    }
    public func lead(activityID: Int, action: PlayLeadAction, text: String?, token: String) async throws {
        // The chapter release needs its frozen command (`unlockChapter(_:token:)`); the bare form is refused by the server.
        guard activityID > 0, action != .unlockChapter else { throw APIError.invalidRequest }
        var fields = ["activityId": String(activityID)]
        if action == .broadcast {
            guard let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw APIError.invalidRequest }
            fields["text"] = text
        }
        if action == .editTime {
            guard let text, !text.isEmpty else { throw APIError.invalidRequest }
            _ = try await request("api/club/lead/edit-ops", json: ["activityId": .int(activityID), "startDate": .string(text)], capability: .leader, token: token)
        } else {
            _ = try await request("api/club/lead/" + action.rawValue, form: fields, capability: .leader, token: token)
        }
    }
    /// WP-02 `leadUnlock`: POST `{activityId, commandId, expectedChapterId, targetChapterId}`.
    public func unlockChapter(_ command: PlayLeadUnlockCommand, token: String) async throws -> PlayWireValue {
        try await request("api/club/lead/unlock-chapter", form: command.fields, capability: .leader, token: token)
    }
    /// WP-02: GET `{activityId, commandId}`. Code 520 is still pending, never a rejection.
    public func unlockChapterReceipt(_ command: PlayLeadUnlockCommand, token: String) async throws -> PlayWireValue {
        try await request("api/club/lead/unlock-chapter-receipt", query: ["activityId": String(command.activityID), "commandId": command.commandID],
                          capability: .leader, token: token)
    }
    /// WP-02 `leadReleaseStation`: POST `{activityId, memberId, nodeId}`. The member then skips the station with 0 points.
    public func releaseStation(activityID: Int, memberID: Int, nodeID: Int, token: String) async throws {
        guard activityID > 0, memberID > 0, nodeID > 0 else { throw APIError.invalidRequest }
        _ = try await request("api/club/lead/release-station", form: ["activityId": String(activityID), "memberId": String(memberID), "nodeId": String(nodeID)],
                              capability: .leader, token: token)
    }
    public func readPaused(scope: PlaySessionScope, token: String) async throws -> PlayPausedRead {
        try PlayPausedRead(await request("api/play/run-session", query: scopeFields(scope), capability: .reads, token: token))
    }
    public func pausedList(token: String) async throws -> [PlayContinueRun] {
        let raw = try await request("api/play/run-session/list", capability: .reads, token: token)
        guard let rows = raw.array else { throw PlayExperienceError.malformed }
        return rows.compactMap(PlayContinueRun.init)
    }
    public func savePaused(scope: PlaySessionScope, record: PlayPausedRecord, token: String) async throws {
        _ = try await send(pausedRequest(scope: scope, record: record, savedAt: record.savedAt, token: token), capability: .runPersistence)
    }
    public func clearPaused(scope: PlaySessionScope, savedAt: Int64, token: String) async throws {
        _ = try await send(pausedRequest(scope: scope, record: nil, savedAt: savedAt, token: token), capability: .runPersistence)
    }
    func pausedRequest(scope: PlaySessionScope, record: PlayPausedRecord?, savedAt: Int64, token: String) throws -> URLRequest {
        guard savedAt > 0 else { throw APIError.invalidRequest }
        var fields = try scopeFields(scope); fields["savedAt"] = String(savedAt)
        if let record { fields["elapsedSeconds"] = String(record.elapsedSeconds) }
        return try makeRequest("api/play/run-session/" + (record == nil ? "clear" : "save"), form: fields, token: token)
    }
    @MainActor func dispatch(_ attempt: PlayPreparedDispatch) async throws -> PlayWireValue {
        guard attempt.baseURL.absoluteString.utf8.elementsEqual(configuration.baseURL.absoluteString.utf8) else { throw PlayExperienceError.persistenceUnavailable }
        return try await send(attempt.request, capability: attempt.capability, attempt: attempt)
    }
    public func operatingSystem(topicID: Int, token: String) async throws -> PlayWireValue {
        guard topicID > 0 else { throw APIError.invalidRequest }
        let raw = try await request("api/play/os/\(topicID)", capability: .reads, token: token)
        guard raw["topicId"].tolerantInteger == topicID else { throw PlayExperienceError.malformed }
        return raw
    }
    public func revokeTag(tagID: Int, token: String) async throws -> PlayWireValue {
        guard tagID > 0 else { throw APIError.invalidRequest }
        let raw = try await request("api/play/tag/\(tagID)/revoke", postWithoutBody: true, capability: .tags, token: token)
        guard raw["id"].tolerantInteger == tagID, raw["status"].text == "REVOKED" else { throw PlayExperienceError.malformed }
        return raw
    }
    func scopeFields(_ scope: PlaySessionScope) throws -> [String: String] {
        guard scope.isValid else { throw APIError.invalidRequest }; return scope.fields
    }
    func scopeJSON(_ scope: PlaySessionScope) -> [String: PlayWireValue] {
        switch scope { case .activity(let id): return ["activityId": .int(id)]; case .topic(let id): return ["topicId": .int(id)] }
    }
    static func validHTTPS(_ value: String) -> Bool {
        guard let url = URLComponents(string: value), url.scheme == "https", url.host?.isEmpty == false, url.user == nil, url.password == nil else { return false }
        return true
    }
    /// One source request only. There is deliberately no retry or URLSession fallback.
    func request(_ path: String, query: [String: String] = [:], form: [String: String]? = nil,
                 json: [String: PlayWireValue]? = nil, postWithoutBody: Bool = false,
                 capability: PlayExperienceCapability, token: String) async throws -> PlayWireValue {
        try await send(makeRequest(path, query: query, form: form, json: json, postWithoutBody: postWithoutBody, token: token), capability: capability)
    }
    private func makeRequest(_ path: String, query: [String: String] = [:], form: [String: String]? = nil,
                             json: [String: PlayWireValue]? = nil, postWithoutBody: Bool = false,
                             token: String, boundary: String = UUID().uuidString) throws -> URLRequest {
        // Restrict every segment before URL construction: dot/semicolon/backslash/encoded
        // aliases must not bypass the protected-route comparison after server normalization.
        let segments = path.split(separator: "/", omittingEmptySubsequences: false)
        guard segments.first == "api", segments.allSatisfy({ !$0.isEmpty && $0.utf8.allSatisfy {
                  (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95
              } }),
              AuthRequestBuilder.isValidToken(token), !(form != nil && json != nil) else { throw APIError.invalidRequest }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(path))
        request.timeoutInterval = 20; request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(token, forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Accept")
        if !query.isEmpty {
            var components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }; request.url = components.url
        }
        if let form {
            request = try AuthRequestBuilder.makeFormRequest(url: request.url!, fields: form, token: token, boundary: boundary)
        } else if let json {
            request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            // Re-encoding an exact reviewed retry must not reorder dictionary keys.
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
        } else { request.httpMethod = postWithoutBody ? "POST" : "GET" }
        return request
    }
    @MainActor private func send(_ request: URLRequest, capability: PlayExperienceCapability, attempt: PlayPreparedDispatch? = nil, beforeTransport: () throws -> Void = {}) async throws -> PlayWireValue {
        try checkReadLifetime()
        guard enabled.contains(capability) else { throw PlayExperienceError.disabled }
        guard let url = request.url, var route = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw APIError.invalidRequest }
        route.query = nil; route.fragment = nil
        // Journey actions have their own reviewed/journaled coordinators. They are
        // not classic node completion and must not borrow its dispatch capability.
        // Bind the capability in both directions, including the HTTP method.
        let playJourneyRoutes: [(String, PlayExperienceCapability)] = [
            ("check/roll", .journeyChecks), ("check/reroll", .journeyChecks),
            ("check/settle", .journeyChecks), ("egg/collect", .journeyEggCollection),
            ("journey/ask", .journeyAsks), ("journey/opening/complete", .journeyOpening)
        ]
        // NPC dialogue is a journey ask that lives under the AI namespace (h-sys-ainpc); same binding rules.
        let journeyRoutes: [(String, PlayExperienceCapability)] = playJourneyRoutes.map { ("api/play/" + $0.0, $0.1) }
            + [("api/ai/npc/dialogue", PlayExperienceCapability.journeyAsks)]
        let journeyCapability = journeyRoutes.first {
            configuration.baseURL.appendingPathComponent($0.0) == route.url
        }?.1
        if let journeyCapability {
            guard capability == journeyCapability, request.httpMethod == "POST" else { throw PlayExperienceError.persistenceUnavailable }
        } else if [.journeyChecks, .journeyEggCollection, .journeyAsks, .journeyOpening].contains(capability) {
            throw PlayExperienceError.persistenceUnavailable
        }
        let protected = ["answer", "checkin", "arrive", "photo", "sensor-result", "run-session/save", "run-session/clear"].contains { configuration.baseURL.appendingPathComponent("api/play/" + $0) == route.url }
        let basicCommand = ["answer", "checkin", "arrive", "photo", "sensor-result"].contains { configuration.baseURL.appendingPathComponent("api/play/" + $0) == route.url }
        if capability == .classicCompletion || capability == .runPersistence {
            guard protected else { throw PlayExperienceError.persistenceUnavailable }
        }
        if protected {
            if let attempt { try await attempt.consume(request: request, transport: transport) }
            else { guard transport is PlayRecoveryRecordingTransport else { throw PlayExperienceError.persistenceUnavailable } }
        } else if attempt != nil { throw PlayExperienceError.persistenceUnavailable }
        try attempt?.checkLifetime()
        try Task.checkCancellation()
        let data: Data, status: Int
        do {
            try checkReadLifetime()
            try beforeTransport()
            (data, status) = try await transport.send(request)
        } catch {
            // A stale response/error cannot expire or mutate the new context.
            try checkReadLifetime(); throw error
        }
        try checkReadLifetime()
        try Task.checkCancellation()
        try attempt?.checkLifetime()
        let envelope = try? JSONDecoder().decode(PlayWireValue.self, from: data)
        let code = envelope?["code"].tolerantInteger
        if status == 401 || code == 401 { throw PlayExperienceError.unauthorized }
        // A transport error or malformed envelope cannot prove a write was rejected.
        guard (200..<300).contains(status) else { throw PlayExperienceError.unknownResult }
        guard let code else { throw PlayExperienceError.malformed }
        // U05-01 / UG-09: a basic command refusal that carries the B5 contract keeps its machine
        // fields. Older replies (code + msg only) stay the generic rejection.
        // WP-02: a chapter release refused with `intentNotExecuted` keeps that proof for the leader.
        let chapterCommand = configuration.baseURL.appendingPathComponent("api/club/lead/unlock-chapter") == route.url
        if code != 200, basicCommand || chapterCommand, let envelope, let refusal = PlayCommandRefusal(envelope: envelope), refusal.carriesContract { throw refusal }
        guard code == 200 else { throw PlayExperienceError.rejected(code, envelope?["msg"].text) }
        return envelope?["data"] ?? .null
    }

    /// UG-09: identity a new basic command must carry. A read only; it creates no intent.
    @MainActor func actionContext(scope: PlaySessionScope, nodeID: Int, token: String) async throws -> PlayBasicActionContext {
        guard nodeID > 0 else { throw APIError.invalidRequest }
        var query = try scopeFields(scope); query["nodeId"] = String(nodeID)
        return try PlayBasicActionContext(raw: await request("api/play/action-context", query: query, capability: .reads, token: token))
    }
    /// U05-04: `GET /api/play/content-manifest`. Read-only: it does not create a run, record arrival
    /// or grant anything. `revisionID` is passed only when the caller already holds one.
    public func contentManifest(scope: PlaySessionScope, revisionID: Int? = nil, token: String) async throws -> PlayContentManifest {
        var query = try scopeFields(scope)
        if let revisionID { guard revisionID > 0 else { throw APIError.invalidRequest }; query["revisionId"] = String(revisionID) }
        let manifest = try PlayContentManifest(raw: await request("api/play/content-manifest", query: query, capability: .reads, token: token))
        switch scope {
        case .activity(let id): guard manifest.activityID == nil || manifest.activityID == id else { throw PlayExperienceError.malformed }
        case .topic(let id): guard manifest.topicID == id else { throw PlayExperienceError.malformed }
        }
        return manifest
    }
    /// Reads the original write. Code 520 stays pending and is not turned into a rejection.
    @MainActor func originalActionReceipt(scope: PlaySessionScope, nodeID: Int, routeActionID: String, token: String) async throws -> PlayActionReceiptOutcome {
        guard nodeID > 0, let routeActionID = PlayActionReceiptIdentity.retained(original: routeActionID, proposed: routeActionID) else {
            throw APIError.invalidRequest
        }
        guard enabled.contains(.reads) else { throw PlayExperienceError.disabled }
        try checkReadLifetime()
        var query = try scopeFields(scope)
        query["nodeId"] = String(nodeID)
        query["routeActionId"] = routeActionID
        let request = try makeRequest("api/play/action-receipt", query: query, token: token)
        try Task.checkCancellation()
        let data: Data
        let status: Int
        do {
            try checkReadLifetime()
            (data, status) = try await transport.send(request)
        } catch {
            try checkReadLifetime()
            throw error
        }
        try checkReadLifetime()
        try Task.checkCancellation()
        return try PlayActionReceipt.decode(data, status: status, routeActionID: routeActionID)
    }
}

extension PlayExperienceService {
    @MainActor func sharedPlanRequest(activityID: Int, token: String, command: PlaySharedPlanCommand? = nil,
        receipt: Bool = false, finalCheck: () throws -> Void) async throws -> PlayWireValue {
        guard activityID > 0, !receipt || command != nil else { throw APIError.invalidRequest }
        let kind = receipt ? "receipt" : command == nil ? "view" : "command"
        var parts = URLComponents(url: configuration.baseURL.appendingPathComponent("api/game/session/" + kind), resolvingAgainstBaseURL: false)!
        if let command { try command.validate(); guard command.activityID == activityID else { throw APIError.invalidRequest } }
        if kind != "command" {
            parts.queryItems = [.init(name: "activityId", value: String(activityID)), .init(name: "perspective", value: "PLAYER")]
            if let command { parts.queryItems?.append(.init(name: "requestId", value: command.requestID)) }
        }
        var request = URLRequest(url: parts.url!); request.httpMethod = kind == "command" ? "POST" : "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData; request.timeoutInterval = 20
        request.setValue(token, forHTTPHeaderField: "Authorization"); request.setValue("application/json", forHTTPHeaderField: "Accept")
        if kind == "command", let command {
            let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]; request.httpBody = try encoder.encode(command.wire)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return try await send(request, capability: kind == "command" ? .playerCommands : .reads, beforeTransport: finalCheck)
    }
}

/// UG-05…UG-09 hint ladder routes. View and receipt are reads; use and skip spend through the reviewed hint grant.
public enum PlayHelpRoute: Sendable {
    case view, use(level: Int, requestID: String), skip(requestID: String), receipt
}

extension PlayExperienceService {
    /// One request with no retry. A transport error or non-2xx stays `.unknown`; only a 4xx business code is a refusal.
    @MainActor func help(_ route: PlayHelpRoute, runID: Int, nodeID: Int, token: String) async -> PlayHelpReply {
        guard runID > 0, nodeID > 0 else { return .unknown }
        let request: URLRequest
        let capability: PlayExperienceCapability
        do {
            switch route {
            case .view:
                capability = .reads
                request = try makeRequest("api/play/help", query: ["runId": String(runID), "nodeId": String(nodeID)], token: token)
            case .receipt:
                capability = .reads
                request = try makeRequest("api/play/help/receipt", query: ["runId": String(runID), "nodeId": String(nodeID)], token: token)
            case .use(let level, let requestID):
                guard level > 0, PlayHelpRequestID.valid(requestID) else { return .unknown }
                capability = .hints
                request = try makeRequest("api/play/help/use", json: ["runId": .int(runID), "nodeId": .int(nodeID), "level": .int(level),
                                                                       "action": .string("HELP"), "requestId": .string(requestID)], token: token)
            case .skip(let requestID):
                guard PlayHelpRequestID.valid(requestID) else { return .unknown }
                capability = .hints
                request = try makeRequest("api/play/help/skip", json: ["runId": .int(runID), "nodeId": .int(nodeID),
                                                                        "requestId": .string(requestID)], token: token)
            }
        } catch { return .unknown }
        guard enabled.contains(capability), (try? checkReadLifetime()) != nil else { return .unknown }
        do {
            let (data, status) = try await transport.send(request)
            guard (try? checkReadLifetime()) != nil else { return .unknown }
            return PlayHelpReply.classify(data: data, status: status)
        } catch { return .unknown }
    }
}

enum PlayHelpRequestID {
    static func valid(_ value: String) -> Bool {
        !value.isEmpty && value.utf8.count <= 64 && value.utf8.allSatisfy { $0 >= 0x21 && $0 <= 0x7e }
    }
}
