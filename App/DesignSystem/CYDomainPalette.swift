import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    /// Native iOS r2: nil = the palette follows the system Light/Dark trait at draw time (player, merchant, editor);
    /// true = forced dark (play stage, explicit dark surfaces).
    private var forcedDark: Bool? { domain.forcedColorScheme.map { $0 == .dark } }
    /// Follows the system appearance and uses the system accent, like Apple's own apps.
    var followsSystem: Bool { forcedDark == nil }
    /// System accent as a concrete colour. `.accentColor` resolves through the view's tint, and the app root sets
    /// `.tint(CYColor.brand)` (= this value), so a bar button image resolving it recursed until the stack overflowed
    /// (d4-badges / d4-stamps crash, 11-27). No AccentColor asset exists, so the system accent is systemBlue.
    static let systemAccent = Color(uiColor: .systemBlue)
    /// Play runtime overlays `.theme-game` tokens onto the player dark stage rather than light gray merchant chrome.
    private var surfaceDomain: ThemeDomain { domain == .game ? .player : domain }

    var isDarkDomain: Bool { forcedDark == true }

    /// Button shape by domain. Owner default skill-r2 Q4 (accepted 2026-11-16): one capsule shape across player,
    /// merchant and editor (Figma `Role Shape / button-radius` = 999 in every mode). This is the one place the shape
    /// is decided; `nil` means capsule. Supersedes verify-r1 2.1 (radius 12 for merchant and editor).
    var buttonCornerRadius: CGFloat? { nil }

    /// Merchant primary buttons are 46 pt high (merchant rule); everything else keeps 44.
    var buttonMinHeight: CGFloat { domain == .merchant ? 46 : 44 }
    var resolvedSurfaceDomain: ThemeDomain { surfaceDomain }

    private func token(_ name: String, dark: CYRGB, light: CYRGB) -> Color {
        if followsSystem {
            let darkValue = Theme.Generated.color(name, in: .player) ?? dark.swiftUIColor
            let lightValue = Theme.Generated.color(name, in: .merchant) ?? light.swiftUIColor
            return Self.dynamic(dark: darkValue, light: lightValue)
        }
        if let value = Theme.Generated.color(name, in: surfaceDomain) { return value }
        return (isDark ? dark : light).swiftUIColor
    }

    /// Resolves at draw time from the view's own Light/Dark trait.
    static func dynamic(dark: Color, light: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light) })
        #else
        return dark
        #endif
    }

    #if canImport(UIKit)
    /// Native restyle (native-ios-r1 §2.2): a UIKit semantic colour resolved in this domain's appearance
    /// (player dark, merchant light), keeping the user's Increase Contrast and elevation traits.
    private func system(_ color: UIColor) -> Color {
        if followsSystem { return Color(uiColor: color) }
        let style: UIUserInterfaceStyle = isDark ? .dark : .light
        return Color(uiColor: UIColor { traits in
            color.resolvedColor(with: traits.modifyingTraits { $0.userInterfaceStyle = style })
        })
    }
    #endif

    /// A native semantic colour where UIKit has one; the MP token sheet value elsewhere (previews, macOS tools).
    private func native(_ kind: CYNativeColor, _ name: String, dark: CYRGB, light: CYRGB) -> Color {
        #if canImport(UIKit)
        return system(kind.uiColor)
        #else
        return token(name, dark: dark, light: light)
        #endif
    }

    /// Dark-domain text colours that the generated token sheet leaves under 4.5:1 on raised surfaces (`#1C1C1E`/`#2A2A2C`)
    /// or on their own soft fill are lifted here once, so no page needs a local fix. Light domains keep the sheet values.
    private func legible(_ name: String, darkText: UInt32, dark: CYRGB, light: CYRGB) -> Color {
        if followsSystem { return Self.dynamic(dark: CYRGB(hex: darkText).swiftUIColor, light: token(name, dark: dark, light: light)) }
        return isDark ? CYRGB(hex: darkText).swiftUIColor : token(name, dark: dark, light: light)
    }

    // MARK: Surfaces (--cy-color-bg-*)
    // Native restyle (native-ios-r1 §2.2): page, surface, fill, label and separator tokens resolve to the iOS
    // semantic colours in the domain's appearance. The MP hex values stay as the non-UIKit fallback.
    // `textTertiary` maps to `secondaryLabel`, not `tertiaryLabel`: most call sites are small meta text, which
    // needs 4.5:1 (spec §2.2 "small meta text uses .secondary"). `bgElevated` stays at the card level
    // (`secondarySystemGroupedBackground`) so existing elevated cards keep lifting off the page; `bgRaised`
    // is the card-in-card level (`tertiarySystemGroupedBackground`). `borderStrong` keeps the owner-adopted 3:1
    // control-boundary value (`opaqueSeparator` is ~1.7:1 on white, below the non-text 3:1 floor in spec §2.2).

    /// `--cy-color-bg-page`: `#000000` / `#F3F4F4`.
    var bgPage: Color { native(.groupedBackground, "--cy-color-bg-page", dark: CYRGB(hex: 0x000000), light: CYRGB(hex: 0xF3F4F4)) }
    /// `--cy-color-bg-surface`: `#0A0A0B` / `#FFFFFF`.
    /// e5c: dark layering is #000 page / #111 surface / #1C1C1E elevated. The generated token (#0A0A0B) sat too close to the
    /// page to read as a layer, so the player surface is pinned to #111111. Light domain still follows the token sheet.
    var bgSurface: Color { native(.secondaryGroupedBackground, "--cy-color-bg-surface", dark: CYRGB(hex: 0x111111), light: CYRGB(hex: 0xFFFFFF)) }
    /// `--cy-color-bg-surface-subtle`: `#141416` / `#EEEEEE` (dividers, nested slots).
    var bgSurfaceSubtle: Color { native(.tertiaryFill, "--cy-color-bg-surface-subtle", dark: CYRGB(hex: 0x141416), light: CYRGB(hex: 0xEEEEEE)) }
    /// `--cy-color-bg-elevated` (= card fill `--cy-comp-card-bg`): `#1C1C1E` / `#FFFFFF`.
    var bgElevated: Color { native(.secondaryGroupedBackground, "--cy-color-bg-elevated", dark: CYRGB(hex: 0x1C1C1E), light: CYRGB(hex: 0xFFFFFF)) }
    /// `--cy-color-bg-raised` (card-in-card, input base): `#2A2A2C` / `#E6E6E6`.
    var bgRaised: Color { native(.tertiaryGroupedBackground, "--cy-color-bg-raised", dark: CYRGB(hex: 0x2A2A2C), light: CYRGB(hex: 0xE6E6E6)) }
    /// `--cy-color-bg-surface-strong`: `#3B3B3D` / `#E4E4E4`.
    var bgStrong: Color { token("--cy-color-bg-surface-strong", dark: CYRGB(hex: 0x3B3B3D), light: CYRGB(hex: 0xE4E4E4)) }
    /// `--cy-color-bg-interactive` (round action buttons, unselected chips): `#4D4D4D` / `#FFFFFF`.
    var bgInteractive: Color { native(.secondaryFill, "--cy-color-bg-interactive", dark: CYRGB(hex: 0x4D4D4D), light: CYRGB(hex: 0xFFFFFF)) }
    /// Player sheet glass (`rgba(44,44,46,.98)`) / merchant sheet (`#FFFFFF`).
    /// Native restyle (native-ios-r1 §3.4): the system sheet background (`systemBackground`, which iOS lifts to the
    /// elevated level inside a sheet), so in-sheet bars match the system sheet. The MP glass stays as the fallback.
    var sheetGlass: Color {
        #if canImport(UIKit)
        return system(CYNativeColor.background.uiColor)
        #else
        return isDark
            ? token("--cy-comp-sheet-player-glass", dark: CYRGB(hex: 0x2C2C2E, alpha: 0.98), light: CYRGB(hex: 0xFFFFFF))
            : token("--cy-comp-sheet-merchant-glass", dark: CYRGB(hex: 0x2C2C2E, alpha: 0.98), light: CYRGB(hex: 0xFFFFFF))
        #endif
    }
    /// The selected segment's thumb, as `UISegmentedControl` draws it (white on light, `#636366` on dark).
    var segmentThumb: Color { native(.segmentThumb, "--cy-color-bg-surface", dark: CYRGB(hex: 0x636366), light: CYRGB(hex: 0xFFFFFF)) }
    /// Nested card inside a sheet (`#3A3A3C` player / `#F8F9FA` merchant).
    var sheetCard: Color {
        if followsSystem { return native(.tertiaryGroupedBackground, "--cy-comp-sheet-player-card", dark: CYRGB(hex: 0x3A3A3C), light: CYRGB(hex: 0xF8F9FA)) }
        return isDark
            ? token("--cy-comp-sheet-player-card", dark: CYRGB(hex: 0x3A3A3C), light: CYRGB(hex: 0xF8F9FA))
            : CYRGB(hex: 0xF8F9FA).swiftUIColor
    }
    /// Centered modal panel (`--cy-comp-modal-panel`: `#4D4D4D` / `#FFFFFF`).
    var modalPanel: Color { token("--cy-comp-modal-panel", dark: CYRGB(hex: 0x4D4D4D), light: CYRGB(hex: 0xFFFFFF)) }
    /// Sheet drag grabber (`--cy-color-sheet-handle`): `#8E8E93` / `#DBDBDB`.
    var sheetHandle: Color { token("--cy-color-sheet-handle", dark: CYRGB(hex: 0x8E8E93), light: CYRGB(hex: 0xDBDBDB)) }
    /// Field idle background. Dark: `--cy-comp-field-idle-bg` `#1C1C1E`.
    /// Light (handbook fix adopted by the owner, design hand-off r1): `#EFEFEF` inside a card (`.card`, the default);
    /// use `inputIdleBgOnPage` (`#E4E4E4`) for a field that sits directly on the grey page.
    var inputIdleBg: Color { isDark ? token("--cy-comp-field-idle-bg", dark: CYRGB(hex: 0x1C1C1E), light: CYRGB(hex: 0xEFEFEF)) : CYRGB(hex: Self.handbookInputInCardHex).swiftUIColor }
    /// Light field on the page background: `#E4E4E4` (handbook). Dark keeps the idle token.
    var inputIdleBgOnPage: Color { isDark ? inputIdleBg : CYRGB(hex: Self.handbookInputOnPageHex).swiftUIColor }
    /// Field filled background. Dark: `--cy-comp-field-filled-bg` `#3B3B3D`. Light: a filled field keeps its idle fill (handbook).
    var inputFilledBg: Color { isDark ? token("--cy-comp-field-filled-bg", dark: CYRGB(hex: 0x3B3B3D), light: CYRGB(hex: 0xEFEFEF)) : inputIdleBg }
    /// Field disabled background (`--cy-comp-field-disabled-bg`): `#141416` / `#F5F5F5`.
    var inputDisabledBg: Color { token("--cy-comp-field-disabled-bg", dark: CYRGB(hex: 0x141416), light: CYRGB(hex: 0xF5F5F5)) }
    /// Cover fallback fill when artwork is missing (`#30383D` dark / `bgRaised` light).
    var coverFallback: Color { isDark ? CYRGB(hex: 0x30383D).swiftUIColor : bgRaised }
    /// Foreground / muted / glass / CTA tokens on top of dark photo/hero scrims.
    var onCoverFg: Color { token("--cy-comp-oncover-fg", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.96), light: CYRGB(hex: 0xFFFFFF, alpha: 0.96)) }
    var onCoverFgDim: Color { token("--cy-comp-oncover-fg-dim", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.72), light: CYRGB(hex: 0xFFFFFF, alpha: 0.72)) }
    var photoCardFg: Color { token("--cy-comp-photo-card-fg", dark: CYRGB(hex: 0xFFFFFF), light: CYRGB(hex: 0xFFFFFF)) }
    var photoCardMuted: Color { token("--cy-comp-photo-card-muted", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.82), light: CYRGB(hex: 0xFFFFFF, alpha: 0.82)) }
    var photoCardGlass: Color { token("--cy-comp-photo-card-glass", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.08), light: CYRGB(hex: 0xFFFFFF, alpha: 0.14)) }
    var photoCardAction: Color { token("--cy-comp-photo-card-action", dark: CYRGB(hex: 0x060606, alpha: 0.94), light: CYRGB(hex: 0x060606, alpha: 0.94)) }

    /// Card fill, `--cy-comp-card-bg`.
    var cardFill: Color { bgSurface }

    // MARK: Borders

    /// `--cy-color-border-subtle`: `rgba(255,255,255,.08)` / `#E8E8E8`.
    var borderSubtle: Color { native(.separator, "--cy-color-border-subtle", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.08), light: CYRGB(hex: 0xE8E8E8)) }
    /// `--cy-color-border-strong`: `rgba(255,255,255,.16)` dark. Light uses the handbook's 3:1 control-boundary fix `#8C8C8C`
    /// (owner adopted it in the design hand-off r1; the shipped token sheet still says `#DBDBDB`).
    var borderStrong: Color { isDark ? token("--cy-color-border-strong", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.16), light: CYRGB(hex: 0x8C8C8C)) : CYRGB(hex: Self.handbookBorderStrongHex).swiftUIColor }
    /// Dark cards rise with a 0.5pt top-edge highlight (`--cy-comp-card-highlight`); light cards use a shadow instead.
    var cardHighlight: Color { token("--cy-comp-card-highlight", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.08), light: CYRGB(hex: 0x000000, alpha: 0)) }
    /// Neutral light-domain card shadow (`rgba(0,0,0,.05)` per unified shadow spec, no slate-blue); clear in dark.
    var cardShadowColor: Color { isDark ? .clear : CYRGB(hex: 0x000000, alpha: 0.05).swiftUIColor }
    /// Elevated float shadow (toasts, floating controls, modals).
    var floatShadowColor: Color { isDark ? CYRGB(hex: 0x000000, alpha: 0.28).swiftUIColor : CYRGB(hex: 0x000000, alpha: 0.10).swiftUIColor }

    // MARK: Text

    /// `#F8F8F8` / `#000000`.
    var textPrimary: Color { native(.label, "--cy-color-text-primary", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x000000)) }
    /// `#C7C7C7` / `#404040`.
    var textSecondary: Color { native(.secondaryLabel, "--cy-color-text-secondary", dark: CYRGB(hex: 0xC7C7C7), light: CYRGB(hex: 0x404040)) }
    /// `#A8A8A8` / `#6B6B6B`.
    var textTertiary: Color { native(.secondaryLabel, "--cy-color-text-tertiary", dark: CYRGB(hex: 0xA8A8A8), light: CYRGB(hex: 0x6B6B6B)) }
    /// `#9E9E9E` / `#6F6F6F`.
    var textPlaceholder: Color { native(.placeholder, "--cy-color-text-placeholder", dark: CYRGB(hex: 0x9E9E9E), light: CYRGB(hex: 0x6F6F6F)) }
    /// `rgba(255,255,255,.40)` / `#737373`.
    var textDisabled: Color { native(.quaternaryLabel, "--cy-color-text-disabled", dark: CYRGB(hex: 0xFFFFFF, alpha: 0.40), light: CYRGB(hex: 0x737373)) }
    /// `#0A0A0A` / `#FFFFFF` (text on a primary fill).
    var textInverse: Color { token("--cy-color-text-inverse", dark: CYRGB(hex: 0x0A0A0A), light: CYRGB(hex: 0xFFFFFF)) }

    // MARK: Brand / actions (NO violet; violet is the selected-tab tint only)

    /// `--cy-color-brand`: `#F8F8F8` (player) / `#33363C` (merchant).
    /// This is also the primary CTA fill. Merchant does not use `--cy-color-action-primary-bg` (`#000000`).
    var brand: Color { followsSystem ? Self.systemAccent : token("--cy-color-brand", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x33363C)) }
    /// `--cy-color-brand-strong`: pressed brand (`#B7B7B7` / `#33363C`).
    var brandStrong: Color { followsSystem ? Self.systemAccent : token("--cy-color-brand-strong", dark: CYRGB(hex: 0xB7B7B7), light: CYRGB(hex: 0x33363C)) }
    /// `--cy-color-brand-soft`: `rgba(248,248,248,.12)` / `#EAEBEE`.
    var brandSoft: Color { token("--cy-color-brand-soft", dark: CYRGB(hex: 0xF8F8F8, alpha: 0.12), light: CYRGB(hex: 0xEAEBEE)) }
    /// `--cy-color-selection`: same pair as brand (`#F8F8F8` / `#33363C`).
    var selection: Color { followsSystem ? Self.systemAccent : token("--cy-color-selection", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x33363C)) }
    /// `--cy-color-action-primary-bg`: `#F8F8F8` / `#000000`.
    var actionPrimaryBg: Color { followsSystem ? Self.systemAccent : token("--cy-color-action-primary-bg", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x000000)) }
    /// `--cy-color-action-primary-fg`: `#0A0A0A` / `#FFFFFF`.
    var actionPrimaryFg: Color { followsSystem ? .white : token("--cy-color-action-primary-fg", dark: CYRGB(hex: 0x0A0A0A), light: CYRGB(hex: 0xFFFFFF)) }
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
    // Light soft fills use the handbook's 18% alpha (owner adopted it in the design hand-off r1); dark keeps the token sheet.
    var successSoft: Color { softFill("--cy-color-status-success-soft", dark: CYRGB(hex: 0x22C55E, alpha: 0.14), lightHex: 0x0B7A57) }
    var warningSoft: Color { softFill("--cy-color-status-warning-soft", dark: CYRGB(hex: 0xD58300, alpha: 0.18), lightHex: 0x96610A) }
    var dangerSoft: Color { softFill("--cy-color-status-danger-soft", dark: CYRGB(hex: 0xE5484D, alpha: 0.14), lightHex: 0xD0323B) }
    var infoSoft: Color { softFill("--cy-color-status-info-soft", dark: CYRGB(hex: 0x4C86FF, alpha: 0.14), lightHex: 0x2563EB) }

    private func softFill(_ name: String, dark: CYRGB, lightHex: UInt32) -> Color {
        isDark ? token(name, dark: dark, light: CYRGB(hex: lightHex, alpha: Self.handbookStatusSoftAlpha)) : CYRGB(hex: lightHex, alpha: Self.handbookStatusSoftAlpha).swiftUIColor
    }

    // MARK: Handbook fixes (design hand-off r1, owner ruling 5: adopt them in the app)

    /// Light `border/strong`: 3:1 against white and the grey page.
    static let handbookBorderStrongHex: UInt32 = 0x8C8C8C
    /// Light input fill inside a card.
    static let handbookInputInCardHex: UInt32 = 0xEFEFEF
    /// Light input fill directly on the page.
    static let handbookInputOnPageHex: UInt32 = 0xE4E4E4
    /// Light status soft-fill alpha.
    static let handbookStatusSoftAlpha: Double = 0.18
    /// Home feed count (4.54:1; the shipped `#F97316` fails on the feed surface).
    static let handbookFeedCountHex: UInt32 = 0xC2410C
    /// Home feed count colour (`--cy-color-home-feed-count`, handbook value).
    var homeFeedCount: Color { CYRGB(hex: Self.handbookFeedCountHex).swiftUIColor }

    // MARK: Skeleton / overlay

    var skeletonBase: Color { token("--cy-color-skeleton-base", dark: CYRGB(hex: 0x191919), light: CYRGB(hex: 0xECEFF3)) }
    var skeletonHighlight: Color { token("--cy-color-skeleton-highlight", dark: CYRGB(hex: 0x242424), light: CYRGB(hex: 0xF6F8FA)) }
    /// `--cy-color-bg-glass`: `rgba(28,28,30,.82)` / `rgba(255,255,255,.88)`.
    var bgGlass: Color { token("--cy-color-bg-glass", dark: CYRGB(hex: 0x1C1C1E, alpha: 0.82), light: CYRGB(hex: 0xFFFFFF, alpha: 0.88)) }
    /// `--cy-color-overlay`: `rgba(0,0,0,.56)` in both domains.
    var overlay: Color { token("--cy-color-overlay", dark: CYRGB(hex: 0x000000, alpha: 0.56), light: CYRGB(hex: 0x000000, alpha: 0.56)) }

    // MARK: Rare, Medals, Playkit & Game Runtime

    /// `--cy-color-rare` (`#F59F00`).
    var rare: Color { token("--cy-color-rare", dark: CYRGB(hex: 0xF59F00), light: CYRGB(hex: 0xF59F00)) }
    /// `--cy-color-rare-fg` (`#F59F00` dark / `#96610A` light).
    var rareFg: Color { token("--cy-color-rare-fg", dark: CYRGB(hex: 0xF59F00), light: CYRGB(hex: 0x96610A)) }
    /// `--cy-color-rare-soft` (`rgba(245,159,0,.14)` dark / `rgba(245,159,0,.12)` light).
    var rareSoft: Color { token("--cy-color-rare-soft", dark: CYRGB(hex: 0xF59F00, alpha: 0.14), light: CYRGB(hex: 0xF59F00, alpha: 0.12)) }

    /// `--cy-color-medal-gold` (`#FFCB3C` / `#D27D08`).
    var medalGold: Color { token("--cy-color-medal-gold", dark: CYRGB(hex: 0xFFCB3C), light: CYRGB(hex: 0xD27D08)) }
    /// `--cy-color-medal-silver` (`#D6D6D6` / `#717171`).
    var medalSilver: Color { token("--cy-color-medal-silver", dark: CYRGB(hex: 0xD6D6D6), light: CYRGB(hex: 0x717171)) }
    /// `--cy-color-medal-bronze` (`#F58C41` / `#D6600B`).
    var medalBronze: Color { token("--cy-color-medal-bronze", dark: CYRGB(hex: 0xF58C41), light: CYRGB(hex: 0xD6600B)) }

    // Playkit category accents (`--cy-color-playkit-*`)
    var playkitAI: Color { token("--cy-color-playkit-ai", dark: CYRGB(hex: 0xB06CFF), light: CYRGB(hex: 0xB06CFF)) }
    var playkitCarbon: Color { token("--cy-color-playkit-carbon", dark: CYRGB(hex: 0xA3C644), light: CYRGB(hex: 0xA3C644)) }
    var playkitCraft: Color { token("--cy-color-playkit-craft", dark: CYRGB(hex: 0x2EC4B6), light: CYRGB(hex: 0x2EC4B6)) }
    var playkitMerit: Color { token("--cy-color-playkit-merit", dark: CYRGB(hex: 0xE8B44A), light: CYRGB(hex: 0xE8B44A)) }
    var playkitMusic: Color { token("--cy-color-playkit-music", dark: CYRGB(hex: 0x8C5CFF), light: CYRGB(hex: 0x8C5CFF)) }
    var playkitNight: Color { token("--cy-color-playkit-night", dark: CYRGB(hex: 0x5B8DEF), light: CYRGB(hex: 0x5B8DEF)) }
    var playkitSign: Color { token("--cy-color-playkit-sign", dark: CYRGB(hex: 0xE5484D), light: CYRGB(hex: 0xE5484D)) }
    var playkitSilent: Color { token("--cy-color-playkit-silent", dark: CYRGB(hex: 0xFF6B35), light: CYRGB(hex: 0xFF6B35)) }
    var playkitSlow: Color { token("--cy-color-playkit-slow", dark: CYRGB(hex: 0x7E8CE0), light: CYRGB(hex: 0x7E8CE0)) }
    var playkitSticker: Color { token("--cy-color-playkit-sticker", dark: CYRGB(hex: 0xF06292), light: CYRGB(hex: 0xF06292)) }
    var playkitTaste: Color { token("--cy-color-playkit-taste", dark: CYRGB(hex: 0x33C773), light: CYRGB(hex: 0x33C773)) }

    // Play-story tokens (`--cy-color-play-story-*`)
    var playStoryAccent: Color { token("--cy-color-play-story-accent", dark: CYRGB(hex: 0x4B46F5), light: CYRGB(hex: 0x4B46F5)) }
    var playStoryAccentSoft: Color { token("--cy-color-play-story-accent-soft", dark: CYRGB(hex: 0x4B46F5, alpha: 0.14), light: CYRGB(hex: 0x4B46F5, alpha: 0.14)) }
    var playStoryAccentFade: Color { token("--cy-color-play-story-accent-fade", dark: CYRGB(hex: 0x8C91A0), light: CYRGB(hex: 0x8C91A0)) }
    var playStoryCtaFg: Color { token("--cy-color-play-story-cta-fg", dark: CYRGB(hex: 0xFFFFFF), light: CYRGB(hex: 0xFFFFFF)) }
    var playStoryPage: Color { token("--cy-color-play-story-page", dark: CYRGB(hex: 0xFFFFFF), light: CYRGB(hex: 0xFFFFFF)) }
    var playStorySurface: Color { token("--cy-color-play-story-surface", dark: CYRGB(hex: 0xF6F7FA), light: CYRGB(hex: 0xF6F7FA)) }
    var playStoryText: Color { token("--cy-color-play-story-text", dark: CYRGB(hex: 0x111111), light: CYRGB(hex: 0x111111)) }
    var playStoryMuted: Color { token("--cy-color-play-story-muted", dark: CYRGB(hex: 0x5E6470), light: CYRGB(hex: 0x5E6470)) }
    var playStoryLine: Color { token("--cy-color-play-story-line", dark: CYRGB(hex: 0x8B8F99), light: CYRGB(hex: 0x8B8F99)) }

    // Game runtime set (`.theme-game`)
    private func gameToken(_ name: String, fallback: CYRGB) -> Color {
        Theme.Generated.color(name, in: .game) ?? fallback.swiftUIColor
    }
    var gameAccent: Color { gameToken("--cy-game-accent", fallback: CYRGB(hex: 0xD0323B)) }
    var gameAccentFg: Color { gameToken("--cy-game-accent-fg", fallback: CYRGB(hex: 0xFFFFFF)) }
    var gameAccentSoft: Color { gameToken("--cy-game-accent-soft", fallback: CYRGB(hex: 0xD0323B, alpha: 0.10)) }
    var gameMarker: Color { gameToken("--cy-game-marker", fallback: CYRGB(hex: 0xF59F00)) }
    var gameWin: Color { gameToken("--cy-game-win", fallback: CYRGB(hex: 0x0B7A57)) }
    var gameFloodWin: Color { gameToken("--cy-game-flood-win", fallback: CYRGB(hex: 0x0B7A57, alpha: 0.14)) }
    var gameFloodOk: Color { gameToken("--cy-game-flood-ok", fallback: CYRGB(hex: 0xF59F00, alpha: 0.16)) }
    var gameFloodMiss: Color { gameToken("--cy-game-flood-miss", fallback: CYRGB(hex: 0xD0323B, alpha: 0.12)) }
    var gameHeroSize: CGFloat { Theme.Generated.length("--cy-game-type-hero", in: .game) ?? 66 }
    var gameReadoutSize: CGFloat { Theme.Generated.length("--cy-game-type-readout", in: .game) ?? 32 }

    // MARK: Reserved `#7A5CFF` Roles (tabSelected, avatarRing, resultSpinner ONLY)

    /// Selected tab icon/label tint. Neutral since the design hand-off r1 (owner ruling, PL-01): the selected tab is the
    /// primary ink at full opacity (white on the player bar, black on the merchant bar); unselected items stay at 60%.
    /// The MP tab ink (`#F8F8F8` / `#000000`), kept as the brand selected state while body text moves to `label`.
    var tabSelectedTint: Color { followsSystem ? Self.systemAccent : token("--cy-color-text-primary", dark: CYRGB(hex: 0xF8F8F8), light: CYRGB(hex: 0x000000)) }
    /// Selected tab capsule behind the icon and label: ink at 12% (PL-01; was a violet pill, then a blank white one).
    var tabSelectedCapsule: Color { tabSelectedTint.opacity(0.12) }
    /// Profile hero avatar ring (`--cy-comp-profile-avatar-ring` `#7A5CFF`).
    var avatarRing: Color {
        token(
            "--cy-comp-profile-avatar-ring",
            dark: CYRGB(hex: Theme.MiniProgramChrome.tabSelectedHex),
            light: CYRGB(hex: Theme.MiniProgramChrome.tabSelectedHex)
        )
    }
    /// Result overlay spinner tint (`--cy-comp-result-spinner` `#7A5CFF`).
    var resultSpinner: Color {
        token(
            "--cy-comp-result-spinner",
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
    var radius: CGFloat = Theme.Radius.card   // native restyle r1: one card radius, 12pt
    var padding: CGFloat = 16               // --cy-comp-card-pad 32rpx

    @Environment(\.cyPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let shadowRadius: CGFloat = 0   // native restyle r1 (spec §3.3): cards carry no shadow
        let shadowY: CGFloat = 0
        content
            .padding(padding)
            .background(
                shape.fill(palette.cardFill)
                    .shadow(color: palette.cardShadowColor, radius: shadowRadius, x: 0, y: shadowY)
            )
            .overlay {
                if colorScheme == .dark {
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(palette.cardHighlight)
                            .frame(height: 0.5)
                        Spacer(minLength: 0)
                    }
                    .clipShape(shape)
                    .allowsHitTesting(false)
                }
            }
    }
}

extension View {
    /// Card surface that follows the mini-program tokens for the current role domain.
    /// Default radius is `--cy-comp-card-radius` (32rpx = 16pt).
    func cyDomainCard(radius: CGFloat = Theme.Radius.card, padding: CGFloat = 16) -> some View {
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
        let tokens = CYDomainButtonTokens.resolve(kind: .primary, isEnabled: isEnabled, isPressed: configuration.isPressed, in: palette)
        let shape = Capsule(style: .continuous)   // native-ios-r1 §3.6: capsule system buttons
        configuration.label
            .cyText(.button)
            .cyWrapText(alignment: .center)
            .foregroundStyle(tokens.foreground)
            .padding(.horizontal, 20)   // --cy-btn-pad-x 40rpx
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)   // --cy-btn-h 88rpx
            .background(shape.fill(tokens.background))
            .contentShape(shape)
            .opacity(tokens.opacity)
    }
}

/// Mini-program secondary button: grey fill only, NO outline (2026-08-05 decision), secondary-text colour.
struct CYDomainSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let tokens = CYDomainButtonTokens.resolve(kind: .secondary, isEnabled: isEnabled, isPressed: configuration.isPressed, in: palette)
        let shape = Capsule(style: .continuous)   // native-ios-r1 §3.6: capsule system buttons
        configuration.label
            .cyText(.button)
            .cyWrapText(alignment: .center)
            .foregroundStyle(tokens.foreground)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(shape.fill(tokens.background))
            .contentShape(shape)
            .opacity(tokens.opacity)
    }
}

/// Mini-program danger button: solid `#D0323B` with white label.
struct CYDomainDestructiveButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let tokens = CYDomainButtonTokens.resolve(kind: .destructive, isEnabled: isEnabled, isPressed: configuration.isPressed, in: palette)
        let shape = Capsule(style: .continuous)   // native-ios-r1 §3.6: capsule system buttons
        configuration.label
            .cyText(.button)
            .cyWrapText(alignment: .center)
            .foregroundStyle(tokens.foreground)
            .padding(.horizontal, 20)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: 44)
            .background(shape.fill(tokens.background))
            .contentShape(shape)
            .opacity(tokens.opacity)
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

enum CYDomainButtonKind: Sendable {
    case primary
    case secondary
    case destructive
}

enum CYDomainButtonTokens {
    struct Resolved {
        let foreground: Color
        let background: Color
        let opacity: Double
    }

    static func resolve(
        kind: CYDomainButtonKind,
        isEnabled: Bool,
        isPressed: Bool,
        in palette: CYDomainPalette
    ) -> Resolved {
        let foreground: Color
        let background: Color
        if !isEnabled {
            foreground = palette.textPlaceholder
            background = palette.bgSurfaceSubtle
        } else {
            switch kind {
            case .primary:
                foreground = palette.actionPrimaryFg
                background = palette.actionPrimaryBg
            case .secondary:
                foreground = palette.textSecondary
                background = palette.actionSecondaryBg
            case .destructive:
                foreground = palette.actionDangerFg
                background = palette.actionDangerBg
            }
        }
        return Resolved(foreground: foreground, background: background, opacity: isPressed ? 0.88 : 1.0)
    }
}

// MARK: - Previews (synthetic fixtures, preview-only)

private struct CYDomainPalettePreviewContent: View {
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text(verbatim: "Preview card")
                    .cyText(.cardTitle)
                    .foregroundStyle(palette.textPrimary)
                Text(verbatim: "Secondary line 1,234")
                    .cyText(.body, monospacedDigit: true)
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

/// The UIKit semantic colours the native restyle maps palette tokens onto (native-ios-r1 §2.2).
enum CYNativeColor {
    case groupedBackground, secondaryGroupedBackground, tertiaryGroupedBackground
    case secondaryFill, tertiaryFill
    case label, secondaryLabel, quaternaryLabel, placeholder
    case separator, segmentThumb, background

    #if canImport(UIKit)
    var uiColor: UIColor {
        switch self {
        case .groupedBackground: return .systemGroupedBackground
        case .secondaryGroupedBackground: return .secondarySystemGroupedBackground
        case .tertiaryGroupedBackground: return .tertiarySystemGroupedBackground
        case .secondaryFill: return .secondarySystemFill
        case .tertiaryFill: return .tertiarySystemFill
        case .label: return .label
        case .secondaryLabel: return .secondaryLabel
        case .quaternaryLabel: return .quaternaryLabel
        case .placeholder: return .placeholderText
        case .separator: return .separator
        case .segmentThumb:
            return UIColor { $0.userInterfaceStyle == .dark
                ? UIColor(red: 0x63 / 255, green: 0x63 / 255, blue: 0x66 / 255, alpha: 1)
                : .white }
        case .background: return .systemBackground
        }
    }
    #endif
}
