import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Capability gaps G4/G5 (capability-graph section 1): community trust, roam extras, template
/// adoption, map/search. One envelope client for the player routes the mini-program calls and the
/// app did not. Every caller ports one mini-program page; the shapes are that page's, not new ones.
public enum PlayerCapabilityFailure: Error, Equatable {
    case signedOut
    case invalid
    case malformed
    /// Business refusal. `message` is the server `msg`, shown verbatim like the mini-program does.
    case rejected(code: Int, message: String?)
    /// A write may have reached the server. Callers read back or retry with the same key, never a new one.
    case outcomeUnknown
}

public struct PlayerCapabilityClient {
    public let baseURL: URL
    let token: String
    let transport: any HTTPTransport
    private static let responseCap = 1_048_576

    public init(context: RuntimeDependencyContext, transport: any HTTPTransport) {
        self.init(baseURL: context.baseURL, token: context.session.token, transport: transport)
    }

    init(baseURL: URL, token: String, transport: any HTTPTransport) {
        self.baseURL = baseURL; self.token = token; self.transport = transport
    }

    // MARK: Requests

    func getRequest(_ path: String, query: [(String, String)] = []) throws -> URLRequest {
        guard AuthRequestBuilder.isValidToken(token) else { throw PlayerCapabilityFailure.signedOut }
        guard var parts = URLComponents(url: baseURL.appendingPathComponent(path), resolvingAgainstBaseURL: false) else {
            throw PlayerCapabilityFailure.invalid
        }
        if !query.isEmpty { parts.queryItems = query.map { URLQueryItem(name: $0.0, value: $0.1) } }
        guard let url = parts.url else { throw PlayerCapabilityFailure.invalid }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    /// `app.sendRequest` with `JSON.stringify(data)` and `Content-Type: application/json`.
    func jsonRequest(_ path: String, body: [String: SquareGovernanceJSON]) throws -> URLRequest {
        var request = try getRequest(path)
        request.httpMethod = "POST"
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        request.httpBody = try encoder.encode(body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        return request
    }

    /// `app.sendRequest` POST without a header: the request client sends `application/x-www-form-urlencoded`.
    func formRequest(_ path: String, fields: [(String, String)]) throws -> URLRequest {
        var request = try getRequest(path)
        request.httpMethod = "POST"
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        let encoded = fields.map { key, value -> String in
            let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
            let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? ""
            return k + "=" + v
        }.joined(separator: "&")
        request.httpBody = Data(encoded.utf8)
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        return request
    }

    // MARK: Sending

    func read(_ request: URLRequest) async throws -> SquareGovernanceJSON {
        try Task.checkCancellation()
        let (data, status) = try await transport.send(request)
        try Task.checkCancellation()
        return try Self.decode(data, status: status, write: false)
    }

    func write(_ request: URLRequest) async throws -> SquareGovernanceJSON {
        try Task.checkCancellation()
        let data: Data, status: Int
        do { (data, status) = try await transport.send(request) }
        catch { throw PlayerCapabilityFailure.outcomeUnknown }
        return try Self.decode(data, status: status, write: true)
    }

    /// Envelope `{code, msg, data}`. `code` may be a number or the string "200" (the mini-program accepts both).
    static func decode(_ data: Data, status: Int, write: Bool) throws -> SquareGovernanceJSON {
        if status == 401 { throw PlayerCapabilityFailure.signedOut }
        guard data.count <= responseCap,
              let body = try? JSONDecoder().decode(SquareGovernanceJSON.self, from: data) else {
            if write, status >= 500 || (200..<300).contains(status) { throw PlayerCapabilityFailure.outcomeUnknown }
            throw (200..<300).contains(status) ? PlayerCapabilityFailure.malformed : PlayerCapabilityFailure.rejected(code: status, message: nil)
        }
        let code = body["code"].int ?? body["code"].string.flatMap { Int($0) }
        if code == 401 { throw PlayerCapabilityFailure.signedOut }
        guard (200..<300).contains(status) else {
            if write, status >= 500 || status == 408 { throw PlayerCapabilityFailure.outcomeUnknown }
            throw PlayerCapabilityFailure.rejected(code: code ?? status, message: body["msg"].string)
        }
        guard let code else { throw write ? PlayerCapabilityFailure.outcomeUnknown : PlayerCapabilityFailure.malformed }
        guard code == 200 else { throw PlayerCapabilityFailure.rejected(code: code, message: body["msg"].string) }
        return body["data"]
    }

    // MARK: Shared field readers (mini-program `positiveId` / `exactId`)

    static func positiveID(_ value: SquareGovernanceJSON) -> Int? {
        if let number = value.int, number > 0 { return number }
        if let text = value.string, text.first != "0", text.count <= 18, text.allSatisfy({ $0.isASCII && $0.isNumber }),
           let number = Int(text), number > 0 { return number }
        return nil
    }

    static func number(_ value: SquareGovernanceJSON) -> Double? {
        switch value {
        case .integer(let v): return Double(v)
        case .decimal(let v): return v
        case .string(let v): return Double(v.trimmingCharacters(in: .whitespaces))
        default: return nil
        }
    }

    static func text(_ value: SquareGovernanceJSON) -> String {
        (value.string ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `'<prefix>' + Date.now().toString(36) + '-' + random(36)` style keys, kept within `limit` characters.
    public static func requestKey(_ prefix: String, limit: Int = 96, now: Date = Date()) -> String {
        let time = String(Int64(now.timeIntervalSince1970 * 1000), radix: 36)
        let random = String(UInt64.random(in: 0...UInt64(UInt32.max)) | 1 << 40, radix: 36)
        return String((prefix + time + "-" + random).prefix(limit))
    }
}
