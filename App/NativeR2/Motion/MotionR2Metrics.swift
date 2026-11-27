import SwiftUI

// R11 gradients with feelings, R12 flame fill, R14 rank change, R17 clean list load, R18 plan symbol morph.

// MARK: - R11 Mood gradient hero

/// The feeling of a metric; picks the gradient colours.
enum MotionR2Mood {
    case calm, warm, fire

    var colors: [Color] {
        switch self {
        case .calm: return [.teal, .blue, .indigo]
        case .warm: return [.yellow, .orange, .pink]
        case .fire: return [.orange, .red, .pink]
        }
    }

    /// Fire for a full run, warm for most of it, calm otherwise.
    static func forFraction(_ fraction: Double) -> MotionR2Mood {
        fraction >= 0.99 ? .fire : (fraction >= 0.5 ? .warm : .calm)
    }
}

/// R11 background: `MeshGradient` on iOS 18 (3 × 3, the middle point drifts on appear), `LinearGradient` on iOS 17.
/// Reduce Motion / flag off: the mesh does not drift.
struct MotionR2MoodGradient: View {
    let mood: MotionR2Mood
    @State private var drift = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if #available(iOS 18, *) {
                mesh
            } else {
                LinearGradient(colors: mood.colors, startPoint: .topLeading, endPoint: .bottomTrailing)
            }
        }
        .accessibilityHidden(true)
        .onAppear {
            guard MotionR2.live(reduceMotion: reduceMotion) else { return }
            withAnimation(.easeInOut(duration: 3).repeatForever(autoreverses: true)) { drift = true }
        }
    }

    @available(iOS 18, *)
    private var mesh: some View {
        let c = mood.colors
        let middle: SIMD2<Float> = drift ? SIMD2<Float>(0.62, 0.4) : SIMD2<Float>(0.4, 0.58)
        let points: [SIMD2<Float>] = [
            SIMD2<Float>(0, 0), SIMD2<Float>(0.5, 0), SIMD2<Float>(1, 0),
            SIMD2<Float>(0, 0.5), middle, SIMD2<Float>(1, 0.5),
            SIMD2<Float>(0, 1), SIMD2<Float>(0.5, 1), SIMD2<Float>(1, 1),
        ]
        let colors: [Color] = [c[0], c[1], c[2], c[1], c[2], c[0], c[2], c[0], c[1]]
        return MeshGradient(width: 3, height: 3, points: points, colors: colors)
    }
}

/// R11: a huge number over the mood gradient with a caption; the number rolls with `.numericText`.
/// VoiceOver: one element "caption, value".
struct MotionR2MoodHero: View {
    let value: String
    let numericValue: Double
    let captionKey: String
    var mood: MotionR2Mood = .warm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(captionKey))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.85))
            Text(verbatim: value)
                .cyText(.dataXL)
                .monospacedDigit()
                .minimumScaleFactor(0.5)
                .lineLimit(1)
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: numericValue))
                .animation(MotionR2.live(reduceMotion: reduceMotion) ? .smooth(duration: 1.0) : nil, value: numericValue)
        }
        .frame(maxWidth: .infinity, minHeight: 150, alignment: .bottomLeading)
        .padding(20)
        .background { MotionR2MoodGradient(mood: mood) }
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(captionKey)))
        .accessibilityValue(Text(verbatim: value))
        .accessibilityIdentifier("motion2.moodHero")
    }
}

// MARK: - R12 Flame fill

/// R12: an SF Symbol (flame) whose fill level rises with `fraction`; the number next to it rolls.
/// Reduce Motion / flag off: the level is set at once. VoiceOver: "caption, value".
struct MotionR2FillGauge: View {
    let fraction: Double
    let valueText: String
    let captionKey: String
    var systemImage: String = "flame.fill"
    var tint: Color = .orange
    @State private var shown: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 14) {
            symbolFill
                .frame(width: 44, height: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(captionKey)).font(.caption).foregroundStyle(.secondary)
                Text(verbatim: valueText)
                    .font(.title2.bold())
                    .monospacedDigit()
                    .contentTransition(.numericText(value: shown))
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(LocalizedStringKey(captionKey)))
        .accessibilityValue(Text(verbatim: valueText))
        .accessibilityIdentifier("motion2.fillGauge")
        .onAppear { update(fraction) }
        .onChange(of: fraction) { _, value in update(value) }
    }

    private var symbolFill: some View {
        let level = min(1, max(0, shown))
        return Image(systemName: systemImage)
            .resizable()
            .scaledToFit()
            .foregroundStyle(tint.opacity(0.18))
            .overlay {
                Canvas { context, size in
                    let height = size.height * CGFloat(level)
                    context.fill(Path(CGRect(x: 0, y: size.height - height, width: size.width, height: height)),
                                 with: .linearGradient(Gradient(colors: [.yellow, tint, .red]),
                                                       startPoint: CGPoint(x: 0, y: size.height),
                                                       endPoint: CGPoint(x: 0, y: 0)))
                }
                .mask {
                    Image(systemName: systemImage).resizable().scaledToFit()
                }
            }
            .accessibilityHidden(true)
    }

    private func update(_ value: Double) {
        if MotionR2.live(reduceMotion: reduceMotion) {
            withAnimation(.smooth(duration: 1.2)) { shown = value }
        } else {
            shown = value
        }
    }
}

// MARK: - R14 Rank change

/// R14: a rank number that rolls when it changes (`.numericText`), plus an up/down arrow for a moment.
struct MotionR2RankText: View {
    let rank: Int?
    @State private var direction: Int = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            Text(verbatim: rank.map(String.init) ?? "—")
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(rank ?? 0)))
            if direction != 0 {
                Image(systemName: direction < 0 ? "arrow.up" : "arrow.down")
                    .font(.caption.bold())
                    .foregroundStyle(direction < 0 ? Color.green : Color.red)
                    .transition(.opacity)
                    .accessibilityHidden(true)
            }
        }
        .animation(MotionR2.live(reduceMotion: reduceMotion) ? MotionR2.spring : nil, value: rank)
        .onChange(of: rank) { old, new in
            guard let old, let new, old != new else { return }
            direction = new < old ? -1 : 1
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.5))
                withAnimation { direction = 0 }
            }
        }
    }
}

extension View {
    /// R14: rows move with the system spring when the ranking order changes (`ids` in display order).
    func motionR2RankMoves<ID: Hashable>(_ ids: [ID]) -> some View {
        modifier(MotionR2RankMoves(ids: ids))
    }
}

private struct MotionR2RankMoves<ID: Hashable>: ViewModifier {
    let ids: [ID]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(MotionR2.live(reduceMotion: reduceMotion) ? MotionR2.spring : nil, value: ids)
    }
}

// MARK: - R17 Clean list load

/// R17: while `loading`, the content shows as a redacted placeholder (skeleton); when it arrives it fades in.
/// Reduce Motion: the swap is instant. VoiceOver keeps the host's own loading label.
private struct MotionR2LoadIn: ViewModifier {
    let loading: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        if NativeR2Flags.motion2 {
            content
                .redacted(reason: loading ? .placeholder : [])
                .opacity(loading ? 0.6 : 1)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.35), value: loading)
        } else {
            content
        }
    }
}

extension View {
    /// R17: skeleton while loading, fade-in on arrival.
    func motionR2LoadIn(loading: Bool) -> some View { modifier(MotionR2LoadIn(loading: loading)) }
}

// MARK: - R18 Plan symbol morph

/// R18: the plan's symbol morphs (`.contentTransition(.symbolEffect(.replace))`) when the selected plan changes.
/// The symbol is picked by the plan's position (short → long). Reduce Motion: the symbol swaps without the effect.
struct MotionR2PlanSymbol: View {
    let index: Int
    var tint: Color = .accentColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    static let symbols: [String] = ["leaf.fill", "flame.fill", "star.fill", "crown.fill"]

    var body: some View {
        let symbol = Self.symbols[min(max(0, index), Self.symbols.count - 1)]
        Group {
            if MotionR2.live(reduceMotion: reduceMotion) {
                Image(systemName: symbol).contentTransition(.symbolEffect(.replace))
            } else {
                Image(systemName: symbol)
            }
        }
        .font(.title)
        .foregroundStyle(tint)
        .animation(.smooth, value: index)
        .accessibilityHidden(true)
        .accessibilityIdentifier("motion2.planSymbol")
    }
}

#Preview("Motion r2 metrics") {
    List {
        MotionR2MoodHero(value: "5.2 km", numericValue: 5.2, captionKey: "motion2.finish.distance", mood: .fire)
        MotionR2FillGauge(fraction: 0.7, valueText: "7/10", captionKey: "motion2.finish.intensity")
        MotionR2RankText(rank: 3)
        MotionR2PlanSymbol(index: 2)
    }
}
