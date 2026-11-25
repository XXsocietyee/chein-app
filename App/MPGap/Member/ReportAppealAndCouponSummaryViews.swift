import SwiftUI

/// `PLY-29-4` (Report appeal 6-phase sheet), `MKT-10-1` (Merchant coupon summary tiles),
/// and `MKT-5-3` (Platform-pass cancel/refund owner-gated sheet).

public struct ReportAppealSheetView: View {
    public let phase: ReportAppealSheetPhase
    @Binding public var reason: String
    public var onToConfirm: () -> Void
    public var onBackToForm: () -> Void
    public var onSubmit: () -> Void
    public var onClose: () -> Void

    public init(
        phase: ReportAppealSheetPhase,
        reason: Binding<String>,
        onToConfirm: @escaping () -> Void,
        onBackToForm: @escaping () -> Void,
        onSubmit: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.phase = phase
        self._reason = reason
        self.onToConfirm = onToConfirm
        self.onBackToForm = onBackToForm
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text(sheetTitle), style: .player, onClose: onClose)
            Form {
                switch phase {
                case .form:
                    Section {
                        TextEditor(text: $reason)
                            .frame(minHeight: 140)
                            .onChange(of: reason) { _, newValue in
                                let clamped = ReportAppealValidator.clamp(newValue)
                                if clamped != newValue { reason = clamped }
                            }
                    } header: {
                        Text("reportAppeal.reasonLabel")
                    } footer: {
                        HStack {
                            Text("reportAppeal.reasonPlaceholder")
                                .cyText(.meta)
                            Spacer()
                            Text("\(reason.count)/\(ReportAppealValidator.maxReasonLength)")
                                .cyText(.meta, monospacedDigit: true)
                        }
                    }
                    Section {
                        Button("reportAppeal.next", action: onToConfirm)
                            .buttonStyle(.cyPrimary)
                            .frame(maxWidth: .infinity)
                            .disabled(!ReportAppealValidator.isValid(reason))
                    }

                case .confirm:
                    Section {
                        Text("reportAppeal.confirmNotice")
                            .cyText(.bodyCompact)
                        Text(reason)
                            .cyText(.body)
                    }
                    Section {
                        Button("reportAppeal.confirmSubmit", action: onSubmit)
                            .buttonStyle(.cyPrimary)
                            .frame(maxWidth: .infinity)
                        Button("reportAppeal.backToEdit", action: onBackToForm)
                            .frame(maxWidth: .infinity)
                    }

                case .busy:
                    Section {
                        HStack(spacing: CYSpacing.sm) {
                            ProgressView()
                            Text("reportAppeal.submitting")
                                .cyText(.body)
                        }
                    }

                case .ok(let receiptText):
                    Section {
                        if let receiptText, !receiptText.isEmpty {
                            Text(receiptText).cyText(.bodyCompact)
                        }
                        Text("reportAppeal.okDetail")
                            .cyText(.body)
                        Button("common.done", action: onClose)
                            .buttonStyle(.cyPrimary)
                            .frame(maxWidth: .infinity)
                    }

                case .fail(let message):
                    Section {
                        Text(message)
                            .cyText(.body)
                        Button("common.done", action: onClose)
                            .buttonStyle(.cyPrimary)
                            .frame(maxWidth: .infinity)
                    }

                case .unknown:
                    Section {
                        Text("reportAppeal.unknownNotice")
                            .cyText(.body)
                        Button("reportAppeal.retry", action: onSubmit)
                            .buttonStyle(.cyPrimary)
                            .frame(maxWidth: .infinity)
                        Button("reportAppeal.checkLater", action: onClose)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var sheetTitle: LocalizedStringKey {
        switch phase {
        case .ok: return "reportAppeal.title.ok"
        case .fail: return "reportAppeal.title.fail"
        case .unknown: return "reportAppeal.title.unknown"
        case .form, .confirm, .busy: return "reportAppeal.title.form"
        }
    }
}

public struct MerchantCouponSummaryTilesView: View {
    public let summary: MerchantCouponSummary

    public init(summary: MerchantCouponSummary) {
        self.summary = summary
    }

    public var body: some View {
        HStack(spacing: CYSpacing.sm) {
            statCard(title: "couponSummary.claimed", value: summary.totalClaimed)
            statCard(title: "couponSummary.redeemed", value: summary.totalRedeemed)
        }
    }

    private func statCard(title: LocalizedStringKey, value: Int) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(title)
                .cyText(.label)
                .foregroundStyle(CYColor.textSecondary)
            Text("\(value)")
                .cyText(.dataXL, monospacedDigit: true)
                .foregroundStyle(CYColor.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.md)
        .background(CYColor.bgSurface)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
}

public struct PlatformPassOrderCancelRefundSheetView: View {
    public let kind: PassOrderActionKind
    /// Owner-gated: money writes remain disabled in Release.
    public let writesEnabled: Bool
    @State private var reason = ""
    public var onSubmit: (String) -> Void
    public var onClose: () -> Void

    private let maxLength = 200

    public init(
        kind: PassOrderActionKind,
        writesEnabled: Bool = false,
        onSubmit: @escaping (String) -> Void,
        onClose: @escaping () -> Void
    ) {
        self.kind = kind
        self.writesEnabled = writesEnabled
        self.onSubmit = onSubmit
        self.onClose = onClose
    }

    public var body: some View {
        VStack(spacing: 0) {
            CYSheetHeader(title: Text(verbatim: kind.title), style: .player, onClose: onClose)
            Form {
                if kind == .refundApply {
                    Section {
                        TextEditor(text: $reason)
                            .frame(minHeight: 100)
                            .onChange(of: reason) { _, newValue in
                                if newValue.count > maxLength {
                                    reason = String(newValue.prefix(maxLength))
                                }
                            }
                    } header: {
                        Text("passOrder.refund.reasonTitle")
                    } footer: {
                        HStack {
                            Spacer()
                            Text("\(reason.count)/\(maxLength)")
                                .cyText(.meta, monospacedDigit: true)
                        }
                    }
                }
                Section {
                    Button(kind.title, role: .destructive) {
                        onSubmit(reason.trimmingCharacters(in: .whitespacesAndNewlines))
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(!writesEnabled || (kind == .refundApply && reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty))
                } footer: {
                    if !writesEnabled {
                        Text("passOrder.actionGated")
                            .cyText(.meta)
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}
