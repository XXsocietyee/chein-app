import SwiftUI

/// Balance hero: meta label, Data XL amount, optional delta chip.
public struct CYBalanceHero: View {
    private let label: String
    private let amount: String
    private let delta: String?

    public init(label: String, amount: String, delta: String? = nil) {
        self.label = label
        self.amount = amount
        self.delta = delta
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(label)
                .font(CYTypography.meta)
                .foregroundStyle(CYColor.textSecondary)
                .lineLimit(1)
            Text(amount)
                .font(CYTypography.dataXL)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let delta {
                Text(delta)
                    .font(CYTypography.caption.monospacedDigit())
                    .foregroundStyle(CYColor.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, CYSpacing.sm)
                    .padding(.vertical, CYSpacing.xs)
                    .background(CYColor.accentSoft, in: Capsule(style: .continuous))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Player") {
    CYBalanceHero(label: "Preview balance", amount: "1,234.00", delta: "+12.00")
        .padding(CYSpacing.lg)
        .themeDomain(.player)
}

#Preview("Merchant") {
    CYBalanceHero(label: "Preview balance", amount: "1,234.00")
        .padding(CYSpacing.lg)
        .themeDomain(.merchant)
}
