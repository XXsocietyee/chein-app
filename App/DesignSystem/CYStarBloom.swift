import SwiftUI

// Night-city light, reward bloom (wave 3 B5, heyozi). Spec: specs/design-wave3.md 3.5 and 5B.
// silhouette -> bloom -> horizon -> orbit, all derived from one `phase` (0...1) the caller drives, so the choreography
// is a pure function of time and every beat can be checked against the millisecond table.
//   phase 0.00...0.45  dark silhouette fills white, lands on an ease-out-back overshoot, blur copies bloom
//   phase 0.45...0.70  horizon arc draws in under the object
//   phase 0.55...1.00  seven stars orbit in
// Lantern gold = reward, so this view is only for discovery and reward moments. Always a background, never over text.

struct CYStarBloom<S: Shape>: View {
    let shape: S
    var tint: Color = CYNight.lantern
    /// 0...1, driven by the caller (a TimelineView clock or a withAnimation).
    var phase: Double
    /// Extra orbit rotation in radians (idle drift once the choreography has landed).
    var spin: Double = 0
    var size: CGFloat = 180
    /// Low Power / Reduce Transparency: no blur copies, one flat glow instead (spec 3.6).
    var cheap: Bool = false

    static func clamp(_ x: Double) -> Double { min(max(x, 0), 1) }
    static func easeOutBack(_ x: Double) -> Double {
        let c1 = 1.70158, c3 = c1 + 1
        let t = clamp(x) - 1
        return 1 + c3 * t * t * t + c1 * t * t
    }
    /// Scale of the object as it lands from 0.2x with an overshoot; the caller scales the real medal with the same curve.
    static func landScale(_ phase: Double) -> Double { 0.2 + 0.8 * easeOutBack(phase / 0.45) }
    /// 1 -> 0 over phase 0.40...0.60: the white silhouette hands over to the real object.
    static func silhouetteOpacity(_ phase: Double) -> Double { 1 - clamp((phase - 0.40) / 0.20) }
    static func objectOpacity(_ phase: Double) -> Double { clamp((phase - 0.40) / 0.20) }

    private var bloomIn: Double { Self.clamp(phase / 0.45) }

    var body: some View {
        ZStack {
            horizon
            glow
            silhouette
            orbit
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Lantern-gold arc that draws in from its centre outward with a soft bloom underneath (phase 0.45...0.70).
    private var horizon: some View {
        let p = Self.clamp((phase - 0.45) / 0.25)
        let arc = Ellipse().trim(from: 0.75 - 0.25 * p, to: 0.75 + 0.25 * p)
        let gold = LinearGradient(colors: [CYNight.ember.opacity(0.0), CYNight.lantern, CYNight.lanternHot, CYNight.lantern, CYNight.ember.opacity(0.0)],
                                  startPoint: .leading, endPoint: .trailing)
        return ZStack {
            if !cheap {
                arc.stroke(gold, lineWidth: 12).blur(radius: 10).opacity(0.65)
                arc.stroke(gold, lineWidth: 6).blur(radius: 3).opacity(0.8)
            }
            arc.stroke(gold, style: StrokeStyle(lineWidth: 3, lineCap: .round))
        }
        .frame(width: size * 4, height: size * 1.45)
        .offset(y: size * 2.3)
        .opacity(p > 0 ? 1 : 0)
    }

    @ViewBuilder private var glow: some View {
        if cheap {
            Circle().fill(CYNight.lantern.opacity(0.22)).frame(width: size * 3.2, height: size * 3.2).opacity(bloomIn)
        } else {
            // radial light behind the object (rule d) plus three blurred copies of the shape.
            Circle().fill(CYNight.lantern.opacity(0.20)).frame(width: size * 3.2, height: size * 3.2).blur(radius: 10).opacity(0.85 * bloomIn)
            ForEach([48.0, 24, 10], id: \.self) { radius in
                shape.fill(tint).frame(width: size, height: size).blur(radius: radius)
                    .opacity(0.5 * bloomIn).scaleEffect(1 + phase * 0.25)
            }
        }
    }

    private var silhouette: some View {
        // Lantern from the first frame. A grey-to-white disc read as a flash on album-badges-new.
        let fill = Self.clamp(phase / 0.30)
        return shape
            .fill(CYNight.lantern.opacity(0.28 + 0.72 * fill))
            .frame(width: size, height: size)
            .scaleEffect(Self.landScale(phase))
            .opacity(Self.silhouetteOpacity(phase) * (phase > 0 ? 1 : 0))
    }

    private var orbit: some View {
        let appear = Self.clamp((phase - 0.55) / 0.30)
        return ZStack {
            ForEach(0..<7, id: \.self) { i in
                let a = Double(i) / 7 * 2 * .pi + phase * 1.6 + spin
                Image(systemName: "sparkle")
                    .accessibilityHidden(true).font(.system(size: 10 + Double(i % 3) * 4))
                    .foregroundStyle(i % 2 == 0 ? tint : CYNight.lanternHot)
                    .offset(x: cos(a) * size * 0.84, y: sin(a) * size * 0.67)
                    .opacity(appear * 0.9)
                    .scaleEffect(0.4 + 0.6 * appear)
            }
        }
    }
}
