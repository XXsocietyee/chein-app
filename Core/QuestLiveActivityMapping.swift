import Foundation

/// Which Live Activity an update addresses. `key` separates two play sessions of the same kind.
public struct QuestLiveActivityDescriptor: Equatable, Sendable {
    public let kind: QuestLiveActivityKind
    public let key: String
    public let title: String?
    public init(kind: QuestLiveActivityKind, key: String, title: String?) { self.kind = kind; self.key = key; self.title = title }
}

/// One display update. `show` starts the activity or updates it; `end` removes it.
/// `end` with a nil key ends whatever activity of that kind is running.
public enum QuestLiveActivityUpdate: Equatable, Sendable {
    case show(QuestLiveActivityDescriptor, QuestLiveActivityContent)
    case end(QuestLiveActivityKind, key: String?, last: QuestLiveActivityContent?)
}

/// Receives updates from the roam and play coordinators. The app's ActivityKit owner implements it;
/// tests use a recorder. Never a source of truth: the in-app screens keep their own state.
@MainActor public protocol QuestLiveActivityPublishing: AnyObject {
    func publish(_ update: QuestLiveActivityUpdate)
}

/// Pure state mapping from coordinator facts to Live Activity content. No I/O, no clocks of its own.
public enum QuestLiveActivityMapping {
    public static let roamKey = "roam"

    /// Live roam walk. A walk without a local record shows nothing. A finished walk ends with its final values;
    /// its record is already cleared, so nil distance and places keep the last published values.
    /// `elapsedSeconds` is the controller's foreground clock; when it is nil (screen locked or app in the background)
    /// the previous timer anchor is kept so the system timer keeps counting on the Lock Screen.
    public static func roam(phase: RoamLivePhase, hasRecord: Bool, distanceMeters: Double?, placesRevealed: Int?,
                            elapsedSeconds: Int?, now: Date, previous: QuestLiveActivityContent?) -> QuestLiveActivityUpdate {
        let status: QuestLiveActivityStatus
        switch phase {
        case .active: status = .active
        case .paused, .recoveryRequired, .recovering, .finishing: status = .paused
        case .finished: status = .finished
        case .ready, .acquiring, .unavailable, .locationDenied: return .end(.roam, key: roamKey, last: nil)
        }
        guard hasRecord || status == .finished else { return .end(.roam, key: roamKey, last: nil) }
        let meters = distanceMeters.flatMap { $0.isFinite && $0 >= 0 ? Int($0.rounded()) : nil } ?? previous?.distanceMeters
        let timer = clock(status: status, reported: elapsedSeconds, now: now, previous: previous)
        let content = QuestLiveActivityContent(status: status, elapsedSeconds: timer.seconds, runningSince: timer.since,
                                               distanceMeters: meters, placesRevealed: placesRevealed.map { max(0, $0) } ?? previous?.placesRevealed)
        if status == .finished { return .end(.roam, key: roamKey, last: content) }
        return .show(.init(kind: .roam, key: roamKey, title: nil), content)
    }

    /// Active play session. Only an `.active` route with a loaded snapshot shows; completion ends with final values.
    /// The run clock only exists for city-orientation runs; other modes show stop and clue progress without a timer.
    @available(macOS 14.0, *)
    public static func play(key: String, snapshot: PlaySnapshot?, clockPhase: PlayRunClock.Phase, elapsedSeconds: Int,
                            now: Date) -> QuestLiveActivityUpdate {
        guard let snapshot else { return .end(.play, key: key, last: nil) }
        let availability = snapshot.availability
        guard availability == .active || availability == .completed else { return .end(.play, key: key, last: nil) }
        let visible = snapshot.visibleNodes
        let current = visible.first(where: { !snapshot.isDone($0) && !snapshot.isLocked($0) }) ?? visible.first(where: { !snapshot.isDone($0) })
        let solved = snapshot.displayedDoneCount ?? visible.filter(snapshot.isDone).count
        let total = snapshot.route?.isBranch == true ? visible.count : (snapshot.result.total ?? visible.count)
        let finished = availability == .completed || clockPhase == .ended
        let status: QuestLiveActivityStatus = finished ? .finished : (clockPhase == .paused ? .paused : .active)
        let seconds: Int? = clockPhase == .idle ? nil : max(0, elapsedSeconds)
        let since: Date? = status == .active && clockPhase == .running ? now.addingTimeInterval(-Double(seconds ?? 0)) : nil
        let name = current?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = QuestLiveActivityContent(status: status, elapsedSeconds: seconds, runningSince: since,
            stopName: finished ? nil : (name?.isEmpty == false ? name : nil),
            stopIndex: finished ? nil : current.flatMap { node in visible.firstIndex(where: { $0.id == node.id }).map { $0 + 1 } },
            stopCount: visible.isEmpty ? nil : visible.count, cluesSolved: max(0, solved), cluesTotal: total > 0 ? total : nil)
        if finished { return .end(.play, key: key, last: content) }
        let title = snapshot.result.topicName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .show(.init(kind: .play, key: key, title: title?.isEmpty == false ? title : nil), content)
    }

    private static func clock(status: QuestLiveActivityStatus, reported: Int?, now: Date,
                              previous: QuestLiveActivityContent?) -> (seconds: Int, since: Date?) {
        let carried: Int
        if let since = previous?.runningSince { carried = max(0, Int(now.timeIntervalSince(since))) }
        else { carried = previous?.elapsedSeconds ?? 0 }
        let seconds = reported.map { max(0, $0) } ?? carried
        return (seconds, status == .active ? now.addingTimeInterval(-Double(seconds)) : nil)
    }
}
