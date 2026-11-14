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
            underlineBar
                .background(palette.bgPage)
                .zIndex(85)
        }
    }

    @ViewBuilder
    private var underlineBar: some View {
        let shouldScroll = items.count >= 5
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
                .fill(palette.borderSubtle)
                .frame(height: 0.5)
        }
    }

    private func underlineTabButton(_ item: CYTabItem<ID>, fillsWidth: Bool) -> some View {
        let isSelected = item.id == selection
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
                            .foregroundStyle(isSelected ? palette.textPrimary : palette.textTertiary)
                    }
                }
                .foregroundStyle(isSelected ? palette.textPrimary : palette.textSecondary)
                .cyWrapText(alignment: .center)
                Spacer(minLength: 0)
                Group {
                    if isSelected {
                        Capsule(style: .continuous)
                            .fill(palette.textPrimary)
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
        HStack(spacing: CYSpacing.xs) {
            ForEach(items) { item in
                let isSelected = item.id == selection
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
                            .cyWrapText(alignment: .center)
                    }
                    .foregroundStyle(isSelected ? palette.textInverse : palette.textSecondary)
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background {
                        if isSelected {
                            RoundedRectangle(cornerRadius: CYRadius.sm + 2, style: .continuous)
                                .fill(palette.textPrimary)
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
        .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.bgSurfaceSubtle))
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
