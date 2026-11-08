import Foundation

/// Anonymous receiver-side reader for `subpackageRoam/session?shareToken=`.
/// Closed by default: without a host approval it reports `.unavailable` and sends nothing.
/// The request is the exact source GET (`RoamShareToken.request`): no Authorization, no cookies.
@MainActor public final class RoamShareSnapshotHTTPReader: RoamShareSnapshotReading {
    private let baseURL: URL
    private let transport: any HTTPTransport
    private let isApproved: () -> Bool
    public init(baseURL: URL, transport: any HTTPTransport, isApproved: @escaping () -> Bool) {
        self.baseURL = baseURL; self.transport = transport; self.isApproved = isApproved
    }
    public func snapshot(_ token: RoamShareToken) async -> RoamShareSnapshotOutcome {
        guard isApproved() else { return .unavailable }
        guard let request = try? token.request(baseURL: baseURL) else { return .error }
        do {
            let (data, status) = try await transport.send(request)
            guard isApproved() else { return .unavailable }
            return RoamShareSnapshotOutcome.resolve(data: data, status: status)
        } catch {
            return .error
        }
    }
}
