import SwiftUI

// Components r1 · lane C5 social. Channel messages and club community only.
// Presentation only: counts, playback state and authorization come from the existing owners.
// The voice waveform is drawn by lane C3's `CYWaveform`. Counts keep their own Label (see `CYSocialCountLabel`).

/// Voice-note waveform drawn from bars. `samples` is the clip's own level data (`IMVoiceReference.waveform`, base64,
/// at most 256 bytes, recorded on device); it is resampled to `barCount` and normalised. With no usable samples the bars
/// fall back to a stable pattern seeded by the message id (same message, same shape). `progress` (0...1) fills
/// played bars with the bubble ink and dims the rest (CYWaveform), so the shape reads in sent and received bubbles.
/// Decorative: VoiceOver reads the play button and the duration instead.
struct CYSocialVoiceWaveform: View {
    let seed: Int
    var samples: Data? = nil
    var progress: Double = 0
    var barCount = 26

    /// Sent bubbles hand down their own ink (`IMPreviewInk.sent`); the page ink elsewhere.
    @Environment(\.imPreviewInk) private var ink

    /// Drawn by lane C3's `CYWaveform`; C5 only supplies the clip's levels, the played share and the bubble ink.
    var body: some View {
        let levels = CYSocialVoiceWaveform.levels(samples: samples, count: barCount) ?? CYSocialVoiceWaveform.levels(seed: seed, count: barCount)
        CYWaveform(levels: levels.map { Double($0) }, progress: min(max(progress, 0), 1), tint: ink.primary, barWidth: 3, height: 22)
            .accessibilityHidden(true)
    }

    /// Bucket maxima of the recorded levels, scaled to 0.15...1.0. Nil for empty or all-silent data.
    static func levels(samples: Data?, count: Int) -> [CGFloat]? {
        guard let samples, !samples.isEmpty, count > 0 else { return nil }
        let bytes = [UInt8](samples)
        guard let peak = bytes.max(), peak > 0 else { return nil }
        var result: [CGFloat] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            let lower = index * bytes.count / count
            let upper = max(lower + 1, (index + 1) * bytes.count / count)
            let bucket = bytes[lower..<min(upper, bytes.count)].max() ?? 0
            result.append(max(0.15, CGFloat(bucket) / CGFloat(peak)))
        }
        return result
    }

    /// 0.2...1.0 levels; a cheap LCG keeps it deterministic without Foundation randomness.
    static func levels(seed: Int, count: Int) -> [CGFloat] {
        var state = UInt64(truncatingIfNeeded: seed) &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        var result: [CGFloat] = []
        result.reserveCapacity(count)
        for index in 0..<count {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let noise = CGFloat((state >> 33) % 1000) / 1000
            // Taper both ends like a spoken phrase.
            let position = count > 1 ? CGFloat(index) / CGFloat(count - 1) : 0.5
            let envelope = 0.55 + 0.45 * sin(position * .pi)
            result.append(max(0.2, min(1, (0.25 + 0.75 * noise) * envelope)))
        }
        return result
    }
}

/// Like / comment / reaction count: system Label, digits roll with `.numericText`, the symbol swaps
/// (heart → heart.fill) and bounces once when the viewer's own state turns on. Reduce Motion keeps the
/// change instant. A zero count shows `emptyTitle` (MP: 「赞」/「评论」 until there is a count).
/// Not C3's `CYLiveCounter`: that one sets its own text style and tint, which would override the action bar's
/// button tint and font; this keeps the system Label inside the Button.
struct CYSocialCountLabel: View {
    let count: Int
    let symbol: String
    var active = false
    var activeSymbol: String? = nil
    var activeTint: Color = .red
    var emptyTitle: LocalizedStringKey? = nil
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        Label { title } icon: { icon }
            .animation(reduceMotion ? nil : .snappy, value: count)
            .animation(reduceMotion ? nil : .snappy, value: active)
    }

    @ViewBuilder private var title: some View {
        if count > 0 {
            Text(count, format: .number.notation(.compactName))
                .monospacedDigit()
                .contentTransition(.numericText(value: Double(count)))
        } else if let emptyTitle {
            Text(emptyTitle)
        } else {
            Text(0, format: .number).monospacedDigit()
        }
    }

    private var icon: some View {
        Image(systemName: active ? (activeSymbol ?? symbol) : symbol)
            .foregroundStyle(active ? AnyShapeStyle(activeTint) : AnyShapeStyle(ForegroundStyle()))
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, options: .nonRepeating, value: reduceMotion ? false : active)
            .accessibilityHidden(true)
    }
}

/// Played share of a voice note at `date`, for a TimelineView driving `CYSocialVoiceWaveform`.
enum CYSocialVoiceProgress {
    static func fraction(start: Date?, durationMS: Int, at date: Date) -> Double {
        guard let start, durationMS > 0 else { return 0 }
        return min(1, max(0, date.timeIntervalSince(start) * 1000 / Double(durationMS)))
    }
}

#if DEBUG
#Preview("Social components") {
    VStack(alignment: .leading, spacing: 20) {
        CYSocialVoiceWaveform(seed: 42, samples: Data([10, 40, 90, 200, 160, 80, 30, 120, 220, 140, 60, 20]), progress: 0.4)
        CYSocialVoiceWaveform(seed: 7, progress: 0)
        HStack(spacing: 24) {
            CYSocialCountLabel(count: 36, symbol: "heart", active: true, activeSymbol: "heart.fill")
            CYSocialCountLabel(count: 1_200, symbol: "bubble")
            CYSocialCountLabel(count: 0, symbol: "heart", emptyTitle: "club.community.like")
        }
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
