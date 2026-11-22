import SwiftUI

/// Money row: title, detail, trailing tabular amount. Sign and colour mark direction only.
public struct CYMoneyRow: View {
    private let title: String
    private let detail: String
    private let amount: String
    private let incoming: Bool

    public init(title: String, detail: String, amount: String, incoming: Bool) {
        self.title = title
        self.detail = detail
        self.amount = amount
        self.incoming = incoming
    }

    private var signedAmount: String {
        let trimmed = amount.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("+") || trimmed.hasPrefix("-") || trimmed.hasPrefix("−") {
            return trimmed
        }
        return (incoming ? "+" : "−") + trimmed
    }

    @Environment(\.dynamicTypeSize) private var typeSize

    private var textBlock: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xxs) {
            Text(title)
                .cyText(.cardTitle)
                .foregroundStyle(CYColor.textPrimary)
            Text(detail)
                .cyText(.meta)
                .foregroundStyle(CYColor.textTertiary)
        }
    }

    private var amountText: some View {
        Text(signedAmount)
            .cyText(.numericBody)
            .foregroundStyle(incoming ? CYColor.successText : CYColor.dangerText)
            .cyWrapText(alignment: .trailing)
    }

    public var body: some View {
        Group {
            if typeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: CYSpacing.xs) {
                    textBlock
                    amountText
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(alignment: .center, spacing: CYSpacing.md) {
                    textBlock
                    Spacer(minLength: CYSpacing.sm)
                    amountText
                }
            }
        }
        .frame(minHeight: CYSpacing.minTouchTarget)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Player") {
    VStack(spacing: CYSpacing.md) {
        CYMoneyRow(title: "Preview in", detail: "Today", amount: "20.00", incoming: true)
        CYMoneyRow(title: "Preview out", detail: "Yesterday", amount: "8.50", incoming: false)
    }
    .padding(CYSpacing.lg)
    .themeDomain(.player)
}

#Preview("Merchant") {
    CYMoneyRow(title: "Preview in", detail: "Today", amount: "+20.00", incoming: true)
        .padding(CYSpacing.lg)
        .themeDomain(.merchant)
}
