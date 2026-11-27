import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Components r1 R-island: sends Live Activity push tokens to `POST /api/live-activity/token`
/// (contract in `docs/release/receipts/comp-r1-island-steps.md`). Idempotent on the server by
/// (account, scope, attributesType, planKey, activityId); a failed send is retried by the caller with the newest token,
/// never with an older one. The response body is not needed beyond `code == 200`.
public struct QuestPlanActivityTokenService {
    public static let path = "api/live-activity/token"
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let token: () -> String?

    public init(configuration: APIConfiguration, transport: any HTTPTransport, token: @escaping () -> String?) {
        self.configuration = configuration; self.transport = transport; self.token = token
    }

    /// The request this service sends; nil when signed out or the body is not well formed.
    public func urlRequest(for body: QuestPlanActivityTokenRequest) -> URLRequest? {
        guard body.isValid, let token = token(), AuthRequestBuilder.isValidToken(token),
              let data = try? Self.encoder.encode(body) else { return nil }
        var request = URLRequest(url: configuration.baseURL.appendingPathComponent(Self.path),
                                 cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 20)
        request.httpMethod = "POST"
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.httpBody = data
        return request
    }

    /// True when the server accepted the token (HTTP 2xx and envelope `code == 200`).
    public func register(_ body: QuestPlanActivityTokenRequest) async -> Bool {
        guard let request = urlRequest(for: body) else { return false }
        guard let reply = try? await transport.send(request), (200..<300).contains(reply.1) else { return false }
        return (try? JSONDecoder().decode(QuestPlanActivityTokenReply.self, from: reply.0))?.code == 200
    }

    static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}

struct QuestPlanActivityTokenReply: Decodable { let code: Int? }
