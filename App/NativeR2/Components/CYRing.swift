import SwiftUI

/// Circular progress ring (city revealed %, clue progress, passport completion). The centre defaults to the
/// percentage with a `.numericText` transition; pass any view to replace it. VoiceOver reads one element:
/// `label`, value = percent. Animation follows Reduce Motion. Components r1 (C3).
struct CYRing<Center: View>: View {
    private let progress: Double
    private let tint: Color
    private let lineWidth: CGFloat
    private let labelKey: LocalizedStringKey
    private let center: Center
    @ScaledMetric private var diameter: CGFloat
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        progress: Double,
        label: LocalizedStringKey = "comp.kit.ring.progress",
        tint: Color = CYColor.textPrimary,
        diameter: CGFloat = 56,
        lineWidth: CGFloat = 6,
        @ViewBuilder center: () -> Center
    ) {
        self.progress = CYRingMath.clamp(progress)
        self.labelKey = label
        self.tint = tint
        self.lineWidth = lineWidth
        self.center = center()
        _diameter = ScaledMetric(wrappedValue: diameter, relativeTo: .body)
    }

    var body: some View {
        ZStack {
            track
            arc
            center
                .padding(lineWidth)
        }
        .frame(width: diameter, height: diameter)
        .animation(reduceMotion ? nil : .smooth, value: progress)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(labelKey))
        .accessibilityValue(Text(progress, format: .percent.precision(.fractionLength(0))))
    }

    private var track: some View {
        Circle()
            .stroke(tint.opacity(0.18), lineWidth: lineWidth)
    }

    private var arc: some View {
        Circle()
            .trim(from: 0, to: progress)
            .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
    }
}

extension CYRing where Center == CYRingPercentLabel {
    /// Ring with the percentage in the centre.
    init(
        progress: Double,
        label: LocalizedStringKey = "comp.kit.ring.progress",
        tint: Color = CYColor.textPrimary,
        diameter: CGFloat = 56,
        lineWidth: CGFloat = 6
    ) {
        let value = CYRingMath.clamp(progress)
        self.init(progress: value, label: label, tint: tint, diameter: diameter, lineWidth: lineWidth) {
            CYRingPercentLabel(progress: value)
        }
    }
}

/// The default ring centre: `42%`, monospaced, shrinks to fit the ring.
struct CYRingPercentLabel: View {
    let progress: Double

    var body: some View {
        Text(progress, format: .percent.precision(.fractionLength(0)))
            .cyText(.micro, monospacedDigit: true)
            .foregroundStyle(CYColor.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .contentTransition(.numericText(value: progress))
    }
}

enum CYRingMath {
    /// 0...1; NaN and infinities become 0.
    static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }

    /// `part / total` as 0...1 (0 when `total` is 0).
    static func fraction(_ part: Int, of total: Int) -> Double {
        guard total > 0 else { return 0 }
        return clamp(Double(part) / Double(total))
    }
}

private struct CYRingPreviewBody: View {
    var body: some View {
        HStack(spacing: CYSpacing.lg) {
            CYRing(progress: 0.42)
            CYRing(progress: 0.8, tint: CYColor.gameAccent, diameter: 72, lineWidth: 8)
            CYRing(progress: 1, tint: CYColor.successText) {
                Image(systemName: "checkmark")
                    .font(.headline)
                    .foregroundStyle(CYColor.successText)
                    .accessibilityHidden(true)
            }
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
    }
}
#Preview("Ring · player dark") { CYRingPreviewBody().themeDomain(.player) }
