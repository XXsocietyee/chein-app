import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// MARK: - Refund apply + progress (IWP-R)
// Backend section R and the cash leg are not decided. This client is the typed seam.
// Shipped composition does not construct the HTTP client. `writeAllowed` defaults to false.
// `BundleMoneyWriteGate.allowsRefundApply` stays false, so a refund POST cannot leave the device
// while payment, payout, withdrawal and virtual goods stay off. Approval is not cash arrival:
// PROCESSING, UNKNOWN, MANUAL_PAYOUT and APPROVED are never "refunded".

public enum BundleMoneyWriteGate {
    /// Hard-closed. A refund POST also requires `ReleaseMoneyWriteSwitch.refundEnabled`, which stays false in Release.
    public static let allowsRefundApply = false
    public static let allowsPayment = false
    public static let allowsPayout = false
    public static let allowsWithdrawal = false
    public static let allowsVirtualGoods = false
}

@MainActor public protocol BundleRefundServing: AnyObject {
    var permitsWrites: Bool { get }
    func apply(_ command: BundleRefundApplyCommand) async throws -> BundleRefundProgressPresentation
    func progress(registrationID: FreeExploreLaunchID) async throws -> BundleRefundProgressPresentation
}

/// Default until section R is live and a reviewed composition injects the HTTP client.
@MainActor public final class UnavailableBundleRefundClient: BundleRefundServing {
    public init() {}
    public var permitsWrites: Bool { false }
    public func apply(_ command: BundleRefundApplyCommand) async throws -> BundleRefundProgressPresentation {
        throw FreeExploreLaunchFailure.disabled
    }
    public func progress(registrationID: FreeExploreLaunchID) async throws -> BundleRefundProgressPresentation {
        throw FreeExploreLaunchFailure.disabled
    }
}

/// HTTP implementation. Never constructed by shipped composition.
/// Apply sends the server quote's route and amount verbatim as `expectedRoute` / `expectedAmount`.
@MainActor public final class BundleRefundHTTPClient: BundleRefundServing {
    public let session: FreeExploreLaunchSession
    private let authorization: String
    private let transport: any HTTPTransport
    private let currentSession: () -> FreeExploreLaunchSession?
    private let writeAllowed: () -> Bool
    private let onUnauthorized: (FreeExploreLaunchSession) -> Void
    private static let responseCap = 1_048_576

    public var permitsWrites: Bool {
        isCurrent && writeAllowed() && BundleMoneyWriteGate.allowsRefundApply && ReleaseMoneyWriteSwitch.isEnabled(.refund)
    }
    private var isCurrent: Bool { currentSession() == session }

    public init(session: FreeExploreLaunchSession, authorization: String, transport: any HTTPTransport,
                currentSession: @escaping () -> FreeExploreLaunchSession?,
                writeAllowed: @escaping () -> Bool = { false },
                onUnauthorized: @escaping (FreeExploreLaunchSession) -> Void = { _ in }) throws {
        guard AuthRequestBuilder.isValidToken(authorization) else { throw FreeExploreLaunchFailure.invalid }
        self.session = session; self.authorization = authorization; self.transport = transport
        self.currentSession = currentSession; self.writeAllowed = writeAllowed; self.onUnauthorized = onUnauthorized
    }

    public func apply(_ command: BundleRefundApplyCommand) async throws -> BundleRefundProgressPresentation {
        guard isCurrent else { throw FreeExploreLaunchFailure.staleSession }
        guard permitsWrites else { throw FreeExploreLaunchFailure.disabled }
        let body = ApplyBody(registrationId: command.registrationId, unitIds: command.unitIDs,
                              idempotencyKey: command.idempotencyKey, expectedRoute: command.expectedRoute,
                              expectedAmount: command.expectedAmount)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let value: BundleRefundProgressWire = try await fetch(request("order/refund", query: [:], body: try encoder.encode(body)), write: true)
        guard value.registrationId == command.registrationId, !value.state.isEmpty else { throw FreeExploreLaunchFailure.outcomeUnknown }
        return BundleRefundProgressPresentation(state: value.state, refundNo: value.refundNo)
    }

    public func progress(registrationID: FreeExploreLaunchID) async throws -> BundleRefundProgressPresentation {
        let value: BundleRefundProgressWire = try await fetch(
            request("order/refund", query: ["registrationId": registrationID.text], body: nil), write: false)
        guard value.registrationId == registrationID, !value.state.isEmpty else { throw FreeExploreLaunchFailure.malformed }
        return BundleRefundProgressPresentation(state: value.state, refundNo: value.refundNo)
    }

    private struct ApplyBody: Encodable {
        let registrationId: FreeExploreLaunchID
        let unitIds: [FreeExploreLaunchID]
        let idempotencyKey: String
        let expectedRoute: String
        let expectedAmount: String
    }

    private struct BundleRefundProgressWire: Decodable {
        let registrationId: FreeExploreLaunchID
        let state: String
        let refundNo: String?
    }

    private func request(_ path: String, query: [String: String], body: Data?) throws -> URLRequest {
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
        if write { guard permitsWrites else { throw FreeExploreLaunchFailure.disabled } }
        else { guard isCurrent else { throw FreeExploreLaunchFailure.staleSession } }
        try Task.checkCancellation()
        let response: (Data, Int)
        do { response = try await transport.send(request) }
        catch {
            if write { throw FreeExploreLaunchFailure.outcomeUnknown }
            guard isCurrent else { throw FreeExploreLaunchFailure.staleSession }
            throw error
        }
        let (data, status) = response
        guard isCurrent else { throw write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.staleSession }
        if write, !permitsWrites { throw FreeExploreLaunchFailure.outcomeUnknown }
        if status == 401 { onUnauthorized(session); throw APIError.unauthorized }
        let unknown = write ? FreeExploreLaunchFailure.outcomeUnknown : FreeExploreLaunchFailure.malformed
        guard data.count <= Self.responseCap else { throw unknown }
        let decoder = JSONDecoder()
        let header = try? decoder.decode(Code.self, from: data)
        if header?.code == 401 { onUnauthorized(session); throw APIError.unauthorized }
        guard (200..<300).contains(status), header?.code == 200 else {
            if write, status >= 500 || header == nil { throw FreeExploreLaunchFailure.outcomeUnknown }
            throw FreeExploreLaunchFailure.response(status: status, code: header?.code ?? status, businessCode: header?.businessCode)
        }
        do {
            guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any], object.keys.contains("data") else { throw unknown }
            guard let value = try decoder.decode(Envelope<T>.self, from: data).data else { throw unknown }
            return value
        } catch { throw unknown }
    }
}
