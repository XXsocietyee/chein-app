import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Round-2 service methods for `player-content` MP gaps:
/// `PC-A-2-1`, `PC-A-4-2`, `PC-A-5-5`, `PC-B-3-2`, `PC-D-1-3/6`, `PC-D-4-2`, `PC-D-9-1/3`.
@MainActor
public final class PlayerContentRound2Service {
    public static let paths: Set<String> = [
        "api/template/list",
        "api/search/unified",
        "api/category/list",
        "api/merchant/info",
        "api/registration/merchant/list",
        "api/merchant/chapter-application/mine",
        "api/activity/cancel_preview",
        "api/coop/finance",
        "api/im/read",
        "api/im/report"
    ]

    public let baseURL: URL
    private let token: () -> String?
    private let transport: any HTTPTransport

    public init(baseURL: URL, token: @escaping () -> String?, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.token = token
        self.transport = transport
    }

    func makeRequest(
        _ path: String,
        method: String,
        query: [String: String] = [:],
        json: [String: PlayWireValue]? = nil,
        form: [String: String]? = nil,
        requireAuth: Bool = true
    ) throws -> URLRequest {
        var url = baseURL.appendingPathComponent(path)
        if !query.isEmpty {
            guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
                throw APIError.invalidRequest
            }
            components.queryItems = query.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            guard let built = components.url else { throw APIError.invalidRequest }
            url = built
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if requireAuth {
            guard let token = token(), AuthRequestBuilder.isValidToken(token) else {
                throw APIError.invalidRequest
            }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        if let json {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            request.httpBody = try encoder.encode(json)
        } else if let form {
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            var components = URLComponents()
            components.queryItems = form.sorted { $0.key < $1.key }.map { URLQueryItem(name: $0.key, value: $0.value) }
            let encoded = (components.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B")
            request.httpBody = Data(encoded.utf8)
        }
        return request
    }

    private func send(_ request: URLRequest) async -> PlayerGapReply {
        do {
            let (data, status) = try await transport.send(request)
            return PlayerGapReply.classify(data: data, status: status)
        } catch {
            return .unknown
        }
    }

    /// `PC-A-2-1`: `POST /api/template/list` (form `pageNum`, `pageSize=50`, `keyword?`)
    public func fetchTemplateShelfPage(pageNum: Int, keyword: String? = nil) async -> PlayerGapReply {
        var form: [String: String] = [
            "pageNum": String(pageNum),
            "pageSize": String(TemplateShelfPagination.mpPageSize)
        ]
        if let keyword, !keyword.isEmpty { form["keyword"] = keyword }
        guard let req = try? makeRequest("api/template/list", method: "POST", form: form, requireAuth: false) else {
            return .unknown
        }
        return await send(req)
    }

    /// `PC-A-4-2`: `POST /api/search/unified` (form `keyword`, `pageNum`, `pageSize`)
    public func searchUnified(keyword: String, pageNum: Int = 1, pageSize: Int = 20) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/search/unified",
            method: "POST",
            form: [
                "keyword": keyword,
                "pageNum": String(pageNum),
                "pageSize": String(pageSize)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-A-5-5`: `POST /api/category/list` (form `type=MERCHANT`)
    public func fetchMerchantCategories() async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/category/list",
            method: "POST",
            form: ["type": "MERCHANT"],
            requireAuth: false
        ) else { return .unknown }
        return await send(req)
    }

    /// `PC-B-3-2`: `POST /api/merchant/info`
    public func fetchMerchantPrefillInfo() async -> PlayerGapReply {
        guard let req = try? makeRequest("api/merchant/info", method: "POST", form: [:]) else {
            return .unauthorized
        }
        return await send(req)
    }

    /// `PC-D-1-6`: `POST /api/registration/merchant/list` + `POST /api/merchant/chapter-application/mine`
    public func fetchMerchantRegistrations() async -> PlayerGapReply {
        guard let req = try? makeRequest("api/registration/merchant/list", method: "POST", form: [:]) else {
            return .unauthorized
        }
        return await send(req)
    }

    public func fetchMerchantChapterApplications() async -> PlayerGapReply {
        guard let req = try? makeRequest("api/merchant/chapter-application/mine", method: "POST", form: [:]) else {
            return .unauthorized
        }
        return await send(req)
    }

    /// `PC-D-1-3`: `POST /api/activity/cancel_preview` (form `id`)
    public func fetchActivityCancelPreview(activityID: Int) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/activity/cancel_preview",
            method: "POST",
            form: ["id": String(activityID)]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-D-4-2`: `POST /api/coop/finance`
    public func fetchCoopFinance(pageNum: Int = 1, pageSize: Int = 20) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/coop/finance",
            method: "POST",
            json: [
                "pageNum": .integer(Int64(pageNum)),
                "pageSize": .integer(Int64(pageSize))
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-D-9-1`: `POST /api/im/read {conversation_id, read_to}`
    public func markConversationRead(conversationID: String, readToMessageID: String) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/im/read",
            method: "POST",
            json: [
                "conversation_id": .string(conversationID),
                "read_to": .string(readToMessageID)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }

    /// `PC-D-9-3`: `POST /api/im/report {targetType: "MEMBER", targetId, reason}`
    public func reportPeerMember(memberID: Int, reason: String) async -> PlayerGapReply {
        guard let req = try? makeRequest(
            "api/im/report",
            method: "POST",
            json: [
                "targetType": .string("MEMBER"),
                "targetId": .integer(Int64(memberID)),
                "reason": .string(reason)
            ]
        ) else { return .unauthorized }
        return await send(req)
    }
}
