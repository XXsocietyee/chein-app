import SwiftUI

enum CYPillStyle { case primary, secondary, tertiary }

/// 56pt capsule button. Primary = solid, secondary = filled grey with no outline, tertiary = text only.
/// One primary per screen (owner rule). Disabled state keeps full contrast via palette, no opacity drop.
struct CYPillButton: View {
    private let title: LocalizedStringKey
    private let tableName: String?
    private let verbatimTitle: String?
    private let style: CYPillStyle
    private let systemImage: String?
    private let fullWidth: Bool
    private let compact: Bool
    private let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        style: CYPillStyle = .primary,
        systemImage: String? = nil,
        fullWidth: Bool = true,
        compact: Bool = false,
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
        self.action = action
    }

    /// Already-resolved copy (another string table, or a server string). Not looked up again.
    init(
        verbatim title: String,
        style: CYPillStyle = .primary,
        systemImage: String? = nil,
        fullWidth: Bool = true,
        compact: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = ""
        self.tableName = nil
        self.verbatimTitle = title
        self.style = style
        self.systemImage = systemImage
        self.fullWidth = fullWidth
        self.compact = compact
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
        }
        .buttonStyle(CYPillButtonStyle(style: style, fullWidth: fullWidth, compact: compact))
    }
}

struct CYPillButtonStyle: ButtonStyle {
    var style: CYPillStyle = .primary
    var fullWidth: Bool = true
    /// 44pt inline variant for card footers (still the minimum touch target).
    var compact: Bool = false

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @QuestifyReduceMotion private var reduceMotion
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 56
    @ScaledMetric(relativeTo: .body) private var compactHeight: CGFloat = 44

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule(style: .continuous)
        configuration.label
            .font(CYTypography.button)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .foregroundStyle(foreground)
            .padding(.horizontal, compact ? CYSpacing.xl : CYSpacing.xxl)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: compact ? compactHeight : height)
            .background(shape.fill(fill))
            .contentShape(shape)
            .cyPressEffect(configuration.isPressed && isEnabled, reduceMotion: reduceMotion)
    }

    static func tokens(style: CYPillStyle, isEnabled: Bool, in palette: CYDomainPalette) -> (foreground: Color, fill: Color) {
        let fg: Color
        if !isEnabled {
            fg = palette.textPlaceholder
        } else {
            switch style {
            case .primary: fg = palette.actionPrimaryFg
            case .secondary: fg = palette.textSecondary
            case .tertiary: fg = palette.textPrimary
            }
        }
        let bg: Color
        switch style {
        case .primary: bg = isEnabled ? palette.actionPrimaryBg : palette.bgSurfaceSubtle
        case .secondary: bg = isEnabled ? palette.actionSecondaryBg : palette.bgSurfaceSubtle
        case .tertiary: bg = .clear
        }
        return (foreground: fg, fill: bg)
    }

    private var foreground: Color { Self.tokens(style: style, isEnabled: isEnabled, in: palette).foreground }
    private var fill: Color { Self.tokens(style: style, isEnabled: isEnabled, in: palette).fill }
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
