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

    // MARK: 1. Brand, selection, and actions (neutral; #7A5CFF reserved ONLY for tabSelected, avatarRing, resultSpinner)

    /// Brand and selection neutral (`--cy-color-brand`: `#F8F8F8` dark / `#33363C` light).
    public static let brand = resolved { $0.brand }
    /// Pressed brand fill (`--cy-color-brand-strong`: `#B7B7B7` dark / `#33363C` light).
    public static let brandStrong = resolved { $0.brandStrong }
    /// Soft brand tint (`--cy-color-brand-soft`: `rgba(248,248,248,.12)` dark / `#EAEBEE` light).
    public static let brandSoft = resolved { $0.brandSoft }
    /// Selection fill (`--cy-color-selection`: `#F8F8F8` dark / `#33363C` light).
    public static let selection = resolved { $0.selection }

    /// Primary CTA background (`--cy-color-action-primary-bg`: `#F8F8F8` dark / `#000000` light).
    public static let actionPrimaryBg = resolved { $0.actionPrimaryBg }
    /// Label on primary CTA (`--cy-color-action-primary-fg`: `#0A0A0A` dark / `#FFFFFF` light).
    public static let actionPrimaryFg = resolved { $0.actionPrimaryFg }
    /// Secondary action fill (`--cy-color-action-secondary-bg`: `rgba(255,255,255,.08)` dark / `#EEEEEE` light).
    public static let actionSecondary = resolved { $0.actionSecondaryBg }

    /// Selected bottom tab bar icon/label tint (`--cy-ref-violet-500` `#7A5CFF`; 1 of 3 reserved violet roles).
    public static let tabSelected = resolved { $0.tabSelectedTint }
    /// Profile hero avatar ring (`--cy-comp-profile-avatar-ring` `#7A5CFF`; 2 of 3 reserved violet roles).
    public static let avatarRing = resolved { $0.avatarRing }
    /// Result overlay spinner (`--cy-comp-result-spinner` `#7A5CFF`; 3 of 3 reserved violet roles).
    public static let resultSpinner = resolved { $0.resultSpinner }

    // MARK: 2. Surface & Sheet / Modal Role Tokens (delegated to CYDomainPalette / Theme.Generated)

    /// Root page background (`--cy-color-bg-page`: `#F3F4F4` light / `#000000` dark).
    public static let bgPage = resolved { $0.bgPage }
    /// Primary section surface (`--cy-color-bg-surface`: `#FFFFFF` light / `#111111` dark).
    public static let bgSurface = resolved { $0.bgSurface }
    /// Subtle secondary container (`--cy-color-bg-surface-subtle`: `#EEEEEE` light / `#141416` dark).
    public static let bgSurfaceSubtle = resolved { $0.bgSurfaceSubtle }
    /// Elevated card surface (`--cy-color-bg-elevated`: `#FFFFFF` light / `#1C1C1E` dark).
    public static let bgElevated = resolved { $0.bgElevated }
    /// Nested pill / input base (`--cy-color-bg-raised`: `#E6E6E6` light / `#2A2A2C` dark).
    public static let bgRaised = resolved { $0.bgRaised }
    /// Emphasized neutral surface (`--cy-color-bg-surface-strong`: `#E4E4E4` light / `#3B3B3D` dark).
    public static let bgSurfaceStrong = resolved { $0.bgStrong }
    /// Interactive neutral chip / round control (`--cy-color-bg-interactive`: `#FFFFFF` light / `#4D4D4D` dark).
    public static let bgInteractive = resolved { $0.bgInteractive }
    /// Translucent glass (`--cy-color-bg-glass`).
    public static let bgGlass = resolved { $0.bgGlass }
    /// Modal backdrop scrim (`--cy-color-overlay`).
    public static let bgOverlay = resolved { $0.overlay }
    /// Player sheet glass (`--cy-comp-sheet-player-glass` `rgba(44,44,46,.98)` dark / `#FFFFFF` light).
    public static let sheetGlass = resolved { $0.sheetGlass }
    /// Nested card inside a sheet (`--cy-comp-sheet-player-card` `#3A3A3C` dark / `#FFFFFF` light).
    public static let sheetCard = resolved { $0.sheetCard }
    /// Centered modal panel (`--cy-comp-modal-panel` `#4D4D4D` dark / `#FFFFFF` light).
    public static let modalPanel = resolved { $0.modalPanel }
    public static let sheetHandle = resolved { $0.sheetHandle }
    public static let inputIdleBg = resolved { $0.inputIdleBg }
    public static let inputFilledBg = resolved { $0.inputFilledBg }
    public static let inputDisabledBg = resolved { $0.inputDisabledBg }
    public static let coverFallback = resolved { $0.coverFallback }
    public static let skeletonBase = resolved { $0.skeletonBase }
    public static let skeletonHighlight = resolved { $0.skeletonHighlight }
    public static let cardHighlight = resolved { $0.cardHighlight }
    public static let cardShadowColor = resolved { $0.cardShadowColor }
    public static let floatShadowColor = resolved { $0.floatShadowColor }

    // MARK: 3. Text Hierarchy (delegated to CYDomainPalette / Theme.Generated)

    /// Primary body & headline text (`#000000` light / `#F8F8F8` dark).
    public static let textPrimary = resolved { $0.textPrimary }
    /// Secondary descriptive text (`#404040` light / `#C7C7C7` dark).
    public static let textSecondary = resolved { $0.textSecondary }
    /// Tertiary metadata (`#6B6B6B` light / `#A8A8A8` dark).
    public static let textTertiary = resolved { $0.textTertiary }
    /// Input placeholder & muted hint text (`#6F6F6F` light / `#9E9E9E` dark).
    public static let textPlaceholder = resolved { $0.textPlaceholder }
    /// Disabled control label (`#737373` light / `rgba(255,255,255,.40)` dark).
    public static let textDisabled = resolved { $0.textDisabled }
    /// Label on primary CTA (`#FFFFFF` light / `#0A0A0A` dark).
    public static let textOnAccent = resolved { $0.actionPrimaryFg }
    /// Inverse text (`#FFFFFF` light / `#0A0A0A` dark).
    public static let textInverse = resolved { $0.textInverse }

    // MARK: 4. Semantic Status, Rare & Medal Colours

    public static let successText = resolved { $0.success }
    public static let successSoft = resolved { $0.successSoft }

    public static let warningText = resolved { $0.warning }
    public static let warningSoft = resolved { $0.warningSoft }

    public static let dangerText = resolved { $0.danger }
    /// Solid danger action fill (`--cy-color-action-danger-bg`, `#D0323B` in both roles).
    public static let actionDangerBg = resolved { $0.actionDangerBg }
    public static let actionDangerFg = resolved { $0.actionDangerFg }
    public static let dangerSolid = resolved { $0.actionDangerBg }
    public static let dangerSoft = resolved { $0.dangerSoft }

    public static let infoText = resolved { $0.info }
    public static let infoSoft = resolved { $0.infoSoft }

    /// Rare badge / milestone amber (`--cy-color-rare` `#F59F00`).
    public static let rare = resolved { $0.rare }
    public static let rareFg = resolved { $0.rareFg }
    public static let rareSoft = resolved { $0.rareSoft }

    /// Medal podium tiers (`--cy-color-medal-*`).
    public static let medalGold = resolved { $0.medalGold }
    public static let medalSilver = resolved { $0.medalSilver }
    public static let medalBronze = resolved { $0.medalBronze }

    // Game runtime palette (`.theme-game`)
    public static let gameAccent = CYDomainPalette(.game).gameAccent
    public static let gameAccentFg = CYDomainPalette(.game).gameAccentFg
    public static let gameAccentSoft = CYDomainPalette(.game).gameAccentSoft
    public static let gameMarker = CYDomainPalette(.game).gameMarker
    public static let gameWin = CYDomainPalette(.game).gameWin
    public static let gameFloodWin = CYDomainPalette(.game).gameFloodWin
    public static let gameFloodOk = CYDomainPalette(.game).gameFloodOk
    public static let gameFloodMiss = CYDomainPalette(.game).gameFloodMiss

    // MARK: 5. Borders & Dividers (neutral only; no ink blue)

    /// Hairline divider (`--cy-color-border-subtle`: `#E8E8E8` light / `rgba(255,255,255,.08)` dark).
    public static let borderSubtle = resolved { $0.borderSubtle }
    /// Emphasized neutral control outline (`--cy-color-border-strong`: `#DBDBDB` light / `rgba(255,255,255,.16)` dark).
    public static let borderStrong = resolved { $0.borderStrong }
    /// Keyboard / accessibility focus ring (`brand`).
    public static let focusRing = brand
}

// MARK: - Typography Scale (CYTextStyle -> CYTypography / Theme.Font / cyText)

/// The one type scale (consist-1). Base: mini-program `style/tokens.wxss`, pt = rpx / 2 as integers (owner rule).
/// Rule card: `docs/design/type-and-chrome.md`. `CYTypography`, `Theme.Font` and `.cyText(_:)` all read this table.
enum CYTextStyle: String, CaseIterable {
    case display, pageTitle, sheetTitle, sectionTitle, cardTitle, button
    case body, bodyMedium, bodyCompact, label, meta, caption, micro
    case numericBody, dataXL, data2XL
}

/// One row of the scale.
struct CYTypeSpec {
    /// Point size at the default Dynamic Type size (Large). rpx / 2 from the mini-program.
    let size: CGFloat
    let weight: Font.Weight
    let design: Font.Design
    /// Mini-program CSS `line-height` multiple. Applied through `lineSpacing` by `.cyText(_:)`.
    let lineHeight: CGFloat
    /// Letter spacing in pt. 0 for every style: Chinese takes no tracking, and SF applies its own optical tracking.
    let tracking: CGFloat
    /// Dynamic Type style the size scales with (`@ScaledMetric(relativeTo:)` in `.cyText(_:)`).
    let relativeTo: Font.TextStyle
    /// Set only when `size` equals this text style's default size; the static `Font` token then uses the
    /// text style itself, so it scales with Dynamic Type even without `.cyText(_:)`.
    let nativeStyle: Font.TextStyle?
    let monospacedDigit: Bool

    init(
        _ size: CGFloat,
        _ weight: Font.Weight,
        lineHeight: CGFloat,
        relativeTo: Font.TextStyle,
        nativeStyle: Font.TextStyle? = nil,
        design: Font.Design = .default,
        monospacedDigit: Bool = false
    ) {
        self.size = size
        self.weight = weight
        self.design = design
        self.lineHeight = lineHeight
        self.tracking = 0
        self.relativeTo = relativeTo
        self.nativeStyle = nativeStyle
        self.monospacedDigit = monospacedDigit
    }

    /// PingFang SC, the system CJK face, is ascent 1.06 + descent 0.34 = 1.4 em tall, so a Chinese line is already
    /// about 1.4 x size before any spacing. `lineSpacing` adds only the rest of the mini-program line height and is
    /// never negative (a mini-program `1.3` stays at the natural 1.4).
    static let cjkNaturalLineHeight: CGFloat = 1.4

    func lineSpacing(at size: CGFloat) -> CGFloat {
        max(0, (lineHeight - Self.cjkNaturalLineHeight) * size)
    }
}

extension CYTextStyle {
    var spec: CYTypeSpec {
        switch self {
        // rpx 56 -> 28 pt. Hero display text (onboarding, result, empty-state hero).
        case .display: return CYTypeSpec(Theme.length("--cy-type-display"), .bold, lineHeight: 1.15, relativeTo: .largeTitle)
        // rpx 58 -> 29 pt. In-content page title. Tab roots use the system large title instead (cyRootHeader).
        case .pageTitle: return CYTypeSpec(Theme.length("--cy-type-page-title"), .bold, lineHeight: 1.2, relativeTo: .largeTitle)
        // rpx 44 -> 22 pt. Sheet / modal title (CYSheetHeader).
        case .sheetTitle: return CYTypeSpec(Theme.length("--cy-type-sheet-title"), .bold, lineHeight: 1.3, relativeTo: .title2, nativeStyle: .title2)
        // rpx 36 -> 18 pt. Section header inside a page.
        case .sectionTitle: return CYTypeSpec(Theme.length("--cy-type-section-title"), .bold, lineHeight: 1.25, relativeTo: .title3)
        // rpx 32 -> 16 pt, 600. Card / row headline.
        case .cardTitle: return CYTypeSpec(Theme.length("--cy-type-card-title"), .semibold, lineHeight: 1.3, relativeTo: .callout, nativeStyle: .callout)
        // rpx 32 -> 16 pt, 700. Button label (CYPillButton).
        case .button: return CYTypeSpec(Theme.length("--cy-type-button"), .bold, lineHeight: 1.3, relativeTo: .callout, nativeStyle: .callout)
        // rpx 28 -> 14 pt. Reading body.
        case .body: return CYTypeSpec(Theme.length("--cy-type-body"), .regular, lineHeight: 1.6, relativeTo: .body)
        // rpx 28 -> 14 pt, 600 (`.cy-text-body-strong`). Emphasised body.
        case .bodyMedium: return CYTypeSpec(Theme.length("--cy-type-body"), .semibold, lineHeight: 1.6, relativeTo: .body)
        // rpx 28 -> 14 pt, tight leading. Dense secondary copy: list subtitles, one- or two-line descriptions.
        case .bodyCompact: return CYTypeSpec(Theme.length("--cy-type-body"), .regular, lineHeight: 1.3, relativeTo: .subheadline)
        // rpx 24 -> 12 pt, 500. Control label: tab, field label, chip.
        case .label: return CYTypeSpec(Theme.length("--cy-type-label"), .medium, lineHeight: 1.35, relativeTo: .caption, nativeStyle: .caption)
        // rpx 24 -> 12 pt, 400. Metadata: time, count, location, secondary row hint.
        case .meta: return CYTypeSpec(Theme.length("--cy-type-label"), .regular, lineHeight: 1.35, relativeTo: .caption, nativeStyle: .caption)
        // rpx 22 -> 11 pt. Caption, tag, badge text.
        case .caption: return CYTypeSpec(Theme.length("--cy-type-caption"), .regular, lineHeight: 1.45, relativeTo: .caption2, nativeStyle: .caption2)
        // rpx 20 -> 10 pt, 500. Micro counter, legal footnote, status dot label.
        case .micro: return CYTypeSpec(Theme.length("--cy-type-micro"), .medium, lineHeight: 1.3, relativeTo: .caption2)
        // rpx 28 -> 14 pt, 600 rounded tabular. Inline numbers: price, points, counts in rows.
        case .numericBody: return CYTypeSpec(Theme.length("--cy-type-body"), .semibold, lineHeight: 1.3, relativeTo: .body, design: .rounded, monospacedDigit: true)
        // rpx 64 -> 32 pt, 700 rounded tabular. Stat hero number (wallet, leaderboard).
        case .dataXL: return CYTypeSpec(Theme.length("--cy-type-data-xl"), .bold, lineHeight: 1.05, relativeTo: .largeTitle, design: .rounded, monospacedDigit: true)
        // rpx 84 -> 42 pt, 700 rounded tabular. Balance / settlement total.
        case .data2XL: return CYTypeSpec(Theme.length("--cy-type-data-2xl"), .bold, lineHeight: 1.05, relativeTo: .largeTitle, design: .rounded, monospacedDigit: true)
        }
    }

    /// Static token (no line spacing). Scales with Dynamic Type only when the spec has a `nativeStyle`.
    var font: Font {
        let spec = self.spec
        let base: Font
        if let native = spec.nativeStyle {
            base = .system(native, design: spec.design, weight: spec.weight)
        } else {
            base = .system(size: spec.size, weight: spec.weight, design: spec.design)
        }
        return spec.monospacedDigit ? base.monospacedDigit() : base
    }

    /// The font at an already-scaled size (used by `.cyText(_:)`).
    func font(size: CGFloat, weight: Font.Weight? = nil, monospacedDigit: Bool = false) -> Font {
        let spec = self.spec
        let base = Font.system(size: size, weight: weight ?? spec.weight, design: spec.design)
        return (spec.monospacedDigit || monospacedDigit) ? base.monospacedDigit() : base
    }

    func lineSpacing(at size: CGFloat) -> CGFloat {
        spec.lineSpacing(at: size)
    }
}

/// Font plus line spacing plus Dynamic Type in one call. Works on a single `Text` or on a container.
private struct CYTextModifier: ViewModifier {
    let style: CYTextStyle
    let weight: Font.Weight?
    let monospacedDigit: Bool
    @ScaledMetric private var size: CGFloat

    init(style: CYTextStyle, weight: Font.Weight?, monospacedDigit: Bool) {
        self.style = style
        self.weight = weight
        self.monospacedDigit = monospacedDigit
        let spec = style.spec
        _size = ScaledMetric(wrappedValue: spec.size, relativeTo: spec.relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(style.font(size: size, weight: weight, monospacedDigit: monospacedDigit))
            .lineSpacing(style.lineSpacing(at: size))
    }
}

extension View {
    /// Preferred way to set text: `.cyText(.body)`. Applies the scale's font, its Chinese line height (as
    /// `lineSpacing`) and Dynamic Type scaling together. `weight` is for a one-off emphasis where the scale has no
    /// matching style; prefer the dedicated style (`.bodyMedium`, `.label`) when it exists.
    func cyText(_ style: CYTextStyle, weight: Font.Weight? = nil, monospacedDigit: Bool = false) -> some View {
        modifier(CYTextModifier(style: style, weight: weight, monospacedDigit: monospacedDigit))
    }
}

extension Text {
    /// Fallback the compiler picks only where a `Text` is required (`Text(a).cyText(.body) + Text(b)`, a `-> Text`
    /// builder, `navigationTitle(Text)`): the scale's static font, without line spacing. Everywhere else the
    /// `View` version above wins, so the codemod's `.font(x)` -> `.cyText(.y)` rewrite keeps compiling.
    @_disfavoredOverload
    func cyText(_ style: CYTextStyle, weight: Font.Weight? = nil, monospacedDigit: Bool = false) -> Text {
        var font = style.font
        if let weight { font = font.weight(weight) }
        if monospacedDigit { font = font.monospacedDigit() }
        return self.font(font)
    }
}

/// Semantic typography tokens. Names are stable; values come from `CYTextStyle.spec`.
/// These are plain `Font` values (no line spacing). In views prefer `.cyText(.body)`.
public enum CYTypography {

    /// Hero display title (`28pt`, bold, `--cy-type-display`).
    public static var display: Font {
        CYTextStyle.display.font
    }

    /// In-content page title (`29pt`, bold, `--cy-type-page-title`).
    public static var pageTitle: Font {
        CYTextStyle.pageTitle.font
    }

    /// Sheet / modal title (`22pt` `.title2`, bold, Dynamic Type).
    public static var sheetTitle: Font {
        CYTextStyle.sheetTitle.font
    }

    /// Section header title (`18pt`, bold, `--cy-type-section-title`).
    public static var sectionTitle: Font {
        CYTextStyle.sectionTitle.font
    }

    /// Card headline (`16pt` `.callout`, semibold, Dynamic Type).
    public static var cardTitle: Font {
        CYTextStyle.cardTitle.font
    }

    /// Primary button label (`16pt` `.callout`, bold, Dynamic Type `--cy-type-button`).
    public static var button: Font {
        CYTextStyle.button.font
    }

    /// Standard reading body (`14pt`, regular, `--cy-type-body`).
    public static var body: Font {
        CYTextStyle.body.font
    }

    /// Emphasized body (`14pt`, semibold, `.cy-text-body-strong`).
    public static var bodyMedium: Font {
        CYTextStyle.bodyMedium.font
    }

    /// Compact secondary copy (`14pt`, regular, tight leading).
    public static var bodyCompact: Font {
        CYTextStyle.bodyCompact.font
    }

    /// Interactive control / label (`12pt` `.caption`, medium, Dynamic Type `--cy-type-label`).
    public static var label: Font {
        CYTextStyle.label.font
    }

    /// Metadata, timestamps, secondary row hints (`12pt` `.caption`, regular, Dynamic Type).
    public static var meta: Font {
        CYTextStyle.meta.font
    }

    /// Dense badge / tag / pill caption (`11pt` `.caption2`, regular, Dynamic Type `--cy-type-caption`).
    public static var caption: Font {
        CYTextStyle.caption.font
    }

    /// Micro legal / counter / status label (`10pt`, medium, `--cy-type-micro`).
    public static var micro: Font {
        CYTextStyle.micro.font
    }

    /// Financial / wallet / leaderboard hero number (`32pt`, bold rounded tabular, `--cy-type-data-xl`).
    public static var dataXL: Font {
        CYTextStyle.dataXL.font
    }

    /// Wallet balance / settlement primary total (`42pt`, bold rounded tabular, `--cy-type-data-2xl`).
    public static var data2XL: Font {
        CYTextStyle.data2XL.font
    }

    /// Tabular numeric body (`14pt` semibold rounded tabular, `--cy-type-body`).
    public static var numericBody: Font {
        CYTextStyle.numericBody.font
    }
}

extension View {
    /// Titles and button labels grow downward. Long Chinese wraps instead of clipping.
    func cyWrapText(alignment: TextAlignment = .leading) -> some View {
        multilineTextAlignment(alignment)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - 4pt Grid Spacing Scale (CYSpacing -> Theme.Space)

/// Spatial grid delegating to `Theme.Space` (generated from `tokens.wxss`), including 6/10/14pt half-steps.
public enum CYSpacing {
    /// `2pt` optical hairline offset.
    public static let xxs: CGFloat = 2
    /// `4pt` minimum grid unit (`Theme.Space.s1`, `--cy-space-1`).
    public static let xs: CGFloat = Theme.Space.s1
    /// `6pt` compact half-step (`Theme.Space.s1_5`, `--cy-space-1-5`).
    public static let s1_5: CGFloat = Theme.Space.s1_5
    /// `8pt` compact chip/tag gap (`Theme.Space.s2`, `--cy-space-2`).
    public static let sm: CGFloat = Theme.Space.s2
    /// `10pt` dense half-step (`Theme.Space.s2_5`, `--cy-space-2-5`).
    public static let s2_5: CGFloat = Theme.Space.s2_5
    /// `12pt` list row / inner card stack spacing (`Theme.Space.s3`, `--cy-space-3`).
    public static let md: CGFloat = Theme.Space.s3
    /// `14pt` half-step (`Theme.Space.s3_5`, `--cy-space-3-5`).
    public static let s3_5: CGFloat = Theme.Space.s3_5
    /// `16pt` standard page horizontal margin & card padding (`Theme.Space.s4`, `--cy-space-4`).
    public static let lg: CGFloat = Theme.Space.s4
    /// `20pt` spacious card padding.
    public static let xl: CGFloat = 20
    /// `24pt` major section vertical rhythm (`Theme.Space.s5`, `--cy-space-5`).
    public static let xxl: CGFloat = Theme.Space.s5
    /// `32pt` hero block separation (`Theme.Space.s6`, `--cy-space-6`).
    public static let xxxl: CGFloat = Theme.Space.s6
    /// `40pt` empty/error state vertical breathing room (`Theme.Space.s7`, `--cy-space-7`).
    public static let hero: CGFloat = Theme.Space.s7
    /// `48pt` sheet / top-level showcase spacing (`Theme.Space.s8`, `--cy-space-8`).
    public static let jumbo: CGFloat = Theme.Space.s8

    /// Standard page horizontal inset (`Theme.Space.pageX` = `16pt`).
    public static let pageHorizontal: CGFloat = Theme.Space.pageX
    /// Minimum interactive tap target dimension (`Theme.MiniProgramChrome.minHit` = `44pt`).
    public static let minTouchTarget: CGFloat = Theme.MiniProgramChrome.minHit
}

// MARK: - Corner Radii (CYRadius -> Theme.Radius)

/// Continuous squircle corner radius scale unified with `Theme.Radius` and `tokens.wxss`.
public enum CYRadius {
    /// Legacy alias for the 8pt step (was shifted +1 tier prior to `ui/h-tokens-v1`).
    @available(*, deprecated, renamed: "sm")
    public static let xs: CGFloat = sm
    /// `8pt` small tags, code chips, compact thumbnails (`Theme.Radius.sm`, `--cy-radius-sm`).
    public static let sm: CGFloat = Theme.Radius.sm
    /// `12pt` buttons, text fields, list rows (`Theme.Radius.md`, `--cy-radius-md`).
    public static let md: CGFloat = Theme.Radius.md
    /// `16pt` standard content cards (`Theme.Radius.lg`, `--cy-radius-lg`).
    public static let lg: CGFloat = Theme.Radius.lg
    /// `20pt` featured topic/activity cards (`Theme.Radius.xl`, `--cy-radius-xl`).
    public static let xl: CGFloat = Theme.Radius.xl
    /// `22pt` hero banners & wallet summary cards (`Theme.Radius.xxl`, `--cy-radius-2xl`).
    public static let xxl: CGFloat = Theme.Radius.xxl
    /// `24pt` bottom sheets & modal dialogs.
    public static let sheet: CGFloat = 24
    /// Full capsule pills & primary CTAs (`Theme.Radius.pill`, `--cy-radius-pill`; prefer `Capsule()`).
    public static let pill: CGFloat = Theme.Radius.pill
}

// MARK: - DesignSystem Typealiases

public extension DesignSystem {
    typealias Colors = CYColor
    typealias Typography = CYTypography
    typealias Spacing = CYSpacing
    typealias Radius = CYRadius
}
