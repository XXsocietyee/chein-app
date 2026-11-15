import ActivityKit
import Foundation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// The app's only ActivityKit owner. Starts, updates and ends the roam-walk and play-session Live Activities
/// from `QuestLiveActivityUpdate`s published by `RoamLiveSessionController` and `PlayExperienceCoordinator`.
/// Local only (no push token). A refused request (Live Activities off, system limit) leaves the in-app flow unchanged.
@MainActor final class QuestLiveActivityCenter: QuestLiveActivityPublishing {
    static let shared = QuestLiveActivityCenter()
    private struct Running {
        let key: String
        let activity: Activity<QuestLiveActivityAttributes>
        var content: QuestLiveActivityContent
    }
    private var running: [QuestLiveActivityKind: Running] = [:]
    private init() {}

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

    private func show(_ descriptor: QuestLiveActivityDescriptor, _ content: QuestLiveActivityContent) {
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
        Task { await activity.end(ActivityContent(state: last ?? current.content, staleDate: nil), dismissalPolicy: policy) }
    }
}
