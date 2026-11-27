import Foundation

// ADAPT-2: adapter for the ADAPTABLE rows of docs/release/gap345/merchant-topic.md.
// Everything here is NEW and dormant: nothing is wired into AppSession / AppCompositionRoot / QuestifyApp,
// existing contract types, allow-lists and constants are intentionally left untouched.
// Route facts were re-verified against hengyin controllers (see docs/release/gap345/adapt-2-report.md).

/// Backend routes that replace iOS legacy names which have no backend route.
public enum Adapt2MerchantTopicRoute: String, CaseIterable, Equatable {
    /// ApiAiController `@PostMapping("/merchant/insight")` under `/api/ai`; no parameters.
    case merchantInsight = "api/ai/merchant/insight"
    /// ApiMerchantController `@PostMapping("/public-detail")`, JSON `MmsMerchant` (only `id` is read), anonymous-capable.
    case merchantPublicDetail = "api/merchant/public-detail"
    /// ApiMerchantController `@PostMapping("/merchant_registration")`, JSON `MerchantRegistrationDTO`, token required.
    case merchantRegistration = "api/merchant/merchant_registration"
    /// ApiTopicController `@PostMapping("/info-to-user")`, form field `id`.
    case topicInfoToUser = "api/topic/info-to-user"
    /// ApiMerchantController `@PostMapping("/npc/voice/reset")`, no parameters, merchant PROFILE_WRITE.
    case npcVoiceReset = "api/merchant/npc/voice/reset"

    public enum Encoding: Equatable { case none, json, form }

    public var encoding: Encoding {
        switch self {
        case .merchantInsight, .npcVoiceReset: return .none
        case .merchantPublicDetail, .merchantRegistration: return .json
        case .topicInfoToUser: return .form
        }
    }

    /// Public detail is documented anonymous-capable; every other route needs the raw token.
    public var requiresToken: Bool { self != .merchantPublicDetail }

    /// Legacy iOS path (no backend route) -> served replacement. Legacy strings are NOT sent anywhere.
    public static let legacyReplacements: [String: Adapt2MerchantTopicRoute] = [
        "api/merchant/insight": .merchantInsight,
        "api/merchant/poi/detail": .merchantPublicDetail,
        "api/merchant/shop/apply": .merchantRegistration,
        "api/merchant/npc/voice/revoke": .npcVoiceReset,
    ]
}

public enum Adapt2Failure: Error, Equatable {
    case disabled, invalid, malformed, unknownOutcome, unauthorized
    case rejected(code: Int, message: String?)
}

/// Builds requests for the routes above. Authorization is the raw token (no Bearer), matching AuthRequestBuilder.
public struct Adapt2MerchantTopicRequestBuilder {
    public let baseURL: URL
    public init(baseURL: URL) { self.baseURL = baseURL }

    public func make(_ route: Adapt2MerchantTopicRoute, token: String?, json: Data? = nil, form: [String: String] = [:]) throws -> URLRequest {
        if route.requiresToken {
            guard let token, AuthRequestBuilder.isValidToken(token) else { throw Adapt2Failure.invalid }
        }
        var request = URLRequest(url: baseURL.appendingPathComponent(route.rawValue))
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 30
        if let token, AuthRequestBuilder.isValidToken(token) { request.setValue(token, forHTTPHeaderField: "Authorization") }
        switch route.encoding {
        case .none:
            guard json == nil, form.isEmpty else { throw Adapt2Failure.invalid }
        case .json:
            guard form.isEmpty, let json, json.count <= 128 * 1024,
                  (try? JSONSerialization.jsonObject(with: json)) is [String: Any] else { throw Adapt2Failure.invalid }
            request.httpBody = json
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        case .form:
            guard json == nil, !form.isEmpty else { throw Adapt2Failure.invalid }
            var allowed = CharacterSet.alphanumerics; allowed.insert(charactersIn: "-._~")
            let encode: (String) -> String = { $0.addingPercentEncoding(withAllowedCharacters: allowed) ?? "" }
            request.httpBody = Data(form.keys.sorted().map { "\(encode($0))=\(encode(form[$0]!))" }.joined(separator: "&").utf8)
            request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    /// `public-detail` body: only `id` is read by the controller.
    public func publicDetail(merchantID: Int) throws -> URLRequest {
        guard merchantID > 0 else { throw Adapt2Failure.invalid }
        return try make(.merchantPublicDetail, token: nil, json: try JSONSerialization.data(withJSONObject: ["id": merchantID], options: [.sortedKeys]))
    }

    /// `info-to-user` form field `id`.
    public func topicInfo(topicID: Int, token: String) throws -> URLRequest {
        guard topicID > 0 else { throw Adapt2Failure.invalid }
        return try make(.topicInfoToUser, token: token, form: ["id": String(topicID)])
    }
}

/// AjaxResult `{code,msg,data}` unwrapping. Business errors arrive as HTTP 200 with `code != 200`.
public enum Adapt2AjaxEnvelope {
    public struct Result: Equatable {
        public let message: String?
        public let data: Data?
    }

    public static func unwrap(status: Int, body: Data) throws -> Result {
        if status == 401 || status == 403 { throw Adapt2Failure.unauthorized }
        if status >= 500 { throw Adapt2Failure.unknownOutcome }
        guard (200..<300).contains(status) else { throw Adapt2Failure.rejected(code: status, message: nil) }
        guard let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any], let code = object["code"] as? Int else { throw Adapt2Failure.malformed }
        let message = object["msg"] as? String
        if code == 401 { throw Adapt2Failure.unauthorized }
        guard code == 200 else { throw Adapt2Failure.rejected(code: code, message: message) }
        var data: Data?
        if let value = object["data"], !(value is NSNull) {
            data = try? JSONSerialization.data(withJSONObject: value, options: [.fragmentsAllowed, .sortedKeys])
        }
        return Result(message: message, data: data)
    }
}

/// Replacement for the unserved `npc/voice/revoke`: backend `npc/voice/reset`. Safety gate defaults to OFF.
/// The controller takes no body and no request id (reset is a single conditional DB update), so `requestID`
/// is NOT sent; it only lets callers keep their own dedupe.
public struct Adapt2MerchantNPCVoiceResetClient {
    private let builder: Adapt2MerchantTopicRequestBuilder
    private let token: () -> String?
    private let transport: any HTTPTransport
    private let allowed: () -> Bool

    public init(baseURL: URL, token: @escaping () -> String?, transport: any HTTPTransport, allowed: @escaping () -> Bool = { false }) {
        self.builder = Adapt2MerchantTopicRequestBuilder(baseURL: baseURL)
        self.token = token; self.transport = transport; self.allowed = allowed
    }

    public func reset() async throws -> MerchantNPCResourceReceipt {
        guard allowed() else { throw MerchantNPCFailure.disabled }
        let request: URLRequest
        do { request = try builder.make(.npcVoiceReset, token: token()) }
        catch { throw MerchantNPCFailure.invalid }
        let result: (Data, Int)
        do { result = try await transport.send(request) } catch { throw MerchantNPCFailure.unknownOutcome }
        do {
            let unwrapped = try Adapt2AjaxEnvelope.unwrap(status: result.1, body: result.0)
            return .accepted(message: unwrapped.message)
        } catch let failure as Adapt2Failure {
            switch failure {
            case .rejected(let code, let message): throw MerchantNPCFailure.rejected(code: code, message: message)
            case .malformed: throw MerchantNPCFailure.malformed
            case .unauthorized, .unknownOutcome: throw MerchantNPCFailure.unknownOutcome
            case .disabled: throw MerchantNPCFailure.disabled
            case .invalid: throw MerchantNPCFailure.invalid
            }
        }
    }
}
