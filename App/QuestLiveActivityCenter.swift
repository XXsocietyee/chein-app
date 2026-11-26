import ActivityKit
import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The app's only ActivityKit owner. Starts, updates and ends the roam-walk and play-session Live Activities
/// from `QuestLiveActivityUpdate`s published by `RoamLiveSessionController` and `PlayExperienceCoordinator`,
/// plus (native r2 M4, `nativeR2.island`) the story-audio activity and the orientation / explore play context.
/// Local only (no push token). A refused request (Live Activities off, system limit) leaves the in-app flow unchanged.
@MainActor final class QuestLiveActivityCenter: QuestLiveActivityPublishing {
    static let shared = QuestLiveActivityCenter()
    private struct Running {
        let key: String
        let activity: Activity<QuestLiveActivityAttributes>
        var content: QuestLiveActivityContent
    }
    private var running: [QuestLiveActivityKind: Running] = [:]
    /// Native r2 M4: what the visible play screen knows and Core mapping does not (flow, distance to the next stop).
    private var playContext: (mode: QuestLiveActivityMode, nextDistanceMeters: Int?)?
    private static let storyKey = "story.audio"
    private init() {}

    // MARK: Native r2 M4 (Dynamic Island regions)

    /// City orientation run or free explore map on screen: tags the running `.play` activity with its flow and
    /// the distance to the next stop (rounded to 10 m so walking does not flood ActivityKit with updates).
    func setPlayContext(mode: QuestLiveActivityMode, nextDistanceMeters: Double?) {
        guard NativeR2Flags.island else { return }
        let meters = nextDistanceMeters.flatMap { $0.isFinite && $0 >= 0 ? Int(($0 / 10).rounded()) * 10 : nil }
        if let current = playContext, current.mode == mode, current.nextDistanceMeters == meters { return }
        playContext = (mode, meters)
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
        decorated.nextDistanceMeters = content.stopName == nil && content.stopIndex == nil ? nil : playContext.nextDistanceMeters
        return decorated
    }

    private func redecoratePlay() {
        guard var current = running[.play] else { return }
        var base = current.content
        base.mode = nil; base.nextDistanceMeters = nil
        let decorated = decorate(base, kind: .play)
        guard decorated != current.content else { return }
        current.content = decorated
        running[.play] = current
        let activity = current.activity
        Task { await activity.update(ActivityContent(state: decorated, staleDate: nil)) }
    }

    func publish(_ update: QuestLiveActivityUpdate) {
        switch update {
        case .show(let descriptor, let content): show(descriptor, content)
        case .end(let kind, let key, let last): end(kind: kind, key: key, last: last)
        }
    }

    /// A relaunch has no coordinator state for activities left by an earlier process; remove them.
    func endOrphanedActivities() {
        let tracked = Set(running.values.map(\.activity.id))
        for activity in Activity<QuestLiveActivityAttributes>.activities where !tracked.contains(activity.id) {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func show(_ descriptor: QuestLiveActivityDescriptor, _ incoming: QuestLiveActivityContent) {
        let content = decorate(incoming, kind: descriptor.kind)
        if var current = running[descriptor.kind], current.key == descriptor.key {
            guard current.content != content else { return }
            current.content = content
            running[descriptor.kind] = current
            let activity = current.activity
            Task { await activity.update(ActivityContent(state: content, staleDate: nil)) }
            return
        }
        if running[descriptor.kind] != nil { end(kind: descriptor.kind, key: nil, last: nil) }
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let attributes = QuestLiveActivityAttributes(kind: descriptor.kind, title: descriptor.title)
        guard let activity = try? Activity.request(attributes: attributes,
                                                   content: ActivityContent(state: content, staleDate: nil),
                                                   pushType: nil) else { return }
        running[descriptor.kind] = Running(key: descriptor.key, activity: activity, content: content)
    }

    private func end(kind: QuestLiveActivityKind, key: String?, last: QuestLiveActivityContent?) {
        guard let current = running[kind], key == nil || key == current.key else { return }
        running[kind] = nil
        let activity = current.activity
        // A finished walk or run stays briefly on the Lock Screen with its final values; anything else leaves at once.
        let policy: ActivityUIDismissalPolicy = last == nil ? .immediate : .default
        let final = last.map { decorate($0, kind: kind) } ?? current.content
        Task { await activity.end(ActivityContent(state: final, staleDate: nil), dismissalPolicy: policy) }
    }
}
