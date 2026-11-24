import SwiftUI

enum CYPillStyle { case primary, secondary, tertiary }

/// Pill height (design hand-off r1, full-player §2): 44 on pages and sheets, 52 on full-screen moments
/// (level-up, lobby start, play, result screens).
enum CYPillSize { case regular, moment }

/// The player kit button (`Player/Button`, design hand-off r1 §2 and PL-10/PL-12), drawn by the system since the
/// native restyle (native-ios-r1 §3.6): primary = `.borderedProminent` in the monochrome accent (white pill with a black
/// label on the player stage; black pill on merchant light); secondary = `.bordered`; tertiary = `.borderless`.
/// One primary per screen (owner rule).
struct CYPillButton: View {
    private let title: LocalizedStringKey
    private let tableName: String?
    private let verbatimTitle: String?
    private let style: CYPillStyle
    private let systemImage: String?
    private let fullWidth: Bool
    private let compact: Bool
    private let size: CYPillSize
    private let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        style: CYPillStyle = .primary,
        systemImage: String? = nil,
        fullWidth: Bool = true,
        compact: Bool = false,
        size: CYPillSize = .regular,
        tableName: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.tableName = tableName
        self.verbatimTitle = nil
        self.style = style
        self.systemImage = systemImage
        self.fullWidth = fullWidth
        self.compact = compact
        self.size = size
        self.action = action
    }

    /// Already-resolved copy (another string table, or a server string). Not looked up again.
    init(
        verbatim title: String,
        style: CYPillStyle = .primary,
        systemImage: String? = nil,
        fullWidth: Bool = true,
        compact: Bool = false,
        size: CYPillSize = .regular,
        action: @escaping () -> Void
    ) {
        self.title = ""
        self.tableName = nil
        self.verbatimTitle = title
        self.style = style
        self.systemImage = systemImage
        self.fullWidth = fullWidth
        self.compact = compact
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                if let verbatimTitle {
                    Text(verbatim: verbatimTitle)
                } else {
                    Text(title, tableName: tableName)
                }
            }
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .modifier(CYNativeButtonChrome(style: style, size: compact ? .regular : size))
    }
}

/// Native restyle (native-ios-r1 §3.6): the pill is the system button.
/// primary → `.borderedProminent`, secondary → `.bordered`, tertiary → `.borderless`, all `.large` + capsule.
/// The monochrome accent (near-white on the player stage, black on merchant light) is the tint, and the label colour
/// is set explicitly so a near-white fill never carries a white label (spec §2.2 gotcha). The system draws the
/// press and disabled states, so there is no second press animation.
struct CYNativeButtonChrome: ViewModifier {
    let style: CYPillStyle
    var size: CYPillSize = .regular

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled

    func body(content: Content) -> some View {
        let tokens = CYPillButtonStyle.tokens(style: style, isEnabled: isEnabled, in: palette)
        styled(content)
            .foregroundStyle(tokens.foreground)
            .controlSize(size == .moment ? .extraLarge : .large)
            .buttonBorderShape(.capsule)
            .frame(minHeight: CYSpacing.minTouchTarget)
    }

    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        switch style {
        case .primary:
            content.buttonStyle(.borderedProminent).tint(palette.actionPrimaryBg)
        case .secondary:
            content.buttonStyle(.bordered).tint(palette.textPrimary)
        case .tertiary:
            content.buttonStyle(.borderless).tint(palette.textSecondary)
        }
    }
}

struct CYPillButtonStyle: ButtonStyle {
    var style: CYPillStyle = .primary
    var fullWidth: Bool = true
    /// 44pt inline variant for card footers (still the minimum touch target).
    var compact: Bool = false
    /// 44 on pages and sheets, 52 on full-screen moments.
    var size: CYPillSize = .regular

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.cyPillOnSheet) private var onSheet
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1
    @ScaledMetric(relativeTo: .body) private var momentHeight: CGFloat = 52

    /// 44 pt (46 on merchant), scaled with Dynamic Type.
    private var height: CGFloat { palette.buttonMinHeight * scale }

    func makeBody(configuration: Configuration) -> some View {
        let shape: AnyShape = palette.buttonCornerRadius.map { AnyShape(RoundedRectangle(cornerRadius: $0, style: .continuous)) }
            ?? AnyShape(Capsule(style: .continuous))
        configuration.label
            .font(style == .tertiary ? Self.tertiaryFont : Self.labelFont)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? CYSpacing.xl : CYSpacing.xxl)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: size == .moment && !compact ? momentHeight : height)
            .background(shape.fill(fill))
            .contentShape(shape)
            // System button press: a highlight, no second (scale) animation (native-ios-r1 §1.1).
            .opacity(configuration.isPressed && isEnabled ? 0.7 : 1)
    }

    /// The system button label (`.headline`, native-ios-r1 §2.1 `button`); follows Dynamic Type.
    static let labelFont: Font = .headline
    /// Tertiary text button, 15 pt (`.subheadline`, Dynamic Type).
    static let tertiaryFont: Font = .system(.subheadline, design: .default)

    static func tokens(style: CYPillStyle, isEnabled: Bool, in palette: CYDomainPalette, onSheet: Bool = false) -> (foreground: Color, fill: Color) {
        let fg: Color
        if !isEnabled {
            fg = palette.textPlaceholder
        } else {
            switch style {
            case .primary: fg = palette.actionPrimaryFg
            // Player: white label on a dark pill. Merchant light keeps a dark label on its light grey pill.
            case .secondary: fg = palette.textPrimary
            case .tertiary: fg = palette.isDarkDomain ? palette.textPrimary.opacity(0.7) : palette.textSecondary
            }
        }
        let bg: Color
        switch style {
        case .primary: bg = isEnabled ? palette.actionPrimaryBg : palette.bgSurfaceSubtle
        case .secondary:
            if !isEnabled {
                bg = palette.bgSurfaceSubtle
            } else if palette.isDarkDomain {
                // `#1C1C1E` disappears on a `#1C1C1E`/glass sheet, so on a sheet the secondary pill steps up to surface-3.
                bg = onSheet ? palette.bgStrong : palette.bgElevated
            } else {
                bg = palette.actionSecondaryBg
            }
        case .tertiary: bg = .clear
        }
        return (foreground: fg, fill: bg)
    }

    private var foreground: Color { Self.tokens(style: style, isEnabled: isEnabled, in: palette, onSheet: onSheet).foreground }
    private var fill: Color { Self.tokens(style: style, isEnabled: isEnabled, in: palette, onSheet: onSheet).fill }
}

private struct CYPillOnSheetKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// True inside `CYResizableSheet`/`CYSheetContainer` content, so the player secondary pill stays visible on the sheet fill.
    var cyPillOnSheet: Bool {
        get { self[CYPillOnSheetKey.self] }
        set { self[CYPillOnSheetKey.self] = newValue }
    }
}

private struct CYPillButtonPreviewBody: View {
    var body: some View {
        VStack(spacing: CYSpacing.md) {
            CYPillButton("Continue", action: {})
            CYPillButton("Continue with phone", style: .secondary, systemImage: "phone", action: {})
            CYPillButton("Skip for now", style: .tertiary, action: {})
            CYPillButton("Disabled", action: {}).disabled(true)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxHeight: .infinity, alignment: .top)
        .cyDomainPageBackground()
    }
}
#Preview("Pill · player dark") { CYPillButtonPreviewBody().themeDomain(.player) }
#Preview("Pill · merchant light") { CYPillButtonPreviewBody().themeDomain(.merchant) }
