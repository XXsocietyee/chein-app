import Foundation

/// One durable unresolved request per account/realm/license. Login epochs fence transport but
/// are not storage keys: a relogin must recover the original command rather than create a duplicate.
@MainActor public final class ModInstallationPendingStore {
    private let storage: any TemplateAuthoringStorage
    private let scope: String
    private let identity: ModInstallationIdentity
    private var key: String { "mod-installation-v1." + Data(scope.utf8).base64EncodedString() }
    private struct Record: Codable { let version: Int; let scope: String; let attempt: ModInstallationAttempt }
    public init(storage: any TemplateAuthoringStorage, context: RuntimeDependencyContext, identity: ModInstallationIdentity) {
        self.storage = storage; self.identity = identity
        scope = [String(describing: context.market), context.baseURL.absoluteString, context.session.namespace,
                 String(context.session.accountID), identity.licenseId].map { "\($0.utf8.count):\($0)" }.joined(separator: ":")
    }
    public func load() throws -> ModInstallationAttempt? {
        let raw: Data?
        do { raw = try storage.read(key) } catch { throw ModInstallationIssue.storageUnavailable }
        guard let data = raw else { return nil }
        guard data.count <= 524288, let record = try? JSONDecoder().decode(Record.self, from: data),
              record.version == 1, record.scope.utf8.elementsEqual(scope.utf8), record.attempt.identity == identity else { throw ModInstallationIssue.storageUnavailable }
        do { try record.attempt.validate() } catch { throw ModInstallationIssue.storageUnavailable }
        return record.attempt
    }
    /// Called before any prepare POST. Exact readback is mandatory; a failed write is not permission to dispatch.
    public func begin(_ attempt: ModInstallationAttempt) throws {
        try attempt.validate()
        guard attempt.identity == identity else { throw ModInstallationIssue.pendingConflict }
        if let existing = try load() {
            guard existing == attempt else { throw ModInstallationIssue.pendingConflict }
            return
        }
        try write(attempt)
    }
    public func accept(_ receipt: ModInstallationReceipt) throws -> ModInstallationAttempt {
        guard var attempt = try load() else { throw ModInstallationIssue.pendingConflict }
        try attempt.validate(receipt: receipt)
        attempt.receipt = receipt; attempt.pendingAction = nil; try write(attempt); return attempt
    }
    public func markDispatch(_ action: ModInstallationAttempt.PendingAction, confirmed: ModInstallationReceipt) throws -> ModInstallationAttempt {
        guard action != .prepare, var attempt = try load(), attempt.pendingAction == nil,
              attempt.receipt == confirmed, confirmed.state == .prepared else { throw ModInstallationIssue.pendingConflict }
        try attempt.validate(receipt: confirmed)
        attempt.pendingAction = action; try write(attempt); return attempt
    }
    public func markFacts(_ facts: ModInstallationFacts) throws -> ModInstallationAttempt {
        guard var attempt = try load(), attempt.pendingFacts == nil, let receipt = attempt.receipt else { throw ModInstallationIssue.pendingConflict }
        try facts.validate(receipt: receipt)
        guard !facts.confirmed else { throw ModInstallationIssue.pendingConflict }
        attempt.pendingFacts = .init(facts: facts); try write(attempt); return attempt
    }
    public func acceptFacts(_ facts: ModInstallationFacts) throws -> ModInstallationAttempt {
        guard var attempt = try load(), let receipt = attempt.receipt else { throw ModInstallationIssue.pendingConflict }
        try facts.validate(receipt: receipt)
        attempt.pendingFacts = nil; try write(attempt); return attempt
    }
    /// Only an explicit server preflight rejection permits clearing a not-created request. Never called after a timeout/404.
    public func discardRejectedPreflight(requestId: String) throws {
        guard let attempt = try load(), attempt.request.requestId == requestId,
              attempt.receipt == nil, attempt.pendingAction == .prepare else { throw ModInstallationIssue.pendingConflict }
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw ModInstallationIssue.storageUnavailable }
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    /// Unknown requests cannot be discarded. Even a terminal local result must be freshly verified by the server.
    public func finish(_ verified: ModInstallationReceipt) throws {
        guard verified.terminal, let attempt = try load(), attempt.pendingFacts == nil else { throw ModInstallationIssue.pendingConflict }
        try attempt.validate(receipt: verified)
        guard attempt.receipt == verified else { throw ModInstallationIssue.pendingConflict }
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw ModInstallationIssue.storageUnavailable }
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    private struct QaRecord: Codable { let version: Int; let scope: String; let pending: ModInstallationQaEditPending }
    private func qaKey(_ request: String) -> String { key + ".qa-edit." + request }
    func loadQaEdit(installation: ModInstallationReceipt) throws -> ModInstallationQaEditPending? {
        guard installation.identity == identity else { throw ModInstallationIssue.pendingConflict }
        do {
            guard let raw = try storage.read(qaKey(installation.requestId)) else { return nil }
            guard raw.count <= 131072 else { throw ModInstallationIssue.storageUnavailable }
            let record = try JSONDecoder().decode(QaRecord.self, from: raw)
            guard record.version == 1, record.scope.utf8.elementsEqual(scope.utf8), record.pending.installation == installation else { throw ModInstallationIssue.storageUnavailable }
            try record.pending.validate(); return record.pending
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    func beginQaEdit(_ value: ModInstallationQaEditPending) throws {
        try value.validate(); guard value.receipt == nil else { throw ModInstallationIssue.pendingConflict }
        if let old = try loadQaEdit(installation: value.installation), old.receipt == nil {
            guard old == value else { throw ModInstallationIssue.pendingConflict }; return
        }
        try writeQaEdit(value)
    }
    func acceptQaEdit(_ value: ModInstallationQaEditPending) throws {
        try value.validate(); guard let old = try loadQaEdit(installation: value.installation), value.receipt != nil,
              old.command == value.command, old.templateId == value.templateId else { throw ModInstallationIssue.pendingConflict }
        try writeQaEdit(value)
    }
    func rejectQaEdit(_ value: ModInstallationQaEditPending) throws {
        guard value.receipt == nil, try loadQaEdit(installation: value.installation) == value else { throw ModInstallationIssue.pendingConflict }
        do { try storage.remove(qaKey(value.installation.requestId)); guard try storage.read(qaKey(value.installation.requestId)) == nil else { throw ModInstallationIssue.storageUnavailable } }
        catch { throw ModInstallationIssue.storageUnavailable }
    }
    private func writeQaEdit(_ value: ModInstallationQaEditPending) throws {
        do {
            try storage.write(JSONEncoder().encode(QaRecord(version: 1, scope: scope, pending: value)), key: qaKey(value.installation.requestId))
            guard try loadQaEdit(installation: value.installation) == value else { throw ModInstallationIssue.storageUnavailable }
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    private struct TemplateRecord: Codable { let version: Int; let scope: String; let pending: ModInstallationTemplateEditPending }
    private func templateKey(_ request: String) -> String { key + ".template-edit." + request }
    func loadTemplateEdit(installation: ModInstallationReceipt) throws -> ModInstallationTemplateEditPending? {
        guard installation.identity == identity else { throw ModInstallationIssue.pendingConflict }
        do {
            guard let raw = try storage.read(templateKey(installation.requestId)) else { return nil }
            guard raw.count <= 4194304 else { throw ModInstallationIssue.storageUnavailable }
            let record = try JSONDecoder().decode(TemplateRecord.self, from: raw)
            guard record.version == 1, record.scope.utf8.elementsEqual(scope.utf8), record.pending.installation == installation else { throw ModInstallationIssue.storageUnavailable }
            try record.pending.validate(); return record.pending
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    func beginTemplateEdit(_ value: ModInstallationTemplateEditPending) throws {
        try value.validate(); guard value.receipt == nil else { throw ModInstallationIssue.pendingConflict }
        if let old = try loadTemplateEdit(installation: value.installation), old.receipt == nil {
            guard old == value else { throw ModInstallationIssue.pendingConflict }; return
        }
        try writeTemplateEdit(value)
    }
    func acceptTemplateEdit(_ value: ModInstallationTemplateEditPending) throws {
        try value.validate(); guard let old = try loadTemplateEdit(installation: value.installation), value.receipt != nil,
              old.command == value.command, old.reviewedSnapshotJson == value.reviewedSnapshotJson else { throw ModInstallationIssue.pendingConflict }
        try writeTemplateEdit(value)
    }
    func rejectTemplateEdit(_ value: ModInstallationTemplateEditPending) throws {
        guard value.receipt == nil, try loadTemplateEdit(installation: value.installation) == value else { throw ModInstallationIssue.pendingConflict }
        do { try storage.remove(templateKey(value.installation.requestId)); guard try storage.read(templateKey(value.installation.requestId)) == nil else { throw ModInstallationIssue.storageUnavailable } }
        catch { throw ModInstallationIssue.storageUnavailable }
    }
    private func writeTemplateEdit(_ value: ModInstallationTemplateEditPending) throws {
        do {
            try storage.write(JSONEncoder().encode(TemplateRecord(version: 1, scope: scope, pending: value)), key: templateKey(value.installation.requestId))
            guard try loadTemplateEdit(installation: value.installation) == value else { throw ModInstallationIssue.storageUnavailable }
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    private struct VenueRecord: Codable { let version: Int; let scope: String; let pending: ModVenueOperationPending }
    private func venueKey(_ request: String) -> String { key + ".venue-operation." + request }
    func loadVenue(installation: ModInstallationReceipt) throws -> ModVenueOperationPending? {
        guard installation.identity == identity else { throw ModInstallationIssue.pendingConflict }
        do {
            guard let raw = try storage.read(venueKey(installation.requestId)) else { return nil }
            guard raw.count <= 1048576 else { throw ModInstallationIssue.storageUnavailable }
            let record = try JSONDecoder().decode(VenueRecord.self, from: raw)
            guard record.version == 1, record.scope.utf8.elementsEqual(scope.utf8), record.pending.installation == installation else { throw ModInstallationIssue.storageUnavailable }
            try record.pending.validate(); return record.pending
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    func beginVenue(_ value: ModVenueOperationPending) throws {
        try value.validate(); guard value.receipt == nil else { throw ModInstallationIssue.pendingConflict }
        if let old = try loadVenue(installation: value.installation), old.receipt == nil { guard old == value else { throw ModInstallationIssue.pendingConflict }; return }
        try writeVenue(value)
    }
    func acceptVenue(_ value: ModVenueOperationPending) throws {
        try value.validate(); guard let old = try loadVenue(installation: value.installation), value.receipt != nil,
              old.command == value.command, old.installationId == value.installationId else { throw ModInstallationIssue.pendingConflict }
        try writeVenue(value)
    }
    private func writeVenue(_ value: ModVenueOperationPending) throws {
        do {
            try storage.write(JSONEncoder().encode(VenueRecord(version: 1, scope: scope, pending: value)), key: venueKey(value.installation.requestId))
            guard try loadVenue(installation: value.installation) == value else { throw ModInstallationIssue.storageUnavailable }
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
    private func write(_ attempt: ModInstallationAttempt) throws {
        do {
            try storage.write(JSONEncoder().encode(Record(version: 1, scope: scope, attempt: attempt)), key: key)
            guard try load() == attempt else { throw ModInstallationIssue.storageUnavailable }
        } catch { throw ModInstallationIssue.storageUnavailable }
    }
}
