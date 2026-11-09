import SwiftUI

// Collectible layer (e5b): badge medal with locked/unlocked states, and the celebratory moment used by
// check-in, stamp, badge unlock and club join. Presentation only; callers decide when to show it.

/// Round medal. Unlocked = generated gradient art, gold rim and a soft highlight; locked = quiet dashed
/// socket with a lock (never a fake progress number). Pure decoration for the badge's text, so it is hidden from VoiceOver.
struct CYBadgeMedal: View {
    var seed: String
    var symbol: String = "medal.fill"
    var locked = false
    var size: CGFloat = 84

    var body: some View {
        ZStack {
            if locked {
                Circle().fill(CYColor.bgSurfaceSubtle)
                Circle().strokeBorder(CYColor.borderStrong, style: StrokeStyle(lineWidth: 2, dash: [3, 5]))
                Image(systemName: "lock.fill")
                    .font(.system(size: size * 0.32, weight: .semibold))
                    .foregroundStyle(CYColor.textTertiary)
            } else {
                CYCoverArt(seed: seed, symbol: symbol, showsDebugLabel: false, showsGlyph: false).clipShape(Circle())
                Circle().fill(LinearGradient(colors: [.white.opacity(0.38), .clear], startPoint: .topLeading, endPoint: .center))
                Circle().strokeBorder(
                    AngularGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.40), .white, Color(red: 0.95, green: 0.65, blue: 0.20),
                                             Color(red: 1.0, green: 0.84, blue: 0.40)], center: .center),
                    lineWidth: max(3, size * 0.06))
                Image(systemName: symbol)
                    .font(.system(size: size * 0.38, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
            }
        }
        .frame(width: size, height: size)
        .shadow(color: locked ? .clear : .black.opacity(0.4), radius: 8, y: 5)
        .accessibilityHidden(true)
    }
}

/// Collection-grid tile: medal, name, state. Unknown dates stay a dash.
struct CYBadgeTile: View {
    var seed: String
    var symbol: String = "medal.fill"
    var locked: Bool
    var name: Text
    var status: Text

    var body: some View {
        VStack(spacing: CYSpacing.sm) {
            CYBadgeMedal(seed: seed, symbol: symbol, locked: locked, size: 84)
            name
                .font(CYTypography.bodyCompact.weight(.semibold))
                .foregroundStyle(locked ? CYColor.textSecondary : CYColor.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
            status
                .font(CYTypography.meta)
                .foregroundStyle(locked ? CYColor.textTertiary : CYColor.successText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.lg)
        .padding(.horizontal, CYSpacing.sm)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Full-screen celebration. One primary button. Haptic `.success` on landing, confetti only without Reduce Motion.
struct CYCelebrationMoment: View {
    enum Kind { case badge, stamp, checkIn, club }
    var kind: Kind
    var seed: String
    var symbol: String
    var title: Text
    var message: Text
    var primaryTitle: LocalizedStringKey
    var onPrimary: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var landed = false
    @State private var burst = 0

    var body: some View {
        ZStack {
            CYColor.bgPage.ignoresSafeArea()
            RadialGradient(colors: [Color(hue: Double(CYCoverArt.stableHash(seed) % 360) / 360, saturation: 0.6, brightness: 0.55).opacity(0.55), .clear],
                           center: .init(x: 0.5, y: 0.36), startRadius: 10, endRadius: 360)
                .ignoresSafeArea()
            VStack(spacing: CYSpacing.xxl) {
                Spacer(minLength: CYSpacing.xxxl)
                hero.frame(height: 230)
                VStack(spacing: CYSpacing.sm) {
                    title.font(.system(.largeTitle, design: .rounded).weight(.heavy)).foregroundStyle(CYColor.textPrimary)
                        .multilineTextAlignment(.center).accessibilityAddTraits(.isHeader)
                    message.font(CYTypography.body).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
                }
                .fixedSize(horizontal: false, vertical: true)
                .opacity(landed || reduceMotion ? 1 : 0)
                .offset(y: landed || reduceMotion ? 0 : 14)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.4).delay(0.35), value: landed)
                Spacer(minLength: CYSpacing.lg)
                CYPillButton(primaryTitle, action: onPrimary)
            }
            .padding(.horizontal, CYSpacing.xxl)
            .padding(.bottom, CYSpacing.lg)
            CYConfettiBurst(trigger: burst)
        }
        .sensoryFeedback(.success, trigger: landed) { _, new in new }
        .onAppear {
            if reduceMotion { landed = true; return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.58)) { landed = true }
            burst += 1
        }
    }

    @ViewBuilder private var hero: some View {
        let on = landed || reduceMotion
        switch kind {
        case .badge:
            CYBadgeMedal(seed: seed, symbol: symbol, size: 168)
                .scaleEffect(on ? 1 : 0.25)
                .rotation3DEffect(.degrees(on ? 0 : 100), axis: (x: 0, y: 1, z: 0))
                .background { CYRingPulse(trigger: burst, idle: false).frame(width: 168, height: 168) }
        case .stamp:
            stamp.scaleEffect(on ? 1 : 2.4).rotationEffect(.degrees(on ? -9 : -26)).opacity(on ? 1 : 0)
                .background { CYRingPulse(trigger: burst, idle: false).frame(width: 170, height: 170) }
        case .checkIn, .club:
            Image(systemName: symbol)
                .font(.system(size: 92, weight: .semibold))
                .foregroundStyle(.white, Color(hue: Double(CYCoverArt.stableHash(seed) % 360) / 360, saturation: 0.65, brightness: 0.75))
                .symbolEffect(.bounce, options: .nonRepeating, value: landed)
                .scaleEffect(on ? 1 : 0.3)
                .background { CYRingPulse(trigger: burst, idle: false).frame(width: 150, height: 150) }
        }
    }

    /// Passport-ink stamp: double ring, dashed inner ring, glyph.
    private var stamp: some View {
        let ink = Color(red: 0.98, green: 0.45, blue: 0.40)
        return ZStack {
            Circle().strokeBorder(ink, lineWidth: 6)
            Circle().strokeBorder(ink.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [2, 6])).padding(16)
            Image(systemName: symbol).font(.system(size: 64, weight: .bold)).foregroundStyle(ink)
        }
        .frame(width: 170, height: 170)
        .background(Circle().fill(ink.opacity(0.10)))
        .shadow(color: ink.opacity(0.35), radius: 16)
    }
}

extension View {
    /// Stamp-slam entrance for an existing stamp card: scales down from large with a spring and a heavy tap.
    func cyStampSlam(trigger: Bool) -> some View { modifier(CYStampSlam(active: trigger)) }
}

private struct CYStampSlam: ViewModifier {
    let active: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var done = false
    func body(content: Content) -> some View {
        content
            .scaleEffect(done || reduceMotion ? 1 : 1.35)
            .opacity(done || reduceMotion ? 1 : 0)
            .sensoryFeedback(.impact(weight: .heavy), trigger: done) { _, new in new }
            .onAppear { settle() }
            .onChange(of: active) { _, _ in settle() }
    }
    private func settle() {
        guard active, !done else { return }
        withAnimation(reduceMotion ? nil : .spring(response: 0.38, dampingFraction: 0.55)) { done = true }
    }
}
