import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// UI-F10: native TabView styling that follows the mini-program bottom bar.
//
// Source of truth (mini-program):
//   - `custom-tab-bar/` is an EMPTY shim; the real bar is `components/tabBar` (`CONSUMER_LIST` / `MERCHANT_LIST`).
//   - Player order (W1-1): Explore / Roam / Clubs / Passport -> RootTab.playerTabs (.home .roam .club .mine); Publish is an Explore "+" entry
//   - Merchant order: 工作台 / 营销 / 模板 / 合作 / 我的 -> RootTabBarParity.merchantTabs (Core/HomeSearchTabParity.swift)
//   Both lists already exist natively with the same count/order/titles (QuestifyApp.swift TabView and
//   SessionMerchantRootContainerView), so NO tab structure change is needed. What was missing is the bar
//   *styling*: selected = violet `#7A5CFF`, unselected = 45% opacity of the label colour, glass bar with a
//   hairline top border on player, transparent-to-white gradient with no border on merchant.
//
// This file adds the styling as opt-in modifiers; wiring them onto the two TabViews is a one-line change
// at each root (`.cyDomainTabBar(.player)` / `.cyDomainTabBar(.merchant)`), which is outside this agent's
// scope (QuestifyApp.swift / HomeSearchTabParityViews.swift are on the never-edit list).

/// Icon intent for one mini-program tab, expressed as SF Symbols (outline when idle, fill when selected).
struct CYDomainTabIcon: Equatable {
    let idle: String
    let selected: String
}

enum CYDomainTabIcons {
    /// Player bar. Mini-program icons: icon_f1 (home), icon_roam (map pin), icon_f3 (publish / plus tile),
    /// icon_f4 (club / group), icon_f5 (me). Matches `RootTab.systemImage` for the idle glyph.
    static func player(_ tab: RootTab) -> CYDomainTabIcon {
        switch tab {
        case .home: return CYDomainTabIcon(idle: "sparkles", selected: "sparkles")
        case .roam: return CYDomainTabIcon(idle: "map", selected: "map.fill")
        case .publish: return CYDomainTabIcon(idle: "plus.square", selected: "plus.square.fill")
        case .club: return CYDomainTabIcon(idle: "person.3", selected: "person.3.fill")
        case .mine: return CYDomainTabIcon(idle: "book.closed", selected: "book.closed.fill")
        }
    }

    /// Merchant bar. Mini-program icons: icon_tab_workbench / marketing / template / relation / mine (24 grid, 1.8 stroke).
    /// Index order is the merchant order; the `RootTab` slot mirrors `RootTabBarParity.merchantTabs`.
    static func merchant(_ tab: RootTab) -> CYDomainTabIcon {
        switch tab {
        case .home: return CYDomainTabIcon(idle: "square.grid.2x2", selected: "square.grid.2x2.fill")
        case .roam: return CYDomainTabIcon(idle: "megaphone", selected: "megaphone.fill")
        case .publish: return CYDomainTabIcon(idle: "plus.square", selected: "plus.square.fill")
        case .club: return CYDomainTabIcon(idle: "person.2", selected: "person.2.fill")
        case .mine: return CYDomainTabIcon(idle: "person.crop.circle", selected: "person.crop.circle.fill")
        }
    }

    static func icon(for tab: RootTab, domain: ThemeDomain) -> CYDomainTabIcon {
        domain == .merchant ? merchant(tab) : player(tab)
    }

    /// Localisation key for the tab title (existing catalog keys `tabBar.*` / `tabBar.merchant.*`).
    static func titleKey(for tab: RootTab, domain: ThemeDomain) -> String {
        guard domain == .merchant else { return tab.playerTitleKey }
        switch tab {
        case .home: return "tabBar.merchant.workbench"
        case .roam: return "tabBar.merchant.marketing"
        case .publish: return "tabBar.merchant.templates"
        case .club: return "tabBar.merchant.cooperation"
        case .mine: return tab.titleKey // merchant bar keeps 我的
        }
    }
}

/// A tab label that picks the idle / filled glyph from selection, as the mini-program swaps
/// `iconPath` / `selectedIconPath`. Use inside `.tabItem { CYDomainTabLabel(tab:selected:domain:) }`.
struct CYDomainTabLabel: View {
    let tab: RootTab
    let selected: RootTab
    let domain: ThemeDomain

    var body: some View {
        let icon = CYDomainTabIcons.icon(for: tab, domain: domain)
        Label(
            LocalizedStringKey(CYDomainTabIcons.titleKey(for: tab, domain: domain)),
            systemImage: tab == selected ? icon.selected : icon.idle
        )
    }
}

/// Styles a native `TabView` like the mini-program bar for a role domain.
struct CYDomainTabBarStyle: ViewModifier {
    let domain: ThemeDomain
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    func body(content: Content) -> some View {
        if domain == .merchant {
            // components/tabBar/index.wxss `.tabbar.merchant .list`: 0 -> .96 white vertical gradient, no blur,
            // no top border, no shadow. Selected violet is `CYTabBarAppearance` / `CYScreenStyle`, not this tint.
            content
                .toolbarBackground(
                    LinearGradient(
                        colors: [Color.white.opacity(0), Color.white.opacity(0.96)],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    for: .tabBar
                )
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.light, for: .tabBar)
        } else {
            // `.tabbar.dark .list`: rgba(28,28,30,.55) glass + blur(40rpx) + 0.5pt subtle top border.
            // Content tint is `CYScreenStyle` (domain brand). Selected tab violet is the appearance proxy.
            content
                .toolbarBackground(reduceTransparency ? AnyShapeStyle(Color(white: 0.06)) : AnyShapeStyle(.ultraThinMaterial), for: .tabBar)
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        }
    }
}

extension View {
    /// Apply once on the root `TabView` of a role (`.player` or `.merchant`).
    func cyDomainTabBar(_ domain: ThemeDomain) -> some View {
        modifier(CYDomainTabBarStyle(domain: domain))
    }
}

#if canImport(UIKit)
/// UIKit appearance for the parts SwiftUI cannot style: unselected items at 45% label colour
/// (`.tabbar__icon { opacity: .45 }`). Call once at launch (for example from the App initialiser).
@MainActor
enum CYTabBarAppearance {
    static func install() {
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        let unselected = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: 0.45)
                : UIColor(white: 0, alpha: 0.45)
        }
        let layouts: [UITabBarItemAppearance] = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ]
        for layout in layouts {
            layout.normal.iconColor = unselected
            layout.normal.titleTextAttributes = [.foregroundColor: unselected]
            // Violet appears only on the selected tab; everything else inherits the neutral tint.
            let selectedViolet = UIColor(red: 122.0/255, green: 92.0/255, blue: 255.0/255, alpha: 1)
            layout.selected.iconColor = selectedViolet
            layout.selected.titleTextAttributes = [.foregroundColor: selectedViolet]
        }

        let selectedViolet = UIColor(red: 122.0/255, green: 92.0/255, blue: 255.0/255, alpha: 1)
        UITabBar.appearance().tintColor = selectedViolet
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }
}
#endif

// MARK: - Previews (synthetic, preview-only; tab titles use existing catalog keys)

private struct CYDomainTabBarPreview: View {
    let domain: ThemeDomain
    @State private var selection: RootTab = .home

    var body: some View {
        TabView(selection: $selection) {
            ForEach(domain == .merchant ? RootTab.allCases : RootTab.playerTabs, id: \.self) { tab in
                Text(verbatim: "Tab \(tab.rawValue + 1)")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .cyDomainPageBackground()
                    .tabItem { CYDomainTabLabel(tab: tab, selected: selection, domain: domain) }
                    .tag(tab)
            }
        }
        .cyScreenStyle()
        .cyDomainTabBar(domain)
        .themeDomain(domain)
    }
}

#Preview("Player tab bar (dark)") {
    CYDomainTabBarPreview(domain: .player)
}

#Preview("Merchant tab bar (light)") {
    CYDomainTabBarPreview(domain: .merchant)
}

// MARK: - Selection haptic and close affordance (e5c)

extension View {
    /// Light selection tick when the root tab changes. Apply once on the root `TabView`, passing the selection it binds.
    /// No haptic on first appearance. Honors the system haptics setting through `.sensoryFeedback`.
    func cyTabSelectionFeedback<T: Equatable>(_ selection: T) -> some View {
        sensoryFeedback(.selection, trigger: selection)
    }
}

/// One close affordance for modal screens: a 44pt circular xmark in the leading/trailing cancellation slot,
/// always labelled "Close" for VoiceOver. Back stays the system chevron (never custom) on pushed screens.
struct CYCloseToolbarButton: ToolbarContent {
    let action: () -> Void
    var body: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button(action: action) {
                Image(systemName: "xmark").font(.footnote.weight(.bold))
                    .frame(width: 44, height: 44).contentShape(Circle())
            }
            .accessibilityLabel(Text("action.close"))
        }
    }
}
