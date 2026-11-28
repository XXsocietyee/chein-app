import SwiftUI
#if canImport(QuestifyCore)
import QuestifyCore
#endif

// `Player/Moment` (427:1433) with its `Moment/Stage` slot (382:1362): object, headline, one line,
// chips, one primary, one link. Beats follow skill-r2 SR2-49: stage at 0 ms, deed 350 ms, seal
// 600 ms, text 950 ms, actions 1 250 ms; tap anywhere jumps to the last beat; under Reduce Motion
// the last beat fades in over 200 ms. VoiceOver hears the headline and the line once.

enum CityMomentBeat: Int, Comparable, CaseIterable {
    case start = 0, stage, seal, text, actions
    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct CityMomentView<Stage: View>: View {
    let headline: String
    let line: String
    /// The maths above a number headline (14 + 3), xrefs-1 B.1 / Figma `Moment` Kicker.
    var kicker: String? = nil
    /// The headline is a number: 48 pt tabular (`cyHeroNumberFont`), rolling in when it lands.
    var numericHeadline = false
    var chips: [String] = []
    let primary: String
    var secondary: String? = nil
    var onPrimary: () -> Void
    var onSecondary: (() -> Void)? = nil
    /// When the stage beat lands (s). 0.35 by default; 圈下了 starts the deed band 250 ms after the photo starts moving.
    var stageDelay: Double = CYMotion.Delay.momentDeed
    /// Presented over a sheet with a clear background: the ground fades in (200 ms) instead of arriving with a slide.
    var fadesInGround = false
    /// The stage reads the current beat to stage its own parts (deed rows, seal, die face).
    @ViewBuilder let stage: (CityMomentBeat) -> Stage

    @State private var beat: CityMomentBeat = .start
    @State private var groundShown = false
    @State private var task: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        GeometryReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: CYSpacing.lg) {
                    stage(beat)
                        .frame(maxWidth: .infinity)
                        // Regular: 52 % of the screen; accessibility sizes: the stage hugs its object (SR2-35 Compact).
                        .frame(minHeight: typeSize.isAccessibilitySize ? 240 : max(240, proxy.size.height * 0.52))
                    VStack(alignment: .leading, spacing: CYSpacing.sm) {
                        if let kicker {
                            Text(verbatim: kicker)
                                .cyText(.numericBody)
                                .foregroundStyle(palette.textSecondary)
                                .accessibilityHidden(true)
                        }
                        headlineText
                            .foregroundStyle(palette.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityAddTraits(.isHeader)
                        Text(verbatim: line)
                            .cyText(.body).foregroundStyle(palette.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .opacity(beat >= .text ? 1 : 0)
                    .offset(y: beat >= .text || reduceMotion ? 0 : 12)
                    if !chips.isEmpty {
                        CityFlowChips(chips: chips, visible: beat >= .text, reduceMotion: reduceMotion)
                    }
                    VStack(spacing: CYSpacing.sm) {
                        CYPillButton(verbatim: primary, action: onPrimary)
                            .accessibilityIdentifier("city.moment.primary")
                        if let secondary, let onSecondary {
                            CYPillButton(verbatim: secondary, style: .tertiary, action: onSecondary)
                                .accessibilityIdentifier("city.moment.secondary")
                        }
                    }
                    .padding(.top, CYSpacing.sm)
                    .opacity(beat >= .actions ? 1 : 0)
                    .allowsHitTesting(beat >= .actions)
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .padding(.vertical, CYSpacing.lg)
                .frame(minHeight: proxy.size.height, alignment: .top)
            }
        }
        .background(palette.bgPage.opacity(!fadesInGround || groundShown ? 1 : 0).ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { skip() }
        .onAppear {
            withAnimation(.easeOut(duration: CYMotion.Duration.quick)) { groundShown = true }
            play()
        }
        .onDisappear { task?.cancel() }
        .accessibilityAction(named: Text(verbatim: primary), onPrimary)
    }

    @ViewBuilder private var headlineText: some View {
        if numericHeadline {
            // The number wins the page (t-hero 48, tabular); it rolls in as the text beat lands.
            Text(verbatim: beat >= .text || reduceMotion ? headline : "0")
                .cyHeroNumberFont()
                .contentTransition(reduceMotion ? .opacity : .numericText(value: Double(headline) ?? 0))
        } else {
            Text(verbatim: headline).cyText(.display)
        }
    }

    private func play() {
        task?.cancel()
        AccessibilityNotification.Announcement(headline + "。" + line).post()
        if reduceMotion {
            withAnimation(CityTokens.reducedFade) { beat = .actions }
            return
        }
        task = Task { @MainActor in
            // Absolute times from the cause (CYMotion.Delay): stage (deed) 350 ms or `stageDelay`, seal 600 ms,
            // text 950 ms, actions 1 250 ms.
            let times: [(CityMomentBeat, Double, Animation)] = [
                (.stage, stageDelay, CYMotion.moment), (.seal, CYMotion.Delay.momentSeal, CYMotion.seal),
                (.text, CYMotion.Delay.momentText, CYMotion.moment), (.actions, CYMotion.Delay.momentActions, CYMotion.moment)
            ]
            var elapsed = 0.0
            let schedule: [(CityMomentBeat, UInt64, Animation)] = times.map { beat, at, animation in
                let wait = max(0, at - elapsed); elapsed = max(elapsed, at)
                return (beat, UInt64(wait * 1000), animation)
            }
            for (next, delay, animation) in schedule {
                if delay > 0 { try? await Task.sleep(nanoseconds: delay * 1_000_000) }
                guard !Task.isCancelled else { return }
                withAnimation(animation) { beat = max(beat, next) }
            }
        }
    }

    private func skip() {
        guard beat < .actions else { return }
        task?.cancel()
        withAnimation(reduceMotion ? CityTokens.reducedFade : CityTokens.deedSpring) { beat = .actions }
    }
}

/// Chips that wrap and stagger in at 0 / 50 / 90 ms (CYMotion.Stagger.chips).
struct CityFlowChips: View {
    let chips: [String]
    let visible: Bool
    let reduceMotion: Bool
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: CYSpacing.sm) { items }
            VStack(alignment: .leading, spacing: CYSpacing.sm) { items }
        }
    }
    private var items: some View {
        ForEach(Array(chips.enumerated()), id: \.offset) { index, chip in
            CityInfoChip(text: chip)
                .opacity(visible ? 1 : 0)
                .offset(y: visible || reduceMotion ? 0 : 8)
                .animation(reduceMotion ? CityTokens.reducedFade : CityTokens.deedSpring.delay(CYMotion.Stagger.delay(index)), value: visible)
        }
    }
}

/// The seal (`Moment/Art` Seal): lands from 1.6× and −24° to 1× and −8° (SR2-49 圈下了 3).
struct CitySeal: View {
    let text: String
    let landed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        Text(verbatim: text)
            .cyText(.cardTitle, weight: .heavy)
            .foregroundStyle(Color.black.opacity(0.75))
            .padding(.horizontal, 14).padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(LinearGradient(colors: [CityTokens.coin, CityTokens.gold], startPoint: .top, endPoint: .bottom))
            )
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.5), lineWidth: 2))
            .rotationEffect(.degrees(landed || reduceMotion ? -8 : -24))
            .scaleEffect(landed || reduceMotion ? 1 : 1.6)
            .opacity(landed ? 1 : 0)
            .shadow(color: .black.opacity(0.35), radius: 10, y: 6)
            .sensoryFeedback(.impact(weight: .heavy), trigger: landed, condition: CYHapticTransition.isOn)
            .accessibilityHidden(true)
    }
}
