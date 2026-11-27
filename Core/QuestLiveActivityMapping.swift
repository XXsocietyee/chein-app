import Foundation

/// Which Live Activity an update addresses. `key` separates two play sessions of the same kind.
public struct QuestLiveActivityDescriptor: Equatable, Sendable {
    public let kind: QuestLiveActivityKind
    public let key: String
    public let title: String?
    /// Components r1 C1: an event session's venue (`QuestLiveActivityAttributes.place`); nil for runs and audio.
    public let place: String?
    public init(kind: QuestLiveActivityKind, key: String, title: String?, place: String? = nil) {
        self.kind = kind; self.key = key; self.title = title; self.place = place
    }
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
    /// Components r1 C1: `score` / `rank` are the player's own leaderboard row (`PlayCompanionLeaderboard.me`), when read.
    public static func play(key: String, snapshot: PlaySnapshot?, clockPhase: PlayRunClock.Phase, elapsedSeconds: Int,
                            now: Date, score: Int? = nil, rank: Int? = nil) -> QuestLiveActivityUpdate {
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
            stopCount: visible.isEmpty ? nil : visible.count, cluesSolved: max(0, solved), cluesTotal: total > 0 ? total : nil,
            score: score.map { max(0, $0) }, rank: rank.flatMap { $0 > 0 ? $0 : nil })
        if finished { return .end(.play, key: key, last: content) }
        let title = snapshot.result.topicName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return .show(.init(kind: .play, key: key, title: title?.isEmpty == false ? title : nil), content)
    }

    // MARK: Components r1 C1 — event "Starts in mm:ss · 加入" countdown

    public static let eventKey = "event.next"
    /// The countdown shows from this long before a session starts (the system timer reads `h:mm:ss` above an hour).
    public static let eventLeadTime: TimeInterval = 3 * 60 * 60
    /// …and stays this long after the start (reading 已开始 · 加入) so a late player still reaches the pass.
    public static let eventGrace: TimeInterval = 30 * 60

    /// The soonest wallet ticket (MP `usableTicket`, F13) whose session start carries a time of day and falls inside
    /// `[now - eventGrace, now + eventLeadTime]`. Date-only starts never count down (no time to count to).
    /// Nothing inside the window ends the countdown. Display only: no ticket id, code or account reaches the activity.
    public static func event(tickets: [TicketWalletTicket], now: Date) -> QuestLiveActivityUpdate {
        let candidates: [(ticket: TicketWalletTicket, start: Date)] = tickets.compactMap { ticket in
            guard ticket.isWalletUsable, ticket.status != .verified, let start = eventStart(ticket),
                  start <= now.addingTimeInterval(eventLeadTime), start > now.addingTimeInterval(-eventGrace) else { return nil }
            return (ticket, start)
        }
        guard let next = candidates.min(by: { $0.start < $1.start }) else { return .end(.event, key: eventKey, last: nil) }
        let title = next.ticket.title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = next.ticket.addressName?.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = QuestLiveActivityContent(status: .active, startsAt: next.start)
        return .show(.init(kind: .event, key: eventKey, title: title?.isEmpty == false ? title : nil,
                           place: place?.isEmpty == false ? place : nil), content)
    }

    /// Session start (`usableFrom`, else the owner's `startDate`) only when the server text has a time of day.
    public static func eventStart(_ ticket: TicketWalletTicket) -> Date? {
        for text in [ticket.usableFrom, ticket.startDate] {
            guard let raw = text?.trimmingCharacters(in: .whitespaces), raw.count > 10 else { continue }
            if let date = TicketWalletTicket.sourceDate(raw) { return date }
        }
        return nil
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
