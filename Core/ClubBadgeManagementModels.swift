import Foundation
import CryptoKit
import CoreFoundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum ClubBadgeManagementFailure: Error {
    case unavailable, stale, invalid, forbidden, persistence, pending, unknown
    case server(String)
    public var message: String {
        switch self {
        case .unavailable: return "俱乐部徽章暂未开放，请稍后重试。"
        case .stale: return "账号或页面已变化，请重新读取。"
        case .invalid: return "徽章数据未能确认，请刷新。"
        case .forbidden: return "当前身份不能管理本俱乐部徽章。"
        case .persistence: return "未能安全保存操作记录，已暂停提交；请勿重复创建或颁发。"
        case .pending: return "还有结果未确认的操作，请先读取原操作结果。"
        case .unknown: return "结果尚未确认；不会自动再次创建或颁发。"
        case .server(let text): return text
        }
    }
}

public struct ClubBadgeRecord: Decodable, Equatable, Identifiable {
    public var id: String { badgeCode }
    public let badgeCode: String
    public let badgeName: String?
    public let badgeDesc: String?
    public let iconUrl: String?
    public let clubId: Int?
    public var displayName: String {
        let name = badgeName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? "未命名徽章" : name
    }
}

public struct ClubBadgeCreateDraft: Equatable {
    public var name: String = ""
    public var description: String = ""
    public init() {}
    public var normalizedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var normalizedDescription: String { description.trimmingCharacters(in: .whitespacesAndNewlines) }
    public var validation: String? {
        if normalizedName.isEmpty { return "请填写徽章名。" }
        // Original Java writer truncates at 120 UTF-16 units; do not let a surrogate pair
        // be split even when the mini-program's scalar count would allow the input.
        if normalizedName.utf16.count > 120 { return "徽章名最多 120 个字（表情可能占两位）。" }
        if normalizedDescription.utf16.count > 255 { return "说明最多 255 个字（表情可能占两位）。" }
        return nil
    }
    public func fields(clubID: Int) throws -> [String: Any] {
        guard clubID > 0, validation == nil else { throw ClubBadgeManagementFailure.invalid }
        var fields: [String: Any] = ["clubId": clubID, "badgeName": normalizedName]
        if !normalizedDescription.isEmpty { fields["badgeDesc"] = normalizedDescription }
        return fields // No icon upload, unlock rule, asset type or threshold is authored here.
    }
}

/// Deployment acceptance is independent of owner/capability. No production grant is fabricated.
public struct ClubBadgeManagementApproval: Equatable {
    public let revision = UUID()
    public let endpoints: OperationEndpointApproval
    public let clubIDs: Set<Int>
    public let reviewedPolicyVersion: String
    public let reads: Bool, writes: Bool
    /// MP-first (CLB-r10-badges-01): every club; the server checks the badge role per club.
    public let anyClub: Bool
    public init(endpoints: OperationEndpointApproval, clubIDs: Set<Int>, reviewedPolicyVersion: String,
                reads: Bool = false, writes: Bool = false) throws {
        guard !clubIDs.isEmpty, clubIDs.allSatisfy({ $0 > 0 }), !reviewedPolicyVersion.isEmpty,
              !writes || reads else { throw APIError.invalidConfiguration }
        self.endpoints = endpoints; self.clubIDs = clubIDs; self.reviewedPolicyVersion = reviewedPolicyVersion
        self.reads = reads; self.writes = writes; self.anyClub = false
    }
    /// MP pages/club/badges/index.js reads, creates and grants for whichever club the page opens.
    /// Non-money. China only; the endpoints must cover every badge path.
    public init(mpFirstEndpoints endpoints: OperationEndpointApproval) throws {
        guard ClubBadgeManagementRoute.paths.isSubset(of: endpoints.paths) else { throw APIError.invalidConfiguration }
        self.endpoints = endpoints; self.clubIDs = []; self.reviewedPolicyVersion = "r10-club-badges-mp-first"
        self.reads = true; self.writes = true; self.anyClub = true
    }
    public func permits(_ context: RuntimeDependencyContext, clubID: Int, writing: Bool) -> Bool {
        let paths = writing ? ClubBadgeManagementRoute.paths : ClubBadgeManagementRoute.readPaths
        return context.market == .china && reads && (!writing || writes) && clubID > 0 && (anyClub || clubIDs.contains(clubID))
            && context.baseURL == endpoints.baseURL && context.session.accountID == endpoints.accountID
            && context.session.namespace == endpoints.namespace && paths.isSubset(of: endpoints.paths)
    }
    public func sameReadAuthority(as other: Self) -> Bool {
        revision == other.revision && endpoints == other.endpoints && clubIDs == other.clubIDs && reviewedPolicyVersion == other.reviewedPolicyVersion && reads == other.reads && anyClub == other.anyClub
    }
}

/// Optional first-party envelope around the ORIGINAL writer. Without its deployed producer,
/// the legacy create API has NO UUID receipt contract. A local UUID alone never proves success.
public struct ClubBadgeManagementRoute {
    public static let detailPath = "api/club/detail", membersPath = "api/club/members"
    public static let listPath = "api/club/badge/list", createPath = "api/club/badge/create", grantPath = "api/club/badge/grant"
    public static let receiptPath = "api/club/badge/original-receipt"
    public static let requestHeader = "X-Club-Badge-Request-Id", sourceHeader = "X-Club-Badge-Source-SHA256"
    public static let readPaths: Set<String> = [detailPath, membersPath, listPath, receiptPath]
    public static let paths = readPaths.union([createPath, grantPath])
    public let path: String, clubID: Int
    public var writing: Bool { path == Self.createPath || path == Self.grantPath }
    public init?(request: URLRequest, baseURL: URL) {
        guard request.httpMethod == "POST", request.httpBodyStream == nil,
              request.value(forHTTPHeaderField: "Content-Type") == "application/json",
              let path = Self.paths.first(where: { baseURL.appendingPathComponent($0) == request.url }),
              let data = request.httpBody, data.count < 16_384, let text = String(data: data, encoding: .utf8),
              (try? ContentDraftJSON.parse(text)) != nil,
              let fields = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let club = Self.positive(fields[(path == Self.detailPath || path == Self.listPath) ? "id" : "clubId"]) else { return nil }
        let requestID = request.value(forHTTPHeaderField: Self.requestHeader), source = request.value(forHTTPHeaderField: Self.sourceHeader)
        if path == Self.createPath || path == Self.grantPath {
            guard let requestID, Self.requestID(requestID), let source, Self.hash(source),
                  (try? Self.sourceHash(operation: path == Self.createPath ? "CREATE" : "GRANT", fields: fields)) == source else { return nil }
        } else {
            guard requestID == nil, source == nil else { return nil }
            if path == Self.receiptPath {
                guard Set(fields.keys) == ["clubId", "requestId", "operation", "sourceSHA256"],
                      let id = fields["requestId"] as? String, Self.requestID(id),
                      let op = fields["operation"] as? String, ["CREATE", "GRANT"].contains(op),
                      let hash = fields["sourceSHA256"] as? String, Self.hash(hash) else { return nil }
            } else {
                guard Set(fields.keys) == [(path == Self.detailPath || path == Self.listPath) ? "id" : "clubId"] else { return nil }
            }
        }
        self.path = path; clubID = club
    }
    public static func sourceHash(operation: String, fields: [String: Any]) throws -> String {
        guard let club = positive(fields["clubId"]) else { throw ClubBadgeManagementFailure.invalid }
        var pieces = ["CLUB_BADGE_V1", operation, String(club)]
        if operation == "CREATE" {
            let keys: Set<String> = fields["badgeDesc"] == nil ? ["clubId", "badgeName"] : ["clubId", "badgeName", "badgeDesc"]
            guard Set(fields.keys) == keys, let name = fields["badgeName"] as? String,
                  !name.isEmpty, name.utf16.count <= 120, name == name.trimmingCharacters(in: .whitespacesAndNewlines),
                  fields["badgeDesc"] == nil || fields["badgeDesc"] is String else { throw ClubBadgeManagementFailure.invalid }
            let desc = fields["badgeDesc"] as? String ?? ""
            guard desc.utf16.count <= 255, desc == desc.trimmingCharacters(in: .whitespacesAndNewlines) else { throw ClubBadgeManagementFailure.invalid }
            pieces += [digest(name), digest(desc)]
        } else if operation == "GRANT" {
            guard Set(fields.keys) == ["clubId", "memberId", "badgeCode"], let member = positive(fields["memberId"]),
                  let code = fields["badgeCode"] as? String, validCode(code) else { throw ClubBadgeManagementFailure.invalid }
            pieces += [String(member), digest(code)]
        } else { throw ClubBadgeManagementFailure.invalid }
        return digest(pieces.joined(separator: "\u{001f}"))
    }
    public static func digest(_ value: String) -> String { SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined() }
    public static func requestID(_ value: String) -> Bool { UUID(uuidString: value)?.uuidString.lowercased() == value }
    public static func hash(_ value: String) -> Bool { value.utf8.count == 64 && value.utf8.allSatisfy { (48...57).contains($0) || (97...102).contains($0) } }
    public static func validCode(_ value: String) -> Bool { !value.isEmpty && value.utf8.count <= 255 && value == value.trimmingCharacters(in: .whitespacesAndNewlines) && !value.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) }
    static func positive(_ value: Any?) -> Int? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(), let result = Int(n.stringValue), result > 0 else { return nil }; return result
    }
}

/// A server literal, including 0, stays a decimal string. Nil and UNKNOWN stay an em dash, never a guessed 0.
public enum ClubBadgeCountText {
    public static let unknown = "—"
    public static func literal(_ value: Int?) -> String {
        guard let value, value >= 0 else { return unknown }
        return String(value)
    }
    public static func literal(_ value: Int64?) -> String {
        guard let value, value >= 0 else { return unknown }
        return String(value)
    }
}

/// Accessibility identifiers for pages/club/badges/index. The host already uses `entry`.
/// The remaining identifiers are the page contract; the view file is not changed here.
public enum ClubBadgePageAccessibility {
    public static let entry = "club.badges.entry"
    public static let loading = "club.badges.loading"
    public static let empty = "club.badges.empty"
    public static let error = "club.badges.error"
    public static let unknown = "club.badges.unknown"
    public static let ready = "club.badges.ready"
    public static let notAvailable = "club.badges.notAvailable"
    public static let retry = "club.badges.retry"
    public static let refresh = "club.badges.refresh"
    public static let create = "club.badges.create"
    public static let grant = "club.badges.grant"
    public static let ownerOnly = "club.badges.ownerOnly"
    public static let membersLoading = "club.badges.members.loading"
    public static let membersEmpty = "club.badges.members.empty"
    public static let membersError = "club.badges.members.error"
    public static let catalog: [String: String] = [
        "entry": entry, "loading": loading, "empty": empty, "error": error, "unknown": unknown,
        "ready": ready, "notAvailable": notAvailable, "retry": retry, "refresh": refresh,
        "create": create, "grant": grant, "ownerOnly": ownerOnly,
        "membersLoading": membersLoading, "membersEmpty": membersEmpty, "membersError": membersError
    ]
}

public struct ClubBadgeOriginalReceipt: Codable, Equatable, Identifiable {
    public var id: String { requestId }
    public let protocolVersion: Int, clubId: Int, actorMemberId: Int
    public let requestId: String, operation: String, sourceSHA256: String, state: String
    public let badgeId: Int?, badgeCode: String?, memberId: Int?, appliedAt: Int64?, auditId: Int?
    public var isTerminal: Bool { ["CREATED", "GRANTED", "ALREADY_GRANTED"].contains(state) }
    /// UNKNOWN stays an em dash even when a zero was stored beside it. A confirmed literal, including 0, stays a number.
    public var badgeIDText: String { Self.countText(state: state, value: badgeId) }
    public var memberIDText: String { Self.countText(state: state, value: memberId) }
    public var auditIDText: String { Self.countText(state: state, value: auditId) }
    public var appliedAtText: String { Self.countText(state: state, value: appliedAt) }
    private static func countText(state: String, value: Int?) -> String {
        state == "UNKNOWN" ? ClubBadgeCountText.unknown : ClubBadgeCountText.literal(value)
    }
    private static func countText(state: String, value: Int64?) -> String {
        state == "UNKNOWN" ? ClubBadgeCountText.unknown : ClubBadgeCountText.literal(value)
    }
    public var message: String {
        switch state {
        case "CREATED": return "徽章已创建。"
        case "GRANTED": return "这枚徽章已经记在对方名下。"
        case "ALREADY_GRANTED": return "对方之前已经拿到这枚徽章，这次没有重复颁发。"
        default: return "原操作结果尚未确认；不会自动重复提交。"
        }
    }
    func validate(_ entry: ClubBadgeManagementEntry) throws {
        guard protocolVersion == 1, clubId == entry.clubID, actorMemberId == entry.accountID,
              requestId == entry.requestID, operation == entry.operation, sourceSHA256 == entry.sourceSHA256 else { throw ClubBadgeManagementFailure.invalid }
        if state == "UNKNOWN" {
            guard badgeId == nil, badgeCode == nil, memberId == nil, appliedAt == nil, auditId == nil else { throw ClubBadgeManagementFailure.invalid }
        } else {
            guard isTerminal, let code = badgeCode, ClubBadgeManagementRoute.validCode(code),
                  (badgeId ?? 0) > 0, (appliedAt ?? 0) > 0, (auditId ?? 0) > 0 else { throw ClubBadgeManagementFailure.invalid }
            if operation == "CREATE" {
                guard state == "CREATED", memberId == nil else { throw ClubBadgeManagementFailure.invalid }
            } else {
                guard ["GRANTED", "ALREADY_GRANTED"].contains(state), code == entry.badgeCode,
                      memberId == entry.memberID, (memberId ?? 0) > 0 else { throw ClubBadgeManagementFailure.invalid }
            }
        }
    }
}

#if DEBUG
/// Offline bytes for pages/club/badges/index. No URL, host, token, transport, or production grant.
/// Not installed on the player-first launch screen.
public enum ClubBadgeManagementFixtureData {
    public static let clubID = 7
    public static let badgeCode = "CLUB7_FIXTURE"
    public static let requestID = "11111111-1111-4111-8111-111111111111"
    public static let sourceSHA256 = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
    public static func readyList() throws -> Data {
        try envelope(data: [[
            "badgeCode": badgeCode, "badgeName": "Fixture trail badge",
            "badgeDesc": "Synthetic club badge", "clubId": clubID
        ] as [String: Any]] as [Any])
    }
    public static func emptyList() throws -> Data { try envelope(data: [] as [Any]) }
    public static func errorEnvelope() throws -> Data {
        try JSONSerialization.data(withJSONObject: ["code": 500, "msg": "fixture read failed"], options: [.sortedKeys])
    }
    public static func unknownReceipt(actorMemberId: Int) throws -> Data {
        let value: [String: Any] = [
            "protocolVersion": 1, "clubId": clubID, "actorMemberId": actorMemberId,
            "requestId": requestID, "operation": "CREATE", "sourceSHA256": sourceSHA256,
            "state": "UNKNOWN", "badgeId": NSNull(), "badgeCode": NSNull(), "memberId": NSNull(),
            "appliedAt": NSNull(), "auditId": NSNull()
        ]
        return try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys])
    }
    public static func records(from envelope: Data) throws -> [ClubBadgeRecord] {
        guard let object = try JSONSerialization.jsonObject(with: envelope) as? [String: Any],
              let rows = object["data"] as? [Any] else { throw ClubBadgeManagementFailure.invalid }
        return try rows.map { row in
            try JSONDecoder().decode(ClubBadgeRecord.self, from: JSONSerialization.data(withJSONObject: row))
        }
    }
    private static func envelope(data: [Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["code": 200, "data": data], options: [.sortedKeys])
    }
}
#endif
