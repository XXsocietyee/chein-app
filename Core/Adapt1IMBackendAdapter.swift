import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// ADAPT-1 transport for the REAL backend (`hengyin@4ac8c249`, `ApiImController`).
///
/// The strict `IMExpandedService` contract expects receipts the shipped backend does not
/// produce (`data{source,...}` on mute/read). This is a separate, injectable adapter: it never
/// replaces that service, is not wired into any composition root, and every path is OFF by
/// default (`writesEnabled == false`, `enabledPaths == []`). Paths outside `Adapt1IMPath.all`
/// can never be enabled here.
public enum Adapt1IMPath {
    public static let conversations = "api/im/conversations"
    public static let read = "api/im/read"
    public static let mute = "api/im/mute"
    public static let report = "api/im/report"
    public static let send = "api/im/send"
    public static let all: Set<String> = [conversations, read, mute, report, send]
}

/// Mute state derived on the App side from the `/api/im/conversations` row.
/// It is NOT the server-attested `OrdinaryIMMuteCurrent` (no `source` attestation exists server side).
public struct Adapt1MuteCurrent: Equatable {
    public static let source = "app-derived-im-conversations-v1"
    public let source: String
    public let ownerMemberID: String
    public let conversationID: Int
    public let conversationType: Int
    public let muted: Bool
}

public struct Adapt1IMBackendAdapter {
    let configuration: APIConfiguration
    let transport: any HTTPTransport
    private let writesEnabled: Bool
    private let enabledPaths: Set<String>

    public init(configuration: APIConfiguration, transport: any HTTPTransport,
                writesEnabled: Bool = false, enabledPaths: Set<String> = []) {
        self.configuration = configuration; self.transport = transport
        self.writesEnabled = writesEnabled
        self.enabledPaths = enabledPaths.intersection(Adapt1IMPath.all)
    }

    func allow(_ path: String, write: Bool) throws {
        guard Adapt1IMPath.all.contains(path), enabledPaths.contains(path), !write || writesEnabled else {
            throw APIError.notConfigured
        }
    }

    /// POST multipart form with the raw Authorization token. The backend binds query/form only (no `@RequestBody`).
    /// Business errors arrive as HTTP 200 with `{code:<n>,msg}`; success without data is `{code:200,msg}`.
    func post(_ path: String, fields: [String: String], token: String) async throws -> Data {
        guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
        var request = try AuthRequestBuilder.makeFormRequest(
            url: configuration.baseURL.appendingPathComponent(path), fields: fields, token: token)
        request.httpShouldHandleCookies = false
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        guard data.count <= 2 * 1024 * 1024 else { throw APIError.malformedResponse }
        struct Header: Decodable { let code: Int; let msg: String?; let errorCode: String? }
        let header = try? JSONDecoder().decode(Header.self, from: data)
        guard (200..<300).contains(status) else {
            throw MessagingReadFailure(httpStatus: status, code: header?.code, errorCode: header?.errorCode, message: header?.msg)
        }
        guard let header else { throw APIError.malformedResponse }
        guard header.code == 200 else {
            throw MessagingReadFailure(code: header.code, errorCode: header.errorCode, message: header.msg)
        }
        return data
    }

    /// One `POST api/im/conversations` read (bare array in `data`, no paging).
    func conversationRows(token: String) async throws -> [MessagingConversation] {
        try await MessagingService(configuration: configuration, transport: transport).conversations(token: token)
    }

    /// Readback failure after an accepted write is an unknown outcome, never a failure that grants a retry.
    func readbackRow(conversationID: Int, token: String) async throws -> MessagingConversation? {
        do { return try await conversationRows(token: token).first { $0.id == conversationID } }
        catch is CancellationError { throw CancellationError() }
        catch { throw IMCapabilityGap.unknownOutcome }
    }

    // MARK: A1 / A2 — ordinary mute

    /// `POST api/im/mute` form `conversation_id`, `muted` (0|1), `request_id` (ignored by the backend).
    /// The backend answers `{code:200,msg}` with no `data`; the result is therefore proven only by an
    /// immediate `conversations` readback of the same row. Missing row / mismatch / absent `muted` => unknownOutcome.
    public func setMute(_ intent: OrdinaryIMMuteIntent, token: String) async throws -> OrdinaryIMMuteReceipt {
        try allow(Adapt1IMPath.mute, write: true)
        try allow(Adapt1IMPath.conversations, write: false)
        _ = try await post(Adapt1IMPath.mute, fields: [
            "conversation_id": String(intent.scope.conversationID),
            "muted": intent.muted ? "1" : "0",
            "request_id": intent.requestID], token: token)
        guard let row = try await readbackRow(conversationID: intent.scope.conversationID, token: token),
              let actual = row.muted, actual == intent.muted else { throw IMCapabilityGap.unknownOutcome }
        return .applied
    }

    /// Current mute state from the `conversations` row, with an App-side `source` marker.
    public func muteState(scope: IMScope, token: String) async throws -> Adapt1MuteCurrent {
        try allow(Adapt1IMPath.conversations, write: false)
        let rows = try await conversationRows(token: token)
        guard let row = rows.first(where: { $0.id == scope.conversationID }),
              let muted = row.muted, let type = row.type, [1, 2, 3].contains(type) else { throw APIError.malformedResponse }
        return Adapt1MuteCurrent(source: Adapt1MuteCurrent.source, ownerMemberID: String(scope.identity.accountID),
                                 conversationID: row.id, conversationType: type, muted: muted)
    }
}
