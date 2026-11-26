import SwiftUI

/// The exact pending ID is captured when review opens. A later result, dismissal,
/// owner change or disabled authority cannot turn an old confirmation into a send.
@MainActor struct OrdinaryIMSendReceiptRecoveryView: View {
    let clientMessageID: String
    let state: OrdinaryIMReceiptReadState
    let canRead: Bool
    let canRetry: Bool
    let read: () -> Void
    let resend: (String) -> Void
    @State private var reviewedID: String?
    @State private var showingConfirmation = false
    @Environment(\.locale) private var locale
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s2) {
            if state == .reading {
                CYLoadingStateView(rows: 1).accessibilityLabel(Text("ordinary.receipt.reading", tableName: "OrdinaryIMSendReceipt"))
            } else {
                CYStatusChip(verbatim: String(localized: state == .notFound ? "ordinary.receipt.notFound" : "ordinary.receipt.pending", table: "OrdinaryIMSendReceipt"),
                             tone: .warning, systemImage: "clock.arrow.circlepath")
                CYPillButton("ordinary.receipt.read", style: .secondary, tableName: "OrdinaryIMSendReceipt") { read() }
                    .disabled(!canRead).accessibilityIdentifier("ordinary.receipt.read")
            }
            if state == .notFound {
                CYPillButton("ordinary.receipt.reviewRetry", style: .secondary, tableName: "OrdinaryIMSendReceipt") {
                    guard canRetry else { return }
                    reviewedID = clientMessageID; showingConfirmation = true
                }
                    .disabled(!canRetry).accessibilityIdentifier("ordinary.receipt.reviewRetry")
            }
        }
        .cySheet(isPresented: $showingConfirmation, onDismiss: { reviewedID = nil }) {
            CYConfirmSheet(
                title: String(localized: LocalizedStringResource("ordinary.receipt.confirmTitle", table: "OrdinaryIMSendReceipt", locale: locale)),
                message: String(localized: LocalizedStringResource("ordinary.receipt.confirmHint", table: "OrdinaryIMSendReceipt", locale: locale)),
                confirmTitle: String(localized: LocalizedStringResource("ordinary.receipt.confirm", table: "OrdinaryIMSendReceipt", locale: locale)),
                cancelTitle: String(localized: LocalizedStringResource("ordinary.receipt.cancel", table: "OrdinaryIMSendReceipt", locale: locale)),
                onCancel: { reviewedID = nil }
            ) {
                guard canRetry, state == .notFound, let reviewedID, reviewedID == clientMessageID else { return }
                self.reviewedID = nil; resend(reviewedID)
            }
            .cyDomainSheet(detents: [.peek, .half])
        }
        .onChange(of: clientMessageID) { _, _ in clear() }
        .onChange(of: canRetry) { _, allowed in if !allowed { clear() } }
        .onChange(of: state) { _, state in if state != .notFound { clear() } }
        .onDisappear { clear() }
    }
    private func clear() { reviewedID = nil; showingConfirmation = false }
}
