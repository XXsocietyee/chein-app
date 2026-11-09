import Foundation

/// Mini-program `displayDate` parity: server clock strings keep their own digits, epoch numbers render in Shanghai time.
public enum ClubOpsGovernanceClock {
    public static let timeZone = TimeZone(identifier: "Asia/Shanghai")!
    public static func minute(_ value: ClubGovernanceValue) -> String? {
        switch value {
        case .string(let raw):
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "T", with: " ")
            return text.isEmpty ? nil : String(text.prefix(16))
        case .integer, .decimal:
            guard let ms = value.number, ms > 0 else { return nil }
            return format(Date(timeIntervalSince1970: ms / 1000), "yyyy-MM-dd HH:mm")
        default: return nil
        }
    }
    /// Role delegation expiry is shown to the day only (` · 至 MM-DD`).
    public static func monthDay(_ value: ClubGovernanceValue) -> String? {
        switch value {
        case .string(let raw):
            let text = Array(raw.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "T", with: " "))
            return text.count >= 10 ? String(text[5..<10]) : nil
        case .integer, .decimal:
            guard let ms = value.number, ms > 0 else { return nil }
            return format(Date(timeIntervalSince1970: ms / 1000), "MM-dd")
        default: return nil
        }
    }
    public static func format(_ date: Date, _ pattern: String) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian); formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone; formatter.dateFormat = pattern
        return formatter.string(from: date)
    }
    static func text(_ value: ClubGovernanceValue) -> String? {
        guard let raw = value.string else { return nil }
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines); return text.isEmpty ? nil : text
    }
}

public enum ClubOpsBanSource: String, Equatable { case club = "CLUB", platform = "PLATFORM" }
public enum ClubOpsBanStatus: String, Equatable { case active = "ACTIVE", expired = "EXPIRED", unbanned = "UNBANNED" }
public enum ClubOpsBanExpiry: Equatable {
    case until(String), platformPermanent, unknown
    static func of(_ value: ClubGovernanceValue, source: ClubOpsBanSource) -> Self {
        if source == .platform, ClubOpsGovernanceClock.text(value) == nil, value.number == nil { return .platformPermanent }
        return ClubOpsGovernanceClock.minute(value).map(Self.until) ?? .unknown
    }
}

public struct ClubOpsBanRow: Equatable, Identifiable {
    public let id: Int
    public let targetMemberID: Int
    public let nickname: String?
    public let source: ClubOpsBanSource
    public let status: ClubOpsBanStatus
    public let bannedAt: String?
    public let expiry: ClubOpsBanExpiry
    public let unbanReason: String?
    /// Raw source anchors for the existing unban review; present only on an ACTIVE CLUB ban.
    public let unbanSeed: [String: ClubGovernanceValue]?
    /// `仅平台可解封`: an ACTIVE PLATFORM ban is outside club authority.
    public var platformOnly: Bool { status == .active && source == .platform }
}

/// Projection of one authorized `.bans` read. Rows the validator accepted keep their order; nothing becomes a write grant.
public struct ClubOpsBanList: Equatable {
    public let rows: [ClubOpsBanRow]
    public init(snapshot: ClubGovernanceSnapshot) throws {
        guard snapshot.operation == .bans, let clubID = snapshot.scope.clubID, clubID > 0 else { throw ClubGovernanceFailure.targetChanged }
        guard snapshot.permissions?.allows(ClubGovernanceRead.bans.permission, scope: snapshot.scope) == true else { throw ClubGovernanceFailure.forbidden }
        guard let list = snapshot.value.array else { throw ClubGovernanceFailure.malformed }
        rows = try list.map { row -> ClubOpsBanRow in
            guard let id = row["id"].int, id > 0, let member = row["targetMemberId"].int, member > 0, row["clubId"].int == clubID,
                  let source = ClubOpsBanSource(rawValue: row["sourceType"].string ?? ""),
                  let status = ClubOpsBanStatus(rawValue: row["status"].string ?? ""),
                  case .integer(let version) = row["version"], version >= 0 else { throw ClubGovernanceFailure.malformed }
            let unbannable = status == .active && source == .club
            return .init(id: id, targetMemberID: member, nickname: ClubOpsGovernanceClock.text(row["targetNickname"]), source: source,
                         status: status, bannedAt: ClubOpsGovernanceClock.minute(row["bannedAt"]), expiry: .of(row["expiresAt"], source: source),
                         unbanReason: ClubOpsGovernanceClock.text(row["unbanReason"]),
                         unbanSeed: unbannable ? ["banId": row["id"], "version": row["version"]] : nil)
        }
    }
}

public enum ClubOpsCaseKind: Equatable { case appeal, report(String) }
public enum ClubOpsCaseStatus: String, Equatable { case pending = "PENDING", approved = "APPROVED", rejected = "REJECTED" }
public struct ClubOpsCaseRow: Equatable, Identifiable {
    public let id: Int
    public let kind: ClubOpsCaseKind
    public let reason: String?
    public let submittedAt: String?
    public let decisionReason: String?
    public let status: ClubOpsCaseStatus
}
public struct ClubOpsActiveBan: Equatable {
    public let id: Int
    public let source: ClubOpsBanSource
    public let bannedAt: String?
    public let expiry: ClubOpsBanExpiry
    public let reason: String?
}
/// `unknown` = this backend sent no fact; `none` = a known absence. Only `.ban` shows the appeal entry.
public enum ClubOpsAppealEligibility: Equatable { case unknown, none, ban(ClubOpsActiveBan) }

public struct ClubOpsCaseList: Equatable {
    public let rows: [ClubOpsCaseRow]
    public let appeal: ClubOpsAppealEligibility
    /// Reports are filed by active members; a banned viewer only sees own cases and the appeal fact.
    public let canReport: Bool
    public var canAppeal: Bool { if case .ban = appeal { return true }; return false }
    /// Mini governance `mode=appeal` (封禁申诉): an inactive viewer (own-case read without access) or one with a known active ban.
    public var appealMode: Bool { !canReport || canAppeal }
    public init(snapshot: ClubGovernanceSnapshot) throws {
        guard snapshot.operation == .cases, let clubID = snapshot.scope.clubID, clubID > 0 else { throw ClubGovernanceFailure.targetChanged }
        if let permissions = snapshot.permissions {
            guard permissions.allows(ClubGovernanceRead.cases.permission, scope: snapshot.scope) else { throw ClubGovernanceFailure.forbidden }
        }
        guard let list = snapshot.value.array ?? snapshot.value["data"].array else { throw ClubGovernanceFailure.malformed }
        rows = try list.map { row -> ClubOpsCaseRow in
            guard let id = row["id"].int, id > 0, row["clubId"].int == clubID,
                  let status = ClubOpsCaseStatus(rawValue: row["status"].string ?? "") else { throw ClubGovernanceFailure.malformed }
            let kind: ClubOpsCaseKind
            if row["caseType"] == .string("APPEAL"), row["targetType"] == .string("BAN") { kind = .appeal }
            else if row["caseType"] == .string("REPORT"), let target = row["targetType"].string, ["CLUB", "ACTIVITY", "MEMBER"].contains(target) { kind = .report(target) }
            else { throw ClubGovernanceFailure.malformed }
            return .init(id: id, kind: kind, reason: ClubOpsGovernanceClock.text(row["reason"]), submittedAt: ClubOpsGovernanceClock.minute(row["createTime"]),
                         decisionReason: ClubOpsGovernanceClock.text(row["decisionReason"]), status: status)
        }
        switch snapshot.value.object?["activeBan"] {
        case .none: appeal = .unknown
        case .some(.null): appeal = .none
        case .some(let ban):
            guard let id = ban["id"].int, id > 0, ban["clubId"].int == clubID, ban["status"] == .string("ACTIVE"),
                  let source = ClubOpsBanSource(rawValue: ban["sourceType"].string ?? "") else { throw ClubGovernanceFailure.malformed }
            appeal = .ban(.init(id: id, source: source, bannedAt: ClubOpsGovernanceClock.minute(ban["bannedAt"]),
                                expiry: .of(ban["expiresAt"], source: source), reason: ClubOpsGovernanceClock.text(ban["banReason"])))
        }
        canReport = snapshot.permissions != nil
    }
}

/// `.members` projection for the governance target list. The owner row is excluded exactly as the mini-program does.
public struct ClubOpsGovernanceMember: Equatable, Identifiable {
    public let id: Int
    public let nickname: String?
    public var seed: [String: ClubGovernanceValue] {
        var seed: [String: ClubGovernanceValue] = ["targetMemberId": .integer(id)]
        if let nickname { seed["targetNickname"] = .string(nickname) }
        return seed
    }
}
public struct ClubOpsGovernanceMembers: Equatable {
    public let members: [ClubOpsGovernanceMember]
    public let ownerName: String?
    public let viewerIsOwner: Bool
    public init(snapshot: ClubGovernanceSnapshot) throws {
        guard snapshot.operation == .members, (snapshot.scope.clubID ?? 0) > 0 else { throw ClubGovernanceFailure.targetChanged }
        guard let list = snapshot.value.array else { throw ClubGovernanceFailure.malformed }
        var members: [ClubOpsGovernanceMember] = [], owner: String?
        for row in list {
            guard let id = row["memberId"].int, id > 0 else { throw ClubGovernanceFailure.malformed }
            if row["isOwner"] == .bool(true) { owner = owner ?? ClubOpsGovernanceClock.text(row["nickname"]); continue }
            // Existing ban/transfer review proof requires an explicit false; missing owner status is not offered.
            guard row["isOwner"] == .bool(false) else { continue }
            members.append(.init(id: id, nickname: ClubOpsGovernanceClock.text(row["nickname"])))
        }
        self.members = members; ownerName = owner
        viewerIsOwner = snapshot.permissions?.roleCodes.contains("CLUB_OWNER") == true
    }
}

public struct ClubOpsRoleAssignmentRow: Equatable, Identifiable {
    public let id: Int
    public let targetMemberID: Int
    public let memberName: String?
    public let roleCode: String
    public let roleName: String?
    public let expiresMonthDay: String?
    /// Raw anchors for the existing revoke review, plus display-only names the form never sends.
    public let revokeSeed: [String: ClubGovernanceValue]
    public var summaryKey: String { "club.rolePicker.summary." + roleCode }
}
/// Joins `.roles` assignments with `.members` names client-side (the role VO carries neither name).
/// Missing or failed member reads only lose names; they never hide an assignment or grant anything.
public struct ClubOpsRoleRoster: Equatable {
    public let assignments: [ClubOpsRoleAssignmentRow]
    public let ownerName: String?
    /// nil = member list not (yet) accepted; otherwise the count of non-owner members that could be delegated.
    public let delegableMemberCount: Int?
    public init(roles: ClubGovernanceSnapshot, members: ClubGovernanceSnapshot?) throws {
        guard roles.operation == .roles, (roles.scope.clubID ?? 0) > 0 else { throw ClubGovernanceFailure.targetChanged }
        guard roles.permissions?.allows(ClubGovernanceRead.roles.permission, scope: roles.scope) == true else { throw ClubGovernanceFailure.forbidden }
        guard let definitions = roles.value["roles"].array, let rows = roles.value["assignments"].array else { throw ClubGovernanceFailure.malformed }
        var roleNames: [String: String] = [:]
        for row in definitions { if let code = row["roleCode"].string, let name = ClubOpsGovernanceClock.text(row["name"]) { roleNames[code] = name } }
        var roster: ClubOpsGovernanceMembers?
        if let members, members.operation == .members, members.scope == roles.scope { roster = try? ClubOpsGovernanceMembers(snapshot: members) }
        var names: [Int: String] = [:]
        for member in roster?.members ?? [] { if let name = member.nickname { names[member.id] = name } }
        assignments = try rows.map { row -> ClubOpsRoleAssignmentRow in
            guard let id = row["id"].int, id > 0, let member = row["targetMemberId"].int, member > 0,
                  let code = row["roleCode"].string else { throw ClubGovernanceFailure.malformed }
            let memberName = names[member] ?? ClubOpsGovernanceClock.text(row["memberName"])
            let roleName = roleNames[code]
            var seed: [String: ClubGovernanceValue] = ["assignmentId": row["id"], "version": row["version"]]
            if let memberName { seed["memberName"] = .string(memberName) }
            if let roleName { seed["roleName"] = .string(roleName) }
            return .init(id: id, targetMemberID: member, memberName: memberName, roleCode: code, roleName: roleName,
                         expiresMonthDay: ClubOpsGovernanceClock.monthDay(row["expiresAt"]), revokeSeed: seed)
        }
        ownerName = roster?.ownerName
        delegableMemberCount = roster?.members.count
    }
}

/// Page model for `pages/club/governance/index`.
/// Reads that already exist: `.bans` (`api/club/governance/list`), `.cases` (`api/club/governance/cases/mine`), `.members` (`api/club/members`).
/// A missing capability stays hidden and is not read. This type does not register a route, does not mark one live, and does not write.
public struct ClubOpsGovernanceCapability: Equatable {
    public let manageMembers: Bool
    public let readCases: Bool
    public let viewerIsOwner: Bool
    public let activeMember: Bool
    public var granted: Bool { manageMembers || readCases }
    public static let absent = Self(manageMembers: false, readCases: false, viewerIsOwner: false, activeMember: false)

    public init(manageMembers: Bool, readCases: Bool, viewerIsOwner: Bool, activeMember: Bool) {
        self.manageMembers = manageMembers
        self.readCases = readCases
        self.viewerIsOwner = viewerIsOwner
        self.activeMember = activeMember
    }

    /// Local preflight. Event-only grants do not open member governance.
    /// Cases stay readable for an active member of this club, or for an inactive viewer already classified as this club's own-cases reader.
    public init(permissions: ClubGovernancePermissions?, scope: ClubGovernanceScope, inactiveOwnCases: Bool = false) {
        let active = permissions?.allows(nil, scope: scope) == true
        self.init(
            manageMembers: permissions?.allows(ClubGovernanceRead.bans.permission, scope: scope) == true,
            readCases: active || (inactiveOwnCases && permissions == nil),
            viewerIsOwner: permissions?.roleCodes.contains("CLUB_OWNER") == true,
            activeMember: active
        )
    }

    /// Appeal and report keep the cases read only. Manage keeps whatever this capability already allows.
    public func narrowed(to mode: ClubGovernanceEntryRoute.Mode) -> Self {
        switch mode {
        case .manage:
            return self
        case .appeal, .report:
            return Self(manageMembers: false, readCases: readCases, viewerIsOwner: false, activeMember: activeMember)
        }
    }
}

/// A count the server actually sent. Unknown is never stored as 0.
public enum ClubOpsGovernanceCount: Equatable {
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
    /// JSON integer >= 0 only. Numeric strings are not integers.
    public static func parse(_ value: ClubGovernanceValue) -> Self {
        if case .integer(let number) = value, number >= 0 { return .known(number) }
        return .unknown
    }
}

public struct ClubOpsGovernanceCounts: Equatable {
    public var bans: ClubOpsGovernanceCount?
    public var cases: ClubOpsGovernanceCount?
    public var members: ClubOpsGovernanceCount?
    /// Known absence is 0. A missing appeal fact stays nil. An unknown token is an em dash.
    public var activeBan: ClubOpsGovernanceCount?
    public init(bans: ClubOpsGovernanceCount? = nil, cases: ClubOpsGovernanceCount? = nil, members: ClubOpsGovernanceCount? = nil, activeBan: ClubOpsGovernanceCount? = nil) {
        self.bans = bans
        self.cases = cases
        self.members = members
        self.activeBan = activeBan
    }
}

public struct ClubOpsGovernancePage: Equatable {
    public enum Phase: Equatable {
        case loading
        case empty
        case error(ClubGovernanceFailure)
        case unknown
        case ready
    }
    public static let unknownDisplay = ClubOpsGovernanceCount.unknownDisplay
    public static let bansRead = ClubGovernanceRead.bans
    public static let casesRead = ClubGovernanceRead.cases
    public static let membersRead = ClubGovernanceRead.members
    public static let includedInPlayerFirstEntry = false
    public static let routeMarkedLive = false
    public static let performsWrites = false
    public enum Copy {
        public static let loading = "clubOpsGov.page.loading"
        public static let empty = "clubOpsGov.page.empty"
        public static let error = "clubOpsGov.failed"
        public static let unknown = "clubOpsGov.page.unknown"
        public static let retry = "clubOpsGov.retry"
        public static let bansEmpty = "clubOpsGov.bans.empty"
        public static let casesEmpty = "clubOpsGov.cases.empty"
        public static let membersEmpty = "clubOpsGov.members.empty"
        public static let appealEmpty = "clubOpsGov.appeal.empty"
        public static let deniedTitle = "clubOpsGov.denied.title"
        public static let deniedBody = "clubOpsGov.denied.body"
        public static let banCount = "clubOpsGov.count.bans"
        public static let caseCount = "clubOpsGov.count.cases"
        public static let memberCount = "clubOpsGov.count.members"
        public static let activeBanCount = "clubOpsGov.count.activeBan"
    }
    public enum Accessibility {
        public static let loading = "clubOpsGov.page.loading"
        public static let empty = "clubOpsGov.page.empty"
        public static let error = "clubOpsGov.page.error"
        public static let unknown = "clubOpsGov.page.unknown"
        public static let banCount = "clubOpsGov.count.bans"
        public static let caseCount = "clubOpsGov.count.cases"
        public static let memberCount = "clubOpsGov.count.members"
        public static let activeBanCount = "clubOpsGov.count.activeBan"
    }
    public let clientCapabilityPresent: Bool
    public let serverFactPresent: Bool
    public let phase: Phase?
    public let counts: ClubOpsGovernanceCounts?
    public let bans: ClubOpsBanList?
    public let cases: ClubOpsCaseList?
    public let members: ClubOpsGovernanceMembers?
    public var hidden: Bool { !(clientCapabilityPresent && serverFactPresent) }
    public var canAppeal: Bool { cases?.canAppeal == true }
    public var canReport: Bool { cases?.canReport == true }

    public static func reads(for capability: ClubOpsGovernanceCapability) -> [ClubGovernanceRead] {
        var operations: [ClubGovernanceRead] = []
        if capability.manageMembers {
            operations.append(bansRead)
            operations.append(membersRead)
        }
        if capability.readCases { operations.append(casesRead) }
        return operations
    }

    public static func loading(clientCapabilityPresent: Bool) -> Self {
        Self(clientCapabilityPresent: clientCapabilityPresent, serverFactPresent: false, phase: .loading, counts: nil, bans: nil, cases: nil, members: nil)
    }

    /// Projects returned documents. Does not invent rows. A missing capability returns a hidden page.
    public static func project(bans: ClubGovernanceValue? = nil, cases: ClubGovernanceValue? = nil, members: ClubGovernanceValue? = nil, scope: ClubGovernanceScope, capability: ClubOpsGovernanceCapability, includeBans: Bool? = nil, includeMembers: Bool? = nil, includeCases: Bool? = nil) -> Self {
        assemble(bans: bans, cases: cases, members: members, scope: scope, capability: capability, permissions: makePermissions(scope: scope, capability: capability), includeBans: includeBans, includeMembers: includeMembers, includeCases: includeCases)
    }

    /// Reads the existing governance contracts. A missing capability does not call the reader. Nothing is sent.
    @MainActor public static func load(access: any ClubGovernanceAccess, scope: ClubGovernanceScope, capability: ClubOpsGovernanceCapability) async -> Self {
        guard capability.granted else { return .loading(clientCapabilityPresent: false) }
        var bans: ClubGovernanceValue?
        var members: ClubGovernanceValue?
        var cases: ClubGovernanceValue?
        var acceptedPermissions: ClubGovernancePermissions?
        var failure: ClubGovernanceFailure?
        func accept(_ snapshot: ClubGovernanceSnapshot, into store: inout ClubGovernanceValue?) {
            if acceptedPermissions == nil { acceptedPermissions = snapshot.permissions }
            store = snapshot.value
        }
        if capability.manageMembers, failure == nil {
            switch await fetch(access, .bans, scope) {
            case .cancelled: return .loading(clientCapabilityPresent: true)
            case .denied: break
            case .failed(let error): failure = error
            case .value(let snapshot): accept(snapshot, into: &bans)
            }
        }
        if capability.manageMembers, failure == nil {
            switch await fetch(access, .members, scope) {
            case .cancelled: return .loading(clientCapabilityPresent: true)
            case .denied: break
            case .failed(let error): failure = error
            case .value(let snapshot): accept(snapshot, into: &members)
            }
        }
        if capability.readCases, failure == nil {
            switch await fetch(access, .cases, scope) {
            case .cancelled: return .loading(clientCapabilityPresent: true)
            case .denied: break
            case .failed(let error): failure = error
            case .value(let snapshot): accept(snapshot, into: &cases)
            }
        }
        if let failure { return revealed(.error(failure)) }
        if bans == nil, members == nil, cases == nil { return .loading(clientCapabilityPresent: false) }
        return assemble(bans: bans, cases: cases, members: members, scope: scope, capability: capability, permissions: acceptedPermissions, includeBans: bans != nil, includeMembers: members != nil, includeCases: cases != nil)
    }

    private static func assemble(bans: ClubGovernanceValue?, cases: ClubGovernanceValue?, members: ClubGovernanceValue?, scope: ClubGovernanceScope, capability: ClubOpsGovernanceCapability, permissions: ClubGovernancePermissions?, includeBans: Bool?, includeMembers: Bool?, includeCases: Bool?) -> Self {
        let showBans = includeBans ?? capability.manageMembers
        let showMembers = includeMembers ?? capability.manageMembers
        let showCases = includeCases ?? capability.readCases
        guard capability.granted, showBans || showMembers || showCases else { return .loading(clientCapabilityPresent: false) }
        guard let clubID = scope.clubID, clubID > 0 else { return revealed(.error(.invalidRequest)) }
        var counts = ClubOpsGovernanceCounts()
        var banList: ClubOpsBanList?
        var caseList: ClubOpsCaseList?
        var memberList: ClubOpsGovernanceMembers?
        var failed: ClubGovernanceFailure?
        var unknown = false
        var parsed = false
        var content = false
        if showBans {
            let taken = take(bans) { value in
                try ClubOpsBanList(snapshot: .init(operation: .bans, scope: scope, permissions: permissions, value: value))
            } count: { $0.rows.count }
            apply(taken, failed: &failed, unknown: &unknown, parsed: &parsed, content: &content, assignCount: { counts.bans = $0 }, assignBody: { banList = $0 })
        }
        if showMembers {
            let taken = take(members) { value in
                try ClubOpsGovernanceMembers(snapshot: .init(operation: .members, scope: scope, permissions: permissions, value: value))
            } count: { $0.members.count }
            apply(taken, failed: &failed, unknown: &unknown, parsed: &parsed, content: &content, assignCount: { counts.members = $0 }, assignBody: { memberList = $0 })
        }
        if showCases {
            let taken = casesTake(cases, scope: scope, permissions: permissions)
            apply(taken.outcome, failed: &failed, unknown: &unknown, parsed: &parsed, content: &content, assignCount: { counts.cases = $0 }, assignBody: { caseList = $0 })
            if failed == nil {
                counts.activeBan = taken.active
                if taken.active?.literal == nil, taken.active != nil { unknown = true }
                if caseList?.canAppeal == true { content = true }
                if let number = taken.active?.literal, number > 0 { content = true }
            }
        }
        if let failed { return revealed(.error(failed)) }
        if unknown { return revealed(.unknown, counts: counts, bans: banList, cases: caseList, members: memberList) }
        if parsed && content { return revealed(.ready, counts: counts, bans: banList, cases: caseList, members: memberList) }
        if parsed { return revealed(.empty, counts: counts, bans: banList, cases: caseList, members: memberList) }
        return .loading(clientCapabilityPresent: false)
    }

    private enum SectionTake<Body> {
        case parsed(ClubOpsGovernanceCount, Body?)
        case unknown(ClubOpsGovernanceCount)
        case failed(ClubGovernanceFailure)
        case skipped
    }

    private static func isUnknownScalar(_ value: ClubGovernanceValue) -> Bool {
        switch value {
        case .null, .string, .decimal, .bool: return true
        case .integer(let number): return number < 0
        case .array, .object: return false
        }
    }

    private static func take<Body>(_ value: ClubGovernanceValue?, parse: (ClubGovernanceValue) throws -> Body, count: (Body) -> Int) -> SectionTake<Body> {
        guard let value else { return .unknown(.unknown) }
        if isUnknownScalar(value) { return .unknown(.parse(value)) }
        if case .integer = value {
            let parsed = ClubOpsGovernanceCount.parse(value)
            if parsed.literal == nil { return .unknown(parsed) }
            return .parsed(parsed, nil)
        }
        do {
            let body = try parse(value)
            return .parsed(.known(count(body)), body)
        } catch let failure as ClubGovernanceFailure {
            if failure == .forbidden || failure == .signedOut { return .skipped }
            return .failed(failure)
        } catch {
            return .failed(.malformed)
        }
    }

    private static func casesTake(_ value: ClubGovernanceValue?, scope: ClubGovernanceScope, permissions: ClubGovernancePermissions?) -> (outcome: SectionTake<ClubOpsCaseList>, active: ClubOpsGovernanceCount?) {
        guard let value else { return (.unknown(.unknown), .unknown) }
        if isUnknownScalar(value) { return (.unknown(.parse(value)), .unknown) }
        if case .integer = value {
            let parsed = ClubOpsGovernanceCount.parse(value)
            if parsed.literal == nil { return (.unknown(parsed), nil) }
            return (.parsed(parsed, nil), nil)
        }
        if let object = value.object {
            guard Set(object.keys) == ["data", "activeBan"] else { return (.failed(.malformed), nil) }
            let data = object["data"] ?? .null
            let ban = object["activeBan"] ?? .null
            let dataList = data.array != nil
            let banStrict = ban == .null || ban.object != nil
            if dataList && banStrict {
                // Validated below as the original document.
            } else if let rows = data.array {
                let probe = ClubGovernanceValue.object(["data": .array(rows), "activeBan": .null])
                switch list(probe, scope: scope, permissions: permissions) {
                case .failed(let failure): return (.failed(failure), nil)
                case .skipped: return (.skipped, nil)
                default:
                    let active = ClubOpsGovernanceCount.parse(ban)
                    if active.literal == nil { return (.unknown(.known(rows.count)), active) }
                    return (.parsed(.known(rows.count), nil), active)
                }
            } else if ban.object != nil {
                let probe = ClubGovernanceValue.object(["data": .array([]), "activeBan": ban])
                switch list(probe, scope: scope, permissions: permissions) {
                case .failed(let failure): return (.failed(failure), nil)
                case .skipped: return (.skipped, nil)
                case .parsed(_, let body):
                    let active = activeBanCount(body?.appeal ?? .unknown) ?? .unknown
                    let caseCount = ClubOpsGovernanceCount.parse(data)
                    if caseCount.literal == nil || active.literal == nil { return (.unknown(caseCount), active) }
                    return (.parsed(caseCount, nil), active)
                case .unknown(let count):
                    return (.unknown(count), .unknown)
                }
            } else {
                let caseCount = ClubOpsGovernanceCount.parse(data)
                let active: ClubOpsGovernanceCount = ban == .null ? .known(0) : .parse(ban)
                if caseCount.literal == nil || active.literal == nil { return (.unknown(caseCount), active) }
                return (.parsed(caseCount, nil), active)
            }
        }
        let parsed = list(value, scope: scope, permissions: permissions)
        switch parsed {
        case .parsed(_, let body): return (parsed, activeBanCount(body?.appeal ?? .unknown))
        default: return (parsed, nil)
        }
    }

    private static func list(_ value: ClubGovernanceValue, scope: ClubGovernanceScope, permissions: ClubGovernancePermissions?) -> SectionTake<ClubOpsCaseList> {
        do {
            let body = try ClubOpsCaseList(snapshot: .init(operation: .cases, scope: scope, permissions: permissions, value: value))
            return .parsed(.known(body.rows.count), body)
        } catch let failure as ClubGovernanceFailure {
            if failure == .forbidden || failure == .signedOut { return .skipped }
            return .failed(failure)
        } catch {
            return .failed(.malformed)
        }
    }

    private static func activeBanCount(_ appeal: ClubOpsAppealEligibility) -> ClubOpsGovernanceCount? {
        switch appeal {
        case .unknown: return nil
        case .none: return .known(0)
        case .ban: return .known(1)
        }
    }

    private static func apply<Body>(_ take: SectionTake<Body>, failed: inout ClubGovernanceFailure?, unknown: inout Bool, parsed: inout Bool, content: inout Bool, assignCount: (ClubOpsGovernanceCount) -> Void, assignBody: (Body?) -> Void) {
        switch take {
        case .skipped:
            break
        case .failed(let failure):
            failed = failed ?? failure
        case .unknown(let count):
            unknown = true
            assignCount(count)
        case .parsed(let count, let body):
            parsed = true
            assignCount(count)
            assignBody(body)
            if let number = count.literal, number > 0 { content = true }
        }
    }

    private static func makePermissions(scope: ClubGovernanceScope, capability: ClubOpsGovernanceCapability) -> ClubGovernancePermissions? {
        guard capability.activeMember, let clubID = scope.clubID, clubID > 0 else { return nil }
        var codes: [ClubGovernanceValue] = []
        if capability.manageMembers, let permission = ClubGovernanceRead.bans.permission { codes.append(.string(permission)) }
        let roles = capability.viewerIsOwner ? ["CLUB_OWNER"] : ["CLUB_OPERATOR"]
        let value = ClubGovernanceValue.object([
            "active": .bool(true),
            "club": .object(["id": .integer(clubID)]),
            "roleCodes": .array(roles.map(ClubGovernanceValue.string)),
            "permissions": .array(codes),
            "canManageRoles": .bool(false)
        ])
        return try? ClubGovernancePermissions(value: value, scope: scope)
    }

    private enum Fetch {
        case value(ClubGovernanceSnapshot)
        case denied
        case failed(ClubGovernanceFailure)
        case cancelled
    }

    @MainActor private static func fetch(_ access: any ClubGovernanceAccess, _ operation: ClubGovernanceRead, _ scope: ClubGovernanceScope) async -> Fetch {
        do {
            let snapshot = try await access.read(operation, scope: scope, options: [:])
            guard snapshot.operation == operation, snapshot.scope.clubID == scope.clubID else { return .failed(.targetChanged) }
            return .value(snapshot)
        } catch let failure as ClubGovernanceFailure {
            if failure == .forbidden || failure == .signedOut { return .denied }
            return .failed(failure)
        } catch is CancellationError {
            return .cancelled
        } catch {
            return .failed(.unknown(message: nil))
        }
    }

    private init(clientCapabilityPresent: Bool, serverFactPresent: Bool, phase: Phase?, counts: ClubOpsGovernanceCounts?, bans: ClubOpsBanList?, cases: ClubOpsCaseList?, members: ClubOpsGovernanceMembers?) {
        self.clientCapabilityPresent = clientCapabilityPresent
        self.serverFactPresent = serverFactPresent
        let revealed = clientCapabilityPresent && serverFactPresent
        if revealed {
            switch phase {
            case .some(.loading), .none: self.phase = .unknown
            case .some(.empty), .some(.error), .some(.unknown), .some(.ready): self.phase = phase
            }
        } else if clientCapabilityPresent, case .loading? = phase {
            self.phase = .loading
        } else {
            self.phase = nil
        }
        switch self.phase {
        case .some(.empty), .some(.unknown), .some(.ready):
            self.counts = counts
            self.bans = bans
            self.cases = cases
            self.members = members
        case .some(.loading), .some(.error), .none:
            self.counts = nil
            self.bans = nil
            self.cases = nil
            self.members = nil
        }
    }

    private static func revealed(_ phase: Phase, counts: ClubOpsGovernanceCounts? = nil, bans: ClubOpsBanList? = nil, cases: ClubOpsCaseList? = nil, members: ClubOpsGovernanceMembers? = nil) -> Self {
        Self(clientCapabilityPresent: true, serverFactPresent: true, phase: phase, counts: counts, bans: bans, cases: cases, members: members)
    }
}

#if DEBUG
/// Offline governance documents. Compiled only in DEBUG. Not a live account.
public enum ClubOpsGovernancePageFixtureData {
    public static let scope = ClubGovernanceScope(clubID: 81)
    public static var bans: ClubGovernanceValue { ClubGovernanceFixtures.value(.bans, scope: scope) }
    public static var cases: ClubGovernanceValue { ClubGovernanceFixtures.value(.cases, scope: scope) }
    public static var members: ClubGovernanceValue { ClubGovernanceFixtures.value(.members, scope: scope) }
    public static var emptyBans: ClubGovernanceValue { .array([]) }
    public static var emptyMembers: ClubGovernanceValue { .array([]) }
    public static var emptyCases: ClubGovernanceValue { .object(["data": .array([]), "activeBan": .null]) }
    public static var unknownBans: ClubGovernanceValue { .string("UNKNOWN") }
    public static var numericStringZero: ClubGovernanceValue { .string("0") }
    public static var literalZero: ClubGovernanceValue { .integer(0) }
}
#endif
