import Foundation

/// Mirrors `onLoad(options)` of mini-program `pages/club/governance`: a deep link or in-app
/// route (`clubId`, `mode`, `targetType`, `targetId`, `targetMemberId`, `targetName`, `memberId`)
/// resolves to exactly one of manage / appeal / report, or a typed error shown with retry-less copy.
public struct ClubGovernanceEntryRoute: Equatable, Sendable {
    public enum ReportTargetType: String, Equatable, Sendable { case club = "CLUB", activity = "ACTIVITY", member = "MEMBER" }
    public enum Mode: Equatable, Sendable {
        case manage(focusMemberID: Int?)
        case appeal
        case report(type: ReportTargetType, targetID: Int, label: String)
    }
    public enum Failure: Error, Equatable, Sendable { case missingClub, invalidReportTarget }

    public let clubID: Int
    public let mode: Mode
    public init(clubID: Int, mode: Mode) { self.clubID = clubID; self.mode = mode }

    public static func positiveID(_ value: String?) -> Int? {
        guard let value, let parsed = Int(value.trimmingCharacters(in: .whitespacesAndNewlines)), parsed > 0 else { return nil }
        return parsed
    }
    public static func targetText(_ type: ReportTargetType, chinese: Bool) -> String {
        switch type {
        case .club: return chinese ? "俱乐部" : "Club"
        case .activity: return chinese ? "活动" : "Activity"
        case .member: return chinese ? "成员" : "Member"
        }
    }
    /// 展示名 only: whitespace collapsed, at most 40 characters; the submit key stays type + id.
    public static func displayName(_ value: String?) -> String {
        let collapsed = (value ?? "").split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        return String(collapsed.prefix(40))
    }

    public static func resolve(_ options: [String: String], chinese: Bool = true) -> Result<ClubGovernanceEntryRoute, Failure> {
        guard let clubID = positiveID(options["clubId"]) else { return .failure(.missingClub) }
        switch options["mode"] {
        case "appeal":
            return .success(.init(clubID: clubID, mode: .appeal))
        case "report":
            let legacyMember = positiveID(options["targetMemberId"])
            var rawType = (options["targetType"] ?? "").uppercased()
            var targetID = positiveID(options["targetId"])
            if rawType.isEmpty, legacyMember != nil { rawType = "MEMBER" }
            if targetID == nil, let legacyMember { targetID = legacyMember }
            if rawType == "CLUB", targetID == nil { targetID = clubID }
            guard let type = ReportTargetType(rawValue: rawType), let targetID else { return .failure(.invalidReportTarget) }
            let name = displayName(options["targetName"])
            let typeText = targetText(type, chinese: chinese)
            let label = name.isEmpty ? typeText : (chinese ? typeText + "「" + name + "」" : typeText + " \u{201C}" + name + "\u{201D}")
            return .success(.init(clubID: clubID, mode: .report(type: type, targetID: targetID, label: label)))
        default:
            return .success(.init(clubID: clubID, mode: .manage(focusMemberID: positiveID(options["memberId"]))))
        }
    }
}
