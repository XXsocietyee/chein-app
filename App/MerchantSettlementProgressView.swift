import SwiftUI
import UIKit

/// The write dependency is injected in tests; no test touches the real clipboard.
@MainActor final class MerchantSettlementVoucherCopyModel: ObservableObject {
    @Published private(set) var busy = false
    @Published private(set) var messageKey: String?
    @Published private(set) var intentID = UUID()

    func invalidate() { intentID = UUID(); busy = false; messageKey = nil }

    func copy(_ displayed: MerchantSettlementProgress, intent: UUID, reader: any MerchantBusinessReading,
              currentSnapshot: () -> MerchantBusinessSnapshot?, write: (String) -> Void) async {
        guard intent == intentID, !busy, !Task.isCancelled else { return }
        let ticket = intentID
        messageKey = nil
        guard let scope = reader.scope, reader.isConfigured,
              let baseline = currentSnapshot(),
              Self.matches(baseline, displayed: displayed), displayed.voucherForCopy != nil else {
            messageKey = "merchant.settlementProgress.copyUnavailable"; return
        }
        let authorization = reader.authorizationGeneration
        busy = true
        defer { if intentID == ticket { busy = false } }
        do {
            // snapshot performs fresh access/me and the existing owned detail read.
            let latest = try await reader.snapshot(.batch(.init(displayed.batchID)))
            guard intentID == ticket, !Task.isCancelled,
                  reader.isConfigured, reader.scope == scope, reader.authorizationGeneration == authorization,
                  currentSnapshot() == baseline, latest.access == baseline.access,
                  Self.matches(latest, displayed: displayed),
                  let voucher = displayed.voucherForCopy else { throw MerchantBusinessFailure.stale }
            // No await between the final identity/intent checks and local write.
            write(voucher)
            messageKey = "merchant.settlementProgress.copied"
        } catch {
            guard intentID == ticket, !Task.isCancelled else { return }
            messageKey = "merchant.settlementProgress.copyUnavailable"
        }
    }
    private static func matches(_ snapshot: MerchantBusinessSnapshot, displayed: MerchantSettlementProgress) -> Bool {
        guard snapshot.access.allows("merchant:finance:read"),
              case .batch(let id) = snapshot.document.query, id.rawValue == displayed.batchID,
              let row = snapshot.document.rows.first(where: { $0.kind == .batch }),
              let value = try? MerchantSettlementProgress(record: row) else { return false }
        return value == displayed
    }
}

/// Hosted in the current authorized detail row. No independent navigation cache.
@MainActor struct MerchantSettlementProgressView: View {
    let progress: MerchantSettlementProgress
    let reader: any MerchantBusinessReading
    let currentSnapshot: () -> MerchantBusinessSnapshot?
    @StateObject private var copyModel = MerchantSettlementVoucherCopyModel()
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        let displayedIntent = copyModel.intentID
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text(LocalizedStringKey(progress.paymentKey)).cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                .accessibilityIdentifier("merchant.settlementProgress.status")
            Text(LocalizedStringKey(progress.invoiceKey)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
            if progress.amount.raw == nil {
                Text("merchant.settlementProgress.amountUnknown").cyText(.meta).foregroundStyle(CYColor.textSecondary)
            }
            if !progress.steps.isEmpty {
                Text("merchant.settlementProgress.title").cyText(.cardTitle).foregroundStyle(CYColor.textPrimary)
                ForEach(progress.steps) { step in
                    HStack(alignment: .top, spacing: CYSpacing.s2_5) {
                        Image(systemName: symbol(step.state))
                            .foregroundStyle(step.state == .done ? CYColor.successText : CYColor.textSecondary)
                            .accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: CYSpacing.xs) {
                            Text(LocalizedStringKey("merchant.settlementProgress.step." + step.id))
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                            Text(LocalizedStringKey("merchant.settlementProgress.stepState." + step.state.rawValue))
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                            if let time = step.timestamp {
                                MerchantSettlementTimestampText(raw: time)
                                    .cyText(.meta)
                                    .monospacedDigit()
                                    .foregroundStyle(CYColor.textSecondary)
                            }
                        }
                    }.fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("merchant.settlementProgress.step." + step.id)
                }
            }
            if let voucher = progress.voucherForCopy {
                // MC8-08-2 (batch-detail/index.wxml:17): 打款凭证 {payVoucherNo} is visible, with the copy action under it.
                LabeledContent("merchantR8.batch.voucherLabel") {
                    Text(verbatim: voucher).cyText(.body).monospacedDigit().textSelection(.enabled)
                }
                .accessibilityIdentifier("merchant.settlementProgress.voucher")
                CYPillButton("merchant.settlementProgress.copyVoucher", style: .secondary, systemImage: "doc.on.doc") {
                    Task { await copyModel.copy(progress, intent: displayedIntent, reader: reader, currentSnapshot: currentSnapshot, write: Self.writeLocally) }
                }
                .frame(minHeight: 44)
                .disabled(copyModel.busy || scenePhase != .active)
                .accessibilityIdentifier("merchant.settlementProgress.copyVoucher")
                if copyModel.busy { ProgressView("merchant.settlementProgress.checking").cyText(.meta) }
            }
            if let key = copyModel.messageKey {
                Text(LocalizedStringKey(key)).cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .accessibilityIdentifier("merchant.settlementProgress.copyStatus")
            }
        }
        .onChange(of: progress) { _, _ in copyModel.invalidate() }
        .onChange(of: ObjectIdentifier(reader)) { _, _ in copyModel.invalidate() }
        .onChange(of: reader.scope) { _, _ in copyModel.invalidate() }
        .onChange(of: reader.authorizationGeneration) { _, _ in copyModel.invalidate() }
        .onChange(of: reader.isConfigured) { _, _ in copyModel.invalidate() }
        .onChange(of: scenePhase) { _, _ in copyModel.invalidate() }
        .onDisappear { copyModel.invalidate() }
    }
    private static func writeLocally(_ text: String) {
        UIPasteboard.general.setItems([["public.utf8-plain-text": text]], options: [.localOnly: true, .expirationDate: Date().addingTimeInterval(120)])
    }
    private func symbol(_ state: MerchantSettlementProgress.StepState) -> String {
        switch state { case .done: return "checkmark.circle.fill"; case .current: return "circle.inset.filled"
        case .pending: return "circle"; case .paused: return "pause.circle" }
    }
}

/// Shared by the batch field and timeline so neither retains bare Beijing text.
/// Re-render the same instant on phone-zone changes; this is not a deadline.
struct MerchantSettlementTimestampText: View {
    let raw: String?
    @State private var phoneTimeZone = TimeZone.current
    var body: some View {
        Group {
            if let date = MerchantSettlementProgress.paymentTimestamp(raw) {
                Text(verbatim: MerchantAftercareTime.event(date, phoneTimeZone: phoneTimeZone))
            } else {
                Text("merchant.settlementProgress.timeUnknown").foregroundStyle(CYColor.textTertiary)
            }
        }
        .onAppear { phoneTimeZone = .current }
        .onReceive(NotificationCenter.default.publisher(for: .NSSystemTimeZoneDidChange)) { _ in
            phoneTimeZone = .current
        }
    }
}
