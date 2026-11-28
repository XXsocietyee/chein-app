import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Community report reason returned by `GET /api/v1/community/capabilities` (`reporting.reasons`).
public struct UGCReportReasonOption: Identifiable, Hashable, Sendable {
    public let code: String
    public let label: String
    public let priority: String?
    public let isEmergency: Bool

    public var id: String { "\(code)::\(label)" }

    public init(code: String, label: String, priority: String? = nil, isEmergency: Bool = false) {
        self.code = code
        self.label = label
        self.priority = priority
        self.isEmergency = isEmergency
    }

    /// Fallback copy used only if `/api/v1/community/capabilities` cannot be reached offline.
    public static let fallbackPolicyVersion = "COMMUNITY_REPORT_POLICY_V1"
    public static let fallbackTaxonomy: [UGCReportReasonOption] = [
        UGCReportReasonOption(code: "DANGEROUS", label: "现实人身危险或违法行为", priority: "URGENT", isEmergency: true),
        UGCReportReasonOption(code: "MINOR_SAFETY", label: "未成年人安全", priority: "URGENT", isEmergency: true),
        UGCReportReasonOption(code: "SELF_HARM", label: "自伤或自杀风险", priority: "URGENT", isEmergency: true),
        UGCReportReasonOption(code: "SEXUAL_CONTENT", label: "色情低俗内容", priority: "STANDARD"),
        UGCReportReasonOption(code: "HARASSMENT", label: "人身攻击或骚扰", priority: "STANDARD"),
        UGCReportReasonOption(code: "HATE", label: "仇恨或歧视", priority: "STANDARD"),
        UGCReportReasonOption(code: "FRAUD", label: "诈骗", priority: "STANDARD"),
        UGCReportReasonOption(code: "IMPERSONATION", label: "冒充他人", priority: "STANDARD"),
        UGCReportReasonOption(code: "FALSE_INFORMATION", label: "虚假信息", priority: "STANDARD"),
        UGCReportReasonOption(code: "SPAM", label: "垃圾广告或站外导流", priority: "STANDARD"),
        UGCReportReasonOption(code: "PRIVACY", label: "隐私泄露", priority: "STANDARD"),
        UGCReportReasonOption(code: "INTELLECTUAL_PROPERTY", label: "知识产权或内容盗用", priority: "STANDARD"),
        UGCReportReasonOption(code: "OTHER", label: "其他", priority: "STANDARD")
    ]
}

public enum UGCCommunityTargetType: String, Hashable, Sendable {
    case member = "MEMBER"
    case merchant = "MERCHANT"
    case club = "CLUB"
    case activity = "ACTIVITY"
    case content = "CONTENT"
    case comment = "COMMENT"
    case safetyRating = "SAFETY_RATING"
}

/// Canonical UGC surface target mapping every user-generated content surface to its live backend report route.
public enum UGCSafetyReportTarget: Hashable, Sendable {
    case topic(id: Int)
    case template(id: Int, personal: Bool = false)
    case creativeSquarePost(id: Int)
    case comment(id: Int)
    case clubPost(clubID: Int, postID: Int)
    case clubPostComment(commentID: Int)
    case community(targetType: UGCCommunityTargetType, targetID: Int)
    case member(memberID: Int)
    case activity(activityID: Int)
    case team(teamID: Int)
    case mod(modID: Int)

    public var routePath: String {
        switch self {
        case .topic:
            return ContentReportReasonRules.topicWritePath
        case .template(_, let personal):
            return personal ? ContentReportReasonRules.personalTemplateWritePath : ContentReportReasonRules.templateWritePath
        case .creativeSquarePost:
            return "api/creativesquare/report"
        case .comment:
            return "api/comment/report"
        case .clubPost:
            return "api/club/post/report"
        case .clubPostComment:
            return "api/club/post/comment/report"
        case .community(let type, _):
            // CONTENT and COMMENT are posts the v1 report route accepts. MEMBER, ACTIVITY, CLUB, MERCHANT and
            // SAFETY_RATING fall through that route to a post lookup and come back 404 (P1-7). The trust submit
            // route already accepts those target types (CommunityTrustServiceImpl.REPORT_TARGETS).
            switch type {
            case .content, .comment: return "api/v1/community/reports"
            case .member, .merchant, .club, .activity, .safetyRating: return "api/community-trust/reports/submit"
            }
        case .member, .activity:
            return "api/community-trust/reports/submit"
        case .team:
            return "api/team/report"
        case .mod:
            return "api/mod-owned-report"
        }
    }
}

public struct UGCContentSafetyCapabilities: Equatable, Sendable {
    public let policyVersion: String
    public let reasons: [UGCReportReasonOption]

    public init(policyVersion: String, reasons: [UGCReportReasonOption]) {
        self.policyVersion = policyVersion
        self.reasons = reasons
    }
}

public struct UGCPrecheckResult: Equatable, Sendable {
    public let allowed: Bool
    public let message: String?

    public init(allowed: Bool, message: String?) {
        self.allowed = allowed
        self.message = message
    }
}

public enum UGCContentSafetyError: Error, Equatable, Sendable {
    case signedOut
    case invalidTarget
    case invalidResponse
    case serverRejected(String?)
}

public protocol UGCContentSafetyServing: Sendable {
    func fetchCapabilities(token: String) async throws -> UGCContentSafetyCapabilities
    func submitReport(
        target: UGCSafetyReportTarget,
        reason: UGCReportReasonOption,
        details: String,
        policyVersion: String,
        token: String
    ) async throws -> String?
    func blockUser(targetMemberID: Int, token: String) async throws
    func unblockUser(targetMemberID: Int, token: String) async throws
    func fetchBlockedMemberIDs(cursor: Int64, token: String) async throws -> [Int]
    func precheckContent(text: String, scene: String, token: String) async throws -> UGCPrecheckResult
}

/// Shared UGC 1.2 service implementing mini-program taxonomy discovery (`/api/v1/community/capabilities`),
/// surface reporting, user blocking/unblocking (`/api/im/block`, `/api/im/unblock`, `/api/native/blacklist/list`),
/// and AI safety moderation prechecks (`/api/ai/safety/precheck`).
public struct UGCContentSafetyHTTPService: UGCContentSafetyServing, @unchecked Sendable {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    public func fetchCapabilities(token: String) async throws -> UGCContentSafetyCapabilities {
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(ContentReportReasonRules.policyPath),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = nil // `[]` leaves a bare "?" (empty query) on this Foundation
        guard let url = components?.url else { throw UGCContentSafetyError.invalidTarget }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if AuthRequestBuilder.isValidToken(token) {
            request.setValue(token, forHTTPHeaderField: "Authorization")
        }

        let (data, status) = try await transport.send(request)
        guard (200..<300).contains(status),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UGCContentSafetyError.invalidResponse
        }
        let bodyCode = json["code"] as? Int
        guard bodyCode == nil || bodyCode == 200 else {
            throw UGCContentSafetyError.serverRejected(json["msg"] as? String)
        }
        let dataObject = (json["data"] as? [String: Any]) ?? json
        let reporting = (dataObject["reporting"] as? [String: Any]) ?? [:]
        let policyVersion = (reporting["policyVersion"] as? String) ?? UGCReportReasonOption.fallbackPolicyVersion
        let rawReasons = (reporting["reasons"] as? [[String: Any]]) ?? []
        let labels = ContentReportReasonRules.labels(code: 200, reasons: rawReasons)
        var parsed: [UGCReportReasonOption] = []
        for row in rawReasons {
            guard let rawLabel = row["label"] as? String else { continue }
            let trimmedLabel = rawLabel.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedLabel.isEmpty, labels.contains(trimmedLabel) else { continue }
            let code = (row["code"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let priority = row["priority"] as? String
            let isEmergency = (row["emergency"] as? Bool) ?? (priority == "URGENT")
            parsed.append(
                UGCReportReasonOption(
                    code: (code?.isEmpty == false ? code : nil) ?? trimmedLabel,
                    label: trimmedLabel,
                    priority: priority,
                    isEmergency: isEmergency
                )
            )
        }
        return UGCContentSafetyCapabilities(
            policyVersion: policyVersion,
            reasons: parsed.isEmpty ? UGCReportReasonOption.fallbackTaxonomy : parsed
        )
    }

    public func submitReport(
        target: UGCSafetyReportTarget,
        reason: UGCReportReasonOption,
        details: String,
        policyVersion: String,
        token: String
    ) async throws -> String? {
        guard AuthRequestBuilder.isValidToken(token) else { throw UGCContentSafetyError.signedOut }
        let trimmedReason = reason.label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedReason.isEmpty else { throw UGCContentSafetyError.invalidTarget }
        let trimmedDetails = details.trimmingCharacters(in: .whitespacesAndNewlines)
        let reasonText = trimmedDetails.isEmpty ? trimmedReason : "\(trimmedReason) - \(trimmedDetails)"

        let request: URLRequest
        switch target {
        case .community(let targetType, let targetID):
            guard targetID > 0 else { throw UGCContentSafetyError.invalidTarget }
            request = try makeCommunityReportRequest(
                targetType: targetType.rawValue,
                targetID: targetID,
                reason: reason,
                details: reasonText,
                policyVersion: policyVersion,
                token: token
            )
        case .member(let memberID):
            guard memberID > 0 else { throw UGCContentSafetyError.invalidTarget }
            request = try makeCommunityReportRequest(
                targetType: UGCCommunityTargetType.member.rawValue,
                targetID: memberID,
                reason: reason,
                details: reasonText,
                policyVersion: policyVersion,
                token: token
            )
        case .activity(let activityID):
            guard activityID > 0 else { throw UGCContentSafetyError.invalidTarget }
            request = try makeCommunityReportRequest(
                targetType: UGCCommunityTargetType.activity.rawValue,
                targetID: activityID,
                reason: reason,
                details: reasonText,
                policyVersion: policyVersion,
                token: token
            )
        case .topic(let id), .template(let id, _), .creativeSquarePost(let id), .comment(let id), .clubPostComment(let id):
            guard id > 0 else { throw UGCContentSafetyError.invalidTarget }
            let url = configuration.baseURL.appendingPathComponent(target.routePath)
            let fields = ContentReportReasonRules.fields(id: String(id), reason: trimmedReason)
            request = try AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: token)
        case .clubPost(let clubID, let postID):
            guard postID > 0 else { throw UGCContentSafetyError.invalidTarget }
            let url = configuration.baseURL.appendingPathComponent(target.routePath)
            var fields = ContentReportReasonRules.fields(id: String(postID), reason: trimmedReason)
            if clubID > 0 { fields["club_id"] = String(clubID) }
            request = try AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: token)
        case .team(let teamID):
            guard teamID > 0 else { throw UGCContentSafetyError.invalidTarget }
            let url = configuration.baseURL.appendingPathComponent(target.routePath)
            let fields = ContentReportReasonRules.fields(id: String(teamID), reason: trimmedReason)
            request = try AuthRequestBuilder.makeFormRequest(url: url, fields: fields, token: token)
        case .mod(let modID):
            guard modID > 0 else { throw UGCContentSafetyError.invalidTarget }
            request = try makeJSONRequest(
                path: target.routePath,
                payload: ["mod_id": modID, "id": modID, "reason": reasonText],
                token: token
            )
        }

        let (data, status) = try await transport.send(request)
        let decoded = decodeEnvelope(data)
        let accepted = (200..<300).contains(status) && (decoded.code == nil || decoded.code == 200)
        guard accepted else {
            // A 404 (post lookup, or HTTP 404) keeps the server's whole message, not a collapsed unknown.
            if status == 404 || decoded.code == 404 {
                let full = decoded.message ?? String(data: data, encoding: .utf8)
                throw UGCContentSafetyError.serverRejected(full?.isEmpty == false ? full : nil)
            }
            throw UGCContentSafetyError.serverRejected(decoded.message)
        }
        return decoded.message
    }

    public func blockUser(targetMemberID: Int, token: String) async throws {
        try await sendMemberBlockMutation(path: "api/im/block", targetMemberID: targetMemberID, token: token)
    }

    public func unblockUser(targetMemberID: Int, token: String) async throws {
        try await sendMemberBlockMutation(path: "api/im/unblock", targetMemberID: targetMemberID, token: token)
    }

    public func fetchBlockedMemberIDs(cursor: Int64 = 0, token: String) async throws -> [Int] {
        guard AuthRequestBuilder.isValidToken(token) else { throw UGCContentSafetyError.signedOut }
        var components = URLComponents(
            url: configuration.baseURL.appendingPathComponent(NativeBlacklistApproval.listPath),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [URLQueryItem(name: "cursor", value: String(cursor))]
        guard let url = components?.url else { throw UGCContentSafetyError.invalidTarget }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, status) = try await transport.send(request)
        guard (200..<300).contains(status),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw UGCContentSafetyError.invalidResponse
        }
        let bodyCode = json["code"] as? Int
        guard bodyCode == nil || bodyCode == 200 else {
            throw UGCContentSafetyError.serverRejected(json["msg"] as? String)
        }
        return Self.extractMemberIDs(from: json)
    }

    /// fix/1128c-ai-showcase (planning audit H-08b): the body is the backend `AiSafetyPrecheckReq`
    /// `{title, subtitle, description, nodes}` with the text as the description. `scene` stays a caller label only; the
    /// backend DTO has no such field, so it is no longer sent.
    public func precheckContent(text: String, scene: String, token: String) async throws -> UGCPrecheckResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return UGCPrecheckResult(allowed: true, message: nil) }
        guard AuthRequestBuilder.isValidToken(token) else { throw UGCContentSafetyError.signedOut }
        let request = try makeJSONRequest(
            path: "api/ai/safety/precheck",
            payload: ["title": "", "subtitle": "", "description": trimmed, "nodes": [Any]()],
            token: token
        )
        let (data, status) = try await transport.send(request)
        let decoded = decodeEnvelope(data)
        guard (200..<300).contains(status) else {
            throw UGCContentSafetyError.serverRejected(decoded.message)
        }
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let dataDict = json["data"] as? [String: Any] {
            if let passed = dataDict["allowed"] as? Bool {
                return UGCPrecheckResult(allowed: passed, message: (dataDict["reason"] as? String) ?? decoded.message)
            }
            if let passed = dataDict["pass"] as? Bool {
                return UGCPrecheckResult(allowed: passed, message: (dataDict["reason"] as? String) ?? decoded.message)
            }
        }
        return UGCPrecheckResult(allowed: decoded.code == nil || decoded.code == 200, message: decoded.message)
    }

    private func sendMemberBlockMutation(path: String, targetMemberID: Int, token: String) async throws {
        guard targetMemberID > 0 else { throw UGCContentSafetyError.invalidTarget }
        guard AuthRequestBuilder.isValidToken(token) else { throw UGCContentSafetyError.signedOut }
        let url = configuration.baseURL.appendingPathComponent(path)
        let request = try AuthRequestBuilder.makeFormRequest(
            url: url,
            fields: ["target_member_id": String(targetMemberID)],
            token: token
        )
        let (data, status) = try await transport.send(request)
        let decoded = decodeEnvelope(data)
        guard (200..<300).contains(status), (decoded.code == nil || decoded.code == 200) else {
            throw UGCContentSafetyError.serverRejected(decoded.message)
        }
    }

    private func makeCommunityReportRequest(
        targetType: String,
        targetID: Int,
        reason: UGCReportReasonOption,
        details: String,
        policyVersion: String,
        token: String
    ) throws -> URLRequest {
        let payload: [String: Any] = [
            "targetType": targetType,
            "targetId": targetID,
            "reasonCode": reason.code,
            "policyVersion": policyVersion.isEmpty ? UGCReportReasonOption.fallbackPolicyVersion : policyVersion,
            "description": String(details.prefix(500)),
            "evidenceAssetIds": [Int](),
            "requestId": UUID().uuidString.lowercased()
        ]
        return try makeJSONRequest(path: "api/v1/community/reports", payload: payload, token: token)
    }

    private func makeJSONRequest(path: String, payload: [String: Any], token: String) throws -> URLRequest {
        let url = configuration.baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.httpShouldHandleCookies = false
        request.setValue(token, forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys])
        return request
    }

    private func decodeEnvelope(_ data: Data) -> (code: Int?, message: String?) {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return (nil, nil)
        }
        let code: Int?
        if let intCode = json["code"] as? Int {
            code = intCode
        } else if let strCode = json["code"] as? String {
            code = Int(strCode)
        } else {
            code = nil
        }
        let msg = (json["msg"] as? String) ?? (json["message"] as? String)
        return (code, msg?.isEmpty == false ? msg : nil)
    }

    private static func extractMemberIDs(from json: [String: Any]) -> [Int] {
        let dataObj = json["data"] as? [String: Any] ?? json
        let list = (dataObj["items"] as? [[String: Any]])
            ?? (dataObj["records"] as? [[String: Any]])
            ?? (dataObj["rows"] as? [[String: Any]])
            ?? (dataObj["list"] as? [[String: Any]])
            ?? []
        return list.compactMap { row in
            (row["blockedMemberId"] as? Int)
                ?? (row["blocked_member_id"] as? Int)
                ?? (row["targetMemberId"] as? Int)
                ?? (row["target_member_id"] as? Int)
                ?? (row["memberId"] as? Int)
                ?? (row["member_id"] as? Int)
        }.filter { $0 > 0 }
    }
}

/// Observable per-account store tracking blocked member IDs and display names across all UGC surfaces
/// (feeds, club posts/comments/channels, IM DMs, reviews, profiles, topics/templates) and keeping local
/// storage synchronized with `/api/native/blacklist/list`, `/api/im/block`, and `/api/im/unblock`.
@MainActor
public final class UGCBlockedUsersStore: ObservableObject {
    @Published public private(set) var blockedMemberIDs: Set<Int> = []
    @Published public private(set) var blockedAuthorNames: Set<String> = []
    @Published public private(set) var lastSyncError: String?

    private let defaults: UserDefaults
    private var accountID: Int?
    private var realm: String = "default"
    private var serverSyncedAccountKey: String?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    private var scopeKey: String {
        "\(realm).\(accountID ?? 0)"
    }

    private var memberDefaultsKey: String { "questify.ugc.blocked.members.\(scopeKey)" }
    private var authorDefaultsKey: String { "questify.ugc.blocked.authors.\(scopeKey)" }

    public func configureScope(accountID: Int?, realm: String) {
        let normalizedRealm = realm.trimmingCharacters(in: .whitespacesAndNewlines)
        let effectiveRealm = normalizedRealm.isEmpty ? "default" : normalizedRealm
        guard self.accountID != accountID || self.realm != effectiveRealm else { return }
        self.accountID = accountID
        self.realm = effectiveRealm
        serverSyncedAccountKey = nil
        loadPersistedState()
    }

    public func isBlocked(memberID: Int?, authorName: String? = nil) -> Bool {
        if let memberID, memberID > 0, blockedMemberIDs.contains(memberID) {
            return true
        }
        if let normalized = Self.normalizeName(authorName), blockedAuthorNames.contains(normalized) {
            return true
        }
        return false
    }

    public func syncFromServerIfNeeded(
        accountID: Int?,
        realm: String,
        token: String?,
        service: (any UGCContentSafetyServing)?
    ) async {
        configureScope(accountID: accountID, realm: realm)
        guard let accountID, accountID > 0,
              let token, AuthRequestBuilder.isValidToken(token),
              let service else { return }
        let currentScope = scopeKey
        guard serverSyncedAccountKey != currentScope else { return }
        do {
            let ids = try await service.fetchBlockedMemberIDs(cursor: 0, token: token)
            guard scopeKey == currentScope else { return }
            serverSyncedAccountKey = currentScope
            if !ids.isEmpty {
                blockedMemberIDs.formUnion(ids)
                persistState()
            }
            lastSyncError = nil
        } catch {
            lastSyncError = error.localizedDescription
        }
    }

    public func recordLocalBlock(memberID: Int?, authorName: String? = nil) {
        var changed = false
        if let memberID, memberID > 0 {
            if blockedMemberIDs.insert(memberID).inserted { changed = true }
        }
        if let normalized = Self.normalizeName(authorName) {
            if blockedAuthorNames.insert(normalized).inserted { changed = true }
        }
        if changed { persistState() }
    }

    public func recordLocalUnblock(memberID: Int?, authorName: String? = nil) {
        var changed = false
        if let memberID, memberID > 0 {
            if blockedMemberIDs.remove(memberID) != nil { changed = true }
        }
        if let normalized = Self.normalizeName(authorName) {
            if blockedAuthorNames.remove(normalized) != nil { changed = true }
        }
        if changed { persistState() }
    }

    public func block(
        memberID: Int?,
        authorName: String? = nil,
        clubID: Int? = nil,
        channelStore: (any ChannelBlockedUsersStoring)? = nil,
        token: String?,
        service: (any UGCContentSafetyServing)?
    ) async throws {
        if let memberID, memberID > 0 {
            guard let service, let token, AuthRequestBuilder.isValidToken(token) else {
                throw UGCContentSafetyError.signedOut
            }
            try await service.blockUser(targetMemberID: memberID, token: token)
            if let clubID, clubID > 0, let viewerID = accountID, viewerID > 0 {
                channelStore?.addBlockedUser(targetMemberID: memberID, clubID: clubID, viewerMemberID: viewerID)
            }
        }
        recordLocalBlock(memberID: memberID, authorName: authorName)
    }

    public func unblock(
        memberID: Int?,
        authorName: String? = nil,
        clubID: Int? = nil,
        channelStore: (any ChannelBlockedUsersStoring)? = nil,
        token: String?,
        service: (any UGCContentSafetyServing)?
    ) async throws {
        if let memberID, memberID > 0 {
            guard let service, let token, AuthRequestBuilder.isValidToken(token) else {
                throw UGCContentSafetyError.signedOut
            }
            try await service.unblockUser(targetMemberID: memberID, token: token)
            if let clubID, clubID > 0, let viewerID = accountID, viewerID > 0 {
                channelStore?.removeBlockedUser(targetMemberID: memberID, clubID: clubID, viewerMemberID: viewerID)
            }
        }
        recordLocalUnblock(memberID: memberID, authorName: authorName)
    }

    private func loadPersistedState() {
        guard let accountID, accountID > 0 else {
            blockedMemberIDs = []
            blockedAuthorNames = []
            return
        }
        let ids = (defaults.array(forKey: memberDefaultsKey) as? [Int] ?? []).filter { $0 > 0 }
        let names = (defaults.stringArray(forKey: authorDefaultsKey) ?? []).compactMap(Self.normalizeName)
        blockedMemberIDs = Set(ids)
        blockedAuthorNames = Set(names)
    }

    private func persistState() {
        guard let accountID, accountID > 0 else { return }
        defaults.set(Array(blockedMemberIDs).sorted(), forKey: memberDefaultsKey)
        defaults.set(Array(blockedAuthorNames).sorted(), forKey: authorDefaultsKey)
    }

    public static func normalizeName(_ name: String?) -> String? {
        guard let name else { return nil }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.isEmpty ? nil : trimmed
    }
}
