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
            .environment(\.colorScheme, domain.colorScheme)
            .preferredColorScheme(domain.colorScheme)
            // Unstyled system buttons inherit this. Primary / secondary / tertiary actions stay `CYPillButton`.
            .tint(palette.brand)
            .buttonBorderShape(.roundedRectangle(radius: Theme.Radius.md))
            .listStyle(.insetGrouped)
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)
            .listSectionSpacing(CYSpacing.md)
            .listRowSeparatorTint(palette.borderSubtle)
            .headerProminence(.increased)
            .containerBackground(palette.bgPage, for: .navigation)
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
}

#if canImport(UIKit)
enum CYScreenChrome {
    static func install(domain: ThemeDomain) {
        let palette = CYDomainPalette(domain)
        let page = UIColor(palette.bgPage)
        let title = UIColor(palette.textPrimary)
        let hairline = UIColor(palette.borderSubtle)
        let brand = UIColor(palette.brand)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = page
        nav.shadowColor = hairline
        nav.titleTextAttributes = [.foregroundColor: title]
        nav.largeTitleTextAttributes = [.foregroundColor: title]

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = nav
        bar.scrollEdgeAppearance = nav
        bar.compactAppearance = nav
        bar.compactScrollEdgeAppearance = nav
        bar.tintColor = brand

        let header = UILabel.appearance(whenContainedInInstancesOf: [UITableViewHeaderFooterView.self])
        header.textColor = UIColor(palette.textSecondary)

        // Selected tab stays violet. `CYTabBarAppearance.install()` owns the unselected 45% label.
        UITabBar.appearance().tintColor = UIColor(palette.tabSelectedTint)
    }

    static func correct(_ view: UIView, domain: ThemeDomain) {
        let typeName = NSStringFromClass(type(of: view))
        // Map and web tiles are not screen chrome, and walking them is wasted work.
        if typeName.contains("MKMapView") || typeName.contains("WKWebView") { return }
        let palette = CYDomainPalette(domain)
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
        nav.standardAppearance = appearance
        nav.scrollEdgeAppearance = appearance
        nav.compactAppearance = appearance
        nav.compactScrollEdgeAppearance = appearance
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
        guard labels.count == 1, let label = labels[0] else { return }
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
