import ActivityKit
import Foundation
import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// Components r1 R-island: owner of the shared invite / plan Live Activity (`QuestPlanActivityAttributes`).
///
/// Shared: the server starts the same card on every member's device with ActivityKit push-to-start and updates it with
/// per-activity pushes. This center hands both kinds of token to `POST /api/live-activity/token`
/// (`QuestPlanActivityTokenRequest`): the push-to-start token (iOS 17.2+) and each running activity's update token, and
/// withdraws a token when its activity ends.
/// Local fallback: invite / club / team data the app already reads starts a local card (`present`). It asks for a push
/// token first so the server can keep it in sync; when that is refused (no push entitlement, push off) it starts a plain
/// local activity. A plan the server already started is updated in place, never duplicated (same `planKey`).
/// 稍后 (Tuck) is remembered per plan so a refresh does not unfold the card again.
@MainActor final class QuestPlanActivityCenter {
    static let shared = QuestPlanActivityCenter()
    typealias Registrar = (QuestPlanActivityTokenRequest) async -> Bool

    private var registrar: Registrar?
    private var queued: [QuestPlanActivityTokenRequest] = []
    private var observed: Set<String> = []
    private var tucked: Set<String> = []
    private var started = false
    private var teamMembers: [String: [PlayPlayerTeamMember]] = [:]
    private static let maxLocalPlans = 2
    private init() {}

    // MARK: Launch / tokens

    /// From `QuestifyApp.init`: installs the Tuck handler and starts observing tokens and push-started activities.
    func start() {
        guard !started else { return }
        started = true
        QuestPlanActionRouter.tuck = { [weak self] key in await self?.tuck(planKey: key) ?? false }
        for activity in Activity<QuestPlanActivityAttributes>.activities { observe(activity) }
        Task { [weak self] in
            for await activity in Activity<QuestPlanActivityAttributes>.activityUpdates { self?.observe(activity) }
        }
        if #available(iOS 17.2, *) {
            Task { [weak self] in
                for await token in Activity<QuestPlanActivityAttributes>.pushToStartTokenUpdates {
                    self?.send(.pushToStart, token: token, planKey: nil, activityID: nil)
                }
            }
        }
    }

    /// The signed-in session's sender (`questPlanTokenRegistration`). Nil on sign-out: requests wait for the next account.
    func setRegistrar(_ registrar: Registrar?) {
        self.registrar = registrar
        guard registrar != nil, !queued.isEmpty else { return }
        let pending = queued
        queued = []
        for request in pending { deliver(request) }
    }

    private func observe(_ activity: Activity<QuestPlanActivityAttributes>) {
        guard observed.insert(activity.id).inserted else { return }
        let key = activity.attributes.planKey
        let id = activity.id
        if activity.content.state.tucked == true { tucked.insert(key) }
        Task { [weak self] in
            for await token in activity.pushTokenUpdates { self?.send(.activity, token: token, planKey: key, activityID: id) }
        }
        Task { [weak self] in
            for await state in activity.activityStateUpdates where state == .ended || state == .dismissed {
                self?.send(.ended, token: nil, planKey: key, activityID: id)
                self?.observed.remove(id)
                break
            }
        }
    }

    private func send(_ scope: QuestPlanActivityTokenRequest.Scope, token: Data?, planKey: String?, activityID: String?) {
        #if DEBUG
        let environment = "SANDBOX"
        #else
        let environment = "PRODUCTION"
        #endif
        let request = QuestPlanActivityTokenRequest(scope: scope, token: token, planKey: planKey, activityId: activityID,
                                                    environment: environment, bundleId: Bundle.main.bundleIdentifier ?? "",
                                                    locale: Locale.current.identifier)
        guard request.isValid else { return }
        deliver(request)
    }

    private func deliver(_ request: QuestPlanActivityTokenRequest) {
        guard let registrar else {
            // Keep the newest of each (scope, plan) until a session can send it.
            queued.removeAll { $0.scope == request.scope && $0.planKey == request.planKey }
            queued.append(request)
            return
        }
        Task { [weak self] in
            if await registrar(request) == false, request.scope != .ended {
                self?.queued.removeAll { $0.scope == request.scope && $0.planKey == request.planKey }
                self?.queued.append(request)
            }
        }
    }

    // MARK: Local plans (fallback)

    /// Starts or updates the local card for a plan. A tucked plan stays tucked.
    func present(_ descriptor: QuestPlanDescriptor, staleDate: Date? = nil) {
        guard NativeR2Flags.island else { return }
        var content = descriptor.content
        if tucked.contains(descriptor.planKey) { content.tucked = true }
        let existing = Activity<QuestPlanActivityAttributes>.activities.filter {
            $0.attributes.planKey == descriptor.planKey && $0.activityState == .active
        }
        if let activity = existing.first {
            // A pushed card owns its copy; locally only the joined state may be added to it.
            var next = activity.content.state
            if next.tucked == true { content.tucked = true }
            if next.headline == content.headline && next.note == content.note && next.joined == content.joined
                && next.done == content.done && next.tucked == content.tucked { return }
            next = content
            Task { await activity.update(ActivityContent(state: next, staleDate: staleDate)) }
            return
        }
        guard ActivityAuthorizationInfo().areActivitiesEnabled, content.joined != true,
              Activity<QuestPlanActivityAttributes>.activities.count < Self.maxLocalPlans else { return }
        let attributes = QuestPlanActivityAttributes(kind: descriptor.kind, planKey: descriptor.planKey,
                                                     title: descriptor.title, targetID: descriptor.targetID)
        let initial = ActivityContent(state: content, staleDate: staleDate)
        let activity: Activity<QuestPlanActivityAttributes>
        if let pushed = try? Activity.request(attributes: attributes, content: initial, pushType: .token) {
            activity = pushed
        } else if let local = try? Activity.request(attributes: attributes, content: initial, pushType: nil) {
            activity = local
        } else {
            return
        }
        observe(activity)
    }

    /// Ends local cards of `kind` whose plan is no longer offered (invite answered, event over, run left).
    func withdraw(kind: QuestPlanKind, keeping keys: Set<String>) {
        for activity in Activity<QuestPlanActivityAttributes>.activities
        where activity.attributes.kind == kind && !keys.contains(activity.attributes.planKey) {
            tucked.remove(activity.attributes.planKey)
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
        }
    }

    private func tuck(planKey: String) async -> Bool {
        tucked.insert(planKey)
        var found = false
        for activity in Activity<QuestPlanActivityAttributes>.activities where activity.attributes.planKey == planKey {
            found = true
            var state = activity.content.state
            guard state.tucked != true else { continue }
            state.tucked = true
            await activity.update(ActivityContent(state: state, staleDate: activity.content.staleDate))
        }
        return found
    }

    // MARK: Adoption points

    private nonisolated static func localize(_ key: String) -> String {
        appLocalized(String.LocalizationValue(key), locale: Locale.current)
    }

    /// Team invites read on the invite page (`NativeFriendTeamInviteEntry`).
    func teamInvites(_ offers: [NativeFriendTeamOffer]) {
        guard NativeR2Flags.island else { return }
        let plans = QuestPlanActivityMapping.teamInvites(offers, localize: Self.localize)
        for plan in plans { present(plan) }
        // Offers that are no longer pending (answered, revoked, expired) leave; a joined one shows 已加入 then ends.
        let live = Set(plans.filter { $0.content.joined != true }.map(\.planKey))
        let listed = Set(offers.map { QuestPlanActivityMapping.offerKey($0.offerID) })
        let stale = Activity<QuestPlanActivityAttributes>.activities.filter {
            $0.attributes.kind == .teamInvite && listed.contains($0.attributes.planKey) && !live.contains($0.attributes.planKey)
        }
        for activity in stale {
            Task { await activity.end(ActivityContent(state: activity.content.state, staleDate: nil), dismissalPolicy: .default) }
        }
    }

    /// Club calendar read (`ClubEventCalendarView`): an event that starts today nudges once per event.
    func clubEvents(clubID: Int, clubName: String?, events: [ClubCalendarEvent]) {
        guard NativeR2Flags.island else { return }
        guard let plan = QuestPlanActivityMapping.clubEvent(clubID: clubID, clubName: clubName, events: events,
                                                           now: Date(), localize: Self.localize) else { return }
        present(plan.descriptor, staleDate: plan.staleDate)
    }

    /// Team status read during a run (`PlayPlayerTeamStatusView`). Leaving the run (`nil`) ends the card.
    func teamStatus(scope: String, title: String?, members: [PlayPlayerTeamMember]?) {
        guard NativeR2Flags.island else { return }
        let key = QuestPlanActivityMapping.teamStatusKey(scope)
        guard let members else {
            teamMembers[scope] = nil
            withdraw(kind: .teamStatus, keeping: [])
            return
        }
        let previous = teamMembers[scope] ?? members
        teamMembers[scope] = members
        guard let plan = QuestPlanActivityMapping.teamStatus(scope: scope, title: title, previous: previous,
                                                             current: members, localize: Self.localize) else { return }
        withdraw(kind: .teamStatus, keeping: [key])
        present(plan)
    }
}

/// Signed-in sender for `POST /api/live-activity/token`, installed on the session root.
private struct QuestPlanTokenRegistration: ViewModifier {
    @ObservedObject var session: AppSession
    func body(content: Content) -> some View {
        content.task(id: session.token) {
            QuestPlanActivityCenter.shared.setRegistrar(session.questPlanTokenRegistrar())
        }
    }
}

extension View {
    func questPlanTokenRegistration(_ session: AppSession) -> some View {
        modifier(QuestPlanTokenRegistration(session: session))
    }
}

extension AppSession {
    /// Nil while signed out or without a regional API.
    func questPlanTokenRegistrar() -> QuestPlanActivityCenter.Registrar? {
        guard let configuration = regionalConfiguration?.apiConfiguration, let token,
              AuthRequestBuilder.isValidToken(token) else { return nil }
        let service = QuestPlanActivityTokenService(configuration: configuration, transport: runtimeHTTPTransport,
                                                    token: { [weak self] in self?.token })
        return { request in await service.register(request) }
    }
}
