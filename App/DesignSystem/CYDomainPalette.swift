import SwiftUI

// UI-F10: role-domain palette that follows the WeChat mini-program token sheet
// (`chengyinhub-xcx/style/tokens.wxss`) exactly.
//
// Why this file exists: `CYColor` (CYDesignTokens.swift) is a *violet-accent*, appearance-driven palette
// (`#7A5CFF` primary fill, `#F5F5F7` / `#18181B` text, `#F3F4F4` page). The mini-program has since moved to
//   - player (dark):   neutral near-white brand/CTA `#F8F8F8` on `#0A0A0A`, page `#000000`, cards `#1C1C1E`
//   - merchant (light): CTA pure black `#000000`, brand grey `#33363C`, page `#F3F4F4`, cards `#FFFFFF`
// and uses violet `#7A5CFF` ONLY for the selected tab icon.
//
// This type resolves the mini-program values per `ThemeDomain` (single source: `Theme.Generated`, which is
// produced from tokens.wxss). Hard-coded fallbacks below are the same tokens.wxss values and are only used
// if a generated name is ever dropped. Additive: nothing existing is changed or renamed.

/// Mini-program palette for one role domain. Cheap value type; build it from `@Environment(\.themeDomain)`
/// or use `@Environment(\.cyPalette)`.
struct CYDomainPalette {
    let domain: ThemeDomain

    init(_ domain: ThemeDomain) { self.domain = domain }

    private var isDark: Bool { domain.colorScheme == .dark }

    private func token(_ name: String, dark: CYRGB, light: CYRGB) -> Color {
        if let value = Theme.Generated.color(name, in: domain) { return value }
        return (isDark ? dark : light).swiftUIColor
    }

    /// Dark-domain text colours that the generated token sheet leaves under 4.5:1 on raised surfaces (`#1C1C1E`/`#2A2A2C`)
    /// or on their own soft fill are lifted here once, so no page needs a local fix. Light domains keep the sheet values.
    private func legible(_ name: String, darkText: UInt32, dark: CYRGB, light: CYRGB) -> Color {
        isDark ? CYRGB(hex: darkText).swiftUIColor : token(name, dark: dark, light: light)
    }

    // MARK: Surfaces (--cy-color-bg-*)

    /// `--cy-color-bg-page`: `#000000` / `#F3F4F4`.
    var bgPage: Color { token("--cy-color-bg-page", dark: CYRGB(hex: 0x000000), light: CYRGB(hex: 0xF3F4F4)) }
    /// `--cy-color-bg-surface`: `#0A0A0B` / `#FFFFFF`.
    var bgSurface: Color { token("--cy-color-bg-surface", dark: CYRGB(hex: 0x0A0A0B), light: CYRGB(hex: 0xFFFFFF)) }
    /// `--cy-color-bg-surface-subtle`: `#141416` / `#EEEEEE` (dividers, nested slots).
    var bgSurfaceSubtle: Color { token("--cy-color-bg-surface-subtle", dark: CYRGB(hex: 0x141416), light: CYRGB(hex: 0xEEEEEE)) }
    /// `--cy-color-bg-elevated` (= card fill `--cy-comp-card-bg`): `#1C1C1E` / `#FFFFFF`.
    var bgElevated: Color { token("--cy-color-bg-elevated", dark: CYRGB(hex: 0x1C1C1E), light: CYRGB(hex: 0xFFFFFF)) }
    /// `--cy-color-bg-raised` (card-in-card, input base): `#2A2A2C` / `#E6E6E6`.
    var bgRaised: Color { token("--cy-color-bg-raised", dark: CYRGB(hex: 0x2A2A2C), light: CYRGB(hex: 0xE6E6E6)) }
    /// `--cy-color-bg-surface-strong`: `#3B3B3D` / `#E4E4E4`.
    var bgStrong: Color { token("--cy-color-bg-surface-strong", dark: CYRGB(hex: 0x3B3B3D), light: CYRGB(hex: 0xE4E4E4)) }
    /// `--cy-color-bg-interactive` (round action buttons, unselected chips): `#4D4D4D` / `#FFFFFF`.
    var bgInteractive: Color { token("--cy-color-bg-interactive", dark: CYRGB(hex: 0x4D4D4D), light: CYRGB(hex: 0xFFFFFF)) }

    /// Card fill, `--cy-comp-card-bg`.
    var cardFill: Color { bgElevated }

    // MARK: Borders

    /// `--cy-color-border-subtle`: `rgba(255,255,255,.08)` / `#E8E8E8`.
    var borderSubtle: Color { token("--cy-color-border-subtle", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.08), light: CYRGB(hex: 0xE8E8E8)) }
    /// `--cy-color-border-strong`: `rgba(255,255,255,.16)` / `#DBDBDB`.
    var borderStrong: Color { token("--cy-color-border-strong", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.16), light: CYRGB(hex: 0xDBDBDB)) }
    /// Dark cards rise with a 0.5pt top-edge highlight (`--cy-comp-card-highlight`); light cards use a shadow instead.
    var cardHighlight: Color { token("--cy-comp-card-highlight", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.08), light: CYRGB(hex: 0x000000, alpha: 0)) }
    /// Light-domain card shadow (`--cy-comp-card-shadow-day: 0 2rpx 8rpx rgba(15,23,43,.48)`); none in dark.
    var cardShadowColor: Color { isDark ? .clear : CYRGB(hex: 0x0F172B, alpha: 0.48).swiftUIColor }

    // MARK: Text

    /// `#F8F8F8` / `#000000`.
    var textPrimary: Color { token("--cy-color-text-primary", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x000000)) }
    /// `#B7B7B7` / `#404040`.
    var textSecondary: Color { token("--cy-color-text-secondary", dark: CYRGB(hex: 0xB7B7B7), light: CYRGB(hex: 0x404040)) }
    /// `#919191` / `#6B6B6B`.
    var textTertiary: Color { token("--cy-color-text-tertiary", dark: CYRGB(hex: 0x919191), light: CYRGB(hex: 0x6B6B6B)) }
    /// `#868686` / `#6F6F6F`.
    var textPlaceholder: Color { legible("--cy-color-text-placeholder", darkText: 0x929292, dark: CYRGB(hex: 0x868686), light: CYRGB(hex: 0x6F6F6F)) }
    /// `rgba(255,255,255,.40)` / `#737373`.
    var textDisabled: Color { token("--cy-color-text-disabled", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.40), light: CYRGB(hex: 0x737373)) }
    /// `#0A0A0A` / `#FFFFFF` (text on a primary fill).
    var textInverse: Color { token("--cy-color-text-inverse", dark: CYRGB(hex: 0x0A0A0A), light: CYRGB(hex: 0xFFFFFF)) }

    // MARK: Brand / actions (NO violet; violet is the selected-tab tint only)

    /// `--cy-color-brand`: `#F8F8F8` (player) / `#33363C` (merchant).
    /// This is also the primary CTA fill. Merchant does not use `--cy-color-action-primary-bg` (`#000000`).
    var brand: Color { token("--cy-color-brand", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x33363C)) }
    /// `--cy-color-brand-strong`: pressed brand (`#B7B7B7` / `#33363C`).
    var brandStrong: Color { token("--cy-color-brand-strong", dark: CYRGB(hex: 0xB7B7B7), light: CYRGB(hex: 0x33363C)) }
    /// `--cy-color-brand-soft`: `rgba(248,248,248,.12)` / `#EAEBEE`.
    var brandSoft: Color { token("--cy-color-brand-soft", dark: CYRGB(hex: 0xF8F8F8, alpha: 0.12), light: CYRGB(hex: 0xEAEBEE)) }
    /// `--cy-color-selection`: same pair as brand (`#F8F8F8` / `#33363C`).
    var selection: Color { token("--cy-color-selection", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x33363C)) }
    /// `--cy-color-action-primary-bg`: `#F8F8F8` / `#000000`.
    var actionPrimaryBg: Color { token("--cy-color-action-primary-bg", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x000000)) }
    /// `--cy-color-action-primary-fg`: `#0A0A0A` / `#FFFFFF`.
    var actionPrimaryFg: Color { token("--cy-color-action-primary-fg", dark: CYRGB(hex: 0x0A0A0A), light: CYRGB(hex: 0xFFFFFF)) }
    /// `--cy-color-action-secondary-bg`: `rgba(255,255,255,.08)` / `#EEEEEE`.
    var actionSecondaryBg: Color { token("--cy-color-action-secondary-bg", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.08), light: CYRGB(hex: 0xEEEEEE)) }
    /// `--cy-color-action-danger-bg`: `#D0323B` both domains (white text 5.0:1).
    var actionDangerBg: Color { token("--cy-color-action-danger-bg", dark: CYRGB(hex: 0xD0323B), light: CYRGB(hex: 0xD0323B)) }
    var actionDangerFg: Color { .white }

    // MARK: Status text + soft fills

    /// `#22C55E` / `#0B7A57`.
    var success: Color { token("--cy-color-status-success", dark: CYRGB(hex: 0x22C55E), light: CYRGB(hex: 0x0B7A57)) }
    /// `#D58300` / `#96610A`.
    var warning: Color { legible("--cy-color-status-warning", darkText: 0xEDA52B, dark: CYRGB(hex: 0xD58300), light: CYRGB(hex: 0x96610A)) }
    /// `#E5484D` / `#D0323B`.
    var danger: Color { legible("--cy-color-status-danger", darkText: 0xFF6B70, dark: CYRGB(hex: 0xE5484D), light: CYRGB(hex: 0xD0323B)) }
    /// `#4C86FF` / `#2563EB`.
    var info: Color { legible("--cy-color-status-info", darkText: 0x7AA5FF, dark: CYRGB(hex: 0x4C86FF), light: CYRGB(hex: 0x2563EB)) }
    var successSoft: Color { token("--cy-color-status-success-soft", dark: CYRGB(hex: 0x22C55E, alpha: 0.14), light: CYRGB(hex: 0x0B7A57, alpha: 0.10)) }
    var warningSoft: Color { token("--cy-color-status-warning-soft", dark: CYRGB(hex: 0xD58300, alpha: 0.18), light: CYRGB(hex: 0x96610A, alpha: 0.12)) }
    var dangerSoft: Color { token("--cy-color-status-danger-soft", dark: CYRGB(hex: 0xE5484D, alpha: 0.14), light: CYRGB(hex: 0xD0323B, alpha: 0.10)) }
    var infoSoft: Color { token("--cy-color-status-info-soft", dark: CYRGB(hex: 0x4C86FF, alpha: 0.14), light: CYRGB(hex: 0x2563EB, alpha: 0.10)) }

    // MARK: Skeleton / overlay

    var skeletonBase: Color { token("--cy-color-skeleton-base", dark: CYRGB(hex: 0x191919), light: CYRGB(hex: 0xECEFF3)) }
    var skeletonHighlight: Color { token("--cy-color-skeleton-highlight", dark: CYRGB(hex: 0x242424), light: CYRGB(hex: 0xF6F8FA)) }
    /// `--cy-color-bg-glass`: `rgba(28,28,30,.82)` / `rgba(255,255,255,.88)`.
    var bgGlass: Color { token("--cy-color-bg-glass", dark: CYRGB(hex: 0x1C1C1E, alpha: 0.82), light: CYRGB(hex: 0xFFFFFF, alpha: 0.88)) }
    /// `--cy-color-overlay`: `rgba(0,0,0,.56)` in both domains.
    var overlay: Color { token("--cy-color-overlay", dark: CYRGB(hex: 0x000000, alpha: 0.56), light: CYRGB(hex: 0x000000, alpha: 0.56)) }

    // MARK: Tab bar (components/tabBar/index.wxss)

    /// Selected tab icon/label tint: the only violet (`--cy-ref-violet-500` `#7A5CFF`).
    var tabSelectedTint: Color {
        token(
            "--cy-ref-violet-500",
            dark: CYRGB(hex: Theme.MiniProgramChrome.tabSelectedHex),
            light: CYRGB(hex: Theme.MiniProgramChrome.tabSelectedHex)
        )
    }
}

extension CYDomainPalette {
    /// Palette `CYColor` reads. Dark is the player role; light is the merchant role.
    static func resolving(_ scheme: ColorScheme) -> CYDomainPalette {
        CYDomainPalette(scheme == .dark ? .player : .merchant)
    }
}

// MARK: - Environment access

extension EnvironmentValues {
    /// Mini-program palette for the current `themeDomain` (set once at the role root via `.themeDomain(_:)`).
    var cyPalette: CYDomainPalette { CYDomainPalette(themeDomain) }
}

// MARK: - Card surface (components/cy/card + --cy-comp-card-*)

/// Mini-program card: 16pt continuous radius, 16pt padding, fill `bgElevated`, no border,
/// dark = 0.5pt top-edge highlight, light = soft shadow (offset 1pt, blur 4pt).
struct CYDomainCardModifier: ViewModifier {
    var radius: CGFloat = Theme.Radius.lg   // --cy-comp-card-radius 32rpx = 16pt
    var padding: CGFloat = 16               // --cy-comp-card-pad 32rpx

    @Environment(\.cyPalette) private var palette

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .background(shape.fill(palette.cardFill).shadow(color: palette.cardShadowColor, radius: 2, x: 0, y: 1))
            .overlay(
                shape.strokeBorder(
                    LinearGradient(
                        colors: [palette.cardHighlight, .clear],
                        startPoint: .top,
                        endPoint: .center
                    ),
                    lineWidth: 0.5
                )
            )
    }
}

extension View {
    /// Card surface that follows the mini-program tokens for the current role domain.
    /// Default radius is `--cy-comp-card-radius` (32rpx = 16pt).
    func cyDomainCard(radius: CGFloat = Theme.Radius.lg, padding: CGFloat = 16) -> some View {
        modifier(CYDomainCardModifier(radius: radius, padding: padding))
    }

    /// Full-screen page background (`--cy-color-bg-page`) for the current role domain.
    func cyDomainPageBackground() -> some View {
        modifier(CYDomainPageBackgroundModifier())
    }
}

struct CYDomainPageBackgroundModifier: ViewModifier {
    @Environment(\.cyPalette) private var palette
    func body(content: Content) -> some View {
        content.background(palette.bgPage.ignoresSafeArea())
    }
}

// MARK: - Buttons (components/cy/btn)

/// Mini-program primary button: solid neutral fill (`#F8F8F8` on dark, `#000000` on light), 44pt tall,
/// 12pt continuous radius (`--cy-comp-btn-radius`), bold label, pressed = 0.88 opacity.
/// Disabled = placeholder text on the subtle surface (never an opacity drop).
struct CYDomainPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = true

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        configuration.label
            .font(Theme.Font.button.weight(.bold))
            .foregroundStyle(isEnabled ? palette.actionPrimaryFg : palette.textPlaceholder)
            .padding(.horizontal, 20)   // --cy-btn-pad-x 40rpx
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)   // --cy-btn-h 88rpx
            .background(shape.fill(isEnabled ? palette.actionPrimaryBg : palette.bgSurfaceSubtle))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

/// Mini-program secondary button: grey fill only, NO outline (2026-08-05 decision), secondary-text colour.
struct CYDomainSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        configuration.label
            .font(Theme.Font.button.weight(.bold))
            .foregroundStyle(isEnabled ? palette.textSecondary : palette.textPlaceholder)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(shape.fill(isEnabled ? palette.actionSecondaryBg : palette.bgSurfaceSubtle))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

/// Mini-program danger button: solid `#D0323B` with white label.
struct CYDomainDestructiveButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
        configuration.label
            .font(Theme.Font.button.weight(.bold))
            .foregroundStyle(isEnabled ? palette.actionDangerFg : palette.textPlaceholder)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(shape.fill(isEnabled ? palette.actionDangerBg : palette.bgSurfaceSubtle))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.88 : 1)
    }
}

extension ButtonStyle where Self == CYDomainPrimaryButtonStyle {
    static var cyDomainPrimary: CYDomainPrimaryButtonStyle { CYDomainPrimaryButtonStyle() }
    static func cyDomainPrimary(fullWidth: Bool) -> CYDomainPrimaryButtonStyle { CYDomainPrimaryButtonStyle(fullWidth: fullWidth) }
}

extension ButtonStyle where Self == CYDomainSecondaryButtonStyle {
    static var cyDomainSecondary: CYDomainSecondaryButtonStyle { CYDomainSecondaryButtonStyle() }
    static func cyDomainSecondary(fullWidth: Bool) -> CYDomainSecondaryButtonStyle { CYDomainSecondaryButtonStyle(fullWidth: fullWidth) }
}

extension ButtonStyle where Self == CYDomainDestructiveButtonStyle {
    static var cyDomainDestructive: CYDomainDestructiveButtonStyle { CYDomainDestructiveButtonStyle() }
    static func cyDomainDestructive(fullWidth: Bool) -> CYDomainDestructiveButtonStyle { CYDomainDestructiveButtonStyle(fullWidth: fullWidth) }
}

// MARK: - Previews (synthetic fixtures, preview-only)

private struct CYDomainPalettePreviewContent: View {
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "Preview card")
                    .font(Theme.Font.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: "Secondary line 1,234")
                    .font(Theme.Font.body.monospacedDigit())
                    .foregroundStyle(palette.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyDomainCard()

            Button(action: {}) { Text(verbatim: "Primary") }
                .buttonStyle(.cyDomainPrimary)
            Button(action: {}) { Text(verbatim: "Secondary") }
                .buttonStyle(.cyDomainSecondary(fullWidth: true))
            Button(action: {}) { Text(verbatim: "Delete") }
                .buttonStyle(.cyDomainDestructive(fullWidth: true))
        }
        .padding(16)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
    }
}

#Preview("Player (dark)") {
    CYDomainPalettePreviewContent().themeDomain(.player)
}

#Preview("Merchant (light)") {
    CYDomainPalettePreviewContent().themeDomain(.merchant)
}
