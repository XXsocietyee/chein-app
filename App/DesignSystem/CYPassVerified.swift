import SwiftUI

// Night-city light, wave 3 (B6): the pass when it is verified. Choreography D (spec section 5):
//   0 ms impactLight, QR tile dims to 60 %, edge glow (CYEdgeGlow) sweeps the display edge
//   300 ms the pass flips (0.5 s, rotation3D) to the green "You're in" face
//   800 ms the perforation tears: the stub opens a 3 pt gap, slides down 24 pt, impactLight
//   1700 ms the stub drops away toward the tab bar
// Reduce Motion: the glow fades, the two faces crossfade, nothing flips or tears.

/// Two faces on one card. `angle` 0 shows `content`, 180 shows `back`. The face swap reads the interpolated angle, so
/// it happens at 90 degrees while the card is edge-on. Reduce Motion crossfades on the same angle without rotating.
struct CYPassFlip<Back: View>: ViewModifier, Animatable {
    var angle: Double
    var crossfade: Bool
    let back: Back
    var animatableData: Double {
        get { angle }
        set { angle = newValue }
    }

    func body(content: Content) -> some View {
        ZStack {
            if crossfade {
                content.opacity(1 - angle / 180)
                back.opacity(angle / 180)
            } else {
                content.opacity(angle < 90 ? 1 : 0)
                back.rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0)).opacity(angle >= 90 ? 1 : 0)
            }
        }
        .rotation3DEffect(.degrees(crossfade ? 0 : angle), axis: (x: 0, y: 1, z: 0), perspective: 0.55)
    }
}

/// The torn pass: the same face drawn twice and cut along the tear line, so the notches and perforation holes become
/// the torn edge. `tear` 0 to 1 opens the 3 pt gap and the 24 pt slide; `drop` 0 to 1 sends the stub away.
struct CYPassTear<Face: View>: View {
    let face: Face
    let size: CGSize
    let notchY: CGFloat
    var tear: CGFloat
    var drop: CGFloat

    var body: some View {
        ZStack(alignment: .top) {
            face.frame(width: size.width, height: size.height)
                .mask(alignment: .top) { Rectangle().frame(height: notchY) }
            face.frame(width: size.width, height: size.height)
                .mask(alignment: .bottom) { Rectangle().frame(height: max(0, size.height - notchY)) }
                .rotationEffect(.degrees(Double(tear) * 1.2), anchor: .topLeading)
                .offset(y: tear * 27 + drop * 280)
                .scaleEffect(1 - drop * 0.45, anchor: .top)
                .opacity(1 - Double(drop))
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .shadow(color: CYNight.ink0.opacity(0.4), radius: 16, y: 9)
    }
}

/// The "You're in" face: a verify-green tint over the pass ground, a big check, a rounded-heavy title (semibold in
/// Chinese; the strokes clog at heavy). The stub below the tear line keeps the ticket number.
struct CYPassVerifiedFace: View {
    let title: String
    let number: String?
    let size: CGSize
    let notchY: CGFloat
    let shape: CYTicketPassShape
    @Environment(\.locale) private var locale
    @QuestifyReduceMotion private var reduceMotion
    @State private var landed = false
    private var c: CoreLoopCopy { CoreLoopCopy(locale: locale) }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: CYSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 76, weight: .semibold))
                    .foregroundStyle(CYNight.verify)
                    .symbolEffect(.bounce, options: .nonRepeating, isActive: landed && !reduceMotion)
                    .shadow(color: CYNight.verify.opacity(0.5), radius: 14)
                    .accessibilityHidden(true)
                Text(verbatim: c.t("已入场", "You're in"))
                    .font(.system(.largeTitle, design: c.isChinese ? .default : .rounded).weight(c.isChinese ? .semibold : .heavy))
                    .foregroundStyle(CYColor.textPrimary)
                Text(verbatim: c.t("玩得开心", "Have fun."))
                    .font(CYTypography.cardTitle).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: title.isEmpty ? "—" : title)
                    .font(CYTypography.meta).foregroundStyle(CYColor.textTertiary)
                    .lineLimit(1).padding(.horizontal, CYSpacing.xl)
            }
            .frame(maxWidth: .infinity)
            .frame(height: notchY)
            VStack(spacing: CYSpacing.xs) {
                Text(verbatim: c.t("已核验入场", "Checked in"))
                    .font(CYTypography.cardTitle).foregroundStyle(CYNight.verify)
                Text(verbatim: (number?.isEmpty == false) ? number! : "—")
                    .font(CYTypography.caption.monospaced()).foregroundStyle(CYColor.textTertiary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size.width, height: size.height)
        .background { ZStack { CYColor.bgElevated; CYNight.verify.opacity(0.12) } }
        .clipShape(shape, style: FillStyle(eoFill: true))
        .overlay(shape.stroke(CYNight.verify.opacity(0.45), lineWidth: 1).allowsHitTesting(false))
        .onAppear { landed = true }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: c.t("已入场，玩得开心", "You're in. Have fun.")))
        .accessibilityIdentifier("ticketPass.verified")
    }
}

// MARK: - Foil edge

extension View {
    /// Holographic edge for a collectible pass: three foil hues on a 1.5 pt stroke that drifts slowly. Reduce Motion and
    /// Low Power: the same stroke, static. Inactive passes keep the plain subtle border.
    func cyPassFoilEdge<S: Shape>(_ shape: S, active: Bool) -> some View {
        modifier(CYPassFoilEdge(shape: shape, active: active))
    }
}

private struct CYPassFoilEdge<S: Shape>: ViewModifier {
    let shape: S
    let active: Bool
    @State private var spin = 0.0
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        content.overlay {
            if active {
                shape.stroke(
                    AngularGradient(colors: [CYNight.foilA, CYNight.foilB, CYNight.foilC, CYNight.foilA],
                                    center: .center, angle: .degrees(spin)),
                    lineWidth: 1.5)
                    .opacity(0.6)
                    .allowsHitTesting(false)
                    .onAppear {
                        guard !reduceMotion, CYLightBudget.shadersAllowed else { return }
                        withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) { spin = 360 }
                    }
            } else {
                shape.stroke(CYColor.borderSubtle, lineWidth: 1).allowsHitTesting(false)
            }
        }
    }
}
