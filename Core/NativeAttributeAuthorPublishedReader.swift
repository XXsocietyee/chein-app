import Foundation

/// A read-only inspection of the original owner's *current published* snapshot. It is
/// never proof that an UNKNOWN save/publication request committed or that a player may run it.
public struct NativeAttributeAuthorPublishedInspection {
    public let binding: NativeAttributeAuthorBinding
    public let source: Data
}

@MainActor public final class NativeAttributeAuthorPublishedReader {
    private let service: ProjectEditHTTPService
    private let currentSession: () -> ProjectEditSession?
    public init(service: ProjectEditHTTPService, currentSession: @escaping () -> ProjectEditSession?) {
        self.service = service; self.currentSession = currentSession
    }
    private func matches(_ session: ProjectEditSession, _ binding: NativeAttributeAuthorBinding) -> Bool {
        Int64(session.accountID) == binding.accountID && session.epoch == binding.epoch &&
        session.storageNamespace.utf8.elementsEqual(binding.namespace.utf8) &&
        "\(session.viewerRevision):\(session.configurationRevision)".utf8.elementsEqual(binding.authorizationRevision.utf8)
    }
    /// For a current binding, require the same freshly captured draft S and return the
    /// server's actual published P/source-S/hash. For a locked binding, read only that P;
    /// a newer publication is rejected instead of substituting it for the requested version.
    public func inspect(_ requested: NativeAttributeAuthorBinding) async throws -> NativeAttributeAuthorPublishedInspection {
        guard let session = currentSession(), matches(session, requested),
              let topicID = Int(exactly: requested.topicID) else { throw NativeAttributeAuthorError.staleSource }
        try Task.checkCancellation()
        let readback = try await service.readOriginalAuthorDetail(topicID: topicID, session: session)
        guard !Task.isCancelled, currentSession() == session, readback.session == session,
              readback.server.absoluteString.utf8.elementsEqual(requested.server.utf8),
              readback.owner.rawValue.utf8.elementsEqual(requested.requestScope.utf8),
              readback.snapshot.topicID == topicID else { throw NativeAttributeAuthorError.staleSource }
        let root = try NativeAttributeAuthorWire.decode(readback.raw)
        guard let topic = root.object?["data"]?.object?["topic"]?.object,
              topic["id"]?.integer == topicID,
              let currentVersion = topic["configVersion"]?.integer, currentVersion >= 0,
              let publishedVersion = topic["publishedConfigVersion"]?.integer, publishedVersion > 0,
              let raw = topic["publishedRouteGraphJson"]?.text else {
            throw NativeAttributeAuthorError.unavailable("original published attribute source")
        }
        let topicNumbers = try NativeAttributeAuthorWire.numberSpellings(readback.raw, beneath: ["data", "topic"])
        guard topicNumbers[["id"]] == String(topicID), topicNumbers[["configVersion"]] == String(currentVersion),
              topicNumbers[["publishedConfigVersion"]] == String(publishedVersion) else {
            throw NativeAttributeAuthorError.invalid("original published integer metadata")
        }
        if !requested.isLocked, Int64(currentVersion) != requested.sourceConfigVersion { throw NativeAttributeAuthorError.staleSource }
        let graph = Data(raw.utf8), snapshot = try NativeAttributeAuthorWire.decode(graph)
        guard snapshot.object?["runtimeSnapshotVersion"]?.integer == 1,
              let attributes = snapshot.object?["dynamicAttributes"]?.object,
              attributes["definitionVersion"]?.integer == publishedVersion,
              let sourceVersion = attributes["sourceConfigVersion"]?.integer, sourceVersion >= 0, sourceVersion <= currentVersion,
              let digest = attributes["sha256"]?.text else {
            throw NativeAttributeAuthorError.unavailable("immutable marker1 published attributes")
        }
        let snapshotNumbers = try NativeAttributeAuthorWire.numberSpellings(graph, beneath: [])
        guard snapshotNumbers[["runtimeSnapshotVersion"]] == "1" else {
            throw NativeAttributeAuthorError.invalid("immutable marker1 integer metadata")
        }
        let binding = try NativeAttributeAuthorBinding(server: requested.server, namespace: requested.namespace,
            accountID: requested.accountID, epoch: requested.epoch, authorizationRevision: requested.authorizationRevision,
            topicID: requested.topicID, sourceConfigVersion: Int64(sourceVersion), requestScope: requested.requestScope,
            source: .locked(definitionVersion: Int64(publishedVersion), sourceConfigVersion: Int64(sourceVersion), sha256: digest))
        if requested.isLocked, requested != binding { throw NativeAttributeAuthorError.staleSource }
        let source = try NativeAttributeAuthorWire.fragment(graph, at: ["dynamicAttributes"])
        _ = try NativeAttributeAuthorService.frozenDraft(binding: binding, source: source)
        return .init(binding: binding, source: source)
    }
    public func readLocked(_ binding: NativeAttributeAuthorBinding) async throws -> Data {
        guard binding.isLocked else { throw NativeAttributeAuthorError.staleSource }
        return try await inspect(binding).source
    }
}
