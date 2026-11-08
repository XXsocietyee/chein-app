import Foundation

/// Owner-bound durable appeal command (modelled on FreeExploreLaunchPendingStore).
/// Holds the command only: no token, no server response. The injected storage must write durably and synchronously.
@MainActor public final class BundleAppealPendingStore {
    private let storage: any TemplateAuthoringStorage
    private let ownerKey: String
    private var key: String { "bundle-appeal.pending.v1." + Data(ownerKey.utf8).base64EncodedString() }
    private struct Record: Codable {
        let version: Int
        let ownerKey: String
        let command: BundleAppealCommand
    }
    public init(storage: any TemplateAuthoringStorage, session: FreeExploreLaunchSession) {
        self.storage = storage; ownerKey = session.ownerKey
    }
    public func load() throws -> BundleAppealCommand? {
        do {
            guard let data = try storage.read(key) else { return nil }
            guard data.count <= 16_384 else { throw FreeExploreLaunchFailure.storageUnavailable }
            let record = try JSONDecoder().decode(Record.self, from: data)
            guard record.version == 1, record.ownerKey == ownerKey else { throw FreeExploreLaunchFailure.storageUnavailable }
            try record.command.validate(); return record.command
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }
    /// Never replaces an unresolved command (including one for another unit).
    public func save(_ command: BundleAppealCommand) throws {
        try command.validate()
        if let previous = try load() {
            guard previous == command else { throw FreeExploreLaunchFailure.pendingConflict }
            return
        }
        do {
            let data = try JSONEncoder().encode(Record(version: 1, ownerKey: ownerKey, command: command))
            try storage.write(data, key: key)
            guard try load() == command else { throw FreeExploreLaunchFailure.storageUnavailable }
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }
    /// Only call once the server definitely resolved the command (matching found receipt / definite business refusal).
    public func clear() throws {
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw FreeExploreLaunchFailure.storageUnavailable }
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }
}
