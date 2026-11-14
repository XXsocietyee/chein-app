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
    func roleTheme(_ role: RoleTheme) -> some View {
        environment(\.roleTheme, role)
            .themeDomain(role.domain)
    }

    /// Apply to the content of a `.sheet`, `.fullScreenCover` or popover presented from a role root.
    /// Re-asserts the forced colour scheme, rounded sheet radius, and sheet glass background so the
    /// sheet never follows the device appearance.
    func roleThemedPresentation() -> some View {
        modifier(RoleThemedPresentationModifier())
    }

    /// Apply player sheet glass (`rgba(44,44,46,.98)` + 24pt top corner radius) and dark player tokens
    /// directly onto a presented sheet hierarchy.
    func cyPlayerSheetGlass() -> some View {
        self
            .themeDomain(.player)
            .presentationCornerRadius(CYRadius.sheet)
            .presentationBackground(CYDomainPalette(.player).sheetGlass)
    }
}

private struct RoleThemedPresentationModifier: ViewModifier {
    @Environment(\.roleTheme) private var role

    func body(content: Content) -> some View {
        content
            .themeDomain(role.domain)
            .presentationCornerRadius(CYRadius.sheet)
            .presentationBackground(CYDomainPalette(role.domain).sheetGlass)
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
