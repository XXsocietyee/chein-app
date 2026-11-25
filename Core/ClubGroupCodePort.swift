import Foundation

/// club/group-code parity helpers: session picker labels, terminal-state mapping and refresh policy.
public enum ClubGroupCodePort {
    /// `M月D日 HH:mm` (mini `formatActivityStart`); empty unless both date and time parse.
    public static func formatStart(date: String?, time: String?) -> String {
        let dateSource = (date ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let timeSource = (time ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        func ints(_ pattern: String, _ text: String) -> [Int]? {
            guard let re = try? NSRegularExpression(pattern: pattern),
                  let m = re.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)) else { return nil }
            return (1..<m.numberOfRanges).compactMap { i in
                let r = m.range(at: i)
                guard r.location != NSNotFound, let rr = Range(r, in: text) else { return nil }
                return Int(text[rr])
            }
        }
        var dateText = "", timeText = ""
        if let d = ints("^(\\d{4})-(\\d{1,2})-(\\d{1,2})", dateSource), d.count >= 3, (1...12).contains(d[1]), (1...31).contains(d[2]) {
            dateText = "\(d[1])月\(d[2])日"
        }
        let timeInput = timeSource.isEmpty ? dateSource : timeSource
        if let t = ints("(\\d{1,2}):(\\d{2})", timeInput), t.count >= 2, (0...23).contains(t[0]), (0...59).contains(t[1]) {
            timeText = String(format: "%02d:%02d", t[0], t[1])
        }
        return dateText.isEmpty || timeText.isEmpty ? "" : dateText + " " + timeText
    }

    public static func sessionLabel(id: Int, name: String?, startDate: String?, startTime: String?) -> String {
        let trimmed = (name ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let base = trimmed.isEmpty ? "场次 \(id)" : trimmed
        let start = formatStart(date: startDate, time: startTime)
        return start.isEmpty ? base : base + " · " + start
    }

    /// Sessions that can issue a code: positive integer ids only, in server order.
    public static func sessionIDs(_ ids: [Int?]) -> [Int] { ids.compactMap { $0 }.filter { $0 > 0 } }

    public enum IssueOutcome: Equatable { case retryable, noPermission }

    /// Mini `isPermissionDenial`: 403 or a message mentioning 权限/无权 is a terminal state with an
    /// exit to club management instead of a retry.
    public static func classify(code: Int?, message: String?) -> IssueOutcome {
        if code == 403 { return .noPermission }
        let text = message ?? ""
        return text.contains("权限") || text.contains("无权") ? .noPermission : .retryable
    }

    public static func classify(_ failure: ClubGovernanceFailure) -> IssueOutcome {
        switch failure {
        case .forbidden: return .noPermission
        case .rejected(let code, let message): return classify(code: code, message: message)
        default: return .retryable
        }
    }

    /// The code on screen must be replaced when it has expired or when the screen returns to the
    /// foreground after the code's lifetime ended (mini `onShow` re-issue).
    public static func needsReissue(expiresAt: Date, now: Date) -> Bool { now >= expiresAt }
}

/// A headcount the server actually sent. Unknown is never stored as 0.
public enum ClubGroupCodeCount: Equatable {
    case known(Int)
    case unknown
    public static let unknownDisplay = "—"
    /// The server literal, including 0. Unknown is nil.
    public var literal: Int? {
        if case .known(let number) = self { return number }
        return nil
    }
    /// Unknown, null, a numeric string, and a non-integer are an em dash, never 0.
    public var displayText: String {
        switch self {
        case .known(let number): return String(number)
        case .unknown: return Self.unknownDisplay
        }
    }
    public static func parse(_ value: ClubGovernanceValue) -> Self {
        if case .integer(let number) = value, number >= 0 { return .known(number) }
        return .unknown
    }
}

/// Check-in grant for pages/club/group-code/index. A missing grant stays hidden.
public struct ClubGroupCodeCapability: Equatable {
    public let granted: Bool
    public let permissions: ClubGovernancePermissions?
    public let clubID: Int
    public let topicID: Int
    public static let absent = Self(granted: false, permissions: nil, clubID: 0, topicID: 0)

    public init(permissions: ClubGovernancePermissions?, scope: ClubGovernanceScope) {
        self.permissions = permissions
        clubID = scope.clubID ?? 0
        topicID = scope.topicID ?? 0
        let sameClub = permissions?.clubID == scope.clubID && clubID > 0 && topicID > 0
        let clubWide = permissions?.permissions.contains(ClubGovernanceMutation.issueGroupCode.permission ?? "") == true
        let eventScoped = permissions?.eventAccesses.contains { row in
            (row["permissions"].array ?? []).contains(.string(ClubGovernanceMutation.issueGroupCode.permission ?? ""))
        } == true
        granted = sameClub && permissions?.active == true && (clubWide || eventScoped)
    }

    public func allows(activityID: Int) -> Bool {
        guard granted, activityID > 0, let permissions else { return false }
        return permissions.allows(ClubGovernanceMutation.issueGroupCode.permission, scope: .init(clubID: clubID, topicID: topicID, activityID: activityID))
    }

    private init(granted: Bool, permissions: ClubGovernancePermissions?, clubID: Int, topicID: Int) {
        self.granted = granted
        self.permissions = permissions
        self.clubID = clubID
        self.topicID = topicID
    }
}

public struct ClubGroupCodeSession: Equatable, Identifiable {
    public let id: Int
    public let label: String
    public let headcount: ClubGroupCodeCount
    public init(id: Int, label: String, headcount: ClubGroupCodeCount) {
        self.id = id
        self.label = label
        self.headcount = headcount
    }
}

/// Page model for pages/club/group-code/index.
/// Reads the existing topic overview (`api/topic/info-to-user`) and builds the existing
/// `issueGroupCode` command (`api/verify/groupcode/issue`). It does not dispatch, does not
/// register a route, and is not a player-first entry. Missing check-in capability stays hidden.
public struct ClubGroupCodePage: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(ClubGovernanceFailure)
        case unknown
        case ready
    }
    public static let unknownDisplay = ClubGroupCodeCount.unknownDisplay
    public static let readOperation = ClubGovernanceRead.topicOverview
    public static let issueOperation = ClubGovernanceMutation.issueGroupCode
    /// Production issuance stays behind the provider risk gate. This type never sends.
    public static let issuanceLive = false
    public static let includedInPlayerFirstEntry = false
    public static let routeMarkedLive = false
    public enum Copy {
        public static let loading = "club.groupCode.page.loading"
        public static let empty = "club.groupCode.page.empty"
        public static let error = "club.groupCode.page.error"
        public static let unknown = "club.groupCode.page.unknown"
        public static let retry = "club.groupCode.page.retry"
        public static let headcount = "club.groupCode.metric.headcount"
        public static let providerGate = "club.gov.providerGate"
    }
    public enum Accessibility {
        public static let loading = "club.groupCode.page.loading"
        public static let empty = "club.groupCode.page.empty"
        public static let error = "club.groupCode.page.error"
        public static let unknown = "club.groupCode.page.unknown"
        public static let headcount = "club.groupCode.metric.headcount"
    }
    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public let scope: ClubGovernanceScope?
    public let sessions: [ClubGroupCodeSession]?
    public var hidden: Bool { !(clientCapabilityPresent && serverFactPresent) }
    public var showsSessions: Bool { sessions?.isEmpty == false }

    public static func loading(clientCapabilityPresent: Bool) -> Self {
        Self(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: false, phase: .loading, scope: nil, sessions: nil)
    }

    /// Projects one topic overview. Sessions the viewer cannot check in are omitted.
    /// A missing or non-integer `headcount` is an em dash. A literal 0 stays 0.
    public static func project(value: ClubGovernanceValue, scope: ClubGovernanceScope, capability: ClubGroupCodeCapability) -> Self {
        guard capability.granted, capability.clubID == scope.clubID, capability.topicID == scope.topicID else {
            return .loading(clientCapabilityPresent: false)
        }
        guard (scope.clubID ?? 0) > 0, (scope.topicID ?? 0) > 0 else {
            return revealed(scope: scope, phase: .error(.invalidRequest), sessions: nil)
        }
        let validated: ClubGovernanceValue
        do { validated = try ClubGovernanceValidation.validate(value, operation: readOperation, scope: scope) }
        catch let failure as ClubGovernanceFailure { return revealed(scope: scope, phase: .error(failure), sessions: nil) }
        catch { return revealed(scope: scope, phase: .error(.malformed), sessions: nil) }
        var sessions: [ClubGroupCodeSession] = []
        var seen = Set<Int>()
        for row in validated["activityList"].array ?? [] {
            guard case .integer(let id) = row["id"], id > 0, seen.insert(id).inserted, capability.allows(activityID: id) else { continue }
            let label = ClubGroupCodePort.sessionLabel(id: id, name: row["name"].string, startDate: row["startDate"].string, startTime: row["startTime"].string)
            sessions.append(.init(id: id, label: label, headcount: ClubGroupCodeCount.parse(row["headcount"])))
        }
        if sessions.isEmpty { return revealed(scope: scope, phase: .empty, sessions: []) }
        if sessions.contains(where: { $0.headcount.literal == nil }) { return revealed(scope: scope, phase: .unknown, sessions: sessions) }
        return revealed(scope: scope, phase: .ready, sessions: sessions)
    }

    public init(snapshot: ClubGovernanceSnapshot) {
        let capability = ClubGroupCodeCapability(permissions: snapshot.permissions, scope: snapshot.scope)
        guard snapshot.operation == Self.readOperation, capability.granted else {
            self = .loading(clientCapabilityPresent: false)
            return
        }
        self = .project(value: snapshot.value, scope: snapshot.scope, capability: capability)
    }

    /// Reads the existing topic overview. A missing check-in capability does not call the reader.
    /// This method does not issue a code.
    @MainActor public static func load(access: any ClubGovernanceAccess, scope: ClubGovernanceScope, capability: ClubGroupCodeCapability) async -> Self {
        guard capability.granted else { return .loading(clientCapabilityPresent: false) }
        do {
            let snapshot = try await access.read(readOperation, scope: scope, options: [:])
            return Self(snapshot: snapshot)
        } catch let failure as ClubGovernanceFailure {
            if failure == .forbidden || failure == .signedOut { return .loading(clientCapabilityPresent: false) }
            return revealed(scope: scope, phase: .error(failure), sessions: nil)
        } catch is CancellationError {
            return .loading(clientCapabilityPresent: true)
        } catch {
            return revealed(scope: scope, phase: .error(.unknown(message: nil)), sessions: nil)
        }
    }

    /// The existing issue body, only for a session this page already revealed. Never sent from here.
    public func issueCommand(activityID: Int) -> ClubGovernanceCommand? {
        guard let scope, sessions?.contains(where: { $0.id == activityID }) == true,
              let clubID = scope.clubID, let topicID = scope.topicID else { return nil }
        return try? ClubGovernanceCommand(operation: Self.issueOperation, scope: .init(clubID: clubID, topicID: topicID, activityID: activityID), values: [:])
    }

    private init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?, scope: ClubGovernanceScope?, sessions: [ClubGroupCodeSession]?) {
        self.clientCapabilityPresent = clientCapabilityPresent
        self.serverFactPresent = serverFactPresent
        let revealed = clientCapabilityPresent && serverFactPresent
        if revealed {
            switch phase {
            case .loading, nil: self.phase = .unknown
            case .empty, .error, .unknown, .ready: self.phase = phase
            }
        } else if clientCapabilityPresent, case .loading? = phase {
            self.phase = .loading
        } else {
            self.phase = nil
        }
        switch self.phase {
        case .some(.empty), .some(.unknown), .some(.ready):
            self.scope = scope
            self.sessions = sessions ?? []
        case .some(.error):
            self.scope = scope
            self.sessions = nil
        case .some(.loading), .none:
            self.scope = nil
            self.sessions = nil
        }
    }

    private static func revealed(scope: ClubGovernanceScope, phase: Phase, sessions: [ClubGroupCodeSession]?) -> Self {
        Self(clientCapabilityPresent: true, serverFactPresent: true, phase: phase, scope: scope, sessions: sessions)
    }
}

/// Issue body is `{activityId}` only. A link with no club id can build this command.
public enum ClubGroupCodeIssueBody {
    public static func command(activityID: Int) throws -> ClubGovernanceCommand {
        try ClubGovernanceCommand(operation: .issueGroupCode, scope: ClubGovernanceScope(activityID: activityID), values: [:])
    }
}

/// Club-scoped scan router from `utils/verification-scan.js`. Invalid codes send nothing.
public struct ClubScanReady: Equatable {
    public let kind: String
    public let path: String
    public let body: [String: String]
    public let loadingTitle: String
    public let successTitle: String
}

public enum ClubScanResolution: Equatable {
    case ready(ClubScanReady)
    case invalid(message: String, path: String?, confirmText: String?)
    public var readyPath: String? {
        if case .ready(let matched) = self { return matched.path }
        return nil
    }
    public var readyBody: [String: String]? {
        if case .ready(let matched) = self { return matched.body }
        return nil
    }
}

public enum ClubScanRoute {
    public static func resolve(_ raw: String) -> ClubScanResolution {
        let code = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return invalid() }
        if code.hasPrefix("v1.") {
            let parts = code.split(separator: ".", omittingEmptySubsequences: false).map(String.init)
            let type = parts.count >= 3 ? parts[2] : ""
            if type.hasPrefix("group_") {
                return ready("group", code, "api/verify/groupcode/redeem", ["code": code], "核销中...", "已记录接待该团")
            }
            if isSeat(type, prefix: "topic_seat_") {
                return invalid("这是主题席位码，请由本场带队者从带队核销入口扫码")
            }
            if type == "activity" || type == "topic" || isSeat(type, prefix: "activity_seat_") {
                return ready("dynamic-ticket", code, "api/registration/scan_dynamic_code", ["code": code], "验票中...", "验票成功")
            }
            if type.hasPrefix("citynode_") {
                return .invalid(message: "这是节点核销码，请从「城市节点」页扫码核销", path: "/pages/merchant/citynode/index", confirmText: "去节点页")
            }
            return invalid("暂不支持此动态码")
        }
        if code.hasPrefix("cq1."), code.split(separator: ".", omittingEmptySubsequences: false).count == 4 {
            return ready("coupon", code, "api/coupon/verification", ["code": code], "核销中...", "核销成功")
        }
        if let data = code.data(using: .utf8),
           let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let kind = object["type"] as? String, !kind.isEmpty,
           let inner = object["code"] as? String, !inner.isEmpty {
            if kind == "coupon" {
                return ready("coupon", inner, "api/coupon/verification", ["code": inner], "核销中...", "核销成功")
            }
            if kind == "activity" || kind == "topic" {
                return ready("legacy-ticket", inner, "api/registration/scan_qr_code", ["type": kind, "code": inner], "验票中...", "验票成功")
            }
        }
        return invalid()
    }

    private static func isSeat(_ type: String, prefix: String) -> Bool {
        guard type.hasPrefix(prefix) else { return false }
        let rest = type.dropFirst(prefix.count)
        guard let first = rest.first, ("1"..."9").contains(first) else { return false }
        return rest.dropFirst().allSatisfy(\.isNumber)
    }

    private static func ready(_ kind: String, _ code: String, _ path: String, _ body: [String: String], _ loading: String, _ success: String) -> ClubScanResolution {
        .ready(.init(kind: kind, path: path, body: body, loadingTitle: loading, successTitle: success))
    }

    private static func invalid(_ message: String = "二维码格式错误") -> ClubScanResolution {
        .invalid(message: message, path: nil, confirmText: nil)
    }
}

/// Non-money club verify. On. Pay, refund, payout, and withdrawal are not this switch.
public enum ClubScanWrite {
    public static let enabled = true
    public static func mayScan(canGovern: Bool, canManageActivities: Bool) -> Bool {
        canGovern || canManageActivities
    }
}

public struct ClubScanClient {
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport

    public init(configuration: APIConfiguration, transport: any HTTPTransport) {
        self.configuration = configuration
        self.transport = transport
    }

    /// Posts the mini-program body when the scan is a real verify route and the caller may scan.
    /// Returns false and sends nothing for an invalid code, a closed switch, or a viewer who cannot scan.
    public func submit(_ raw: String, token: String, canGovern: Bool, canManageActivities: Bool) async throws -> Bool {
        guard ClubScanWrite.enabled, ClubScanWrite.mayScan(canGovern: canGovern, canManageActivities: canManageActivities) else { return false }
        guard case .ready(let matched) = ClubScanRoute.resolve(raw) else { return false }
        let payload = matched.body.mapValues { $0 as Any }
        try await MPGapHTTP.postAction(
            configuration: configuration, transport: transport,
            path: matched.path, body: payload, token: token)
        return true
    }
}

#if DEBUG
/// Offline group-code documents. Compiled only in DEBUG. Not a live account and not a code image.
public enum ClubGroupCodePageFixtureData {
    public static let scope = ClubGovernanceScope(clubID: 81, topicID: 91)
    public static var ready: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"id":91,"name":"Fixture club story","activityList":[{"id":101,"name":"夜游","startDate":"2026-09-06","startTime":"9:05","headcount":0},{"id":102,"name":"午场","headcount":2}]}"#)
    }
    public static var emptyList: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"id":91,"name":"Fixture club story","activityList":[]}"#)
    }
    public static var unknownHeadcount: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"id":91,"name":"Fixture club story","activityList":[{"id":101,"name":"夜游","headcount":0},{"id":102,"name":"午场","headcount":null}]}"#)
    }
    public static var stringZeroHeadcount: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"id":91,"name":"Fixture club story","activityList":[{"id":101,"name":"夜游","headcount":"0"}]}"#)
    }
}
#endif
