import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// `City/Odds Bar` (421:1585) and the d20 of `Moment/Art` (382:1118). Owner defaults Q2 and Q7:
// the die is a 2D illustrated d20, thrown by a flick on the die or a tap on 掷骰. No shake.

/// Twenty segments; the faces that win are filled. One accessibility element (SR2 mapping table).
struct CityOddsBar: View {
    /// Lowest natural face that wins (d20 + mod ≥ DC, nat 20 always wins, nat 1 always loses).
    let needFace: Int
    var modifiers: [String] = []
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    private var winFaces: Int { max(1, min(19, 21 - max(2, needFace))) }
    private var percent: Int { winFaces * 5 }

    var body: some View {
        let copy = CityCopy(locale: locale)
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(verbatim: copy("需要掷出 ≥ \(max(2, min(20, needFace)))", "Roll ≥ \(max(2, min(20, needFace)))"))
                .cyText(.sectionTitle).foregroundStyle(palette.textPrimary)
            HStack(spacing: 3) {
                ForEach(1...20, id: \.self) { face in
                    let wins = face >= 21 - winFaces
                    Capsule()
                        .fill(wins ? palette.textPrimary : palette.textPrimary.opacity(0.16))
                        .overlay { if differentiate && wins { Capsule().strokeBorder(palette.bgPage, lineWidth: 1) } }
                        .frame(height: 12)
                }
            }
            Text(verbatim: copy("20 面骰 · \(winFaces) 个面能赢（\(percent)%）", "d20 · \(winFaces) winning faces (\(percent)%)"))
                .cyText(.caption, monospacedDigit: true).foregroundStyle(palette.textSecondary)
            if !modifiers.isEmpty {
                HStack(spacing: CYSpacing.sm) { ForEach(modifiers, id: \.self) { CityInfoChip(text: $0) } }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: copy("胜率", "Odds")))
        .accessibilityValue(Text(verbatim: copy("20 面里 \(winFaces) 面能赢，百分之 \(percent)", "\(winFaces) of 20 faces win, \(percent) percent")))
    }

    /// The face the player needs: `DC − mod`, clamped to the natural-roll rules.
    static func needFace(dc: Int, mod: Int) -> Int { min(20, max(2, dc - mod)) }
}

/// The d20, drawn: a gold icosahedron silhouette with facets and the face numeral.
struct CityD20Art: View {
    /// The face on top; nil while it tumbles (motion streaks instead of a numeral, SR2-26).
    var face: Int?
    var lost = false
    var size: CGFloat = 132

    var body: some View {
        ZStack {
            hexagon.fill(LinearGradient(colors: lost ? [CYCityPalette.lostTop, CYCityPalette.lostBottom] : [CityTokens.coin, CityTokens.gold],
                                        startPoint: .top, endPoint: .bottom))
            facets.stroke(Color.black.opacity(0.22), lineWidth: max(1, size / 90))
            hexagon.stroke(Color.white.opacity(0.35), lineWidth: max(1, size / 70))
            if let face {
                Text(verbatim: String(face))
                    .cyText(.dataXL)
                    .lineLimit(1)
                    .minimumScaleFactor(0.3)
                    .foregroundStyle(Color.black.opacity(0.78))
                    .frame(width: size * 0.5)
                    .contentTransition(.numericText(value: Double(face)))
            }
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.45), radius: size / 10, y: size / 18)
        .accessibilityHidden(true)
    }

    private var hexagon: Path {
        Path { path in
            let r = size / 2, c = CGPoint(x: r, y: r)
            for i in 0..<6 {
                let angle = Double(i) * .pi / 3 - .pi / 2
                let point = CGPoint(x: c.x + r * CGFloat(cos(angle)), y: c.y + r * CGFloat(sin(angle)))
                i == 0 ? path.move(to: point) : path.addLine(to: point)
            }
            path.closeSubpath()
        }
    }

    private var facets: Path {
        Path { path in
            let r = size / 2, c = CGPoint(x: r, y: r)
            func vertex(_ i: Int) -> CGPoint {
                let angle = Double(i) * .pi / 3 - .pi / 2
                return CGPoint(x: c.x + r * CGFloat(cos(angle)), y: c.y + r * CGFloat(sin(angle)))
            }
            // The upward central triangle and its spokes to the outer vertices.
            let top = CGPoint(x: c.x, y: c.y - r * 0.42)
            let left = CGPoint(x: c.x - r * 0.48, y: c.y + r * 0.36)
            let right = CGPoint(x: c.x + r * 0.48, y: c.y + r * 0.36)
            path.move(to: top); path.addLine(to: left); path.addLine(to: right); path.closeSubpath()
            for (inner, outer) in [(top, 0), (top, 1), (top, 5), (left, 4), (left, 3), (left, 5), (right, 2), (right, 3), (right, 1)] {
                path.move(to: inner); path.addLine(to: vertex(outer))
            }
        }
    }
}

/// The throwable die (`MomentView(.ready)`): follows the finger, a flick throws it; under
/// 300 pt/s it springs back. Tap 掷骰 does the same. VoiceOver gets a plain action.
struct CityThrowableDie: View {
    let enabled: Bool
    let onThrow: () -> Void
    @State private var drag: CGSize = .zero
    @State private var spin: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    var body: some View {
        CityD20Art(face: 20, size: 148)
            .rotationEffect(.degrees(spin))
            .offset(drag)
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        guard enabled else { return }
                        drag = value.translation
                        spin = Double(value.translation.width) / 3
                    }
                    .onEnded { value in
                        guard enabled else { return }
                        let speed = hypot(value.velocity.width, value.velocity.height)
                        withAnimation(reduceMotion ? CityTokens.reducedFade : CityTokens.sealSpring) { drag = .zero; spin = 0 }
                        if speed >= 300 { onThrow() }
                    }
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: CityCopy(locale: locale)("二十面骰", "Twenty-sided die")))
            .accessibilityHint(Text(verbatim: CityCopy(locale: locale)("甩出去或点「掷骰」", "Flick it, or tap Roll")))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { if enabled { onThrow() } }
    }
}

/// A tumbling die while the server rolls: rotation driven by time, no numeral (SR2-26, N37).
struct CityTumblingDie: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        if reduceMotion {
            CityD20Art(face: nil, size: 148).opacity(0.85)
        } else {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                CityD20Art(face: nil, size: 148)
                    .rotationEffect(.degrees((t * 540).truncatingRemainder(dividingBy: 360)))
                    .scaleEffect(1 + 0.06 * sin(t * 9))
                    .blur(radius: 1.2)
            }
        }
    }
}
