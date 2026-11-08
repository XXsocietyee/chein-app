import Foundation

/// club/governance `mode=report` parity: the target card (type + optional display name), the
/// page title and the per-mode "reason required" copy keys. Display only; submission still
/// depends on the immutable targetType/targetId anchors.
public enum ClubGovernanceReportPort {
    public static let maximumNameLength = 40

    /// Localization key suffix for the target type (CLUB / ACTIVITY / MEMBER; anything else is MEMBER like the mini-program).
    public static func typeKey(_ targetType: String?) -> String {
        switch targetType { case "CLUB": return "CLUB"; case "ACTIVITY": return "ACTIVITY"; default: return "MEMBER" }
    }

    /// Mini `entryName`: collapse whitespace, trim, keep at most 40 characters.
    public static func displayName(_ raw: String?) -> String? {
        let collapsed = (raw ?? "").split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        let clipped = String(collapsed.prefix(maximumNameLength))
        return clipped.isEmpty ? nil : clipped
    }

    /// `活动「夜跑 · 09-24」`-style label pieces: the localized type is composed by the view; this
    /// returns the quoted name segment (never an internal id).
    public static func quotedName(_ raw: String?) -> String? { displayName(raw).map { "「\($0)」" } }

    public enum ReasonMode: String, CaseIterable { case ban, transfer, report, appeal }

    /// Localization key of the inline "required" hint for a mode (mirrors 请填写封禁原因/交接原因/事实说明).
    public static func reasonRequiredKey(_ mode: ReasonMode) -> String { "clubOpsGov.reasonRequired." + mode.rawValue }

    public static func reasonIsValid(_ raw: String) -> Bool { !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
}
