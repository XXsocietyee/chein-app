import Foundation

public struct NativeConditionAuthorCapture {
    public let scope: NativeConditionAuthorScope
    public let raw: String
    public let surface: NativeConditionAuthorDocument.Surface
    public let catalog: NativeConditionAuthorCatalog
    public let attributes: NativeConditionAuthorAttributeProjection?
    public let canEdit: Bool
    public init(scope: NativeConditionAuthorScope, raw: String, surface: NativeConditionAuthorDocument.Surface,
                catalog: NativeConditionAuthorCatalog, attributes: NativeConditionAuthorAttributeProjection?, canEdit: Bool) {
        self.scope = scope; self.raw = raw; self.surface = surface; self.catalog = catalog
        self.attributes = attributes; self.canEdit = canEdit
    }
}

@MainActor public protocol NativeConditionAuthorDraftHosting: AnyObject {
    /// Read from the original author's current in-memory draft; nil after session/visit retirement.
    func capture() -> NativeConditionAuthorCapture?
    /// Must preserve the complete original envelope and use its existing atomic local saver.
    /// Failure must not be reported as saved. Never issues a remote command or clears pending writes.
    func persistOriginalDraft(_ raw: String, replacing expected: NativeConditionAuthorCapture) throws -> NativeConditionAuthorCapture
}

public struct NativeConditionAuthorReadback {
    public let requestedScope: NativeConditionAuthorScope
    public let raw: String
    public let serverRevision: String
    public init(requestedScope: NativeConditionAuthorScope, raw: String, serverRevision: String) {
        self.requestedScope = requestedScope; self.raw = raw; self.serverRevision = serverRevision
    }
}
@MainActor public protocol NativeConditionAuthorReadbackServing: AnyObject {
    /// Implement with the authorized original owner-private read, never a public template projection.
    func readOriginalAuthorSource(for scope: NativeConditionAuthorScope) async throws -> NativeConditionAuthorReadback
}

/// Lifecycle and stale-response isolation independent of SwiftUI and transports.
@MainActor public final class NativeConditionAuthorSession {
    public enum State: Equatable { case editing, localSaved, reading, authoritative(String), stale, failed }
    public private(set) var document: NativeConditionAuthorDocument
    public private(set) var state: State = .editing
    public private(set) var authoritative: NativeConditionAuthorDocument?
    public private(set) var capture: NativeConditionAuthorCapture
    private let host: any NativeConditionAuthorDraftHosting
    private var generation: UInt64 = 0
    private var active = true

    public init(host: any NativeConditionAuthorDraftHosting) throws {
        guard let capture = host.capture() else { throw NativeConditionAuthorError.staleEditor }
        self.host = host; self.capture = capture
        document = try .init(raw: capture.raw, surface: capture.surface, scope: capture.scope)
    }
    public var isCurrent: Bool {
        guard active else { return false }
        guard let current = host.capture() else { return false }
        return current.scope == capture.scope && current.surface == capture.surface &&
            current.raw.utf8.elementsEqual(capture.raw.utf8) &&
            current.attributes == capture.attributes && current.catalog == capture.catalog
    }
    public var canEdit: Bool { isCurrent && host.capture()?.canEdit == true && document.canRoundTrip && (document.surface != .routeGraph || document.isExplicitV2) }
    public var issues: [NativeConditionAuthorIssue] {
        NativeConditionAuthorValidation.issues(document, catalog: capture.catalog, attributes: capture.attributes)
    }
    public func replace(path: NativeConditionAuthorPath, expected: ProjectEditJSON, replacement: ProjectEditJSON, revision: UInt64) throws {
        guard canEdit else { state = .stale; throw NativeConditionAuthorError.staleEditor }
        try document.replace(at: path, expected: expected, with: replacement, revision: revision)
        generation &+= 1; authoritative = nil; state = .editing
    }
    public func saveOriginalLocalDraft() throws {
        guard canEdit else { state = .stale; throw NativeConditionAuthorError.staleEditor }
        guard issues.isEmpty else { throw NativeConditionAuthorError.blocked(issues) }
        let raw = try document.serialized(), expected = capture
        let next = try host.persistOriginalDraft(raw, replacing: expected)
        guard let current = host.capture(), current.scope == next.scope,
              current.raw.utf8.elementsEqual(raw.utf8), next.raw.utf8.elementsEqual(raw.utf8),
              next.scope.accountID == expected.scope.accountID, next.scope.namespace == expected.scope.namespace,
              next.scope.documentIdentity == expected.scope.documentIdentity, next.scope.epoch == expected.scope.epoch,
              next.scope.authorizationRevision == expected.scope.authorizationRevision,
              next.scope.incarnation == expected.scope.incarnation else { state = .failed; throw NativeConditionAuthorError.persistenceFailed }
        capture = next; document = try .init(raw: raw, surface: next.surface, scope: next.scope)
        generation &+= 1; authoritative = nil; state = .localSaved
    }
    /// Compares the original server source after the normal host submission flow. Does not
    /// replace an unsaved local draft or infer that a local save reached the server.
    public func readAuthoritative(using reader: any NativeConditionAuthorReadbackServing) async throws {
        guard isCurrent, !document.hasChanges else { throw NativeConditionAuthorError.staleEditor }
        let scope = capture.scope, revision = document.revision
        generation &+= 1; let stamp = generation; state = .reading
        do {
            let read = try await reader.readOriginalAuthorSource(for: scope)
            guard !Task.isCancelled, isCurrent, capture.scope == scope, document.revision == revision,
                  generation == stamp, read.requestedScope == scope, !read.serverRevision.isEmpty else { throw NativeConditionAuthorError.staleEditor }
            authoritative = try .init(raw: read.raw, surface: capture.surface, scope: scope)
            state = .authoritative(read.serverRevision)
        } catch {
            // A retired callback must never overwrite newer editor state or clear original pending work.
            if generation == stamp { authoritative = nil; state = isCurrent ? .failed : .stale }
            throw error
        }
    }
    public func retire() { active = false; generation &+= 1; authoritative = nil; state = .stale }
}
