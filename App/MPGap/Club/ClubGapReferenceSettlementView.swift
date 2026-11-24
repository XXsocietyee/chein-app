import SwiftUI

/// Mount hook for `ClubGovernanceViews` / `MerchantLedgerSettlementOverview` (`CLB-G17`, `MC-G04`, `F-C20`):
/// Displays 自由探索结算（参考） rows; `标记已结清` is payer-only, settles a group (`[Int]`) with an
/// optional 转账凭证号 confirmation alert, and stays gated behind `allowsMoneyWrite` (TEST-only).
public struct ClubGapFEReferenceSettlementSection: View {
    public let role: FEReferenceSettlementRole
    public let items: [FEReferenceSettlementItem]
    public let allowsMoneyWrite: Bool
    public let onMarkSettled: (_ ids: [Int], _ voucherNo: String?) -> Void
    public let onDispute: (Int) -> Void

    @State private var settlingIDs: [Int]?
    @State private var voucherNo: String = ""

    public init(
        role: FEReferenceSettlementRole = .payer,
        items: [FEReferenceSettlementItem],
        allowsMoneyWrite: Bool = false,
        onMarkSettled: @escaping (_ ids: [Int], _ voucherNo: String?) -> Void,
        onDispute: @escaping (Int) -> Void
    ) {
        self.role = role
        self.items = items
        self.allowsMoneyWrite = allowsMoneyWrite
        self.onMarkSettled = onMarkSettled
        self.onDispute = onDispute
    }

    public var body: some View {
        Section {
            if items.isEmpty {
                CYEmptyState(systemImage: "doc.text", verbatimTitle: FEReferenceSettlementCopy.emptyTitle)
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: CYSpacing.xs) {
                        HStack {
                            Text(verbatim: item.title)
                                .cyText(.cardTitle)
                                .foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            CYStatusChip(verbatim: item.statusText, tone: .neutral)
                        }
                        if let counterpart = item.counterpartName, !counterpart.isEmpty {
                            Text(verbatim: counterpart)
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                        HStack {
                            Text(verbatim: item.amountText)
                                .cyText(.body)
                                .foregroundStyle(CYColor.textPrimary)
                            Spacer()
                            if role == .payer && allowsMoneyWrite && item.canSettle {
                                Button(FEReferenceSettlementCopy.markSettled) {
                                    voucherNo = ""
                                    settlingIDs = [item.id]
                                }
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                            }
                            if role == .merchant && item.canDispute {
                                Button(FEReferenceSettlementCopy.dispute) {
                                    onDispute(item.id)
                                }
                                .buttonStyle(CYPillButtonStyle(style: .secondary, fullWidth: false, compact: true))
                            }
                        }
                    }
                    .padding(.vertical, CYSpacing.xs)
                }
            }
        } header: {
            Text(verbatim: FEReferenceSettlementCopy.sectionTitle).cyText(.sectionTitle)
        } footer: {
            if !allowsMoneyWrite {
                Text(verbatim: FEReferenceSettlementCopy.moneyGateNote).cyText(.meta)
            }
        }
        .alert(
            "标记已线下结清？",
            isPresented: Binding(
                get: { settlingIDs != nil },
                set: { if !$0 { settlingIDs = nil } }
            )
        ) {
            TextField("转账凭证号（选填）", text: $voucherNo)
            Button("取消", role: .cancel) { settlingIDs = nil }
            Button(FEReferenceSettlementCopy.markSettled) {
                if let ids = settlingIDs {
                    let trimmed = voucherNo.trimmingCharacters(in: .whitespacesAndNewlines)
                    onMarkSettled(ids, trimmed.isEmpty ? nil : trimmed)
                }
                settlingIDs = nil
            }
        }
    }
}
