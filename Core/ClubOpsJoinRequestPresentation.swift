import Foundation

/// Mini-program pages/club/join-requests presentation and the optional reject reason
/// (`reviewReason`, backend `ApiClubController.reviewJoinRequest`: trimmed, at most 500 UTF-16 units).
public enum ClubOpsJoinReviewReason {
    public static let maximumUTF16Count = 500
    /// Trimmed reason, or nil when blank (the mini-program sends no `reviewReason` key then).
    public static func normalized(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
    public static func isValid(_ raw: String) -> Bool {
        (normalized(raw)?.utf16.count ?? 0) <= maximumUTF16Count
    }
    /// A dispatchable value: nil, or already trimmed, non-empty and within the limit.
    public static func isDispatchable(_ reason: String?) -> Bool {
        guard let reason else { return true }
        return normalized(reason) == reason && reason.utf16.count <= maximumUTF16Count
    }
    public static func count(_ raw: String) -> Int { normalized(raw)?.utf16.count ?? 0 }
}

/// Page-ready binding for the existing join-request review contract.
/// Does not add a route. `api/club/join-requests/apply` stays hidden.
/// A missing review capability, a viewer who cannot govern, a player-first entry,
/// or a server denial stays hidden. Unknown counts are an em dash, never 0.
public enum ClubJoinRequestsPageReady {
    public static let routes = [
        "api/club/join-requests",
        ClubManagementAction.approve.path,
        ClubManagementAction.reject.path,
    ]
    public static let hiddenApplyRoute = "api/club/join-requests/apply"
    public static let revealsApplyRoute = false
    public static let unknownCountText = "\u{2014}"

    public struct Visibility: Equatable {
        public let reviewCapabilityPresent: Bool
        public let canGovern: Bool
        public let playerFirstEntry: Bool
        public init(reviewCapabilityPresent: Bool, canGovern: Bool, playerFirstEntry: Bool) {
            self.reviewCapabilityPresent = reviewCapabilityPresent
            self.canGovern = canGovern
            self.playerFirstEntry = playerFirstEntry
        }
        public var shown: Bool { reviewCapabilityPresent && canGovern && !playerFirstEntry }
    }

    public enum Phase: Equatable {
        case hidden, loading, empty, error, unknown, ready
    }

    public static func countText(_ count: Int?) -> String {
        count.map(String.init) ?? unknownCountText
    }

    /// Nil hides the number. A shown unknown is an em dash. A literal 0 stays "0".
    public static func pendingCountText(visibility: Visibility, count: Int?) -> String? {
        guard visibility.shown else { return nil }
        return countText(count)
    }

    public static func phase(visibility: Visibility, loading: Bool, failed: Bool, denied: Bool,
                             list: [ClubManagementRequest]?) -> Phase {
        guard visibility.shown, !denied else { return .hidden }
        guard let list else {
            if loading { return .loading }
            if failed { return .error }
            return .unknown
        }
        return list.isEmpty ? .empty : .ready
    }
}

public enum ClubOpsJoinRequestPresentation {
    /// `N 条待审 · 可直接通过或拒绝`; zero pending shows only the action line (CU-C-96).
    public static func introPendingCount(_ count: Int) -> Int? { count > 0 ? count : nil }
    /// Nil for a missing/blank nickname; the page then shows its "城瘾玩家" fallback.
    public static func displayName(_ nickname: String?) -> String? {
        guard let nickname, !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return nickname
    }
    /// `“message”` after one display-text decode; nil when the applicant wrote nothing.
    public static func quotedMessage(_ message: String?) -> String? {
        guard let message, !message.isEmpty else { return nil }
        return "\u{201C}" + decodeDisplayText(message) + "\u{201D}"
    }
    private static let entity = try! NSRegularExpression(pattern: "&(?:(lt|gt|amp|quot|#39)|#0*(60|62|38|34|39)|#[xX]0*(3[cCeE]|26|22|27));")
    /// Single pass over the five server-filter entities only (utils/display-text.js); `&amp;lt;` becomes `&lt;`.
    public static func decodeDisplayText(_ value: String) -> String {
        guard value.contains("&") else { return value }
        let source = value as NSString
        var result = "", cursor = 0
        for match in entity.matches(in: value, range: NSRange(location: 0, length: source.length)) {
            result += source.substring(with: NSRange(location: cursor, length: match.range.location - cursor))
            let token = source.substring(with: match.range).lowercased()
            let replacement: String
            switch token {
            case "&lt;": replacement = "<"
            case "&gt;": replacement = ">"
            case "&amp;": replacement = "&"
            case "&quot;": replacement = "\""
            case "&#39;": replacement = "'"
            default:
                let digits = token.dropFirst(2).dropLast()
                let code = digits.hasPrefix("x") ? Int(digits.dropFirst(), radix: 16) : Int(digits)
                replacement = code.flatMap { Unicode.Scalar(UInt32($0)) }.map { String(Character($0)) } ?? source.substring(with: match.range)
            }
            result += replacement
            cursor = match.range.location + match.range.length
        }
        result += source.substring(from: cursor)
        return result
    }
}
