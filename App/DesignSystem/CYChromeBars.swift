import SwiftUI

/// Navigation bar surface variants per DESIGN.md Part 4 (`plain`, `solid`, `overlayHero`).
/// Note: Back button is a bare chevron on `plain`/`solid`; `32pt` glass circle pill appears ONLY on `overlayHero`.
public enum CYNavBarMode: Sendable, Hashable {
    case plain
    case solid
    case overlayHero
}

public enum CYNavBarTokens {
    public struct Resolved {
        public let titleColor: Color
        public let backForeground: Color
        public let backBadgeFill: Color?
        public let backgroundColor: Color
        public let dividerColor: Color?
    }

    static func resolve(
        mode: CYNavBarMode,
        colorScheme: ColorScheme,
        in palette: CYDomainPalette
    ) -> Resolved {
        switch mode {
        case .plain:
            return Resolved(
                titleColor: palette.textPrimary,
                backForeground: palette.textPrimary,
                backBadgeFill: nil,
                backgroundColor: Color.clear,
                dividerColor: nil
            )
        case .solid:
            return Resolved(
                titleColor: palette.textPrimary,
                backForeground: palette.textPrimary,
                backBadgeFill: nil,
                backgroundColor: palette.bgPage,
                dividerColor: colorScheme == .light ? palette.borderSubtle : nil
            )
        case .overlayHero:
            return Resolved(
                titleColor: palette.onCoverFg,
                backForeground: palette.onCoverFg,
                backBadgeFill: palette.bgGlass,
                backgroundColor: Color.clear,
                dividerColor: nil
            )
        }
    }
}

public enum CYFooterBarTokens {
    public struct Resolved {
        public let divider: Color
        public let background: Color
        public let primaryVariant: CYButtonVariant
        public let secondaryVariant: CYButtonVariant
        public let usesStackedDualLayout: Bool
    }

    static func resolve(isAccessibilitySize: Bool, in palette: CYDomainPalette) -> Resolved {
        Resolved(
            divider: palette.borderSubtle,
            background: palette.bgPage,
            primaryVariant: .primary,
            secondaryVariant: .secondary,
            usesStackedDualLayout: isAccessibilitySize
        )
    }
}

/// Top navigation bar (`44pt` bar + safe-area top option, centered `18pt` title with `48pt` horizontal clearance).
public struct CYNavBar<Trailing: View>: View {
    private let title: String
    private let mode: CYNavBarMode
    private let showsBack: Bool
    private let includesTopSafeArea: Bool
    private let onBack: (() -> Void)?
    private let trailing: Trailing

    @Environment(\.cyPalette) private var palette
    @Environment(\.colorScheme) private var colorScheme

    public init(
        title: String,
        mode: CYNavBarMode = .solid,
        showsBack: Bool = true,
        includesTopSafeArea: Bool = false,
        onBack: (() -> Void)? = nil,
        @ViewBuilder trailing: () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.mode = mode
        self.showsBack = showsBack
        self.includesTopSafeArea = includesTopSafeArea
        self.onBack = onBack
        self.trailing = trailing()
    }

    public var body: some View {
        ZStack {
            Text(verbatim: title)
                .font(CYTypography.pageTitle)
                .foregroundStyle(titleColor)
                .lineLimit(1)
                .padding(.horizontal, 48)

            HStack {
                if showsBack {
                    Button(action: { onBack?() }) {
                        backGlyph
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Text("action.back"))
                } else {
                    Color.clear.frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                }

                Spacer()

                trailing
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
            }
            .padding(.horizontal, CYSpacing.xs)
        }
        .frame(height: CYSpacing.minTouchTarget)
        .padding(.top, includesTopSafeArea ? 44 : 0)
        .background(backgroundSurface)
    }

    private var navTokens: CYNavBarTokens.Resolved {
        CYNavBarTokens.resolve(mode: mode, colorScheme: colorScheme, in: palette)
    }

    private var titleColor: Color {
        navTokens.titleColor
    }

    @ViewBuilder
    private var backGlyph: some View {
        let tokens = navTokens
        if let badgeFill = tokens.backBadgeFill {
            Image(systemName: "chevron.left")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(tokens.backForeground)
                .frame(width: 32, height: 32)
                .background(Circle().fill(badgeFill))
                .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
        } else {
            Image(systemName: "chevron.left")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(tokens.backForeground)
                .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                .contentShape(Rectangle())
        }
    }

    @ViewBuilder
    private var backgroundSurface: some View {
        let tokens = navTokens
        tokens.backgroundColor
            .overlay(alignment: .bottom) {
                if let dividerColor = tokens.dividerColor {
                    Rectangle()
                        .fill(dividerColor)
                        .frame(height: 0.5)
                }
            }
    }
}

/// Footer bar CTA arrangement per DESIGN.md Part 4:
/// single full-width pill CTA OR dual 1:2 ratio (secondary flex 1, primary flex 2, 12pt gap), stacking at AX sizes.
public struct CYFooterAction {
    public let title: String
    public let isLoading: Bool
    public let isDisabled: Bool
    public let action: () -> Void

    public init(
        _ title: String,
        isLoading: Bool = false,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.isLoading = isLoading
        self.isDisabled = isDisabled
        self.action = action
    }
}

/// Pinned bottom footer bar (`bgPage`, `12 × 16pt` padding, 0.5pt top divider, pill CTAs).
public struct CYFooterBar: View {
    private let primary: CYFooterAction
    private let secondary: CYFooterAction?
    private let ignoresBottomSafeArea: Bool

    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    public init(
        primary: CYFooterAction,
        secondary: CYFooterAction? = nil,
        ignoresBottomSafeArea: Bool = false
    ) {
        self.primary = primary
        self.secondary = secondary
        self.ignoresBottomSafeArea = ignoresBottomSafeArea
    }

    public var body: some View {
        let tokens = CYFooterBarTokens.resolve(isAccessibilitySize: typeSize.isAccessibilitySize, in: palette)
        VStack(spacing: 0) {
            Rectangle()
                .fill(tokens.divider)
                .frame(height: 0.5)

            Group {
                if let secondary {
                    if tokens.usesStackedDualLayout {
                        VStack(spacing: CYSpacing.md) {
                            primaryButton(primary)
                            secondaryButton(secondary)
                        }
                    } else {
                        CYFooterDualRatioLayout(gap: CYSpacing.md) {
                            secondaryButton(secondary)
                            primaryButton(primary)
                        }
                    }
                } else {
                    primaryButton(primary)
                }
            }
            .padding(.horizontal, CYSpacing.lg)
            .padding(.vertical, CYSpacing.md)
        }
        .background {
            if ignoresBottomSafeArea {
                tokens.background.ignoresSafeArea(edges: .bottom)
            } else {
                tokens.background
            }
        }
    }

    private func primaryButton(_ spec: CYFooterAction) -> some View {
        Button(action: spec.action) {
            Text(verbatim: spec.title)
        }
        .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, size: .md, isLoading: spec.isLoading, isPill: true))
        .disabled(spec.isDisabled || spec.isLoading)
    }

    private func secondaryButton(_ spec: CYFooterAction) -> some View {
        Button(action: spec.action) {
            Text(verbatim: spec.title)
        }
        .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true, size: .md, isLoading: spec.isLoading, isPill: true))
        .disabled(spec.isDisabled || spec.isLoading)
    }
}

/// Allocates 1:2 horizontal split (`secondary` 1/3, `primary` 2/3 of available width minus gap).
private struct CYFooterDualRatioLayout: Layout {
    let gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 2 else { return .zero }
        let totalW = max(0, (proposal.width ?? 320) - gap)
        let leftW = totalW / 3
        let rightW = totalW - leftW
        let leftH = subviews[0].sizeThatFits(ProposedViewSize(width: leftW, height: nil)).height
        let rightH = subviews[1].sizeThatFits(ProposedViewSize(width: rightW, height: nil)).height
        return CGSize(width: proposal.width ?? 320, height: max(leftH, rightH))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let usableW = max(0, bounds.width - gap)
        let leftW = usableW / 3
        let rightW = usableW - leftW
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: leftW, height: bounds.height)
        )
        subviews[1].place(
            at: CGPoint(x: bounds.minX + leftW + gap, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: rightW, height: bounds.height)
        )
    }
}
