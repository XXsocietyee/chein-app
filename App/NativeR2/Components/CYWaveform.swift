import SwiftUI

/// Bar waveform for a voice note or now-playing audio. `levels` are 0...1 (use `placeholderLevels` when the
/// file has none); `progress` tints the played part; `isLive` gently moves the bars while audio plays and stops
/// under Reduce Motion. Decorative: the player control beside it carries the VoiceOver label. Components r1 (C3).
struct CYWaveform: View {
    private let levels: [Double]
    private let progress: Double?
    private let isLive: Bool
    private let tint: Color
    private let barWidth: CGFloat
    @ScaledMetric(relativeTo: .body) private var height: CGFloat = 24
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        levels: [Double],
        progress: Double? = nil,
        isLive: Bool = false,
        tint: Color = CYColor.textPrimary,
        barWidth: CGFloat = 3,
        height: CGFloat = 24
    ) {
        self.levels = levels.map { CYRingMath.clamp($0) }
        self.progress = progress.map { CYRingMath.clamp($0) }
        self.isLive = isLive
        self.tint = tint
        self.barWidth = barWidth
        _height = ScaledMetric(wrappedValue: height, relativeTo: .body)
    }

    var body: some View {
        Group {
            if isLive && !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 15.0)) { context in
                    bars(phase: context.date.timeIntervalSinceReferenceDate)
                }
            } else {
                bars(phase: nil)
            }
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    private func bars(phase: Double?) -> some View {
        HStack(alignment: .center, spacing: barWidth * 0.67) {
            ForEach(levels.indices, id: \.self) { index in
                Capsule()
                    .fill(color(at: index))
                    .frame(width: barWidth, height: barHeight(at: index, phase: phase))
            }
        }
    }

    private func barHeight(at index: Int, phase: Double?) -> CGFloat {
        var level = levels[index]
        if let phase {
            level *= 0.55 + 0.45 * abs(sin(phase * 5 + Double(index) * 0.7))
        }
        return max(barWidth, height * CGFloat(level))
    }

    private func color(at index: Int) -> Color {
        guard let progress, !levels.isEmpty else { return tint }
        let position = Double(index) / Double(levels.count)
        return position < progress ? tint : tint.opacity(0.35)
    }

    /// Deterministic bar levels for audio without a waveform (same seed, same shape).
    static func placeholderLevels(count: Int = 24, seed: Int = 7) -> [Double] {
        guard count > 0 else { return [] }
        var state = UInt64(truncatingIfNeeded: seed &* 2_654_435_761 &+ 1)
        return (0..<count).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Double(state >> 33) / Double(UInt64(1) << 31)
            return 0.25 + 0.75 * unit
        }
    }
}

private struct CYWaveformPreviewBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            CYWaveform(levels: CYWaveform.placeholderLevels())
            CYWaveform(levels: CYWaveform.placeholderLevels(seed: 3), progress: 0.4, tint: CYColor.infoText)
            CYWaveform(levels: CYWaveform.placeholderLevels(count: 32, seed: 11), isLive: true, tint: CYColor.gameAccent)
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
    }
}
#Preview("Waveform · player dark") { CYWaveformPreviewBody().themeDomain(.player) }
