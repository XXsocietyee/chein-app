import SwiftUI

// Night-city light, particles (wave 3 B5). Spec: specs/design-wave3.md 3.4 and 5A. Canvas + TimelineView, no images.
// A mix of round dots, four-point sparkles and warm streaks (4-9 pt), slow easeOut drift with a light fall.
// Budget: at most 90 particles, stops drawing when it ends. Reduce Motion, Low Power and thermal >= serious draw nothing
// (CYLightBudget.particlesAllowed); the surrounding choreography carries the beat.

struct CYBurst: View {
    enum Style { case dust, confetti }
    private enum Glyph { case dot, sparkle, streak }

    private struct Particle {
        var angle: Double, speed: Double, size: Double, hue: Double, spin: Double, glyph: Glyph
    }

    /// Owner call (wave 3 review): richer than the spec's 60.
    static let maxCount = 90

    var origin: UnitPoint = .center
    var count = 48
    var duration = 1.4
    var style: Style = .dust
    /// Radial travel in points at full speed.
    var reach: Double = 220
    var colors: [Color] = [CYNight.lantern, CYNight.lanternHot, .white]
    @QuestifyReduceMotion private var reduceMotion
    @State private var particles: [Particle] = []
    @State private var started: Date?

    private var palette: [Color] {
        style == .confetti ? [CYNight.lantern, CYNight.lanternHot, CYNight.verify, CYNight.foilC, CYNight.foilA] : colors
    }

    /// Native r2: no particles (no bursts or confetti). Draws nothing; the surrounding system feedback carries the beat.
    var body: some View {
        EmptyView()
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, at date: Date) {
        guard let started else { return }
        let t = date.timeIntervalSince(started) / duration
        guard t >= 0, t < 1 else { return }
        let o = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
        let colors = palette
        for p in particles {
            let eased = 1 - pow(1 - t, 2.4)               // slow tail: drifts rather than flies
            let travel = p.speed * eased * reach
            let gravity = (style == .confetti ? 110 : 36) * t * t
            let dx = cos(p.angle) * travel, dy = sin(p.angle) * travel + gravity
            var c = context
            // Twinkle: sparkles pulse, everything fades over the last 40 %.
            let fade = t < 0.6 ? 1 : max(0, 1 - (t - 0.6) / 0.4)
            let twinkle = p.glyph == .sparkle ? 0.65 + 0.35 * sin(t * 18 + p.hue * 20) : 1
            c.opacity = fade * twinkle
            c.translateBy(x: o.x + dx, y: o.y + dy)
            let color = colors[Int(p.hue * Double(colors.count)) % colors.count]
            switch p.glyph {
            case .dot:
                let r = p.size / 2
                c.fill(Path(ellipseIn: CGRect(x: -r, y: -r, width: p.size, height: p.size)), with: .color(color))
            case .sparkle:
                c.rotate(by: .radians(p.spin * t))
                c.fill(Self.sparkle(radius: p.size * 0.9), with: .color(color))
            case .streak:
                // Warm streak along the direction of travel.
                c.rotate(by: .radians(atan2(dy, dx)))
                let len = p.size * 3.2
                c.fill(Path(roundedRect: CGRect(x: -len, y: -0.9, width: len, height: 1.8), cornerRadius: 0.9),
                       with: .linearGradient(Gradient(colors: [.clear, CYNight.lantern]), startPoint: CGPoint(x: -len, y: 0), endPoint: .zero))
            }
        }
    }

    /// Four-point sparkle: long thin points with a pinched waist.
    static func sparkle(radius r: Double) -> Path {
        var path = Path()
        let waist = r * 0.22
        for i in 0..<8 {
            let a = Double(i) * .pi / 4 - .pi / 2
            let rad = i % 2 == 0 ? r : waist
            let pt = CGPoint(x: cos(a) * rad, y: sin(a) * rad)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
