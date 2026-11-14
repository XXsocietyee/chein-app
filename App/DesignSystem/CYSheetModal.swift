import SwiftUI

/// Bottom-sheet detents from DESIGN.md Part 4 (`peek 30%`, `half 60%`, `full 80%`).
public enum CYSheetDetent: Sendable, Hashable {
    case peek
    case half
    case full

    public var presentationDetent: PresentationDetent {
        switch self {
        case .peek: return .fraction(0.30)
        case .half: return .fraction(0.60)
        case .full: return .fraction(0.80)
        }
    }
}

/// Top grabber + domain glass/card container matching DESIGN.md Part 4 Sheet anatomy:
/// 24pt top radius, 36×4pt handle (`sheetHandle`), player glass `rgba(44,44,46,.98)`, sheet card `#3A3A3C` / `#F8F9FA`.
public struct CYSheetContainer<Content: View>: View {
    private let title: String?
    private let onClose: (() -> Void)?
    private let content: Content

    @Environment(\.cyPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    public init(
        title: String? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.onClose = onClose
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            Capsule(style: .continuous)
                .fill(palette.sheetHandle)
                .frame(
                    width: Theme.length("--cy-sheet-immersive-grab-w"),
                    height: Theme.length("--cy-sheet-immersive-grab-h")
                )
                .padding(.top, CYSpacing.s2_5)
                .padding(.bottom, CYSpacing.sm)
                .accessibilityHidden(true)

            if title != nil || onClose != nil {
                HStack(spacing: CYSpacing.md) {
                    if let title {
                        Text(verbatim: title)
                            .font(CYTypography.sheetTitle)
                            .foregroundStyle(palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                    }
                    Spacer(minLength: CYSpacing.sm)
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(palette.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Circle().fill(palette.sheetCard))
                                .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("action.close"))
                    }
                }
                .padding(.horizontal, CYSpacing.lg)
                .padding(.bottom, CYSpacing.md)
            }

            content
                .padding(.horizontal, CYSpacing.lg)
                .padding(.bottom, CYSpacing.lg)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            UnevenRoundedRectangle(
                topLeadingRadius: CYRadius.sheet,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: CYRadius.sheet,
                style: .continuous
            )
            .fill(palette.sheetGlass)
            .ignoresSafeArea(edges: .bottom)
        )
    }
}

/// Domain-styled modal/sheet presentation helper applying spec detents, 24pt sheet radius, and role surface.
public extension View {
    func cyDomainSheet(
        detents: [CYSheetDetent] = [.half, .full],
        selection: Binding<PresentationDetent>? = nil
    ) -> some View {
        let mapped = Set(detents.map(\.presentationDetent))
        return self
            .modifier(CYDomainSheetDetentsModifier(detents: mapped, selection: selection))
            .presentationDragIndicator(.hidden)
            .presentationCornerRadius(CYRadius.sheet)
            .presentationBackground(CYColor.sheetGlass)
            .roleThemedPresentation()
    }
}

private struct CYDomainSheetDetentsModifier: ViewModifier {
    let detents: Set<PresentationDetent>
    let selection: Binding<PresentationDetent>?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let selection {
            content.presentationDetents(detents, selection: selection)
        } else {
            content.presentationDetents(detents)
        }
    }
}

/// Option row item for `CYOptionSheet` (`56pt` tall row, 0.5pt divider, radio/check/danger).
public struct CYOptionSheetItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let subtitle: String?
    public let systemImage: String?
    public let isDanger: Bool

    public init(
        id: ID,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        isDanger: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isDanger = isDanger
    }
}

/// Bottom action/picker option sheet rendered inside `CYSheetContainer`.
public struct CYOptionSheet<ID: Hashable>: View {
    private let title: String
    private let items: [CYOptionSheetItem<ID>]
    private let selectedID: ID?
    private let onSelect: (ID) -> Void
    private let onClose: () -> Void

    @Environment(\.cyPalette) private var palette

    public init(
        title: String,
        items: [CYOptionSheetItem<ID>],
        selectedID: ID? = nil,
        onSelect: @escaping (ID) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.items = items
        self.selectedID = selectedID
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        CYSheetContainer(title: title, onClose: onClose) {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let isSelected = item.id == selectedID
                    Button {
                        onSelect(item.id)
                    } label: {
                        HStack(spacing: CYSpacing.md) {
                            if let systemImage = item.systemImage {
                                Image(systemName: systemImage)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(item.isDanger ? palette.danger : palette.textPrimary)
                                    .frame(width: 24)
                            }
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text(verbatim: item.title)
                                    .font(CYTypography.cardTitle)
                                    .foregroundStyle(item.isDanger ? palette.danger : palette.textPrimary)
                                if let subtitle = item.subtitle {
                                    Text(verbatim: subtitle)
                                        .font(CYTypography.meta)
                                        .foregroundStyle(palette.textTertiary)
                                }
                            }
                            Spacer(minLength: CYSpacing.sm)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(palette.textPrimary)
                            }
                        }
                        .padding(.horizontal, CYSpacing.lg)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CYListRowButtonStyle())

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(palette.borderSubtle)
                            .frame(height: 0.5)
                            .padding(.leading, CYSpacing.lg)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.sheetCard))
            .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        }
    }
}

/// Centered scrim dialog (`maxWidth: 320pt`, `CYRadius.lg` 16pt radius, `modalPanel`, `bgOverlay` scrim).
/// Supports standard confirmation and 3-part destructive layout (consequences + lighter alt + solid danger button).
public struct CYModal: View {
    private let title: String
    private let message: String
    private let consequences: [CYConfirmConsequence]
    private let cancelTitle: String
    private let confirmTitle: String
    private let lighterAlternativeTitle: String?
    private let isDestructive: Bool
    private let isConfirmLoading: Bool
    private let onCancel: () -> Void
    private let onLighterAlternative: (() -> Void)?
    private let onConfirm: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        message: String,
        consequences: [CYConfirmConsequence] = [],
        cancelTitle: String = "取消",
        confirmTitle: String = "确认",
        lighterAlternativeTitle: String? = nil,
        isDestructive: Bool = false,
        isConfirmLoading: Bool = false,
        onCancel: @escaping () -> Void,
        onLighterAlternative: (() -> Void)? = nil,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self.consequences = consequences
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.lighterAlternativeTitle = lighterAlternativeTitle
        self.isDestructive = isDestructive
        self.isConfirmLoading = isConfirmLoading
        self.onCancel = onCancel
        self.onLighterAlternative = onLighterAlternative
        self.onConfirm = onConfirm
    }

    public var body: some View {
        ZStack {
            palette.overlay
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            panelCard
                .padding(.horizontal, CYSpacing.xxxl)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
        }
    }

    /// Standalone modal panel (also directly embeddable in side-by-side Design Kit fixtures).
    public var panelCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                Text(verbatim: title)
                    .font(CYTypography.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: CYSpacing.sm)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(palette.bgSurfaceSubtle))
                        .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .accessibilityLabel(Text("action.close"))
            }

            Text(verbatim: message)
                .font(CYTypography.bodyCompact)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if !consequences.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.s2_5) {
                    ForEach(consequences) { item in
                        HStack(alignment: .top, spacing: CYSpacing.sm) {
                            Image(systemName: item.systemImage)
                                .font(CYTypography.caption.weight(.semibold))
                                .foregroundStyle(isDestructive ? palette.danger : palette.textSecondary)
                                .frame(width: 20, alignment: .center)
                                .accessibilityHidden(true)
                            Text(verbatim: item.text)
                                .font(CYTypography.meta)
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(CYSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.sheetCard))
            }

            if let lighterAlternativeTitle, let onLighterAlternative {
                Button(action: onLighterAlternative) {
                    Text(verbatim: lighterAlternativeTitle)
                        .font(CYTypography.label.weight(.semibold))
                        .foregroundStyle(palette.info)
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                }
                .buttonStyle(CYGhostButtonStyle(isFullWidth: true, size: .sm))
            }

            HStack(spacing: CYSpacing.md) {
                Button(action: onCancel) {
                    Text(verbatim: cancelTitle)
                }
                .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))

                if isDestructive {
                    Button(role: .destructive, action: onConfirm) {
                        Text(verbatim: confirmTitle)
                    }
                    .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true, isLoading: isConfirmLoading))
                } else {
                    Button(action: onConfirm) {
                        Text(verbatim: confirmTitle)
                    }
                    .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, isLoading: isConfirmLoading))
                }
            }
        }
        .padding(CYSpacing.xl)
        .frame(maxWidth: 320, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.modalPanel))
        .shadow(color: palette.floatShadowColor, radius: 20, x: 0, y: 10)
    }
}
