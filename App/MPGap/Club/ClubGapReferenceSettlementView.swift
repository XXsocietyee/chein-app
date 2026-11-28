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
    @Environment(\.locale) private var locale
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
                ContentUnavailableView(FEReferenceSettlementCopy.emptyTitle, systemImage: "doc.text")
            } else {
                ForEach(items) { item in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(verbatim: item.title)
                                .font(.headline)
                            Spacer()
                            Text(verbatim: item.statusText)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        if let counterpart = item.counterpartName, !counterpart.isEmpty {
                            Text(verbatim: counterpart)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Text(verbatim: LocaleDisplay.yuanAmounts(in: item.amountText, locale: locale))
                                .monospacedDigit()
                            Spacer()
                            if role == .payer && allowsMoneyWrite && item.canSettle {
                                Button(FEReferenceSettlementCopy.markSettled) {
                                    voucherNo = ""
                                    settlingIDs = [item.id]
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                            if role == .merchant && item.canDispute {
                                Button(FEReferenceSettlementCopy.dispute) {
                                    onDispute(item.id)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                    }
                }
            }
        } header: {
            Text(verbatim: FEReferenceSettlementCopy.sectionTitle)
        } footer: {
            if !allowsMoneyWrite {
                Text(verbatim: FEReferenceSettlementCopy.moneyGateNote)
            }
        }
        .alert(
            "标记已线下结清？",
            isPresented: Binding(
                get: { settlingIDs != nil },
                set: { if !$0 { settlingIDs = nil } }
            )
        ) {
            TextField("club.settlement.voucherOptional", text: $voucherNo)
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
