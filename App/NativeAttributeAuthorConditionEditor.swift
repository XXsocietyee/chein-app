import SwiftUI

/// Connects the existing42 rules.when consumer to41's original recursive expression UI.
/// The original attribute coordinator remains the only local saver; this owns no journal,
/// transport, evaluator, remote writer, or source/catalog authorization.
@MainActor final class NativeAttributeAuthorConditionEditor: NativeAttributeAuthorConditionEditing {
    private let source: (NativeAttributeAuthorBinding) -> (NativeConditionAuthorScope, NativeConditionAuthorCatalog)?
    private let refreshSource: (() async throws -> Void)?
    init(source: @escaping (NativeAttributeAuthorBinding) -> (NativeConditionAuthorScope, NativeConditionAuthorCatalog)?,
         refreshSource: (() async throws -> Void)? = nil) {
        self.source = source; self.refreshSource = refreshSource
    }
    /// Shared production path for the asynchronous destination and its source regression.
    func loadHost(condition: ProjectEditJSON?, binding: NativeAttributeAuthorBinding, registeredKeys: [String],
                  isCurrent: @escaping () -> Bool, save: @escaping (ProjectEditJSON?) -> Bool) async throws -> NativeAttributeAuthorConditionDraftHost {
        guard isCurrent() else { throw NativeAttributeAuthorError.staleSource }
        if let refreshSource { try await refreshSource() }
        try Task.checkCancellation()
        guard let host = NativeAttributeAuthorConditionDraftHost(condition: condition, binding: binding,
            registeredKeys: registeredKeys, source: source, isCurrent: isCurrent, save: save) else {
            throw NativeAttributeAuthorError.staleSource
        }
        return host
    }
    func editor(condition: ProjectEditJSON?, binding: NativeAttributeAuthorBinding,
                registeredKeys: [String], isCurrent: @escaping () -> Bool,
                save: @escaping (ProjectEditJSON?) -> Bool) -> AnyView {
        if refreshSource != nil {
            return AnyView(NativeAttributeAuthorConditionCatalogDestination(makeHost: { [self] in
                try await loadHost(condition: condition, binding: binding, registeredKeys: registeredKeys,
                                   isCurrent: isCurrent, save: save)
            }))
        }
        guard let host = NativeAttributeAuthorConditionDraftHost(condition: condition, binding: binding,
            registeredKeys: registeredKeys, source: source, isCurrent: isCurrent, save: save) else {
            return AnyView(Text("nativeCondition.unavailable"))
        }
        return AnyView(NativeConditionAuthorView(host: host))
    }
}

/// The ordinary42 condition NavigationLink loads its real private source before constructing
/// the existing41 editor. Failed/cancelled reads never expose an old or fabricated catalog.
@MainActor private struct NativeAttributeAuthorConditionCatalogDestination: View {
    let makeHost: () async throws -> NativeAttributeAuthorConditionDraftHost
    @State private var host: NativeAttributeAuthorConditionDraftHost?
    @State private var loading = false
    @State private var failed = false
    @State private var retry = 0
    @State private var generation = UUID()
    var body: some View {
        Group {
            if let host { NativeConditionAuthorView(host: host) }
            else if loading { ProgressView() }
            else if failed {
                VStack {
                    Text("nativeCondition.readFailed")
                    Button("nativeCondition.readAuthoritative") { retry += 1 }.disabled(loading)
                }
            }
        }
        .navigationTitle("nativeCondition.title").navigationBarTitleDisplayMode(.inline)
        .task(id: retry) { if host == nil { await load() } }
    }
    private func load() async {
        generation = UUID(); let ticket = generation
        loading = true; host = nil; failed = false
        defer { if generation == ticket { loading = false } }
        do {
            let value = try await makeHost()
            guard !Task.isCancelled, generation == ticket else { return }
            host = value
        } catch { if !Task.isCancelled, generation == ticket { failed = true } }
        // Do not discard host onDisappear: pushing41's nested field editor is not an
        // abandoned edit. Its same-source guards still retire it when identity changes.
    }
}

/// A single retained editing visit. Captures exact source/catalog and draft key set, and
/// rejects a stale row, retired Project model, account switch, or failed original local save.
@MainActor final class NativeAttributeAuthorConditionDraftHost: NativeConditionAuthorDraftHosting {
    private let binding: NativeAttributeAuthorBinding
    private let scope: NativeConditionAuthorScope
    private let catalog: NativeConditionAuthorCatalog
    private let projection: NativeConditionAuthorAttributeProjection
    private let source: (NativeAttributeAuthorBinding) -> (NativeConditionAuthorScope, NativeConditionAuthorCatalog)?
    private let isCurrent: () -> Bool
    private let save: (ProjectEditJSON?) -> Bool
    private var raw: String

    init?(condition: ProjectEditJSON?, binding: NativeAttributeAuthorBinding, registeredKeys: [String],
          source: @escaping (NativeAttributeAuthorBinding) -> (NativeConditionAuthorScope, NativeConditionAuthorCatalog)?,
          isCurrent: @escaping () -> Bool, save: @escaping (ProjectEditJSON?) -> Bool) {
        guard !binding.isLocked, isCurrent(), let captured = source(binding),
              let accountID = Int(exactly: binding.accountID), let topicID = Int(exactly: binding.topicID),
              captured.0.accountID == accountID, captured.0.epoch == binding.epoch,
              captured.0.namespace == Data(binding.namespace.utf8),
              captured.0.authorizationRevision == Data(binding.authorizationRevision.utf8),
              let identity = try? ProjectEditDraftIdentity(topicID: topicID),
              captured.0.documentIdentity == Data(identity.bucket.utf8),
              Set(registeredKeys.map { Data($0.utf8) }).count == registeredKeys.count,
              registeredKeys.allSatisfy(NativeAttributeAuthorRow.validKey),
              let bytes = try? NativeAttributeAuthorWire.encode(condition == .null ? .array([]) : condition ?? .array([])),
              let text = String(data: bytes, encoding: .utf8) else { return nil }
        self.binding = binding; scope = captured.0; catalog = captured.1; raw = text
        self.source = source; self.isCurrent = isCurrent; self.save = save
        // These are the original42 draft's complete registration identities, including its
        // forward declarations. No initial values, runtime facts or server grant are inferred.
        projection = .init(scope: captured.0, definitionVersion: String(binding.sourceConfigVersion), origin: .currentDefinition,
            references: registeredKeys.map { .init(key: $0, label: $0, type: .number, writable: false) })
    }
    func capture() -> NativeConditionAuthorCapture? {
        guard isCurrent(), let current = source(binding), current.0 == scope, current.1 == catalog else { return nil }
        return .init(scope: scope, raw: raw, surface: .attributeCondition, catalog: catalog, attributes: projection, canEdit: true)
    }
    func persistOriginalDraft(_ next: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture {
        guard let current = capture(), current.scope == expected.scope, current.surface == expected.surface,
              current.raw.utf8.elementsEqual(expected.raw.utf8), current.catalog == expected.catalog,
              current.attributes == expected.attributes else { throw NativeConditionAuthorError.staleEditor }
        let document = try NativeConditionAuthorDocument(raw: next, surface: .attributeCondition, scope: scope)
        let issues = NativeConditionAuthorValidation.issues(document, catalog: catalog, attributes: projection)
        guard issues.isEmpty else { throw NativeConditionAuthorError.blocked(issues) }
        // The42 callback reports the actual durable local write result. An accepted UI
        // binding change alone must not be shown as saved. Empty remains the existing no-when form.
        guard save(document.value == .array([]) ? nil : document.value) else { throw NativeConditionAuthorError.persistenceFailed }
        raw = next
        guard let result = capture() else { throw NativeConditionAuthorError.staleEditor }
        return result
    }
}

/// Synchronous exact-row guard around the original coordinator's durable local replace.
/// Rule IDs survive reorder; copying a rule makes a new ID and cannot steal this edit.
@MainActor final class NativeAttributeAuthorConditionTarget {
    private weak var coordinator: NativeAttributeAuthorCoordinator?
    private let rowID: UUID
    private let registeredKeys: [Data]
    private var expected: NativeAttributeAuthorRule
    private var expectedRow: NativeAttributeAuthorRow
    init(coordinator: NativeAttributeAuthorCoordinator, row: NativeAttributeAuthorRow, rule: NativeAttributeAuthorRule) {
        self.coordinator = coordinator; rowID = row.id; expected = rule; expectedRow = row
        registeredKeys = coordinator.draft?.rows.map { Data($0.key.utf8) } ?? []
    }
    var isCurrent: Bool {
        guard let coordinator, coordinator.canEdit,
              coordinator.draft?.rows.map({ Data($0.key.utf8) }) == registeredKeys,
              let row = coordinator.draft?.rows.first(where: { $0.id == rowID }), Self.sameRow(row, expectedRow),
              let rule = row.rules.first(where: { $0.id == expected.id }),
              let actual = try? rule.encoded(), let original = try? expected.encoded() else { return false }
        return NativeAttributeAuthorWire.same(actual, original)
    }
    func save(_ value: ProjectEditJSON?) -> Bool {
        guard isCurrent, let coordinator,
              var row = coordinator.draft?.rows.first(where: { $0.id == rowID }),
              let index = row.rules.firstIndex(where: { $0.id == expected.id }) else { return false }
        row.rules[index].condition = value
        guard coordinator.replace(row) else { return false }
        expected = row.rules[index]; expectedRow = row
        return true
    }
    private static func sameRow(_ lhs: NativeAttributeAuthorRow, _ rhs: NativeAttributeAuthorRow) -> Bool {
        // The original42 parent form writes its whole @State row onChange. Freeze every
        // field, not just this rule, or that later callback could resurrect stale metadata.
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let left = try? encoder.encode(lhs), let right = try? encoder.encode(rhs) else { return false }
        return left == right
    }
}
