import SwiftUI

/// Gyro-driven holographic sheen for collectibles and the pass (spec 3.3). Apply to the object itself: it overlays
/// three hue stops, a lantern-hot specular spot and a diagonal band, all clipped to `shape` and screen-blended,
/// and slides them with `CYTilt` (device roll/pitch; DEBUG `--uitesting-fake-tilt` in the simulator).
/// Reduce Motion, Low Power and thermal pressure: the same layers frozen as one quiet highlight, no gyro.
private struct CYFoilModifier<S: Shape>: ViewModifier {
    let shape: S
    let active: Bool
    @QuestifyReduceMotion private var reduceMotion

    private var live: Bool { active && !reduceMotion && CYLightBudget.gyroAllowed }

    func body(content: Content) -> some View {
        content
            .overlay {
                if active {
                    Group {
                        if live { CYFoilLive() } else { CYFoilLayers(u: UnitPoint(x: 0.3, y: 0.25), strength: 0.25) }
                    }
                    .clipShape(shape)   // clip the light only, never the host (shadows and glows stay)
                }
            }
            .cyTiltHold(live)
    }
}

/// Reads the shared tilt so only this overlay re-renders at 30 Hz, not the host view.
private struct CYFoilLive: View {
    var body: some View {
        let tilt = CYTilt.shared
        CYFoilLayers(u: UnitPoint(x: 0.5 + CGFloat(tilt.roll) * 1.4, y: 0.5 - CGFloat(tilt.pitch) * 1.0), strength: 1)
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
    func cyFoil<S: Shape>(in shape: S, active: Bool = true) -> some View {
        modifier(CYFoilModifier(shape: shape, active: active))
    }

    func cyFoil(cornerRadius: CGFloat = CYRadius.lg, active: Bool = true) -> some View {
        cyFoil(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous), active: active)
    }
}
