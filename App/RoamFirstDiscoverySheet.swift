import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

/// ROAM-r11-7: where the 首次发现 options go. Nil (fixtures) keeps the walk without the card.
struct RoamDiscoverDestinations {
    /// 领优惠券 → the coupon wallet (MP `openRoamReward` → game-coupon-wallet).
    let coupons: @MainActor () -> AnyView
    /// 做微任务 → the official task list (MP `openRoamTasks`).
    let tasks: @MainActor () -> AnyView
    /// `GET /api/roam/nearby-exploreday`; nil = no candidate.
    let exploreDay: @MainActor () async -> RoamExploreDay?
    /// MP `openScene('play-activity-detail', {id})`.
    let activity: @MainActor (Int) -> AnyView
    /// MP 主题半屏 查看详情 → `pages/topic/index/index?id=`; nil hides the row.
    var topic: (@MainActor (Int) -> AnyView)? = nil
}

private struct RoamDiscoverDestinationsKey: EnvironmentKey {
    static let defaultValue: RoamDiscoverDestinations? = nil
}

extension EnvironmentValues {
    var roamDiscoverDestinations: RoamDiscoverDestinations? {
        get { self[RoamDiscoverDestinationsKey.self] }
        set { self[RoamDiscoverDestinationsKey.self] = newValue }
    }
}

/// MP 首次发现商家 sheet (`pages/roam/index.wxml:960-990`, index.js:4643-4733): 选一份见面礼 — 领优惠券, 做微任务 and,
/// when the server recommends one, the nearby explore day; 先继续走 closes it.
@MainActor struct RoamFirstDiscoverySheet: View {
    let place: RoamPlace
    let destinations: RoamDiscoverDestinations
    @Environment(\.dismiss) private var dismiss
    @State private var exploreDay: RoamExploreDay?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(verbatim: place.name).font(.title3.weight(.semibold))
                    Text("roam.discover.pick").foregroundStyle(.secondary)
                }
                Section {
                    NavigationLink { destinations.coupons() } label: {
                        Label { VStack(alignment: .leading) { Text("roam.discover.coupon"); Text("roam.discover.couponHint").font(.footnote).foregroundStyle(.secondary) } }
                            icon: { Image(systemName: "ticket") }
                    }
                    .accessibilityIdentifier("roam.discover.coupon")
                    NavigationLink { destinations.tasks() } label: {
                        Label { VStack(alignment: .leading) { Text("roam.discover.task"); Text("roam.discover.taskHint").font(.footnote).foregroundStyle(.secondary) } }
                            icon: { Image(systemName: "flag") }
                    }
                    .accessibilityIdentifier("roam.discover.task")
                    if let exploreDay {
                        NavigationLink { destinations.activity(exploreDay.id) } label: {
                            Label { VStack(alignment: .leading) {
                                Text(verbatim: exploreDay.title)
                                Text("roam.discover.exploreDayHint \(exploreDay.distanceM ?? 0)").font(.footnote).foregroundStyle(.secondary)
                            } } icon: { Image(systemName: "point.topleft.down.to.point.bottomright.curvepath") }
                        }
                        .accessibilityIdentifier("roam.discover.exploreDay")
                    }
                }
                Section {
                    Button("roam.discover.skip") { dismiss() }
                        .accessibilityIdentifier("roam.discover.skip")
                }
            }
            .navigationTitle(Text("roam.discover.title"))
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .task { exploreDay = await destinations.exploreDay() }
    }
}

extension AppSession {
    /// ROAM-r11-7: destinations for the 首次发现 card.
    var roamDiscoverDestinations: RoamDiscoverDestinations {
        RoamDiscoverDestinations(
            coupons: { [weak self] in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(AccountCollectionCouponsView(reader: self.accountCollectionReader))
            },
            tasks: { [weak self] in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(RoamOfficialTasksView(roamReader: self.roamExperienceReader, reader: self.officialEventReader))
            },
            exploreDay: { [weak self] in
                guard let self else { return nil }
                return try? await self.roamReader.roamExploreDay()
            },
            activity: { [weak self] id in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(MPReviewedPageScreen(page: "pages/activity/detail/index", query: ["id": String(id)]).environmentObject(self))
            },
            topic: { [weak self] id in
                guard let self else { return AnyView(EmptyView()) }
                return AnyView(MPReviewedPageScreen(page: "pages/topic/index/index", query: ["id": String(id)]).environmentObject(self))
            })
    }
}
