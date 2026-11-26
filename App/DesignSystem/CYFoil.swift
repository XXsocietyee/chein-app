import SwiftUI

/// Gyro-driven holographic sheen for collectibles and the pass (spec 3.3). Apply to the object itself: it overlays
/// three hue stops, a lantern-hot specular spot and a diagonal band, all clipped to `shape` and screen-blended,
/// and slides them with `CYTilt` (device roll/pitch; DEBUG `--uitesting-fake-tilt` in the simulator).
/// Reduce Motion, Low Power and thermal pressure: the same layers frozen as one quiet highlight, no gyro.
private struct CYFoilModifier<S: Shape>: ViewModifier {
    let shape: S
    let active: Bool
    /// Scales every foil layer: 1 for big collectibles; small saturated seals (Passport grid) use less so the colour stays punchy.
    var strength: Double = 1
    @QuestifyReduceMotion private var reduceMotion

    private var live: Bool { active && !reduceMotion && CYLightBudget.gyroAllowed }

    /// Native r2: no foil sheen and no gyro tilt. Shows the content as is.
    func body(content: Content) -> some View {
        content
    }
}

/// Reads the shared tilt so only this overlay re-renders at 30 Hz, not the host view.
private struct CYFoilLive: View {
    var scale: Double = 1
    var body: some View {
        let tilt = CYTilt.shared
        CYFoilLayers(u: UnitPoint(x: 0.5 + CGFloat(tilt.roll) * 1.4, y: 0.5 - CGFloat(tilt.pitch) * 1.0), strength: scale)
    }
}

private struct CYFoilLayers: View {
    let u: UnitPoint
    let strength: Double

    var body: some View {
        GeometryReader { geo in
            let reach = max(geo.size.width, geo.size.height)
            let band = UnitPoint(x: u.x, y: 0.5)
            ZStack {
                AngularGradient(colors: [CYNight.foilA, CYNight.foilB, CYNight.foilC, CYNight.foilA], center: u)
                    .opacity(0.32)
                RadialGradient(colors: [CYNight.lanternHot.opacity(0.75), CYNight.lantern.opacity(0.18), .clear],
                               center: u, startRadius: 0, endRadius: reach * 0.7)
                // Diagonal specular band that rides the roll, so the sheen visibly travels across the face.
                LinearGradient(stops: [.init(color: .clear, location: 0),
                                       .init(color: .white.opacity(0.34), location: 0.5),
                                       .init(color: .clear, location: 1)],
                               startPoint: UnitPoint(x: band.x - 0.18, y: 0), endPoint: UnitPoint(x: band.x + 0.18, y: 1))
            }
            .opacity(strength)
        }
        .blendMode(.screen)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

extension View {
    /// Holographic foil sheen, clipped to `shape`. `active` false (locked) draws nothing.
    func cyFoil<S: Shape>(in shape: S, active: Bool = true, strength: Double = 1) -> some View {
        modifier(CYFoilModifier(shape: shape, active: active, strength: strength))
    }

    func cyFoil(cornerRadius: CGFloat = CYRadius.lg, active: Bool = true, strength: Double = 1) -> some View {
        cyFoil(in: CYFoilClip(cornerRadius: cornerRadius), active: active, strength: strength)
    }
}

/// Rounded-rect clip that becomes a true circle/capsule once the radius reaches half the short side. A `.continuous`
/// rounded rect with an oversize radius (a 64 pt radius on a 44 pt seal) draws a diamond-like squircle, which is
/// what turned round stamp seals into pastel diamonds.
struct CYFoilClip: Shape {
    var cornerRadius: CGFloat
    func path(in rect: CGRect) -> Path {
        let half = min(rect.width, rect.height) / 2
        if cornerRadius >= half { return Capsule(style: .circular).path(in: rect) }
        return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).path(in: rect)
    }
}
