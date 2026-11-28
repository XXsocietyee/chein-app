import SwiftUI

/// fix/1128c-ai-weather, OWNER RULE 3 level A: live weather and day / night light over maps and game / story scenes.
/// Ports the MP map ambience (`subpackageRoam/components/map-weather`: rain streaks, snow points, fog veil above the map
/// and below cards, no gestures) and the SURVIVAL look weather (`pages/play/utils/look-fx.js`: wind, rain, dust,
/// debris, lightning that change by phase).
///
/// - Particles: `TimelineView(.animation)` + `Canvas`, positions derived from time and a per-particle seed (no state,
///   no allocation per frame), at most ~30 fps.
/// - Reduce Motion: no particles and no lightning; the static light and tint stay (they carry the information).
/// - Low Power / serious thermal (`CYLightBudget.particlesAllowed`): the static tint only.
/// - Never hit-testable, hidden from VoiceOver (the chip states the condition in text).
/// - Level A only: `check_design_consistency` "effect on clean page" flags a `CYWeatherScene(` call outside the map,
///   play, story and game surfaces.
struct CYWeatherScene: View {
    /// What to draw. `story` (SURVIVAL look) replaces the live condition with the author's climate timeline.
    struct Spec: Equatable {
        var kind: WeatherSceneKind
        var intensity: Double
        var solarPhase: SolarLight.Phase?
        var story: StoryClimate?

        init(kind: WeatherSceneKind, intensity: Double, solarPhase: SolarLight.Phase? = nil, story: StoryClimate? = nil) {
            self.kind = kind; self.intensity = max(0, min(1, intensity)); self.solarPhase = solarPhase; self.story = story
        }

        init(_ context: WeatherContext) {
            self.init(kind: context.kind, intensity: context.intensity, solarPhase: context.solarPhase)
        }

        init(story: StoryClimate) {
            self.init(kind: story.kind, intensity: story.kind.defaultIntensity, story: story)
        }

        var animates: Bool { story != nil || kind.drawsParticles }
    }

    let spec: Spec
    /// Maps 1; scenes with text over them (story) pass less so words stay readable.
    var strength: Double = 1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            CYWeatherTint(spec: spec, strength: strength, dark: colorScheme == .dark)
            if spec.animates, !reduceMotion, CYLightBudget.particlesAllowed {
                CYWeatherParticles(spec: spec, strength: strength, dark: colorScheme == .dark)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .ignoresSafeArea()
    }
}

/// Static layer: night / twilight light, overcast grey, fog veil, sand haze. Drawn in every mode.
private struct CYWeatherTint: View {
    let spec: CYWeatherScene.Spec
    let strength: Double
    let dark: Bool

    var body: some View {
        ZStack {
            Rectangle().fill(CYWeatherPalette.light(for: spec.solarPhase).opacity(CYWeatherPalette.lightOpacity(spec.solarPhase) * strength))
            Rectangle().fill(CYWeatherPalette.haze(for: spec.kind, dark: dark).opacity(CYWeatherPalette.hazeOpacity(spec) * strength))
            if spec.kind == .fog {
                LinearGradient(colors: [CYWeatherPalette.fog(dark: dark).opacity(0.10 * strength),
                                        CYWeatherPalette.fog(dark: dark).opacity((0.18 + 0.22 * spec.intensity) * strength)],
                               startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// Animated layer. The closure stays one call so the view body is type-checked fast.
private struct CYWeatherParticles: View {
    let spec: CYWeatherScene.Spec
    let strength: Double
    let dark: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
            Canvas(opaque: false, rendersAsynchronously: true) { context, size in
                CYWeatherPainter.paint(spec, strength: strength, dark: dark, time: timeline.date.timeIntervalSinceReferenceDate, into: &context, size: size)
            }
        }
    }
}

enum CYWeatherPalette {
    static func light(for phase: SolarLight.Phase?) -> Color {
        phase == .twilight ? Color(red: 0.42, green: 0.27, blue: 0.45) : Color(red: 0.05, green: 0.08, blue: 0.22)
    }
    static func lightOpacity(_ phase: SolarLight.Phase?) -> Double {
        if phase == .night { return 0.30 }
        if phase == .twilight { return 0.16 }
        return 0
    }
    static func haze(for kind: WeatherSceneKind, dark: Bool) -> Color {
        switch kind {
        case .sand: return Color(red: 0.80, green: 0.60, blue: 0.32)
        case .fog: return fog(dark: dark)
        default: return Color(red: 0.36, green: 0.40, blue: 0.47)
        }
    }
    static func hazeOpacity(_ spec: CYWeatherScene.Spec) -> Double {
        if let story = spec.story { return 0.04 + 0.10 * (story.kind == .sand ? 1 : 0.5) }
        switch spec.kind {
        case .clear, .wind: return 0
        case .cloudy: return 0.06
        case .rain, .snow: return 0.04 + 0.08 * spec.intensity
        case .storm: return 0.10 + 0.10 * spec.intensity
        case .fog: return 0.08 * spec.intensity
        case .sand: return 0.10 + 0.14 * spec.intensity
        }
    }
    static func fog(dark: Bool) -> Color { dark ? Color(red: 0.62, green: 0.66, blue: 0.72) : Color(red: 0.93, green: 0.94, blue: 0.96) }
    /// MP `RAIN` rgba(205,216,235,.42) on the dark map; a slate streak on the light map so it still reads.
    static func rain(dark: Bool) -> Color { dark ? Color(red: 0.80, green: 0.85, blue: 0.92) : Color(red: 0.33, green: 0.40, blue: 0.50) }
    /// MP `SNOW` rgba(232,238,250,.34): fainter than the map's white place dots.
    static func snow(dark: Bool) -> Color { dark ? Color(red: 0.91, green: 0.93, blue: 0.98) : Color(red: 0.55, green: 0.62, blue: 0.72) }
    static func dust(dark: Bool) -> Color { dark ? Color(red: 0.86, green: 0.70, blue: 0.46) : Color(red: 0.62, green: 0.44, blue: 0.22) }
}

/// Stateless painter: every particle's position is a function of (seed, time), so a frame costs one pass.
enum CYWeatherPainter {
    /// What one frame draws (0…1 each; wind is signed, about −3…3 like the MP table).
    struct Mix: Equatable {
        var rain = 0.0, snow = 0.0, dust = 0.0, debris = 0.0, wind = 0.0, streaks = 0.0, fog = 0.0
        var bolt = false
    }

    static func mix(_ spec: CYWeatherScene.Spec, time: Double) -> Mix {
        if let story = spec.story {
            let sample = story.sample(at: time)
            return Mix(rain: sample.rain, dust: sample.dust, debris: sample.debris, wind: sample.wind,
                       streaks: abs(sample.wind) > 1.5 ? 0.5 : 0, bolt: sample.bolt)
        }
        let i = spec.intensity
        switch spec.kind {
        case .rain: return Mix(rain: i, wind: 0.4 + 0.4 * i)
        case .storm: return Mix(rain: max(0.6, i), debris: 0.25, wind: 1.4, streaks: 0.3, bolt: true)
        case .snow: return Mix(snow: i, wind: 0.2)
        case .fog: return Mix(fog: i)
        case .wind: return Mix(debris: 0.15, wind: 2 * max(0.4, i), streaks: max(0.4, i))
        case .sand: return Mix(dust: i, debris: 0.3 * i, wind: 1.6 + 1.2 * i, streaks: 0.2)
        case .clear, .cloudy: return Mix()
        }
    }

    /// `value` folded into 0..<span (also for negative values).
    static func wrap(_ value: Double, _ span: Double) -> Double {
        guard span > 0 else { return 0 }
        let r = value.truncatingRemainder(dividingBy: span)
        return r < 0 ? r + span : r
    }

    /// Deterministic 0…1 noise.
    static func seed(_ n: Int, _ salt: Double) -> Double {
        let v = sin(Double(n) * 12.9898 + salt * 78.233) * 43_758.5453
        return v - v.rounded(.down)
    }

    static func paint(_ spec: CYWeatherScene.Spec, strength: Double, dark: Bool, time: Double,
                      into context: inout GraphicsContext, size: CGSize) {
        guard size.width > 1, size.height > 1 else { return }
        let m = mix(spec, time: time)
        if m.fog > 0 { paintFog(m.fog * strength, dark: dark, time: time, into: &context, size: size) }
        if m.rain > 0 { paintRain(m.rain, wind: m.wind, strength: strength, dark: dark, time: time, into: &context, size: size) }
        if m.snow > 0 { paintSnow(m.snow, wind: m.wind, strength: strength, dark: dark, time: time, into: &context, size: size) }
        if m.dust > 0 || m.debris > 0 { paintDust(m, strength: strength, dark: dark, time: time, into: &context, size: size) }
        if m.streaks > 0 { paintStreaks(m.streaks, wind: m.wind, strength: strength, dark: dark, time: time, into: &context, size: size) }
        if m.bolt { paintFlash(strength: strength, time: time, into: &context, size: size) }
    }

    /// `weather-core.js` rain: 60 + 100 × intensity drops, 15 px/frame at 60 fps (900 pt/s) × speed 0.6–1.3, slanted.
    static func paintRain(_ amount: Double, wind: Double, strength: Double, dark: Bool, time: Double,
                          into context: inout GraphicsContext, size: CGSize) {
        let count = Int(60 + 100 * amount)
        let slant = 0.17 + 0.12 * wind
        var path = Path()
        for n in 0..<count {
            let speed = 0.6 + 0.7 * seed(n, 1)
            let span = size.height + 40
            let y = (seed(n, 2) * span + time * 900 * speed).truncatingRemainder(dividingBy: span) - 20
            let x = wrap(seed(n, 3) * (size.width + 120) - slant * y, size.width + 120) - 60
            let length = 10 + 10 * speed
            path.move(to: CGPoint(x: x, y: y))
            path.addLine(to: CGPoint(x: x - slant * length, y: y + length))
        }
        context.stroke(path, with: .color(CYWeatherPalette.rain(dark: dark).opacity(0.42 * strength)), lineWidth: 1)
    }

    /// Snow: 40 + 70 × intensity flakes, 1.3 px/frame (78 pt/s) with a sine sway, sizes 1–3 pt.
    static func paintSnow(_ amount: Double, wind: Double, strength: Double, dark: Bool, time: Double,
                          into context: inout GraphicsContext, size: CGSize) {
        let count = Int(40 + 70 * amount)
        var path = Path()
        for n in 0..<count {
            let speed = 0.6 + 0.7 * seed(n, 4)
            let span = size.height + 12
            let y = (seed(n, 5) * span + time * 78 * speed).truncatingRemainder(dividingBy: span) - 6
            let sway = sin(y / 40 + seed(n, 6) * 6) * 14 + wind * y * 0.05
            var x = (seed(n, 7) * size.width + sway).truncatingRemainder(dividingBy: size.width)
            if x < 0 { x += size.width }
            let r = 1 + 2 * seed(n, 8)
            path.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
        }
        context.fill(path, with: .color(CYWeatherPalette.snow(dark: dark).opacity(0.34 * strength + 0.2)))
    }

    /// Fog: three soft bands drifting a few points a second (the MP draws one static veil; the drift is ours).
    static func paintFog(_ amount: Double, dark: Bool, time: Double, into context: inout GraphicsContext, size: CGSize) {
        for band in 0..<3 {
            let drift = sin(time * 0.05 + Double(band) * 2.1) * size.width * 0.12
            let height = size.height * (0.28 + 0.08 * Double(band))
            let rect = CGRect(x: -size.width * 0.25 + drift, y: size.height * (0.12 + 0.3 * Double(band)),
                              width: size.width * 1.5, height: height)
            let shading = GraphicsContext.Shading.radialGradient(
                Gradient(colors: [CYWeatherPalette.fog(dark: dark).opacity(0.22 * amount), CYWeatherPalette.fog(dark: dark).opacity(0)]),
                center: CGPoint(x: rect.midX, y: rect.midY), startRadius: 0, endRadius: rect.width / 2)
            context.fill(Path(ellipseIn: rect), with: shading)
        }
    }

    /// Sand and debris: fast horizontal motes (look-fx `D` / debris), speed from the wind.
    static func paintDust(_ m: Mix, strength: Double, dark: Bool, time: Double, into context: inout GraphicsContext, size: CGSize) {
        let count = Int(30 + 110 * m.dust) + Int(12 * m.debris)
        let speed = 60 + 90 * abs(m.wind)
        let direction: Double = m.wind < 0 ? -1 : 1
        var motes = Path()
        var chips = Path()
        for n in 0..<count {
            let span = size.width + 40
            var x = (seed(n, 9) * span + direction * time * speed * (0.5 + seed(n, 10))).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            x -= 20
            let y = seed(n, 11) * size.height + sin(time * 1.3 + seed(n, 12) * 6) * 6
            if n < count - Int(12 * m.debris) {
                let r = 0.5 + 1.2 * seed(n, 13)
                motes.addEllipse(in: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r))
            } else {
                let s = 2 + 3 * seed(n, 14)
                chips.addRect(CGRect(x: x, y: y, width: s, height: s * 0.6))
            }
        }
        context.fill(motes, with: .color(CYWeatherPalette.dust(dark: dark).opacity((0.18 + 0.25 * m.dust) * strength)))
        context.fill(chips, with: .color(CYWeatherPalette.dust(dark: dark).opacity(0.35 * strength)))
    }

    /// Wind: long faint streaks crossing the screen.
    static func paintStreaks(_ amount: Double, wind: Double, strength: Double, dark: Bool, time: Double,
                             into context: inout GraphicsContext, size: CGSize) {
        let count = Int(4 + 12 * amount)
        let direction: Double = wind < 0 ? -1 : 1
        var path = Path()
        for n in 0..<count {
            let length = 60 + 80 * seed(n, 15)
            let span = size.width + 2 * length
            var x = (seed(n, 16) * span + direction * time * (260 + 140 * seed(n, 17))).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            x -= length
            let y = seed(n, 18) * size.height
            path.move(to: CGPoint(x: x, y: y))
            path.addQuadCurve(to: CGPoint(x: x + length, y: y - 4), control: CGPoint(x: x + length / 2, y: y + 5))
        }
        context.stroke(path, with: .color(CYWeatherPalette.rain(dark: dark).opacity(0.22 * strength)), lineWidth: 1)
    }

    /// Lightning: a short soft flash about every 7–9 s (never a strobe; Reduce Motion never gets here).
    static func paintFlash(strength: Double, time: Double, into context: inout GraphicsContext, size: CGSize) {
        let period = 8.0
        let cycle = floor(time / period)
        let at = seed(Int(cycle), 19) * (period - 1)
        let local = time - cycle * period - at
        guard local >= 0, local < 0.35 else { return }
        let fade = local < 0.08 ? local / 0.08 : max(0, 1 - (local - 0.08) / 0.27)
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color.white.opacity(0.16 * fade * strength)))
    }
}
