import SwiftUI

/// `PC-C-4-2` (Official event leaderboard), `PC-B-4-2`/`B-4-4` (Topic pricing extras),
/// and `PC-B-2-3` (Merchant host workbench commands, owner-gated).

public struct OfficialEventLeaderboardSection: View {
    public let rows: [OfficialEventLeaderboardRow]
    public let myRank: Int?

    public init(rows: [OfficialEventLeaderboardRow], myRank: Int? = nil) {
        self.rows = rows
        self.myRank = myRank
    }

    public var body: some View {
        if !rows.isEmpty {
            Section {
                ForEach(rows) { row in
                    HStack {
                        Text("#\(row.rank)")
                            .cyText(.numericBody, monospacedDigit: true)
                            .foregroundStyle(row.isSelf ? CYColor.brand : CYColor.textSecondary)
                            .frame(width: 40, alignment: .leading)
                        Text(row.displayName)
                            .cyText(.bodyMedium)
                            .foregroundStyle(CYColor.textPrimary)
                        Spacer()
                        Text(row.scoreText)
                            .cyText(.numericBody, monospacedDigit: true)
                            .foregroundStyle(CYColor.textSecondary)
                    }
                }
            } header: {
                HStack {
                    Text("official.leaderboard.title")
                    Spacer()
                    if let myRank {
                        Text("暂列第 \(myRank) 名")
                            .cyText(.meta, monospacedDigit: true)
                            .foregroundStyle(CYColor.brand)
                    }
                }
            }
        }
    }
}

public struct TopicPricingGapSection: View {
    @Binding public var ticketFields: [TopicPricingPerTicketField]
    public let extraStatus: TopicPricingExtraStatus
    public let canConfirmPricing: Bool

    public init(
        ticketFields: Binding<[TopicPricingPerTicketField]>,
        extraStatus: TopicPricingExtraStatus,
        canConfirmPricing: Bool = false
    ) {
        self._ticketFields = ticketFields
        self.extraStatus = extraStatus
        self.canConfirmPricing = canConfirmPricing
    }

    public var body: some View {
        Group {
            if !ticketFields.isEmpty {
                Section("topicPricing.perTicket.title") {
                    ForEach($ticketFields) { $field in
                        HStack {
                            Text(field.ticketName)
                                .cyText(.bodyCompact)
                            Spacer()
                            TextField("0", text: $field.priceText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .cyText(.numericBody, monospacedDigit: true)
                                .disabled(!canConfirmPricing)
                        }
                    }
                }
            }

            if extraStatus.saleStatusText != nil || extraStatus.settlementPendingText != nil || extraStatus.platformFeeRatePercent != nil {
                Section("topicPricing.extra.title") {
                    if let sale = extraStatus.saleStatusText {
                        LabeledContent("topicPricing.saleStatus", value: sale)
                            .cyText(.bodyCompact)
                    }
                    if let pending = extraStatus.settlementPendingText {
                        LabeledContent("topicPricing.settlementPending", value: pending)
                            .cyText(.bodyCompact)
                    }
                    if let fee = extraStatus.platformFeeRatePercent {
                        LabeledContent("topicPricing.feeRate", value: String(format: "%.1f%%", fee))
                            .cyText(.numericBody, monospacedDigit: true)
                    }
                }
            }
        }
    }
}

public struct MerchantHostWorkbenchSection: View {
    /// Owner-gated: `MerchantContentWriteApproval` stays false in Release.
    public let writesEnabled: Bool
    public var onAction: (MerchantHostWorkbenchAction) -> Void = { _ in }

    public init(writesEnabled: Bool = false, onAction: @escaping (MerchantHostWorkbenchAction) -> Void = { _ in }) {
        self.writesEnabled = writesEnabled
        self.onAction = onAction
    }

    public var body: some View {
        Section {
            ForEach(MerchantHostWorkbenchAction.allCases) { action in
                Button {
                    onAction(action)
                } label: {
                    HStack {
                        Text(action.title)
                            .cyText(.body)
                        Spacer()
                        if !writesEnabled {
                            Text("merchantHost.gated")
                                .cyText(.meta)
                                .foregroundStyle(CYColor.textSecondary)
                        }
                    }
                }
                .disabled(!writesEnabled)
            }
        } header: {
            Text("merchantHost.workbench.title")
        } footer: {
            if !writesEnabled {
                Text("merchantHost.workbench.gatedFooter")
                    .cyText(.meta)
            }
        }
    }
}
