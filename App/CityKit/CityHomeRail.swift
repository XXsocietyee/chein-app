import SwiftUI
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
    private var copy: CityCopy { CityCopy(locale: locale) }

    var body: some View {
        if store.isAvailable, store.phase == .loaded || !store.mine.isEmpty {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Button(action: onOpenMap) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(verbatim: title).font(Font.title3.weight(.bold)).foregroundStyle(palette.textPrimary)
                        Spacer(minLength: CYSpacing.sm)
                        HStack(spacing: 2) {
                            Text(verbatim: copy("全部", "All"))
                            Image(systemName: "chevron.right").imageScale(.small).accessibilityHidden(true)
                        }
                        .font(CYTypography.meta).foregroundStyle(palette.textSecondary)
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
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: CYSpacing.md) {
                            ForEach(store.mine) { place in
                                Button(action: onOpenMap) { CityDeedCard(place: place, size: .mini) }
                                    .buttonStyle(.plain)
                                    .accessibilityIdentifier("homeFeed.cityRail.\(place.id)")
                            }
                        }
                        .padding(.horizontal, CYSpacing.pageHorizontal)
                    }
                    .padding(.horizontal, -CYSpacing.pageHorizontal)
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
            let center = (try? await session.cityCaptureFix()())?.coordinate ?? session.roamArea?.coordinate
            if let center { await store.load(center: center, radiusMeters: 25_000) }
        }
    }
}
