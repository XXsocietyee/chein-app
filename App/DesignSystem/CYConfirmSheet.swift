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
    private let onConfirm: () -> Void
    private let isDestructive: Bool
    private let confirmIdentifier: String?
    private let cancelIdentifier: String?
    private let titleIdentifier: String?
    private let consequences: [CYConfirmConsequence]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .body) private var iconWidth: CGFloat = 24

    public init(title: String, message: String, confirmTitle: String,
                isDestructive: Bool = false, confirmIdentifier: String? = nil,
                cancelIdentifier: String? = nil, titleIdentifier: String? = nil,
                consequences: [CYConfirmConsequence] = [],
                onConfirm: @escaping () -> Void) {
        self.isDestructive = isDestructive
        self.consequences = consequences
        self.confirmIdentifier = confirmIdentifier
        self.cancelIdentifier = cancelIdentifier
        self.titleIdentifier = titleIdentifier
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
    }

    @ViewBuilder private var confirmButton: some View {
        let label = Button(action: onConfirm) {
            Text(confirmTitle).frame(maxWidth: .infinity)
        }
        if let confirmIdentifier {
            styled(label).accessibilityIdentifier(confirmIdentifier)
        } else {
            styled(label)
        }
    }

    private var cancelButton: some View {
        Button("action.cancel") { dismiss() }.buttonStyle(.cySecondary(fullWidth: true))
            .cyOptionalAccessibilityIdentifier(cancelIdentifier)
    }

    @ViewBuilder private func styled(_ label: some View) -> some View {
        if isDestructive && !consequences.isEmpty {
            // Solid red, matching the mini-program quit dialog.
            label.buttonStyle(.plain)
                .font(CYTypography.label)
                .foregroundStyle(Color.white)
                .padding(.vertical, CYSpacing.sm)
                .frame(maxWidth: .infinity, minHeight: CYSpacing.minTouchTarget)
                .background(CYColor.dangerSolid, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        } else if isDestructive {
            label.buttonStyle(.cyDestructive)
        } else {
            label.buttonStyle(.cyPrimary)
        }
    }

    public var body: some View {
        ScrollView {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(title)
                .font(CYTypography.sheetTitle)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .cyOptionalAccessibilityIdentifier(titleIdentifier)
            Text(message)
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
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
                                .font(CYTypography.body)
                                .foregroundStyle(CYColor.textPrimary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(CYSpacing.md)
                .background(CYColor.bgPage, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                .accessibilityIdentifier("confirm.consequences")
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(CYSpacing.lg)
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(CYColor.bgElevated.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            Group {
                if consequences.isEmpty {
                    VStack(spacing: CYSpacing.sm) {
                        confirmButton
                        Button("action.cancel") { dismiss() }
                            .buttonStyle(.cySecondary(fullWidth: true))
                    }
                } else {
                    // Cancel left, destructive right (mini-program dialog); stacks when the type is large.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: CYSpacing.sm) { cancelButton; confirmButton }
                        VStack(spacing: CYSpacing.sm) { confirmButton; cancelButton }
                    }
                }
            }
            .padding(CYSpacing.lg)
            .background(CYColor.bgElevated)
        }
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : (consequences.isEmpty ? [.fraction(0.36), .large] : [.medium, .large]))
        .presentationDragIndicator(.visible)
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
