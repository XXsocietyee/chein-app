import SwiftUI

/// Mount hook for `ClubGovernanceViews` / `MerchantLedgerSettlementOverview` (`CLB-G17`, `MC-G04`):
/// Displays 自由探索结算（参考） rows; money write (`标记已结清`) stays gated behind `allowsMoneyWrite` (TEST-only).
public struct ClubGapFEReferenceSettlementSection: View {
    public let items: [FEReferenceSettlementItem]
    public let allowsMoneyWrite: Bool
    public let onMarkSettled: (Int) -> Void
    public let onDispute: (Int) -> Void

    public init(
        items: [FEReferenceSettlementItem],
        allowsMoneyWrite: Bool = false,
        onMarkSettled: @escaping (Int) -> Void,
        onDispute: @escaping (Int) -> Void
    ) {
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
                            if allowsMoneyWrite && item.canSettle {
                                Button(FEReferenceSettlementCopy.markSettled) {
                                    onMarkSettled(item.id)
                                }
                                .buttonStyle(CYPillButtonStyle(style: .primary, fullWidth: false, compact: true))
                            }
                            if item.canDispute {
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
    }
}
