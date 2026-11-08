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

    public var body: some View {
        HStack(alignment: .center, spacing: CYSpacing.md) {
            VStack(alignment: .leading, spacing: CYSpacing.xxs) {
                Text(title)
                    .font(CYTypography.cardTitle)
                    .foregroundStyle(CYColor.textPrimary)
                    .lineLimit(1)
                Text(detail)
                    .font(CYTypography.meta)
                    .foregroundStyle(CYColor.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: CYSpacing.sm)
            Text(signedAmount)
                .font(CYTypography.numericBody)
                .foregroundStyle(incoming ? CYColor.successText : CYColor.dangerText)
                .lineLimit(1)
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
