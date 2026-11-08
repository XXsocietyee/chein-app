import SwiftUI

/// Bottom-sheet confirmation. Not a centered alert.
public struct CYConfirmSheet: View {
    private let title: String
    private let message: String
    private let confirmTitle: String
    private let onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    public init(title: String, message: String, confirmTitle: String, onConfirm: @escaping () -> Void) {
        self.title = title
        self.message = message
        self.confirmTitle = confirmTitle
        self.onConfirm = onConfirm
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(title)
                .font(CYTypography.sheetTitle)
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
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
                Button(action: onConfirm) {
                    Text(confirmTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.cyPrimary)
                Button("action.cancel") { dismiss() }
                    .buttonStyle(.cySecondary(fullWidth: true))
            }
            .padding(CYSpacing.lg)
            .background(CYColor.bgElevated)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
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
