import Foundation
import CryptoKit

/// Permanent client operation id bound to account (subject) + object + body hash.
/// Pure value type; no feature is migrated onto it yet.
public struct ClientOperationID: Codable, Equatable, Hashable, Sendable {
    public let value: String
    public let subject: String
    public let object: String
    public let bodyHash: String

    public init(value: String, subject: String, object: String, bodyHash: String) {
        self.value = value; self.subject = subject; self.object = object; self.bodyHash = bodyHash
    }

    public static func hash(of body: Data) -> String {
        SHA256.hash(data: body).map { String(format: "%02x", $0) }.joined()
    }

    static func key(subject: String, object: String, bodyHash: String) -> String {
        [subject, object, bodyHash].map { "\($0.utf8.count):\($0)" }.joined(separator: "|")
    }

    static func isValid(_ text: String) -> Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum ClientOperationIDError: Error, Equatable {
    case blankSubject
    case blankObject
    case journalUnreadable
}

public protocol ClientOperationIDStore: AnyObject {
    /// Returns the existing id for (subject, object, body) or mints and persists a new one.
    func operationID(subject: String, object: String, body: Data) throws -> ClientOperationID
    func existing(subject: String, object: String, body: Data) -> ClientOperationID?
    /// Forget an id after the write is confirmed; a later identical write mints a new id.
    func complete(_ id: ClientOperationID)
}

public final class InMemoryClientOperationIDStore: ClientOperationIDStore {
    private var entries: [String: ClientOperationID] = [:]
    private let lock = NSLock()
    private let makeValue: () -> String
    public init(makeValue: @escaping () -> String = { UUID().uuidString.lowercased() }) {
        self.makeValue = makeValue
    }
    public func operationID(subject: String, object: String, body: Data) throws -> ClientOperationID {
        guard ClientOperationID.isValid(subject) else { throw ClientOperationIDError.blankSubject }
        guard ClientOperationID.isValid(object) else { throw ClientOperationIDError.blankObject }
        let bodyHash = ClientOperationID.hash(of: body)
        let key = ClientOperationID.key(subject: subject, object: object, bodyHash: bodyHash)
        lock.lock(); defer { lock.unlock() }
        if let found = entries[key] { return found }
        let id = ClientOperationID(value: makeValue(), subject: subject, object: object, bodyHash: bodyHash)
        entries[key] = id
        return id
    }
    public func existing(subject: String, object: String, body: Data) -> ClientOperationID? {
        let key = ClientOperationID.key(subject: subject, object: object, bodyHash: ClientOperationID.hash(of: body))
        lock.lock(); defer { lock.unlock() }
        return entries[key]
    }
    public func complete(_ id: ClientOperationID) {
        let key = ClientOperationID.key(subject: id.subject, object: id.object, bodyHash: id.bodyHash)
        lock.lock(); defer { lock.unlock() }
        if entries[key] == id { entries[key] = nil }
    }
}

/// File-journal store: every mint/complete is written through so an id survives relaunch.
public final class FileClientOperationIDStore: ClientOperationIDStore {
    private let fileURL: URL
    private var entries: [String: ClientOperationID]
    private let lock = NSLock()
    private let makeValue: () -> String

    public init(fileURL: URL, makeValue: @escaping () -> String = { UUID().uuidString.lowercased() }) throws {
        self.fileURL = fileURL
        self.makeValue = makeValue
        if FileManager.default.fileExists(atPath: fileURL.path) {
            do {
                let data = try Data(contentsOf: fileURL)
                entries = try JSONDecoder().decode([String: ClientOperationID].self, from: data)
            } catch { throw ClientOperationIDError.journalUnreadable }
        } else {
            entries = [:]
        }
    }
    private func persist() throws {
        let data = try JSONEncoder().encode(entries)
        #if os(iOS)
        try data.write(to: fileURL, options: [.atomic, .completeFileProtection])
        #else
        try data.write(to: fileURL, options: .atomic)
        #endif
    }
    public func operationID(subject: String, object: String, body: Data) throws -> ClientOperationID {
        guard ClientOperationID.isValid(subject) else { throw ClientOperationIDError.blankSubject }
        guard ClientOperationID.isValid(object) else { throw ClientOperationIDError.blankObject }
        let bodyHash = ClientOperationID.hash(of: body)
        let key = ClientOperationID.key(subject: subject, object: object, bodyHash: bodyHash)
        lock.lock(); defer { lock.unlock() }
        if let found = entries[key] { return found }
        let id = ClientOperationID(value: makeValue(), subject: subject, object: object, bodyHash: bodyHash)
        entries[key] = id
        do { try persist() } catch { entries[key] = nil; throw error }
        return id
    }
    public func existing(subject: String, object: String, body: Data) -> ClientOperationID? {
        let key = ClientOperationID.key(subject: subject, object: object, bodyHash: ClientOperationID.hash(of: body))
        lock.lock(); defer { lock.unlock() }
        return entries[key]
    }
    public func complete(_ id: ClientOperationID) {
        let key = ClientOperationID.key(subject: id.subject, object: id.object, bodyHash: id.bodyHash)
        lock.lock(); defer { lock.unlock() }
        guard entries[key] == id else { return }
        entries[key] = nil
        try? persist()
    }
}
