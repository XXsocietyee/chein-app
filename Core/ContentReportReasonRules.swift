import Foundation

/// Mini-program `utils/content-report.js` + `utils/community-report-sheet.js` for the topic / template /
/// personal-template report entries: the reason labels come from the community policy
/// (`api/v1/community/capabilities` -> `reporting.reasons[].label`), the user picks one in a sheet, and the
/// write sends only `{ id, reason: <label> }`. Pure logic; no I/O.
public enum ContentReportReasonRules {
    public static let topicWritePath = "api/topic/report"
    public static let templateWritePath = "api/template/report"
    public static let personalTemplateWritePath = "api/template/personal-report"
    public static let policyPath = "api/v1/community/capabilities"

    /// Source `reasonLabels`: only a 200 reply with a `reporting.reasons` array yields labels; each label is
    /// trimmed and blanks are dropped (not an error). No usable label -> the entry reports "unavailable".
    public static func labels(code: Int?, reasons: [[String: Any]]?) -> [String] {
        guard code == 200, let reasons else { return [] }
        return reasons.compactMap { row in
            guard let label = row["label"] as? String else { return nil }
            let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        }
    }

    /// Form fields of the three writes: exactly `id` and `reason`.
    public static func fields(id: String, reason: String) -> [String: String] { ["id": id, "reason": reason] }

    public enum SheetError: Error, Equatable {
        /// Source code 409: a reason sheet is already open for this page.
        case alreadyOpen
        /// Source code 499: the page was torn down or the task aborted; silent for the user.
        case cancelled
        /// Source code 500: the sheet returned an index outside the offered list, or could not be shown.
        case invalidSelection
        public var sourceCode: Int {
            switch self { case .alreadyOpen: return 409; case .cancelled: return 499; case .invalidSelection: return 500 }
        }
        /// Cancellation never shows a toast.
        public var isSilent: Bool { self == .cancelled }
    }

    /// Source `community-report-sheet.js` as a value type: one pending selection per page.
    public struct Sheet: Equatable {
        public private(set) var offeredCount: Int?
        public init() {}
        public var isOpen: Bool { offeredCount != nil }

        public mutating func open(count: Int, pageUnloaded: Bool, aborted: Bool) -> SheetError? {
            if isOpen { return .alreadyOpen }
            if pageUnloaded || aborted { return .cancelled }
            offeredCount = count
            return nil
        }
        /// Accepts exactly one integer index in `0..<count`; any other value closes the sheet as an error.
        /// Selecting with no sheet open is ignored (`nil` result, state unchanged).
        public mutating func select(_ index: Int?) -> Result<Int, SheetError>? {
            guard let count = offeredCount else { return nil }
            offeredCount = nil
            guard let index, index >= 0, index < count else { return .failure(.invalidSelection) }
            return .success(index)
        }
        public mutating func cancel() -> SheetError? {
            guard isOpen else { return nil }
            offeredCount = nil
            return .cancelled
        }
    }

    /// Source `run`: a second tap while a report is in flight, or an empty id, does nothing.
    public struct Run: Equatable {
        public private(set) var reporting = false
        public init() {}
        public mutating func begin(id: String?) -> Bool {
            guard let id, !id.isEmpty, !reporting else { return false }
            reporting = true
            return true
        }
        public mutating func finish() { reporting = false }
    }

    public struct Outcome: Equatable {
        public let accepted: Bool
        /// The server's own words, shown verbatim when present; otherwise the caller's localized default.
        public let serverMessage: String?
    }

    /// Source write `success`: code 200 (number or "200") is accepted; any other answer is a failure whose
    /// server message, if any, is shown as is.
    public static func outcome(code: Int?, message: String?) -> Outcome {
        let text = message?.isEmpty == false ? message : nil
        return Outcome(accepted: code == 200, serverMessage: text)
    }
}
