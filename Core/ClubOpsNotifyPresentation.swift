import Foundation

/// Mini-program pages/club/notify presentation. Display only: every read, preview, send and
/// retry keeps the existing governance permission, validation, review and production gates.
public struct ClubOpsNotifyCampaign: Equatable {
    public enum Phase: String, Equatable { case completed, partialFailed, delivering }
    public let id: Int
    public let totalCount: Int
    public let successCount: Int
    public let failedCount: Int
    public let phase: Phase
    /// Only an explicit `PROCESSING` shows "后台还在投递".
    public let processing: Bool
    /// `total - success - failed`, never negative; not a separate server field.
    public var pendingCount: Int { max(max(totalCount - successCount, 0) - failedCount, 0) }
    public var canRetryFailed: Bool { failedCount > 0 }
    public init(value: ClubGovernanceValue) throws {
        guard let id = value["id"].int, id > 0 else { throw ClubGovernanceFailure.malformed }
        func count(_ key: String) throws -> Int {
            switch value[key] {
            case .null: return 0
            case .integer(let number) where number >= 0: return number
            default: throw ClubGovernanceFailure.malformed
            }
        }
        self.id = id
        totalCount = try count("totalCount"); successCount = try count("successCount"); failedCount = try count("failedCount")
        let status = (value["status"].string ?? "").uppercased()
        phase = status == "COMPLETED" ? .completed : status == "PARTIAL_FAILED" ? .partialFailed : .delivering
        processing = status == "PROCESSING"
    }
}

public struct ClubOpsNotifyAudienceRow: Equatable, Identifiable {
    public let id: String
    /// Nil when the server sends null (e.g. event audiences without an activity): unknown, not zero.
    public let count: Int?
}

public enum ClubOpsNotifyPresentation {
    public static let audienceIDs = ["ALL_MEMBERS", "ADMINS", "REGISTERED", "WAITLIST", "NO_SHOW", "INACTIVE"]
    public static let titleLimit = 80
    public static let contentLimit = 1000
    public enum DraftIssue: String, Equatable { case title, content }
    public static func audienceRows(_ value: ClubGovernanceValue) throws -> [ClubOpsNotifyAudienceRow] {
        guard let counts = value["counts"].object else { throw ClubGovernanceFailure.malformed }
        return audienceIDs.map { id in
            if case .integer(let number) = counts[id] ?? .null, number >= 0 { return .init(id: id, count: number) }
            return .init(id: id, count: nil)
        }
    }
    /// Same order and bounds as `validDraft()`: title first (1–80), then content (1–1000), trimmed, UTF-16.
    public static func draftIssue(title: String, content: String) -> DraftIssue? {
        let title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if title.isEmpty || title.utf16.count > titleLimit { return .title }
        if content.isEmpty || content.utf16.count > contentLimit { return .content }
        return nil
    }
    /// Preview card: `N 人`, or the empty-audience note when the count is 0.
    public static func previewCount(_ value: ClubGovernanceValue) -> Int? {
        guard case .integer(let count) = value["recipientCount"], count >= 0 else { return nil }
        return count
    }
}

/// A count the server actually sent as a non-negative integer. Unknown is never stored as 0.
public enum ClubNotifyCount: Equatable {
    case known(Int)
    case unknown
    public static let unknownDisplay = "—"
    /// The server literal, including 0. Unknown is nil.
    public var literal: Int? {
        if case .known(let number) = self { return number }
        return nil
    }
    /// Unknown, null, a numeric string, a decimal, and a negative are an em dash, never 0.
    public var displayText: String {
        switch self {
        case .known(let number): return String(number)
        case .unknown: return Self.unknownDisplay
        }
    }
    /// Only a JSON integer of 0 or more is known. `.int` is not used, because it accepts numeric strings.
    public static func parse(_ value: ClubGovernanceValue) -> Self {
        if case .integer(let number) = value, number >= 0 { return .known(number) }
        return .unknown
    }
    /// Pending is `total - success - failed` only when every input is a known integer and the sum fits.
    /// A missing or non-integer input stays unknown. It is not treated as 0.
    public static func pending(total: Self, success: Self, failed: Self) -> Self {
        guard let total = total.literal, let success = success.literal, let failed = failed.literal else { return .unknown }
        let (sum, overflow) = success.addingReportingOverflow(failed)
        guard !overflow, sum <= total else { return .unknown }
        return .known(total - sum)
    }
}

/// Club broadcast stays on `club:notify:send`. Event audiences use the existing `club:event:operate` grant
/// only when the scope already names an activity. A missing grant stays hidden.
public struct ClubNotifyCapability: Equatable {
    public let canRead: Bool
    public let canBroadcast: Bool
    public let canSendEventAudience: Bool
    public static let absent = Self(canRead: false, canBroadcast: false, canSendEventAudience: false)
    public init(canRead: Bool, canBroadcast: Bool, canSendEventAudience: Bool) {
        self.canRead = canRead
        self.canBroadcast = canRead && canBroadcast
        self.canSendEventAudience = canRead && canSendEventAudience
    }
    public init(permissions: ClubGovernancePermissions?, scope: ClubGovernanceScope) {
        let notify = permissions?.allows(ClubGovernanceRead.audienceCounts.permission, scope: scope) == true
        let event = (scope.activityID ?? 0) > 0 && permissions?.allows("club:event:operate", scope: scope) == true
        self.init(canRead: notify || event, canBroadcast: notify, canSendEventAudience: event)
    }
}

public struct ClubNotifyAudienceCount: Equatable, Identifiable {
    public let id: String
    public let count: ClubNotifyCount
}

/// Page model for pages/club/notify/index. Reads the existing audience-counts contract.
/// This type does not register a route, does not mark one live, and is not a player-first entry.
/// It never sends or retries a broadcast.
public struct ClubNotifyPage: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(ClubGovernanceFailure)
        case unknown
        case ready
    }
    public static let unknownDisplay = ClubNotifyCount.unknownDisplay
    public static let readOperation = ClubGovernanceRead.audienceCounts
    public static let includedInPlayerFirstEntry = false
    public static let routeMarkedLive = false
    public static let sendMarkedLive = false
    public static let retryMarkedLive = false
    public static let broadcastSend = ClubGovernanceMutation.sendNotification
    public static let broadcastRetry = ClubGovernanceMutation.retryNotification
    /// Same three event audiences the existing command gate already requires `club:event:operate` for.
    public static let eventAudienceIDs: Set<String> = ["REGISTERED", "WAITLIST", "NO_SHOW"]
    public enum Copy {
        public static let loading = "club.loading"
        public static let empty = "clubOpsJN.notify.preview.empty"
        public static let error = "clubOpsNotify.failed"
        public static let retry = "clubOpsNotify.retry"
        public static let forbiddenTitle = "clubOpsNotify.denied.title"
        public static let forbiddenBody = "clubOpsNotify.denied.body"
    }
    public enum Accessibility {
        public static let loading = "club.notify.page.loading"
        public static let empty = "club.notify.page.empty"
        public static let error = "club.notify.page.error"
        public static let unknown = "club.notify.page.unknown"
        public static func audience(_ id: String) -> String { "club.notify.page.audience." + id }
    }
    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public let rows: [ClubNotifyAudienceCount]?
    public let canBroadcast: Bool
    public let canSendEventAudience: Bool
    public var hidden: Bool { !(clientCapabilityPresent && serverFactPresent) }
    /// Club-wide broadcast is shown only with the notify grant and a revealed audience fact.
    /// An all-zero audience does not offer it. This flag does not send.
    public var broadcastOffered: Bool {
        guard !hidden, canBroadcast else { return false }
        switch phase {
        case .ready, .unknown: return true
        default: return false
        }
    }
    /// Event audiences stay on the existing event grant. They are not a club-wide broadcast.
    public var eventAudienceOffered: Bool {
        guard !hidden, canSendEventAudience else { return false }
        switch phase {
        case .ready, .unknown: return true
        default: return false
        }
    }

    public static func loading(clientCapabilityPresent: Bool, canBroadcast: Bool = false, canSendEventAudience: Bool = false) -> Self {
        Self(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: false, phase: .loading,
             rows: nil, canBroadcast: canBroadcast, canSendEventAudience: canSendEventAudience)
    }

    /// Projects one audience-counts document. Does not invent a count for a missing or non-integer field.
    public static func project(value: ClubGovernanceValue, capability: ClubNotifyCapability) -> Self {
        guard capability.canRead else { return .loading(clientCapabilityPresent: false) }
        guard let counts = value["counts"].object else {
            return revealed(phase: .error(.malformed), capability: capability)
        }
        let rows = ClubOpsNotifyPresentation.audienceIDs.map { id in
            ClubNotifyAudienceCount(id: id, count: .parse(counts[id] ?? .null))
        }
        let parsed = rows.map(\.count)
        if parsed.contains(where: { $0.literal == nil }) {
            return revealed(phase: .unknown, rows: rows, capability: capability)
        }
        if parsed.allSatisfy({ $0.literal == 0 }) {
            return revealed(phase: .empty, rows: rows, capability: capability)
        }
        return revealed(phase: .ready, rows: rows, capability: capability)
    }

    /// Preview recipient count from the existing preview document. A literal 0 stays 0.
    public static func previewRecipient(_ value: ClubGovernanceValue) -> ClubNotifyCount {
        ClubNotifyCount.parse(value["recipientCount"])
    }

    public init(snapshot: ClubGovernanceSnapshot) {
        let capability = ClubNotifyCapability(permissions: snapshot.permissions, scope: snapshot.scope)
        guard snapshot.operation == Self.readOperation, capability.canRead else {
            self = .loading(clientCapabilityPresent: false)
            return
        }
        self = .project(value: snapshot.value, capability: capability)
    }

    /// Reads the existing audience-counts route. A missing capability does not call the reader and does not send.
    @MainActor public static func load(access: any ClubGovernanceAccess, scope: ClubGovernanceScope, capability: ClubNotifyCapability) async -> Self {
        guard capability.canRead else { return .loading(clientCapabilityPresent: false) }
        guard (scope.clubID ?? 0) > 0 else {
            return revealed(phase: .error(.invalidRequest), capability: capability)
        }
        do {
            let snapshot = try await access.read(readOperation, scope: scope, options: [:])
            return Self(snapshot: snapshot)
        } catch let failure as ClubGovernanceFailure {
            if failure == .forbidden || failure == .signedOut { return .loading(clientCapabilityPresent: false) }
            return revealed(phase: .error(failure), capability: capability)
        } catch is CancellationError {
            return .loading(clientCapabilityPresent: true, canBroadcast: capability.canBroadcast, canSendEventAudience: capability.canSendEventAudience)
        } catch {
            return revealed(phase: .error(.unknown(message: nil)), capability: capability)
        }
    }

    /// True only for a known positive count and the grant that audience already requires.
    /// Unknown and literal 0 are not addressable. Event audiences do not follow the club-wide grant.
    public func canAddress(_ id: String) -> Bool {
        guard let count = rows?.first(where: { $0.id == id })?.count.literal, count > 0 else { return false }
        if Self.eventAudienceIDs.contains(id) { return eventAudienceOffered }
        return broadcastOffered
    }

    private init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?, rows: [ClubNotifyAudienceCount]?, canBroadcast: Bool, canSendEventAudience: Bool) {
        self.clientCapabilityPresent = clientCapabilityPresent
        self.serverFactPresent = serverFactPresent
        self.canBroadcast = clientCapabilityPresent && canBroadcast
        self.canSendEventAudience = clientCapabilityPresent && canSendEventAudience
        let revealed = clientCapabilityPresent && serverFactPresent
        if revealed {
            if phase == nil || phase == .loading { self.phase = .unknown }
            else { self.phase = phase }
        } else if clientCapabilityPresent, phase == .loading {
            self.phase = .loading
        } else {
            self.phase = nil
        }
        switch self.phase {
        case .some(.empty), .some(.unknown), .some(.ready): self.rows = rows
        default: self.rows = nil
        }
    }

    private static func revealed(phase: Phase, rows: [ClubNotifyAudienceCount]? = nil, capability: ClubNotifyCapability) -> Self {
        Self(clientCapabilityPresent: true, serverFactPresent: true, phase: phase, rows: rows,
             canBroadcast: capability.canBroadcast, canSendEventAudience: capability.canSendEventAudience)
    }
}

/// Delivery card for the same page. Uses the existing status read. Unknown counts stay an em dash.
/// `ClubOpsNotifyCampaign` still accepts a null count as 0 for the older receipt path; this type does not.
public struct ClubNotifyDeliveryPage: Equatable {
    public static let unknownDisplay = ClubNotifyCount.unknownDisplay
    public static let readOperation = ClubGovernanceRead.notificationStatus
    public static let includedInPlayerFirstEntry = false
    public static let routeMarkedLive = false
    public static let sendMarkedLive = false
    public static let retryMarkedLive = false
    public enum Accessibility {
        public static let status = "club.notify.page.delivery.status"
        public static let total = "club.notify.page.delivery.total"
        public static let success = "club.notify.page.delivery.success"
        public static let failed = "club.notify.page.delivery.failed"
        public static let pending = "club.notify.page.delivery.pending"
    }
    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: ClubNotifyPage.Phase?
    public let id: Int?
    public let total: ClubNotifyCount?
    public let success: ClubNotifyCount?
    public let failed: ClubNotifyCount?
    public let pending: ClubNotifyCount?
    /// COMPLETED, PARTIAL_FAILED, or PROCESSING. Anything else, including the literal UNKNOWN, is nil.
    public let knownStatus: String?
    public let processing: Bool
    public let canBroadcast: Bool
    public var hidden: Bool { !(clientCapabilityPresent && serverFactPresent) }
    public var statusDisplay: String { knownStatus ?? Self.unknownDisplay }
    public var statusKey: String? {
        switch knownStatus {
        case "COMPLETED": return "clubOpsJN.notify.phase.completed"
        case "PARTIAL_FAILED": return "clubOpsJN.notify.phase.partialFailed"
        case "PROCESSING": return "clubOpsJN.notify.phase.delivering"
        default: return nil
        }
    }
    public var broadcastOffered: Bool {
        guard !hidden, canBroadcast else { return false }
        switch phase {
        case .ready, .unknown: return true
        default: return false
        }
    }
    /// Retry stays on the notify grant and a known status. An unknown failed count does not become 0 and does not offer retry.
    public var retryOffered: Bool {
        guard case .ready? = phase, canBroadcast, let failed = failed?.literal else { return false }
        return failed > 0
    }

    public static func loading(clientCapabilityPresent: Bool, canBroadcast: Bool = false) -> Self {
        Self(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: false, phase: .loading,
             id: nil, total: nil, success: nil, failed: nil, pending: nil, knownStatus: nil,
             processing: false, canBroadcast: canBroadcast)
    }

    public static func project(value: ClubGovernanceValue, capability: ClubNotifyCapability) -> Self {
        guard capability.canRead else { return .loading(clientCapabilityPresent: false) }
        guard case .integer(let id) = value["id"], id > 0 else {
            return revealed(phase: .error(.malformed), capability: capability)
        }
        let total = ClubNotifyCount.parse(value["totalCount"])
        let success = ClubNotifyCount.parse(value["successCount"])
        let failed = ClubNotifyCount.parse(value["failedCount"])
        let pending = ClubNotifyCount.pending(total: total, success: success, failed: failed)
        if let total = total.literal, let success = success.literal, let failed = failed.literal {
            let (sum, overflow) = success.addingReportingOverflow(failed)
            if overflow || sum > total {
                return revealed(phase: .error(.malformed), capability: capability)
            }
        }
        let knownStatus = Self.statusToken(value["status"])
        let counts = [total, success, failed]
        let phase: ClubNotifyPage.Phase
        if counts.contains(where: { $0.literal == nil }) || knownStatus == nil {
            phase = counts.allSatisfy({ $0.literal == 0 }) ? .empty : .unknown
        } else if counts.allSatisfy({ $0.literal == 0 }) {
            phase = .empty
        } else {
            phase = .ready
        }
        return revealed(phase: phase, id: id, total: total, success: success, failed: failed, pending: pending,
                        knownStatus: knownStatus, processing: phase == .ready && knownStatus == "PROCESSING", capability: capability)
    }

    public init(snapshot: ClubGovernanceSnapshot) {
        let capability = ClubNotifyCapability(permissions: snapshot.permissions, scope: snapshot.scope)
        guard snapshot.operation == Self.readOperation, capability.canRead else {
            self = .loading(clientCapabilityPresent: false)
            return
        }
        self = .project(value: snapshot.value, capability: capability)
    }

    /// Reads the existing status route. A missing capability does not call the reader and does not retry.
    @MainActor public static func load(access: any ClubGovernanceAccess, scope: ClubGovernanceScope, capability: ClubNotifyCapability) async -> Self {
        guard capability.canRead else { return .loading(clientCapabilityPresent: false) }
        guard (scope.campaignID ?? 0) > 0, (scope.clubID ?? 0) > 0 else {
            return revealed(phase: .error(.invalidRequest), capability: capability)
        }
        do {
            let snapshot = try await access.read(readOperation, scope: scope, options: [:])
            return Self(snapshot: snapshot)
        } catch let failure as ClubGovernanceFailure {
            if failure == .forbidden || failure == .signedOut { return .loading(clientCapabilityPresent: false) }
            return revealed(phase: .error(failure), capability: capability)
        } catch is CancellationError {
            return .loading(clientCapabilityPresent: true, canBroadcast: capability.canBroadcast)
        } catch {
            return revealed(phase: .error(.unknown(message: nil)), capability: capability)
        }
    }

    private static func statusToken(_ value: ClubGovernanceValue) -> String? {
        guard case .string(let raw) = value else { return nil }
        let token = raw.uppercased()
        return ["COMPLETED", "PARTIAL_FAILED", "PROCESSING"].contains(token) ? token : nil
    }

    private init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: ClubNotifyPage.Phase?, id: Int?, total: ClubNotifyCount?, success: ClubNotifyCount?, failed: ClubNotifyCount?, pending: ClubNotifyCount?, knownStatus: String?, processing: Bool, canBroadcast: Bool) {
        self.clientCapabilityPresent = clientCapabilityPresent
        self.serverFactPresent = serverFactPresent
        self.canBroadcast = clientCapabilityPresent && canBroadcast
        let revealed = clientCapabilityPresent && serverFactPresent
        if revealed {
            if phase == nil || phase == .loading { self.phase = .unknown }
            else { self.phase = phase }
        } else if clientCapabilityPresent, phase == .loading {
            self.phase = .loading
        } else {
            self.phase = nil
        }
        switch self.phase {
        case .some(.empty), .some(.unknown), .some(.ready):
            self.id = id; self.total = total; self.success = success; self.failed = failed
            self.pending = pending; self.knownStatus = knownStatus; self.processing = processing
        default:
            self.id = nil; self.total = nil; self.success = nil; self.failed = nil
            self.pending = nil; self.knownStatus = nil; self.processing = false
        }
    }

    private static func revealed(phase: ClubNotifyPage.Phase, id: Int? = nil, total: ClubNotifyCount? = nil, success: ClubNotifyCount? = nil, failed: ClubNotifyCount? = nil, pending: ClubNotifyCount? = nil, knownStatus: String? = nil, processing: Bool = false, capability: ClubNotifyCapability) -> Self {
        Self(clientCapabilityPresent: true, serverFactPresent: true, phase: phase, id: id, total: total, success: success,
             failed: failed, pending: pending, knownStatus: knownStatus, processing: processing, canBroadcast: capability.canBroadcast)
    }
}

#if DEBUG
/// Offline notify documents. Compiled only in DEBUG. Not a live account.
public enum ClubNotifyFixtureData {
    public static let clubScope = ClubGovernanceScope(clubID: 81)
    public static let eventScope = ClubGovernanceScope(clubID: 81, activityID: 101)
    public static let statusScope = ClubGovernanceScope(clubID: 81, campaignID: 131)
    public static var mixed: ClubGovernanceValue { ClubGovernanceFixtures.value(.audienceCounts) }
    public static var ready: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"counts":{"ALL_MEMBERS":8,"ADMINS":1,"REGISTERED":3,"WAITLIST":2,"NO_SHOW":0,"INACTIVE":4}}"#)
    }
    public static var empty: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"counts":{"ALL_MEMBERS":0,"ADMINS":0,"REGISTERED":0,"WAITLIST":0,"NO_SHOW":0,"INACTIVE":0}}"#)
    }
    public static var statusReady: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"id":131,"totalCount":8,"successCount":5,"failedCount":1,"status":"PARTIAL_FAILED"}"#)
    }
    public static var statusZero: ClubGovernanceValue {
        ClubGovernanceFixtures.json(#"{"id":131,"totalCount":0,"successCount":0,"failedCount":0,"status":"COMPLETED"}"#)
    }
}
#endif
