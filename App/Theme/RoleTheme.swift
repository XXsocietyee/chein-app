import SwiftUI

/// The two app roles and the appearance each one owns.
/// Player surfaces are dark, merchant surfaces are light, regardless of the device appearance.
/// This is a thin, additive layer over `ThemeDomain` (see `Theme.swift`); it adds no colours.
enum RoleTheme: String, CaseIterable, Equatable {
    case player, merchant

    /// The `ThemeDomain` whose generated tokens this role uses.
    var domain: ThemeDomain {
        switch self {
        case .player: return .player
        case .merchant: return .merchant
        }
    }

    var colorScheme: ColorScheme { domain.colorScheme }
}

private struct RoleThemeKey: EnvironmentKey {
    static let defaultValue = RoleTheme.player
}

extension EnvironmentValues {
    /// The role that owns the current view tree. Defaults to `.player`.
    var roleTheme: RoleTheme {
        get { self[RoleThemeKey.self] }
        set { self[RoleThemeKey.self] = newValue }
    }
}

extension View {
    /// Apply once at a role root (player shell or merchant console).
    /// Sets the role environment, the theme domain and the forced colour scheme.
    ///
    /// The root is the only place that sets the window's colour scheme: the role's own scheme, unless an in-window
    /// page has asked for another one through `themeDomain(_:)` (see `CYShellSchemeArbiter`). Before this, the root
    /// forced its scheme unconditionally and a light editor pushed from the dark player shell rendered in two themes.
    func roleTheme(_ role: RoleTheme) -> some View {
        modifier(RoleThemeRootModifier(role: role))
    }

    /// Apply to the content of a `.sheet`, `.fullScreenCover` or popover presented from a role root.
    /// Re-asserts the role's colour scheme so the sheet never follows the device appearance. Corners and
    /// background are the system sheet's (native-ios-r1 §3.4).
    func roleThemedPresentation() -> some View {
        modifier(RoleThemedPresentationModifier())
    }

    /// Apply player sheet glass (`rgba(44,44,46,.98)` + 24pt top corner radius) and dark player tokens
    /// directly onto a presented sheet hierarchy.
    /// Native restyle (native-ios-r1 §3.4): the system sheet in the player appearance. No custom corner radius
    /// or glass background; the name stays so call sites keep reading as "player sheet".
    func cyPlayerSheetGlass() -> some View {
        self.themeDomain(.player)
    }
}

private struct RoleThemeRootModifier: ViewModifier {
    let role: RoleTheme
    @State private var arbiter = CYShellSchemeArbiter()

    func body(content: Content) -> some View {
        content
            .environment(\.roleTheme, role)
            .themeDomainRoot(role.domain)
            .environment(\.cyShellSchemeArbiter, arbiter)
            .preferredColorScheme(arbiter.requestedScheme ?? role.colorScheme)
            #if canImport(UIKit)
            // Bar buttons (the system back chevron) follow UINavigationBar.tintColor, which the role root set for its
            // own domain. When a page of the other scheme is on top, tint them for that scheme, and back on pop.
            .onChange(of: arbiter.requestedScheme) { _, scheme in
                CYScreenChrome.retintNavigationBars(for: scheme ?? role.colorScheme, role: role)
                CYScreenChrome.syncStatusBar(for: scheme ?? role.colorScheme)
            }
            .onAppear { CYScreenChrome.syncStatusBar(for: arbiter.requestedScheme ?? role.colorScheme) }
            #endif
    }
}

private struct RoleThemedPresentationModifier: ViewModifier {
    @Environment(\.roleTheme) private var role

    func body(content: Content) -> some View {
        content
            .themeDomain(role.domain)
            // Native restyle (native-ios-r1 §3.4): system sheet corners and background in the role appearance.
    }
}

#Preview("Player (dark)") {
    Text(verbatim: "Player")
        .padding()
        .roleTheme(.player)
}

#Preview("Merchant (light)") {
    Text(verbatim: "Merchant")
        .padding()
        .roleTheme(.merchant)
}

#Preview("Sheet inherits role") {
    Text(verbatim: "Sheet")
        .padding()
        .roleThemedPresentation()
        .roleTheme(.merchant)
}
