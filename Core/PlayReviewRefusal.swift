import Foundation

/// F-05 (acceptance r2): why a stop's submit cannot be reviewed. `PlayExperienceCoordinator.review`
/// still throws; the screen turns that refusal into one of these reasons and shows it beside the submit
/// button and as a toast, so a refused review is never a silent no-op.
public enum PlayReviewRefusal: String, Equatable, CaseIterable, Sendable {
    case completed, locked, notVisible, sessionUnavailable, busy, unresolved, sessionChanged
    case advancedRequired, arrivalRequired, emptyAnswer, invalidChoice, unsupported, disabled, invalidEvidence

    /// Key in `Resources/PlayReviewRefusal.xcstrings` (en + zh-Hans).
    public var messageKey: String { "playReview.refusal." + rawValue }
    public static let table = "PlayReviewRefusal"

    /// Reason for a thrown review error when the snapshot facts name nothing more specific.
    public init(error: Error) {
        switch error as? PlayExperienceError {
        case .staleSession?, .unauthorized?: self = .sessionChanged
        case .unsupported?: self = .unsupported
        case .disabled?: self = .disabled
        case .busy?: self = .busy
        default: self = .invalidEvidence
        }
    }

    /// Stop-level facts from one read, in the order `review` checks them. The server's done flag
    /// (`done`, or a `COMPLETED` node or route state) wins over every other fact. Nil: the stop may be reviewed.
    public static func station(nodeID: Int, in snapshot: PlaySnapshot, mode: PlayGameplayMode?, advancedReady: Bool) -> PlayReviewRefusal? {
        guard let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }) else { return .notVisible }
        if snapshot.isDone(node) { return .completed }
        if snapshot.isLocked(node) { return .locked }
        guard snapshot.availability == .active, node.done == false else { return .sessionUnavailable }
        switch mode {
        case .freeExploration?:
            guard FreeExplorationPresentation.evidenceTask(for: node, in: snapshot) != nil else { return .unsupported }
        case .cityOrientation?:
            if node.hasAdvancedPrerequisite && !advancedReady { return .advancedRequired }
            if PlayNodeTask.resolve(mode: snapshot.result.mode, node: node) == .unsupported { return .unsupported }
        case nil:
            return .unsupported
        }
        if snapshot.route?.isBranch == true, snapshot.route?.version == nil { return .sessionUnavailable }
        return nil
    }

    /// Typed or picked answer facts, checked after `station`. Mirrors the answer guards in `review`.
    public static func answer(_ text: String, nodeID: Int, in snapshot: PlaySnapshot) -> PlayReviewRefusal? {
        guard let node = snapshot.visibleNodes.first(where: { $0.id == nodeID }) else { return .notVisible }
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .emptyAnswer }
        if node.validationMethod == 3, node.options?[text] == nil { return .invalidChoice }
        if (node.needScan == true || node.needGPS == true) && node.arrived != true { return .arrivalRequired }
        return nil
    }
}

/// F-05: every stop the read makes visible, in server order, with the server's done flag applied.
/// Done stops read as completed, locked ones as locked, and every other visible stop stays openable.
public struct PlayStationListRow: Equatable, Identifiable {
    public enum State: String, Equatable { case completed, current, available, locked }
    public let id: Int
    public let position: Int
    public let state: State
}

public enum PlayStationListPresentation {
    public static func rows(_ snapshot: PlaySnapshot, chapterID: Int? = nil) -> [PlayStationListRow] {
        let current = PlayTaskSummaryPresentation(snapshot: snapshot).currentNodeID
        let nodes = snapshot.visibleNodes.filter { chapterID == nil || $0.chapterID == chapterID }
        return nodes.enumerated().map { index, node in
            let state: PlayStationListRow.State
            if snapshot.isDone(node) { state = .completed }
            else if snapshot.isLocked(node) { state = .locked }
            else if node.id == current { state = .current }
            else { state = .available }
            return PlayStationListRow(id: node.id, position: index + 1, state: state)
        }
    }
}
