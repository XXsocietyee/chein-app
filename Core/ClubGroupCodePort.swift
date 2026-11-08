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
