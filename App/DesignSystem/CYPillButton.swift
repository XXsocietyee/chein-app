import SwiftUI

enum CYPillStyle { case primary, secondary, tertiary }

/// Kept for call-site compatibility. Since native r2 both sizes render as the system `.large` control.
enum CYPillSize { case regular, moment }

/// Native r2 (owner, 2026-11-26: "identical to Apple's official ones"): the system button, nothing drawn by us.
/// primary → `.borderedProminent`, secondary → `.bordered`, tertiary → `.borderless`; `.controlSize(.large)`,
/// system tint (accent), system label colour, height and shape. One prominent button per screen.
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
            labelView
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .modifier(CYNativeButtonChrome(style: style, size: size))
    }

    @ViewBuilder
    private var labelView: some View {
        if let systemImage {
            Label {
                titleText
            } icon: {
                Image(systemName: systemImage)
            }
        } else {
            titleText
        }
    }

    @ViewBuilder
    private var titleText: some View {
        if let verbatimTitle {
            Text(verbatim: verbatimTitle)
        } else {
            Text(title, tableName: tableName)
        }
    }
}

/// Native r2: the system button style only. No tint, foreground, shape or height of our own;
/// the system draws press, disabled, Dynamic Type and Light/Dark.
struct CYNativeButtonChrome: ViewModifier {
    let style: CYPillStyle
    var size: CYPillSize = .regular

    func body(content: Content) -> some View {
        styled(content)
            .controlSize(.large)
    }

    @ViewBuilder
    private func styled(_ content: Content) -> some View {
        switch style {
        case .primary:
            content.buttonStyle(.borderedProminent)
        case .secondary:
            content.buttonStyle(.bordered)
        case .tertiary:
            content.buttonStyle(.borderless)
        }
    }
}

/// `.buttonStyle(CYPillButtonStyle(...))` call sites (also used through `AnyButtonStyle` and the
/// `ButtonStyle where Self == CYPillButtonStyle` statics, so it stays a `ButtonStyle`). The label is hosted in a
/// real system button of the matching style (`.borderedProminent` / `.bordered` / `.borderless`, `.large`,
/// role kept) so the system draws fill, shape, tint, label colour and the disabled state. The host button
/// takes the tap; the system press dim is mirrored from `isPressed`.
struct CYPillButtonStyle: ButtonStyle {
    var style: CYPillStyle = .primary
    var fullWidth: Bool = true
    /// Kept for call-site compatibility; the system `.large` control already meets the touch target.
    var compact: Bool = false
    /// Kept for call-site compatibility.
    var size: CYPillSize = .regular

    func makeBody(configuration: Configuration) -> some View {
        Button(role: configuration.role, action: {}) {
            configuration.label
                .frame(maxWidth: fullWidth ? .infinity : nil)
        }
        .modifier(CYNativeButtonChrome(style: style, size: size))
        .allowsHitTesting(false)
        .opacity(configuration.isPressed ? 0.75 : 1)
    }

    /// The system button label style (`.headline`); follows Dynamic Type.
    static let labelFont: Font = .headline
    /// Tertiary text button (`.subheadline`, Dynamic Type).
    static let tertiaryFont: Font = .subheadline

    /// Token readback kept for existing token tests and the few non-button callers. The rendered buttons above
    /// no longer read it: the system draws their colours.
    static func tokens(style: CYPillStyle, isEnabled: Bool, in palette: CYDomainPalette, onSheet: Bool = false) -> (foreground: Color, fill: Color) {
        let fg: Color
        if !isEnabled {
            fg = palette.textPlaceholder
        } else {
            switch style {
            case .primary: fg = palette.actionPrimaryFg
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
                bg = onSheet ? palette.bgStrong : palette.bgElevated
            } else {
                bg = palette.actionSecondaryBg
            }
        case .tertiary: bg = .clear
        }
        return (foreground: fg, fill: bg)
    }
}

private struct CYPillOnSheetKey: EnvironmentKey { static let defaultValue = false }

extension EnvironmentValues {
    /// Kept for call-site compatibility (set by sheet containers); the system button no longer needs it.
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
        .padding()
        .frame(maxHeight: .infinity, alignment: .top)
    }
}
#Preview("Pill") { CYPillButtonPreviewBody() }
