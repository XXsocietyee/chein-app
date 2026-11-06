import Foundation

public struct NativeAttributeAuthorPending: Codable, Equatable {
    public let request: NativeAttributeAuthorRequest
    public let draft: NativeAttributeAuthorDraft
    public var dispatchStarted: Bool
    public var acknowledged: Bool
    public let deletingKey: String?
    public var validatedTarget: NativeAttributeAuthorValidatedTarget? = nil
    public var receipt: NativeAttributeAuthorMutationReceipt? = nil
    public var lastResponse: Data? = nil
    public var originalRequestProtocol: String? = nil
    public var requiresOriginalContractRecovery: Bool {
        do {
            try request.validateShape()
            if request.isVersionedMutation { return deletingKey == nil && validatedTarget == nil }
            if deletingKey != nil { return false }
            let changed = try draft.changedRows()
            return changed.contains(where: \.isDefinition)
        } catch { return true }
    }
    public init(request: NativeAttributeAuthorRequest, draft: NativeAttributeAuthorDraft, deletingKey: String? = nil) {
        self.request = request; self.draft = draft; dispatchStarted = false; acknowledged = false; self.deletingKey = deletingKey
        originalRequestProtocol = request.isVersionedMutation ? NativeAttributeAuthorRequest.originalRequestProtocol : nil
    }
}
public struct NativeAttributeAuthorRecovery: Codable, Equatable {
    public let version: Int
    public var draft: NativeAttributeAuthorDraft
    public var pending: NativeAttributeAuthorPending?
    public init(draft: NativeAttributeAuthorDraft, pending: NativeAttributeAuthorPending? = nil) {
        version = 1; self.draft = draft; self.pending = pending
    }
}

/// Reuses the original owner-provided storage primitive. A single record contains the local
/// draft and pending mutation; no shared saver, key format or original project journal is changed.
@MainActor public final class NativeAttributeAuthorLocalStore {
    private let storage: any TemplateAuthoringStorage
    public init(storage: any TemplateAuthoringStorage) { self.storage = storage }
    public func load(binding: NativeAttributeAuthorBinding) throws -> NativeAttributeAuthorRecovery? {
        guard let data = try storage.read(binding.storageKey) else { return nil }
        guard data.count <= 4 * 1024 * 1024 else { throw NativeAttributeAuthorError.storage }
        let value = try JSONDecoder().decode(NativeAttributeAuthorRecovery.self, from: data)
        guard value.version == 1, value.draft.binding.storageKey == binding.storageKey else { throw NativeAttributeAuthorError.storage }
        try validate(value, allowHistoricalExtendedPending: true)
        return value
    }
    private func validate(_ value: NativeAttributeAuthorRecovery, allowHistoricalExtendedPending: Bool = false) throws {
        // Rebuild source rows so a corrupted local envelope cannot invent an authoritative baseline.
        let baseline = try NativeAttributeAuthorDraft(binding: value.draft.binding, rawRows: value.draft.rawSource)
        let saved = value.draft.rows.filter { $0.existingKey != nil }
        guard saved.count == baseline.rows.count else { throw NativeAttributeAuthorError.storage }
        var seen = Set<Data>()
        for row in value.draft.rows {
            guard seen.insert(Data(row.key.utf8)).inserted else { throw NativeAttributeAuthorError.storage }
            if let key = row.existingKey {
                guard let original = baseline.rows.first(where: { $0.key.utf8.elementsEqual(key.utf8) }),
                      original.original == row.original, row.key.utf8.elementsEqual(key.utf8),
                      original.isDefinition == row.isDefinition else { throw NativeAttributeAuthorError.storage }
            } else if !row.original.isEmpty { throw NativeAttributeAuthorError.storage }
        }
        if let pending = value.pending {
            guard pending.originalRequestProtocol == nil || (pending.request.isVersionedMutation && pending.originalRequestProtocol == NativeAttributeAuthorRequest.originalRequestProtocol) else { throw NativeAttributeAuthorError.storage }
            guard pending.draft == value.draft, pending.request.binding == value.draft.binding,
                  !pending.acknowledged || pending.dispatchStarted else { throw NativeAttributeAuthorError.storage }
            if allowHistoricalExtendedPending, pending.requiresOriginalContractRecovery,
               pending.deletingKey == nil, pending.request.path == "api/topic/state-keys",
               pending.request.method == .post, pending.request.query.isEmpty,
               try pending.draft.changedRows().contains(where: \.isDefinition) {
                // Preserve the exact historical 8e032fd5 envelope for inspection. This branch
                // can load it, never save/replay it or declare its ignored extensions committed.
                let keys = try pending.draft.changedRows().map { row -> ProjectEditJSON in
                    if row.existingKey == nil || !row.isDefinition { return .object(try row.definition()) }
                    var patch = try row.changes()
                    patch["stateKey"] = .string(row.key); patch["keyType"] = .string(row.keyType); patch["scope"] = .string(row.scope)
                    return .object(patch)
                }
                let body = try NativeAttributeAuthorWire.encode(.object([
                    "topicId": .number(Decimal(pending.request.binding.topicID)), "scope": .string(pending.request.binding.requestScope), "keys": .array(keys)]))
                guard body == pending.request.body else { throw NativeAttributeAuthorError.storage }
                return
            }
            let expected: NativeAttributeAuthorRequest
            if let deleting = pending.deletingKey {
                if pending.request.isVersionedMutation { expected = try .definitionDelete(deleting, binding: pending.draft.binding, requestKey: pending.request.requestKey) }
                else { expected = try .delete(deleting, binding: pending.draft.binding, key: pending.request.requestKey) }
            } else {
                if pending.request.isVersionedMutation {
                    expected = try .definitionsWrite(pending.draft, key: pending.request.requestKey)
                    guard let target = pending.validatedTarget,
                          target == (try NativeAttributeAuthorValidatedTarget(draft: pending.draft, requestKey: pending.request.requestKey, response: target.response)) else {
                        throw NativeAttributeAuthorError.storage
                    }
                } else { expected = try .save(pending.draft.changedRows(), binding: pending.draft.binding, key: pending.request.requestKey) }
            }
            guard expected == pending.request else { throw NativeAttributeAuthorError.storage }
            try pending.request.validateShape()
            if let receipt = pending.receipt {
                guard pending.request.isVersionedMutation, pending.acknowledged, pending.dispatchStarted,
                      receipt == (try NativeAttributeAuthorMutationReceipt(pending: pending, response: receipt.response)) else {
                    throw NativeAttributeAuthorError.storage
                }
            } else if pending.request.isVersionedMutation && pending.acknowledged { throw NativeAttributeAuthorError.storage }
        }
    }
    public func save(_ value: NativeAttributeAuthorRecovery, replacing expected: NativeAttributeAuthorRecovery? = nil) throws {
        try validate(value)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        guard data.count <= 4 * 1024 * 1024 else { throw NativeAttributeAuthorError.storage }
        let previous = try storage.read(value.draft.binding.storageKey)
        if let expected {
            guard expected.draft.binding.storageKey == value.draft.binding.storageKey,
                  previous == (try encoder.encode(expected)) else { throw NativeAttributeAuthorError.storage }
        } else if previous != nil { throw NativeAttributeAuthorError.storage }
        try storage.write(data, key: value.draft.binding.storageKey)
        guard try storage.read(value.draft.binding.storageKey) == data else { throw NativeAttributeAuthorError.storage }
    }
}
