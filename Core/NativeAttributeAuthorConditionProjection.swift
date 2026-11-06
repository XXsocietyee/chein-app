import Foundation

/// The one bridge from actual42 owner-read definitions to41's existing picker. It is a
/// transient, exact-scope projection, not another registry or a grammar/RPG implementation.
@MainActor public final class NativeAttributeAuthorConditionProjection: NativeConditionAuthorAttributePicking {
    private let service: NativeAttributeAuthorService
    private let binding: (NativeConditionAuthorScope) -> NativeAttributeAuthorBinding?
    private var generation = UUID()
    private var cached: NativeConditionAuthorAttributeProjection?
    private var capturedBinding: NativeAttributeAuthorBinding?
    public init(service: NativeAttributeAuthorService,
                binding: @escaping (NativeConditionAuthorScope) -> NativeAttributeAuthorBinding?) {
        self.service = service; self.binding = binding
    }
    public func refresh(for scope: NativeConditionAuthorScope) async throws {
        generation = UUID(); let ticket = generation
        cached = nil; capturedBinding = nil
        guard let expected = binding(scope), expected.accountID == Int64(scope.accountID),
              Data(expected.namespace.utf8) == scope.namespace, expected.epoch == scope.epoch,
              Data(expected.authorizationRevision.utf8) == scope.authorizationRevision else {
            throw NativeConditionAuthorError.staleEditor
        }
        let draft = try await service.load(expected)
        guard !Task.isCancelled, generation == ticket, binding(scope) == expected, draft.binding == expected else {
            throw NativeConditionAuthorError.staleEditor
        }
        var seen = Set<Data>()
        let references = try draft.rows.map { row -> NativeConditionAuthorAttributeReference in
            guard let key = row.existingKey, key.utf8.elementsEqual(row.key.utf8),
                  NativeAttributeAuthorRow.validKey(key), seen.insert(Data(key.utf8)).inserted,
                  row.keyType == (key.hasPrefix("clue.") ? "flag" : String(key.prefix { $0 != "." })) else {
                throw NativeAttributeAuthorError.invalid("original registered attribute identity")
            }
            // The actual32 RouteConditionSchema.numericKeys/withNumericKeys map every original ThemeStateKey
            // to NUMBER. sys.* facts and string declarations are NOT invented from this API.
            return .init(key: key, label: row.label.isEmpty ? key : row.label, type: .number, writable: true)
        }
        let version: Int64
        switch expected.source {
        case .current: version = expected.sourceConfigVersion
        case .locked(let publishedVersion, _, _): version = publishedVersion
        }
        capturedBinding = expected
        cached = .init(scope: scope, definitionVersion: String(version),
                       origin: expected.isLocked ? .publishedDefinition : .currentDefinition, references: references)
    }
    public func references(for scope: NativeConditionAuthorScope) -> NativeConditionAuthorAttributeProjection? {
        guard let cached, cached.scope == scope, let capturedBinding,
              binding(scope) == capturedBinding else { return nil }
        return cached
    }
    public func retire() { generation = UUID(); cached = nil; capturedBinding = nil }
}
