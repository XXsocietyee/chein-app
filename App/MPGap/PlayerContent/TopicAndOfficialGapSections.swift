import SwiftUI

/// `PC-C-4-2` (Official event leaderboard), `PC-B-4-2`/`B-4-4` (Topic pricing extras),
/// and `PC-B-2-3` (Merchant host workbench commands, owner-gated).

public struct OfficialEventLeaderboardSection: View {
    public let rows: [OfficialEventLeaderboardRow]
    public let chipText: String
    public let myRank: Int?
    public let isFinal: Bool
    @Environment(\.locale) private var locale

    public init(rows: [OfficialEventLeaderboardRow], chipText: String = "", myRank: Int? = nil, isFinal: Bool = false) {
        self.rows = rows
        self.chipText = chipText
        self.myRank = myRank
        self.isFinal = isFinal
    }

    /// Catalog chip when the key resolves. Otherwise the Chinese `chipText` from the payload.
    private var chip: String? {
        let trimmed = chipText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let myRank, myRank > 0 else { return trimmed.isEmpty ? nil : trimmed }
        let key = isFinal ? "official.leaderboard.final" : "official.leaderboard.provisional"
        let localized = appLocalized(String.LocalizationValue(key), locale: locale)
        if localized != key {
            return String(format: localized, locale: locale, arguments: [String(myRank)])
        }
        return trimmed.isEmpty ? nil : trimmed
    }

    public var body: some View {
        if !rows.isEmpty || chip != nil {
            Section {
                ForEach(rows) { row in
                    HStack {
                        Text("#\(row.rank)")
                            .cyText(.numericBody, monospacedDigit: true)
                            .foregroundStyle(row.isSelf ? Color.accentColor : Color.secondary)
                            .frame(width: 40, alignment: .leading)
                        Text(row.displayName)
                            .cyText(.bodyMedium)
                            .foregroundStyle(.primary)
                        Spacer()
                        Text(row.scoreText)
                            .cyText(.numericBody, monospacedDigit: true)
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                HStack {
                    Text("official.leaderboard.title")
                    Spacer()
                    if let chip {
                        Text(verbatim: chip)
                            .cyText(.meta, monospacedDigit: true)
                            .foregroundStyle(.tint)
                            .accessibilityIdentifier("official.leaderboard.chip")
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
    /// Unmounted. Live merchant-content writes go through `MerchantContentWriteApproval` (MP-first default on).
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
                                .foregroundStyle(.secondary)
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
