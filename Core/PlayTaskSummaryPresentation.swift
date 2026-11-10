import Foundation

/// Read-only presentation of an existing authoritative snapshot. No completion commands,
/// inferred totals, local success flags, timers or provider access live in this projection.
public struct PlayTaskSummaryPresentation: Equatable {
    public let completed: Int?
    public let total: Int?
    public let currentNodeID: Int?
    public init(snapshot: PlaySnapshot) {
        let done = snapshot.displayedDoneCount
        if let count = snapshot.result.total, count > 0, let done, (0...count).contains(done) {
            completed = done; total = count
        } else { completed = nil; total = nil }
        let candidates = snapshot.visibleNodes.filter { !snapshot.isDone($0) && !snapshot.isLocked($0) && $0.done == false }
        // Multiple playable branches remain a choice; their order is not an authoritative current task.
        currentNodeID = snapshot.result.mode != 2 && snapshot.availability == .active && candidates.count == 1 ? candidates.first?.id : nil
    }
    public var fraction: Double? {
        guard let completed, let total else { return nil }
        return Double(completed) / Double(total)
    }
}

public enum PlayTaskStatusPresentation: String, Equatable {
    case completed, locked, awaitingVerification, available, unknown
    public init(node: PlayNode, snapshot: PlaySnapshot) {
        if snapshot.isDone(node) { self = .completed }
        else if snapshot.isLocked(node) { self = .locked }
        else if snapshot.result.mode == 2 && node.selfReported == true { self = .awaitingVerification }
        else if node.done == false && snapshot.availability == .active { self = .available }
        else { self = .unknown }
    }
    public var labelKey: String { "referenceTask.status." + rawValue }
    public var symbol: String {
        switch self {
        case .completed: return "checkmark.circle"
        case .locked: return "lock"
        case .awaitingVerification: return "clock"
        case .available: return "circle"
        case .unknown: return "questionmark.circle"
        }
    }
}

/// Container facts for `pages/play/index`. Built only from a phase, the read gate,
/// and a snapshot the coordinator already holds. It does not fetch, write, or open a route.
/// A missing read stays the disabled empty shell. UNKNOWN progress is an em dash.
public struct PlayIndexPageReadiness: Equatable {
    public static let unknownMark = "—"
    public enum Kind: String, Equatable {
        case loading, empty, error, unknown, ready
    }
    public let kind: Kind
    public let titleKey: String
    public let accessibilityIdentifier: String
    public let progressText: String

    public init(phase: String, readsEnabled: Bool, unresolved: Bool, snapshot: PlaySnapshot?) {
        if phase == "loading" {
            self = .marked(.loading, titleKey: "playx.loading", accessibilityIdentifier: "playx.loading")
            return
        }
        // Reads default off. Hide the session instead of inventing an empty route or a zero.
        if !readsEnabled {
            self = .marked(.empty, titleKey: "playx.disabled.title", accessibilityIdentifier: "playx.disabled")
            return
        }
        guard let snapshot else {
            if unresolved || phase == "unknown" {
                self = .marked(.unknown, titleKey: "playx.unknown.title", accessibilityIdentifier: "referenceTask.phaseOnly")
            } else {
                self = .marked(.error, titleKey: "playx.error.title", accessibilityIdentifier: "playx.issue")
            }
            return
        }
        if unresolved || phase == "unknown" || snapshot.availability == .unknown {
            self = .marked(.unknown, titleKey: "playx.unknown.title", accessibilityIdentifier: "referenceTask.phaseOnly")
            return
        }
        if snapshot.availability == .empty {
            self = .marked(.empty, titleKey: "play.empty", accessibilityIdentifier: "play.status")
            return
        }
        if phase == "failed" {
            self = .marked(.error, titleKey: "playx.error.title", accessibilityIdentifier: "playx.issue")
            return
        }
        let progress = Self.progress(PlayTaskSummaryPresentation(snapshot: snapshot))
        let identifier = progress == Self.unknownMark ? "referenceTask.phaseOnly" : "referenceTask.count"
        self = Self(kind: .ready, titleKey: "playx.progress", accessibilityIdentifier: identifier, progressText: progress)
    }

    private static func marked(_ kind: Kind, titleKey: String, accessibilityIdentifier: String) -> Self {
        Self(kind: kind, titleKey: titleKey, accessibilityIdentifier: accessibilityIdentifier, progressText: unknownMark)
    }

    private init(kind: Kind, titleKey: String, accessibilityIdentifier: String, progressText: String) {
        self.kind = kind
        self.titleKey = titleKey
        self.accessibilityIdentifier = accessibilityIdentifier
        self.progressText = progressText
    }

    /// A known zero of a positive total stays numeric. Missing or inconsistent totals stay the em dash.
    static func progress(_ summary: PlayTaskSummaryPresentation) -> String {
        guard let completed = summary.completed, let total = summary.total else { return unknownMark }
        return "\(completed)/\(total)"
    }
}
