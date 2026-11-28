import SwiftUI

/// In-theme look tokens: native port of mini-program `pages/play/look-tokens.wxss` (`--lk-*`) and
/// `pages/play/utils/look-colors.js`. Four looks × five palettes, values copied 1:1.
/// Only applies inside a theme (play / story / chapter gate). Platform pages, the pass and the
/// settlement keep the regular CYNight palette (mini-program `.lk-plain`).
/// A topic with no look (or an unreadable one) renders `legacy`, exactly as before.
struct CYThemeLook: Equatable, Hashable {
    enum Style: String, CaseIterable { case stardust = "STARDUST", paper = "PAPER", survival = "SURVIVAL", cyber = "CYBER" }
    enum Palette: String, CaseIterable { case black = "DEFAULT", blue = "BLUE", red = "RED", yellow = "YELLOW", white = "WHITE" }
    /// Cyber only (`params.neon`). Explicit non-default palettes still win, as in the wxss order.
    enum Neon: String { case yellowCyan = "YELLOW_CYAN", cyanPink = "CYAN_PINK", redCyan = "RED_CYAN" }

    var style: Style
    var palette: Palette = .black
    var neon: Neon = .yellowCyan
    /// SURVIVAL `params.climate` / `params.volatility` (fix/1128c-ai-weather): the story weather timeline
    /// (`StoryClimate`) drawn by `PlaySceneWeather`. Nil for the other styles.
    var climate: String? = nil
    var volatility: String? = nil

    /// Mirrors `theme-look.normalizeLook`: unknown style → nil (legacy), unknown palette/neon → default.
    init?(style raw: String?, palette: String? = nil, neon: String? = nil, climate: String? = nil, volatility: String? = nil) {
        guard let raw, let style = Style(rawValue: raw.uppercased()) else { return nil }
        self.style = style
        self.palette = palette.flatMap { Palette(rawValue: $0.uppercased()) } ?? .black
        self.neon = neon.flatMap { Neon(rawValue: $0.uppercased()) } ?? .yellowCyan
        if style == .survival { self.climate = climate; self.volatility = volatility }
    }

    /// The author's story weather, or nil when this look has none.
    var storyClimate: StoryClimate? {
        StoryClimate(style: style.rawValue, climate: climate, volatility: volatility)
    }
    init(style: Style, palette: Palette = .black, neon: Neon = .yellowCyan) {
        self.style = style; self.palette = palette; self.neon = neon
    }

    /// Mini-program 外观目录 label, e.g. 星尘 · 黑.
    var styleTitleKey: LocalizedStringKey { LocalizedStringKey("mpd.look.style." + style.rawValue.lowercased()) }
    var paletteTitleKey: LocalizedStringKey { LocalizedStringKey("mpd.look.palette." + palette.rawValue.lowercased()) }

    var colors: CYThemeLookColors {
        var base = Self.table(style, palette)
        if style == .cyber, palette == .black {
            switch neon {
            case .cyanPink: base.a = CYRGB(hex: 0x2DE2E6); base.b = CYRGB(hex: 0xFF3B6B)
            case .redCyan: base.a = CYRGB(hex: 0xFF2E4C); base.b = CYRGB(hex: 0x2DE2E6)
            case .yellowCyan: break
            }
        }
        return base
    }
    /// Old topics (no look): chapter-flip prototype dark with the original gold.
    static let legacyColors = CYThemeLookColors(bg: 0x1F1F21, ink: 0xF5F5F2, mute: 0x9AA0AA, a: 0xF1C94B, b: 0x9AA0AA,
                                                card: 0x2A2A2C, pop: 0x343436, ctl: 0x3B3B3D, dim: 0xB1B1B0)

    /// `--lk-r` (rpx / 2) and `--lk-rb` for buttons and chips.
    var cardRadius: CGFloat {
        switch style { case .stardust: return 18; case .paper: return 3; case .survival: return 2; case .cyber: return 0 }
    }
    var buttonRadius: CGFloat { style == .stardust ? CYRadius.pill : cardRadius }
    /// `--lk-fd` / `--lk-fw` / `--lk-ls`: serif for stardust and paper, system for survival and cyber.
    var titleDesign: Font.Design { style == .stardust || style == .paper ? .serif : .default }
    var titleWeight: Font.Weight {
        switch style { case .stardust: return .semibold; case .paper: return .black; case .survival: return .bold; case .cyber: return .heavy }
    }
    var titleTracking: CGFloat {
        switch style { case .stardust: return 0.5; case .paper: return 0.3; case .survival: return 2; case .cyber: return 1.3 }
    }
    /// Survival and cyber set their buttons in the mono family (`--lk-fm`).
    var buttonDesign: Font.Design {
        switch style { case .paper: return .serif; case .survival, .cyber: return .monospaced; case .stardust: return .default }
    }
    /// Light palettes (white everywhere, paper yellow) flip system controls to light.
    var colorScheme: ColorScheme { colors.bg.relativeLuminance > 0.5 ? .light : .dark }
    /// Stardust is the only look with glass cards (l-icons 2026-11-11).
    var usesGlass: Bool { style == .stardust }

    private static func table(_ style: Style, _ palette: Palette) -> CYThemeLookColors {
        switch (style, palette) {
        case (.stardust, .black): return .init(bg: 0x0A0A0A, ink: 0xF2F2F0, mute: 0x9AA0AA, a: 0xE9E2D0, b: 0x9AA0AA, card: 0x1D1D1C, pop: 0x2A2A2A, ctl: 0x343433, dim: 0xB1B1B0)
        case (.stardust, .blue): return .init(bg: 0x0E1A33, ink: 0xF5F8FF, mute: 0xA9BBE0, a: 0xCFE0FF, b: 0xA9BBE0, card: 0x202C43, pop: 0x2E3950, ctl: 0x384258, dim: 0xB4BAC6)
        case (.stardust, .red): return .init(bg: 0x2A0E12, ink: 0xFFF4F5, mute: 0xE0AAB1, a: 0xFFB8AC, b: 0xE0AAB1, card: 0x3B2024, pop: 0x482E32, ctl: 0x50373B, dim: 0xC3B4B5)
        case (.stardust, .yellow): return .init(bg: 0x2A2208, ink: 0xFFFBEF, mute: 0xDFCD9A, a: 0xF2D58A, b: 0xDFCD9A, card: 0x3B331A, pop: 0x484028, ctl: 0x504932, dim: 0xC3BEAE)
        case (.stardust, .white): return .init(bg: 0xF5F6F8, ink: 0x111318, mute: 0x5B6270, a: 0x111318, b: 0x5B6270, card: 0xE3E4E6, pop: 0xD5D6D9, ctl: 0xCCCDD0, dim: 0x515357)
        case (.paper, .black): return .init(bg: 0x1D1B18, ink: 0xECE6D8, mute: 0x9A927F, a: 0xD0503C, b: 0x9A927F, card: 0x2E2B27, pop: 0x3A3733, ctl: 0x42403B, dim: 0xB2ADA2)
        case (.paper, .blue): return .init(bg: 0x1C2A44, ink: 0xEEF0EA, mute: 0xA2ADBF, a: 0xE8C66A, b: 0xA2ADBF, card: 0x2D3A51, pop: 0x39465B, ctl: 0x424E62, dim: 0xB3B9BC)
        case (.paper, .red): return .init(bg: 0x3A1A17, ink: 0xF4E6DC, mute: 0xC9A596, a: 0xE8C66A, b: 0xC9A596, card: 0x492A27, pop: 0x543733, ctl: 0x5B3F3A, dim: 0xC0ADA5)
        case (.paper, .yellow): return .init(bg: 0xE6DCC4, ink: 0x2B241A, mute: 0x7D715C, a: 0xA3281D, b: 0x7D715C, card: 0xD7CDB6, pop: 0xCCC2AC, ctl: 0xC4BBA5, dim: 0x5F584A)
        case (.paper, .white): return .init(bg: 0xF4F1EA, ink: 0x1E1C19, mute: 0x7A756C, a: 0xB0302A, b: 0x7A756C, card: 0xE3E0D9, pop: 0xD6D3CD, ctl: 0xCDCBC4, dim: 0x5A5854)
        case (.survival, .black): return .init(bg: 0x0E1012, ink: 0xE4E7E9, mute: 0x8A9196, a: 0xFF8A3D, b: 0x8A9196, card: 0x1F2123, pop: 0x2C2E30, ctl: 0x353739, dim: 0xA8ABAD)
        case (.survival, .blue): return .init(bg: 0x0B1626, ink: 0xEAF3FB, mute: 0x8FA6BD, a: 0xFFB35C, b: 0x8FA6BD, card: 0x1D2837, pop: 0x2A3544, ctl: 0x333E4C, dim: 0xACB5BF)
        case (.survival, .red): return .init(bg: 0x1C0A0A, ink: 0xF3E3E0, mute: 0xB08A86, a: 0x7FE6C4, b: 0xB08A86, card: 0x2D1B1B, pop: 0x3A2828, ctl: 0x433131, dim: 0xB7A6A4)
        case (.survival, .yellow): return .init(bg: 0x2A1D0C, ink: 0xFFF2DC, mute: 0xCDB38A, a: 0x8FD3FF, b: 0xCDB38A, card: 0x3B2E1D, pop: 0x483B29, ctl: 0x504331, dim: 0xC3B6A2)
        case (.survival, .white): return .init(bg: 0xE3E9EE, ink: 0x14202B, mute: 0x5D6D7B, a: 0xD4561E, b: 0x5D6D7B, card: 0xD2D9DE, pop: 0xC6CDD3, ctl: 0xBEC5CB, dim: 0x4E5862)
        case (.cyber, .black): return .init(bg: 0x0B0B0F, ink: 0xECEBE4, mute: 0x8A8C96, a: 0xF3E600, b: 0x24E0E8, card: 0x1D1D20, pop: 0x2B2A2D, ctl: 0x343335, dim: 0xADACA8)
        case (.cyber, .blue): return .init(bg: 0x06101C, ink: 0xE2F1FF, mute: 0x7E93AC, a: 0x2DE2E6, b: 0xFF3B6B, card: 0x18222E, pop: 0x25303C, ctl: 0x2E3945, dim: 0xA4B2BF)
        case (.cyber, .red): return .init(bg: 0x12060A, ink: 0xFFE8EA, mute: 0xA88088, a: 0xFF2E4C, b: 0x2DE2E6, card: 0x25181C, pop: 0x332629, ctl: 0x3D2F32, dim: 0xBDA9AB)
        case (.cyber, .yellow): return .init(bg: 0x100E04, ink: 0xFFF6CC, mute: 0xA99E6E, a: 0xFCEE0A, b: 0xFF2E4C, card: 0x232114, pop: 0x312E20, ctl: 0x3B3828, dim: 0xBCB594)
        case (.cyber, .white): return .init(bg: 0xE6E7EA, ink: 0x101216, mute: 0x5E636E, a: 0xE0002B, b: 0x008C99, card: 0xD5D6D9, pop: 0xC8C9CC, ctl: 0xBFC1C4, dim: 0x4C4E51)
        }
    }
}

/// `--lk-bg / ink / mute / a / b / card / pop / ctl / dim`. `ok` is shared (`--lk-ok`).
struct CYThemeLookColors: Equatable {
    var bg: CYRGB, ink: CYRGB, mute: CYRGB, a: CYRGB, b: CYRGB, card: CYRGB, pop: CYRGB, ctl: CYRGB, dim: CYRGB
    init(bg: UInt32, ink: UInt32, mute: UInt32, a: UInt32, b: UInt32, card: UInt32, pop: UInt32, ctl: UInt32, dim: UInt32) {
        self.bg = CYRGB(hex: bg); self.ink = CYRGB(hex: ink); self.mute = CYRGB(hex: mute); self.a = CYRGB(hex: a)
        self.b = CYRGB(hex: b); self.card = CYRGB(hex: card); self.pop = CYRGB(hex: pop); self.ctl = CYRGB(hex: ctl); self.dim = CYRGB(hex: dim)
    }
    static let ok = CYRGB(hex: 0x22C55E)
}

private struct CYThemeLookKey: EnvironmentKey { static let defaultValue: CYThemeLook? = nil }
extension EnvironmentValues {
    /// Nil outside a theme or for a topic without a look.
    var cyThemeLook: CYThemeLook? {
        get { self[CYThemeLookKey.self] }
        set { self[CYThemeLookKey.self] = newValue }
    }
}

extension View {
    /// Scopes a theme look to this subtree (mini-program `.play.look--<style>.look-palette--<palette>`).
    /// Nil keeps the regular CYNight palette.
    func cyThemeLook(_ look: CYThemeLook?) -> some View {
        modifier(CYThemeLookScope(look: look))
    }
    /// `.lk-card` / `.lk-pop`: card face, hairline ink border, look corner radius; stardust gets glass.
    func cyLookCard(pop: Bool = false, padding: CGFloat = CYSpacing.lg) -> some View {
        modifier(CYLookCardModifier(pop: pop, padding: padding))
    }
    /// `.lk-title`: look display family, weight and tracking; cyber titles take the accent with a glow.
    func cyLookTitle() -> some View { modifier(CYLookTitleModifier()) }
}

private struct CYThemeLookScope: ViewModifier {
    let look: CYThemeLook?
    func body(content: Content) -> some View {
        if let look {
            content
                .environment(\.cyThemeLook, look)
                .foregroundStyle(look.colors.ink.swiftUIColor)
                .tint(look.colors.a.swiftUIColor)
                .environment(\.colorScheme, look.colorScheme)
        } else {
            content
        }
    }
}

private struct CYLookCardModifier: ViewModifier {
    let pop: Bool
    let padding: CGFloat
    @Environment(\.cyThemeLook) private var look
    func body(content: Content) -> some View {
        if let look {
            let colors = look.colors
            let shape = RoundedRectangle(cornerRadius: look.cardRadius, style: .continuous)
            content
                .padding(padding)
                .foregroundStyle(colors.ink.swiftUIColor)
                // Native r2: no glass, gradient or shadow; the look's own card colour (creator theme content).
                .background((pop ? colors.pop : colors.card).swiftUIColor, in: shape)
        } else {
            content.cyCardSurface(padding: padding)
        }
    }
}

private struct CYLookTitleModifier: ViewModifier {
    @Environment(\.cyThemeLook) private var look
    func body(content: Content) -> some View {
        if let look {
            content
                .fontDesign(look.titleDesign)
                .fontWeight(look.titleWeight)
                .tracking(look.titleTracking)
                .foregroundStyle((look.style == .cyber ? look.colors.a : look.colors.ink).swiftUIColor)
                .shadow(color: look.style == .cyber ? look.colors.a.swiftUIColor.opacity(0.4) : .clear, radius: 9)
        } else {
            content
        }
    }
}

/// `.lk-btn--primary / --accent / --ghost / --text`. Falls back to CYNight capsule colours outside a look.
struct CYLookButtonStyle: ButtonStyle {
    enum Kind { case primary, accent, ghost, text }
    var kind: Kind = .primary
    @Environment(\.cyThemeLook) private var look
    @Environment(\.isEnabled) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        let colors = look?.colors ?? CYThemeLook.legacyColors
        let radius = look?.buttonRadius ?? CYRadius.pill
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let primaryFill = look?.style == .cyber ? colors.a : colors.ink
        let fill: Color = switch kind {
        case .primary: primaryFill.swiftUIColor
        case .accent: colors.a.swiftUIColor
        case .ghost: colors.ink.swiftUIColor.opacity(0.07)
        case .text: .clear
        }
        let text: Color = switch kind {
        case .primary, .accent: colors.bg.swiftUIColor
        case .ghost: colors.ink.swiftUIColor
        case .text: colors.mute.swiftUIColor
        }
        configuration.label
            .cyText(.label)
            .fontDesign(look?.buttonDesign ?? .default)
            .tracking(look?.style == .survival || look?.style == .cyber ? 1.6 : 0)
            .foregroundStyle(text)
            .frame(maxWidth: .infinity, minHeight: 50)
            .padding(.horizontal, CYSpacing.xl)
            .background(fill, in: shape)
            .overlay(shape.strokeBorder(kind == .ghost ? colors.ink.swiftUIColor.opacity(0.2) : .clear, lineWidth: 0.5))
            .opacity(enabled ? 1 : 0.5)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.97 : 1)
            .animation(CYMotion.resolve(configuration.isPressed ? CYMotion.press : CYMotion.release, reduceMotion: reduceMotion), value: configuration.isPressed)
            .contentShape(shape)
    }
}
