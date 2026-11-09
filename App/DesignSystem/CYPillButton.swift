import SwiftUI

enum CYPillStyle { case primary, secondary, tertiary }

/// 56pt capsule button. Primary = solid, secondary = outlined, tertiary = text only.
/// One primary per screen (owner rule). Disabled state keeps full contrast via palette, no opacity drop.
struct CYPillButton: View {
    private let title: Text
    private let style: CYPillStyle
    private let systemImage: String?
    private let fullWidth: Bool
    private let action: () -> Void

    init(
        _ title: LocalizedStringKey,
        style: CYPillStyle = .primary,
        systemImage: String? = nil,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = Text(title)
        self.style = style
        self.systemImage = systemImage
        self.fullWidth = fullWidth
        self.action = action
    }

    /// Already-resolved copy (another string table, or a server string). Not looked up again.
    init(
        verbatim title: String,
        style: CYPillStyle = .primary,
        systemImage: String? = nil,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.title = Text(verbatim: title)
        self.style = style
        self.systemImage = systemImage
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: CYSpacing.sm) {
                if let systemImage { Image(systemName: systemImage) }
                title
            }
        }
        .buttonStyle(CYPillButtonStyle(style: style, fullWidth: fullWidth))
    }
}

struct CYPillButtonStyle: ButtonStyle {
    var style: CYPillStyle = .primary
    var fullWidth: Bool = true

    @Environment(\.cyPalette) private var palette
    @Environment(\.isEnabled) private var isEnabled
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 56

    func makeBody(configuration: Configuration) -> some View {
        let shape = Capsule(style: .continuous)
        configuration.label
            .font(.system(.body).weight(.bold))
            .foregroundStyle(foreground)
            .padding(.horizontal, CYSpacing.xxl)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: height)
            .background(shape.fill(fill))
            .overlay(shape.strokeBorder(style == .secondary ? stroke : .clear, lineWidth: 1.5))
            .contentShape(shape)
            .opacity(configuration.isPressed ? 0.8 : 1)
    }

    private var foreground: Color {
        guard isEnabled else { return palette.textPlaceholder }
        switch style {
        case .primary: return palette.actionPrimaryFg
        case .secondary, .tertiary: return palette.textPrimary
        }
    }
    private var fill: Color {
        switch style {
        case .primary: return isEnabled ? palette.actionPrimaryBg : palette.bgSurfaceSubtle
        case .secondary, .tertiary: return .clear
        }
    }
    private var stroke: Color { isEnabled ? palette.borderStrong : palette.borderSubtle }
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
