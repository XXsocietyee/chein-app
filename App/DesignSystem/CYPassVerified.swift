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
                .rotationEffect(.degrees(Double(tear) * 4 + Double(drop) * 6), anchor: .topLeading)
                .offset(x: tear * 5 + drop * 18, y: tear * 27 + drop * 300)
                .scaleEffect(1 - drop * 0.45, anchor: .top)
                .opacity(1 - Double(drop))
        }
        .frame(width: size.width, height: size.height, alignment: .top)
        .shadow(color: CYNight.ink0.opacity(0.4), radius: 16, y: 9)
    }
}

/// The "You're in" face: a verify-green ground that stays at least 4.5:1 off ink, ink text that stays at least
/// 4.5:1 on every stop (the old bright stop was 3.07:1 under white), a rounded-heavy title (semibold in
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
                ZStack {
                    CYStampSeal(index: 0, earned: true, scale: 1.6)
                        .frame(width: 84, height: 84)
                        .shadow(color: CYNight.lantern.opacity(landed ? 0.55 : 0), radius: 16)
                        .scaleEffect(reduceMotion || landed ? 1 : 0.6)
                    let mark = Image(systemName: "checkmark.circle.fill")
                        .font(.title.weight(.semibold))
                        .foregroundStyle(CYNight.ink0)
                        .offset(x: 30, y: 28)
                    if #available(iOS 18.0, *) {
                        mark.symbolEffect(.bounce, options: .nonRepeating, isActive: landed && !reduceMotion)
                    } else {
                        mark
                    }
                }
                .accessibilityHidden(true)
                Text(verbatim: c.t("已入场", "You're in"))
                    .font(.system(.largeTitle, design: c.isChinese ? .default : .rounded).weight(c.isChinese ? .semibold : .heavy))
                    .foregroundStyle(CYNight.ink0)
                Text(verbatim: c.t("玩得开心", "Have fun."))
                    .cyText(.cardTitle).foregroundStyle(CYNight.ink0)
                Text(verbatim: title.isEmpty ? "—" : title)
                    .cyText(.meta).foregroundStyle(CYNight.ink0)
                    .lineLimit(2).multilineTextAlignment(.center).minimumScaleFactor(0.85)
                    .padding(.horizontal, CYSpacing.xl)
            }
            .frame(maxWidth: .infinity)
            .frame(height: notchY)
            VStack(spacing: CYSpacing.xs) {
                Text(verbatim: c.t("已核验入场", "Checked in"))
                    .cyText(.cardTitle).foregroundStyle(CYNight.ink0)
                Text(verbatim: (number?.isEmpty == false) ? number! : "—")
                    .font(CYTypography.caption.monospaced()).foregroundStyle(CYNight.ink0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: size.width, height: size.height)
        .background {
            ZStack {
                // Ink on the darkest stop is 4.83:1, which is also the card against the night page.
                // White fails every stop (4.18 / 3.98 / 3.07). The old dark stop was 2.20:1 on ink.
                LinearGradient(colors: [CYRGB(hex: 0x168E50).swiftUIColor, CYRGB(hex: 0x189252).swiftUIColor, CYRGB(hex: 0x1FA866).swiftUIColor],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [CYNight.verify.opacity(0.55), CYNight.verify.opacity(0.12), .clear],
                               center: UnitPoint(x: 0.5, y: notchY * 0.42 / max(size.height, 1)), startRadius: 4, endRadius: 150)
                LinearGradient(colors: [.white.opacity(0.18), .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35))
            }
        }
        .overlay(alignment: .top) {
            // The perforation line: dotted, on the tear row, so the two halves read as one pass until it tears.
            Path { p in p.move(to: CGPoint(x: 22, y: notchY)); p.addLine(to: CGPoint(x: size.width - 22, y: notchY)) }
                .stroke(CYNight.ink0.opacity(0.45), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [0.5, 7]))
                .allowsHitTesting(false)
        }
        .clipShape(shape, style: FillStyle(eoFill: true))
        .overlay(shape.stroke(CYNight.ink0.opacity(0.28), lineWidth: 1).allowsHitTesting(false))
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
