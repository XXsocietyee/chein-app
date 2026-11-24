#if DEBUG
import SwiftUI

/// e5c system-state fixtures (synthetic, DEBUG only): `--design-fixture e5c-<name>`.
/// Names: favorites-empty, notices-empty, projects-empty, offline, error, perm-location, perm-camera, perm-notifications, perm-photos, tabs.
enum E5cFixtures {
    @MainActor static func make(_ name: String) -> AnyView? {
        switch name {
        case "e5c-favorites-empty":
            return wrap(NavigationStack { AccountCollectionFavoritesView(reader: AccountCollectionFixtureReader(scenario: .empty), onOpenTopic: { _ in }) })
        case "e5c-notices-empty":
            return wrap(NavigationStack {
                List { CYEmptyState(systemImage: "bell", "d7.deliveryLog.empty", kind: .notices).listRowBackground(Color.clear).listRowSeparator(.hidden) }
                    .appNavigationTitle("d7.deliveryLog.title").navigationBarTitleDisplayMode(.inline)
            })
        case "e5c-projects-empty":
            return wrap(NavigationStack { List { MyProjectEmptyView(type: "activity").listRowBackground(Color.clear).listRowSeparator(.hidden) }.navigationTitle(Text(verbatim: E5cCopy.t("My projects", "我的项目"))).navigationBarTitleDisplayMode(.inline) })
        case "e5c-offline":
            return wrap(NavigationStack {
                VStack(spacing: CYSpacing.lg) {
                    CYOfflineStrip(onRetry: {}).padding(.horizontal, CYSpacing.lg)
                    CYErrorState(offline: true, onRetry: {})
                    Spacer()
                }.navigationTitle(Text(verbatim: E5cCopy.t("Orders", "订单"))).navigationBarTitleDisplayMode(.inline)
            })
        case "e5c-error":
            return wrap(NavigationStack { VStack { CYErrorState(onRetry: {}); Spacer() }.navigationTitle(Text(verbatim: E5cCopy.t("Messages", "消息"))).navigationBarTitleDisplayMode(.inline) })
        case "e5c-perm-location": return wrap(CYPermissionPriming(kind: .location, onAllow: {}, onNotNow: {}))
        case "e5c-perm-camera": return wrap(CYPermissionPriming(kind: .camera, onAllow: {}, onNotNow: {}))
        case "e5c-perm-notifications": return wrap(CYPermissionPriming(kind: .notifications, onAllow: {}, onNotNow: {}))
        case "e5c-perm-photos": return wrap(CYPermissionPriming(kind: .photos, onAllow: {}, onNotNow: {}))
        case "e5c-perm-denied": return wrap(VStack { Spacer(); CYPermissionDeniedCard(kind: .location, onOpenSettings: {}); Spacer() })
        case "e5c-messages-empty", "e5c-messages-error":
            let scenario: MessagingFixtureScenario = name == "e5c-messages-empty" ? .empty : .error
            return wrap(NavigationStack { MessagingHomeView(reader: MessagingFixtureReader(scenario), expanded: nil, squareDestination: { _ in AnyView(EmptyView()) }) })
        case "e5c-tabs": return wrap(E5cTabsFixture())
        default: return nil
        }
    }
    @MainActor private static func wrap<V: View>(_ v: V) -> AnyView {
        AnyView(v.themeDomain(.player).cyDomainPageBackground().themeDomain(.player).cyScreenStyle().preferredColorScheme(.dark))
    }
}

enum E5cCopy {
    static func t(_ en: String, _ zh: String) -> String { Locale.preferredLanguages.first?.hasPrefix("zh") == true ? zh : en }
}
#endif

#if DEBUG
/// Real tab chrome (`cyDomainTabBar`, `CYDomainTabLabel`, selection haptic) over a large-title list on the layered dark surfaces.
struct E5cTabsFixture: View {
    @State private var selection: RootTab = .roam
    @Environment(\.cyPalette) private var palette
    var body: some View {
        TabView(selection: $selection) {
            ForEach(RootTab.playerTabs, id: \.self) { tab in
                NavigationStack {
                    List {
                        ForEach(0..<8, id: \.self) { i in
                            HStack(spacing: CYSpacing.md) {
                                CYCoverArt(seed: "tab-\(i)", showsDebugLabel: false, cornerRadius: CYRadius.card).frame(width: 52, height: 52)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verbatim: E5cCopy.t("Night market \(i + 1)", "夜市 \(i + 1)")).cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                                    Text(verbatim: E5cCopy.t("0.\(i + 3) km · open late", "0.\(i + 3) 公里 · 营业至深夜")).cyText(.meta).foregroundStyle(palette.textSecondary)
                                }
                            }
                            .padding(.vertical, 4)
                            .listRowBackground(i % 2 == 0 ? palette.bgSurface : palette.bgElevated)
                        }
                    }
                    .navigationTitle(Text(verbatim: E5cCopy.t("Roam", "漫游"))).navigationBarTitleDisplayMode(.inline)
                }
                .tabItem { CYDomainTabLabel(tab: tab, selected: selection, domain: .player) }
                .tag(tab)
            }
        }
        .cyTabSelectionFeedback(selection)
        .cyDomainTabBar(.player)
    }
}
#endif
