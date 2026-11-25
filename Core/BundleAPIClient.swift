import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Bundle API client (IWP-0 foundation; wires nothing)
// Beside, not inside, FreeExploreLaunchService (protected, pinned by tests; its envelope code is private).
// Envelope handling mirrors FreeExploreLaunchService.executeOptional: code == 200, businessCode, 401 callback,
// 1 MiB cap, Cache-Control: no-store. Login loss is business 409 + LOGIN_REQUIRED, which is a definite
// `.response` failure and never the 401 path (it must not retire the session or clear a pending command).
// Writes are disabled unless the injected `writeAllowed()` is true (default false). An unknown write outcome
// (transport error, 5xx, undecodable 200, session/permission change mid-flight) is `.outcomeUnknown`:
// callers must read back with the SAME idempotency key, never resend blindly.

public enum BundleExitDecision: String, Codable, Equatable {
    case swapConsented = "SWAP_CONSENTED"
    case refundUnfulfilled = "REFUND_UNFULFILLED"
}

/// `POST exit-decision` body: `{ unitId, decision, targetOfferId?, idempotencyKey }`.
public struct BundleExitDecisionCommand: Encodable, Equatable {
    public let unitId: FreeExploreLaunchID
    public let decision: BundleExitDecision
    public let targetOfferId: FreeExploreLaunchID?
    public let idempotencyKey: String
    public init(unitId: FreeExploreLaunchID, decision: BundleExitDecision,
                targetOfferId: FreeExploreLaunchID?, idempotencyKey: String) throws {
        self.unitId = unitId; self.decision = decision
        self.targetOfferId = targetOfferId; self.idempotencyKey = idempotencyKey
        try validate()
    }
    func validate() throws {
        switch decision {
        case .swapConsented: guard targetOfferId != nil else { throw FreeExploreLaunchFailure.invalid }
        case .refundUnfulfilled: guard targetOfferId == nil else { throw FreeExploreLaunchFailure.invalid }
        }
        guard (1...64).contains(idempotencyKey.utf8.count),
              idempotencyKey.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw FreeExploreLaunchFailure.invalid
        }
    }
    func wireData() throws -> Data {
        try validate(); let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(self)
    }
}

private struct BundleCancelBody: Encodable {
    let useWaiver: Bool
    let expectedOutcome: String
}

@MainActor public final class BundleAPIClient {
    public let session: FreeExploreLaunchSession
    private let authorization: String
    private let transport: any HTTPTransport
    private let currentSession: () -> FreeExploreLaunchSession?
    private let writeAllowed: () -> Bool
    private let onUnauthorized: (FreeExploreLaunchSession) -> Void
    private static let responseCap = 1_048_576

    public var isCurrent: Bool { currentSession() == session }
    public var permitsWrites: Bool { isCurrent && writeAllowed() }

    /// `authorization` is the raw session token captured with `session` (FreeExploreLaunchSession keeps its
    /// token fileprivate, and that file is protected). It is sent verbatim as the `Authorization` header.
    public init(session: FreeExploreLaunchSession, authorization: String, transport: any HTTPTransport,
                currentSession: @escaping () -> FreeExploreLaunchSession?,
                writeAllowed: @escaping () -> Bool = { false },
                onUnauthorized: @escaping (FreeExploreLaunchSession) -> Void = { _ in }) throws {
        guard AuthRequestBuilder.isValidToken(authorization) else { throw FreeExploreLaunchFailure.invalid }
        self.session = session; self.authorization = authorization; self.transport = transport
        self.currentSession = currentSession; self.writeAllowed = writeAllowed; self.onUnauthorized = onUnauthorized
    }

    // MARK: Reads

    public func orderReceipt(requestId: String) async throws -> BundleOrderReceipt {
        let id = requestId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !id.isEmpty, id.utf8.count <= 128, id.utf8.allSatisfy({ $0 >= 0x20 && $0 < 0x7f }) else {
            throw FreeExploreLaunchFailure.invalid
        }
        let value: BundleOrderReceipt = try await fetch(request("order/receipt", query: ["requestId": id]), write: false)
        guard value.requestId == id else { throw FreeExploreLaunchFailure.malformed }
        switch value.receipt {
        case .found:
            guard let order = value.order else { throw FreeExploreLaunchFailure.malformed }
            if let bundle = order.bundle, bundle.order.holderMemberId != session.accountID { throw FreeExploreLaunchFailure.malformed }
        case .notFound:
            guard value.order == nil else { throw FreeExploreLaunchFailure.malformed }
        }
        return value
    }

    public func cancelQuote(reservationID: FreeExploreLaunchID, useWaiver: Bool) async throws -> BundleCancelQuote {
        let value: BundleCancelQuote = try await fetch(
            request("reservation/\(reservationID.text)/cancel-quote", query: ["useWaiver": useWaiver ? "true" : "false"]), write: false)
        guard value.reservationId == reservationID, value.useWaiver == useWaiver,
              value.holderMemberId == session.accountID, !value.expectedOutcome.isEmpty else { throw FreeExploreLaunchFailure.malformed }
        return value
    }

    public func exitOptions(registrationID: FreeExploreLaunchID, unitID: FreeExploreLaunchID) async throws -> BundleExitOptions {
        let value: BundleExitOptions = try await fetch(
            request("exit-options", query: ["registrationId": registrationID.text, "unitId": unitID.text]), write: false)
        guard value.registrationId == registrationID, value.unitId == unitID,
              value.holderMemberId == session.accountID else { throw FreeExploreLaunchFailure.malformed }
        return value
    }

    // MARK: Writes (disabled unless writeAllowed() is true)

    /// `expectedOutcome` is mandatory here (the server tolerates omission; this client never does) and must be
    /// the server quote's value verbatim.
    public func cancel(reservationID: FreeExploreLaunchID, useWaiver: Bool,
                       expectedOutcome: String) async throws -> FreeExploreLaunchReservation {
        guard (1...64).contains(expectedOutcome.utf8.count),
              expectedOutcome.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 || $0 == 58 }) else {
            throw FreeExploreLaunchFailure.invalid
        }
        try gateWrite()
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let body = try encoder.encode(BundleCancelBody(useWaiver: useWaiver, expectedOutcome: expectedOutcome))
        let value: FreeExploreLaunchReservation = try await fetch(
            request("reservation/\(reservationID.text)/cancel", query: [:], body: body), write: true)
        guard value.id == reservationID, value.holderMemberId == session.accountID, !value.status.isEmpty else {
            throw FreeExploreLaunchFailure.outcomeUnknown
        }
        return value
    }

    public func exitDecision(_ command: BundleExitDecisionCommand) async throws -> BundleExitCase {
        try command.validate(); try gateWrite()
        let value: BundleExitCase = try await fetch(
            request("exit-decision", query: [:], body: command.wireData()), write: true)
        guard value.holderMemberId == session.accountID, value.unitId == command.unitId,
              value.decision == command.decision.rawValue, value.idempotencyKey == command.idempotencyKey else {
            throw FreeExploreLaunchFailure.outcomeUnknown
        }
        return value
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
        guard let value: T = try await perform(request, write: write) else {
            throw write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.malformed
        }
        return value
    }

    private func perform<T: Decodable>(_ request: URLRequest, write: Bool) async throws -> T? {
        if write { try gateWrite() } else { try check() }
        let response: (Data, Int)
        do {
            response = try await transport.send(request)
        } catch {
            // Request may have reached the server: a write is "unknown", never "failed".
            if write { throw FreeExploreLaunchFailure.outcomeUnknown }
            try check(); throw error
        }
        let (data, status) = response
        // Re-check after the network call (session switched / permission retired mid-flight).
        guard isCurrent else { throw write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.staleSession }
        if write, !writeAllowed() { throw FreeExploreLaunchFailure.outcomeUnknown }
        if status == 401 { onUnauthorized(session); throw APIError.unauthorized }
        let unknown = write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.malformed
        guard data.count <= Self.responseCap else { throw unknown }
        let decoder = JSONDecoder()
        let header = try? decoder.decode(Code.self, from: data)
        // Only the HTTP status or an envelope code of 401 is "unauthorized"; business 409 LOGIN_REQUIRED is not.
        if header?.code == 401 { onUnauthorized(session); throw APIError.unauthorized }
        guard (200..<300).contains(status), header?.code == 200 else {
            if write, status >= 500 || header == nil { throw FreeExploreLaunchFailure.outcomeUnknown }
            throw FreeExploreLaunchFailure.response(status: status, code: header?.code ?? status, businessCode: header?.businessCode, message: nil)
        }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object.keys.contains("data") else {
                throw unknown
            }
            return try decoder.decode(Envelope<T>.self, from: data).data
        } catch {
            throw unknown
        }
    }
}
