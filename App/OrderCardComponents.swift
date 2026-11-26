import SwiftUI

// D3 presentation pieces shared by the orders, tickets and coupons screens.
// Built only from CY tokens; candidates to fold into the design kit once it exists.

/// Native r2: no card chrome. Content keeps its padding and full width; the list or form around it draws the grouping.
struct OrderCardSurface: ViewModifier {
    var padding: CGFloat = CYSpacing.lg
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
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
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        Label { Text(title) } icon: { Image(systemName: systemImage).accessibilityHidden(true) }
            .font(.footnote)
            .foregroundStyle(emphasized ? Color.primary : Color.secondary)
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
    /// MP default artwork (for example `icon_ticket_empty.svg` on the order detail hero) shown instead of the generated cover.
    var fallback: Image? = nil
    var body: some View {
        Group {
            if let url {
                AsyncImage(url: url) { phase in
                    if let image = phase.image { image.resizable().scaledToFill() } else { placeholder }
                }
            } else { placeholder }
        }
        .frame(width: size, height: size)
        .clipped()
        .accessibilityHidden(true)
    }
    @ViewBuilder private var placeholder: some View {
        if let fallback {
            fallback.resizable().scaledToFit().padding(size * 0.18)
                .frame(width: size, height: size)
                .background(.quaternary)
        } else {
            E1CoverArt(seed: seed.isEmpty ? systemImage : seed, symbol: systemImage, debugLabel: false)
        }
    }
}

/// White pill label for the one CTA on a card. The card (or button) around it owns the tap.
struct OrderPillLabel: View {
    let title: Text
    var systemImage: String? = nil
    var fullWidth = false
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        HStack {
            if let systemImage { Image(systemName: systemImage).accessibilityHidden(true) }
            title.multilineTextAlignment(.center)
        }
        .font(.body.weight(.semibold))
        .foregroundStyle(.tint)
        .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: CYSpacing.minTouchTarget)
    }
}

/// Horizontal pill filter; selected pill uses neutral primary fill (`actionPrimaryBg`), others sit on `bgElevated`.
struct OrderFilterPill: View {
    let title: LocalizedStringKey
    let isSelected: Bool
    let choose: () -> Void
    var body: some View {
        Group {
            if isSelected {
                Button(action: choose) { Text(title) }
                    .buttonStyle(.borderedProminent)
            } else {
                Button(action: choose) { Text(title) }
                    .buttonStyle(.bordered)
            }
        }
        .buttonBorderShape(.capsule)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Large tabular amount; an unknown amount is an em dash, never 0. The currency caveat stays under a known figure.
struct OrderAmountHero: View {
    let label: LocalizedStringKey
    let amount: Decimal?
    var showsCurrencyCaveat = true
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    private var figure: String {
        guard let amount else { return "—" }
        let formatter = NumberFormatter(); formatter.locale = locale; formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2; formatter.maximumFractionDigits = 2
        return formatter.string(from: NSDecimalNumber(decimal: amount)) ?? "—"
    }
    var body: some View {
        VStack(alignment: .leading) {
            Text(label).font(.subheadline).foregroundStyle(.secondary)
            Text(verbatim: figure)
                .font(.largeTitle.bold())
                .monospacedDigit()
                .foregroundStyle(.primary)
                .privacySensitive()
            if amount != nil, showsCurrencyCaveat {
                Text(verbatim: appLocalized("activity.currencyUnconfirmed", locale: locale))
                    .font(.caption).foregroundStyle(.tertiary)
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
        LabeledContent {
            Text(verbatim: value)
                .multilineTextAlignment(size.isAccessibilitySize ? .leading : .trailing)
        } label: {
            Text(label)
        }
        .accessibilityElement(children: .combine)
    }
}
