import SwiftUI

// MARK: - 1. Card Surface & Container (CYCard)

public enum CYCardVariant: Sendable {
    /// Standard card surface (`CYColor.bgSurface`, radius 12, no border, no shadow).
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
        radius: CGFloat = CYRadius.card,
        padding: CGFloat = CYSpacing.lg
    ) {
        self.variant = variant
        self.radius = radius
        self.padding = padding
    }

    public static func backgroundColor(for variant: CYCardVariant) -> Color {
        switch variant {
        case .surface: return CYColor.bgSurface
        case .elevated: return CYColor.bgElevated
        case .subtle: return CYColor.bgSurfaceSubtle
        case .accentTint: return CYColor.brandSoft
        }
    }

    private var backgroundColor: Color {
        Self.backgroundColor(for: variant)
    }

    /// Native r2: the system grouped secondary background (the inset-grouped cell colour, Light/Dark aware) in the
    /// one card radius (`CYRadius.card`). No shadow, no tint, no border; `variant` and `radius` are kept for call
    /// sites only. Increase Contrast adds the system separator edge.
    public func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: CYRadius.card, style: .continuous)
        content
            .padding(padding)
            .background(Color(uiColor: .secondarySystemGroupedBackground), in: shape)
            .modifier(CYIncreaseContrastEdge(radius: CYRadius.card))
    }
}

public extension View {
    /// Applies the standard Chengyin card surface and continuous squircle radius (no outer stroke border).
    func cyCardSurface(
        variant: CYCardVariant = .surface,
        radius: CGFloat = CYRadius.card,
        padding: CGFloat = CYSpacing.lg
    ) -> some View {
        modifier(CYCardSurfaceModifier(variant: variant, radius: radius, padding: padding))
    }
}

/// A 1 pt separator edge drawn only when the user turns on Increase Contrast (native-ios-r1 §3.3).
struct CYIncreaseContrastEdge: ViewModifier {
    let radius: CGFloat
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content.overlay {
            if contrast == .increased {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator), lineWidth: 1)
                    .allowsHitTesting(false)
            }
        }
    }
}

public extension View {
    /// The one content-card surface (native restyle r1, spec §3.3): `bgSurface`, radius 12, 16 padding, no shadow.
    func cyCard(padding: CGFloat = CYSpacing.lg) -> some View {
        cyCardSurface(variant: .surface, radius: CYRadius.card, padding: padding)
    }

    /// A card placed as a `List` row (spec §3.3): no row background or separator, 6 pt vertical row insets.
    func cyCardRow() -> some View {
        listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
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
        radius: CGFloat = CYRadius.card,
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
    private let verbatimTitle: String?
    private let subtitle: LocalizedStringKey?
    private let verbatimSubtitle: String?
    private let actionTitle: LocalizedStringKey?
    private let action: (() -> Void)?

    public init(
        _ title: LocalizedStringKey,
        subtitle: LocalizedStringKey? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.verbatimTitle = nil
        self.subtitle = subtitle
        self.verbatimSubtitle = nil
        self.actionTitle = actionTitle
        self.action = action
    }

    public init(
        verbatim title: String,
        subtitle: String? = nil,
        actionTitle: LocalizedStringKey? = nil,
        action: (() -> Void)? = nil
    ) {
        self.title = ""
        self.verbatimTitle = title
        self.subtitle = nil
        self.verbatimSubtitle = subtitle
        self.actionTitle = actionTitle
        self.action = action
    }

    /// Native r2: plain section header text (`.headline`, `.isHeader`), a `.secondary` footnote subtitle, and a
    /// borderless trailing action ("See All" style). No custom colours or heights.
    public var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: CYSpacing.sm) {
                titles
                Spacer(minLength: CYSpacing.sm)
                actionButton
            }
            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                titles
                actionButton
            }
        }
    }

    private var titles: some View {
        VStack(alignment: .leading, spacing: 2) {
            Group {
                if let verbatimTitle {
                    Text(verbatim: verbatimTitle)
                } else {
                    Text(title)
                }
            }
            .font(.headline)
            .accessibilityAddTraits(.isHeader)

            if let verbatimSubtitle {
                Text(verbatim: verbatimSubtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else if let subtitle {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder private var actionButton: some View {
        if let actionTitle, let action {
            Button(action: action) {
                Text(actionTitle)
            }
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - 3. Primary, Secondary & Destructive Button Styles

/// Primary pill button style using domain neutral action fill (`>= 44pt` hit target, Reduce Motion aware).
public enum CYButtonSize: Sendable, Hashable {
    case md
    case sm
    case xs

    var visualHeight: CGFloat {
        switch self {
        case .md: return Theme.length("--cy-btn-h")
        case .sm: return Theme.length("--cy-btn-h-sm")
        case .xs: return Theme.length("--cy-btn-h-xs")
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .md: return CYSpacing.xl
        case .sm: return CYSpacing.lg
        case .xs: return CYSpacing.s2_5
        }
    }

    var font: Font {
        switch self {
        case .md: return CYTypography.button
        case .sm: return CYTypography.meta.weight(.semibold)
        case .xs: return CYTypography.caption.weight(.semibold)
        }
    }

    /// Native restyle (native-ios-r1 §3.6): every button is a capsule (`buttonBorderShape(.capsule)`), so `isPill`
    /// no longer changes the shape. Kept for call-site compatibility.
    func cornerRadius(isPill: Bool) -> CGFloat {
        CYRadius.pill
    }
}

public enum CYButtonVariant: Sendable, Hashable {
    case primary
    case secondary
    case ghost
    case danger
}

/// Native r2: the system `ProgressView` (spinner) in the given tint.
public struct CYButtonSpinner: View {
    public var tint: Color

    public init(tint: Color = CYColor.actionPrimaryFg) {
        self.tint = tint
    }

    public var body: some View {
        ProgressView()
            .accessibilityHidden(true)
    }
}

/// Native r2 host for the `CY*ButtonStyle` family (they must stay `ButtonStyle`s for call sites): the label sits in a
/// real system button of the matching style, so the system draws fill, shape, tint, label colour, size and the
/// disabled state. The outer (styled) button takes the tap; the system press dim is mirrored from `isPressed`.
struct CYSystemButtonHost: View {
    let configuration: ButtonStyleConfiguration
    let variant: CYButtonVariant
    let size: CYButtonSize
    let isFullWidth: Bool
    let isLoading: Bool

    var body: some View {
        styled(
            Button(role: variant == .danger ? .destructive : configuration.role, action: {}) {
                ZStack {
                    configuration.label
                        .opacity(isLoading ? 0 : 1)
                    if isLoading {
                        ProgressView()
                    }
                }
                .frame(maxWidth: isFullWidth ? .infinity : nil)
            }
        )
        .controlSize(controlSize)
        .allowsHitTesting(false)
        .opacity(configuration.isPressed && !isLoading ? 0.75 : 1)
    }

    private var controlSize: ControlSize {
        switch size {
        case .md: return .large
        case .sm: return .regular
        case .xs: return .small
        }
    }

    @ViewBuilder
    private func styled<B: View>(_ button: B) -> some View {
        switch variant {
        case .primary:
            button.buttonStyle(.borderedProminent)
        case .secondary:
            button.buttonStyle(.bordered)
        case .ghost:
            button.buttonStyle(.borderless)
        case .danger:
            button.buttonStyle(.borderedProminent).tint(.red)
        }
    }
}

public enum CYButtonTokens {
    public struct Resolved {
        public let foreground: Color
        public let background: Color
        public let spinnerTint: Color
    }

    public static func resolve(
        variant: CYButtonVariant,
        isEnabled: Bool,
        isPressed: Bool
    ) -> Resolved {
        guard isEnabled else {
            let spinnerTint: Color = switch variant {
            case .primary: CYColor.actionPrimaryFg
            case .secondary: CYColor.textSecondary
            case .ghost: CYColor.textPrimary
            case .danger: CYColor.actionDangerFg
            }
            return Resolved(
                foreground: CYColor.textPlaceholder,
                background: variant == .ghost ? Color.clear : CYColor.bgSurfaceSubtle,
                spinnerTint: spinnerTint
            )
        }
        switch variant {
        case .primary:
            return Resolved(
                foreground: CYColor.actionPrimaryFg,
                background: isPressed ? CYColor.brandStrong : CYColor.actionPrimaryBg,
                spinnerTint: CYColor.actionPrimaryFg
            )
        case .secondary:
            return Resolved(
                foreground: CYColor.textSecondary,
                background: isPressed ? CYColor.bgSurfaceStrong : CYColor.actionSecondary,
                spinnerTint: CYColor.textSecondary
            )
        case .ghost:
            return Resolved(
                foreground: CYColor.textPrimary,
                background: isPressed ? CYColor.bgSurfaceSubtle : Color.clear,
                spinnerTint: CYColor.textPrimary
            )
        case .danger:
            return Resolved(
                foreground: CYColor.actionDangerFg,
                background: CYColor.actionDangerBg,
                spinnerTint: CYColor.actionDangerFg
            )
        }
    }
}

public struct CYPrimaryButtonStyle: ButtonStyle {
    public var isFullWidth: Bool
    public var size: CYButtonSize
    public var isLoading: Bool
    public var isPill: Bool

    public init(isFullWidth: Bool = true, size: CYButtonSize = .md, isLoading: Bool = false, isPill: Bool = false) {
        self.isFullWidth = isFullWidth
        self.size = size
        self.isLoading = isLoading
        self.isPill = isPill
    }

    public func makeBody(configuration: Configuration) -> some View {
        CYSystemButtonHost(configuration: configuration, variant: .primary, size: size, isFullWidth: isFullWidth, isLoading: isLoading)
    }
}

/// Secondary button style with subtle surface fill and no outer border (`>= 44pt` hit target).
public struct CYSecondaryButtonStyle: ButtonStyle {
    public var isFullWidth: Bool
    public var size: CYButtonSize
    public var isLoading: Bool
    public var isPill: Bool

    public init(isFullWidth: Bool = false, size: CYButtonSize = .md, isLoading: Bool = false, isPill: Bool = false) {
        self.isFullWidth = isFullWidth
        self.size = size
        self.isLoading = isLoading
        self.isPill = isPill
    }

    public func makeBody(configuration: Configuration) -> some View {
        CYSystemButtonHost(configuration: configuration, variant: .secondary, size: size, isFullWidth: isFullWidth, isLoading: isLoading)
    }
}

/// Ghost button style (transparent background, text-primary/secondary label, press fill only).
public struct CYGhostButtonStyle: ButtonStyle {
    public var isFullWidth: Bool
    public var size: CYButtonSize
    public var isLoading: Bool
    public var isPill: Bool

    public init(isFullWidth: Bool = false, size: CYButtonSize = .md, isLoading: Bool = false, isPill: Bool = false) {
        self.isFullWidth = isFullWidth
        self.size = size
        self.isLoading = isLoading
        self.isPill = isPill
    }

    public func makeBody(configuration: Configuration) -> some View {
        CYSystemButtonHost(configuration: configuration, variant: .ghost, size: size, isFullWidth: isFullWidth, isLoading: isLoading)
    }
}

/// Destructive button style (`--cy-color-action-danger-bg` `#D0323B` with `--cy-color-action-danger-fg` `#FFFFFF`).
public struct CYDestructiveButtonStyle: ButtonStyle {
    public var isFullWidth: Bool
    public var size: CYButtonSize
    public var isLoading: Bool
    public var isPill: Bool

    public init(isFullWidth: Bool = false, size: CYButtonSize = .md, isLoading: Bool = false, isPill: Bool = false) {
        self.isFullWidth = isFullWidth
        self.size = size
        self.isLoading = isLoading
        self.isPill = isPill
    }

    public func makeBody(configuration: Configuration) -> some View {
        CYSystemButtonHost(configuration: configuration, variant: .danger, size: size, isFullWidth: isFullWidth, isLoading: isLoading)
    }
}

/// Unified spec button supporting variants (`primary`, `secondary`, `ghost`, `danger`), sizes (`md`, `sm`, `xs`),
/// footer `isPill`, `isLoading` lock, and disabled surface tokens.
public struct CYButton<Label: View>: View {
    private let variant: CYButtonVariant
    private let size: CYButtonSize
    private let isFullWidth: Bool
    private let isLoading: Bool
    private let isPill: Bool
    private let action: () -> Void
    private let label: Label

    public init(
        variant: CYButtonVariant = .primary,
        size: CYButtonSize = .md,
        isFullWidth: Bool = true,
        isLoading: Bool = false,
        isPill: Bool = false,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Label
    ) {
        self.variant = variant
        self.size = size
        self.isFullWidth = isFullWidth
        self.isLoading = isLoading
        self.isPill = isPill
        self.action = action
        self.label = label()
    }

    public var body: some View {
        Group {
            switch variant {
            case .primary:
                Button(action: action) { label }
                    .buttonStyle(CYPrimaryButtonStyle(isFullWidth: isFullWidth, size: size, isLoading: isLoading, isPill: isPill))
            case .secondary:
                Button(action: action) { label }
                    .buttonStyle(CYSecondaryButtonStyle(isFullWidth: isFullWidth, size: size, isLoading: isLoading, isPill: isPill))
            case .ghost:
                Button(action: action) { label }
                    .buttonStyle(CYGhostButtonStyle(isFullWidth: isFullWidth, size: size, isLoading: isLoading, isPill: isPill))
            case .danger:
                Button(role: .destructive, action: action) { label }
                    .buttonStyle(CYDestructiveButtonStyle(isFullWidth: isFullWidth, size: size, isLoading: isLoading, isPill: isPill))
            }
        }
        .disabled(isLoading)
    }
}

public extension CYButton where Label == Text {
    init(
        _ titleKey: LocalizedStringKey,
        variant: CYButtonVariant = .primary,
        size: CYButtonSize = .md,
        isFullWidth: Bool = true,
        isLoading: Bool = false,
        isPill: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            variant: variant,
            size: size,
            isFullWidth: isFullWidth,
            isLoading: isLoading,
            isPill: isPill,
            action: action
        ) {
            Text(titleKey)
        }
    }

    init(
        verbatim title: String,
        variant: CYButtonVariant = .primary,
        size: CYButtonSize = .md,
        isFullWidth: Bool = true,
        isLoading: Bool = false,
        isPill: Bool = false,
        action: @escaping () -> Void
    ) {
        self.init(
            variant: variant,
            size: size,
            isFullWidth: isFullWidth,
            isLoading: isLoading,
            isPill: isPill,
            action: action
        ) {
            Text(verbatim: title)
        }
    }
}

public extension ButtonStyle where Self == CYPrimaryButtonStyle {
    static var cyPrimary: CYPrimaryButtonStyle { CYPrimaryButtonStyle() }
    static func cyPrimary(fullWidth: Bool) -> CYPrimaryButtonStyle {
        CYPrimaryButtonStyle(isFullWidth: fullWidth)
    }
    static func cyFooterPill(isLoading: Bool = false) -> CYPrimaryButtonStyle {
        CYPrimaryButtonStyle(isFullWidth: true, size: .md, isLoading: isLoading, isPill: true)
    }
}

public extension ButtonStyle where Self == CYSecondaryButtonStyle {
    static var cySecondary: CYSecondaryButtonStyle { CYSecondaryButtonStyle() }
    static func cySecondary(fullWidth: Bool) -> CYSecondaryButtonStyle {
        CYSecondaryButtonStyle(isFullWidth: fullWidth)
    }
}

public extension ButtonStyle where Self == CYGhostButtonStyle {
    static var cyGhost: CYGhostButtonStyle { CYGhostButtonStyle() }
    static func cyGhost(fullWidth: Bool) -> CYGhostButtonStyle {
        CYGhostButtonStyle(isFullWidth: fullWidth)
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

    public static func fillColor(for style: CYUnreadBadgeStyle) -> Color {
        switch style {
        case .danger: return CYColor.dangerSolid
        case .accent: return CYColor.brand
        case .muted: return CYColor.bgSurfaceStrong
        }
    }

    public static func foregroundColor(for style: CYUnreadBadgeStyle) -> Color {
        switch style {
        case .danger: return Color.white
        case .accent: return CYColor.textOnAccent
        case .muted: return CYColor.textSecondary
        }
    }

    private var fillColor: Color { Self.fillColor(for: style) }
    private var foregroundColor: Color { Self.foregroundColor(for: style) }

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
                    .cyText(.micro, monospacedDigit: true)
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

    public static func ringColor(showAccentRing: Bool) -> Color {
        showAccentRing ? CYColor.avatarRing : CYColor.borderSubtle
    }

    public static func onlineDotColor(isOnline: Bool?) -> Color? {
        guard let isOnline else { return nil }
        return isOnline ? CYColor.successText : CYColor.textDisabled
    }

    private var fallbackView: some View {
        MPAsset.AvatarDefault.dProfile
            .resizable()
            .scaledToFill()
    }
}
