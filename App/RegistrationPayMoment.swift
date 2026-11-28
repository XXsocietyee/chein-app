import SwiftUI

// OWNER RULE 3 (11-28) payment moment, shared by the WeChat Pay and Alipay result rows.
// Paid (only after the server read says so): the ticket slides into the wallet, the wallet bounces, a small burst.
// Cancelled: the line shakes once (the caller plays the `.warning` haptic).
// Reduce Motion: no slide, no shake, no burst; the rows fade in. Low Power: `CYBurst` draws nothing.

/// The paid line: a ticket that drops into the wallet, then the message.
struct RegistrationPaidTicketMoment: View {
    let message: Text
    @QuestifyReduceMotion private var reduceMotion
    @State private var landed = false

    var body: some View {
        HStack(spacing: CYSpacing.md) {
            walletArt
            Label {
                message
            } icon: {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(CYColor.successText)
                    .symbolEffect(.bounce, value: landed)
            }
            .opacity(landed || !reduceMotion ? 1 : 0)
        }
        .accessibilityElement(children: .combine)
        .onAppear(perform: land)
    }

    private var walletArt: some View {
        ZStack {
            Image(systemName: "wallet.pass.fill")
                .font(.title)
                .foregroundStyle(CYColor.brand)
                .symbolEffect(.bounce, value: landed)
            if !reduceMotion {
                Image(systemName: "ticket.fill")
                    .font(.title3)
                    .foregroundStyle(CYColor.successText)
                    .rotationEffect(.degrees(landed ? 0 : -14))
                    .scaleEffect(landed ? 0.5 : 1)
                    .offset(x: landed ? 0 : -30, y: landed ? -2 : -20)
                    .opacity(landed ? 0 : 1)
            }
        }
        .frame(width: 48, height: 40)
        .background {
            if landed && !reduceMotion {
                CYBurst(origin: .center, count: 24, duration: 1.1, style: .dust, reach: 54,
                        colors: [CYColor.brand, CYColor.successText, .white])
                    .frame(width: 140, height: 110)
            }
        }
        .accessibilityHidden(true)
    }

    private func land() {
        guard !landed else { return }
        let animation = CYMotion.resolve(CYMotion.moment.delay(0.12), reduceMotion: reduceMotion)
        withAnimation(animation) { landed = true }
    }
}

/// The cancelled line: shakes once when it appears, so the failure reads before the Pay again button.
struct RegistrationPayCancelledLine: View {
    let message: Text
    @QuestifyReduceMotion private var reduceMotion
    @State private var shakes: CGFloat = 0

    var body: some View {
        message
            .foregroundStyle(CYColor.textSecondary)
            .modifier(RegistrationPayShake(shakes: shakes))
            .onAppear(perform: shake)
    }

    private func shake() {
        guard !reduceMotion, shakes == 0 else { return }
        withAnimation(.linear(duration: 0.36)) { shakes = 3 }
    }
}

/// Horizontal shake: `shakes` full swings of `travel` points.
struct RegistrationPayShake: GeometryEffect {
    var shakes: CGFloat
    var travel: CGFloat = 6

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        let x = travel * sin(shakes * .pi * 2)
        return ProjectionTransform(CGAffineTransform(translationX: x, y: 0))
    }
}
