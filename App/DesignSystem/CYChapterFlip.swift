import SwiftUI

/// Chapter opening gate (mini-program `publish/components/chapter-gate` + `play/components/chapter-flip` gate mode):
/// big chapter number, "Chapter N of T", title, optional line, progress bars, "Tap to continue".
/// The gate also continues by itself after a short pause (owner: the gate need not be tapped every chapter).
/// Reduce Motion: no number drop, no auto-advance timer animation, plain cross-fade.
struct CYChapterGate: View {
    /// 0 = prologue.
    let number: Int
    let total: Int
    let title: String?
    var subtitle: String? = nil
    var autoAdvanceAfter: Duration? = .seconds(3)
    let onContinue: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @State private var entered = false
    @State private var leaving = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [CYNight.ink0, CYNight.indigo], startPoint: .top, endPoint: .bottom).ignoresSafeArea()
            VStack(alignment: .leading, spacing: CYSpacing.md) {
                Spacer(minLength: 0)
                Text(verbatim: number == 0 ? "00" : String(format: "%02d", number))
                    .font(.system(size: 120, weight: .heavy, design: .rounded)).monospacedDigit()
                    .foregroundStyle(.white.opacity(0.92))
                    .offset(y: entered || reduceMotion ? 0 : -24)
                    .accessibilityHidden(true)
                Group {
                    if number == 0 { Text("chapterFlip.prologue") }
                    else { Text("chapterFlip.meta \(number) \(max(total, 1))") }
                }
                .cyText(.caption)
                .foregroundStyle(.white.opacity(0.6))
                if let title, !title.isEmpty {
                    Text(verbatim: title).cyText(.pageTitle).foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let subtitle, !subtitle.isEmpty {
                    Text(verbatim: subtitle).cyText(.body).foregroundStyle(.white.opacity(0.72))
                        .lineLimit(4).fixedSize(horizontal: false, vertical: true)
                }
                if number > 0, total > 1 {
                    HStack(spacing: CYSpacing.xs) {
                        ForEach(Array(1...total), id: \.self) { index in
                            Capsule()
                                .fill(index < number ? Color.white.opacity(0.55) : index == number ? CYNight.lantern : Color.white.opacity(0.14))
                                .frame(height: 4)
                        }
                    }.frame(maxWidth: 280).accessibilityHidden(true)
                }
                Spacer(minLength: 0)
                Text("chapterFlip.tapToContinue").cyText(.meta).foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, CYSpacing.xxl).padding(.bottom, CYSpacing.xxl)
            .opacity(entered && !leaving ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text("chapterFlip.tapToContinue"))
        .accessibilityAction { finish() }
        .accessibilityIdentifier("chapterFlip.gate")
        .onAppear { withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance) { entered = true } }
        .task {
            guard let autoAdvanceAfter else { return }
            try? await Task.sleep(for: autoAdvanceAfter)
            if !Task.isCancelled { finish() }
        }
    }

    private func finish() {
        guard !leaving else { return }
        withAnimation(reduceMotion ? CYMotion.reduced : .easeIn(duration: CYMotion.Duration.quick)) { leaving = true }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 220))
            onContinue()
        }
    }
}

/// One figure on a chapter-end or finish screen. `value == nil` renders an em dash.
struct CYStoryStat: Identifiable, Equatable {
    var id: String { key }
    let key: String
    let value: String?
    var systemImage: String? = nil
}

/// Chapter complete (mini-program chapter-flip end card): success mark over the chapter cover tint,
/// "Chapter N complete", chapter name, up to three stats, then "Next stop: …" or Continue.
struct CYChapterEndCard: View {
    let number: Int
    let title: String?
    let stats: [CYStoryStat]
    let nextTitle: String?
    let onContinue: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var shown = false

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            ZStack {
                Circle().fill(CYNight.glow(radius: 48)).frame(width: 156, height: 156)
                Image(systemName: "seal.fill").font(.system(size: 72)).foregroundStyle(CYNight.lantern)
                Image(systemName: "checkmark").font(.system(size: 30, weight: .bold)).foregroundStyle(CYNight.ink0)
            }
            // P39: one burst over the seal. Overlay keeps the seal's size. CYBurst draws nothing under Reduce Motion or Low Power.
            .overlay {
                if shown && !reduceMotion {
                    CYBurst(origin: .center, count: 36, duration: 1.2, style: .confetti, reach: 140)
                }
            }
            .scaleEffect(shown || reduceMotion ? 1 : 0.6)
            .accessibilityHidden(true)
            VStack(spacing: CYSpacing.xs) {
                Text("chapterFlip.complete \(number)").cyText(.caption)
                    .foregroundStyle(.white.opacity(0.66))
                if let title, !title.isEmpty {
                    Text(verbatim: title).cyText(.sectionTitle).foregroundStyle(.white)
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                }
            }
            if !stats.isEmpty {
                // Three columns at the default size. At an accessibility size they stack so a label is not cut to two glyphs.
                if typeSize.isAccessibilitySize {
                    statStrip(axis: .vertical, labelLines: 3)
                } else {
                    statStrip(axis: .horizontal, labelLines: 2)
                }
            }
            Group {
                if let nextTitle, !nextTitle.isEmpty {
                    CYPillButton(verbatim: appLocalized("chapterFlip.nextStop \(nextTitle)", locale: locale), action: onContinue)
                } else {
                    CYPillButton("chapterFlip.continue", action: onContinue)
                }
            }.accessibilityIdentifier("chapterFlip.end.continue")
        }
        .padding(CYSpacing.xl)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [CYNight.ink2, CYNight.indigo], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("chapterFlip.end")
        .onAppear { withAnimation(reduceMotion ? CYMotion.reduced : CYMotion.entrance.delay(0.1)) { shown = true } }
        .cyHaptic(.success, trigger: shown)
    }

    private enum StatAxis { case horizontal, vertical }

    private func statCell(_ stat: CYStoryStat, axis: StatAxis, labelLines: Int) -> some View {
        VStack(spacing: CYSpacing.xxs) {
            Text(verbatim: stat.value ?? "—").cyText(.dataXL).monospacedDigit()
                .foregroundStyle(.white).lineLimit(1).minimumScaleFactor(0.6)
            Text(LocalizedStringKey(stat.key)).cyText(.micro).foregroundStyle(.white.opacity(0.6))
                .lineLimit(labelLines).multilineTextAlignment(axis == .horizontal ? .center : .leading)
        }
        .frame(maxWidth: .infinity, alignment: axis == .horizontal ? .center : .leading)
        .padding(.vertical, CYSpacing.md)
        .background(CYNight.glassFill, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private func statStrip(axis: StatAxis, labelLines: Int) -> some View {
        let shown = Array(stats.prefix(3))
        if axis == .horizontal {
            HStack(spacing: CYSpacing.sm) {
                ForEach(shown) { stat in statCell(stat, axis: axis, labelLines: labelLines) }
            }
        } else {
            VStack(spacing: CYSpacing.sm) {
                ForEach(shown) { stat in statCell(stat, axis: axis, labelLines: labelLines) }
            }
        }
    }
}
