import SwiftUI

/// Tab visual/behavioural variants from DESIGN.md Part 4 (`underline`, `segmented`, `chip`, `sticky`).
public enum CYTabsVariant: Sendable, Hashable {
    case underline
    case segmented
    case chip
    case sticky
}

/// Tab descriptor for `CYTabs`.
public struct CYTabItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let badgeCount: Int?
    public let systemImage: String?

    public init(id: ID, title: String, badgeCount: Int? = nil, systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.badgeCount = badgeCount
        self.systemImage = systemImage
    }
}

/// Pure state-to-token resolver for `CYTabs`.
enum CYTabsTokens {
    struct Resolved {
        let foreground: Color
        let badgeForeground: Color
        let indicatorFill: Color?
        let trackFill: Color?
        let divider: Color?
        let containerBackground: Color?
    }

    static func resolve(variant: CYTabsVariant, isSelected: Bool, in palette: CYDomainPalette) -> Resolved {
        switch variant {
        case .underline, .sticky:
            return Resolved(
                foreground: isSelected ? palette.textPrimary : palette.textSecondary,
                badgeForeground: isSelected ? palette.textPrimary : palette.textTertiary,
                indicatorFill: isSelected ? palette.textPrimary : nil,
                trackFill: nil,
                divider: palette.borderSubtle,
                containerBackground: variant == .sticky ? palette.bgPage : nil
            )
        case .segmented:
            return Resolved(
                foreground: isSelected ? palette.textInverse : palette.textSecondary,
                badgeForeground: isSelected ? palette.textInverse : palette.textTertiary,
                indicatorFill: isSelected ? palette.textPrimary : nil,
                trackFill: palette.bgSurfaceSubtle,
                divider: nil,
                containerBackground: nil
            )
        case .chip:
            let chip = CYFilterChip.tokens(isSelected: isSelected, in: palette)
            return Resolved(
                foreground: chip.foreground,
                badgeForeground: chip.countForeground,
                indicatorFill: chip.background,
                trackFill: nil,
                divider: nil,
                containerBackground: nil
            )
        }
    }
}

/// Shared tab switcher across `underline`, `segmented`, `chip`, and `sticky` modes.
/// Active indicator always uses neutral high-contrast tokens (`textPrimary`), never violet.
public struct CYTabs<ID: Hashable>: View {
    private let items: [CYTabItem<ID>]
    @Binding private var selection: ID
    private let variant: CYTabsVariant

    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var tabNamespace

    public init(
        items: [CYTabItem<ID>],
        selection: Binding<ID>,
        variant: CYTabsVariant = .underline
    ) {
        self.items = items
        self._selection = selection
        self.variant = variant
    }

    public var body: some View {
        switch variant {
        case .underline:
            underlineBar
        case .segmented:
            segmentedBar
        case .chip:
            chipBar
        case .sticky:
            let tokens = CYTabsTokens.resolve(variant: .sticky, isSelected: true, in: palette)
            underlineBar
                .background(tokens.containerBackground ?? palette.bgPage)
                .zIndex(85)
        }
    }

    @ViewBuilder
    private var underlineBar: some View {
        let shouldScroll = items.count >= 5
        let barTokens = CYTabsTokens.resolve(variant: variant, isSelected: false, in: palette)
        VStack(spacing: 0) {
            if shouldScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.lg) {
                        ForEach(items) { item in
                            underlineTabButton(item, fillsWidth: false)
                        }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(items) { item in
                        underlineTabButton(item, fillsWidth: true)
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
            }
            Rectangle()
                .fill(barTokens.divider ?? palette.borderSubtle)
                .frame(height: 0.5)
        }
    }

    private func underlineTabButton(_ item: CYTabItem<ID>, fillsWidth: Bool) -> some View {
        let isSelected = item.id == selection
        let tokens = CYTabsTokens.resolve(variant: variant, isSelected: isSelected, in: palette)
        return Button {
            select(item.id)
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                HStack(spacing: CYSpacing.xs) {
                    if let systemImage = item.systemImage {
                        Image(systemName: systemImage)
                            .font(CYTypography.caption.weight(.semibold))
                    }
                    Text(verbatim: item.title)
                        .font(CYTypography.label.weight(isSelected ? .bold : .semibold))
                    if let badgeCount = item.badgeCount, badgeCount > 0 {
                        Text(verbatim: "\(badgeCount)")
                            .font(CYTypography.micro.weight(.bold).monospacedDigit())
                            .foregroundStyle(tokens.badgeForeground)
                    }
                }
                .foregroundStyle(tokens.foreground)
                .lineLimit(1)
                Spacer(minLength: 0)
                Group {
                    if let indicatorFill = tokens.indicatorFill {
                        Capsule(style: .continuous)
                            .fill(indicatorFill)
                            .frame(width: 24, height: 2.5)
                            .matchedGeometryEffect(id: "cy-tab-underline", in: tabNamespace, isSource: true)
                    } else {
                        Color.clear.frame(width: 24, height: 2.5)
                    }
                }
            }
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var segmentedBar: some View {
        let trackFill = CYTabsTokens.resolve(variant: .segmented, isSelected: false, in: palette).trackFill ?? palette.bgSurfaceSubtle
        return HStack(spacing: CYSpacing.xs) {
            ForEach(items) { item in
                let isSelected = item.id == selection
                let tokens = CYTabsTokens.resolve(variant: .segmented, isSelected: isSelected, in: palette)
                Button {
                    select(item.id)
                } label: {
                    HStack(spacing: CYSpacing.xs) {
                        if let systemImage = item.systemImage {
                            Image(systemName: systemImage)
                                .font(CYTypography.caption.weight(.semibold))
                        }
                        Text(verbatim: item.title)
                            .font(CYTypography.label.weight(isSelected ? .bold : .semibold))
                            .lineLimit(1)
                    }
                    .foregroundStyle(tokens.foreground)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background {
                        if let indicatorFill = tokens.indicatorFill {
                            RoundedRectangle(cornerRadius: CYRadius.sm + 2, style: .continuous)
                                .fill(indicatorFill)
                                .matchedGeometryEffect(id: "cy-tab-segment", in: tabNamespace)
                        }
                    }
                    .frame(minHeight: CYSpacing.minTouchTarget - 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(trackFill))
    }

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.sm) {
                ForEach(items) { item in
                    CYFilterChip(
                        verbatim: item.title,
                        systemImage: item.systemImage,
                        count: item.badgeCount,
                        isSelected: item.id == selection
                    ) {
                        select(item.id)
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
        }
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [palette.bgPage.opacity(0), palette.bgPage],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 24)
            .allowsHitTesting(false)
        }
    }

    private func select(_ id: ID) {
        if reduceMotion {
            selection = id
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                selection = id
            }
        }
    }
}
