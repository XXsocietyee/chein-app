import Foundation

// MARK: - Bundle transfer pending store (IWP-8c). Wires nothing.
// Recovery metadata only: operation kind, order id, channel and the idempotency key.
// It NEVER holds the one-time code, the receiver phone, a token, or any server response.
// (A hash of a short code or a phone number is brute-forceable, so no fingerprint of them is kept either;
// after an unknown outcome the user re-enters them and the server compares against the original request.)
// Owner-bound like `FreeExploreLaunchPendingStore`. Login loss must not clear it.

public struct BundleTransferPendingOperation: Codable, Equatable {
    public enum Kind: String, Codable { case send, claim }
    public let kind: Kind
    public let registrationId: FreeExploreLaunchID?
    public let channel: BundleTransferChannel?
    public let idempotencyKey: String

    public static func send(registrationId: FreeExploreLaunchID, channel: BundleTransferChannel,
                            idempotencyKey: String) -> BundleTransferPendingOperation {
        BundleTransferPendingOperation(kind: .send, registrationId: registrationId, channel: channel, idempotencyKey: idempotencyKey)
    }
    public static func claim(idempotencyKey: String) -> BundleTransferPendingOperation {
        BundleTransferPendingOperation(kind: .claim, registrationId: nil, channel: nil, idempotencyKey: idempotencyKey)
    }
    func validate() throws {
        guard (1...64).contains(idempotencyKey.utf8.count),
              idempotencyKey.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw FreeExploreLaunchFailure.invalid
        }
        switch kind {
        case .send: guard registrationId != nil, channel != nil else { throw FreeExploreLaunchFailure.invalid }
        case .claim: guard registrationId == nil, channel == nil else { throw FreeExploreLaunchFailure.invalid }
        }
    }
}

/// The injected app storage must provide durable synchronous writes.
@MainActor public final class BundleTransferPendingStore {
    private let storage: any TemplateAuthoringStorage
    private let ownerKey: String
    private var key: String { "bundle-transfer.pending.v1." + Data(ownerKey.utf8).base64EncodedString() }
    private struct Record: Codable {
        let version: Int
        let ownerKey: String
        let operation: BundleTransferPendingOperation
    }
    public init(storage: any TemplateAuthoringStorage, session: FreeExploreLaunchSession) {
        self.storage = storage; ownerKey = session.ownerKey
    }
    public func load() throws -> BundleTransferPendingOperation? {
        do {
            guard let data = try storage.read(key) else { return nil }
            guard data.count <= 4_096 else { throw FreeExploreLaunchFailure.storageUnavailable }
            let record = try JSONDecoder().decode(Record.self, from: data)
            guard record.version == 1, record.ownerKey == ownerKey else { throw FreeExploreLaunchFailure.storageUnavailable }
            try record.operation.validate(); return record.operation
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }
    /// Never replaces a different unresolved operation.
    public func save(_ operation: BundleTransferPendingOperation) throws {
        try operation.validate()
        if let previous = try load() {
            guard previous == operation else { throw FreeExploreLaunchFailure.pendingConflict }
            return
        }
        do {
            let data = try JSONEncoder().encode(Record(version: 1, ownerKey: ownerKey, operation: operation))
            try storage.write(data, key: key)
            guard try load() == operation else { throw FreeExploreLaunchFailure.storageUnavailable }
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }
    /// Call only after a definite server answer (success or definite rejection).
    public func clear() throws {
        do {
            try storage.remove(key)
            guard try storage.read(key) == nil else { throw FreeExploreLaunchFailure.storageUnavailable }
        } catch { throw FreeExploreLaunchFailure.storageUnavailable }
    }
}
