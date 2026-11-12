import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Allow-list for the refund skeleton (IWP-R). Nothing in the shipped build sets `writeAllowed` true.
///   GET  {base}/api/free-explore/bundle/order/refund?registrationId=<bound id>
///   POST {base}/api/free-explore/bundle/order/refund
///        body keys exactly registrationId, unitIds, idempotencyKey, expectedRoute, expectedAmount
/// A POST is refused unless `writeAllowed()` is true before and after the call. A 403 retires the permission.
@MainActor final class BundleRefundTransport: HTTPTransport {
    private let captured: RuntimeDependencyContext
    private let registrationID: FreeExploreLaunchID
    private let underlying: any HTTPTransport
    private let current: () -> RuntimeDependencyContext?
    private let writeAllowed: () -> Bool
    private let denied: () -> Void
    private var active = true
    private static let bodyCap = 4_096
    private static let responseCap = 1_048_576

    init(context: RuntimeDependencyContext, registrationID: FreeExploreLaunchID, underlying: any HTTPTransport,
         current: @escaping () -> RuntimeDependencyContext?,
         writeAllowed: @escaping () -> Bool = { false },
         denied: @escaping () -> Void = {}) throws {
        guard context.market == .china, context.session.accountID > 0,
              AuthRequestBuilder.isValidToken(context.session.token) else { throw APIError.invalidConfiguration }
        captured = context
        self.registrationID = registrationID
        self.underlying = underlying
        self.current = current
        self.writeAllowed = writeAllowed
        self.denied = denied
    }

    var isCurrent: Bool { active && current() == captured }
    func retire() { active = false }

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        try Task.checkCancellation()
        guard active, current() == captured,
              request.value(forHTTPHeaderField: "Authorization") == captured.session.token,
              request.httpBodyStream == nil,
              let url = request.url, let parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.user == nil, parts.password == nil, parts.fragment == nil else { throw APIError.notConfigured }
        let writing = request.httpMethod == "POST"
        if writing {
            guard writeAllowed(), parts.query == nil, bodyIsExact(request), url.absoluteString == postURL else { throw FreeExploreLaunchFailure.disabled }
        } else {
            guard request.httpMethod == "GET", request.httpBody == nil, url.absoluteString == progressURL else { throw APIError.notConfigured }
        }
        let result = try await underlying.send(request)
        try Task.checkCancellation()
        guard active, current() == captured else { throw writing ? FreeExploreLaunchFailure.outcomeUnknown : APIError.notConfigured }
        if writing, !writeAllowed() { throw FreeExploreLaunchFailure.outcomeUnknown }
        guard result.0.count <= Self.responseCap else { throw FreeExploreLaunchFailure.malformed }
        let bodyCode = (try? JSONSerialization.jsonObject(with: result.0) as? [String: Any])?["code"] as? Int
        if result.1 == 403 || bodyCode == 403 { active = false; denied(); throw APIError.notConfigured }
        return result
    }

    private var postURL: String {
        captured.baseURL.appendingPathComponent("api/free-explore/bundle/order/refund").absoluteString
    }

    private var progressURL: String {
        var parts = URLComponents(url: captured.baseURL.appendingPathComponent("api/free-explore/bundle/order/refund"),
                                  resolvingAgainstBaseURL: false)
        parts?.queryItems = [URLQueryItem(name: "registrationId", value: registrationID.text)]
        return parts?.url?.absoluteString ?? ""
    }

    private func bodyIsExact(_ request: URLRequest) -> Bool {
        guard request.value(forHTTPHeaderField: "Content-Type") == "application/json; charset=utf-8",
              let body = request.httpBody, !body.isEmpty, body.count <= Self.bodyCap,
              request.value(forHTTPHeaderField: "Content-Length") == String(body.count),
              let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any],
              Set(object.keys) == ["registrationId", "unitIds", "idempotencyKey", "expectedRoute", "expectedAmount"],
              Self.positiveID(object["registrationId"]),
              (object["registrationId"] as? NSNumber)?.stringValue == registrationID.text,
              let units = object["unitIds"] as? [Any], !units.isEmpty, units.allSatisfy({ Self.positiveID($0) }),
              let key = object["idempotencyKey"] as? String, !key.isEmpty, key.utf8.count <= 64,
              let route = object["expectedRoute"] as? String, !route.isEmpty, route.utf8.count <= 64,
              let amount = object["expectedAmount"] as? String, !amount.isEmpty, amount.utf8.count <= 100 else { return false }
        return true
    }

    private static func positiveID(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() else { return false }
        return number.int64Value > 0 && number.stringValue == String(number.int64Value)
    }
}
