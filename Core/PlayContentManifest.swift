import Foundation
import CryptoKit
import Observation

/// U05-04 / §23.3. `GET /api/play/content-manifest` `data` (backend `content-manifest-v1.schema.json`).
/// A readable manifest is not offline playability: `verified` is false on every asset today, and
/// answers, arrival, hints, rewards, payment and scoring stay online-only whatever is cached.
public struct PlayContentManifest: Equatable {
    public enum Status: String { case revision = "REVISION", runSnapshot = "RUN_SNAPSHOT", onlineLegacy = "ONLINE_LEGACY" }
    public enum Scope: String { case start = "START", route = "ROUTE", optional = "OPTIONAL" }
    public struct Asset: Equatable, Identifiable {
        /// Stable content identity (chapter / node / template + field). Not the signed URL.
        public let assetKey: String
        public let url: URL?
        /// Nil when the server has no authoritative value. Never filled in locally.
        public let sha256: String?
        public let bytes: Int?
        public let mime: String?
        public let priority: Int
        public let scope: Scope
        public let textAlternative: String?
        /// Server statement that `sha256` / `bytes` are authoritative. False: show "not verified".
        public let verified: Bool
        public var id: String { assetKey }
        public var isRequired: Bool { scope != .optional }
    }
    public struct Station: Equatable, Identifiable {
        public let nodeID: Int
        public let nodeName: String?
        public let scope: Scope
        public let scanReady: Bool
        public var id: Int { nodeID }
    }
    public let status: Status
    public let topicID: Int
    public let activityID: Int?
    public let contentRevisionID: Int?
    public let revisionNo: Int?
    public let schemaVersion: Int?
    public let contentSha256: String?
    public let onlineRequired: Bool
    /// Nil = undeclared / not derivable. It is not "no requirements".
    public let requiredCapabilityKeys: [String]?
    public let stations: [Station]
    public let assets: [Asset]

    public init(raw: PlayWireValue) throws {
        guard raw.object != nil, let status = raw["status"].text.flatMap(Status.init(rawValue:)),
              let topic = raw["topicId"].tolerantInteger, topic > 0,
              let onlineRequired = raw["onlineRequired"].bool else { throw PlayExperienceError.malformed }
        func positive(_ key: String) -> Int? { raw[key].tolerantInteger.flatMap { $0 > 0 ? $0 : nil } }
        self.status = status; topicID = topic; activityID = positive("activityId")
        contentRevisionID = positive("contentRevisionId"); revisionNo = positive("revisionNo")
        schemaVersion = raw["schemaVersion"].tolerantInteger.flatMap { $0 >= 0 ? $0 : nil }
        contentSha256 = raw["contentSha256"].text.flatMap(Self.hex64)
        self.onlineRequired = onlineRequired
        if raw["requiredCapabilities"].array == nil { requiredCapabilityKeys = nil }
        else { requiredCapabilityKeys = (raw["requiredCapabilities"].array ?? []).compactMap { $0["key"].text.flatMap { $0.isEmpty ? nil : $0 } } }
        stations = (raw["stations"].array ?? []).compactMap { row in
            guard let id = row["nodeId"].tolerantInteger, id > 0, let scope = row["scope"].text.flatMap(Scope.init(rawValue:)) else { return nil }
            return Station(nodeID: id, nodeName: row["nodeName"].text, scope: scope, scanReady: row["scanReady"].bool == true)
        }
        var seen = Set<String>()
        assets = (raw["assets"].array ?? []).compactMap { row in
            guard let key = row["assetKey"].text, !key.isEmpty, key.count <= 200, seen.insert(key).inserted,
                  let scope = row["scope"].text.flatMap(Scope.init(rawValue:)),
                  let priority = row["priority"].tolerantInteger, (1...3).contains(priority) else { return nil }
            let url = row["url"].text.flatMap(URL.init(string:)).flatMap { $0.scheme == "https" && $0.host?.isEmpty == false ? $0 : nil }
            return Asset(assetKey: key, url: url, sha256: row["sha256"].text.flatMap(Self.hex64),
                         bytes: row["bytes"].tolerantInteger.flatMap { $0 >= 0 ? $0 : nil },
                         mime: row["mime"].text.flatMap { $0.isEmpty ? nil : $0 }, priority: priority, scope: scope,
                         textAlternative: row["textAlternative"].text.flatMap { $0.isEmpty ? nil : $0 },
                         verified: row["verified"].bool == true)
        }.sorted { ($0.priority, $0.assetKey) < ($1.priority, $1.assetKey) }
        // Shape rules from the schema `allOf`; a contradiction is not guessed into a pack.
        switch status {
        case .revision: guard contentRevisionID != nil, revisionNo != nil, contentSha256 != nil, !onlineRequired else { throw PlayExperienceError.malformed }
        case .runSnapshot: guard !onlineRequired else { throw PlayExperienceError.malformed }
        case .onlineLegacy: guard onlineRequired, assets.isEmpty else { throw PlayExperienceError.malformed }
        }
    }
    static func hex64(_ value: String) -> String? {
        value.count == 64 && value.allSatisfy({ $0.isHexDigit && !$0.isUppercase }) ? value : nil
    }
    /// Content identity used for cache directories. Nil for online-only legacy content.
    public var identity: String? {
        switch status {
        case .revision: return "rev-\(contentRevisionID ?? 0)-\(contentSha256 ?? "")"
        case .runSnapshot: return "run-\(topicID)-\(activityID ?? 0)-\(schemaVersion.map(String.init) ?? "x")-\(contentRevisionID.map(String.init) ?? "x")"
        case .onlineLegacy: return nil
        }
    }
    public var requiredAssets: [Asset] { assets.filter(\.isRequired) }
    public var optionalAssets: [Asset] { assets.filter { !$0.isRequired } }
    /// Sum of the sizes the server states; assets with no stated size are counted separately.
    public func knownSize(of rows: [Asset]) -> (bytes: Int, unknownCount: Int) {
        rows.reduce((0, 0)) { total, row in row.bytes.map { (total.0 + $0, total.1) } ?? (total.0, total.1 + 1) }
    }
}

/// One stored copy. `localSha256` is computed on this device for its own integrity check only;
/// it is never shown as a server verification.
public struct PlayPrefetchedAsset: Codable, Equatable {
    public let assetKey: String
    public let bytes: Int
    public let localSha256: String
    public let storedAt: Date
    /// True only when the server marked the asset verified and its hash matched these bytes.
    public let serverVerified: Bool
}

/// Account-private, content-identity-scoped file cache. A new identity is filled in its own
/// directory; the previous complete pack stays the readable one until every required asset of the
/// new identity is stored (a half pack never replaces a complete one).
public final class PlayContentPrefetchStore: @unchecked Sendable {
    private let root: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    public static let maximumAssetBytes = 50 * 1024 * 1024
    public init(root: URL, fileManager: FileManager = .default) { self.root = root; self.fileManager = fileManager }

    struct Index: Codable { var assets: [String: PlayPrefetchedAsset] = [:]; var complete = false; var syncedAt: Date? }
    struct Pointer: Codable { var completeIdentity: String? }

    static func digest(_ text: String) -> String { SHA256.hash(data: Data(text.utf8)).map { String(format: "%02x", $0) }.joined() }
    func ownerDirectory(namespace: String, accountID: Int, scope: PlaySessionScope) -> URL {
        let scopeKey: String
        switch scope { case .activity(let id): scopeKey = "a\(id)"; case .topic(let id): scopeKey = "t\(id)" }
        return root.appendingPathComponent(Self.digest("\(namespace)|\(accountID)"), isDirectory: true)
            .appendingPathComponent(scopeKey, isDirectory: true)
    }
    private func packDirectory(_ owner: URL, identity: String) -> URL { owner.appendingPathComponent(Self.digest(identity), isDirectory: true) }

    private func readJSON<T: Decodable>(_ type: T.Type, _ url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder(); decoder.dateDecodingStrategy = .secondsSince1970
        return try? decoder.decode(type, from: data)
    }
    private func writeJSON<T: Encodable>(_ value: T, _ url: URL) throws {
        let encoder = JSONEncoder(); encoder.dateEncodingStrategy = .secondsSince1970; encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(value).write(to: url, options: [.atomic, .completeFileProtection])
    }

    public func stored(owner: URL, identity: String) -> [String: PlayPrefetchedAsset] {
        lock.lock(); defer { lock.unlock() }
        return readJSON(Index.self, packDirectory(owner, identity: identity).appendingPathComponent("index.json"))?.assets ?? [:]
    }
    public func completeIdentity(owner: URL) -> String? {
        lock.lock(); defer { lock.unlock() }
        return readJSON(Pointer.self, owner.appendingPathComponent("pointer.json"))?.completeIdentity
    }
    public func syncedAt(owner: URL, identity: String) -> Date? {
        lock.lock(); defer { lock.unlock() }
        return readJSON(Index.self, packDirectory(owner, identity: identity).appendingPathComponent("index.json"))?.syncedAt
    }
    public func noteSynced(owner: URL, identity: String, at date: Date) throws {
        lock.lock(); defer { lock.unlock() }
        let directory = packDirectory(owner, identity: identity)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        var index = readJSON(Index.self, directory.appendingPathComponent("index.json")) ?? Index()
        index.syncedAt = date
        try writeJSON(index, directory.appendingPathComponent("index.json"))
    }

    /// Writes bytes atomically, then records them. A size or hash the server states must match.
    public func store(_ data: Data, for asset: PlayContentManifest.Asset, owner: URL, identity: String, at date: Date) throws -> PlayPrefetchedAsset {
        guard data.count <= Self.maximumAssetBytes, asset.bytes.map({ $0 == data.count }) ?? true else { throw PlayExperienceError.malformed }
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        if let expected = asset.sha256, expected != hash { throw PlayExperienceError.malformed }
        lock.lock(); defer { lock.unlock() }
        let directory = packDirectory(owner, identity: identity)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        try data.write(to: directory.appendingPathComponent(Self.digest(asset.assetKey)), options: [.atomic, .completeFileProtection])
        var index = readJSON(Index.self, directory.appendingPathComponent("index.json")) ?? Index()
        let row = PlayPrefetchedAsset(assetKey: asset.assetKey, bytes: data.count, localSha256: hash, storedAt: date,
                                      serverVerified: asset.verified && asset.sha256 == hash)
        index.assets[asset.assetKey] = row
        try writeJSON(index, directory.appendingPathComponent("index.json"))
        return row
    }

    /// Promotes `identity` only when every required asset is stored, then removes older packs.
    @discardableResult
    public func promoteIfComplete(_ manifest: PlayContentManifest, owner: URL) throws -> Bool {
        guard let identity = manifest.identity else { return false }
        lock.lock(); defer { lock.unlock() }
        let directory = packDirectory(owner, identity: identity)
        let index = readJSON(Index.self, directory.appendingPathComponent("index.json")) ?? Index()
        guard manifest.requiredAssets.allSatisfy({ index.assets[$0.assetKey] != nil }) else { return false }
        try writeJSON(Pointer(completeIdentity: identity), owner.appendingPathComponent("pointer.json"))
        let keep = Self.digest(identity)
        for entry in (try? fileManager.contentsOfDirectory(at: owner, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
        where (try? entry.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true && entry.lastPathComponent != keep {
            try? fileManager.removeItem(at: entry)
        }
        return true
    }
    /// Removes this account's copies for one run scope.
    public func clear(owner: URL) {
        lock.lock(); defer { lock.unlock() }
        try? fileManager.removeItem(at: owner)
    }
}

/// U05-04 screen model: required / optional resources, stated size, stored and verification
/// state per resource, last sync time, per-resource retry, and the offline scope it can honestly
/// declare. Every async result is dropped if the account or run changed meanwhile.
@available(macOS 14.0, *)
@MainActor @Observable public final class PlayOfflinePackModel {
    public enum Phase: Equatable { case idle, loading, loaded, failed(PlayExperienceError) }
    public enum AssetState: Equatable { case notStored, downloading, stored(PlayPrefetchedAsset), failed }
    /// What may be claimed offline. Only server-verified, fully stored required resources would
    /// allow reading; play actions (answers, arrival, hints, rewards, payment, scoring) never do.
    public enum OfflineScope: Equatable {
        case onlineOnly
        case notVerified
        case incomplete
        case readingOnly
    }
    public private(set) var phase: Phase = .idle
    public private(set) var manifest: PlayContentManifest?
    public private(set) var states: [String: AssetState] = [:]
    public private(set) var lastSyncedAt: Date?
    /// A previously completed identity still on this device (kept until the new one is complete).
    public private(set) var previousCompleteIdentity: String?
    private let scope: PlaySessionScope
    private let service: PlayExperienceService
    private let session: PlayExperienceSession
    private let isCurrent: () -> Bool
    private let store: PlayContentPrefetchStore
    private let fetch: @Sendable (URL) async throws -> Data
    private let now: () -> Date
    private var generation: UInt64 = 0
    public init(scope: PlaySessionScope, service: PlayExperienceService, session: PlayExperienceSession, isCurrent: @escaping () -> Bool,
                store: PlayContentPrefetchStore, fetch: @escaping @Sendable (URL) async throws -> Data, now: @escaping () -> Date = Date.init) {
        self.scope = scope; self.service = service; self.session = session; self.isCurrent = isCurrent
        self.store = store; self.fetch = fetch; self.now = now
    }
    private var owner: URL { store.ownerDirectory(namespace: session.namespace, accountID: session.accountID, scope: scope) }

    public func load() async {
        guard isCurrent() else { phase = .failed(.staleSession); return }
        generation &+= 1; let request = generation
        phase = .loading
        do {
            let manifest = try await service.contentManifest(scope: scope, token: session.token)
            guard request == generation, isCurrent() else { return }
            self.manifest = manifest
            let owner = self.owner
            if let identity = manifest.identity {
                try? store.noteSynced(owner: owner, identity: identity, at: now())
                lastSyncedAt = store.syncedAt(owner: owner, identity: identity)
                let stored = store.stored(owner: owner, identity: identity)
                states = Dictionary(uniqueKeysWithValues: manifest.assets.map { ($0.assetKey, stored[$0.assetKey].map(AssetState.stored) ?? .notStored) })
                let complete = store.completeIdentity(owner: owner)
                previousCompleteIdentity = complete == identity ? nil : complete
            } else {
                lastSyncedAt = now(); states = [:]; previousCompleteIdentity = store.completeIdentity(owner: owner)
            }
            phase = .loaded
        } catch {
            guard request == generation, isCurrent() else { return }
            phase = .failed(error as? PlayExperienceError ?? .unknownResult)
        }
    }

    public func canDownload(_ asset: PlayContentManifest.Asset) -> Bool {
        guard manifest?.identity != nil, asset.url != nil else { return false }
        switch states[asset.assetKey] { case .downloading?, .stored?: return false; default: return true }
    }
    /// Downloads one resource (also the per-resource retry). Never touches play state.
    public func download(_ asset: PlayContentManifest.Asset) async {
        guard let manifest, let identity = manifest.identity, manifest.assets.contains(asset), canDownload(asset),
              let url = asset.url, isCurrent() else { return }
        let request = generation, owner = self.owner
        states[asset.assetKey] = .downloading
        do {
            let data = try await fetch(url)
            guard request == generation, isCurrent() else { return }
            let row = try store.store(data, for: asset, owner: owner, identity: identity, at: now())
            states[asset.assetKey] = .stored(row)
            if try store.promoteIfComplete(manifest, owner: owner) { previousCompleteIdentity = nil }
        } catch {
            guard request == generation, isCurrent() else { return }
            states[asset.assetKey] = .failed
        }
    }
    public func downloadRequired() async {
        for asset in manifest?.requiredAssets ?? [] where canDownload(asset) { await download(asset) }
    }
    public var requiredStoredCount: Int {
        manifest?.requiredAssets.filter { if case .stored? = states[$0.assetKey] { return true }; return false }.count ?? 0
    }
    public var offlineScope: OfflineScope {
        guard let manifest, manifest.identity != nil, !manifest.onlineRequired else { return .onlineOnly }
        let required = manifest.requiredAssets
        let rows = required.compactMap { asset -> PlayPrefetchedAsset? in if case .stored(let row)? = states[asset.assetKey] { return row }; return nil }
        guard rows.count == required.count else { return .incomplete }
        return rows.allSatisfy(\.serverVerified) ? .readingOnly : .notVerified
    }
    /// Discards this account's copies for the run. Play progress is unaffected.
    public func clearDownloads() {
        generation &+= 1; store.clear(owner: owner)
        states = states.mapValues { _ in .notStored }; previousCompleteIdentity = nil
    }
}
