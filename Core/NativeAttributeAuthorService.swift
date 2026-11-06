import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct NativeAttributeAuthorRequest: Codable, Equatable {
    public enum Method: String, Codable { case get = "GET", post = "POST", put = "PUT", delete = "DELETE" }
    public let binding: NativeAttributeAuthorBinding
    /// Registry identity remains local. Newly recorded versioned mutations pair this UUID
    /// with the explicit original request protocol; historical local UUIDs are not adopted.
    public let requestKey: UUID
    public let method: Method
    public let path: String
    public let query: [String: String]
    public let body: Data?
    public var mutates: Bool { method != .get }
    static let registrationFields: Set<String> = ["stateKey","keyType","scope","label","initialValue"]
    static func list(_ binding: NativeAttributeAuthorBinding, key: UUID = UUID()) -> Self {
        .init(binding: binding, requestKey: key, method: .get, path: "api/topic/state-keys",
              query: ["topicId": String(binding.topicID), "scope": binding.requestScope], body: nil)
    }
    static func publishCheck(_ binding: NativeAttributeAuthorBinding, key: UUID) -> Self {
        .init(binding: binding, requestKey: key, method: .get, path: "api/topic/publish-check",
              query: ["topicId": String(binding.topicID), "scope": binding.requestScope], body: nil)
    }
    static func modulePreflight(_ binding: NativeAttributeAuthorBinding, key: UUID) -> Self {
        .init(binding: binding, requestKey: key, method: .get, path: "api/topic/module-preflight",
              query: ["topicId": String(binding.topicID), "scope": binding.requestScope,
                      "expectedConfigVersion": String(binding.sourceConfigVersion)], body: nil)
    }
    static func save(_ rows: [NativeAttributeAuthorRow], binding: NativeAttributeAuthorBinding, key: UUID) throws -> Self {
        let keys = try rows.map { ProjectEditJSON.object(try $0.registrationPayload()) }
        return .init(binding: binding, requestKey: key, method: .post, path: "api/topic/state-keys", query: [:],
            body: try NativeAttributeAuthorWire.encode(.object(["topicId": .number(Decimal(binding.topicID)),
                "scope": .string(binding.requestScope), "keys": .array(keys)])))
    }
    static func delete(_ stateKey: String, binding: NativeAttributeAuthorBinding, key: UUID) throws -> Self {
        guard NativeAttributeAuthorRow.validKey(stateKey) else { throw NativeAttributeAuthorError.invalid("key") }
        return .init(binding: binding, requestKey: key, method: .delete, path: "api/topic/state-keys",
            query: ["topicId": String(binding.topicID), "scope": binding.requestScope, "key": stateKey], body: nil)
    }
    func validateShape() throws {
        guard !binding.isLocked else { throw NativeAttributeAuthorError.staleSource }
        if isOriginalReceiptRead {
            guard body == nil, Set(query.keys) == ["topicId","expectedConfigVersion","scope","requestId","protocolVersion","sessionEpoch","method","payloadSHA256"],
                  query["topicId"] == String(binding.topicID), query["expectedConfigVersion"] == String(binding.sourceConfigVersion),
                  query["scope"] == binding.requestScope, query["requestId"] == requestKey.uuidString.lowercased(),
                  query["protocolVersion"] == Self.originalRequestProtocol, query["sessionEpoch"] == String(binding.epoch),
                  ["POST","DELETE"].contains(query["method"] ?? ""),
                  query["payloadSHA256"]?.range(of: "^[0-9a-f]{64}$", options: .regularExpression) != nil else { throw NativeAttributeAuthorError.invalid("original request GET") }
            return
        }
        if path == "api/topic/attribute-author" || path == "api/topic/attribute-author/validate" || path == "api/topic/attribute-author/references" {
            if method == .get {
                let expected: Self
                if path.hasSuffix("/references") { expected = try Self.definitionReferences(query["key"] ?? "", binding: binding, requestKey: requestKey) }
                else { expected = Self.definitionsList(binding, key: requestKey, inspect: isCurrentInspection) }
                guard path != "api/topic/attribute-author/validate", self == expected else { throw NativeAttributeAuthorError.invalid("versioned GET") }
                return
            }
            if method == .delete {
                guard self == (try Self.definitionDelete(query["key"] ?? "", binding: binding, requestKey: requestKey)) else { throw NativeAttributeAuthorError.invalid("versioned DELETE") }
                return
            }
            guard method == .post, path != "api/topic/attribute-author/references", query.isEmpty, let body,
                  let root = try NativeAttributeAuthorWire.decode(body).object,
                  Set(root.keys) == ["topicId","expectedConfigVersion","scope","keys"],
                  root["topicId"] == .number(Decimal(binding.topicID)), root["scope"] == .string(binding.requestScope),
                  root["expectedConfigVersion"] == .number(Decimal(binding.sourceConfigVersion)),
                  binding.sourceConfigVersion < Int64.max, let rows = root["keys"]?.array,
                  !rows.isEmpty, rows.count <= 32 else { throw NativeAttributeAuthorError.invalid("versioned request DTO") }
            var seen = Set<Data>()
            for raw in rows {
                guard let fields = raw.object, Set(fields.keys).isSubset(of: NativeAttributeAuthorRow.fields),
                      let key = fields["stateKey"]?.text, NativeAttributeAuthorRow.validKey(key),
                      fields["keyType"]?.text == (key.hasPrefix("clue.") ? "flag" : String(key.prefix { $0 != "." })),
                      let scope = fields["scope"]?.text, ["run","party","deployment"].contains(scope),
                      seen.insert(Data(key.utf8)).inserted else { throw NativeAttributeAuthorError.invalid("versioned keys[]") }
            }
            return
        }
        if method == .get {
            let expected: Self
            switch path {
            case "api/topic/state-keys": expected = .list(binding, key: requestKey)
            case "api/topic/publish-check": expected = .publishCheck(binding, key: requestKey)
            case "api/topic/module-preflight": expected = .modulePreflight(binding, key: requestKey)
            default: throw NativeAttributeAuthorError.invalid("unverified author GET route")
            }
            guard self == expected else { throw NativeAttributeAuthorError.invalid("author GET query/body") }
            return
        }
        guard path == "api/topic/state-keys", method == .post || method == .delete else {
            throw NativeAttributeAuthorError.contractMissing("a829 ApiTopicStateKeyController has no PUT or state-keys/validate endpoint")
        }
        if method == .delete {
            guard self == (try Self.delete(query["key"] ?? "", binding: binding, key: requestKey)) else {
                throw NativeAttributeAuthorError.invalid("DELETE query/body")
            }
            return
        }
        guard query.isEmpty, let body, let root = try NativeAttributeAuthorWire.decode(body).object,
              Set(root.keys) == ["topicId","scope","keys"], root["topicId"] == .number(Decimal(binding.topicID)),
              root["scope"] == .string(binding.requestScope), let rows = root["keys"]?.array,
              !rows.isEmpty, rows.count <= 4096 else { throw NativeAttributeAuthorError.invalid("registration keys/topicId/scope") }
        var seen = Set<Data>()
        for raw in rows {
            guard let fields = raw.object, Set(fields.keys).isSubset(of: Self.registrationFields),
                  let key = fields["stateKey"]?.text, seen.insert(Data(key.utf8)).inserted else {
                throw NativeAttributeAuthorError.contractMissing("ThemeStateKey DTO fields only; extension fields may not be sent")
            }
            let row = try NativeAttributeAuthorRow(source: fields)
            _ = try row.registrationPayload()
        }
    }

    /// Mechanical wire conversion for the original approved final-forward adapter. This
    /// constructs no client, credential, capability or grant and performs no HTTP operation.
    public func urlRequest(configuration: APIConfiguration, token: String) throws -> URLRequest {
        try validateShape()
        guard configuration.baseURL.absoluteString.utf8.elementsEqual(binding.server.utf8),
              AuthRequestBuilder.isValidToken(token),
              var components = URLComponents(url: configuration.baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw NativeAttributeAuthorError.staleSource
        }
        if !query.isEmpty {
            components.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) }
        }
        guard let url = components.url else { throw NativeAttributeAuthorError.invalid("author URL") }
        var request = try AuthRequestBuilder.makeFormRequest(url: url, fields: [:], token: token, includesBody: false)
        request.httpMethod = method.rawValue; request.httpBody = body; request.httpShouldHandleCookies = false
        request.setValue(body == nil ? nil : "application/json", forHTTPHeaderField: "Content-Type")
        if isVersionedMutation {
            request.setValue(Self.originalRequestProtocol, forHTTPHeaderField: "X-Attribute-Request-Protocol")
            request.setValue(requestKey.uuidString.lowercased(), forHTTPHeaderField: "X-Attribute-Request-Id")
            request.setValue(originalPayloadSHA256, forHTTPHeaderField: "X-Attribute-Request-SHA256")
            request.setValue(String(binding.epoch), forHTTPHeaderField: "X-Attribute-Session-Epoch")
        }
        return request
    }

}

@MainActor public protocol NativeAttributeAuthorTransport: AnyObject {
    /// The original approved transport must call finalCheck immediately before its actual send.
    /// It owns authentication and its independent reviewed per-route capability; this module creates neither.
    func send(_ request: NativeAttributeAuthorRequest, finalCheck: @escaping @MainActor () throws -> Void) async throws -> (Data, Int)
}

public struct NativeAttributeAuthorReferences: Equatable {
    public let binding: NativeAttributeAuthorBinding
    public let requestKey: UUID
    public let stateKey: String
    public let positions: [String]
    public let incompleteReason: String?
    public init(binding: NativeAttributeAuthorBinding, requestKey: UUID, stateKey: String,
                positions: [String], incompleteReason: String?) {
        self.binding = binding; self.requestKey = requestKey; self.stateKey = stateKey
        self.positions = positions; self.incompleteReason = incompleteReason
    }
    public var permitsDelete: Bool { incompleteReason == nil && positions.isEmpty }
}

/// The original draft/preview/publication flow is injected, never replaced by new endpoints.
public enum NativeAttributeAuthorProjectAction: String, Codable { case saveDraft, preview, publish }
public struct NativeAttributeAuthorProjectReadback {
    public let requestKey: UUID
    public let action: NativeAttributeAuthorProjectAction
    public let originalBinding: NativeAttributeAuthorBinding
    public let binding: NativeAttributeAuthorBinding
    /// For publish this is the original locked dynamicAttributes object, not today's registry rows.
    public let source: Data
    public init(requestKey: UUID, action: NativeAttributeAuthorProjectAction, originalBinding: NativeAttributeAuthorBinding,
                binding: NativeAttributeAuthorBinding, source: Data) {
        self.requestKey = requestKey; self.action = action; self.originalBinding = originalBinding; self.binding = binding; self.source = source
    }
}
@MainActor public protocol NativeAttributeAuthorProjectFlow: AnyObject {
    /// Reuse original command journal/CAS/auth and read back its authoritative receipt and definition source.
    /// Unknown original save/publication results must throw .uncertain and retain that original journal.
    func perform(_ action: NativeAttributeAuthorProjectAction, binding: NativeAttributeAuthorBinding,
                 requestKey: UUID) async throws -> NativeAttributeAuthorProjectReadback
}

@MainActor public final class NativeAttributeAuthorService {
    public typealias ReferenceReader = @MainActor (NativeAttributeAuthorBinding, String, UUID) async throws -> NativeAttributeAuthorReferences
    public typealias LockedReader = @MainActor (NativeAttributeAuthorBinding) async throws -> Data
    private let transport: (any NativeAttributeAuthorTransport)?
    private let current: @MainActor () -> NativeAttributeAuthorBinding?
    private let references: ReferenceReader?
    private let locked: LockedReader?
    private let endpointAllowed: (NativeAttributeAuthorHostEndpoint) -> Bool
    public let contract: NativeAttributeAuthorContract
    public var usesVersionedDefinitions: Bool { contract == .versionedCandidate }
    public init(transport: (any NativeAttributeAuthorTransport)? = nil,
                current: @escaping @MainActor () -> NativeAttributeAuthorBinding?,
                references: ReferenceReader? = nil, locked: LockedReader? = nil,
                contract: NativeAttributeAuthorContract = .legacyRegistry,
                endpointAllowed: @escaping (NativeAttributeAuthorHostEndpoint) -> Bool = { _ in true }) {
        self.transport = transport; self.current = current; self.references = references; self.locked = locked
        self.contract = contract; self.endpointAllowed = endpointAllowed
    }
    /// UI availability only; the original transport independently repeats its live exact
    /// approval at final-forward. No boolean returned here authorizes a network request.
    public func permits(_ endpoint: NativeAttributeAuthorHostEndpoint) -> Bool {
        transport != nil && endpointAllowed(endpoint)
    }
    public var permitsSave: Bool {
        usesVersionedDefinitions ? permits(.validate) && permits(.save) && permits(.requestReceipt) : permits(.legacyRegister)
    }
    public func check(_ binding: NativeAttributeAuthorBinding) throws {
        try Task.checkCancellation()
        guard current() == binding else { throw NativeAttributeAuthorError.staleSource }
    }
    func checkIdentity(_ binding: NativeAttributeAuthorBinding) throws {
        try Task.checkCancellation()
        guard let actual = current(), actual.accountID == binding.accountID, actual.epoch == binding.epoch,
              actual.topicID == binding.topicID,
              zip([actual.server,actual.namespace,actual.authorizationRevision,actual.requestScope],
                  [binding.server,binding.namespace,binding.authorizationRevision,binding.requestScope]).allSatisfy({ pair in
                  pair.0.utf8.elementsEqual(pair.1.utf8)
              }) else { throw NativeAttributeAuthorError.staleSource }
    }
    public func load(_ binding: NativeAttributeAuthorBinding) async throws -> NativeAttributeAuthorDraft {
        try check(binding)
        if binding.isLocked {
            guard let locked else { throw NativeAttributeAuthorError.unavailable("original locked dynamicAttributes reader") }
            let data = try await locked(binding); try check(binding)
            return try Self.frozenDraft(binding: binding, source: data)
        }
        if usesVersionedDefinitions {
            let response = try await executeResponse(.definitionsList(binding))
            let envelope = try NativeAttributeAuthorVersionedEnvelope(response.data, expected: binding, version: binding.sourceConfigVersion)
            return try .init(binding: binding, rawRows: envelope.keys(at: ["data"]))
        }
        let response = try await executeResponse(.list(binding)), root = response.root
        guard let rows = root["data"]?.array else { throw NativeAttributeAuthorError.invalid("state-keys data[]") }
        _ = rows
        return try .init(binding: binding, rawRows: NativeAttributeAuthorWire.fragment(response.data, at: ["data"]))
    }
    /// Local registration-shape validation only. publish-check and module-preflight inspect
    /// saved project data; neither validates the supplied unsaved keys or authorizes a save.
    public func validate(_ draft: NativeAttributeAuthorDraft, key: UUID) async throws -> [String] {
        try check(draft.binding)
        for row in try draft.changedRows() { _ = try row.registrationPayload() }
        return ["nativeAttribute.localRegistrationCheck"]
    }
    public func prepareSave(_ draft: NativeAttributeAuthorDraft, key: UUID) async throws -> (NativeAttributeAuthorRequest, NativeAttributeAuthorValidatedTarget?, [String]) {
        let rows = try draft.changedRows(), dynamic = rows.filter(\.isDefinition)
        if !dynamic.isEmpty {
            guard dynamic.count == rows.count else { throw NativeAttributeAuthorError.mixedBatch }
            guard usesVersionedDefinitions else { throw NativeAttributeAuthorError.contractMissing("versioned attribute-author candidate is not selected") }
            let request = try NativeAttributeAuthorRequest.definitionsWrite(draft, key: key)
            let response = try await executeResponse(.definitionsWrite(draft, key: key, validate: true))
            let target = try NativeAttributeAuthorValidatedTarget(draft: draft, requestKey: key, response: response.data)
            return (request, target, target.warnings)
        }
        let request = try NativeAttributeAuthorRequest.save(rows, binding: draft.binding, key: key)
        return (request, nil, try await validate(draft, key: key))
    }
    public func inspectCurrent(_ binding: NativeAttributeAuthorBinding) async throws -> NativeAttributeAuthorDraft {
        guard usesVersionedDefinitions else { throw NativeAttributeAuthorError.contractMissing("CURRENT inspection requires versioned candidate contract") }
        let response = try await executeResponse(.definitionsList(binding, inspect: true))
        let envelope = try NativeAttributeAuthorVersionedEnvelope(response.data, expected: binding, version: nil)
        return try .init(binding: envelope.binding, rawRows: envelope.keys(at: ["data"]))
    }
    public func publishCheck(_ binding: NativeAttributeAuthorBinding, key: UUID) async throws -> NativeAttributeAuthorPublishCheck {
        let root = try await execute(.publishCheck(binding, key: key))
        guard let rows = root["data"]?.array, rows.count <= 4096 else { throw NativeAttributeAuthorError.invalid("publish-check data[]") }
        return .init(binding: binding, requestKey: key, issues: try rows.enumerated().map { index, raw in
            try NativeAttributeAuthorPublishIssue(index: index, source: raw)
        })
    }
    public func modulePreflight(_ binding: NativeAttributeAuthorBinding, key: UUID) async throws -> NativeAttributeAuthorModulePreflight {
        let root = try await execute(.modulePreflight(binding, key: key))
        guard let report = root["data"], report.object != nil else { throw NativeAttributeAuthorError.invalid("module-preflight data object") }
        return try .init(binding: binding, requestKey: key, report: report)
    }
    public var hasReferenceReadContract: Bool { references != nil || usesVersionedDefinitions }
    func deleteRequest(_ key: String, binding: NativeAttributeAuthorBinding, requestKey: UUID) throws -> NativeAttributeAuthorRequest {
        if usesVersionedDefinitions { return try .definitionDelete(key, binding: binding, requestKey: requestKey) }
        return try .delete(key, binding: binding, key: requestKey)
    }
    public func submit(_ request: NativeAttributeAuthorRequest) async throws {
        guard request.mutates, !request.isVersionedMutation else { throw NativeAttributeAuthorError.invalid("versioned mutations require receipt consumer") }
        _ = try await execute(request)
    }
    public func submitWithReceipt(_ pending: NativeAttributeAuthorPending) async throws -> NativeAttributeAuthorMutationReply {
        guard pending.request.mutates else { throw NativeAttributeAuthorError.invalid("mutation") }
        if pending.request.isVersionedMutation {
            guard pending.originalRequestProtocol == NativeAttributeAuthorRequest.originalRequestProtocol, permits(.requestReceipt) else {
                throw NativeAttributeAuthorError.contractMissing("new original request contract required; old local UUID cannot be replayed")
            }
        }
        let response = try await executeResponse(pending.request)
        if pending.request.isVersionedMutation {
            guard (try? pending.request.verifyOriginalReceipt(response.root)) == "COMMITTED" else { return .unconfirmed(response.data) }
        }
        guard pending.request.isVersionedMutation else { return .legacyAcknowledged }
        if pending.deletingKey != nil,
           let envelope = try? NativeAttributeAuthorVersionedEnvelope(response.data, expected: pending.request.binding, version: pending.request.binding.sourceConfigVersion),
           envelope.root["data"]?.object?["deleted"] == .bool(false) { return .notDeleted }
        do { return .confirmed(try NativeAttributeAuthorMutationReceipt(pending: pending, response: response.data)) }
        catch { return .unconfirmed(response.data) }
    }
    public func recoverOriginal(_ pending: NativeAttributeAuthorPending) async throws -> NativeAttributeAuthorMutationReply {
        guard pending.request.isVersionedMutation, pending.dispatchStarted,
              pending.originalRequestProtocol == NativeAttributeAuthorRequest.originalRequestProtocol else {
            throw NativeAttributeAuthorError.contractMissing("historical local UUID has no original request contract")
        }
        let response = try await executeResponse(.originalReceipt(pending.request))
        guard (try? pending.request.verifyOriginalReceipt(response.root)) == "COMMITTED" else { return .unconfirmed(response.data) }
        if pending.deletingKey != nil,
           let envelope = try? NativeAttributeAuthorVersionedEnvelope(response.data, expected: pending.request.binding, version: pending.request.binding.sourceConfigVersion),
           envelope.root["data"]?.object?["deleted"] == .bool(false) { return .notDeleted }
        do { return .confirmed(try NativeAttributeAuthorMutationReceipt(pending: pending, response: response.data)) }
        catch { return .unconfirmed(response.data) }
    }
    private func execute(_ request: NativeAttributeAuthorRequest) async throws -> [String: ProjectEditJSON] {
        (try await executeResponse(request)).root
    }
    private func executeResponse(_ request: NativeAttributeAuthorRequest) async throws -> (root: [String: ProjectEditJSON], data: Data) {
        try request.validateShape()
        guard permits(try NativeAttributeAuthorHostEndpoint(request: request)) else {
            throw NativeAttributeAuthorError.unavailable("independent original author operation")
        }
        if request.path.hasPrefix("api/topic/attribute-author"), !usesVersionedDefinitions {
            throw NativeAttributeAuthorError.contractMissing("versioned attribute-author candidate contract is not selected")
        }
        if request.isCurrentInspection || request.isOriginalReceiptRead { try checkIdentity(request.binding) } else { try check(request.binding) }
        guard let transport else { throw NativeAttributeAuthorError.unavailable("approved original state-keys transport") }
        let result = try await transport.send(request) { [weak self] in
            guard let self else { throw NativeAttributeAuthorError.staleSource }
            if request.isCurrentInspection || request.isOriginalReceiptRead { try self.checkIdentity(request.binding) } else { try self.check(request.binding) }
        }
        if request.isVersionedMutation || request.isCurrentInspection || request.isOriginalReceiptRead || (usesVersionedDefinitions && request.mutates) { try checkIdentity(request.binding) } else { try check(request.binding) }
        let (data, status) = result
        guard status < 500 else { throw NativeAttributeAuthorError.unconfirmedResponse(data) }
        guard let root = try NativeAttributeAuthorWire.decode(data).object else { throw NativeAttributeAuthorError.invalid("response") }
        guard let code = root["code"]?.integer else { throw NativeAttributeAuthorError.invalid("response.code") }
        if request.isVersionedMutation, code >= 500 { throw NativeAttributeAuthorError.unconfirmedResponse(data) }
        guard (200..<300).contains(status), code == 200 else {
            if request.path.hasPrefix("api/topic/attribute-author"), status == 409 || code == 409 {
                throw NativeAttributeAuthorError.versionConflict(root["msg"]?.text ?? "nativeAttribute.stale")
            }
            throw NativeAttributeAuthorError.rejected(root["msg"]?.text ?? "HTTP \(status)")
        }
        return (root, data)
    }
    public func readReferences(binding: NativeAttributeAuthorBinding, key: String, requestKey: UUID) async throws -> NativeAttributeAuthorReferences {
        try check(binding)
        if usesVersionedDefinitions, !permits(.references) {
            throw NativeAttributeAuthorError.unavailable("independent original references read")
        }
        if references == nil, usesVersionedDefinitions {
            return try await referencePositionsForInspection(binding: binding, key: key, requestKey: requestKey)
        }
        guard let references else {
            throw NativeAttributeAuthorError.unavailable("TopicStateKeyRefService.referencesOf: original authorized reference-position read contract missing; schema2 RPG producer incomplete")
        }
        let value = try await references(binding, key, requestKey); try check(binding)
        if usesVersionedDefinitions, !permits(.references) {
            throw NativeAttributeAuthorError.unavailable("independent original references read")
        }
        guard value.binding == binding, value.requestKey == requestKey, value.stateKey.utf8.elementsEqual(key.utf8),
              value.positions.allSatisfy({ !$0.isEmpty }) else { throw NativeAttributeAuthorError.staleSource }
        return value
    }
    /// Actual route read only. Root's existing ReferenceReader must bind the completed
    /// collector/37 protection composition before any empty result becomes a delete review.
    public func referencePositionsForInspection(binding: NativeAttributeAuthorBinding, key: String, requestKey: UUID) async throws -> NativeAttributeAuthorReferences {
            guard usesVersionedDefinitions else { throw NativeAttributeAuthorError.contractMissing("versioned reference route not selected") }
            let response = try await executeResponse(.definitionReferences(key, binding: binding, requestKey: requestKey))
            let envelope = try NativeAttributeAuthorVersionedEnvelope(response.data, expected: binding, version: binding.sourceConfigVersion)
            guard let data = envelope.root["data"]?.object, data["stateKey"]?.text?.utf8.elementsEqual(key.utf8) == true,
                  let rows = data["positions"]?.array else { throw NativeAttributeAuthorError.invalid("references stateKey/positions") }
            let positions = try rows.map { value -> String in
                guard let position = value.text, !position.isEmpty else { throw NativeAttributeAuthorError.invalid("reference position") }; return position
            }
            return .init(binding: binding, requestKey: requestKey, stateKey: key, positions: positions,
                incompleteReason: "nativeAttribute.referencesIntegrationMissing")
    }
    public nonisolated static func frozenDraft(binding: NativeAttributeAuthorBinding, source: Data) throws -> NativeAttributeAuthorDraft {
        guard case .locked(let version, let provenance, let digest) = binding.source,
              let root = try NativeAttributeAuthorWire.decode(source).object,
              root["schemaVersion"]?.integer == 1, root["definitionVersion"] == .number(Decimal(version)),
              root["sourceConfigVersion"] == .number(Decimal(provenance)), root["sha256"] == .string(digest),
              let rows = root["definitions"]?.array else { throw NativeAttributeAuthorError.invalid("locked dynamicAttributes provenance") }
        // Binding and digest must come from the original authoritative locked snapshot reader.
        // A matching self-reported digest alone is never treated as publication or runtime authority.
        _ = rows
        return try .init(binding: binding, rawRows: NativeAttributeAuthorWire.fragment(source, at: ["definitions"]))
    }
}
