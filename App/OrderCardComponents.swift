import SwiftUI

// D3 presentation pieces shared by the orders, tickets and coupons screens.
// Built only from CY tokens; candidates to fold into the design kit once it exists.

/// Revolut-style card: `bgElevated` fill, soft radius, hairline border, no shadow in dark.
struct OrderCardSurface: ViewModifier {
    var padding: CGFloat = CYSpacing.lg
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous)
                    .strokeBorder(CYColor.borderSubtle, lineWidth: 1)
                    .allowsHitTesting(false)
            }
    }
}

extension View {
    func orderCardSurface(padding: CGFloat = CYSpacing.lg) -> some View { modifier(OrderCardSurface(padding: padding)) }
}

/// Quiet status chip. Symbol and text carry the state, never colour alone.
struct OrderStatusChip: View {
    let title: LocalizedStringKey
    let systemImage: String
    var emphasized = false
    var body: some View {
        Label { Text(title).lineLimit(1).minimumScaleFactor(0.75) } icon: { Image(systemName: systemImage).accessibilityHidden(true) }
            .font(CYTypography.caption.weight(.semibold))
            .foregroundStyle(emphasized ? CYColor.textPrimary : CYColor.textSecondary)
            .padding(.horizontal, CYSpacing.md)
            .padding(.vertical, CYSpacing.xs + 2)
            .background(emphasized ? CYColor.bgRaised : CYColor.bgSurfaceSubtle, in: Capsule(style: .continuous))
            .fixedSize(horizontal: false, vertical: true)
            .layoutPriority(1)
            .accessibilityElement(children: .combine)
    }
}

/// Cover placeholder: the data model carries no image URL, so a raised tile with a mode symbol stands in.
struct OrderCoverTile: View {
    var systemImage = "map"
    var url: URL? = nil
    var size: CGFloat = 88
    var seed = ""
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityHidden(true)
    }
    private var placeholder: some View {
        E1CoverArt(seed: seed.isEmpty ? systemImage : seed, symbol: systemImage, debugLabel: false)
    }
}

/// White pill label for the one CTA on a card. The card (or button) around it owns the tap.
struct OrderPillLabel: View {
    let title: Text
    var systemImage: String? = nil
    var fullWidth = false
    var body: some View {
        HStack(spacing: CYSpacing.xs) {
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            title.lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(CYTypography.label)
        .foregroundStyle(CYColor.textOnAccent)
        .padding(.horizontal, CYSpacing.xl)
        .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: CYSpacing.minTouchTarget)
        .background(CYColor.actionPrimaryBg, in: Capsule(style: .continuous))
    }
}

/// Horizontal pill filter; selected pill uses neutral primary fill (`actionPrimaryBg`), others sit on `bgElevated`.
struct OrderFilterPill: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let choose: () -> Void
    var body: some View {
        Button(action: choose) {
            Text(title)
                .font(CYTypography.label)
                .foregroundStyle(isSelected ? CYColor.textOnAccent : CYColor.textPrimary)
                .padding(.horizontal, CYSpacing.lg)
                .frame(minHeight: CYSpacing.minTouchTarget)
                .background(isSelected ? CYColor.actionPrimaryBg : CYColor.bgElevated, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Large tabular amount; an unknown amount is an em dash, never 0. The currency caveat stays under a known figure.
struct OrderAmountHero: View {
    let label: LocalizedStringKey
    let amount: Decimal?
    var showsCurrencyCaveat = true
    @Environment(\.locale) private var locale
    private var figure: String {
        guard let amount else { return "—" }
        let formatter = NumberFormatter(); formatter.locale = locale; formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "—"
    }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.xs) {
            Text(label).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            Text(verbatim: figure)
                .font(CYTypography.data2XL)
                .foregroundStyle(CYColor.textPrimary)
                .lineLimit(1).minimumScaleFactor(0.5)
                .privacySensitive()
            if amount != nil, showsCurrencyCaveat {
                Text(verbatim: appLocalized("activity.currencyUnconfirmed", locale: locale))
                    .font(CYTypography.caption).foregroundStyle(CYColor.textTertiary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }
}

/// Label / value pair that stacks at accessibility sizes so neither side clips.
struct OrderValueRow: View {
    let label: LocalizedStringKey
    let value: String
    @Environment(\.dynamicTypeSize) private var size
    var body: some View {
        let layout = size.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.xs))
                                              : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: CYSpacing.md))
        layout {
            Text(label).font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
            if size.isAccessibilitySize == false { Spacer(minLength: CYSpacing.sm) }
            Text(verbatim: value).font(CYTypography.bodyCompact).foregroundStyle(CYColor.textPrimary)
                .multilineTextAlignment(size.isAccessibilitySize ? .leading : .trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
