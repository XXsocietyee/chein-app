import Foundation

/// Builds the anonymous share-snapshot reader for `RoamSharedFootprintView(reader:)`.
/// Hook (composition root, not edited here): pass the result as `reader:` when the session
/// page opens with `?shareToken=`. A nil `approval` closure keeps the page on its honest
/// "cannot open shared footprints yet" state.
@MainActor enum RoamShareSnapshotReaderFactory {
    static func make(baseURL: URL?, transport: (any HTTPTransport)?, approval: (() -> Bool)?) -> (any RoamShareSnapshotReading)? {
        guard let baseURL, let transport, let approval else { return nil }
        return RoamShareSnapshotHTTPReader(baseURL: baseURL, transport: transport, isApproved: approval)
    }
}
