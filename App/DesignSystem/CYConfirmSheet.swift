import SwiftUI

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

    @Environment(\.dismiss) private var dismiss

    public init(title: String, message: String, confirmTitle: String,
                isDestructive: Bool = false, confirmIdentifier: String? = nil,
                cancelIdentifier: String? = nil, titleIdentifier: String? = nil,
                onConfirm: @escaping () -> Void) {
        self.isDestructive = isDestructive
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

    @ViewBuilder private func styled(_ label: some View) -> some View {
        if isDestructive {
            label.buttonStyle(.cyDestructive)
        } else {
            label.buttonStyle(.cyPrimary)
        }
    }

    public var body: some View {
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
            Spacer(minLength: CYSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(CYSpacing.lg)
        .background(CYColor.bgElevated.ignoresSafeArea())
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: CYSpacing.sm) {
                confirmButton
                Button("action.cancel") { dismiss() }
                    .buttonStyle(.cySecondary(fullWidth: true))
                    .cyOptionalAccessibilityIdentifier(cancelIdentifier)
            }
            .padding(CYSpacing.lg)
            .background(CYColor.bgElevated)
        }
        .presentationDetents([.medium, .large])
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
