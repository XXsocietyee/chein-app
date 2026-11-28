import SwiftUI

/// One verdict screen for every game (mini-program `play/components/play-verdict`).
/// Only two outcomes exist: passed, or not passed. A neutral verdict closes a branch choice
/// (no right answer), so it lands without the success colour. Copy is never a rule recap:
/// the fail word is "Time's up" when a time limit ran out, otherwise "Not passed".
struct CYPlayVerdict: Identifiable, Equatable {
    enum Kind: String, Equatable { case win, fail, neutral }
    let id = UUID()
    var kind: Kind
    var timedOut = false
    /// Author feedback line (win or fail). Empty means no line at all.
    var text: String? = nil
    /// Author feedback artwork, at most three.
    var images: [String] = []
}

/// The tint fades in, the mark lands, optional author text and images; one tap anywhere continues (MP: no button).
/// Reduce Motion: the tint appears at rest and the mark fades in.
struct CYPlayVerdictOverlay: View {
    let verdict: CYPlayVerdict
    var closable = true
    let onClose: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @State private var risen = false
    @State private var landed = false

    private var tint: Color {
        switch verdict.kind {
        case .win: return CYNight.verify
        case .fail: return CYNight.ember
        case .neutral: return CYNight.indigo
        }
    }
    private var wordKey: LocalizedStringKey {
        switch verdict.kind {
        case .win, .neutral: return "playVerdict.passed"
        case .fail: return verdict.timedOut ? "playVerdict.timeUp" : "playVerdict.failed"
        }
    }

    var body: some View {
        ZStack {
            CYNight.ink0.opacity(0.92).ignoresSafeArea()
            // MP 2026-11-24 (owner): no liquid, crest or bubbles — the tint only fades in.
            LinearGradient(colors: [tint.opacity(0.45), tint.opacity(0.12), CYNight.ink0.opacity(0)],
                           startPoint: .bottom, endPoint: .top)
                .opacity(risen ? 1 : 0)
                .ignoresSafeArea()
                .accessibilityHidden(true)

            VStack(spacing: CYSpacing.lg) {
                Spacer(minLength: 0)
                mark
                if verdict.kind == .fail {
                    Text(wordKey).cyText(.display).foregroundStyle(.white)
                        .accessibilityIdentifier("playVerdict.word")
                }
                if let text = verdict.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
                    Text(verbatim: text).cyText(.body).foregroundStyle(.white.opacity(0.88))
                        .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                        .accessibilityIdentifier("playVerdict.text")
                }
                if !verdict.images.isEmpty {
                    HStack(spacing: CYSpacing.sm) {
                        ForEach(Array(verdict.images.prefix(3).enumerated()), id: \.offset) { index, url in
                            CYCachedAsyncImage(url, role: .shelf)
                                .clipShape(RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                                .accessibilityLabel(Text("playVerdict.image \(index + 1)"))
                        }
                    }.frame(maxWidth: 360)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, CYSpacing.xxl).padding(.bottom, CYSpacing.xxl)
            .opacity(landed ? 1 : 0)
        }
        .preferredColorScheme(.dark)
        // MP: no Continue button (owner 11-24); one tap anywhere on the screen continues.
        .contentShape(Rectangle())
        .onTapGesture { if closable { onClose() } }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(closable ? [.isModal, .isButton] : [.isModal])
        .accessibilityLabel(Text(wordKey))
        .accessibilityHint(closable ? Text("playVerdict.tapToContinue") : Text(verbatim: ""))
        .accessibilityAction { if closable { onClose() } }
        .accessibilityIdentifier("playVerdict." + verdict.kind.rawValue)
        .cyHapticEvent(verdict.kind == .fail ? .wrongAnswer : .rewardOrMedal, trigger: landed) { _, new in new }
        .onAppear {
            if reduceMotion {
                risen = true
                withAnimation(CYMotion.reduced) { landed = true }
            } else {
                withAnimation(.easeOut(duration: CYMotion.Duration.slow)) { risen = true }
                withAnimation(CYMotion.entrance.delay(CYMotion.Duration.quick)) { landed = true }
            }
        }
    }

    @ViewBuilder private var mark: some View {
        switch verdict.kind {
        case .win:
            ZStack {
                Circle().fill(CYNight.glow(radius: 64)).frame(width: 220, height: 220)
                Image(systemName: "checkmark.seal.fill")
                    .resizable().scaledToFit().fontWeight(.semibold).frame(width: 88, height: 88)
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(CYNight.lanternHot, CYNight.verify)
                    .scaleEffect(landed || reduceMotion ? 1 : 0.6)
            }.accessibilityHidden(true)
        case .neutral:
            // MP: a neutral verdict (a branch choice, no right answer) draws no mark — a seal would read as "correct".
            EmptyView()
        case .fail:
            Image(systemName: verdict.timedOut ? "hourglass.bottomhalf.filled" : "xmark.circle")
                .resizable().scaledToFit().fontWeight(.semibold).frame(width: 72, height: 72).foregroundStyle(.white.opacity(0.9))
                .scaleEffect(landed || reduceMotion ? 1 : 0.7)
                .accessibilityHidden(true)
        }
    }
}

extension View {
    /// Presents the shared verdict over the whole screen. Clearing the binding closes it.
    func cyPlayVerdict(_ verdict: Binding<CYPlayVerdict?>, closable: Bool = true) -> some View {
        fullScreenCover(item: verdict) { value in
            CYPlayVerdictOverlay(verdict: value, closable: closable) { verdict.wrappedValue = nil }
                .presentationBackground(.clear)
        }
    }
}
