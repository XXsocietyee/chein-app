import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// CB24: one screen layer for both role roots. Pages do not opt in.
// Player is dark, merchant is light, from `CYDomainPalette` / `themeDomain`.
// Violet stays on the selected tab (`CYTabBarAppearance`); every other tint is the domain brand.
// Controls, identifiers, and copy are left in place. One primary action is not a reason to remove a button.

struct CYScreenStyle: ViewModifier {
    @Environment(\.themeDomain) private var domain

    func body(content: Content) -> some View {
        let palette = CYDomainPalette(domain)
        content
            .cyApplyColorScheme(domain.forcedColorScheme)
            // Unstyled system buttons inherit this. Primary / secondary / tertiary actions stay `CYPillButton`.
            .tint(palette.brand)
            // Native restyle r1 (spec §3.2, §3.6): system bordered buttons are capsules; lists and forms show the
            // system grouped background (no `.scrollContentBackground(.hidden)`), 24 pt between sections.
            .buttonBorderShape(.capsule)
            .listStyle(.insetGrouped)
            .formStyle(.grouped)
            .listSectionSpacing(CYSpacing.xxl)
            .listRowSeparatorTint(palette.borderSubtle)
            .headerProminence(.increased)
            .background(palette.bgPage.ignoresSafeArea())
            .background {
                CYScreenStyleAnchorHost(domain: domain)
                    .allowsHitTesting(false)
            }
            .onAppear { CYScreenChrome.install(domain: domain) }
            .onChange(of: domain) { _, newDomain in
                CYScreenChrome.install(domain: newDomain)
            }
    }
}

extension View {
    /// Apply once at the player root and once at the merchant root.
    func cyScreenStyle() -> some View {
        modifier(CYScreenStyle())
    }

    /// Apply a role/template domain explicitly to any pushed or root screen, forcing its domain palette
    /// regardless of the device's system appearance.
    func cyDomainScreen(_ domain: ThemeDomain) -> some View {
        themeDomain(domain)
            // verify-r2 N-01: the ground is this domain's page colour. `cyDomainPageBackground()` here read the palette
            // from outside `themeDomain`, i.e. the pushing stack's (black under the player shell).
            .background(CYDomainPalette(domain).bgPage.ignoresSafeArea())
            .tint(CYDomainPalette(domain).brand)
    }

    /// Standard chrome for L2+ pushed screens: hides the root tab bar and optionally switches domain.
    func cyPushedChrome(domain: ThemeDomain? = nil) -> some View {
        modifier(CYPushedChromeModifier(domain: domain))
    }

    /// Full-bleed hero pushed chrome: hides the root tab bar, keeps navigation bar transparent,
    /// and overlays the 32pt glass-pill back button ONLY over the hero edge.
    func cyHeroPushedChrome(domain: ThemeDomain? = nil, backAccessibilityIdentifier: String? = nil, onBack: (() -> Void)? = nil) -> some View {
        modifier(CYHeroPushedChromeModifier(domain: domain, backAccessibilityIdentifier: backAccessibilityIdentifier, onBack: onBack))
    }
}

extension View {
    /// verify-r1 1.3 / N-10: hero pages carry no centred page-type title (活动详情, 俱乐部详情). Once the hero has
    /// scrolled away, the navigation bar shows the object's own name inline. Apply to the page's List or ScrollView.
    /// Before iOS 18 the title stays hidden (no scroll geometry); the back control is in the bar either way.
    @ViewBuilder
    func cyTracksHeroScroll(_ scrolledAway: Binding<Bool>, threshold: CGFloat = 220) -> some View {
        if #available(iOS 18, *) {
            onScrollGeometryChange(for: Bool.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top > threshold
            } action: { _, away in
                if scrolledAway.wrappedValue != away { scrolledAway.wrappedValue = away }
            }
        } else {
            self
        }
    }
}

// MARK: - Title and back rules (consist-1, docs/design/type-and-chrome.md)
//
// Title: tab roots -> `cyRootHeader(_:)` (system large title). Pushed pages -> `cyPageTitle(_:)` (system inline title,
// 17 pt semibold, drawn by the navigation bar). Sheets -> `CYSheetHeader` (player / editor / merchant styles).
// Back: the system back button in the navigation bar, with its swipe-from-edge gesture. Two sanctioned exceptions:
// `cyGuardedBack(when:onBack:)` for unsaved-edit exit guards, and `cyHeroChrome(heroScrolledAway:)` + `CYHeroBackButton`
// in the hero overlay for full-bleed hero images. `tools/check_typography_lint.py` fails any new custom back chevron
// or `navigationBarBackButtonHidden(true)` outside this file.

extension View {
    /// Pushed page title: the system inline title (17 pt semibold, Dynamic Type, drawn by the navigation bar).
    /// Do not draw a second page-type title in the content; an object's own name (a club, an activity) may stay
    /// in the content as `.cyText(.pageTitle)`.
    func cyPageTitle(_ key: String.LocalizationValue) -> some View {
        appNavigationTitle(key).navigationBarTitleDisplayMode(.inline)
    }

    /// Pushed page title from server text (an object's name).
    func cyPageTitle(verbatim title: String) -> some View {
        navigationTitle(title).navigationBarTitleDisplayMode(.inline)
    }

    /// The one way to intercept back for an unsaved-edit guard. While `isGuarded` is false the page keeps the system
    /// back button and its swipe gesture; while it is true the bar shows the same-looking `CYBareBackButton`, which
    /// calls `onBack` (show the discard confirmation there), and the edge swipe is blocked so edits are not lost.
    func cyGuardedBack(when isGuarded: Bool, onBack: @escaping () -> Void) -> some View {
        navigationBarBackButtonHidden(isGuarded)
            .toolbar {
                if isGuarded {
                    ToolbarItem(placement: .topBarLeading) { CYBareBackButton(action: onBack) }
                }
            }
    }

    /// Full-bleed hero page chrome. While the hero is on screen the navigation bar is hidden and the page shows
    /// `CYHeroBackButton` inside the hero's own top-leading overlay, so the glass circle scrolls away with the image.
    /// Once `heroScrolledAway` (from `cyTracksHeroScroll`) turns true the bar returns with the system back button and
    /// the object's inline title. The edge swipe keeps working in both states (`cyKeepsSwipeBack()`).
    func cyHeroChrome(heroScrolledAway: Bool, domain: ThemeDomain? = nil) -> some View {
        cyPushedChrome(domain: domain)
            .toolbar(heroScrolledAway ? .visible : .hidden, for: .navigationBar)
            .cyKeepsSwipeBack()
    }

    /// Keeps the swipe-from-edge back gesture working on a pushed page whose navigation bar is hidden.
    /// Not for exit-guarded pages; those block the swipe on purpose.
    func cyKeepsSwipeBack() -> some View {
        #if canImport(UIKit)
        return background {
            CYSwipeBackHost()
                .frame(width: 0, height: 0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        #else
        return self
        #endif
    }
}

#if canImport(UIKit)
private struct CYSwipeBackHost: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> CYSwipeBackController {
        CYSwipeBackController()
    }

    func updateUIViewController(_ controller: CYSwipeBackController, context: Context) {
        controller.attach()
    }
}

private final class CYSwipeBackController: UIViewController {
    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        attach()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        attach()
    }

    func attach() {
        guard let navigation = navigationController, let pop = navigation.interactivePopGestureRecognizer else { return }
        CYSwipeBackGate.install(on: navigation, gesture: pop)
    }
}

/// One gate per navigation controller, kept alive by the controller itself. It only refuses the swipe on the root
/// page (where a pop would leave the stack in a broken state); every pushed page may swipe back.
@MainActor
private final class CYSwipeBackGate: NSObject, UIGestureRecognizerDelegate {
    private static var key: UInt8 = 0
    private weak var navigation: UINavigationController?

    private init(navigation: UINavigationController) {
        self.navigation = navigation
    }

    static func install(on navigation: UINavigationController, gesture: UIGestureRecognizer) {
        let gate: CYSwipeBackGate
        if let existing = objc_getAssociatedObject(navigation, &key) as? CYSwipeBackGate {
            gate = existing
        } else {
            gate = CYSwipeBackGate(navigation: navigation)
            objc_setAssociatedObject(navigation, &key, gate, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        if gesture.delegate !== gate { gesture.delegate = gate }
        gesture.isEnabled = true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        (navigation?.viewControllers.count ?? 0) > 1
    }
}
#endif

/// Global back-navigation chrome variants per DESIGN.md §7.1.
enum CYBackNavigationStyle {
    /// Bare chevron in a 44×44pt hit target for L2+ standard/solid pages.
    case bareChevron
    /// 32pt translucent glass circle in a 44×44pt hit target, restricted to full-bleed hero banners.
    case heroGlassPill
}

/// Bare chevron back button (44×44pt hit target, no capsule/circle fill) for L2+ plain/solid headers.
struct CYBareBackButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.cyPalette) private var palette
    var label: LocalizedStringKey = "action.back"
    var action: (() -> Void)? = nil

    init(label: LocalizedStringKey = "action.back", action: (() -> Void)? = nil) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button {
            if let action { action() } else { dismiss() }
        } label: {
            Image(systemName: "chevron.backward")
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.textPrimary)
                .frame(minWidth: Theme.MiniProgramChrome.minHit, minHeight: Theme.MiniProgramChrome.minHit)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// 32pt translucent glass circular back button (centered in 44×44pt hit target) for full-bleed heroes ONLY.
struct CYHeroBackButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var label: LocalizedStringKey = "action.back"
    var action: (() -> Void)? = nil

    init(label: LocalizedStringKey = "action.back", action: (() -> Void)? = nil) {
        self.label = label
        self.action = action
    }

    var body: some View {
        Button {
            if let action { action() } else { dismiss() }
        } label: {
            Image(systemName: "chevron.backward")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.white)
                .frame(width: 32, height: 32)
                .background {
                    if reduceTransparency {
                        Circle().fill(CYDomainPalette(.player).bgElevated)
                    } else {
                        Circle().fill(.ultraThinMaterial)
                            .overlay(Circle().fill(CYDomainPalette(.player).bgGlass.opacity(0.45)))
                    }
                }
                .frame(minWidth: Theme.MiniProgramChrome.minHit, minHeight: Theme.MiniProgramChrome.minHit)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Pinned bottom footer bar (`cy-footer-bar`) for detail, checkout, and form pages:
/// `bg-page` canvas background, optional 0.5pt `borderSubtle` hairline, and 12pt/16pt safe-area padding.
struct CYFooterBar<Actions: View>: View {
    @Environment(\.cyPalette) private var palette
    var showsDivider: Bool = true
    @ViewBuilder let actions: () -> Actions

    init(showsDivider: Bool = true, @ViewBuilder actions: @escaping () -> Actions) {
        self.showsDivider = showsDivider
        self.actions = actions
    }

    var body: some View {
        VStack(spacing: 0) {
            if showsDivider {
                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(height: 0.5)
                    .accessibilityHidden(true)
            }
            actions()
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.md)
        }
        .frame(maxWidth: .infinity)
        .background(palette.bgPage.ignoresSafeArea(edges: .bottom))
    }
}

extension CYFooterBar where Actions == CYPillButton {
    /// Pinned footer bar with a single full-width pill CTA.
    init(_ title: LocalizedStringKey, systemImage: String? = nil, showsDivider: Bool = true, action: @escaping () -> Void) {
        self.init(showsDivider: showsDivider) {
            CYPillButton(title, style: .primary, systemImage: systemImage, action: action)
        }
    }
}

private struct CYPushedChromeModifier: ViewModifier {
    let domain: ThemeDomain?

    func body(content: Content) -> some View {
        let base = content.cyHideTabBar(true)
        if let domain {
            base.themeDomain(domain)
                .tint(CYDomainPalette(domain).brand)
                // verify-r2 N-01: the navigation bar belongs to the NavigationStack, which inherits the shell's scheme.
                // While this page is on top, the bar (and its back button) takes the page's scheme.
                .toolbarColorScheme(domain.forcedColorScheme, for: .navigationBar)
        } else {
            base
        }
    }
}

private struct CYHeroPushedChromeModifier: ViewModifier {
    let domain: ThemeDomain?
    let backAccessibilityIdentifier: String?
    let onBack: (() -> Void)?
    @Environment(\.dismiss) private var dismiss

    // verify-r1 1.3 / N-10 (HIG Layout, safe areas): the back control lives in the navigation bar. It used to be a
    // screen overlay under the bar, so it stayed put while the page scrolled and covered headings ("戊员身份"). In the bar
    // it is transparent over the hero at the top edge and the bar settles into the page colour (scroll-edge effect) once
    // the hero has scrolled away. The identifier and custom action are kept for tests and guarded exits.
    func body(content: Content) -> some View {
        content.cyPushedChrome(domain: domain)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { heroBack }
            }
    }

    @ViewBuilder private var heroBack: some View {
        let button = Button {
            if let onBack { onBack() } else { dismiss() }
        } label: {
            Image(systemName: "chevron.backward")
                .font(.body.weight(.semibold))
                .frame(minWidth: Theme.MiniProgramChrome.minHit, minHeight: Theme.MiniProgramChrome.minHit)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(Text("action.back"))
        if let backAccessibilityIdentifier {
            button.accessibilityIdentifier(backAccessibilityIdentifier)
        } else {
            button
        }
    }
}

#if canImport(UIKit)
enum CYScreenChrome {
    static func install(domain: ThemeDomain) {
        let palette = CYDomainPalette(domain)
        let page = UIColor(palette.bgPage)
        let title = UIColor(palette.textPrimary)
        let hairline = UIColor(palette.borderSubtle)
        let brand = UIColor(palette.brand)

        // Scrolled: opaque page colour + hairline. At the top edge: transparent, so a large title sits on the page
        // with no rule under it (the system large-title behaviour), and the bar settles into the hairline on scroll.
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = page
        nav.shadowColor = hairline
        nav.titleTextAttributes = [.foregroundColor: title]
        nav.largeTitleTextAttributes = [.foregroundColor: title]
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.titleTextAttributes = [.foregroundColor: title]
        edge.largeTitleTextAttributes = [.foregroundColor: title]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = nav
        bar.scrollEdgeAppearance = edge
        bar.compactAppearance = nav
        bar.compactScrollEdgeAppearance = nav
        bar.tintColor = brand

        let header = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
        header.textColor = UIColor(palette.textSecondary)

        // Selected tab stays violet. `CYTabBarAppearance.install()` owns the unselected 45% label.
        UITabBar.appearance().tintColor = UIColor(palette.tabSelectedTint)
    }

    /// Status bar for the window's arbitrated scheme (coordinator review: a light page pushed from the dark player shell
    /// kept a white status bar). The navigation controller, not the page, owns the status bar while its bar is visible,
    /// and its bar inherited the shell's dark style; so the bar style and the window style both follow the scheme, and
    /// every controller re-reads its status bar style.
    @MainActor
    static func syncStatusBar(for scheme: ColorScheme) {
        let style: UIUserInterfaceStyle = scheme == .light ? .light : .dark
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        DispatchQueue.main.async {
            for window in windows where !window.isHidden {
                if window.overrideUserInterfaceStyle != style { window.overrideUserInterfaceStyle = style }
                if let root = window.rootViewController { syncStatusBar(root, style: style) }
            }
        }
    }

    @MainActor
    private static func syncStatusBar(_ controller: UIViewController, style: UIUserInterfaceStyle) {
        // Presented controllers (sheets) own their scheme; only the in-window stack follows the page.
        if let navigation = controller as? UINavigationController {
            let barStyle: UIBarStyle = style == .light ? .default : .black
            if navigation.navigationBar.barStyle != barStyle { navigation.navigationBar.barStyle = barStyle }
        }
        for child in controller.children { syncStatusBar(child, style: style) }
        controller.setNeedsStatusBarAppearanceUpdate()
    }

    /// verify-r2 N-01: retint every navigation bar in the foreground windows for the window's current scheme.
    @MainActor
    static func retintNavigationBars(for scheme: ColorScheme, role: RoleTheme) {
        let domain: ThemeDomain = scheme == role.colorScheme ? role.domain : (scheme == .light ? .merchant : .player)
        let tint = UIColor(scheme == role.colorScheme ? CYDomainPalette(domain).brand : CYDomainPalette(domain).textPrimary)
        let windows = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.flatMap(\.windows)
        DispatchQueue.main.async {
            for window in windows { retint(window, tint: tint) }
        }
    }

    private static func retint(_ view: UIView, tint: UIColor) {
        let typeName = NSStringFromClass(type(of: view))
        if typeName.contains("MKMapView") || typeName.contains("WKWebView") { return }
        if let bar = view as? UINavigationBar { bar.tintColor = tint; return }
        for subview in view.subviews { retint(subview, tint: tint) }
    }

    static func correct(_ view: UIView, domain: ThemeDomain) {
        let typeName = NSStringFromClass(type(of: view))
        // Map and web tiles are not screen chrome, and walking them is wasted work.
        if typeName.contains("MKMapView") || typeName.contains("WKWebView") { return }
        let palette = CYDomainPalette(effectiveDomain(for: view, rootDomain: domain))
        if let tab = view as? UITabBar {
            let violet = UIColor(palette.tabSelectedTint)
            if !same(tab.tintColor, violet, traits: tab.traitCollection) {
                tab.tintColor = violet
            }
            return
        }
        if let nav = view as? UINavigationBar {
            apply(nav, palette: palette)
            return
        }
        if let collection = view as? UICollectionView {
            apply(collection, palette: palette)
        }
        if let cell = view as? UICollectionViewListCell {
            apply(cell, palette: palette)
        }
        for subview in view.subviews {
            correct(subview, domain: domain)
        }
    }

    private static func effectiveDomain(for view: UIView, rootDomain: ThemeDomain) -> ThemeDomain {
        let style = view.traitCollection.userInterfaceStyle
        if rootDomain.colorScheme == .dark && style == .light { return .merchant }
        if rootDomain.colorScheme == .light && style == .dark { return .player }
        return rootDomain
    }

    private static func apply(_ nav: UINavigationBar, palette: CYDomainPalette) {
        let traits = nav.traitCollection
        let current = nav.standardAppearance.backgroundColor
        guard isReplaceable(current, traits: traits, palette: palette) else { return }
        let page = UIColor(palette.bgPage)
        guard !same(current, page, traits: traits) || !same(nav.tintColor, UIColor(palette.brand), traits: traits) else { return }
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = page
        appearance.shadowColor = UIColor(palette.borderSubtle)
        appearance.titleTextAttributes = [.foregroundColor: UIColor(palette.textPrimary)]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor(palette.textPrimary)]
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        edge.titleTextAttributes = [.foregroundColor: UIColor(palette.textPrimary)]
        edge.largeTitleTextAttributes = [.foregroundColor: UIColor(palette.textPrimary)]
        nav.standardAppearance = appearance
        nav.scrollEdgeAppearance = edge
        nav.compactAppearance = appearance
        nav.compactScrollEdgeAppearance = edge
        nav.tintColor = UIColor(palette.brand)
    }

    private static func apply(_ collection: UICollectionView, palette: CYDomainPalette) {
        let traits = collection.traitCollection
        guard isReplaceable(collection.backgroundColor, traits: traits, palette: palette) else { return }
        let page = UIColor(palette.bgPage)
        if !same(collection.backgroundColor, page, traits: traits) {
            collection.backgroundColor = page
        }
        let headers = collection.visibleSupplementaryViews(ofKind: UICollectionView.elementKindSectionHeader)
        for header in headers {
            styleSectionHeader(header, palette: palette)
        }
    }

    private static func apply(_ cell: UICollectionViewListCell, palette: CYDomainPalette) {
        let traits = cell.traitCollection
        var config = cell.backgroundConfiguration ?? .listGroupedCell()
        guard isReplaceable(config.backgroundColor, traits: traits, palette: palette) else { return }
        let card = UIColor(palette.cardFill)
        guard !same(config.backgroundColor, card, traits: traits) else { return }
        config.backgroundColor = card
        cell.backgroundConfiguration = config
    }

    /// System section headers only: one secondary label. Custom headers keep their own color and font.
    private static func styleSectionHeader(_ view: UIView, palette: CYDomainPalette) {
        let labels = labels(in: view)
        guard labels.count == 1 else { return }
        let label = labels[0]
        let traits = label.traitCollection
        let secondary = UIColor.secondaryLabel.resolvedColor(with: traits)
        let current = label.textColor.resolvedColor(with: traits)
        guard current.isEqual(secondary) else { return }
        label.textColor = UIColor(palette.textSecondary)
        label.font = UIFontMetrics(forTextStyle: .subheadline).scaledFont(for: .systemFont(ofSize: 15, weight: .semibold))
    }

    private static func labels(in view: UIView) -> [UILabel] {
        var found: [UILabel] = []
        if let label = view as? UILabel { found.append(label) }
        for subview in view.subviews { found.append(contentsOf: labels(in: subview)) }
        return found
    }

    private static func isReplaceable(_ color: UIColor?, traits: UITraitCollection, palette: CYDomainPalette) -> Bool {
        guard let color else { return true }
        if isSystemChrome(color, traits: traits) { return true }
        let resolved = color.resolvedColor(with: traits)
        return ownedColors(palette).contains { $0.resolvedColor(with: traits).isEqual(resolved) }
    }

    private static func isSystemChrome(_ color: UIColor, traits: UITraitCollection) -> Bool {
        let resolved = color.resolvedColor(with: traits)
        let system: [UIColor] = [
            .systemBackground,
            .secondarySystemBackground,
            .tertiarySystemBackground,
            .systemGroupedBackground,
            .secondarySystemGroupedBackground,
            .tertiarySystemGroupedBackground,
        ]
        return system.contains { $0.resolvedColor(with: traits).isEqual(resolved) }
    }

    private static func ownedColors(_ palette: CYDomainPalette) -> [UIColor] {
        let player = CYDomainPalette(.player)
        let merchant = CYDomainPalette(.merchant)
        return [
            UIColor(player.bgPage), UIColor(merchant.bgPage),
            UIColor(player.cardFill), UIColor(merchant.cardFill),
            UIColor(player.bgSurface), UIColor(merchant.bgSurface),
            UIColor(palette.bgPage), UIColor(palette.cardFill),
        ]
    }

    static func colorsMatch(_ color: UIColor?, _ other: UIColor, traits: UITraitCollection) -> Bool {
        guard let color else { return false }
        return color.resolvedColor(with: traits).isEqual(other.resolvedColor(with: traits))
    }

    static func findTabBar(in view: UIView) -> UITabBar? {
        if let tab = view as? UITabBar { return tab }
        let typeName = NSStringFromClass(type(of: view))
        if typeName.contains("MKMapView") || typeName.contains("WKWebView") { return nil }
        for subview in view.subviews {
            if let tab = findTabBar(in: subview) { return tab }
        }
        return nil
    }

    private static func same(_ color: UIColor?, _ other: UIColor, traits: UITraitCollection) -> Bool {
        colorsMatch(color, other, traits: traits)
    }
}

private struct CYScreenStyleAnchorHost: UIViewRepresentable {
    let domain: ThemeDomain

    func makeUIView(context: Context) -> CYScreenStyleAnchor {
        let view = CYScreenStyleAnchor()
        view.isUserInteractionEnabled = false
        view.backgroundColor = .clear
        view.isAccessibilityElement = false
        view.domain = domain
        return view
    }

    func updateUIView(_ uiView: CYScreenStyleAnchor, context: Context) {
        uiView.domain = domain
    }
}

private final class CYScreenStyleAnchor: UIView {
    var domain: ThemeDomain = .player {
        didSet { if oldValue != domain { tabBar = nil } }
    }
    private weak var tabBar: UITabBar?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        tabBar = nil
        guard window != nil else { return }
        refresh()
        DispatchQueue.main.async { [weak self] in self?.refresh() }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        retintCachedTabBar()
    }

    private func refresh() {
        guard let window else { return }
        if tabBar == nil || tabBar?.window == nil {
            tabBar = CYScreenChrome.findTabBar(in: window)
        }
        retintCachedTabBar()
        CYScreenChrome.correct(window, domain: domain)
    }

    private func retintCachedTabBar() {
        guard let tabBar, tabBar.window != nil else { return }
        let violet = UIColor(CYDomainPalette(domain).tabSelectedTint)
        if !CYScreenChrome.colorsMatch(tabBar.tintColor, violet, traits: tabBar.traitCollection) {
            tabBar.tintColor = violet
        }
    }
}
#endif

private struct CYScreenStylePreviewBody: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    CYListRow("Wallet", meta: "Balance and coupons", trailing: .value("—")) {
                        CYRowIcon(systemImage: "creditcard")
                    }
                    CYListRow("Tickets", meta: "3 active")
                } header: {
                    Text(verbatim: "Account")
                }
                Section {
                    CYPillButton("Continue", action: {})
                    CYPillButton("Not now", style: .secondary, fullWidth: false, action: {})
                    CYPillButton("Skip for now", style: .tertiary, fullWidth: false, action: {})
                } header: {
                    Text(verbatim: "Actions")
                }
            }
            .navigationTitle(Text(verbatim: "Screen"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview("Screen · player dark") {
    CYScreenStylePreviewBody()
        .cyScreenStyle()
        .themeDomain(.player)
}

#Preview("Screen · merchant light") {
    CYScreenStylePreviewBody()
        .cyScreenStyle()
        .themeDomain(.merchant)
}
