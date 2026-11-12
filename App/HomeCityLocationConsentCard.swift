import SwiftUI

/// Mini-program `v3-locprompt` (pages/index): a non-blocking card at the top of the feed asking consent for the one-time
/// home-city location read. Layout only: the host owns recording consent and the location request; with no handlers the
/// card is not shown (capability absent => hidden).
struct HomeCityLocationConsentCard: View {
    let onAgree: () -> Void
    let onDecline: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Label {
                Text("homeCityConsent.title").font(CYTypography.cardTitle)
            } icon: {
                Image(systemName: "location.circle").foregroundStyle(CYColor.accent)
            }
            .foregroundStyle(CYColor.textPrimary)
            Text("homeCityConsent.body")
                .font(CYTypography.bodyCompact)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: CYSpacing.md) { buttons }
                VStack(spacing: CYSpacing.sm) { buttons }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.lg)
        .background(CYColor.bgSurface, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .cyNightCardDepth(radius: CYRadius.lg)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeCityConsent")
    }

    @ViewBuilder private var buttons: some View {
        Button("homeCityConsent.decline", action: onDecline)
            .buttonStyle(.cySecondary(fullWidth: true))
            .frame(minHeight: CYSpacing.minTouchTarget)
            .accessibilityIdentifier("homeCityConsent.decline")
        Button("homeCityConsent.agree", action: onAgree)
            .buttonStyle(.cyPrimary)
            .frame(minHeight: CYSpacing.minTouchTarget)
            .accessibilityIdentifier("homeCityConsent.agree")
    }
}
