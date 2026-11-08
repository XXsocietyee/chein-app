import Foundation

/// WP-11 / CT12.d: a cache key is scoped by account + object + privacy + content version.
/// Pure value types; no disk, network or clock. Callers own the actual byte storage.
public struct ScopedCacheKey: Hashable, Sendable {
    public enum Privacy: String, Hashable, Sendable {
        case publicContent = "PUBLIC"
        case accountPrivate = "ACCOUNT_PRIVATE"
        case shareLink = "SHARE_LINK"
    }

    public let accountID: String
    public let objectID: String
    public let privacy: Privacy
    public let contentVersion: String

    /// Returns nil when any component is blank after trimming; a blank scope must never collapse into a shared key.
    public init?(accountID: String?, objectID: String?, privacy: Privacy, contentVersion: String?) {
        func clean(_ value: String?) -> String? {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { return nil }
            return trimmed
        }
        guard let account = clean(accountID), let object = clean(objectID), let version = clean(contentVersion) else {
            return nil
        }
        self.accountID = account
        self.objectID = object
        self.privacy = privacy
        self.contentVersion = version
    }

    /// Stable storage name. Components are length-prefixed so separators inside ids cannot alias another key.
    public var storageName: String {
        [accountID, objectID, privacy.rawValue, contentVersion]
            .map { "\($0.utf8.count):\($0)" }
            .joined(separator: "|")
    }
}

/// In-memory index over scoped keys that enforces revoke and logout purges.
public struct ScopedCacheIndex: Sendable, Equatable {
    public private(set) var liveKeys: Set<ScopedCacheKey> = []
    private var revokedObjects: Set<String> = []

    public init() {}

    /// Registers a key. A key for an object revoked earlier is refused.
    @discardableResult
    public mutating func insert(_ key: ScopedCacheKey) -> Bool {
        guard !revokedObjects.contains(Self.objectToken(key)) else { return false }
        liveKeys.insert(key)
        return true
    }

    public func isReusable(_ key: ScopedCacheKey) -> Bool {
        liveKeys.contains(key) && !revokedObjects.contains(Self.objectToken(key))
    }

    /// Revokes an object (e.g. a share image) for every version and account; returns the purged keys.
    @discardableResult
    public mutating func revoke(objectID: String, privacy: ScopedCacheKey.Privacy) -> [ScopedCacheKey] {
        let trimmed = objectID.trimmingCharacters(in: .whitespacesAndNewlines)
        revokedObjects.insert("\(privacy.rawValue)|\(trimmed)")
        let purged = liveKeys.filter { $0.objectID == trimmed && $0.privacy == privacy }
        liveKeys.subtract(purged)
        return Array(purged)
    }

    /// Logout / account removal: drops every key owned by the account; returns the purged keys.
    @discardableResult
    public mutating func purgeAccount(_ accountID: String) -> [ScopedCacheKey] {
        let trimmed = accountID.trimmingCharacters(in: .whitespacesAndNewlines)
        let purged = liveKeys.filter { $0.accountID == trimmed }
        liveKeys.subtract(purged)
        return Array(purged)
    }

    private static func objectToken(_ key: ScopedCacheKey) -> String {
        "\(key.privacy.rawValue)|\(key.objectID)"
    }
}
