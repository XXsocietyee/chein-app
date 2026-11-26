import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Explicit domain roots, independent of the device's current appearance.
enum ThemeDomain: String, CaseIterable {
    case player, merchant, topicEditor, dark, game

    /// The role's nominal appearance (kept for callers that branch on the role, e.g. palette fallbacks).
    var colorScheme: ColorScheme {
        switch self {
        case .player, .dark, .game: return .dark
        case .merchant, .topicEditor: return .light
        }
    }

    /// Native iOS r2 (owner 2026-11-26: "native UI components, identical to Apple's"): player, merchant and editor
    /// screens follow the system Light/Dark setting like Apple's own apps. Only the play stage (`.game`) and explicit
    /// `.dark` surfaces stay dark. `nil` = follow the system.
    var forcedColorScheme: ColorScheme? {
        switch self {
        case .dark, .game: return .dark
        case .player, .merchant, .topicEditor: return nil
        }
    }
}

extension View {
    /// Applies a forced scheme when the domain has one; otherwise leaves the system appearance alone.
    @ViewBuilder func cyApplyColorScheme(_ scheme: ColorScheme?) -> some View {
        if let scheme {
            self.environment(\.colorScheme, scheme).preferredColorScheme(scheme)
        } else {
            self
        }
    }
}

private struct ThemeDomainKey: EnvironmentKey {
    static let defaultValue = ThemeDomain.player
}

extension EnvironmentValues {
    var themeDomain: ThemeDomain {
        get { self[ThemeDomainKey.self] }
        set { self[ThemeDomainKey.self] = newValue }
    }
}

extension View {
    /// Set once at a domain root so native controls and content share appearance.
    ///
    /// Inside a role root (`roleTheme(_:)`), an in-window page also asks the root for its scheme
    /// (`CYShellSchemeArbiter`), so a light editor pushed from the dark player shell turns the whole window light
    /// (status bar, Form / List backgrounds, bar buttons), not only the SwiftUI palette. Sheets keep their own scheme.
    func themeDomain(_ domain: ThemeDomain) -> some View {
        modifier(CYThemeDomainModifier(domain: domain, requestsShellScheme: true))
    }

    /// The role root's own domain: same environment, but no shell-scheme request (the root is the default).
    func themeDomainRoot(_ domain: ThemeDomain) -> some View {
        modifier(CYThemeDomainModifier(domain: domain, requestsShellScheme: false))
    }
}

/// Additive facade; existing QuestifyPalette and QuestifyMotion remain available.
enum Theme {
    private static func color(_ name: String, in domain: ThemeDomain) -> SwiftUI.Color {
        guard let value = Generated.color(name, in: domain) else {
            preconditionFailure("Missing generated Theme color: \(name) / \(domain)")
        }
        return value
    }

    static func length(_ name: String) -> CGFloat {
        guard let value = Generated.length(name, in: .player) else {
            preconditionFailure("Missing generated Theme length: \(name)")
        }
        return value
    }

    enum Color {
        static func bgPage(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-bg-page", in: domain) }
        static func bgSurface(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-bg-surface", in: domain) }
        static func bgElevated(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-bg-elevated", in: domain) }
        static func bgRaised(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-bg-raised", in: domain) }
        static func textPrimary(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-text-primary", in: domain) }
        static func textSecondary(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-text-secondary", in: domain) }
        static func textTertiary(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-text-tertiary", in: domain) }
        static func accent(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-brand", in: domain) }
        static func actionPrimaryBackground(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-action-primary-bg", in: domain) }
        static func actionPrimaryForeground(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-action-primary-fg", in: domain) }
        static func danger(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-status-danger", in: domain) }
        static func success(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-status-success", in: domain) }
        static func borderSubtle(in domain: ThemeDomain) -> SwiftUI.Color { Theme.color("--cy-color-border-subtle", in: domain) }
    }

    enum Space {
        static let s1 = Theme.length("--cy-space-1")
        static let s1_5 = Theme.length("--cy-space-1-5")
        static let s2 = Theme.length("--cy-space-2")
        static let s2_5 = Theme.length("--cy-space-2-5")
        static let s3 = Theme.length("--cy-space-3")
        static let s3_5 = Theme.length("--cy-space-3-5")
        static let s4 = Theme.length("--cy-space-4")
        static let s5 = Theme.length("--cy-space-5")
        static let s6 = Theme.length("--cy-space-6")
        static let s7 = Theme.length("--cy-space-7")
        static let s8 = Theme.length("--cy-space-8")
        static let pageX = Theme.length("--cy-page-x")
    }

    enum Radius {
        static let sm = Theme.length("--cy-radius-sm")
        static let md = Theme.length("--cy-radius-md")
        // Native iOS restyle r1 (owner, 11-24): ONE radius set. Cards are 12 (`lg` folds into `card`), heroes are 20
        // (`xl` and `xxl` fold into `hero`). The mini-program 16 / 20 / 22 steps are retired.
        static let lg = card
        static let xl = hero
        static let xxl = hero
        /// Prefer Capsule for true pills. Source 999rpx is 499.5pt, not 999pt.
        static let pill = Theme.length("--cy-radius-pill")
        /// Native iOS restyle (owner, 11-24): one card radius (12) and one hero radius (20).
        static let card: CGFloat = 12
        static let hero: CGFloat = 20
    }

    enum Font {
        // consist-1: one type scale. Every member reads `CYTextStyle.spec` (CYDesignTokens.swift), which takes the
        // mini-program sizes (rpx / 2, `Theme.length("--cy-type-*")`) and weights. Prefer `CYTypography` / `.cyText(_:)`
        // in views; these names stay for existing callers.
        static var pageTitle: SwiftUI.Font { CYTextStyle.pageTitle.font }
        static var sheetTitle: SwiftUI.Font { CYTextStyle.sheetTitle.font }
        static var sectionTitle: SwiftUI.Font { CYTextStyle.sectionTitle.font }
        static var cardTitle: SwiftUI.Font { CYTextStyle.cardTitle.font }
        static var button: SwiftUI.Font { CYTextStyle.button.font }
        static var body: SwiftUI.Font { CYTextStyle.body.font }
        static var label: SwiftUI.Font { CYTextStyle.label.font }
        static var caption: SwiftUI.Font { CYTextStyle.caption.font }
        static var micro: SwiftUI.Font { CYTextStyle.micro.font }
        static var display: SwiftUI.Font { CYTextStyle.display.font }
        static var dataXL: SwiftUI.Font { CYTextStyle.dataXL.font }
        static var data2XL: SwiftUI.Font { CYTextStyle.data2XL.font }
    }

    enum Motion {
        /// Callers pass @QuestifyReduceMotion, which combines system and App policy.
        static func standard(reduceMotion: Bool) -> Animation? {
            animation("--cy-motion-standard", reduceMotion: reduceMotion)
        }
        static func press(reduceMotion: Bool) -> Animation? {
            animation("--cy-motion-press", reduceMotion: reduceMotion)
        }
        static func fast(reduceMotion: Bool) -> Animation? {
            animation("--cy-motion-fast", reduceMotion: reduceMotion)
        }
        private static func animation(_ name: String, reduceMotion: Bool) -> Animation? {
            guard !reduceMotion else { return nil }
            guard let duration = Generated.duration(name, in: .player),
                  let curve = Generated.easing("--cy-ease-standard", in: .player), curve.count == 4 else {
                preconditionFailure("Missing generated Theme motion: \(name)")
            }
            return .timingCurve(curve[0], curve[1], curve[2], curve[3], duration: duration)
        }
    }
}

// MARK: - Shell scheme arbitration (N-01)

/// One source of truth for the window's colour scheme under a role root.
/// In-window pages that call `themeDomain(_:)` register a request while their view is in the window.
/// The shallowest request wins (a page beats a card nested inside it); among equals, the most recent one
/// (the page just pushed beats the root page it covers). With no request, the role's own scheme applies.
@MainActor
@Observable
final class CYShellSchemeArbiter {
    private struct Request { let depth: Int; let scheme: ColorScheme; let order: Int }
    // Only `requestedScheme` is observed. The bookkeeping is ignored by Observation: a request view reads and writes
    // it from `updateUIView`, and an observed dictionary there made SwiftUI re-run the update forever.
    @ObservationIgnored private var requests: [UUID: Request] = [:]
    @ObservationIgnored private var counter = 0
    private(set) var requestedScheme: ColorScheme?

    func register(_ token: UUID, depth: Int, scheme: ColorScheme) {
        if let existing = requests[token], existing.depth == depth, existing.scheme == scheme { return }
        counter += 1
        requests[token] = Request(depth: depth, scheme: scheme, order: counter)
        resolve()
    }

    func unregister(_ token: UUID) {
        guard requests.removeValue(forKey: token) != nil else { return }
        resolve()
    }

    private func resolve() {
        let winner = requests.values.min { lhs, rhs in
            lhs.depth != rhs.depth ? lhs.depth < rhs.depth : lhs.order > rhs.order
        }
        if requestedScheme != winner?.scheme { requestedScheme = winner?.scheme }
    }
}

private struct CYShellSchemeArbiterKey: EnvironmentKey {
    static let defaultValue: CYShellSchemeArbiter? = nil
}

private struct CYThemeDepthKey: EnvironmentKey {
    static let defaultValue = 0
}

extension EnvironmentValues {
    var cyShellSchemeArbiter: CYShellSchemeArbiter? {
        get { self[CYShellSchemeArbiterKey.self] }
        set { self[CYShellSchemeArbiterKey.self] = newValue }
    }

    /// How many `themeDomain(_:)` calls enclose this view (the role root is 1).
    var cyThemeDepth: Int {
        get { self[CYThemeDepthKey.self] }
        set { self[CYThemeDepthKey.self] = newValue }
    }
}

private struct CYThemeDomainModifier: ViewModifier {
    let domain: ThemeDomain
    let requestsShellScheme: Bool
    @Environment(\.cyThemeDepth) private var depth
    @Environment(\.cyShellSchemeArbiter) private var arbiter

    func body(content: Content) -> some View {
        content
            .environment(\.themeDomain, domain)
            .cyApplyColorScheme(domain.forcedColorScheme)
            .environment(\.cyThemeDepth, depth + 1)
            // verify-r2 N-01: controls take this domain's brand tint; inheriting the shell's (white on the player)
            // made a light sheet's 关闭 button invisible.
            .tint(CYDomainPalette(domain).brand)
            // Applies to the nearest presentation. Inside a role root it is overridden by the root's arbitrated value,
            // which is why the request below exists; in a sheet it is what sets the sheet's scheme.
            .background {
                #if canImport(UIKit)
                if requestsShellScheme, let arbiter, let forced = domain.forcedColorScheme {
                    CYShellSchemeRequestHost(arbiter: arbiter, depth: depth + 1, scheme: forced)
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
                #endif
            }
    }
}

#if canImport(UIKit)
/// Registers while its view is in a window and not inside a presented controller (sheets own their scheme).
private struct CYShellSchemeRequestHost: UIViewRepresentable {
    let arbiter: CYShellSchemeArbiter
    let depth: Int
    let scheme: ColorScheme

    func makeUIView(context: Context) -> CYShellSchemeRequestView {
        let view = CYShellSchemeRequestView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        view.backgroundColor = .clear
        view.configure(arbiter: arbiter, depth: depth, scheme: scheme)
        return view
    }

    func updateUIView(_ uiView: CYShellSchemeRequestView, context: Context) {
        uiView.configure(arbiter: arbiter, depth: depth, scheme: scheme)
    }

    static func dismantleUIView(_ uiView: CYShellSchemeRequestView, coordinator: ()) {
        uiView.withdraw()
    }
}

final class CYShellSchemeRequestView: UIView {
    private let token = UUID()
    private weak var arbiter: CYShellSchemeArbiter?
    private var depth = 0
    private var scheme: ColorScheme = .dark

    func configure(arbiter: CYShellSchemeArbiter, depth: Int, scheme: ColorScheme) {
        if self.arbiter !== arbiter { self.arbiter?.unregister(token) }
        self.arbiter = arbiter
        self.depth = depth
        self.scheme = scheme
        sync()
    }

    func withdraw() {
        let token = token
        DispatchQueue.main.async { [weak arbiter] in arbiter?.unregister(token) }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        sync()
    }

    /// Deferred to the next main-queue turn: the root's scheme must not change in the middle of a SwiftUI update
    /// pass, and several requests changing in one pass then settle together (FIFO keeps their order).
    private func sync() {
        DispatchQueue.main.async { [weak self] in
            guard let self, let arbiter = self.arbiter else { return }
            if self.window != nil, !self.isInsidePresentation {
                arbiter.register(self.token, depth: self.depth, scheme: self.scheme)
            } else {
                arbiter.unregister(self.token)
            }
        }
    }

    /// True when the topmost ancestor controller was presented (sheet, cover, popover).
    var isInsidePresentation: Bool {
        var responder: UIResponder? = self
        var controller: UIViewController?
        while let next = responder?.next {
            if let vc = next as? UIViewController { controller = vc; break }
            responder = next
        }
        while let parent = controller?.parent { controller = parent }
        return controller?.presentingViewController != nil
    }

    deinit {
        let token = token
        let arbiter = arbiter
        DispatchQueue.main.async { arbiter?.unregister(token) }
    }
}
#endif
