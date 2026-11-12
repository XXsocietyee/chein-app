import Foundation

/// Player flow for an independent side quest shown beside the search map (W14.2–W14.3).
///
/// chengyinhub-xcx at 1c80c5aea8f721ca8575e6108048495b100f5576 has a search-map page and no
/// side-quest page. This type does not invent that page, a route, a marker layer, or a
/// production payload. A missing fact is an em dash. Money writes stay off. Accept stays off.
/// Start, answer, and cancel never mutate the attempt book: there is no authoritative readback.
public enum SideQuestPlayerFlow {
    public static let unknownMark = "\u{2014}"
    /// The mini-program revision above does not contain a side-quest page.
    public static let sourcePagePresent = false
    public static let routeInstalled = false
    public static let routeMarkedLive = false
    public static let placement = Placement.besideSearchMap
    public static let sourceRevision = "1c80c5aea8f721ca8575e6108048495b100f5576"

    public static var paymentEnabled: Bool { ReleaseMoneyWriteSwitch.paymentEnabled }
    public static var payoutEnabled: Bool { ReleaseMoneyWriteSwitch.payoutEnabled }
    public static var withdrawalEnabled: Bool { ReleaseMoneyWriteSwitch.withdrawalEnabled }
    public static var virtualGoodsEnabled: Bool { ReleaseMoneyWriteSwitch.virtualGoodsEnabled }
    public static var acceptEnabled: Bool { SideQuestFeature.acceptEnabled }

    public enum Placement: String, Equatable {
        case besideSearchMap
    }

    public enum Phase: Equatable {
        case sourceAbsent
        case loading
        case empty
        case error
        case unknown
        case ready
    }

    /// Server repeat policy. Only `UNRESTRICTED` is discoverable. Anything else, including a
    /// coupon token, is not a discovery policy.
    public enum RepeatPolicy: String, Equatable {
        case unrestricted = "UNRESTRICTED"
        case once = "ONCE"
    }

    public enum Read: Equatable {
        case loading
        case failed
        case unknown
        case loaded([Row])
    }

    public struct Row: Equatable {
        public let instance: SideQuestSpawnInstance
        public let repeatPolicy: RepeatPolicy?
        /// Ignored. Money stays off, so a reward amount is never shown.
        public let rewardText: String?
        public init(instance: SideQuestSpawnInstance, repeatPolicy: RepeatPolicy?, rewardText: String?) {
            self.instance = instance
            self.repeatPolicy = repeatPolicy
            self.rewardText = rewardText
        }
    }

    public struct RowPresentation: Equatable, Identifiable {
        public let id: String
        public let titleText: String
        public let capacityText: String
        public let rewardText: String
        public let offersServerAccept: Bool
        public let showsAccept: Bool
    }

    public struct Snapshot: Equatable {
        public let phase: Phase
        public let totalText: String
        public let statusText: String
        public let rows: [RowPresentation]
        public let showsAccept: Bool
        public let showsStart: Bool
        public let showsAnswer: Bool
        public let showsCancel: Bool
        public let addsMarkerLayer: Bool
        public let placement: Placement
        public let sourcePagePresent: Bool
    }

    public enum Action: Equatable {
        case start(instanceID: String)
        case answer(instanceID: String, choice: String?)
        case cancel(instanceID: String)
    }

    public enum Refusal: Equatable {
        case sourcePageAbsent
        case moneyOff
        case acceptDisabled
        case unknownOutcome
        case notListed
        case missingChoice
        case noAuthoritativeReadback
    }

    public struct ActionResult: Equatable {
        public let refusal: Refusal
        public let book: SideQuestAttemptBook
        public let choiceText: String
        public let applied: Bool
    }

    /// Search-map entry. No read is supplied, so the count is unknown and no row is shown.
    public static var production: Snapshot { project(read: nil, now: Date()) }

    public static func parsedRepeatPolicy(_ serverValue: String?) -> RepeatPolicy? {
        switch serverValue?.trimmingCharacters(in: .whitespacesAndNewlines) {
        case RepeatPolicy.unrestricted.rawValue: return .unrestricted
        case RepeatPolicy.once.rawValue: return .once
        default: return nil
        }
    }

    public static func capacityText(_ value: Int?) -> String {
        guard let value, value >= 0 else { return unknownMark }
        return String(value)
    }

    /// `presentSuppliedRead` is for an explicit caller-supplied read. The default keeps the
    /// production entry closed and does not turn that read into live rows.
    public static func project(read: Read?, now: Date, presentSuppliedRead: Bool = false) -> Snapshot {
        let rows = presentSuppliedRead ? visibleRows(in: read, now: now) : []
        let phase = phase(read: read, rows: rows, presentSuppliedRead: presentSuppliedRead)
        return Snapshot(
            phase: phase,
            totalText: totalText(phase: phase, count: rows.count),
            statusText: unknownMark,
            rows: rows,
            showsAccept: false,
            showsStart: false,
            showsAnswer: false,
            showsCancel: false,
            addsMarkerLayer: false,
            placement: placement,
            sourcePagePresent: sourcePagePresent
        )
    }

    public static func visibleRows(in read: Read?, now: Date) -> [RowPresentation] {
        guard case .loaded(let rows) = read else { return [] }
        return rows.compactMap { row in
            guard row.repeatPolicy == .unrestricted, row.instance.isDiscoverable(now: now) else { return nil }
            return RowPresentation(
                id: row.instance.instanceID,
                titleText: row.instance.title,
                capacityText: capacityText(row.instance.remainingCapacity),
                rewardText: unknownMark,
                offersServerAccept: row.instance.offersAccept(now: now),
                showsAccept: false
            )
        }
    }

    /// Gate order: missing page, money write, accept switch, unknown prior outcome, listing,
    /// missing answer, then the absence of an authoritative readback. The book is never written.
    public static func perform(
        _ action: Action,
        book: SideQuestAttemptBook,
        read: Read? = nil,
        now: Date = Date(),
        sourcePagePresent: Bool = SideQuestPlayerFlow.sourcePagePresent,
        acceptEnabled: Bool = SideQuestFeature.acceptEnabled,
        moneyWrite: Bool = false
    ) -> ActionResult {
        let reason = refusal(
            action: action,
            book: book,
            read: read,
            now: now,
            sourcePagePresent: sourcePagePresent,
            acceptEnabled: acceptEnabled,
            moneyWrite: moneyWrite
        )
        return ActionResult(refusal: reason, book: book, choiceText: unknownMark, applied: false)
    }

    public static func refusal(
        action: Action,
        book: SideQuestAttemptBook,
        read: Read?,
        now: Date,
        sourcePagePresent: Bool,
        acceptEnabled: Bool,
        moneyWrite: Bool
    ) -> Refusal {
        if !sourcePagePresent { return .sourcePageAbsent }
        if moneyWrite { return .moneyOff }
        if !acceptEnabled { return .acceptDisabled }
        if outcomeUnknown(book) { return .unknownOutcome }
        if !listed(instanceID(action), read: read, now: now) { return .notListed }
        if case .answer(_, let choice) = action, !hasChoice(choice) { return .missingChoice }
        return .noAuthoritativeReadback
    }

    private static func phase(read: Read?, rows: [RowPresentation], presentSuppliedRead: Bool) -> Phase {
        guard presentSuppliedRead else { return .sourceAbsent }
        switch read {
        case .none, .some(.unknown): return .unknown
        case .some(.loading): return .loading
        case .some(.failed): return .error
        case .some(.loaded): return rows.isEmpty ? .empty : .ready
        }
    }

    private static func totalText(phase: Phase, count: Int) -> String {
        switch phase {
        case .ready: return String(count)
        case .empty: return "0"
        case .sourceAbsent, .loading, .error, .unknown: return unknownMark
        }
    }

    private static func outcomeUnknown(_ book: SideQuestAttemptBook) -> Bool {
        if case .unknown = book.pending { return true }
        return false
    }

    private static func listed(_ instanceID: String, read: Read?, now: Date) -> Bool {
        visibleRows(in: read, now: now).contains { $0.id == instanceID }
    }

    private static func instanceID(_ action: Action) -> String {
        switch action {
        case .start(let instanceID), .cancel(let instanceID): return instanceID
        case .answer(let instanceID, _): return instanceID
        }
    }

    private static func hasChoice(_ choice: String?) -> Bool {
        guard let choice else { return false }
        return !choice.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
