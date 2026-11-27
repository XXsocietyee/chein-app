import ActivityKit
import Foundation
import WidgetKit
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The app's only ActivityKit owner. Starts, updates and ends the roam-walk and play-session Live Activities
/// from `QuestLiveActivityUpdate`s published by `RoamLiveSessionController` and `PlayExperienceCoordinator`,
/// plus (native r2 M4, `nativeR2.island`) the story-audio activity and the orientation / explore play context.
/// Local only (no push token). A refused request (Live Activities off, system limit) leaves the in-app flow unchanged.
/// Design P1 L9: the play stop also feeds the next-stop widget (`QuestWidgetStore`, dormant without the App Group).
@MainActor final class QuestLiveActivityCenter: QuestLiveActivityPublishing {
    static let shared = QuestLiveActivityCenter()
    private struct Running {
        let key: String
        let activity: Activity<QuestLiveActivityAttributes>
        var content: QuestLiveActivityContent
    }
    private var running: [QuestLiveActivityKind: Running] = [:]
    /// Native r2 M4: what the visible play screen knows and Core mapping does not (flow, distance to the next stop,
    /// and — components r1 C1 — whether the player stands in the current stop's 50 m highlight).
    private var playContext: (mode: QuestLiveActivityMode, nextDistanceMeters: Int?, arrived: Bool)?
    /// Components r1 C1: the run owners a Live Activity button acts on (weak; AppSession keeps them alive).
    private weak var roamController: RoamLiveSessionController?
    private var playCoordinators: [String: WeakPlayCoordinator] = [:]
    private struct WeakPlayCoordinator { weak var value: PlayExperienceCoordinator? }
    /// The run screen's punch-sheet opener for the current stop, while that screen is up.
    private var checkInHandler: (() -> Void)?
    /// A run that ended moments ago, so the score / rank read after completion still reaches its final card.
    private var recentlyEnded: [QuestLiveActivityKind: Running] = [:]
    private static let storyKey = "story.audio"
    /// Last next-stop values handed to the widget; the widget reloads only when what it shows changes.
    private var lastNextStop: QuestNextStopSnapshot?
    private init() {
        QuestLiveActivityActionRouter.handler = { [weak self] action, kind in self?.perform(action, kind: kind) ?? false }
    }

    // MARK: Components r1 C1 (interactive Live Activity buttons)

    /// Called where AppSession hands the coordinator its `liveActivity` sink.
    func attach(play coordinator: PlayExperienceCoordinator) {
        playCoordinators = playCoordinators.filter { $0.value.value != nil }
        playCoordinators["play:\(coordinator.scope)"] = WeakPlayCoordinator(value: coordinator)
    }

    func attach(roam controller: RoamLiveSessionController) { roamController = controller }

    /// The run screen's punch sheet for the current stop. A check-in that launched the app is applied now.
    func setCheckInHandler(_ handler: (() -> Void)?) {
        checkInHandler = handler
        guard handler != nil, let pending = QuestLiveActivityActionRouter.takePending() else { return }
        _ = perform(pending.action, kind: pending.kind)
    }

    /// Same calls as the in-app pause / resume buttons (`PlayExperienceView.cityRunPrimary`, `CityLiveOnMap`).
    private func perform(_ action: QuestLiveActivityAction, kind: QuestLiveActivityKind) -> Bool {
        switch (action, kind) {
        case (.checkIn, _):
            guard let checkInHandler else { return false }
            checkInHandler(); return true
        case (.pause, .roam):
            guard let roamController, roamController.phase == .active else { return false }
            roamController.pause(); return true
        case (.resume, .roam):
            guard let roamController, roamController.phase == .paused else { return false }
            Task { await roamController.resume(purposeAccepted: true) }
            return true
        case (.pause, .play):
            guard let coordinator = runningPlayCoordinator(), coordinator.clock.phase == .running else { return false }
            let savedAt = Int64(Date().timeIntervalSince1970 * 1000)
            Task { await coordinator.pauseRun(now: ProcessInfo.processInfo.systemUptime, savedAt: savedAt) }
            return true
        case (.resume, .play):
            guard let coordinator = runningPlayCoordinator(), coordinator.clock.phase == .paused else { return false }
            coordinator.startRun(now: ProcessInfo.processInfo.systemUptime)
            return true
        case (.pause, _), (.resume, _):
            return false
        }
    }

    private func runningPlayCoordinator() -> PlayExperienceCoordinator? {
        guard let key = running[.play]?.key, let coordinator = playCoordinators[key]?.value, coordinator.canManageRun else { return nil }
        return coordinator
    }

    // MARK: Components r1 C1 (event "Starts in mm:ss · 加入")

    /// The wallet read (`TicketWalletView`) offers its usable tickets; the soonest session inside the window counts down.
    func eventCountdown(tickets: [TicketWalletTicket]) {
        guard NativeR2Flags.island else { return }
        publish(QuestLiveActivityMapping.event(tickets: tickets, now: Date()))
    }

    // MARK: Native r2 M4 (Dynamic Island regions)

    /// City orientation run or free explore map on screen: tags the running `.play` activity with its flow and
    /// the distance to the next stop (rounded to 10 m so walking does not flood ActivityKit with updates).
    func setPlayContext(mode: QuestLiveActivityMode, nextDistanceMeters: Double?, arrived: Bool = false) {
        guard NativeR2Flags.island else { return }
        let meters = nextDistanceMeters.flatMap { $0.isFinite && $0 >= 0 ? Int(($0 / 10).rounded()) * 10 : nil }
        if let current = playContext, current.mode == mode, current.nextDistanceMeters == meters, current.arrived == arrived { return }
        playContext = (mode, meters, arrived)
        redecoratePlay()
    }

    /// The play screen left; the activity keeps its Core values without the distance.
    func clearPlayContext() {
        guard playContext != nil else { return }
        playContext = nil
        redecoratePlay()
    }

    /// Story audio playing or paused (from the story mini player). The elapsed time carries across pauses.
    func storyAudio(title: String?, isPlaying: Bool) {
        guard NativeR2Flags.island else { return }
        let now = Date()
        let previous = running[.story]?.content
        let carried: Int
        if let since = previous?.runningSince { carried = max(0, Int(now.timeIntervalSince(since))) }
        else { carried = previous?.elapsedSeconds ?? 0 }
        let name = title?.trimmingCharacters(in: .whitespacesAndNewlines)
        let content = QuestLiveActivityContent(status: isPlaying ? .active : .paused, elapsedSeconds: carried,
                                               runningSince: isPlaying ? now.addingTimeInterval(-Double(carried)) : nil,
                                               mediaTitle: name?.isEmpty == false ? name : nil, mediaPlaying: isPlaying)
        show(QuestLiveActivityDescriptor(kind: .story, key: Self.storyKey, title: content.mediaTitle), content)
    }

    func endStoryAudio() {
        end(kind: .story, key: Self.storyKey, last: nil)
    }

    private func decorate(_ content: QuestLiveActivityContent, kind: QuestLiveActivityKind) -> QuestLiveActivityContent {
        guard kind == .play, let playContext else { return content }
        var decorated = content
        decorated.mode = playContext.mode
        let hasStop = content.stopName != nil || content.stopIndex != nil
        decorated.nextDistanceMeters = hasStop ? playContext.nextDistanceMeters : nil
        decorated.arrived = hasStop && playContext.arrived ? true : nil
        return decorated
    }

    private func redecoratePlay() {
        guard var current = running[.play] else { return }
        var base = current.content
        base.mode = nil; base.nextDistanceMeters = nil; base.arrived = nil
        let decorated = decorate(base, kind: .play)
        guard decorated != current.content else { return }
        current.content = decorated
        running[.play] = current
        let activity = current.activity
        Task { await activity.update(ActivityContent(state: decorated, staleDate: nil)) }
        publishNextStop(title: activity.attributes.title, content: decorated)
    }

    // MARK: Next-stop widget (design P1 L9, P-016 / G-089)

    private func publishNextStop(title: String?, content: QuestLiveActivityContent) {
        guard let snapshot = QuestNextStopSnapshot(title: title, content: content, now: Date()),
              !snapshot.showsSame(as: lastNextStop) else { return }
        lastNextStop = snapshot
        if QuestWidgetStore.write(snapshot) { WidgetCenter.shared.reloadTimelines(ofKind: QuestWidgetStore.nextStopKind) }
    }

    /// A finished run leaves the widget on its passport entry.
    private func clearNextStop() {
        lastNextStop = nil
        if QuestWidgetStore.write(nil) { WidgetCenter.shared.reloadTimelines(ofKind: QuestWidgetStore.nextStopKind) }
    }

    func publish(_ update: QuestLiveActivityUpdate) {
        switch update {
        case .show(let descriptor, let content): show(descriptor, content)
        case .end(let kind, let key, let last): end(kind: kind, key: key, last: last)
        }
    }

    /// A relaunch has no coordinator state for activities left by an earlier process; remove them.
    /// Components r1 C1: an event countdown needs no coordinator, so one still inside its window is adopted instead.
    func endOrphanedActivities() {
        let tracked = Set(running.values.map(\.activity.id))
        for activity in Activity<QuestLiveActivityAttributes>.activities where !tracked.contains(activity.id) {
            let state = activity.content.state
            if activity.attributes.kind == .event, running[.event] == nil, let start = state.startsAt,
               start > Date().addingTimeInterval(-QuestLiveActivityMapping.eventGrace) {
                running[.event] = Running(key: QuestLiveActivityMapping.eventKey, activity: activity, content: state)
                continue
            }
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    /// An event countdown goes stale at the session start (the views then read 已开始); runs never go stale.
    private func staleDate(_ content: QuestLiveActivityContent, kind: QuestLiveActivityKind) -> Date? {
        kind == .event ? content.startsAt : nil
    }

    private func show(_ descriptor: QuestLiveActivityDescriptor, _ incoming: QuestLiveActivityContent) {
        let content = decorate(incoming, kind: descriptor.kind)
        if var current = running[descriptor.kind], current.key == descriptor.key {
            guard current.content != content else { return }
            current.content = content
            running[descriptor.kind] = current
            let activity = current.activity
            let stale = staleDate(content, kind: descriptor.kind)
            Task { await activity.update(ActivityContent(state: content, staleDate: stale)) }
            if descriptor.kind == .play { publishNextStop(title: descriptor.title, content: content) }
            return
        }
        // The widget follows the run even when Live Activities are off or refused.
        if descriptor.kind == .play { publishNextStop(title: descriptor.title, content: content) }
        if running[descriptor.kind] != nil { end(kind: descriptor.kind, key: nil, last: nil) }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = QuestLiveActivityAttributes(kind: descriptor.kind, title: descriptor.title, place: descriptor.place)
        let stale = staleDate(content, kind: descriptor.kind)
        guard let activity = try? Activity.request(attributes: attributes,
                                                   content: ActivityContent(state: content, staleDate: stale),
                                                   pushType: nil) else { return }
        recentlyEnded[descriptor.kind] = nil
        running[descriptor.kind] = Running(key: descriptor.key, activity: activity, content: content)
    }

    private func end(kind: QuestLiveActivityKind, key: String?, last: QuestLiveActivityContent?) {
        if kind == .play, last != nil { clearNextStop() }
        guard let current = running[kind], key == nil || key == current.key else {
            refreshEnded(kind: kind, key: key, last: last)
            return
        }
        running[kind] = nil
        recentlyEnded[kind] = last == nil ? nil : current
        let activity = current.activity
        // A finished walk or run stays briefly on the Lock Screen with its final values; anything else leaves at once.
        let policy: ActivityUIDismissalPolicy = last == nil ? .immediate : .default
        let final = last.map { decorate($0, kind: kind) } ?? current.content
        Task { await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: policy) }
    }

    /// Components r1 C1: the score / rank read after completion lands on the ended run's final card.
    private func refreshEnded(kind: QuestLiveActivityKind, key: String?, last: QuestLiveActivityContent?) {
        guard var ended = recentlyEnded[kind], key == nil || key == ended.key, let last else { return }
        let final = decorate(last, kind: kind)
        guard final.score != ended.content.score || final.rank != ended.content.rank else { return }
        ended.content = final
        recentlyEnded[kind] = ended
        let activity = ended.activity
        Task { await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: .default) }
    }
}
