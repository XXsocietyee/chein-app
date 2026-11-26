import Foundation

/// Source pages/merchant/aftercare/detail/view-model.js (listRowView, groupAftercareItems,
/// buildAftercareTimeline, sourceTypeText, refundPolicyText) and aftercare/index.wxml empty states.
/// Presentation only: it reads the already validated list rows and detail progress and never
/// infers a refund outcome from a merchant opinion.
public enum MerchantAftercareParity {
    public enum Tone: String, Equatable { case neutral, warning, success, danger }

    /// One list row: nickname first (then refund number, then #id), "HH:mm · status", takeover tag, activity, amount.
    public struct ListRow: Equatable, Identifiable {
        public let id: String
        public let title: String
        public let timeText: String?
        public let statusKey: String
        public let tone: Tone
        public let isTakenOver: Bool
        public let activityTitle: String?
        /// Cents of the refund amount; nil renders the muted "amount to be confirmed".
        public let amountCents: Int?
        public let amountDisplay: String?
        /// yyyy-MM-dd of the request time in the source civil zone, or nil when unknown.
        public let dayKey: String?
        /// Platform-handled 人工退款工单 (read-only; no amount, no merchant actions).
        public let isManualCase: Bool

        public init?(_ record: MerchantBusinessRecord) {
            guard record.kind == .refund else { return nil }
            let fields = record.fields
            func text(_ key: String) -> String? {
                guard let value = fields.mbText(key)?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
                return value
            }
            id = record.id
            isManualCase = record.isManualCase
            let caseNumber = record.isManualCase ? String(record.id.dropFirst(MerchantBusinessRecord.manualCasePrefix.count)) : nil
            // Manual rows: "#<caseId>"; the view prefixes the localized 人工退款工单 label.
            title = caseNumber.map { "#" + $0 } ?? text("customerNickname") ?? text("refundNo") ?? "#\(record.id)"
            let minute = text("createTime").map { String($0.replacingOccurrences(of: "T", with: " ").prefix(16)) }
            if let minute, minute.range(of: #"^\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil {
                dayKey = String(minute.prefix(10))
            } else { dayKey = nil }
            if let minute, minute.range(of: #"^\d{4}-\d{2}-\d{2} \d{2}:\d{2}$"#, options: .regularExpression) != nil {
                timeText = String(minute.suffix(5))
            } else { timeText = nil }
            let processing = text("processing") ?? "UNKNOWN"
            if record.isManualCase {
                statusKey = "merchantOps.aftercare.manualCase.status." + processing
                tone = ["NO_REFUND", "MANUAL_REFUND_EVIDENCE_VERIFIED"].contains(processing) ? .neutral : .warning
            }
            else if text("bucket") == "PENDING" { statusKey = "merchantOps.aftercare.status.awaitingResponse"; tone = .warning }
            else if fields["refunded"]?.bool == true { statusKey = "merchantOps.aftercare.status.returned"; tone = .success }
            else { statusKey = "merchantOps.aftercare.processing." + (MerchantAftercareProgress.Processing(rawValue: processing)?.rawValue ?? "UNKNOWN"); tone = .neutral }
            isTakenOver = text("platformTakeoverAt") != nil
            activityTitle = text("activityTitle")
            if let money = try? MerchantBusinessMoney(fields["refundAmount"]), let raw = money.raw,
               let cents = MerchantAftercareParity.exactDisplayCents(raw) {
                amountCents = cents
                amountDisplay = MerchantAftercareParity.yuan(cents)
            } else { amountCents = nil; amountDisplay = nil }
        }
    }

    public enum DayLabel: Equatable { case today, yesterday, sameYear(month: Int, day: Int), otherYear(year: Int, month: Int, day: Int), unknown }
    public struct DayGroup: Equatable, Identifiable {
        public let id: String
        public let label: DayLabel
        public let rows: [ListRow]
        /// Present only when every amount in the group is known (source: no undercounted totals).
        public let total: String?
    }

    /// Groups keep server order. `allowTotals` is false while searching or when the last group may be cut off.
    public static func groups(_ rows: [ListRow], today: DateComponents, allowTotals: Bool = true, lastGroupComplete: Bool = true) -> [DayGroup] {
        var order: [String] = [], buckets: [String: [ListRow]] = [:]
        for row in rows {
            let key = row.dayKey ?? ""
            if buckets[key] == nil { order.append(key) }
            buckets[key, default: []].append(row)
        }
        let todayKey = dayKey(today), yesterdayKey = dayKey(shift(today, by: -1))
        return order.enumerated().map { index, key in
            let rows = buckets[key] ?? []
            let truncated = index == order.count - 1 && !lastGroupComplete
            let total = allowTotals && !truncated ? checkedTotal(rows).map(yuan) : nil
            return DayGroup(id: key.isEmpty ? "unknown" : key, label: label(key, todayKey: todayKey, yesterdayKey: yesterdayKey, year: today.year ?? 0),
                            rows: rows, total: total)
        }
    }
    /// The group a row opens, so a flat list can show the day header above its first row only.
    public static func leadingGroup(rowID: String, in rows: [ListRow], today: DateComponents, allowTotals: Bool, lastGroupComplete: Bool) -> DayGroup? {
        groups(rows, today: today, allowTotals: allowTotals, lastGroupComplete: lastGroupComplete).first { $0.rows.first?.id == rowID }
    }
    static func label(_ key: String, todayKey: String, yesterdayKey: String, year: Int) -> DayLabel {
        let parts = key.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return .unknown }
        if key == todayKey { return .today }
        if key == yesterdayKey { return .yesterday }
        return parts[0] == year ? .sameYear(month: parts[1], day: parts[2]) : .otherYear(year: parts[0], month: parts[1], day: parts[2])
    }
    static func dayKey(_ value: DateComponents) -> String {
        String(format: "%04d-%02d-%02d", value.year ?? 0, value.month ?? 0, value.day ?? 0)
    }
    static func shift(_ value: DateComponents, by days: Int) -> DateComponents {
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = TimeZone(identifier: "UTC")!
        guard let date = calendar.date(from: DateComponents(year: value.year, month: value.month, day: value.day)),
              let moved = calendar.date(byAdding: .day, value: days, to: date) else { return value }
        return calendar.dateComponents([.year, .month, .day], from: moved)
    }
    // This is a display bound, not a refund/eligibility limit. Preserve the source
    // rounding rule, but never truncate an unrepresentable Decimal into a signed Int.
    private static func exactDisplayCents(_ raw: String) -> Int? {
        guard let value = Decimal(string: raw, locale: Locale(identifier: "en_US_POSIX")),
              !value.isNaN, value >= 0 else { return nil }
        var cents = value * 100, rounded = Decimal()
        guard !cents.isNaN else { return nil }
        NSDecimalRound(&rounded, &cents, 0, .plain)
        guard !rounded.isNaN,
              let exact = Int(NSDecimalNumber(decimal: rounded).stringValue), exact >= 0,
              Decimal(exact) == rounded else { return nil }
        return exact
    }
    private static func checkedTotal(_ rows: [ListRow]) -> Int? {
        var total = 0
        for row in rows {
            guard let cents = row.amountCents else { return nil }
            let addition = total.addingReportingOverflow(cents)
            guard !addition.overflow else { return nil }
            total = addition.partialValue
        }
        return total
    }
    static func yuan(_ cents: Int) -> String {
        let sign = cents < 0 ? "-" : ""
        let value = cents.magnitude
        return "\(sign)¥\(value / 100).\(String(format: "%02d", Int(value % 100)))"
    }

    /// Source aftercare/index.wxml per-tab empty copy.
    public static func emptyKey(_ bucket: String) -> String {
        switch bucket {
        case "PENDING": return "merchantOps.aftercare.empty.PENDING"
        case "PROCESSING": return "merchantOps.aftercare.empty.PROCESSING"
        default: return "merchantOps.aftercare.empty.COMPLETED"
        }
    }

    /// Source sourceTypeText: registration refunds have their own name, anything else is a generic request.
    public static func sourceKey(_ sourceType: String?) -> String {
        sourceType == "registration" || sourceType == "REGISTRATION" ? "merchantOps.aftercare.source.registration" : "merchantOps.aftercare.source.other"
    }
    /// Source refundPolicyText.
    public static func policyKey(_ code: String?) -> String {
        guard let code else { return "merchantOps.aftercare.policy.unknown" }
        return code == "EXPLORE_END_100_0" ? "merchantOps.aftercare.policy.exploreEnd" : "merchantOps.aftercare.policy.snapshot"
    }

    /// Source detail/index.js: why the respond pills are hidden.
    public enum ReadOnlyReason: Equatable { case roleViewOnly, platformClosed }
    public static func readOnlyReason(canRespondPermission: Bool, detailCanRespond: Bool) -> ReadOnlyReason? {
        if !canRespondPermission { return .roleViewOnly }
        if !detailCanRespond { return .platformClosed }
        return nil
    }

    /// Source buildAftercareTimeline future nodes after the recorded facts. They carry no time and no ETA.
    public struct PlatformStep: Equatable {
        public enum State: String, Equatable { case done, doing, todo, rejected }
        public let titleKey: String
        public let hintKey: String?
        public let state: State
    }
    public static func platformSteps(_ processing: MerchantAftercareProgress.Processing) -> [PlatformStep] {
        let title = "merchantOps.aftercare.processing." + processing.rawValue, hint = "merchantOps.aftercare.processingHint." + processing.rawValue
        switch processing {
        case .waiting:
            return [.init(titleKey: title, hintKey: hint, state: .doing),
                    .init(titleKey: "merchantOps.aftercare.step.funds", hintKey: "merchantOps.aftercare.funds.unconfirmed", state: .todo)]
        case .rejected:
            return [.init(titleKey: title, hintKey: hint, state: .rejected)]
        case .refunded:
            return [.init(titleKey: "merchantOps.aftercare.step.approved", hintKey: nil, state: .done),
                    .init(titleKey: title, hintKey: hint, state: .done)]
        case .refunding, .manualPending, .manualReview:
            return [.init(titleKey: "merchantOps.aftercare.step.approved", hintKey: nil, state: .done),
                    .init(titleKey: title, hintKey: hint, state: .doing)]
        case .unknown:
            return [.init(titleKey: title, hintKey: hint, state: .todo)]
        }
    }
}

// MARK: - Aftercare response draft (appended: new Core files need a regenerated project, which this worker may not edit)

/// Source pages/merchant/aftercare/detail/view-model.js `buildResponseDraft` and `RESPONSE_FLOW`.
/// Pure validation and copy keys: it sends nothing. The write itself stays behind
/// `MerchantBusinessMutation.aftercare` and the injected `MerchantBusinessService` transport.
public enum MerchantAftercareResponseIssue: String, Equatable {
    case decisionRequired, contentTooLong, reasonRequired, evidenceInvalid, evidenceRequired
    /// Key in the MerchantOps string table (English + Simplified Chinese).
    public var messageKey: String { "merchantOps.aftercare.respond.issue." + rawValue }
}

public struct MerchantAftercareResponseDraft: Equatable {
    public var decision: MerchantAftercareDecision?
    public var content: String
    /// One evidence object key at most, exactly like the source (a single upload per response).
    public var evidenceKey: String?

    public init(decision: MerchantAftercareDecision?, content: String = "", evidenceKey: String? = nil) {
        self.decision = decision; self.content = content; self.evidenceKey = evidenceKey
    }

    static func isEvidenceObjectKey(_ value: String) -> Bool {
        value.range(of: #"^upload/merchant-aftercare-evidence/[0-9a-f]{32}\.(?:jpe?g|png|gif)$"#, options: .regularExpression) != nil
    }

    /// First blocking issue, in the same order as the source. nil means the draft may be reviewed.
    public var issue: MerchantAftercareResponseIssue? {
        guard let decision else { return .decisionRequired }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.utf16.count > 500 { return .contentTooLong }
        if decision == .reject && trimmed.isEmpty { return .reasonRequired }
        let evidence = evidenceKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let evidence, !evidence.isEmpty, !Self.isEvidenceObjectKey(evidence) { return .evidenceInvalid }
        if decision == .evidence && (evidence ?? "").isEmpty { return .evidenceRequired }
        return nil
    }
    public var isValid: Bool { issue == nil }

    /// The mutation to hand to the confirm-then-act coordinator; nil while the draft is invalid.
    public func mutation(refund: MerchantRefundID) -> MerchantBusinessMutation? {
        guard issue == nil, let decision else { return nil }
        let evidence = evidenceKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .aftercare(refund: refund, decision: decision, content: content,
                          evidenceKey: (evidence ?? "").isEmpty ? nil : evidence)
    }
}

public enum MerchantAftercareResponseGuide {
    /// Decisions the server allowed, in the source pill order (agree, reject, evidence). Unknown
    /// raw values are dropped, never guessed.
    public static func visibleDecisions(allowed: [String], canRespond: Bool) -> [MerchantAftercareDecision] {
        guard canRespond else { return [] }
        return MerchantAftercareDecision.allCases.filter { allowed.contains($0.rawValue) }
    }
    /// Source RESPONSE_FLOW.consequence: a merchant opinion is not a refund.
    public static func consequenceKey(_ decision: MerchantAftercareDecision) -> String {
        "merchantOps.aftercare.respond.consequence." + decision.rawValue
    }
    /// Source: REJECT is the only decision that asks for a second, explicit confirmation.
    public static func requiresDangerConfirmation(_ decision: MerchantAftercareDecision) -> Bool {
        decision == .reject
    }
}

/// POST `api/merchant/aftercare/manual-case-detail?manualCaseId=` (aftercare/detail/index.js).
/// 工单编号 is the source `refundNoText` (`人工退款工单 #id`). Amount is present only when the server sent one.
public struct MerchantAftercareManualDetail: Equatable {
    public let id: Int
    public let numberText: String
    public let amountText: String?
    public init(requestedID: Int, payload: MerchantBusinessValue) throws {
        guard requestedID > 0, let fields = payload.object else { throw MerchantBusinessFailure.malformed }
        let reported = fields["manualCaseId"]?.integer ?? requestedID
        guard reported == requestedID else { throw MerchantBusinessFailure.malformed }
        id = reported
        numberText = "人工退款工单 #\(reported)"
        amountText = Self.displayAmount(fields["refundAmount"])
    }
    private static func displayAmount(_ value: MerchantBusinessValue?) -> String? {
        guard let value, value != .null else { return nil }
        if let text = value.string?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty { return text }
        return value.numberText
    }
}
