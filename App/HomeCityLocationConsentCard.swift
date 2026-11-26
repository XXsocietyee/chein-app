import SwiftUI

/// Mini-program `v3-locprompt` (pages/index): a non-blocking card at the top of the feed asking consent for the one-time
/// home-city location read. Layout only: the host owns recording consent and the location request; with no handlers the
/// card is not shown (capability absent => hidden).
struct HomeCityLocationConsentCard: View {
    let onAgree: () -> Void
    let onDecline: () -> Void

    var body: some View {
        // System GroupBox: the platform's own grouped container for a short in-feed prompt.
        GroupBox {
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Text("homeCityConsent.body")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: CYSpacing.md) { buttons }
                    VStack(spacing: CYSpacing.sm) { buttons }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } label: {
            Label("homeCityConsent.title", systemImage: "location.circle")
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("homeCityConsent")
    }

    @ViewBuilder private var buttons: some View {
        Button(action: onDecline) {
            Text("homeCityConsent.decline").frame(maxWidth: .infinity)
        }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityIdentifier("homeCityConsent.decline")
        Button(action: onAgree) {
            Text("homeCityConsent.agree").frame(maxWidth: .infinity)
        }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("homeCityConsent.agree")
    }
}
