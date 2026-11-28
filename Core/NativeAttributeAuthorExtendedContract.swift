import Foundation

/// Selects a source-backed wire contract, never an authorization or deployment grant.
public enum NativeAttributeAuthorContract: Equatable { case legacyRegistry, versionedCandidate }

public struct NativeAttributeAuthorValidatedTarget: Codable, Equatable {
    public let binding: NativeAttributeAuthorBinding
    public let requestBody: Data
    public let requestKey: UUID
    public let response: Data
    public let definitions: Data
    public let warnings: [String]
    init(draft: NativeAttributeAuthorDraft, requestKey: UUID, response: Data) throws {
        let envelope = try NativeAttributeAuthorVersionedEnvelope(response, expected: draft.binding,
            version: draft.binding.sourceConfigVersion)
        let definitions = try envelope.definitions(at: ["data","definitions"])
        let changed = try draft.changedRows()
        guard !changed.isEmpty, changed.allSatisfy(\.isDefinition) else { throw NativeAttributeAuthorError.invalid("mixed or empty definition batch") }
        guard let source = try NativeAttributeAuthorWire.decode(definitions).array else { throw NativeAttributeAuthorError.invalid("definitions[]") }
        let expected = Set(draft.rows.filter(\.isDefinition).map { Data($0.key.utf8) })
        guard Set(source.compactMap { $0.object?["stateKey"]?.text }.map { Data($0.utf8) }) == expected else {
            throw NativeAttributeAuthorError.invalid("validate definitions are not the complete captured catalog")
        }
        guard let body = try NativeAttributeAuthorRequest.definitionsWrite(draft, key: requestKey).body,
              let commands = try NativeAttributeAuthorWire.decode(body).object?["keys"]?.array,
              let originalRows = try NativeAttributeAuthorWire.decode(draft.rawSource).array else { throw NativeAttributeAuthorError.invalid("definition body") }
        let targetNumbers = try NativeAttributeAuthorWire.numberSpellings(definitions, beneath: [])
        let commandNumbers = try NativeAttributeAuthorWire.numberSpellings(body, beneath: [])
        let sourceNumbers = try NativeAttributeAuthorWire.numberSpellings(draft.rawSource, beneath: [])
        func beneath(_ numbers: [[String]: String], _ prefix: [String]) -> [[String]: String] {
            Dictionary(uniqueKeysWithValues: numbers.compactMap { key, value in key.starts(with: prefix) ? (Array(key.dropFirst(prefix.count)), value) : nil })
        }
        for row in draft.rows where row.isDefinition {
            guard let index = source.firstIndex(where: { $0.object?["stateKey"]?.text == row.key }), let actual = source[index].object,
                  NativeAttributeAuthorWire.same(.object(try row.definition()), .object(actual.filter { NativeAttributeAuthorRow.fields.contains($0.key) })) else {
                throw NativeAttributeAuthorError.invalid("validate did not preserve requested definition")
            }
            let commandIndex = commands.firstIndex(where: { $0.object?["stateKey"]?.text == row.key })
            let originalIndex = originalRows.firstIndex(where: { $0.object?["stateKey"]?.text == row.key })
            for field in actual.keys where NativeAttributeAuthorRow.fields.contains(field) {
                let expectedNumbers: [[String]: String]
                if let commandIndex, commands[commandIndex].object?[field] != nil {
                    expectedNumbers = beneath(commandNumbers, ["keys",String(commandIndex),field])
                } else if let originalIndex { expectedNumbers = beneath(sourceNumbers, [String(originalIndex),field]) }
                else { expectedNumbers = [:] }
                guard beneath(targetNumbers, [String(index),field]) == expectedNumbers else {
                    throw NativeAttributeAuthorError.invalid("validate changed numeric spelling: " + field)
                }
            }
        }
        binding = draft.binding
        requestBody = body; self.requestKey = requestKey; self.response = response; self.definitions = definitions
        warnings = try envelope.warnings()
    }
}

public struct NativeAttributeAuthorMutationReceipt: Codable, Equatable {
    public let requestKey: UUID
    public let originalBinding: NativeAttributeAuthorBinding
    public let binding: NativeAttributeAuthorBinding
    public let response: Data
    public let keys: Data
    public let deletingKey: String?
    init(pending: NativeAttributeAuthorPending, response: Data) throws {
        let request = pending.request, before = request.binding.sourceConfigVersion
        guard request.isVersionedMutation, before < Int64.max else { throw NativeAttributeAuthorError.invalid("versioned mutation") }
        let envelope = try NativeAttributeAuthorVersionedEnvelope(response, expected: request.binding, version: before + 1)
        if pending.originalRequestProtocol != nil {
            guard pending.originalRequestProtocol == NativeAttributeAuthorRequest.originalRequestProtocol,
                  try request.verifyOriginalReceipt(envelope.root) == "COMMITTED" else { throw NativeAttributeAuthorError.invalid("original mutation receipt") }
        }
        let keys = try envelope.keys(at: ["data","keys"])
        if let key = pending.deletingKey {
            guard envelope.root["data"]?.object?["deleted"] == .bool(true),
                  let rows = try NativeAttributeAuthorWire.decode(keys).array,
                  !rows.contains(where: { $0.object?["stateKey"]?.text == key }) else {
                throw NativeAttributeAuthorError.invalid("delete readback not confirmed")
            }
        } else {
            guard let target = pending.validatedTarget, target.binding == pending.draft.binding,
                  target.requestBody == request.body,
                  target.requestKey == request.requestKey else { throw NativeAttributeAuthorError.invalid("missing exact validation target") }
            let definitions = try envelope.definitions(at: ["data","definitions"])
            let actualNumbers = try NativeAttributeAuthorWire.numberSpellings(definitions, beneath: [])
            let targetNumbers = try NativeAttributeAuthorWire.numberSpellings(target.definitions, beneath: [])
            guard NativeAttributeAuthorWire.same(try NativeAttributeAuthorWire.decode(definitions), try NativeAttributeAuthorWire.decode(target.definitions)), actualNumbers == targetNumbers else {
                throw NativeAttributeAuthorError.invalid("complete saved definitions differ from validated target")
            }
            try envelope.verifyDefinitionWire()
            _ = try envelope.warnings()
        }
        requestKey = request.requestKey; originalBinding = request.binding; binding = envelope.binding
        self.response = response; self.keys = keys; deletingKey = pending.deletingKey
    }
    public func readback() throws -> NativeAttributeAuthorDraft { try .init(binding: binding, rawRows: keys) }
}

public enum NativeAttributeAuthorMutationReply {
    case legacyAcknowledged
    case confirmed(NativeAttributeAuthorMutationReceipt)
    case unconfirmed(Data)
    case notDeleted
}

struct NativeAttributeAuthorVersionedEnvelope {
    let raw: Data
    let root: [String: ProjectEditJSON]
    let binding: NativeAttributeAuthorBinding
    static let requiredDefinitionFields: Set<String> = ["stateKey","keyType","scope","label","initialValue","minValue","maxValue","display","sortOrder","visible","persistScope","rules"]
    init(_ raw: Data, expected: NativeAttributeAuthorBinding, version: Int64?) throws {
        guard !expected.isLocked, let root = try NativeAttributeAuthorWire.decode(raw).object,
              root["code"]?.integer == 200, root["topicId"] == .number(Decimal(expected.topicID)),
              let actual = root["configVersion"]?.integer, actual >= 0 else {
            throw NativeAttributeAuthorError.invalid("attribute-author response topicId/configVersion/code")
        }
        if let version, Int64(actual) != version { throw NativeAttributeAuthorError.staleSource }
        self.raw = raw; self.root = root; binding = try expected.currentVersion(Int64(actual))
    }
    func keys(at path: [String]) throws -> Data {
        let data = try NativeAttributeAuthorWire.fragment(raw, at: path)
        let draft = try NativeAttributeAuthorDraft(binding: binding, rawRows: data)
        for row in draft.rows where row.isDefinition {
            guard Self.requiredDefinitionFields.isSubset(of: Set(row.original.keys)) else {
                throw NativeAttributeAuthorError.invalid("incomplete definition in keys readback")
            }
        }
        return data
    }
    func definitions(at path: [String]) throws -> Data {
        let data = try NativeAttributeAuthorWire.fragment(raw, at: path)
        guard let rows = try NativeAttributeAuthorWire.decode(data).array, rows.count <= 32 else {
            throw NativeAttributeAuthorError.invalid("complete definitions array")
        }
        let draft = try NativeAttributeAuthorDraft(binding: binding, rawRows: data)
        guard draft.rows.allSatisfy({ $0.isDefinition && Self.requiredDefinitionFields.isSubset(of: Set($0.original.keys)) }) else {
            throw NativeAttributeAuthorError.invalid("incomplete definition")
        }
        return data
    }
    func warnings() throws -> [String] {
        guard let rows = root["data"]?.object?["warnings"]?.array else { throw NativeAttributeAuthorError.invalid("warnings[]") }
        return try rows.map {
            guard let fields = $0.object, let code = fields["code"]?.text,
                  let path = fields["path"]?.text, let message = fields["message"]?.text else {
                throw NativeAttributeAuthorError.invalid("warnings[].code/path/message")
            }
            return code + " · " + path + ": " + message
        }
    }
    func verifyDefinitionWire() throws {
        guard let definitions = try NativeAttributeAuthorWire.decode(definitions(at: ["data","definitions"])).array,
              let keys = try NativeAttributeAuthorWire.decode(keys(at: ["data","keys"])).array else {
            throw NativeAttributeAuthorError.invalid("definition wire")
        }
        let numbers = try NativeAttributeAuthorWire.numberSpellings(raw, beneath: [])
        func beneath(_ prefix: [String]) -> [[String]: String] {
            Dictionary(uniqueKeysWithValues: numbers.compactMap { key, value in
                key.starts(with: prefix) ? (Array(key.dropFirst(prefix.count)), value) : nil
            })
        }
        for (definitionIndex, rawDefinition) in definitions.enumerated() {
            guard let definition = rawDefinition.object, let key = definition["stateKey"]?.text else {
                throw NativeAttributeAuthorError.invalid("definition wire")
            }
            guard let keyIndex = keys.firstIndex(where: { $0.object?["stateKey"]?.text == key }), let wire = keys[keyIndex].object else {
                throw NativeAttributeAuthorError.invalid("keys omitted a complete definition")
            }
            for (field, value) in definition {
                guard let actual = wire[field], NativeAttributeAuthorWire.same(value, actual),
                      beneath(["data","definitions",String(definitionIndex),field]) == beneath(["data","keys",String(keyIndex),field]) else {
                    throw NativeAttributeAuthorError.invalid("keys missing/stale definition field: " + field)
                }
            }
        }
    }
}

extension NativeAttributeAuthorRequest {
    public static let originalRequestProtocol = "original-attribute-author-request-v1"
    public var isOriginalReceiptRead: Bool { method == .get && path == "api/topic/attribute-author/request" }
    var originalPayloadSHA256: String {
        let payload: Data
        if method == .delete {
            payload = Data("\(binding.topicID)\n\(binding.sourceConfigVersion)\n\(binding.requestScope)\n\(query["key"] ?? "")".utf8)
        } else { payload = body ?? Data() }
        return ProjectEditRequestContract.digest(Data("\(method.rawValue)\napi/topic/attribute-author\n".utf8) + payload)
    }
    static func originalReceipt(_ original: Self) throws -> Self {
        guard original.isVersionedMutation else { throw NativeAttributeAuthorError.invalid("original versioned mutation required") }
        return .init(binding: original.binding, requestKey: original.requestKey, method: .get,
            path: "api/topic/attribute-author/request", query: ["topicId": String(original.binding.topicID),
                "expectedConfigVersion": String(original.binding.sourceConfigVersion), "scope": original.binding.requestScope,
                "requestId": original.requestKey.uuidString.lowercased(), "protocolVersion": originalRequestProtocol,
                "sessionEpoch": String(original.binding.epoch), "method": original.method.rawValue, "payloadSHA256": original.originalPayloadSHA256], body: nil)
    }
    func verifyOriginalReceipt(_ root: [String: ProjectEditJSON]) throws -> String {
        guard let receipt = root["requestReceipt"]?.object,
              receipt["protocolVersion"]?.text == Self.originalRequestProtocol,
              receipt["requestId"]?.text == requestKey.uuidString.lowercased(), receipt["payloadSHA256"]?.text == originalPayloadSHA256,
              receipt["method"]?.text == method.rawValue, receipt["topicId"] == .number(Decimal(binding.topicID)),
              receipt["expectedConfigVersion"] == .number(Decimal(binding.sourceConfigVersion)),
              let state = receipt["state"]?.text, ["COMMITTED","NOT_FOUND","UNKNOWN"].contains(state) else {
            throw NativeAttributeAuthorError.invalid("original attribute request receipt identity")
        }
        return state
    }
    public var isVersionedMutation: Bool { path == "api/topic/attribute-author" && mutates }
    public var isCurrentInspection: Bool { path == "api/topic/attribute-author" && method == .get && query["expectedConfigVersion"] == nil }
    static func definitionsList(_ binding: NativeAttributeAuthorBinding, key: UUID = UUID(), inspect: Bool = false) -> Self {
        var query = ["topicId": String(binding.topicID), "scope": binding.requestScope]
        if !inspect { query["expectedConfigVersion"] = String(binding.sourceConfigVersion) }
        return .init(binding: binding, requestKey: key, method: .get, path: "api/topic/attribute-author", query: query, body: nil)
    }
    static func definitionReferences(_ key: String, binding: NativeAttributeAuthorBinding, requestKey: UUID) throws -> Self {
        guard NativeAttributeAuthorRow.validKey(key) else { throw NativeAttributeAuthorError.invalid("key") }
        var query = definitionsList(binding).query; query["key"] = key
        return .init(binding: binding, requestKey: requestKey, method: .get, path: "api/topic/attribute-author/references", query: query, body: nil)
    }
    static func definitionDelete(_ key: String, binding: NativeAttributeAuthorBinding, requestKey: UUID) throws -> Self {
        let read = try definitionReferences(key, binding: binding, requestKey: requestKey)
        guard binding.sourceConfigVersion < Int64.max else { throw NativeAttributeAuthorError.invalid("configVersion overflow") }
        return .init(binding: binding, requestKey: requestKey, method: .delete, path: "api/topic/attribute-author", query: read.query, body: nil)
    }
    static func definitionsWrite(_ draft: NativeAttributeAuthorDraft, key: UUID, validate: Bool = false) throws -> Self {
        let rows = try draft.changedRows()
        guard !rows.isEmpty, rows.count <= 32, rows.allSatisfy(\.isDefinition), draft.binding.sourceConfigVersion < Int64.max else {
            throw NativeAttributeAuthorError.mixedBatch
        }
        let patches = try rows.map { row -> ProjectEditJSON in
            if row.existingKey == nil { return .object(try row.definition()) }
            var fields = try row.changes(); fields["stateKey"] = .string(row.key)
            fields["keyType"] = .string(row.keyType); fields["scope"] = .string(row.scope); return .object(fields)
        }
        var body = try NativeAttributeAuthorWire.encode(.object(["topicId": .number(Decimal(draft.binding.topicID)),
            "expectedConfigVersion": .number(Decimal(draft.binding.sourceConfigVersion)), "scope": .string(draft.binding.requestScope), "keys": .array(patches)]))
        guard let originals = try NativeAttributeAuthorWire.decode(draft.rawSource).array else {
            throw NativeAttributeAuthorError.invalid("definition body")
        }
        var fragments: [([String], Data)] = []
        for (rowIndex, row) in rows.enumerated() where row.existingKey != nil {
            guard patches[rowIndex].object?["rules"] != nil,
                  let sourceRow = originals.firstIndex(where: { $0.object?["stateKey"]?.text == row.key }),
                  let sourceRules = originals[sourceRow].object?["rules"]?.array else { continue }
            for (ruleIndex, rule) in row.rules.enumerated() {
                guard let originalWhen = rule.original["when"], originalWhen != .null, originalWhen != .array([]),
                      NativeAttributeAuthorWire.sameOptional(rule.condition, originalWhen) else { continue }
                let indices: [Int]
                if let originalIndex = rule.sourceIndex, sourceRules.indices.contains(originalIndex),
                   NativeAttributeAuthorWire.same(sourceRules[originalIndex], .object(rule.original)) { indices = [originalIndex] }
                else { indices = sourceRules.indices.filter { NativeAttributeAuthorWire.same(sourceRules[$0], .object(rule.original)) } }
                let candidates = try indices.map { try NativeAttributeAuthorWire.fragment(draft.rawSource, at: [String(sourceRow),"rules",String($0),"when"]) }
                guard let first = candidates.first, candidates.allSatisfy({ $0 == first }) else {
                    throw NativeAttributeAuthorError.contractMissing("original condition span is ambiguous; reopen with the original32 editor")
                }
                fragments.append((["keys",String(rowIndex),"rules",String(ruleIndex),"when"], first))
            }
        }
        body = try NativeAttributeAuthorWire.replacing(body, fragments: fragments)
        return .init(binding: draft.binding, requestKey: key, method: .post,
            path: validate ? "api/topic/attribute-author/validate" : "api/topic/attribute-author", query: [:], body: body)
    }
}
