import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Bundle transfer HTTP client (IWP-8c; EP-BND-24 does NOT exist in the backend yet). Wires nothing.
// Paths follow bundle-backend-spec.md B-24 under `api/free-explore/bundle/`:
//   GET  transfer/preview?registrationId=      (NOT in the backend spec yet: owner question)
//   POST transfer                              { registrationId, receiverPhone, channel, idempotencyKey }
//   GET  transfer/receipt?idempotencyKey=
//   GET  transfer?registrationId=
//   POST transfer/{id}/revoke
//   POST transfer/claim                        { code, idempotencyKey }
// Envelope handling mirrors BundleAPIClient (code == 200, 401 callback, 1 MiB cap, no-store). Writes are
// disabled unless the injected `writeAllowed()` is true (default false). Unknown write outcome =
// `.outcomeUnknown`: read back with the SAME idempotency key. Response bodies and the one-time code are
// never logged, and the code is never kept past the returned `BundleTransferSendResult`.

private struct BundleTransferWire: Decodable {
    let id: FreeExploreLaunchID
    let registrationId: FreeExploreLaunchID?
    let status: String
    let expiresAt: BundleTimestamp?
    let claimCode: String?
    var record: BundleTransferRecord {
        BundleTransferRecord(id: id, registrationId: registrationId, state: BundleTransferState(raw: status), expiresAt: expiresAt)
    }
}

private struct BundleTransferReceiptWire: Decodable {
    enum Kind: String, Decodable { case found = "FOUND", notFound = "NOT_FOUND" }
    let idempotencyKey: String
    let receipt: Kind
    let transfer: BundleTransferWire?
}

private struct BundleTransferClaimWire: Decodable {
    let status: String
    let registrationId: FreeExploreLaunchID
}

@MainActor public final class BundleTransferHTTPClient: BundleTransferServing {
    public let session: FreeExploreLaunchSession
    private let authorization: String
    private let transport: any HTTPTransport
    private let currentSession: () -> FreeExploreLaunchSession?
    private let writeAllowed: () -> Bool
    private let onUnauthorized: (FreeExploreLaunchSession) -> Void
    private static let responseCap = 1_048_576

    public var isCurrent: Bool { currentSession() == session }

    /// `authorization` is the raw token captured with `session` (same convention as `BundleAPIClient`).
    public init(session: FreeExploreLaunchSession, authorization: String, transport: any HTTPTransport,
                currentSession: @escaping () -> FreeExploreLaunchSession?,
                writeAllowed: @escaping () -> Bool = { false },
                onUnauthorized: @escaping (FreeExploreLaunchSession) -> Void = { _ in }) throws {
        guard AuthRequestBuilder.isValidToken(authorization) else { throw FreeExploreLaunchFailure.invalid }
        self.session = session; self.authorization = authorization; self.transport = transport
        self.currentSession = currentSession; self.writeAllowed = writeAllowed; self.onUnauthorized = onUnauthorized
    }

    // MARK: Reads

    public func preview(registrationID: FreeExploreLaunchID) async throws -> BundleTransferPreview {
        let value: BundleTransferPreview = try await fetch(
            request("transfer/preview", query: ["registrationId": registrationID.text]), write: false)
        guard value.registrationId == registrationID else { throw FreeExploreLaunchFailure.malformed }
        return value
    }

    public func receipt(idempotencyKey: String) async throws -> BundleTransferReceipt {
        guard (1...64).contains(idempotencyKey.utf8.count) else { throw FreeExploreLaunchFailure.invalid }
        let value: BundleTransferReceiptWire = try await fetch(
            request("transfer/receipt", query: ["idempotencyKey": idempotencyKey]), write: false)
        guard value.idempotencyKey == idempotencyKey else { throw FreeExploreLaunchFailure.malformed }
        switch value.receipt {
        case .found:
            guard let wire = value.transfer else { throw FreeExploreLaunchFailure.malformed }
            return BundleTransferReceipt(idempotencyKey: idempotencyKey, transfer: wire.record)
        case .notFound:
            guard value.transfer == nil else { throw FreeExploreLaunchFailure.malformed }
            return BundleTransferReceipt(idempotencyKey: idempotencyKey, transfer: nil)
        }
    }

    public func transfers(registrationID: FreeExploreLaunchID) async throws -> [BundleTransferRecord] {
        let wires: [BundleTransferWire] = try await fetch(
            request("transfer", query: ["registrationId": registrationID.text]), write: false)
        let records = wires.map(\.record)
        guard records.allSatisfy({ $0.registrationId == nil || $0.registrationId == registrationID }),
              Set(records.map(\.id)).count == records.count else { throw FreeExploreLaunchFailure.malformed }
        return records
    }

    // MARK: Writes (disabled unless writeAllowed() is true)

    public func send(_ command: BundleTransferSendCommand) async throws -> BundleTransferSendResult {
        try command.validate(); try gateWrite()
        let wire: BundleTransferWire = try await fetch(
            request("transfer", query: [:], body: command.wireData()), write: true)
        // The code is shown once; a created transfer without one cannot be handed over from this device.
        guard wire.registrationId == nil || wire.registrationId == command.registrationId,
              wire.record.state == .pending, wire.expiresAt != nil,
              let plain = wire.claimCode, let code = try? BundleTransferOneTimeCode(plain) else {
            throw FreeExploreLaunchFailure.outcomeUnknown
        }
        return BundleTransferSendResult(record: wire.record, code: code)
    }

    public func revoke(transferID: FreeExploreLaunchID) async throws -> BundleTransferRecord {
        try gateWrite()
        let wire: BundleTransferWire = try await fetch(
            request("transfer/\(transferID.text)/revoke", query: [:], body: Data("{}".utf8)), write: true)
        guard wire.id == transferID else { throw FreeExploreLaunchFailure.outcomeUnknown }
        return wire.record
    }

    public func claim(_ command: BundleTransferClaimCommand) async throws -> BundleTransferClaimResult {
        try gateWrite()
        let wire: BundleTransferClaimWire = try await fetch(
            request("transfer/claim", query: [:], body: command.wireData()), write: true)
        guard wire.status == "CLAIMED" else { throw FreeExploreLaunchFailure.outcomeUnknown }
        return BundleTransferClaimResult(registrationId: wire.registrationId)
    }

    // MARK: Transport

    private func check() throws {
        guard isCurrent else { throw FreeExploreLaunchFailure.staleSession }
        try Task.checkCancellation()
    }
    private func gateWrite() throws {
        try check()
        guard writeAllowed() else { throw FreeExploreLaunchFailure.disabled }
    }

    private func request(_ path: String, query: [String: String], body: Data? = nil) throws -> URLRequest {
        guard var url = URLComponents(url: session.baseURL.appendingPathComponent("api/free-explore/bundle/" + path),
                                      resolvingAgainstBaseURL: false) else { throw FreeExploreLaunchFailure.invalid }
        if !query.isEmpty { url.queryItems = query.keys.sorted().map { URLQueryItem(name: $0, value: query[$0]) } }
        guard let endpoint = url.url else { throw FreeExploreLaunchFailure.invalid }
        var request = URLRequest(url: endpoint)
        request.httpMethod = body == nil ? "GET" : "POST"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue(authorization, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-store", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        if let body {
            request.httpBody = body
            request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request.setValue(String(body.count), forHTTPHeaderField: "Content-Length")
        }
        return request
    }

    private struct Code: Decodable { let code: Int; let businessCode: String? }
    private struct Envelope<T: Decodable>: Decodable { let data: T? }

    private func fetch<T: Decodable>(_ request: URLRequest, write: Bool) async throws -> T {
        if write { try gateWrite() } else { try check() }
        let response: (Data, Int)
        do {
            response = try await transport.send(request)
        } catch {
            if write { throw FreeExploreLaunchFailure.outcomeUnknown }
            try check(); throw error
        }
        let (data, status) = response
        guard isCurrent else { throw write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.staleSession }
        if write, !writeAllowed() { throw FreeExploreLaunchFailure.outcomeUnknown }
        if status == 401 { onUnauthorized(session); throw APIError.unauthorized }
        let unknown = write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.malformed
        guard data.count <= Self.responseCap else { throw unknown }
        let decoder = JSONDecoder()
        let header = try? decoder.decode(Code.self, from: data)
        if header?.code == 401 { onUnauthorized(session); throw APIError.unauthorized }
        guard (200..<300).contains(status), header?.code == 200 else {
            if write, status >= 500 || header == nil { throw FreeExploreLaunchFailure.outcomeUnknown }
            throw FreeExploreLaunchFailure.response(status: status, code: header?.code ?? status, businessCode: header?.businessCode, message: nil)
        }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object.keys.contains("data"),
                  let value = try decoder.decode(Envelope<T>.self, from: data).data else { throw unknown }
            return value
        } catch {
            throw unknown
        }
    }
}
