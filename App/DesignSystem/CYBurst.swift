import SwiftUI

// Night-city light, particles (wave 3 B5). Spec: specs/design-wave3.md 3.4 and 5A. Canvas + TimelineView, no images.
// Budget: at most 60 particles, stops drawing (and stops the timeline) when it ends. Reduce Motion, Low Power and
// thermal >= serious draw nothing at all (CYLightBudget.particlesAllowed); the surrounding choreography carries the beat.

struct CYBurst: View {
    enum Style { case dust, confetti }

    private struct Particle {
        var angle: Double, speed: Double, size: Double, hue: Double, spin: Double
    }

    /// Spec cap: never more than 60 particles on screen.
    static let maxCount = 60

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

    var body: some View {
        Group {
            if !reduceMotion && CYLightBudget.particlesAllowed {
                TimelineView(.animation(paused: started == nil)) { timeline in
                    Canvas { context, size in draw(&context, size, at: timeline.date) }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear {
            guard particles.isEmpty else { return }
            let n = min(max(count, 0), Self.maxCount)
            particles = (0..<n).map { _ in
                Particle(angle: .random(in: 0..<2 * .pi), speed: .random(in: 0.4...1), size: .random(in: 3...7),
                         hue: .random(in: 0..<1), spin: .random(in: -6...6))
            }
            started = .now
        }
    }

    private func draw(_ context: inout GraphicsContext, _ size: CGSize, at date: Date) {
        guard let started else { return }
        let t = date.timeIntervalSince(started) / duration
        guard t >= 0, t < 1 else { return }
        let o = CGPoint(x: size.width * origin.x, y: size.height * origin.y)
        let colors = palette
        for p in particles {
            let travel = p.speed * (1 - pow(1 - t, 3)) * reach
            let gravity = (style == .confetti ? 140 : 80) * t * t
            var c = context
            c.opacity = max(0, 1 - t * t)
            c.translateBy(x: o.x + cos(p.angle) * travel, y: o.y + sin(p.angle) * travel + gravity)
            c.rotate(by: .radians(p.spin * t))
            let w = style == .confetti ? p.size * 1.4 : p.size
            let rect = CGRect(x: -w / 2, y: -p.size / 2, width: w, height: p.size * 0.6)
            let color = colors[Int(p.hue * Double(colors.count)) % colors.count]
            c.fill(style == .confetti ? Path(rect) : Path(ellipseIn: rect), with: .color(color))
        }
    }
}
