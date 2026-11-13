import Foundation
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// One club or merchant-club call the handover names. Settlement export and a merchant
/// cooperation write stay withheld unless the caller passes the matching switch.
public struct ClubGapCall: Equatable, Sendable {
    public enum Kind: Equatable, Sendable { case catalog, merchantCooperationWrite }
    public let path: String
    public let method: String
    public let fields: [String: ClubGapField]
    public let kind: Kind

    public init(path: String, method: String, fields: [String: ClubGapField], kind: Kind = .catalog) {
        self.path = path
        self.method = method
        self.fields = fields
        self.kind = kind
    }
}

public enum ClubGapField: Equatable, Sendable {
    case text(String)
    case number(Int)
    case flag(Bool)
    case null
}

/// A response the transport actually returned, or a withheld call that was not sent.
public struct ClubGapReply: Equatable, Sendable {
    public let sent: Bool
    public let succeeded: Bool
    public let httpStatus: Int?
    public let code: Int?
    public let errorCode: String?
    public let message: String

    public static let unknown = "\u{2014}"
    public static let withheld = ClubGapReply(sent: false, succeeded: false, httpStatus: nil, code: nil, errorCode: nil, message: unknown)
}

public enum ClubGapPaths {
    public static let evidence = "api/club-compensation/quality/evidence"
    public static let activityCancel = "api/club/activity/cancel"
    public static let activityDetail = "api/club/activity/detail"
    public static let activityJoin = "api/club/activity/join"
    public static let channels = "api/club/channels"
    public static let events = "api/club/events"
    public static let checkin = "api/club/events/Checkin"
    public static let proxyEnroll = "api/club/events/proxy-enroll"
    public static let eventsSave = "api/club/events/save"
    public static let groupCode = "api/club/group-code"
    public static let groupCodeSave = "api/club/group-code/save"
    public static let apply = "api/club/join-requests/apply"
    public static let lead = "api/club/lead"
    public static let notices = "api/club/notices"
    public static let noticesSend = "api/club/notices/send"
    public static let post = "api/club/post"
    public static let postOperation = "api/club/post/operation"
    public static let postComment = "api/club/post/operation/comment"
    public static let roles = "api/club/roles"
    public static let settlementsExport = "api/club/settlements/export"
    public static let workbench = "api/club/workbench"
    public static let coop = "api/coop"
    public static let merchantCooperationWrite = "api/coop/invite"

    public static let catalog: [String] = [
        evidence, activityCancel, activityDetail, activityJoin, channels, events, checkin, proxyEnroll,
        eventsSave, groupCode, groupCodeSave, apply, lead, notices, noticesSend, post, postOperation,
        postComment, roles, settlementsExport, workbench, coop
    ]
}

public struct ClubGapClient {
    public let baseURL: URL
    private let transport: any HTTPTransport

    public init(baseURL: URL, transport: any HTTPTransport) {
        self.baseURL = baseURL
        self.transport = transport
    }

    public func perform(_ call: ClubGapCall, token: String?, allowsPayout: Bool, allowsMerchantWrite: Bool) async -> ClubGapReply {
        if call.path == ClubGapPaths.settlementsExport, !allowsPayout { return .withheld }
        if call.kind == .merchantCooperationWrite, !allowsMerchantWrite { return .withheld }
        let guestPost = call.path == ClubGapPaths.post && call.method == "POST"
        if !guestPost {
            guard let token, AuthRequestBuilder.isValidToken(token) else { return .withheld }
        }
        let request: URLRequest
        do { request = try Self.request(baseURL: baseURL, call: call, token: token) }
        catch { return .withheld }
        let data: Data
        let status: Int
        do { (data, status) = try await transport.send(request) }
        catch { return ClubGapReply(sent: true, succeeded: false, httpStatus: nil, code: nil, errorCode: nil, message: ClubGapReply.unknown) }
        return Self.reply(data: data, status: status)
    }

    static func request(baseURL: URL, call: ClubGapCall, token: String?) throws -> URLRequest {
        guard call.path == ClubGapPaths.merchantCooperationWrite || ClubGapPaths.catalog.contains(call.path),
              !call.path.contains("..") else { throw APIError.invalidRequest }
        var root = baseURL.absoluteString
        if !root.hasSuffix("/") { root += "/" }
        let query = call.method == "GET" ? queryText(call.fields) : ""
        guard let url = URL(string: root + call.path + query) else { throw APIError.invalidRequest }
        var request = URLRequest(url: url)
        request.httpMethod = call.method
        request.timeoutInterval = 20
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token {
            guard AuthRequestBuilder.isValidToken(token) else { throw APIError.invalidRequest }
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }
        if call.method != "GET" {
            guard let body = jsonData(call.fields) else { throw APIError.invalidRequest }
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }
        return request
    }

    static func reply(data: Data, status: Int) -> ClubGapReply {
        let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
        let code = integer(object?["code"])
        let errorCode = object?["errorCode"] as? String
        let message = (object?["msg"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? ClubGapReply.unknown
        let httpOK = (200..<300).contains(status)
        let succeeded = httpOK && code == 200
        return ClubGapReply(sent: true, succeeded: succeeded, httpStatus: status, code: code, errorCode: errorCode, message: message)
    }

    private static func queryText(_ fields: [String: ClubGapField]) -> String {
        guard case .number(let activity) = fields["activityId"], activity > 0 else { return "" }
        return "?activityId=\(activity)"
    }

    private static func jsonData(_ fields: [String: ClubGapField]) -> Data? {
        var parts: [String] = []
        for key in fields.keys.sorted() {
            guard let literal = fields[key]?.literal else { return nil }
            parts.append(quoted(key) + ":" + literal)
        }
        return ("{" + parts.joined(separator: ",") + "}").data(using: .utf8)
    }

    private static func integer(_ value: Any?) -> Int? {
        guard let number = value as? NSNumber else { return nil }
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return nil }
        let int = number.intValue
        guard number.doubleValue == Double(int) else { return nil }
        return int
    }

    private static func quoted(_ text: String) -> String {
        "\"" + text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"") + "\""
    }
}

extension ClubGapField {
    var literal: String? {
        switch self {
        case .text(let value):
            let escaped = value.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            return "\"\(escaped)\""
        case .number(let value): return String(value)
        case .flag(let value): return value ? "true" : "false"
        case .null: return "null"
        }
    }
}

public struct ClubGapSurface: Equatable, Sendable, Identifiable {
    public let path: String
    public let method: String
    public let titleEN: String
    public let titleZH: String
    public let fields: [String: ClubGapField]
    public var id: String { path }

    public func title(chinese: Bool) -> String { chinese ? titleZH : titleEN }

    public static let all: [ClubGapSurface] = [
        .init(path: ClubGapPaths.evidence, method: "POST", titleEN: "Quality evidence", titleZH: "质量证据", fields: ["clubId": .number(1), "topicId": .number(2), "dimension": .text("DELIVERY_SAFETY"), "evidenceHash": .text(String(repeating: "a", count: 64))]),
        .init(path: ClubGapPaths.activityCancel, method: "POST", titleEN: "Cancel waitlist", titleZH: "取消候补", fields: ["activityId": .number(2)]),
        .init(path: ClubGapPaths.activityDetail, method: "POST", titleEN: "Activity status", titleZH: "场次状态", fields: ["clubId": .number(1), "activityId": .number(2)]),
        .init(path: ClubGapPaths.activityJoin, method: "POST", titleEN: "Join waitlist", titleZH: "加入候补", fields: ["activityId": .number(2)]),
        .init(path: ClubGapPaths.channels, method: "POST", titleEN: "Club channels", titleZH: "俱乐部频道", fields: ["clubId": .number(1)]),
        .init(path: ClubGapPaths.events, method: "POST", titleEN: "Event series", titleZH: "活动系列", fields: ["clubId": .number(1)]),
        .init(path: ClubGapPaths.checkin, method: "POST", titleEN: "Correct attendance", titleZH: "更正出勤", fields: ["clubId": .number(1), "activityId": .number(2), "memberId": .number(3), "arrived": .flag(true), "expectedVersion": .number(0), "reason": .text("arrived"), "requestId": .text("req-1")]),
        .init(path: ClubGapPaths.proxyEnroll, method: "POST", titleEN: "Proxy enroll", titleZH: "代报名", fields: ["clubId": .number(1), "activityId": .number(2), "memberId": .number(3)]),
        .init(path: ClubGapPaths.eventsSave, method: "POST", titleEN: "Save series", titleZH: "保存系列", fields: ["clubId": .number(1), "topicId": .number(2), "recurrenceType": .text("ONCE"), "startDate": .text("2026-12-01"), "startTime": .text("19:00"), "occurrenceCount": .number(1), "customDates": .null, "capacity": .null, "defaultLeadMemberId": .null, "waitlistEnabled": .flag(false), "offerMinutes": .number(30), "requestId": .text("series-1")]),
        .init(path: ClubGapPaths.groupCode, method: "POST", titleEN: "Group code", titleZH: "组队码", fields: ["activityId": .number(2)]),
        .init(path: ClubGapPaths.groupCodeSave, method: "POST", titleEN: "Save group code", titleZH: "保存组队码", fields: ["activityId": .number(2)]),
        .init(path: ClubGapPaths.apply, method: "POST", titleEN: "Apply to join", titleZH: "申请加入", fields: ["id": .number(1), "joinMessage": .text("")]),
        .init(path: ClubGapPaths.lead, method: "GET", titleEN: "Lead progress", titleZH: "带队进度", fields: ["activityId": .number(2)]),
        .init(path: ClubGapPaths.notices, method: "POST", titleEN: "Notice audience", titleZH: "通知人数", fields: ["clubId": .number(1)]),
        .init(path: ClubGapPaths.noticesSend, method: "POST", titleEN: "Send notice", titleZH: "发送通知", fields: ["clubId": .number(1), "audienceType": .text("ALL_MEMBERS"), "title": .text("Meet"), "content": .text("Tonight"), "requestId": .text("notice-1")]),
        .init(path: ClubGapPaths.post, method: "POST", titleEN: "Club posts", titleZH: "俱乐部帖子", fields: ["clubId": .number(1), "limit": .number(20)]),
        .init(path: ClubGapPaths.postOperation, method: "POST", titleEN: "Post receipt", titleZH: "帖子回执", fields: ["operationKind": .text("receipt")]),
        .init(path: ClubGapPaths.postComment, method: "POST", titleEN: "Comment receipt", titleZH: "评论回执", fields: ["operationKind": .text("receipt")]),
        .init(path: ClubGapPaths.roles, method: "POST", titleEN: "Club roles", titleZH: "俱乐部角色", fields: ["clubId": .number(1)]),
        .init(path: ClubGapPaths.settlementsExport, method: "POST", titleEN: "Settlement summary", titleZH: "结算摘要", fields: ["clubId": .number(1)]),
        .init(path: ClubGapPaths.workbench, method: "POST", titleEN: "Club workbench", titleZH: "俱乐部工作台", fields: ["clubId": .number(1)]),
        .init(path: ClubGapPaths.coop, method: "POST", titleEN: "Cooperation list", titleZH: "合作列表", fields: [:])
    ]

    public func call() -> ClubGapCall {
        ClubGapCall(path: path, method: method, fields: fields)
    }

    public static func merchantInvite(topicID: Int, recipientID: Int) -> ClubGapCall {
        ClubGapCall(path: ClubGapPaths.merchantCooperationWrite, method: "POST", fields: [
            "inviteType": .number(2), "toType": .text("MERCHANT"), "toId": .number(recipientID),
            "topicId": .number(topicID), "shareMode": .number(0), "message": .text("邀请贵店承接本主题合作")
        ], kind: .merchantCooperationWrite)
    }
}
