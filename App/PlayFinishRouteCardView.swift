import SwiftUI

/// 附近下一程 card from the mini-program finish sheet. Read-only; tapping opens the
/// host-provided activity detail (where price and purchase stay behind their own gates).
@MainActor struct PlayFinishRouteCardView: View {
    let card: PlayFinishRouteCard
    var destination: ((Int) -> AnyView)?
    @Environment(\.locale) private var locale

    var body: some View {
        if let destination {
            NavigationLink { destination(card.activityID) } label: { content }
                .accessibilityIdentifier("playx.finishRoute.card")
        } else {
            content.accessibilityIdentifier("playx.finishRoute.card")
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s3) {
            Text("playx.finishRoute.eyebrow").cyText(.caption).foregroundStyle(CYColor.textTertiary)
            if let title = card.title { Text(verbatim: title).cyText(.cardTitle) }
            else { Text("playx.finishRoute.untitled").cyText(.cardTitle) }
            if let meta = metaLine { Text(meta).cyText(.meta).foregroundStyle(CYColor.textSecondary) }
            ViewThatFits(in: .horizontal) {
                priceAndAction.fixedSize(horizontal: true, vertical: false)
                VStack(alignment: .leading, spacing: Theme.Space.s2) {
                    price
                    Text("playx.finishRoute.action").cyText(.label)
                }.frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .padding(Theme.Space.s4)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).strokeBorder(CYColor.borderSubtle, lineWidth: 1).allowsHitTesting(false))
        .accessibilityElement(children: .combine)
    }
    private var priceAndAction: some View {
            HStack {
                price
                Spacer(minLength: Theme.Space.s4)
                HStack(spacing: CYSpacing.xs) {
                    Text("playx.finishRoute.action").cyText(.label)
                    Image(systemName: "chevron.right").font(.footnote.weight(.semibold)).accessibilityHidden(true)
                }
            }
    }
    @ViewBuilder private var price: some View {
                switch card.price {
                case .from(let amount)?: Text("playx.finishRoute.priceFrom \(NSDecimalNumber(decimal: amount).stringValue)").cyText(.numericBody)
                case .free?: Text("playx.finishRoute.free").cyText(.numericBody)
                case nil: EmptyView()
                }
    }

    private var metaLine: LocalizedStringKey? {
        // i18n r2: the distance argument carries its unit (zh `1.2 公里` / `850 米` unchanged; en-US `0.7 mi` / `500 ft`).
        let distance = card.distanceMeters.map { meters -> String in
            let parts = PlayFinishRouteCard.distanceParts(meters)
            return LocaleDisplay.distanceArgument(meters: meters, zhText: parts.value + (parts.kilometres ? " 公里" : " 米"), locale: locale)
        }
        switch (distance, card.address) {
        case (let d?, let address?): return "playx.finishRoute.metaDistance \(d) \(address)"
        case (let d?, nil): return "playx.finishRoute.distance \(d)"
        case (nil, let address?): return "playx.finishRoute.address \(address)"
        case (nil, nil): return nil
        }
    }
}
