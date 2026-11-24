import SwiftUI

/// One icon row inside the consequence box of a `CYConfirmSheet`.
public struct CYConfirmConsequence: Identifiable {
    public let id = UUID()
    public let systemImage: String
    public let text: String
    public init(systemImage: String, text: String) { self.systemImage = systemImage; self.text = text }
}

/// Bottom-sheet confirmation. Not a centered alert.
public struct CYConfirmSheet: View {
    private let title: String
    private let message: String
    private let confirmTitle: String
    private let cancelTitle: String?
    private let onCancel: (() -> Void)?
    private let onConfirm: () -> Void
    private let isDestructive: Bool
    private let confirmDisabled: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let titleIdentifier: String?
    private let consequences: [CYConfirmConsequence]
    /// Join only: the sheet itself plays a stamp seal and lantern burst before it dismisses.
    private let showsJoinReward: Bool

    @Environment(\.dismiss) private var dismiss
    @QuestifyReduceMotion private var reduceMotion
    @State private var rewarding = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24

    public init(title: String, message: String, confirmTitle: String,
                cancelTitle: String? = nil,
                isDestructive: Bool = false, confirmDisabled: Bool = false,
                confirmIdentifier: String? = nil,
                cancelIdentifier: String? = nil, titleIdentifier: String? = nil,
                consequences: [CYConfirmConsequence] = [],
                showsJoinReward: Bool = false,
                onCancel: (() -> Void)? = nil,
                onConfirm: @escaping () -> Void) {
        self.isDestructive = isDestructive
        self.confirmDisabled = confirmDisabled
        self.consequences = consequences
        self.showsJoinReward = showsJoinReward && !isDestructive
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.titleIdentifier = titleIdentifier
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.cancelTitle = cancelTitle
        self.onCancel = onCancel
        self.onConfirm = onConfirm
    }

    @ViewBuilder private var confirmButton: some View {
        let label = Button(action: confirm) {
            Text(confirmTitle).frame(maxWidth: .infinity)
        }
        .disabled(rewarding || confirmDisabled)
        if let confirmIdentifier {
            styled(label).accessibilityIdentifier(confirmIdentifier)
        } else {
            styled(label)
        }
    }

    @ViewBuilder private var cancelButton: some View {
        Button {
            onCancel?()
            dismiss()
        } label: {
            if let cancelTitle {
                Text(cancelTitle).frame(maxWidth: .infinity)
            } else {
                Text("action.cancel").frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(.cySecondary(fullWidth: true))
        .pageTemplateControl(label: cancelTitle.map { Text($0) } ?? Text("action.cancel"), traits: .isButton)
        .cyOptionalAccessibilityIdentifier(cancelIdentifier)
    }

    @ViewBuilder private func styled(_ label: some View) -> some View {
        if isDestructive {
            label.buttonStyle(CYDestructiveButtonStyle(isFullWidth: true))
                .pageTemplateControl(label: Text(verbatim: confirmTitle), traits: .isButton)
        } else {
            label.buttonStyle(CYPrimaryButtonStyle(isFullWidth: true))
                .pageTemplateControl(label: Text(verbatim: confirmTitle), traits: .isButton)
        }
    }

    public var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(title)
                .cyText(.sheetTitle)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .cyOptionalAccessibilityIdentifier(titleIdentifier)
            if !message.isEmpty {
                Text(message)
                    .cyText(.body)
                    .foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if !consequences.isEmpty {
                VStack(alignment: .leading, spacing: CYSpacing.md) {
                    ForEach(consequences) { item in
                        HStack(alignment: .top, spacing: CYSpacing.sm) {
                            Image(systemName: item.systemImage)
                                .font(CYTypography.body)
                                .foregroundStyle(CYColor.textSecondary)
                                .frame(width: iconWidth)
                                .accessibilityHidden(true)
                            Text(item.text)
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.md)
                .background(CYColor.sheetCard, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("confirm.consequences")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(CYSpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(CYColor.sheetGlass.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Group {
                if consequences.isEmpty {
                    // Visual order is top to bottom: confirm, then cancel.
                    VStack(spacing: CYSpacing.sm) {
                        confirmButton.pageTemplateReadingOrder(2)
                        cancelButton.pageTemplateReadingOrder(1)
                    }
                } else {
                    // Cancel left, confirm right. The stacked fallback keeps confirm above cancel.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: CYSpacing.sm) {
                            cancelButton.pageTemplateReadingOrder(2)
                            confirmButton.pageTemplateReadingOrder(1)
                        }
                        VStack(spacing: CYSpacing.sm) {
                            confirmButton.pageTemplateReadingOrder(2)
                            cancelButton.pageTemplateReadingOrder(1)
                        }
                    }
                }
            }
            .padding(CYSpacing.lg)
            .background(CYColor.sheetGlass)
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : (consequences.isEmpty ? [.fraction(0.36), .large] : [.medium, .large]))
        .presentationDragIndicator(.visible)
        .overlay { if rewarding { joinReward } }
    }

    private func confirm() {
        guard showsJoinReward else { onConfirm(); return }
        withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance) { rewarding = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 180 : 720))
            onConfirm()
        }
    }

    private var joinReward: some View {
        ZStack {
            Circle()
                .fill(LinearGradient(colors: [CYColor.brand, CYColor.brandStrong], startPoint: .top, endPoint: .bottom))
                .frame(width: 72, height: 72)
                .shadow(color: CYColor.brand.opacity(0.45), radius: 16)
                .overlay {
                    Circle().strokeBorder(CYColor.textOnAccent.opacity(0.7), lineWidth: 3).padding(12)
                    Image(systemName: "checkmark")
                        .font(.system(.title2, design: .rounded).weight(.heavy))
                        .foregroundStyle(CYColor.textOnAccent)
                }
                .transition(reduceMotion ? .opacity : .scale(scale: 0.55).combined(with: .opacity))
            CYBurst(origin: .center, count: 32, duration: 0.9, style: .dust, reach: 140)
                .frame(width: 200, height: 200)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension View {
    @ViewBuilder func cyOptionalAccessibilityIdentifier(_ identifier: String?) -> some View {
        if let identifier { accessibilityIdentifier(identifier) } else { self }
    }
}

#Preview("Player") {
    CYConfirmSheet(title: "Preview title", message: "Preview message for this confirmation.", confirmTitle: "Continue", onConfirm: {})
        .themeDomain(.player)
}

#Preview("Merchant") {
    CYConfirmSheet(title: "Preview title", message: "Preview message for this confirmation.", confirmTitle: "Continue", onConfirm: {})
        .themeDomain(.merchant)
}
