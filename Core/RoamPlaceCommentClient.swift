import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Place reviews on the existing comment routes. Owner type 4 is the city POI.
/// `routeMarkedLive` stays false: this client does not register a new route.
/// No payment, quote, or price field is sent.
public struct RoamPlaceCommentClient {
    public static let routeMarkedLive = false
    public static let ownerType = 4
    public static let listPath = "api/comment/list"
    public static let addPath = "api/comment/add"

    public struct Row: Equatable {
        public let id: String
        public let memberID: Int?
        public let name: String?
        public let timeText: String?
        public let stars: Int?
        public let text: String
    }

    public enum PublishOutcome: Equatable {
        case published
        case rejected(String?)
        case notSent
        case unknown
        case unauthorized
    }

    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public static func acceptableRequestID(_ value: String) -> Bool {
        value.range(of: "^[A-Za-z0-9_.:-]{1,64}$", options: .regularExpression) != nil
    }

    public enum ListOutcome: Equatable {
        case loaded([Row])
        /// The list did not return a row array. The empty sentence stays hidden.
        case unavailable
        case unauthorized
    }

    public func list(poiID: Int, token: String) async -> ListOutcome {
        guard poiID > 0, AuthRequestBuilder.isValidToken(token) else { return .unavailable }
        let fields = ["owner_type": String(Self.ownerType), "owner_id": String(poiID), "pageNum": "1", "pageSize": "10"]
        guard let request = try? Self.form(configuration, Self.listPath, fields, token) else { return .unavailable }
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) }
        catch { return .unavailable }
        if status == 401 { return .unauthorized }
        guard (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = Self.integer(root["code"]) else { return .unavailable }
        if code == 401 { return .unauthorized }
        guard code == 200,
              let dataObject = root["data"] as? [String: Any],
              let rows = dataObject["rows"] as? [Any] else { return .unavailable }
        return .loaded(rows.compactMap(Self.row))
    }

    /// A transport failure after the request is built is unknown: the server may have stored it.
    /// The caller keeps `requestID` and does not mint another one for that draft.
    public func publish(poiID: Int, stars: Int, text: String, requestID: String, token: String) async -> PublishOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard poiID > 0, (1...5).contains(stars), !trimmed.isEmpty, trimmed.utf16.count <= 200,
              Self.acceptableRequestID(requestID), AuthRequestBuilder.isValidToken(token) else { return .notSent }
        let fields = [
            "owner_type": String(Self.ownerType),
            "owner_id": String(poiID),
            "rating": String(stars),
            "contents": trimmed,
            "reply_id": "0",
            "requestId": requestID
        ]
        guard let request = try? Self.form(configuration, Self.addPath, fields, token) else { return .notSent }
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) }
        catch { return .unknown }
        if status == 401 { return .unauthorized }
        guard (200..<300).contains(status),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let code = Self.integer(root["code"]) else { return .unknown }
        if code == 401 { return .unauthorized }
        if code == 200 { return .published }
        let message = (root["msg"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .rejected(message?.isEmpty == false ? message : nil)
    }

    private static func form(_ configuration: APIConfiguration, _ path: String, _ fields: [String: String], _ token: String) throws -> URLRequest {
        try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(path), fields: fields, token: token)
    }

    private static func row(_ value: Any) -> Row? {
        guard let object = value as? [String: Any] else { return nil }
        let id = integer(object["id"]).map(String.init) ?? (object["id"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let id, !id.isEmpty else { return nil }
        let text = ((object["contents"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return nil }
        let stars = integer(object["rating"]).flatMap { (1...5).contains($0) ? $0 : nil }
        let name = (object["memberNickname"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let rawTime = (object["createTime"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let time = rawTime.isEmpty ? nil : String(rawTime.prefix(10))
        return Row(id: id, memberID: integer(object["memberId"]), name: name?.isEmpty == false ? name : nil, timeText: time, stars: stars, text: text)
    }

    private static func integer(_ value: Any?) -> Int? {
        if let number = value as? Int { return number }
        if let number = value as? NSNumber, CFGetTypeID(number) != CFBooleanGetTypeID() { return number.intValue }
        if let text = value as? String { return Int(text) }
        return nil
    }
}
