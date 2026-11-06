import Foundation

/// Stable across relogin, distinct across accounts, API realms and original licenses.
@MainActor public final class ModUpgradeIntentStore {
    private let storage: any TemplateAuthoringStorage
    private let source: ModInstallationIdentity
    private let scope: String
    private var key: String { "mod-upgrade-v1." + Data(scope.utf8).base64EncodedString() }
    /// Bounded original record, including both complete frozen terms; keys/version remain unchanged.
    private let maximumRecordBytes = 262144
    private struct Record: Codable { let version: Int; let scope: String; let intent: ModUpgradeIntent }
    public init(storage: any TemplateAuthoringStorage, context: RuntimeDependencyContext, source: ModInstallationIdentity) {
        self.storage = storage; self.source = source
        scope = [context.market.rawValue, context.baseURL.absoluteString, context.session.namespace,
                 String(context.session.accountID), source.licenseId].map { "\($0.utf8.count):\($0)" }.joined(separator: ":")
    }
    public func load() throws -> ModUpgradeIntent? {
        do {
            guard let data = try storage.read(key) else { return nil }
            guard data.count <= maximumRecordBytes else { throw ModUpgradeIssue.storageUnavailable }
            let record = try JSONDecoder().decode(Record.self, from: data)
            guard record.version == 1, record.scope.utf8.elementsEqual(scope.utf8), record.intent.source == source else { throw ModUpgradeIssue.storageUnavailable }
            try record.intent.validate(); return record.intent
        } catch { throw ModUpgradeIssue.storageUnavailable }
    }
    public func begin(_ intent: ModUpgradeIntent) throws {
        try intent.validate()
        guard intent.source == source, intent.installation == nil, intent.rejectionReason == nil else { throw ModUpgradeIssue.pendingConflict }
        if let existing = try load() {
            guard existing.source == intent.source, existing.candidate == intent.candidate else { throw ModUpgradeIssue.pendingConflict }
            return
        }
        try write(intent)
    }
    /// Exact command readback must succeed before upgrade stage POST. Unknown outcomes never change UUID.
    public func bind(_ attempt: ModInstallationAttempt) throws -> ModUpgradeIntent {
        try attempt.validate()
        guard var intent = try load(), intent.target == attempt.identity, intent.rejectionReason == nil else { throw ModUpgradeIssue.pendingConflict }
        if let command = intent.installation {
            guard command == attempt.request else { throw ModUpgradeIssue.pendingConflict }; return intent
        }
        intent.installation = attempt.request; try write(intent); return intent
    }
    public func finishUninstalled(_ expected: ModUpgradeIntent, verified: ModInstallationReceipt) throws {
        guard let original = expected.installation, let target = expected.target,
              verified.requestId == original.requestId, verified.state == .cancelled || verified.state == .failed,
              try load() == expected else { throw ModUpgradeIssue.pendingConflict }
        try verified.validate(identity: target)
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw ModUpgradeIssue.storageUnavailable }
        } catch { throw ModUpgradeIssue.storageUnavailable }
    }
    /// Caller must additionally prove the separately persisted installation journal is empty.
    public func abandonUnstaged(_ expected: ModUpgradeIntent) throws {
        guard expected.installation == nil, expected.rejectionReason == nil, try load() == expected else { throw ModUpgradeIssue.pendingConflict }
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw ModUpgradeIssue.storageUnavailable }
        } catch { throw ModUpgradeIssue.storageUnavailable }
    }
    /// Only a validated server 422 proves this exact command did not create an upgrade.
    public func markRejected(_ reason: String, attempt: ModInstallationAttempt) throws {
        guard var saved = try load(), saved.installation == attempt.request, saved.target == attempt.identity else { throw ModUpgradeIssue.pendingConflict }
        saved.rejectionReason = reason; try saved.validate(); try write(saved)
    }
    /// Explicit user action only; never for an unknown result, timeout, or 404.
    public func abandonRejected(_ expected: ModUpgradeIntent) throws {
        guard expected.rejectionReason != nil, try load() == expected else { throw ModUpgradeIssue.pendingConflict }
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw ModUpgradeIssue.storageUnavailable }
        } catch { throw ModUpgradeIssue.storageUnavailable }
    }
    private func write(_ intent: ModUpgradeIntent) throws {
        do {
            let data = try JSONEncoder().encode(Record(version: 1, scope: scope, intent: intent))
            guard data.count <= maximumRecordBytes else { throw ModUpgradeIssue.storageUnavailable }
            try storage.write(data, key: key)
            guard try load() == intent else { throw ModUpgradeIssue.storageUnavailable }
        } catch { throw ModUpgradeIssue.storageUnavailable }
    }
}

/// Reuses the complete installation journal without colliding with direct installs or another old license.
@MainActor public final class ModUpgradeInstallationStorage: TemplateAuthoringStorage {
    private let storage: any TemplateAuthoringStorage
    private let prefix: String
    public init(storage: any TemplateAuthoringStorage, source: ModInstallationIdentity) {
        self.storage = storage; prefix = "mod-upgrade-installation." + Data(source.licenseId.utf8).base64EncodedString() + "."
    }
    public func read(_ key: String) throws -> Data? { try storage.read(prefix + key) }
    public func write(_ data: Data, key: String) throws { try storage.write(data, key: prefix + key) }
    public func remove(_ key: String) throws { try storage.remove(prefix + key) }
}
