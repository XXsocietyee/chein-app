import SwiftUI

// Components r1 · C4 games: the live HUD every game shows above its controls, the countdown clock for the
// countdown kit, and the result-sheet reward moment.
// Apple references: Fitness workout metrics (one row of live values), Clock → Timer (ring that empties),
// Fitness ring close (one spring + ripple at a moment of meaning).
// MP references: `components/cy/play-header` (eyebrow, progress text + track),
// `pages/playkit/components/playkit-countdown` (one clock, remaining time rounds up, empties as time runs),
// `components/cy/result-sheet` (badge springs in → ripple → check; reduced motion = static).
// Values are always the server's (score, tries, hint ladder); nothing is computed on the phone.
// The pills are local until lane C3's `CYStatPill` lands; swap `NativeGameStatPill` for it then.

/// What the HUD shows. Every field is optional; an empty model draws nothing.
struct NativeGameHUDModel: Equatable {
    /// Server `score` / `points`, when the kit reports one before or after the verdict.
    var score: Int? = nil
    /// Server `maxTries` / `maxAttempts` with the used count: "left / cap".
    var triesLeft: Int? = nil
    var triesCap: Int? = nil
    /// Uncapped kits: the server attempt count.
    var attempts: Int? = nil
    /// Hint ladder: layers already revealed (re-viewable) and all layers.
    var hintsUsed: Int? = nil
    var hintsTotal: Int? = nil
    /// "第 n/N 题".
    var progress: NativeGameProgress? = nil

    var isEmpty: Bool {
        score == nil && triesCap == nil && attempts == nil && hintsTotal == nil && progress == nil
    }

    /// Hint counts from the ladder; nil when the ladder has no layers.
    @MainActor static func hints(_ model: PlayHelpLadderModel?) -> (used: Int, total: Int)? {
        guard let model, model.enabled, !model.rows.isEmpty else { return nil }
        let used = model.rows.filter { $0.state == .review }.count
        return (used, model.rows.count)
    }
}

/// One row of stat pills (score, tries, hints, progress) and a thin progress bar for multi-question kits.
/// Dynamic Type: the row wraps into two lines through `ViewThatFits`, then into a vertical stack.
@MainActor struct NativeGameHUD: View {
    let model: NativeGameHUDModel
    @Environment(\.locale) private var locale

    var body: some View {
        if !model.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) { pills }
                    VStack(alignment: .leading, spacing: 8) { pills }
                }
                if let progress = model.progress {
                    ProgressView(value: Double(min(progress.current, progress.total)), total: Double(max(1, progress.total)))
                        .accessibilityHidden(true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("nativeGames.hud.label"))
            .accessibilityIdentifier("nativeGames.hud")
        }
    }

    @ViewBuilder private var pills: some View {
        if let score = model.score {
            NativeGameStatPill(systemImage: "star.fill", label: Text("nativeGames.hud.score"),
                               value: Text(verbatim: score.formatted(.number.locale(locale))), numeric: Double(score))
                .accessibilityIdentifier("nativeGames.hud.score")
        }
        if let progress = model.progress {
            NativeGameStatPill(systemImage: "list.number", label: Text("nativeGames.hud.progress"),
                               value: Text(verbatim: "\(progress.current)/\(progress.total)"), numeric: Double(progress.current))
                .accessibilityValue(Text("nativeGames.progress \(progress.current) \(progress.total)"))
                .accessibilityIdentifier("nativeGames.progress")
        }
        if let cap = model.triesCap, let left = model.triesLeft {
            NativeGameStatPill(systemImage: "arrow.counterclockwise", label: Text("playkit.triesLeft"),
                               value: Text(verbatim: "\(left)/\(cap)"), numeric: Double(left),
                               tint: left <= 1 ? .orange : nil)
                .accessibilityIdentifier("playkit.triesLeft")
        } else if let attempts = model.attempts {
            NativeGameStatPill(systemImage: "arrow.counterclockwise", label: Text("playkit.attempts"),
                               value: Text(verbatim: String(attempts)), numeric: Double(attempts))
                .accessibilityIdentifier("nativeGames.hud.attempts")
        }
        if let total = model.hintsTotal, let used = model.hintsUsed {
            NativeGameStatPill(systemImage: "lightbulb.fill", label: Text("nativeGames.hud.hints"),
                               value: Text(verbatim: "\(used)/\(total)"), numeric: Double(used))
                .accessibilityIdentifier("nativeGames.hud.hints")
        }
    }
}

/// Capsule: SF Symbol, caption label, rolling value. VoiceOver reads "label, value".
@MainActor struct NativeGameStatPill: View {
    let systemImage: String
    let label: Text
    let value: Text
    let numeric: Double
    var tint: Color? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(tint.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.tint))
                .accessibilityHidden(true)
            label
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            valueText
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.fill.tertiary, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }

    @ViewBuilder private var valueText: some View {
        let base = value
            .font(.subheadline.weight(.semibold))
            .monospacedDigit()
            .lineLimit(1)
        if reduceMotion || !NativeR2Flags.motion {
            base
        } else {
            base
                .contentTransition(.numericText(value: numeric))
                .animation(.smooth, value: numeric)
        }
    }
}

/// The countdown kit's clock once the server acknowledged START_CHALLENGE: remaining time counts down by
/// itself (`Text(timerInterval:countsDown:)`) over a ring that empties (`ProgressView(timerInterval:)`).
/// Display only: the server decides when the countdown is done (`SUBMIT_COUNTDOWN` carries no number).
@MainActor struct NativeGameCountdownClock: View {
    let start: Date
    let seconds: Double

    private var interval: ClosedRange<Date> { start...start.addingTimeInterval(max(1, seconds)) }

    var body: some View {
        VStack(spacing: 12) {
            Text(timerInterval: interval, countsDown: true)
                .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
            ProgressView(timerInterval: interval, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                .accessibilityHidden(true)
        }
        .accessibilityIdentifier("nativeGames.countdown.clock")
    }

    /// For the enclosing element's VoiceOver value: a live remaining-time text.
    static func accessibilityValue(start: Date, seconds: Double) -> Text {
        Text(timerInterval: start...start.addingTimeInterval(max(1, seconds)), countsDown: true)
    }
}

/// Result-sheet reward moment for a fresh pass (MP result-sheet: badge springs in → one ripple → settle).
/// Reduce Motion or the motion flag off: the badge is shown still; the success haptic and announcement stay
/// in the shell either way.
@MainActor struct NativeGameRewardBadge: View {
    let systemImage: String
    let passed: Bool
    /// Bumped by the shell when the sheet is on screen.
    let trigger: Int
    @State private var landed = false
    @State private var ripple = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var animates: Bool { passed && NativeR2Flags.motion && !reduceMotion }

    var body: some View {
        ZStack {
            if animates {
                Circle()
                    .stroke(.tint, lineWidth: 3)
                    .frame(width: 72, height: 72)
                    .scaleEffect(ripple ? 1.9 : 0.8)
                    .opacity(ripple ? 0 : 0.6)
                    .accessibilityHidden(true)
            }
            Image(systemName: systemImage)
                .font(.largeTitle)
                .imageScale(.large)
                .foregroundStyle(passed ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                .symbolEffect(.bounce, value: animates ? trigger : 0)
                .scaleEffect(animates && !landed ? 0.4 : 1)
                .accessibilityHidden(true)
        }
        .frame(height: 96)
        .onChange(of: trigger) { _, _ in play() }
    }

    private func play() {
        guard animates else { landed = true; return }
        landed = false; ripple = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.55)) { landed = true }
        withAnimation(.easeOut(duration: 0.9).delay(0.12)) { ripple = true }
    }
}

#Preview("HUD") {
    List {
        Section {
            NativeGameHUD(model: NativeGameHUDModel(score: 120, triesLeft: 1, triesCap: 3, hintsUsed: 1, hintsTotal: 3,
                                                    progress: NativeGameProgress(current: 2, total: 5)))
        }
        Section {
            NativeGameCountdownClock(start: .now, seconds: 90)
        }
        Section {
            NativeGameRewardBadge(systemImage: "checkmark.seal.fill", passed: true, trigger: 1)
        }
    }
}
