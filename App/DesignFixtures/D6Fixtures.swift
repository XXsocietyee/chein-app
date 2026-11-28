#if DEBUG
import SwiftUI

/// D6 player map fixtures (play / roam / search map / live roam). Synthetic, debug-only, never in Release.
/// The map is a static placeholder; real screens render MapKit. Text follows the launch language.
private func t(_ en: String, _ zh: String) -> String {
    Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en
}

enum D6FixtureKind: String { case play, playLoading, roam, search, live }

struct D6MapFixture: View {
    let kind: D6FixtureKind
    @State private var sheet = true

    var body: some View {
        ZStack {
            CYMapPlaceholder(fog: kind == .roam || kind == .live)
            content
        }
        .themeDomain(.player)
        .preferredColorScheme(followsSystem ? nil : .dark)
        .background(followsSystem ? Color.clear : Color.black)
    }

    /// Play maps follow the system appearance (one map style across d2-play / d6-play, sweep 11-27 23:50).
    private var followsSystem: Bool {
        kind == .roam || kind == .play || kind == .playLoading
    }

    @ViewBuilder private var content: some View {
        switch kind {
        case .play, .playLoading: play
        case .roam: roam
        case .search: search
        case .live: live
        }
    }

    // MARK: Play: node on the map, info + the one primary action in a detent sheet

    private var play: some View {
        ZStack {
            CYMapCallout(text: t("Lantern Gate", "灯笼门"), selected: true).position(x: 250, y: 330)
            CYMapCallout(text: t("Tea House", "茶馆")).position(x: 120, y: 420)
            VStack {
                HStack {
                    CYGlassButton(systemImage: "chevron.left", label: "Back", action: {})
                    Spacer()
                    // ADA 1128: the MP play map has no locate control (P9); only More stays.
                    CYGlassButton(systemImage: "ellipsis", label: "More", action: {})
                }
                .padding(.horizontal, CYSpacing.lg)
                Spacer()
            }
        }
        .cyMapSheet(isPresented: $sheet) { playSheet }
    }

    private var playSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: CYSpacing.lg) {
                if kind == .playLoading {
                    CYSkeleton()
                } else {
                    HStack(spacing: CYSpacing.sm) {
                        CYStatusChip(LocalizedStringKey(t("Task 2 of 5", "任务 2 / 5")), systemImage: "flag.fill")
                        CYStatusChip(LocalizedStringKey(t("120 m", "120 米")), systemImage: "location")
                    }
                    Text(verbatim: t("Find the Lantern Gate", "找到灯笼门"))
                        .cyText(.display)
                        .foregroundStyle(.primary)
                    Text(verbatim: t("Follow the river and look for red lanterns above a stone arch.",
                                     "沿着河走，找到石拱门上方的红灯笼。"))
                        .cyText(.body).foregroundStyle(.secondary)
                    CYPillButton(LocalizedStringKey(t("I've arrived", "我到了")), action: {})
                    CYSectionHeader(LocalizedStringKey(t("Next stops", "接下来")))
                    CYListRow(LocalizedStringKey(t("Tea House", "茶馆")), meta: LocalizedStringKey(t("Locked until task 2", "完成任务 2 后解锁")), trailing: .none, card: true) { CYRowIcon(systemImage: "lock") }
                    CYListRow(LocalizedStringKey(t("Old Bridge", "老桥")), meta: LocalizedStringKey(t("Locked", "未解锁")), trailing: .none, card: true) { CYRowIcon(systemImage: "lock") }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.top, CYSpacing.xxl)
        }
        .themeDomain(.player)
    }

    // MARK: Roam: title top-left, passport menu, GO

    /// mp-roam r3 (sweep 19:50): the same tab-root chrome as the shipping roam root over a map (d2-roam):
    /// inline 漫游 on the `.bar` material with one ⋯ item, never a hand-drawn large title.
    private var roam: some View {
        NavigationStack {
            roamBody
                .navigationTitle(Text(verbatim: t("Roam", "漫游")))
                .navigationBarTitleDisplayMode(.inline)
                .toolbarBackground(.bar, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: {}) { Label("roam.toolbar.more", systemImage: "ellipsis.circle") }
                    }
                }
        }
    }

    private var roamBody: some View {
        VStack {
            Spacer()
            // Same floating row as the shipping roam root: material circles + the one `.borderedProminent` 走起.
            HStack(spacing: CYSpacing.xl) {
                Button(action: {}) {
                    Label("roam.preflightRules.availability", systemImage: "info").labelStyle(.iconOnly)
                        .modifier(RoamMapGlassControl())
                }
                .buttonStyle(.plain)
                Button(action: {}) { Label("roam.w208.intro.start", systemImage: "figure.walk") }
                    .buttonStyle(.borderedProminent).buttonBorderShape(.capsule).controlSize(.large)
                Button(action: {}) {
                    Label("nearby.title", systemImage: "map").labelStyle(.iconOnly)
                        .modifier(RoamMapGlassControl())
                }
                .buttonStyle(.plain)
            }
            .padding(.bottom, CYSpacing.xxl * 2)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background { CYMapPlaceholder(fog: true).ignoresSafeArea() }
    }

    // MARK: Search map: back + search + locate, callouts, one pill primary

    private var search: some View {
        ZStack {
            CYMapCallout(text: t("Suzhou Creek, solo walk", "苏州河，一个人的散步")).position(x: 260, y: 240)
            CYMapCallout(text: t("Bund at night", "夜色外滩")).position(x: 160, y: 340)
            CYMapCallout(text: t("Old Town: ten hidden spots", "老城厢：十个没人去的地方")).position(x: 230, y: 560)
            VStack(spacing: 0) {
                HStack(spacing: CYSpacing.sm) {
                    CYGlassButton(systemImage: "chevron.left", label: "Back", action: {})
                    CYGlassCapsule {
                        HStack(spacing: CYSpacing.sm) {
                            Image(systemName: "magnifyingglass").accessibilityHidden(true).foregroundStyle(Color.white.opacity(0.6))
                            Text(verbatim: t("Search routes, places", "搜索路线、地点等")).foregroundStyle(Color.white.opacity(0.6))
                                .lineLimit(1).minimumScaleFactor(0.7)
                            Spacer(minLength: 0)
                        }.cyText(.body)
                    }
                    CYGlassButton(systemImage: "location.fill", label: "Locate", action: {})
                }
                .padding(.horizontal, CYSpacing.lg)
                Spacer()
                CYPillButton(LocalizedStringKey(t("View all 8 results", "查看全部 8 个结果")), fullWidth: false, action: {})
                    .padding(.bottom, CYSpacing.xxl * 2)
            }
        }
    }

    // MARK: Live roam: stat strip, pause as the one primary, rules + finish

    private var live: some View {
        VStack {
            CYGlassCapsule {
                HStack(spacing: CYSpacing.xl) {
                    stat("roam.live.stat.time", "00:24:10")
                    stat("roam.live.stat.turf", "3.2%")
                    stat("roam.live.stat.distance", "1.8")
                }.padding(.vertical, CYSpacing.md)
            }
            .padding(.horizontal, CYSpacing.lg)
            Spacer()
            HStack(spacing: CYSpacing.xxl) {
                CYGlassButton(systemImage: "info", label: "Rules", action: {})
                CYGoButton("roam.live.pause", action: {})
                CYGlassButton(systemImage: "flag.checkered", label: "Finish", action: {})
            }
            .padding(.bottom, CYSpacing.xxl * 2)
        }
    }

    private func stat(_ label: LocalizedStringKey, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value).cyText(.sectionTitle, monospacedDigit: true).foregroundStyle(.white)
            Text(label).cyText(.meta).foregroundStyle(Color.white.opacity(0.65))
        }
    }
}
/// DEBUG-only, labelled host: the real `RoamLiveSessionView` driven by the synthetic `RoamLiveFixture`.
struct D6RealLiveHost: View {
    @State private var fixture: RoamLiveFixture?
    var body: some View {
        NavigationStack {
            if let fixture { RoamLiveSessionView(controller: fixture.controller, offlineExample: true) }
        }
        .task { if fixture == nil { fixture = await MainActor.run { RoamLiveFixture() } } }
        .themeDomain(.player).preferredColorScheme(.dark)
    }
}
#endif
