import SwiftUI

/// Bottom-sheet detents. Native iOS restyle r1: `half` and `full` are the system `.medium` / `.large` detents;
/// `peek` (30%) stays a fraction because the system has no smaller standard detent.
public enum CYSheetDetent: Sendable, Hashable {
    case peek
    case half
    case full

    public var presentationDetent: PresentationDetent {
        switch self {
        case .peek: return .fraction(0.30)
        case .half: return .medium
        case .full: return .large
        }
    }
}

/// Sheet content container (native iOS restyle r1): system drag indicator and system sheet corners, domain
/// sheet surface, optional title row with a system-style close button (44pt target).
public struct CYSheetContainer<Content: View>: View {
    private let title: String?
    private let closeIdentifier: String?
    private let onClose: (() -> Void)?
    private let content: Content

    @Environment(\.cyPalette) private var palette
    @Environment(\.dismiss) private var dismiss

    public init(
        title: String? = nil,
        closeIdentifier: String? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.closeIdentifier = closeIdentifier
        self.onClose = onClose
        self.content = content()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Native restyle r1: the system drag indicator replaces the drawn grabber.
            Color.clear
                .frame(height: CYSpacing.xl)
                .accessibilityHidden(true)

            if title != nil || onClose != nil {
                HStack(spacing: CYSpacing.md) {
                    if let title {
                        Text(verbatim: title)
                            .cyText(.sheetTitle)
                            .foregroundStyle(palette.textPrimary)
                            .accessibilityAddTraits(.isHeader)
                            .pageTemplateReadingOrder(2)
                    }
                    Spacer(minLength: CYSpacing.sm)
                    if let onClose {
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.title2)
                                .symbolRenderingMode(.hierarchical)
                                .foregroundStyle(palette.textSecondary)
                                .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("action.close"))
                        .modifier(CYOptionalAccessibilityIdentifier(identifier: closeIdentifier))
                        .pageTemplateControl(label: Text("action.close"), traits: .isButton)
                        .pageTemplateReadingOrder(1)
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
        .background(palette.sheetGlass.ignoresSafeArea(edges: .bottom))
        .presentationDragIndicator(.visible)
    }
}

/// Domain-styled sheet presentation: system detents (`.medium` / `.large`), visible drag indicator, system corners and
/// background in the role appearance (native-ios-r1 §3.4).
public extension View {
    func cyDomainSheet(
        detents: [CYSheetDetent] = [.half, .full],
        selection: Binding<PresentationDetent>? = nil
    ) -> some View {
        let mapped = Set(detents.map(\.presentationDetent))
        return self
            .modifier(CYDomainSheetDetentsModifier(detents: mapped, selection: selection))
            .presentationDragIndicator(.visible)
            .roleThemedPresentation()
    }
}

public extension View {
    /// The one sheet chrome (native restyle r1, spec §3.4). Apply to the sheet's root (usually a `NavigationStack`
    /// with an inline title and 取消 / 完成 toolbar items): system detents, visible drag indicator, system corners and
    /// background in the role's appearance.
    func cySheet(
        detents: Set<PresentationDetent> = [.medium, .large],
        selection: Binding<PresentationDetent>? = nil
    ) -> some View {
        modifier(CYDomainSheetDetentsModifier(detents: detents, selection: selection))
            .presentationDragIndicator(.visible)
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

public enum CYSheetModalTokens {
    public struct SheetResolved {
        public let background: Color
        public let handle: Color
        public let title: Color
        public let card: Color
        public let divider: Color
    }

    public struct ModalResolved {
        public let overlay: Color
        public let panel: Color
        public let consequenceBackground: Color
        public let consequenceIcon: Color
        public let confirmVariant: CYButtonVariant
        public let shadow: Color
    }

    static func sheet(in palette: CYDomainPalette) -> SheetResolved {
        SheetResolved(
            background: palette.sheetGlass,
            handle: palette.sheetHandle,
            title: palette.textPrimary,
            card: palette.sheetCard,
            divider: palette.borderSubtle
        )
    }

    static func optionRowForeground(isDanger: Bool, in palette: CYDomainPalette) -> Color {
        isDanger ? palette.danger : palette.textPrimary
    }

    static func modal(isDestructive: Bool, in palette: CYDomainPalette) -> ModalResolved {
        ModalResolved(
            overlay: palette.overlay,
            panel: palette.modalPanel,
            consequenceBackground: palette.sheetCard,
            consequenceIcon: isDestructive ? palette.danger : palette.textSecondary,
            confirmVariant: isDestructive ? .danger : .primary,
            shadow: palette.floatShadowColor
        )
    }
}

/// Returns a raw accessibility identifier without altering its value.
public func cyAccessibilityID(id: String) -> String { id }

/// Option row item for `CYOptionSheet` (`56pt` tall row, 0.5pt divider, radio/check/danger).
public struct CYOptionSheetItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let subtitle: String?
    public let systemImage: String?
    public let isDanger: Bool
    public let identifier: String?

    public init(
        id: ID,
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        isDanger: Bool = false,
        identifier: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.isDanger = isDanger
        self.identifier = identifier
    }
}

/// Bottom action/picker option sheet rendered inside `CYSheetContainer`.
public struct CYOptionSheet<ID: Hashable>: View {
    private let title: String
    private let items: [CYOptionSheetItem<ID>]
    private let selectedID: ID?
    private let onSelect: (ID) -> Void
    private let onClose: () -> Void
    private let closeIdentifier: String?

    @Environment(\.cyPalette) private var palette

    public init(
        title: String,
        items: [CYOptionSheetItem<ID>],
        selectedID: ID? = nil,
        closeIdentifier: String? = nil,
        onSelect: @escaping (ID) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.title = title
        self.items = items
        self.selectedID = selectedID
        self.closeIdentifier = closeIdentifier
        self.onSelect = onSelect
        self.onClose = onClose
    }

    public var body: some View {
        CYSheetContainer(title: title, closeIdentifier: closeIdentifier, onClose: onClose) {
            let sheetTokens = CYSheetModalTokens.sheet(in: palette)
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    let isSelected = item.id == selectedID
                    let rowColor = CYSheetModalTokens.optionRowForeground(isDanger: item.isDanger, in: palette)
                    Button {
                        onSelect(item.id)
                    } label: {
                        HStack(spacing: CYSpacing.md) {
                            if let systemImage = item.systemImage {
                                Image(systemName: systemImage)
                                    .font(.system(.body, weight: .semibold))
                                    .foregroundStyle(rowColor)
                                    .frame(width: 24)
                                    .accessibilityHidden(true)
                            }
                            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                                Text(verbatim: item.title)
                                    .cyText(.cardTitle)
                                    .foregroundStyle(rowColor)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let subtitle = item.subtitle {
                                    Text(verbatim: subtitle)
                                        .cyText(.meta)
                                        .foregroundStyle(palette.textTertiary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            Spacer(minLength: CYSpacing.sm)
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(.subheadline, weight: .bold))
                                    .foregroundStyle(palette.textPrimary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .padding(.horizontal, CYSpacing.lg)
                        .frame(maxWidth: .infinity, minHeight: 56, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(CYListRowButtonStyle())
                    .pageTemplateControl(
                        label: item.subtitle.map { Text(verbatim: item.title) + Text(verbatim: ", ") + Text(verbatim: $0) } ?? Text(verbatim: item.title),
                        traits: isSelected ? [.isButton, .isSelected] : .isButton
                    )
                    .cyOptionalAccessibilityIdentifier(item.identifier)

                    if index < items.count - 1 {
                        Rectangle()
                            .fill(sheetTokens.divider)
                            .frame(height: 0.5)
                            .padding(.leading, CYSpacing.lg)
                    }
                }
            }
            .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(sheetTokens.card))
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
    private let cancelTitle: String?
    private let confirmTitle: String
    private let lighterAlternativeTitle: String?
    private let showCancel: Bool
    private let isDestructive: Bool
    private let isConfirmLoading: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let titleIdentifier: String?
    private let lighterAlternativeIdentifier: String?
    private let onCancel: () -> Void
    private let onLighterAlternative: (() -> Void)?
    private let onConfirm: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    public init(
        title: String,
        message: String,
        consequences: [CYConfirmConsequence] = [],
        cancelTitle: String? = "取消",
        confirmTitle: String = "确认",
        lighterAlternativeTitle: String? = nil,
        showCancel: Bool = true,
        isDestructive: Bool = false,
        isConfirmLoading: Bool = false,
        confirmIdentifier: String? = nil,
        cancelIdentifier: String? = nil,
        titleIdentifier: String? = nil,
        lighterAlternativeIdentifier: String? = nil,
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
        self.showCancel = showCancel
        self.isDestructive = isDestructive
        self.isConfirmLoading = isConfirmLoading
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.titleIdentifier = titleIdentifier
        self.lighterAlternativeIdentifier = lighterAlternativeIdentifier
        self.onCancel = onCancel
        self.onLighterAlternative = onLighterAlternative
        self.onConfirm = onConfirm
    }

    public var body: some View {
        let modalTokens = CYSheetModalTokens.modal(isDestructive: isDestructive, in: palette)
        ZStack {
            modalTokens.overlay
                .ignoresSafeArea()
                .onTapGesture(perform: onCancel)

            panelCard
                .padding(.horizontal, CYSpacing.xxxl)
                .transition(reduceMotion ? .opacity : .scale(scale: 0.96).combined(with: .opacity))
        }
    }

    /// Standalone modal panel (also directly embeddable in side-by-side Design Kit fixtures).
    public var panelCard: some View {
        let modalTokens = CYSheetModalTokens.modal(isDestructive: isDestructive, in: palette)
        return VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                Text(verbatim: title)
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                    .cyOptionalAccessibilityIdentifier(titleIdentifier)
                    .pageTemplateReadingOrder(2)
                Spacer(minLength: CYSpacing.sm)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(palette.textSecondary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(palette.bgSurfaceSubtle))
                        .frame(width: CYSpacing.minTouchTarget, height: CYSpacing.minTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .offset(x: 8, y: -8)
                .pageTemplateControl(label: Text("action.close"), traits: .isButton)
                .pageTemplateReadingOrder(1)
            }

            if !message.isEmpty {
                Text(verbatim: message)
                    .cyText(.bodyCompact)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !consequences.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.s2_5) {
                    ForEach(consequences) { item in
                        HStack(alignment: .top, spacing: CYSpacing.sm) {
                            Image(systemName: item.systemImage)
                                .font(CYTypography.caption.weight(.semibold))
                                .foregroundStyle(modalTokens.consequenceIcon)
                                .frame(width: 20, alignment: .center)
                                .accessibilityHidden(true)
                            Text(verbatim: item.text)
                                .cyText(.meta)
                                .foregroundStyle(palette.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .padding(CYSpacing.md)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(modalTokens.consequenceBackground))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
            }

            if let lighterAlternativeTitle, let onLighterAlternative {
                Button(action: onLighterAlternative) {
                    Text(verbatim: lighterAlternativeTitle)
                        .cyText(.label, weight: .semibold)
                        .foregroundStyle(palette.info)
                        .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(CYGhostButtonStyle(isFullWidth: true, size: .sm))
                .cyOptionalAccessibilityIdentifier(lighterAlternativeIdentifier)
            }

            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: CYSpacing.sm) {
                    modalConfirmButton
                    if showCancel, let cancelTitle {
                        modalCancelButton(cancelTitle)
                    }
                }
            } else {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CYSpacing.md) {
                        if showCancel, let cancelTitle {
                            modalCancelButton(cancelTitle)
                        }
                        modalConfirmButton
                    }
                    VStack(spacing: CYSpacing.sm) {
                        modalConfirmButton
                        if showCancel, let cancelTitle {
                            modalCancelButton(cancelTitle)
                        }
                    }
                }
            }
        }
        .padding(CYSpacing.xl)
        .frame(maxWidth: 320, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(modalTokens.panel))
        .shadow(color: modalTokens.shadow, radius: 20, x: 0, y: 10)
    }

    @ViewBuilder private func identified<V: View>(_ identifier: String?, @ViewBuilder content: () -> V) -> some View {
        if let identifier { content().accessibilityIdentifier(identifier) } else { content() }
    }

    @ViewBuilder private func modalCancelButton(_ cancelTitle: String) -> some View {
        identified(cancelIdentifier) {
            Button(action: onCancel) {
                Text(verbatim: cancelTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
        }
        .pageTemplateControl(label: Text(verbatim: cancelTitle), traits: .isButton)
        .pageTemplateReadingOrder(2)
    }

    @ViewBuilder private var modalConfirmButton: some View {
        if isDestructive {
            identified(confirmIdentifier) {
                Button(role: .destructive, action: onConfirm) {
                    Text(verbatim: confirmTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true, isLoading: isConfirmLoading))
            }
            .pageTemplateControl(label: Text(verbatim: confirmTitle), traits: .isButton)
            .pageTemplateReadingOrder(1)
        } else {
            identified(confirmIdentifier) {
                Button(action: onConfirm) {
                    Text(verbatim: confirmTitle)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, isLoading: isConfirmLoading))
            }
            .pageTemplateControl(label: Text(verbatim: confirmTitle), traits: .isButton)
            .pageTemplateReadingOrder(1)
        }
    }
}

/// Centered prompt modal matching `utils/modal.js` editable input dialogs (`overlay`, `modalPanel`, inline validation).
public struct CYPromptModal: View {
    private let title: String
    private let message: String?
    @Binding private var text: String
    private let placeholder: String
    private let validationMessage: String?
    private let cancelTitle: String
    private let confirmTitle: String
    private let isDestructive: Bool
    private let isConfirmLoading: Bool
    private let cancelIdentifier: String?
    private let confirmIdentifier: String?
    private let onCancel: () -> Void
    private let onConfirm: () -> Void

    @Environment(\.cyPalette) private var palette
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(
        title: String,
        message: String? = nil,
        text: Binding<String>,
        placeholder: String = "",
        validationMessage: String? = nil,
        cancelTitle: String = "取消",
        confirmTitle: String = "确认",
        isDestructive: Bool = false,
        isConfirmLoading: Bool = false,
        cancelIdentifier: String? = nil,
        confirmIdentifier: String? = nil,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping () -> Void
    ) {
        self.title = title
        self.message = message
        self._text = text
        self.placeholder = placeholder
        self.validationMessage = validationMessage
        self.cancelTitle = cancelTitle
        self.confirmTitle = confirmTitle
        self.isDestructive = isDestructive
        self.isConfirmLoading = isConfirmLoading
        self.cancelIdentifier = cancelIdentifier
        self.confirmIdentifier = confirmIdentifier
        self.onCancel = onCancel
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

    public var panelCard: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            HStack(alignment: .top, spacing: CYSpacing.sm) {
                Text(verbatim: title)
                    .cyText(.sectionTitle)
                    .foregroundStyle(palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: CYSpacing.sm)
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(CYTypography.caption.weight(.semibold))
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

            if let message, !message.isEmpty {
                Text(verbatim: message)
                    .cyText(.bodyCompact)
                    .foregroundStyle(palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: CYSpacing.xs) {
                TextField(text: $text, prompt: Text(verbatim: placeholder).foregroundStyle(palette.textSecondary)) {
                    Text(verbatim: title)
                }
                .cyText(.bodyCompact)
                .foregroundStyle(palette.textPrimary)
                .padding(.horizontal, CYSpacing.md)
                .padding(.vertical, CYSpacing.s2_5)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(palette.sheetCard))

                if let validationMessage, !validationMessage.isEmpty {
                    Text(verbatim: validationMessage)
                        .cyText(.meta)
                        .foregroundStyle(palette.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: CYSpacing.md) {
                    cancelButton
                    confirmButton
                }
                VStack(spacing: CYSpacing.sm) {
                    confirmButton
                    cancelButton
                }
            }
        }
        .padding(CYSpacing.xl)
        .frame(maxWidth: 320, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.modalPanel))
        .shadow(color: palette.floatShadowColor, radius: 20, x: 0, y: 10)
    }

    private var cancelButton: some View {
        Button(action: onCancel) {
            Text(verbatim: cancelTitle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .buttonStyle(CYSecondaryButtonStyle(isFullWidth: true))
        .cyOptionalAccessibilityIdentifier(cancelIdentifier)
    }

    @ViewBuilder
    private var confirmButton: some View {
        if isDestructive {
            Button(role: .destructive, action: onConfirm) {
                Text(verbatim: confirmTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(CYDestructiveButtonStyle(isFullWidth: true, isLoading: isConfirmLoading))
            .cyOptionalAccessibilityIdentifier(confirmIdentifier)
        } else {
            Button(action: onConfirm) {
                Text(verbatim: confirmTitle)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(CYPrimaryButtonStyle(isFullWidth: true, isLoading: isConfirmLoading))
            .cyOptionalAccessibilityIdentifier(confirmIdentifier)
        }
    }
}

private struct CYModalOverlayModifier<ModalContent: View>: ViewModifier {
    let isPresented: Bool
    let modalContent: () -> ModalContent
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if isPresented {
                    modalContent()
                }
            }
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isPresented)
    }
}

private extension View {
    @ViewBuilder
    func cyOptionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier {
            accessibilityIdentifier(identifier)
        } else {
            self
        }
    }
}

public extension View {
    /// Presents a DesignSystem modal panel (`CYModal`, `CYPromptModal`) over the view with reduced-motion support.
    func cyModalOverlay<ModalContent: View>(
        isPresented: Bool,
        @ViewBuilder content: @escaping () -> ModalContent
    ) -> some View {
        modifier(CYModalOverlayModifier(isPresented: isPresented, modalContent: content))
    }
}
