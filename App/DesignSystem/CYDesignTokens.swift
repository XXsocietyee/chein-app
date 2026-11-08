import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - DesignSystem Namespace

/// Authoritative native iOS Design System for Chengyin (城瘾 / Questify).
///
/// Mirrors `城瘾小程序_设计系统权威基准_20260801.md` and `chengyinhub-xcx/style/tokens.wxss`
/// while adapting to iOS 17+ Human Interface Guidelines:
/// - Semantic colours from `CYDomainPalette.resolving(_:)` (player dark / merchant light). Violet is the selected tab icon only.
/// - Verified WCAG 2.1 AA contrast ratios (>= 4.5:1 normal text, >= 3.0:1 large text & UI controls)
/// - Dynamic Type scale with `@ScaledMetric` support
/// - 4pt spacing grid (`pageX = 16pt`)
/// - Continuous squircle corner radii
public enum DesignSystem {}

// MARK: - RGB & WCAG Contrast Utilities

public struct CYRGB: Equatable, Sendable {
    public let r: Double
    public let g: Double
    public let b: Double
    public let a: Double

    public init(r: Double, g: Double, b: Double, a: Double = 1.0) {
        self.r = r
        self.g = g
        self.b = b
        self.a = a
    }

    public init(hex: UInt32, alpha: Double = 1.0) {
        self.r = Double((hex >> 16) & 0xFF) / 255.0
        self.g = Double((hex >> 8) & 0xFF) / 255.0
        self.b = Double(hex & 0xFF) / 255.0
        self.a = alpha
    }

    public var swiftUIColor: Color {
        Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    /// Relative luminance per WCAG 2.1 specification.
    public var relativeLuminance: Double {
        func linearize(_ channel: Double) -> Double {
            channel <= 0.03928 ? (channel / 12.92) : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linearize(r) + 0.7152 * linearize(g) + 0.0722 * linearize(b)
    }

    /// WCAG 2.1 contrast ratio against another colour (range 1.0 ... 21.0).
    public func contrastRatio(against other: CYRGB) -> Double {
        let l1 = max(relativeLuminance, other.relativeLuminance)
        let l2 = min(relativeLuminance, other.relativeLuminance)
        return (l1 + 0.05) / (l2 + 0.05)
    }

    /// Checks whether this foreground/background pair meets WCAG AA (4.5:1 normal text, 3.0:1 large text).
    public func meetsWCAGAA(against background: CYRGB, isLargeText: Bool = false) -> Bool {
        contrastRatio(against: background) >= (isLargeText ? 3.0 : 4.5)
    }
}

// MARK: - Semantic Colour Tokens

public enum CYColor {

    // MARK: Dynamic Light/Dark Helper

    public static func dynamic(light: CYRGB, dark: CYRGB) -> Color {
        #if canImport(UIKit)
        return Color(
            UIColor { traits in
                let target = traits.userInterfaceStyle == .dark ? dark : light
                return UIColor(
                    red: CGFloat(target.r),
                    green: CGFloat(target.g),
                    blue: CGFloat(target.b),
                    alpha: CGFloat(target.a)
                )
            }
        )
        #else
        return dark.swiftUIColor
        #endif
    }

    /// Every role colour below is read from this palette. Dark is player; light is merchant.
    private static func resolved(_ component: @escaping (CYDomainPalette) -> Color) -> Color {
        #if canImport(UIKit)
        Color(UIColor { traits in
            let scheme: ColorScheme = traits.userInterfaceStyle == .dark ? .dark : .light
            return UIColor(component(CYDomainPalette.resolving(scheme)))
        })
        #else
        component(CYDomainPalette.resolving(.dark))
        #endif
    }

    // MARK: 1. Brand, selection, and actions (neutral; violet is not a brand colour)

    /// Retained RGB constant. Painted brand, selection, and CTA colours use `CYDomainPalette.resolving(_:)`, not this value.
    public static let accentRGB = CYRGB(hex: 0x7A5CFF)
    /// Retained RGB constant. Painted `accentStrong` reads `brandStrong` from the domain palette.
    public static let accentStrongLightRGB = CYRGB(hex: 0x6A4AF0)
    /// Retained RGB constant. Painted `accentText` reads `brand` from the domain palette.
    public static let accentTextDarkRGB = CYRGB(hex: 0xC4B5FD)
    /// Retained RGB constants. Painted `accentSoft` reads `brandSoft` from the domain palette.
    public static let accentSoftLightRGB = CYRGB(hex: 0xEDE9FE)
    public static let accentSoftDarkRGB = CYRGB(hex: 0x7A5CFF, alpha: 0.18)

    /// Brand, selection, and primary CTA fill. Player near-white `#F8F8F8`; merchant grey `#33363C`.
    public static let brand = resolved { $0.brand }
    /// Selection fill. Same pair as `brand` (`--cy-color-selection`).
    public static let selection = resolved { $0.selection }
    /// Primary interactive fill. Calls `CYDomainPalette.resolving(_:)` then `brand`.
    public static let accent = brand

    /// Pressed brand fill (`--cy-color-brand-strong`).
    public static let accentStrong = resolved { $0.brandStrong }

    /// Pressed primary CTA. Same palette value as `accentStrong`.
    public static let accentPressed = accentStrong

    /// Accent text on a page surface: near-white on player, `#33363C` on merchant.
    public static let accentText = brand

    /// Soft brand tint (`--cy-color-brand-soft`).
    public static let accentSoft = resolved { $0.brandSoft }

    /// Secondary action fill (`--cy-color-action-secondary-bg`).
    public static let actionSecondary = resolved { $0.actionSecondaryBg }

    /// Secondary warm coral accent for play/badge highlights (`#FF6B4A` light, `#FF8266` dark).
    public static let accentWarm = dynamic(
        light: CYRGB(hex: 0xE04F2E),
        dark: CYRGB(hex: 0xFF8266)
    )

    // MARK: 2. Surface & Dark Base (#0A0A0B Family + Light Counterparts)

    /// Dark base `#0A0A0B` (`--cy-bg-surface` dark) and `#000000` (`--cy-bg-page` dark).
    public static let darkPageRGB = CYRGB(hex: 0x000000)
    public static let darkBaseRGB = CYRGB(hex: 0x0A0A0B)
    public static let darkSubtleRGB = CYRGB(hex: 0x141416)
    public static let darkElevatedRGB = CYRGB(hex: 0x1C1C1E)
    public static let darkRaisedRGB = CYRGB(hex: 0x2A2A2C)
    public static let darkStrongRGB = CYRGB(hex: 0x3B3B3D)

    public static let lightPageRGB = CYRGB(hex: 0xF3F4F4)
    public static let lightSurfaceRGB = CYRGB(hex: 0xFFFFFF)
    public static let lightSubtleRGB = CYRGB(hex: 0xEEEEEE)
    public static let lightElevatedRGB = CYRGB(hex: 0xFFFFFF)
    public static let lightRaisedRGB = CYRGB(hex: 0xE6E6E6)
    public static let lightStrongRGB = CYRGB(hex: 0xE4E4E4)

    /// Root page background (`#F3F4F4` light / `#000000` dark).
    public static let bgPage = dynamic(light: lightPageRGB, dark: darkPageRGB)

    /// Primary card and section surface (`#FFFFFF` light / `#0A0A0B` dark).
    public static let bgSurface = dynamic(light: lightSurfaceRGB, dark: darkBaseRGB)

    /// Subtle secondary container (`#EEEEEE` light / `#141416` dark).
    public static let bgSurfaceSubtle = dynamic(light: lightSubtleRGB, dark: darkSubtleRGB)

    /// Elevated card / modal / sheet background (`#FFFFFF` light / `#1C1C1E` dark).
    public static let bgElevated = dynamic(light: lightElevatedRGB, dark: darkElevatedRGB)

    /// Nested pill / input / skeleton base (`#E6E6E6` light / `#2A2A2C` dark).
    public static let bgRaised = dynamic(light: lightRaisedRGB, dark: darkRaisedRGB)

    /// Pressed or emphasized neutral surface (`#E4E4E4` light / `#3B3B3D` dark).
    public static let bgSurfaceStrong = dynamic(light: lightStrongRGB, dark: darkStrongRGB)

    /// Translucent glass (`--cy-color-bg-glass`).
    public static let bgGlass = resolved { $0.bgGlass }

    /// Modal backdrop scrim (`--cy-color-overlay`).
    public static let bgOverlay = resolved { $0.overlay }

    // MARK: 3. Text Hierarchy (WCAG AA Verified)

    public static let textPrimaryLightRGB = CYRGB(hex: 0x18181B)   // 17.7:1 on #FFFFFF
    public static let textPrimaryDarkRGB = CYRGB(hex: 0xF5F5F7)    // 18.1:1 on #0A0A0B

    public static let textSecondaryLightRGB = CYRGB(hex: 0x3F3F46) // 10.3:1 on #FFFFFF
    public static let textSecondaryDarkRGB = CYRGB(hex: 0xD4D4D8)  // 13.0:1 on #0A0A0B

    public static let textTertiaryLightRGB = CYRGB(hex: 0x52525B)  // 7.4:1 on #FFFFFF
    public static let textTertiaryDarkRGB = CYRGB(hex: 0xA1A1AA)   // 7.6:1 on #0A0A0B

    public static let textPlaceholderLightRGB = CYRGB(hex: 0x71717A) // 4.8:1 on #FFFFFF (passes AA)
    public static let textPlaceholderDarkRGB = CYRGB(hex: 0x8E8E98)  // 5.9:1 on #0A0A0B (passes AA)

    /// Primary body & headline text (`#18181B` light / `#F5F5F7` dark).
    public static let textPrimary = dynamic(light: textPrimaryLightRGB, dark: textPrimaryDarkRGB)

    /// Secondary descriptive text from the domain palette.
    public static let textSecondary = resolved { $0.textSecondary }

    /// Tertiary metadata from the domain palette.
    public static let textTertiary = resolved { $0.textTertiary }

    /// Input placeholder & muted hint text (`#71717A` light / `#8E8E98` dark, >= 4.5:1 AA).
    public static let textPlaceholder = dynamic(light: textPlaceholderLightRGB, dark: textPlaceholderDarkRGB)

    /// Disabled control label (`#71717A` light / `#6E6E77` dark).
    public static let textDisabled = dynamic(
        light: CYRGB(hex: 0x71717A),
        dark: CYRGB(hex: 0x6E6E77)
    )

    /// Label on the primary CTA: `#0A0A0A` on the player near-white fill, white on merchant `#33363C`.
    public static let textOnAccent = resolved { $0.actionPrimaryFg }

    /// Inverse text (`#FFFFFF` light / `#0A0A0B` dark).
    public static let textInverse = dynamic(light: CYRGB(hex: 0xFFFFFF), dark: darkBaseRGB)

    // MARK: 4. Semantic Status Colours (WCAG AA Foreground + Soft Surface)

    public static let successText = resolved { $0.success }
    public static let successSoft = resolved { $0.successSoft }

    public static let warningText = resolved { $0.warning }
    public static let warningSoft = resolved { $0.warningSoft }

    public static let dangerText = resolved { $0.danger }
    /// Solid danger action fill (`--cy-color-action-danger-bg`, `#D0323B` in both roles).
    public static let dangerSolid = resolved { $0.actionDangerBg }
    public static let dangerSoft = resolved { $0.dangerSoft }

    public static let infoText = resolved { $0.info }
    public static let infoSoft = resolved { $0.infoSoft }

    // MARK: 5. Borders & Dividers

    /// Hairline card/list divider (`rgba(15,23,42,0.08)` light / `rgba(255,255,255,0.09)` dark).
    public static let borderSubtle = dynamic(
        light: CYRGB(hex: 0x0F172A, alpha: 0.08),
        dark: CYRGB(hex: 0xFFFFFF, alpha: 0.09)
    )

    /// Emphasized control outline (`rgba(15,23,42,0.16)` light / `rgba(255,255,255,0.18)` dark).
    public static let borderStrong = dynamic(
        light: CYRGB(hex: 0x0F172A, alpha: 0.16),
        dark: CYRGB(hex: 0xFFFFFF, alpha: 0.18)
    )

    /// Keyboard / accessibility focus ring (`#7A5CFF`).
    public static let focusRing = accent
}

// MARK: - Dynamic Type Scale (CYTypography)

/// Semantic typography tokens mapped to iOS Dynamic Type (`Font.TextStyle`).
/// Never uses fixed pixel heights; scales automatically with user accessibility settings.
public enum CYTypography {

    /// Hero display title (`32pt` base -> `.largeTitle`, bold, tight tracking).
    public static var display: Font {
        .system(.largeTitle, design: .rounded).weight(.bold)
    }

    /// Primary page title (`26pt` base -> `.title`, bold).
    public static var pageTitle: Font {
        .system(.title, design: .default).weight(.bold)
    }

    /// Sheet / modal title (`22pt` base -> `.title2`, semibold).
    public static var sheetTitle: Font {
        .system(.title2, design: .default).weight(.semibold)
    }

    /// Section header title (`18pt` base -> `.title3`, semibold).
    public static var sectionTitle: Font {
        .system(.title3, design: .default).weight(.semibold)
    }

    /// Card headline (`16pt` base -> `.headline`, semibold).
    public static var cardTitle: Font {
        .system(.headline, design: .default)
    }

    /// Standard reading body (`15pt` base -> `.body`, regular).
    public static var body: Font {
        .system(.body, design: .default)
    }

    /// Emphasized body (`15pt` base -> `.body`, medium).
    public static var bodyMedium: Font {
        .system(.body, design: .default).weight(.medium)
    }

    /// Compact secondary copy (`14pt` base -> `.subheadline`, regular).
    public static var bodyCompact: Font {
        .system(.subheadline, design: .default)
    }

    /// Interactive control / button / tab label (`14pt` base -> `.subheadline`, semibold).
    public static var label: Font {
        .system(.subheadline, design: .default).weight(.semibold)
    }

    /// Metadata, timestamps, secondary row hints (`12pt` base -> `.footnote`, regular).
    public static var meta: Font {
        .system(.footnote, design: .default)
    }

    /// Dense badge / tag / pill caption (`11pt` base -> `.caption`, medium).
    public static var caption: Font {
        .system(.caption, design: .default).weight(.medium)
    }

    /// Micro legal / counter / status label (`10pt` base -> `.caption2`, semibold).
    public static var micro: Font {
        .system(.caption2, design: .default).weight(.semibold)
    }

    /// Financial / wallet / leaderboard hero number (`28pt` base -> `.title`, bold, monospaced digits).
    public static var dataXL: Font {
        .system(.title, design: .rounded).weight(.bold).monospacedDigit()
    }

    /// Wallet balance / settlement primary total (`34pt` base -> `.largeTitle`, bold, monospaced digits).
    public static var data2XL: Font {
        .system(.largeTitle, design: .rounded).weight(.bold).monospacedDigit()
    }

    /// Tabular numeric body for prices, distances, countdowns, and scores.
    public static var numericBody: Font {
        .system(.subheadline, design: .rounded).weight(.semibold).monospacedDigit()
    }
}

// MARK: - 4pt Grid Spacing Scale (CYSpacing)

/// Strict 4pt spatial grid aligned with `tokens.wxss` and `Theme.Space`.
public enum CYSpacing {
    /// `2pt` optical hairline offset (`--cy-space-2`).
    public static let xxs: CGFloat = 2
    /// `4pt` minimum grid unit (`--cy-space-4`, icon-to-text gap).
    public static let xs: CGFloat = 4
    /// `8pt` compact chip/tag gap (`--cy-space-8`).
    public static let sm: CGFloat = 8
    /// `12pt` list row / inner card stack spacing (`--cy-space-12`).
    public static let md: CGFloat = 12
    /// `16pt` standard page horizontal margin & card padding (`--cy-page-x` / `--cy-space-16`).
    public static let lg: CGFloat = 16
    /// `20pt` spacious card padding (`--cy-space-20`).
    public static let xl: CGFloat = 20
    /// `24pt` major section vertical rhythm (`--cy-space-24`).
    public static let xxl: CGFloat = 24
    /// `32pt` hero block separation (`--cy-space-32`).
    public static let xxxl: CGFloat = 32
    /// `40pt` empty/error state vertical breathing room (`--cy-space-40`).
    public static let hero: CGFloat = 40
    /// `48pt` sheet / top-level showcase spacing (`--cy-space-48`).
    public static let jumbo: CGFloat = 48

    /// Standard page horizontal inset (`16pt`).
    public static let pageHorizontal: CGFloat = lg
    /// Minimum interactive tap target dimension per Apple HIG (`44pt`).
    public static let minTouchTarget: CGFloat = 44
}

// MARK: - Corner Radii (CYRadius)

/// Continuous squircle corner radius scale aligned with `城瘾小程序_设计系统权威基准_20260801.md`.
public enum CYRadius {
    /// `8pt` small tags, code chips, compact thumbnails (`--cy-radius-xs`).
    public static let xs: CGFloat = 8
    /// `12pt` secondary buttons, text fields, list rows (`--cy-radius-sm`).
    public static let sm: CGFloat = 12
    /// `16pt` standard content cards (`--cy-radius-md`).
    public static let md: CGFloat = 16
    /// `20pt` featured topic/activity cards (`--cy-radius-lg`).
    public static let lg: CGFloat = 20
    /// `22pt` hero banners & wallet summary cards (`--cy-radius-xl`).
    public static let xl: CGFloat = 22
    /// `24pt` bottom sheets & modal dialogs (`--cy-radius-sheet`).
    public static let sheet: CGFloat = 24
    /// `999pt` full capsule pills & primary CTAs (`--cy-radius-pill`).
    public static let pill: CGFloat = 999
}

// MARK: - DesignSystem Typealiases

public extension DesignSystem {
    typealias Colors = CYColor
    typealias Typography = CYTypography
    typealias Spacing = CYSpacing
    typealias Radius = CYRadius
}
