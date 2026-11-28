import SwiftUI
import CoreLocation
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// 我的地盘 rail on 首页 (P 210:8239, round-1 Q1, SR2-02): header on the page margin (title + 全部),
// then a horizontal row of Deed Minis. Hidden when the viewer has no CITY lease; with a lease and
// no place yet it shows one line that sends the player to the map.

struct CityHomeRail: View {
    @ObservedObject var store: CityBoardStore
    let onOpenMap: () -> Void

    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @QuestifyReduceMotion private var reduceMotion
    private var copy: CityCopy { CityCopy(locale: locale) }

    var body: some View {
        if store.isAvailable, store.phase == .loaded || !store.mine.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Button(action: onOpenMap) {
                    HStack(alignment: .firstTextBaseline) {
                        // Section header on the type scale, like 编辑精选 and 附近活动 above and below it; long titles wrap.
                        Text(verbatim: title).cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
                            .monospacedDigit()
                            .cyWrapText()
                        Spacer(minLength: CYSpacing.sm)
                        HStack(spacing: 2) {
                            Text(verbatim: copy("全部", "All"))
                            Image(systemName: "chevron.right").imageScale(.small).accessibilityHidden(true)
                        }
                        .cyText(.meta).foregroundStyle(palette.textSecondary)
                    }
                    .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(verbatim: title))
                .accessibilityHint(Text(verbatim: copy("打开漫游地图", "Opens the roam map")))
                .accessibilityIdentifier("homeFeed.cityRail.all")
                if store.mine.isEmpty {
                    Button(action: onOpenMap) {
                        CityEmptyLine(symbol: "flag", text: copy("还没有地盘。去漫游地图上圈下第一块地。", "No places yet. Claim your first on the roam map."))
                    }
                    .buttonStyle(.plain)
                } else {
                    // xrefs-1 Adopt 9 (focused card in a rail): cards snap to the margin and the neighbours sit at 94 % / 70 %.
                    // Scroll-linked, so it costs no time; off under Reduce Motion. A place that leaves or arrives on a
                    // refresh fades in place instead of the row jumping.
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: CYSpacing.md) {
                            ForEach(store.mine) { place in
                                Button(action: onOpenMap) { CityDeedCard(place: place, size: .mini) }
                                    .buttonStyle(.cyPressable)
                                    .modifier(CityHomeRailFocus(enabled: !reduceMotion))
                                    .transition(.opacity)
                                    .accessibilityIdentifier("homeFeed.cityRail.\(place.id)")
                            }
                        }
                        .scrollTargetLayout()
                        .padding(.horizontal, CYSpacing.pageHorizontal)
                    }
                    .scrollTargetBehavior(.viewAligned)
                    .scrollClipDisabled()
                    .padding(.horizontal, -CYSpacing.pageHorizontal)
                    .animation(reduceMotion ? nil : CYMotion.standard, value: store.mine.map(\.id))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("homeFeed.cityRail")
        }
    }

    private var title: String {
        if let rent = store.todayRent, rent > 0 { return copy("我的地盘 · 今天 +\(rent)", "My places · today +\(rent)") }
        return copy("我的地盘", "My places")
    }
}

/// Neighbour cards recede (scale 0.94, opacity 0.7) while the focused card stays at full size (xrefs-1 Adopt 9).
private struct CityHomeRailFocus: ViewModifier {
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled {
            content.scrollTransition(.interactive, axis: .horizontal) { view, phase in
                view.scaleEffect(phase.isIdentity ? 1 : 0.94).opacity(phase.isIdentity ? 1 : 0.7)
            }
        } else {
            content
        }
    }
}

/// Session host for the rail: builds the store once per CITY identity and loads a wide window
/// around the player's area (the layer read is capped at 0.5°).
@MainActor struct CitySessionHomeRail: View {
    @EnvironmentObject private var session: AppSession
    let onOpenMap: () -> Void
    @State private var store: CityBoardStore?
    @State private var identity: String?

    var body: some View {
        // A zero-height anchor keeps the task alive while the rail itself is hidden (an empty Group never appears).
        ZStack(alignment: .top) {
            Color.clear.frame(height: 0)
            if let store { CityHomeRail(store: store, onOpenMap: onOpenMap).padding(.top, CYSpacing.lg) }
        }
        .task(id: session.cityPlayerReadIdentity) {
            if identity != session.cityPlayerReadIdentity || store == nil {
                identity = session.cityPlayerReadIdentity
                store = session.makeCityBoardStore()
            }
            guard let store, store.isAvailable else { return }
            // Function audit P2-3: 首页 never asks for location on load. A device fix only when the player already
            // granted it; otherwise the chosen area, and the permission ask stays behind an explicit tap.
            let status = CLLocationManager().authorizationStatus
            let authorized = status == .authorizedWhenInUse || status == .authorizedAlways
            let fix = authorized ? (try? await session.cityCaptureFix()())?.coordinate : nil
            let center = fix ?? session.roamArea?.coordinate
            if let center { await store.load(center: center, radiusMeters: 25_000) }
        }
    }
}
