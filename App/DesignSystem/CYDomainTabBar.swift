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
        case .home: return CYDomainTabIcon(idle: "house", selected: "house.fill")
        case .roam: return CYDomainTabIcon(idle: "map", selected: "map.fill")
        case .publish: return CYDomainTabIcon(idle: "plus.square", selected: "plus.square.fill")
        case .club: return CYDomainTabIcon(idle: "person.3", selected: "person.3.fill")
        case .mine: return CYDomainTabIcon(idle: "person.crop.circle", selected: "person.crop.circle.fill")
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
            // Merchant light tab bar: transparent -> solid page/white vertical fade, no top stroke.
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
            // Player dark tab bar: transparent -> bgPage dark top-fade gradient (solid fallback when Reduce Transparency).
            let bottomColor = CYDomainPalette(.player).bgPage
            content
                .toolbarBackground(
                    reduceTransparency
                        ? AnyShapeStyle(bottomColor)
                        : AnyShapeStyle(
                            LinearGradient(
                                colors: [bottomColor.opacity(0), bottomColor.opacity(0.96), bottomColor],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        ),
                    for: .tabBar
                )
                .toolbarBackground(.visible, for: .tabBar)
                .toolbarColorScheme(.dark, for: .tabBar)
        }
    }
}

/// Preference key so pushed destinations inside any root tab hide custom floating tab bar chrome
/// alongside SwiftUI's `.toolbar(.hidden, for: .tabBar)`.
struct CYTabBarHiddenPreferenceKey: PreferenceKey {
    static let defaultValue = false
    static func reduce(value: inout Bool, nextValue: () -> Bool) {
        value = value || nextValue()
    }
}

private struct CYTabBarHiddenEnvironmentKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var cyTabBarHidden: Bool {
        get { self[CYTabBarHiddenEnvironmentKey.self] }
        set { self[CYTabBarHiddenEnvironmentKey.self] = newValue }
    }
}

extension View {
    /// Apply once on the root `TabView` of a role (`.player` or `.merchant`).
    func cyDomainTabBar(_ domain: ThemeDomain) -> some View {
        modifier(CYDomainTabBarStyle(domain: domain))
    }

    /// Assigns stable accessibility identifiers to the native `UITabBarItem`s of a `TabView`.
    func cyTabBarAccessibilityIdentifiers(_ identifiers: [String]) -> some View {
        modifier(CYTabBarAccessibilityModifier(identifiers: identifiers))
    }

    /// Hide both the system tab bar and the floating player pill overlay on pushed routes.
    func cyHideTabBar(_ hidden: Bool = true) -> some View {
        modifier(CYHideTabBarModifier(hidden: hidden))
    }
}

private struct CYHideTabBarModifier: ViewModifier {
    let hidden: Bool
    @Environment(\.cyTabBarVisibility) private var visibility
    @State private var token = UUID()

    func body(content: Content) -> some View {
        content
            .toolbar(hidden ? .hidden : .visible, for: .tabBar)
            .preference(key: CYTabBarHiddenPreferenceKey.self, value: hidden)
            .environment(\.cyTabBarHidden, hidden)
            .onAppear {
                if hidden { visibility?.hide(token) } else { visibility?.show(token) }
            }
            .onDisappear {
                if hidden { visibility?.show(token) }
            }
    }
}

/// Custom-rendered root tab bar bar/strip faithful to spec (`top-fade`, unselected 0.6, selected `#7A5CFF` icon)
/// for root tab fixtures and Design Kit comparisons across Player (dark) and Merchant (light).
struct CYRootTabBarStrip: View {
    let tabs: [RootTab]?
    @Binding var selection: RootTab
    @Environment(\.cyPalette) private var palette
    @Environment(\.themeDomain) private var domain

    init(tabs: [RootTab]? = nil, selection: Binding<RootTab>) {
        self.tabs = tabs
        self._selection = selection
    }

    private var activeTabs: [RootTab] {
        tabs ?? (domain == .merchant ? RootTab.allCases : RootTab.playerTabs)
    }

    static func stripTokens(isSelected: Bool, in palette: CYDomainPalette) -> (
        foreground: Color,
        gradientStops: [Color]
    ) {
        let unselectedColor = palette.textPrimary.opacity(Theme.MiniProgramChrome.tabUnselectedOpacity)
        return (
            foreground: isSelected ? palette.tabSelectedTint : unselectedColor,
            gradientStops: [palette.bgPage.opacity(0), palette.bgPage.opacity(0.96), palette.bgPage]
        )
    }

    var body: some View {
        let stripGradient = Self.stripTokens(isSelected: false, in: palette).gradientStops
        HStack(spacing: 0) {
            ForEach(activeTabs, id: \.self) { tab in
                let isSelected = tab == selection
                let fg = Self.stripTokens(isSelected: isSelected, in: palette).foreground
                let icon = CYDomainTabIcons.icon(for: tab, domain: domain)
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: CYSpacing.xs) {
                        Image(systemName: isSelected ? icon.selected : icon.idle)
                            .font(.system(.title3, weight: isSelected ? .semibold : .regular))
                            .foregroundStyle(fg)
                        Text(LocalizedStringKey(CYDomainTabIcons.titleKey(for: tab, domain: domain)))
                            .font(CYTypography.micro.weight(isSelected ? .semibold : .medium))
                            .foregroundStyle(fg)
                            .cyWrapText(alignment: .center)
                    }
                    .frame(maxWidth: .infinity, minHeight: Theme.MiniProgramChrome.minHit)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.horizontal, CYSpacing.sm)
        .padding(.top, CYSpacing.md)
        .padding(.bottom, CYSpacing.sm)
        .background(
            LinearGradient(
                colors: stripGradient,
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct CYTabBarAccessibilityModifier: ViewModifier {
    let identifiers: [String]

    func body(content: Content) -> some View {
        #if canImport(UIKit)
        content.background {
            CYTabBarAccessibilityHost(identifiers: identifiers)
                .allowsHitTesting(false)
        }
        #else
        content
        #endif
    }
}

#if canImport(UIKit)
private struct CYTabBarAccessibilityHost: UIViewRepresentable {
    let identifiers: [String]

    func makeUIView(context: Context) -> CYTabBarAccessibilityAnchor {
        let view = CYTabBarAccessibilityAnchor()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.identifiers = identifiers
        return view
    }

    func updateUIView(_ uiView: CYTabBarAccessibilityAnchor, context: Context) {
        uiView.identifiers = identifiers
        uiView.applyIfNeeded()
    }
}

private final class CYTabBarAccessibilityAnchor: UIView {
    var identifiers: [String] = []
    private weak var cachedTabBar: UITabBar?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        cachedTabBar = nil
        guard window != nil else { return }
        applyIfNeeded()
        DispatchQueue.main.async { [weak self] in self?.applyIfNeeded() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        applyIfNeeded()
    }

    func applyIfNeeded() {
        guard window != nil else { return }
        if cachedTabBar == nil || cachedTabBar?.window == nil {
            cachedTabBar = findEnclosingTabBar()
        }
        guard let tabBar = cachedTabBar,
              tabBar.window != nil,
              let items = tabBar.items,
              items.count == identifiers.count else { return }
        for (item, id) in zip(items, identifiers) where item.accessibilityIdentifier != id {
            item.accessibilityIdentifier = id
        }
    }

    private func findEnclosingTabBar() -> UITabBar? {
        var node: UIView? = self
        while let current = node {
            if let found = CYScreenChrome.findTabBar(in: current) {
                return found
            }
            node = current.superview
        }
        return nil
    }
}
#endif

#if canImport(UIKit)
/// UIKit appearance for the parts SwiftUI cannot style: unselected items at 0.6 opacity
/// (`Theme.MiniProgramChrome.tabUnselectedOpacity`), selected icon/label in the primary ink (neutral, PL-01).
/// Call once at launch (for example from the App initialiser).
@MainActor
enum CYTabBarAppearance {
    static func install() {
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()

        let unselectedAlpha = Theme.MiniProgramChrome.tabUnselectedOpacity
        let unselected = UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: 1, alpha: unselectedAlpha)
                : UIColor(white: 0, alpha: unselectedAlpha)
        }
        // PL-01 (design hand-off r1): neutral selection. Selected = primary ink at full opacity with a Semibold label.
        let selectedInk = UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(white: 0xF8 / 255.0, alpha: 1) : UIColor(white: 0, alpha: 1)
        }
        let selectedFont = UIFont.systemFont(ofSize: 10, weight: .semibold)
        let normalFont = UIFont.systemFont(ofSize: 10, weight: .regular)
        let layouts: [UITabBarItemAppearance] = [
            appearance.stackedLayoutAppearance,
            appearance.inlineLayoutAppearance,
            appearance.compactInlineLayoutAppearance,
        ]
        for layout in layouts {
            layout.normal.iconColor = unselected
            layout.normal.titleTextAttributes = [.foregroundColor: unselected, .font: normalFont]
            layout.selected.iconColor = selectedInk
            layout.selected.titleTextAttributes = [.foregroundColor: selectedInk, .font: selectedFont]
        }

        UITabBar.appearance().tintColor = selectedInk
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
