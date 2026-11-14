import SwiftUI

// MARK: - 1. Card Surface & Container (CYCard)

public enum CYCardVariant: Sendable {
    /// Standard card surface (`CYColor.bgSurface`, subtle border).
    case surface
    /// Elevated card surface (`CYColor.bgElevated`, soft drop shadow in light mode, hairline border in dark mode).
    case elevated
    /// Subtle inset group surface (`CYColor.bgSurfaceSubtle`, no shadow).
    case subtle
    /// Highlighted brand tint surface (`CYColor.brandSoft`, no border).
    case accentTint
}

public struct CYCardSurfaceModifier: ViewModifier {
    public let variant: CYCardVariant
    public let radius: CGFloat
    public let padding: CGFloat

    @Environment(\.colorScheme) private var colorScheme

    public init(
        variant: CYCardVariant = .surface,
        radius: CGFloat = CYRadius.lg,
        padding: CGFloat = CYSpacing.lg
    ) {
        self.variant = variant
        self.radius = radius
        self.padding = padding
    }

    private var backgroundColor: Color {
        switch variant {
        case .surface: return CYColor.bgSurface
        case .elevated: return CYColor.bgElevated
        case .subtle: return CYColor.bgSurfaceSubtle
        case .accentTint: return CYColor.brandSoft
        }
    }

    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .padding(padding)
            .background(shape.fill(backgroundColor))
            .shadow(
                color: (variant == .elevated && colorScheme == .light)
                    ? Color.black.opacity(0.05)
                    : Color.clear,
                // A clear shadow still costs an offscreen blur pass; zero it unless it is drawn.
                radius: (variant == .elevated && colorScheme == .light) ? 10 : 0,
                x: 0,
                y: (variant == .elevated && colorScheme == .light) ? 4 : 0
            )
    }
}

public extension View {
    /// Applies the standard Chengyin card surface and continuous squircle radius (no outer stroke border).
    func cyCardSurface(
        variant: CYCardVariant = .surface,
        radius: CGFloat = CYRadius.lg,
        padding: CGFloat = CYSpacing.lg
    ) -> some View {
        modifier(CYCardSurfaceModifier(variant: variant, radius: radius, padding: padding))
    }
}

/// Reusable semantic card container.
public struct CYCard<Content: View>: View {
    private let variant: CYCardVariant
    private let radius: CGFloat
    private let padding: CGFloat
    private let content: Content

    public init(
        variant: CYCardVariant = .surface,
        radius: CGFloat = CYRadius.lg,
        padding: CGFloat = CYSpacing.lg,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.radius = radius
        self.padding = padding
        self.content = content()
    }

    public var body: some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .cyCardSurface(variant: variant, radius: radius, padding: padding)
    }
}

// MARK: - 2. Section Header (CYSectionHeader)

/// Standard section header with title, optional subtitle/eyebrow, and optional trailing action button.
public struct CYSectionHeader: View {
    private let title: LocalizedStringKey
    private let subtitle: LocalizedStringKey?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(title)
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .accessibilityAddTraits(.isHeader)

                if let subtitle {
                    Text(subtitle)
                        .font(CYTypography.meta)
                        .foregroundStyle(CYColor.textTertiary)
                }
            }

            Spacer(minLength: CYSpacing.sm)

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: CYSpacing.xs) {
                        Text(actionTitle)
                            .font(CYTypography.label)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(CYColor.brand)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - 3. Primary, Secondary & Destructive Button Styles

/// Primary pill button style using domain neutral action fill (`>= 44pt` hit target, Reduce Motion aware).
public struct CYPrimaryButtonStyle: ButtonStyle {
    public var isFullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isFullWidth: Bool = true) {
        self.isFullWidth = isFullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.pill, style: .continuous)
        configuration.label
            .font(CYTypography.button)
            .foregroundStyle(isEnabled ? CYColor.actionPrimaryFg : CYColor.textDisabled)
            .padding(.horizontal, CYSpacing.xl)
            .padding(.vertical, CYSpacing.md)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: CYSpacing.minTouchTarget)
            .background(
                shape.fill(
                    !isEnabled
                        ? CYColor.bgRaised
                        : (configuration.isPressed ? CYColor.brandStrong : CYColor.actionPrimaryBg)
                )
            )
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Secondary button style with subtle surface fill and no outer border (`>= 44pt` hit target).
public struct CYSecondaryButtonStyle: ButtonStyle {
    public var isFullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isFullWidth: Bool = false) {
        self.isFullWidth = isFullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
        configuration.label
            .font(CYTypography.button)
            .foregroundStyle(isEnabled ? CYColor.textSecondary : CYColor.textDisabled)
            .padding(.horizontal, CYSpacing.lg)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: CYSpacing.minTouchTarget)
            .background(
                shape.fill(configuration.isPressed ? CYColor.bgSurfaceStrong : CYColor.actionSecondary)
            )
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

/// Destructive button style for irreversible actions (cancel, delete, block).
public struct CYDestructiveButtonStyle: ButtonStyle {
    public var isFullWidth: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(isFullWidth: Bool = false) {
        self.isFullWidth = isFullWidth
    }

    public func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous)
        configuration.label
            .font(CYTypography.button)
            .foregroundStyle(isEnabled ? CYColor.dangerText : CYColor.textDisabled)
            .padding(.horizontal, CYSpacing.lg)
            .padding(.vertical, CYSpacing.sm)
            .frame(maxWidth: isFullWidth ? .infinity : nil, minHeight: CYSpacing.minTouchTarget)
            .background(
                shape.fill(configuration.isPressed ? CYColor.dangerSoft.opacity(0.85) : CYColor.dangerSoft)
            )
            .contentShape(shape)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1.0)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: configuration.isPressed)
    }
}

public extension ButtonStyle where Self == CYPrimaryButtonStyle {
    static var cyPrimary: CYPrimaryButtonStyle { CYPrimaryButtonStyle() }
    static func cyPrimary(fullWidth: Bool) -> CYPrimaryButtonStyle {
        CYPrimaryButtonStyle(isFullWidth: fullWidth)
    }
}

public extension ButtonStyle where Self == CYSecondaryButtonStyle {
    static var cySecondary: CYSecondaryButtonStyle { CYSecondaryButtonStyle() }
    static func cySecondary(fullWidth: Bool) -> CYSecondaryButtonStyle {
        CYSecondaryButtonStyle(isFullWidth: fullWidth)
    }
}

public extension ButtonStyle where Self == CYDestructiveButtonStyle {
    static var cyDestructive: CYDestructiveButtonStyle { CYDestructiveButtonStyle() }
}

// MARK: - 4. Empty State (CYEmptyStateView)

/// System-first empty state built on `ContentUnavailableView` with at most one primary CTA.
public struct CYEmptyStateView: View {
    private let systemImage: String
    private let title: LocalizedStringKey
    private let description: LocalizedStringKey?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        systemImage: String = "tray",
        title: LocalizedStringKey,
        description: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.description = description
        self.actionTitle = actionTitle
        self.action = action
    }

    public var body: some View {
        CYStateLayout(
            kind: CYStateKind(symbol: systemImage),
            title: Text(title),
            detail: description.map { Text($0) },
            primary: actionTitle.flatMap { t in action.map { (title: t, action: $0) } },
            primaryStyle: .primary
        )
    }
}

// MARK: - 5. Error State with Retry (CYErrorStateView)

/// User-readable error state with retry action (never exposes raw HTTP codes or stack traces).
public struct CYErrorStateView: View {
    private let systemImage: String
    private let title: LocalizedStringKey
    private let message: LocalizedStringKey
    private let retryTitle: LocalizedStringKey
    private let onRetry: (() -> Void)?

    public init(
        systemImage: String = "exclamationmark.triangle",
        title: LocalizedStringKey = "暂时无法加载内容",
        message: LocalizedStringKey = "请检查网络连接后重试",
        retryTitle: LocalizedStringKey = "重试",
        onRetry: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.title = title
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    public var body: some View {
        CYStateLayout(
            kind: CYStateKind(symbol: systemImage) == .offline ? .offline : .failure,
            title: Text(title),
            detail: Text(message),
            primary: onRetry.map { (title: retryTitle, action: $0) },
            primaryStyle: .secondary
        )
    }
}

// MARK: - 6. Unread Badge (CYUnreadBadge)

public enum CYUnreadBadgeStyle: Sendable {
    /// High-priority mention / DM unread (`CYColor.dangerSolid` red capsule).
    case danger
    /// Neutral brand unread (`CYColor.brand` capsule).
    case accent
    /// Muted channel / silent notification (`CYColor.bgSurfaceStrong` neutral capsule).
    case muted
}

/// Reusable unread indicator supporting dot-only mode and numeric count (`1...99` / `99+`) for IM & Discord-style club channels.
public struct CYUnreadBadge: View {
    public let count: Int?
    public let isDotOnly: Bool
    public let style: CYUnreadBadgeStyle

    @ScaledMetric(relativeTo: .caption2) private var dotSize: CGFloat = 8
    @ScaledMetric(relativeTo: .caption2) private var badgeMinHeight: CGFloat = 18

    public init(
        count: Int? = nil,
        isDotOnly: Bool = false,
        style: CYUnreadBadgeStyle = .danger
    ) {
        self.count = count
        self.isDotOnly = isDotOnly
        self.style = style
    }

    public var isVisible: Bool {
        if isDotOnly {
            return (count ?? 1) > 0
        }
        return (count ?? 0) > 0
    }

    public static func formattedCount(_ value: Int) -> String {
        guard value > 0 else { return "" }
        return value > 99 ? "99+" : "\(value)"
    }

    private var fillColor: Color {
        switch style {
        case .danger: return CYColor.dangerSolid
        case .accent: return CYColor.brand
        case .muted: return CYColor.bgSurfaceStrong
        }
    }

    private var foregroundColor: Color {
        switch style {
        case .danger: return Color.white
        case .accent: return CYColor.textOnAccent
        case .muted: return CYColor.textSecondary
        }
    }

    public var body: some View {
        if isVisible {
            if isDotOnly {
                Circle()
                    .fill(fillColor)
                    .frame(width: dotSize, height: dotSize)
                    .accessibilityLabel(Text("有未读消息"))
            } else if let count, count > 0 {
                let text = Self.formattedCount(count)
                Text(verbatim: text)
                    .font(CYTypography.micro.monospacedDigit())
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, count > 9 ? CYSpacing.xs + CYSpacing.xxs : CYSpacing.xs)
                    .frame(minWidth: badgeMinHeight, minHeight: badgeMinHeight)
                    .background(Capsule(style: .continuous).fill(fillColor))
                    .accessibilityLabel(Text("\(text) 条未读消息"))
            }
        }
    }
}

// MARK: - 7. Avatar View (CYAvatarView)

public enum CYAvatarSize: CGFloat, Sendable {
    /// `24pt` inline chip / compact comment avatar.
    case xs = 24
    /// `32pt` message / channel row avatar.
    case sm = 32
    /// `40pt` standard list / club member avatar.
    case md = 40
    /// `56pt` profile card / merchant header avatar.
    case lg = 56
    /// `72pt` hero identity card avatar.
    case xl = 72
}

/// Semantic avatar component with HTTPS `AsyncImage`, monogram/symbol fallback, optional ring, and VoiceOver label.
public struct CYAvatarView: View {
    private let url: URL?
    private let name: String
    private let size: CYAvatarSize
    private let showAccentRing: Bool
    private let isOnline: Bool?

    @ScaledMetric(relativeTo: .body) private var scaleFactor: CGFloat = 1.0

    public init(
        url: URL? = nil,
        name: String,
        size: CYAvatarSize = .md,
        showAccentRing: Bool = false,
        isOnline: Bool? = nil
    ) {
        // Enforce HTTPS-only remote image loading
        if let url, url.scheme?.lowercased() == "https" {
            self.url = url
        } else {
            self.url = nil
        }
        self.name = name
        self.size = size
        self.showAccentRing = showAccentRing
        self.isOnline = isOnline
    }

    public static func monogram(for rawName: String) -> String {
        let trimmed = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else { return "旅" }
        return String(first).uppercased()
    }

    private var dimension: CGFloat {
        size.rawValue * min(max(scaleFactor, 0.85), 1.35)
    }

    private var monogramFont: Font {
        switch size {
        case .xs: return CYTypography.micro
        case .sm: return CYTypography.caption
        case .md: return CYTypography.label
        case .lg: return CYTypography.sectionTitle
        case .xl: return CYTypography.pageTitle
        }
    }

    public var body: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let url {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        default:
                            fallbackView
                        }
                    }
                } else {
                    fallbackView
                }
            }
            .frame(width: dimension, height: dimension)
            .clipShape(Circle())
            .overlay(
                Circle()
                    .strokeBorder(
                        showAccentRing ? CYColor.avatarRing : CYColor.borderSubtle,
                        lineWidth: showAccentRing ? 2 : 1
                    )
            )

            if let isOnline {
                Circle()
                    .fill(isOnline ? CYColor.successText : CYColor.textDisabled)
                    .frame(width: max(8, dimension * 0.24), height: max(8, dimension * 0.24))
                    .overlay(
                        Circle().strokeBorder(CYColor.bgSurface, lineWidth: 1.5)
                    )
                    .accessibilityHidden(true)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "用户头像" : "\(name)的头像"))
    }

    private var fallbackView: some View {
        ZStack {
            CYColor.brandSoft
            Text(verbatim: Self.monogram(for: name))
                .font(monogramFont)
                .foregroundStyle(CYColor.brand)
        }
    }
}
