import SwiftUI

@MainActor final class NativeConditionAuthorController: ObservableObject {
    @Published private(set) var revision: UInt64 = 0
    @Published private(set) var errorKey: String?
    private(set) var session: NativeConditionAuthorSession?
    init(host: any NativeConditionAuthorDraftHosting) {
        do { session = try .init(host: host) } catch { errorKey = "nativeCondition.unavailable" }
    }
    var isCurrent: Bool { session?.isCurrent == true }
    var canEdit: Bool {
        guard let session, session.canEdit, session.document.canRoundTrip else { return false }
        if session.document.surface == .routeGraph || session.document.surface == .attributeCondition { return true }
        return session.capture.catalog.component != nil && [.componentCondition, .componentEffects, .componentCheck].contains(session.document.surface)
    }
    var document: NativeConditionAuthorDocument? { isCurrent ? session?.document : nil }
    var issues: [NativeConditionAuthorIssue] { isCurrent ? session?.issues ?? [] : [] }
    var catalog: NativeConditionAuthorCatalog? { isCurrent ? session?.capture.catalog : nil }
    var attributes: [NativeConditionAuthorAttributeReference] {
        guard isCurrent, let document else { return [] }
        var refs = session?.capture.attributes?.references ?? []
        if document.surface == .attributeCondition {
            // Attribute rules may read only their original registered scalar keys. Tags
            // use HAS_TAG, not scalar EQ; sys.* values are not registered attribute keys.
            return refs.filter { $0.type == .number && !$0.key.hasPrefix("tag.") }
        }
        if catalog?.component != nil { return refs }
        for fact in catalog?.numericFacts ?? [] where !refs.contains(where: { $0.key == fact.id }) {
            refs.append(.init(key: fact.id, label: fact.label, type: .number, writable: false))
        }
        // Original graph declarations are source references, never synthesized initial values.
        for (field, type) in [("variables", NativeConditionAuthorAttributeReference.ValueType.number), ("stringVariables", .string)] {
            for key in (document.value.nativeConditionObject?[field]?.nativeConditionObject ?? [:]).keys.sorted() where !refs.contains(where: { $0.key == key }) {
                refs.append(.init(key: key, label: key, type: type, writable: !key.hasPrefix("sys.passed.") && !key.hasPrefix("sys.quest.")))
            }
        }
        for node in catalog?.nodes ?? [] {
            let key = "sys.passed." + node.id
            if !refs.contains(where: { $0.key == key }) { refs.append(.init(key: key, label: node.label + " · " + key, type: .number, writable: false)) }
        }
        return refs
    }
    var edgeReferences: [NativeConditionAuthorOption] {
        guard let document else { return [] }
        if document.surface == .attributeCondition || catalog?.component != nil { return catalog?.edges ?? [] }
        let rows = document.value.nativeConditionObject?["edges"]?.nativeConditionArray ?? []
        return rows.compactMap { $0.nativeConditionObject?["id"]?.nativeConditionText }.map { .init(id: $0, label: $0) }
    }
    func value(_ path: NativeConditionAuthorPath) -> ProjectEditJSON? {
        guard let document else { return nil }; return NativeConditionAuthorTree.value(document.value, at: path)
    }
    func retire() { session?.retire(); errorKey = nil; revision &+= 1 }
    func refresh() { if !isCurrent { session?.retire() }; revision &+= 1 }
    @discardableResult func replace(_ path: NativeConditionAuthorPath, expected: ProjectEditJSON,
                                    with value: ProjectEditJSON, revision capturedRevision: UInt64? = nil) -> Bool {
        do {
            guard let session else { throw NativeConditionAuthorError.staleEditor }
            try session.replace(path: path, expected: expected, replacement: value, revision: capturedRevision ?? session.document.revision)
            errorKey = nil; revision &+= 1; return true
        } catch { errorKey = "nativeCondition.editFailed"; revision &+= 1; return false }
    }
    func setField(_ key: String, at path: NativeConditionAuthorPath, to entry: ProjectEditJSON) {
        guard let original = value(path), var row = original.nativeConditionObject else { return }
        row[key] = entry; _ = replace(path, expected: original, with: .object(row))
    }
    func removeField(_ key: String, at path: NativeConditionAuthorPath) {
        guard let original = value(path), var row = original.nativeConditionObject else { return }
        row.removeValue(forKey: key); _ = replace(path, expected: original, with: .object(row))
    }
    func append(_ entry: ProjectEditJSON, to path: NativeConditionAuthorPath) {
        guard let original = value(path), let array = original.nativeConditionArray else { return }
        _ = replace(path, expected: original, with: .array(array + [entry]))
    }
    func remove(_ offsets: IndexSet, from path: NativeConditionAuthorPath) {
        guard let original = value(path), var array = original.nativeConditionArray, offsets.allSatisfy(array.indices.contains) else { return }
        for i in offsets.sorted(by: >) { array.remove(at: i) }
        _ = replace(path, expected: original, with: .array(array))
    }
    func move(_ offsets: IndexSet, to destination: Int, in path: NativeConditionAuthorPath) {
        guard let original = value(path), var array = original.nativeConditionArray,
              offsets.allSatisfy(array.indices.contains), (0...array.count).contains(destination) else { return }
        array.move(fromOffsets: offsets, toOffset: destination)
        _ = replace(path, expected: original, with: .array(array))
    }
    func save() {
        do { guard let session else { return }; try session.saveOriginalLocalDraft(); errorKey = nil }
        catch { errorKey = "nativeCondition.saveFailed" }
        revision &+= 1
    }
    func read(using reader: any NativeConditionAuthorReadbackServing) async {
        do { try await session?.readAuthoritative(using: reader); errorKey = nil }
        catch { if isCurrent { errorKey = "nativeCondition.readFailed" } }
        revision &+= 1
    }
}
