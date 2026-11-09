import SwiftUI

/// Pure presentation of verified original-request facts. This layer cannot grant a
/// channel, settle a pending UUID, or turn a historical event into current consent.
struct MarketingConsentOriginalPresentation {
    let locale: Locale
    func text(_ key: String) -> String {
        String(localized: LocalizedStringResource(String.LocalizationValue(stringLiteral: key),
                                                 table: "MarketingConsentOriginalPresentation", locale: locale))
    }
    func outcome(_ value: String) -> String { text(Self.outcomeKey(value)) }
    static func outcomeKey(_ value: String) -> String {
        switch value {
        case "RECORDED": return "marketingOriginal.outcome.recorded"
        case "NOT_OBSERVED": return "marketingOriginal.outcome.notObserved"
        default: return "marketingOriginal.outcome.unknown"
        }
    }
    func event(_ value: String?) -> String { text(Self.eventKey(value)) }
    static func eventKey(_ value: String?) -> String {
        switch value {
        case "OPT_IN": return "marketingOriginal.event.optIn"
        case "OPT_OUT": return "marketingOriginal.event.optOut"
        default: return "marketingOriginal.event.unknown"
        }
    }
    func channel(_ value: String) -> String { text(Self.channelKey(value)) }
    static func channelKey(_ value: String) -> String {
        switch value {
        case "IN_APP": return "marketingOriginal.channel.inApp"
        case "COUPON": return "marketingOriginal.channel.coupon"
        default: return "marketingOriginal.channel.unknown"
        }
    }
}

/// Shared by the original order shortcut and the existing Settings opt-out screen.
/// No navigation, task, lifecycle callback or mutation is introduced by this view.
/// pages/shezhi/marketing/index renders this receipt. Keys stay in MarketingConsentOriginalPresentation.
@MainActor struct MarketingConsentOriginalReceiptView: View {
    let receipt: MerchantMarketingConsentOriginalReceipt
    @Environment(\.locale) private var locale
    @Environment(\.cyPalette) private var palette
    private var presentation: MarketingConsentOriginalPresentation { .init(locale: locale) }

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("marketingOriginal.receipt.title", tableName: "MarketingConsentOriginalPresentation")
                .font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
            factRow(presentation.outcome(receipt.outcome), systemImage: "doc.text.magnifyingglass")
            factRow(presentation.channel(receipt.channel), systemImage: "megaphone")
            if receipt.recorded {
                factRow(presentation.event(receipt.eventType), systemImage: "checkmark.circle")
            } else {
                CYEmptyState(systemImage: "clock", resolved(presentation.text("marketingOriginal.receipt.unconfirmed")))
            }
            Text("marketingOriginal.receipt.historyOnly", tableName: "MarketingConsentOriginalPresentation")
                .font(CYTypography.meta)
                .foregroundStyle(palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            DisclosureGroup {
                reference("marketingOriginal.reference.request", value: shown(receipt.requestId))
                reference("marketingOriginal.reference.merchant", value: receipt.merchantRowId > 0 ? String(receipt.merchantRowId) : "—")
                if receipt.recorded, let id = receipt.consentId, id > 0 {
                    reference("marketingOriginal.reference.record", value: String(id))
                }
            } label: {
                Text("marketingOriginal.reference.title", tableName: "MarketingConsentOriginalPresentation")
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .privacySensitive()
        .accessibilityIdentifier("marketing.original.receipt.\(receipt.requestId)")
    }

    /// Kit rows take a `LocalizedStringKey` from the main catalog. These sentences already
    /// resolved against MarketingConsentOriginalPresentation, so they must not be looked up again.
    private func resolved(_ value: String) -> LocalizedStringKey { LocalizedStringKey(value) }

    private func shown(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "—" : trimmed
    }

    private func factRow(_ sentence: String, systemImage: String) -> some View {
        CYListRow(resolved(sentence), trailing: .none, card: true) {
            CYRowIcon(systemImage: systemImage)
        }
    }

    private func reference(_ key: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            CYListRow(resolved(presentation.text(key)), trailing: .none, card: false)
            Text(verbatim: shown(value))
                .font(CYTypography.numericBody)
                .foregroundStyle(palette.textPrimary)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .cyDomainCard(radius: CYRadius.md, padding: CYSpacing.lg)
        .accessibilityElement(children: .combine)
    }
}

#if DEBUG
private enum MarketingConsentOriginalPreviewData {
    static func receipt(recorded: Bool) -> MerchantMarketingConsentOriginalReceipt {
        let outcome = recorded ? "RECORDED" : "NOT_OBSERVED"
        let extra = recorded ? ",\"consentId\":4,\"eventType\":\"OPT_IN\",\"recordedAt\":1" : ""
        let json = """
        {"receiptVersion":1,"actorId":1,"merchantRowId":2,"merchantOwnerMemberId":3,"channel":"IN_APP","requestId":"preview-request","outcome":"\(outcome)"\(extra)}
        """
        return try! JSONDecoder().decode(MerchantMarketingConsentOriginalReceipt.self, from: Data(json.utf8))
    }
}

#Preview("Receipt · player") {
    MarketingConsentOriginalReceiptView(receipt: MarketingConsentOriginalPreviewData.receipt(recorded: true))
        .padding(CYSpacing.lg)
        .cyDomainPageBackground()
        .themeDomain(.player)
}

#Preview("Receipt · merchant") {
    MarketingConsentOriginalReceiptView(receipt: MarketingConsentOriginalPreviewData.receipt(recorded: false))
        .padding(CYSpacing.lg)
        .cyDomainPageBackground()
        .themeDomain(.merchant)
}
#endif
