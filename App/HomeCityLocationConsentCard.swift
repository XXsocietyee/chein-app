import SwiftUI

/// Mini-program `v3-locprompt` (pages/index): a non-blocking card at the top of the feed asking consent for the one-time
/// home-city location read. Layout only: the host owns recording consent and the location request; with no handlers the
/// card is not shown (capability absent => hidden). P40 priming: symbol + title, one sentence of what happens, a privacy
/// line, one `.borderedProminent` 同意定位 and a quiet 暂不定位.
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
                Label("homeCityConsent.privacy", systemImage: "lock.fill")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("homeCityConsent.privacy")
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
            .buttonStyle(.borderless)
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
