import SwiftUI

@MainActor struct PlayKitTimedChallengeView: View {
    let kind: PlayKitScreenKind; let segment: PlayWireValue
    let enabled: Bool; let active: Bool; let onDirty: () -> Void; let requestReview: PlayKitReviewRequest
    let revisionIdentity: String
    let currentRevisionIdentity: (() -> String)?
    @State private var expectedRevision = ""
    @State private var timing = PlayKitTimingRun()
    @State private var reaction: PlayKitReactionRun
    @State private var elapsed = 0
    @State private var input = ""
    @State private var ticker = UUID()
    @State private var mounted = false
    @State private var expired = false
    @FocusState private var typingFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale
    init(kind: PlayKitScreenKind, segment: PlayWireValue, enabled: Bool, active: Bool, onDirty: @escaping () -> Void, requestReview: @escaping PlayKitReviewRequest, revisionIdentity: String = "", currentRevisionIdentity: (() -> String)? = nil) {
        self.kind = kind; self.segment = segment; self.enabled = enabled; self.active = active; self.onDirty = onDirty; self.requestReview = requestReview
        self.revisionIdentity = revisionIdentity; self.currentRevisionIdentity = currentRevisionIdentity
        _reaction = State(initialValue: PlayTimedReactionConfiguration.makeRun(segment: segment))
    }
    private var seconds: Double { segment[kind == .stopwatch ? "targetSeconds" : "seconds"].double ?? 0 }
    private var running: Bool { timing.phase == .running || [.waiting, .signal].contains(reaction.phase) }
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.lg) {
            CYHeroHeader(LocalizedStringKey("playkit.kind." + kind.rawValue))
            if kind == .reaction { reactionStage }
            else { timedStage }
            if kind == .stopwatch || kind == .reaction {
                // Mini-program footnote: a device reading for fun; backgrounding interrupts the local clock.
                Text("playkit.challenge.localNotice").font(CYTypography.meta).foregroundStyle(CYColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityIdentifier("playkit.challenge.localNotice")
            }
            if timing.phase == .interrupted || reaction.phase == .interrupted {
                CYStatusChip("playkit.challenge.interrupted", tone: .warning, systemImage: "pause.circle")
            }
            if expired { CYStatusChip("playkit.challenge.expired", tone: .danger) }
            if running {
                Button("playkit.challenge.abort", role: .destructive) { interrupt() }
                    .buttonStyle(CYPillButtonStyle(style: .secondary))
            }
        }
        .padding(CYSpacing.pageHorizontal)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .cyDomainPageBackground()
        .themeDomain(.player)
        .tint(CYDomainPalette(.player).brand)
        .onAppear { mounted = true; expectedRevision = currentRevisionIdentity?() ?? revisionIdentity }
        .task(id: ticker) {
            while mounted && active && running && !Task.isCancelled {
                let now = ProcessInfo.processInfo.systemUptime
                if kind == .reaction { reaction.tick(now: now) }
                else if kind == .countdown {
                    // `seconds` is a duration, not a server instant. Do not finish from the device clock.
                } else {
                    elapsed = timing.elapsed(now: now)
                    if kind == .typeIn, seconds > 0, elapsed >= Int(seconds * 1000) { timing.measure(now: now); typingFocused = false; expired = true }
                    if kind == .stopwatch, elapsed > Int((max(0, seconds) + 30) * 1000) { interrupt(); expired = true }
                }
                do { try await Task.sleep(for: .milliseconds(20)) } catch { break }
            }
        }
        .onChange(of: revisionIdentity) { _, next in
            if !expectedRevision.isEmpty && next != expectedRevision {
                interrupt(); timing = PlayKitTimingRun(); reaction = PlayTimedReactionConfiguration.makeRun(segment: segment)
                elapsed = 0; input = ""; expectedRevision = next
            }
        }
        .onChange(of: active) { _, value in if !value { interrupt() } }
        .onChange(of: scenePhase) { _, value in if value != .active { interrupt() } }
        .onDisappear { mounted = false; interrupt() }
    }
    @ViewBuilder private var timedStage: some View {
        if seconds > 0 { LabeledContent("playkit.challenge.target") { Text(verbatim: PlayTimedDisplayLocalization.seconds(seconds, locale: locale)).monospacedDigit() } }
        if kind == .stopwatch, let tolerance = segment["toleranceMs"].integer { LabeledContent("playkit.stopwatch.tolerance") { Text(verbatim: PlayTimedDisplayLocalization.tolerance(tolerance, locale: locale)) } }
        if kind == .typeIn {
            Text(verbatim: segment["target"].text ?? "").font(.title2.monospaced().bold()).textSelection(.disabled)
                .frame(maxWidth: .infinity).padding(CYSpacing.lg)
                .background(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous).fill(CYColor.bgRaised))
            if seconds > 0 {
                Text("playkit.type.goalLine \(PlayTimedDisplayLocalization.seconds(seconds, locale: locale))")
                    .font(CYTypography.body).foregroundStyle(CYColor.textSecondary).frame(maxWidth: .infinity)
            }
            Text(segment["caseSensitive"].bool == true ? "playkit.type.caseSensitive" : "playkit.type.caseInsensitive").font(.footnote)
            TextField("playkit.type.input", text: $input, axis: .vertical)
                .textFieldStyle(.roundedBorder).textInputAutocapitalization(.never).autocorrectionDisabled()
                .focused($typingFocused).disabled(timing.phase != .running || !enabled)
                .onChange(of: input) { _, value in if value.count > 4096 { input = String(value.prefix(4096)) }; onDirty() }
            if let attempts = segment["attempts"].integer, attempts >= 0 { LabeledContent("playkit.attempts") { Text(verbatim: PlayTimedDisplayLocalization.count(attempts, locale: locale)) } }
            if let cap = segment["tries"].integer, cap > 0 { LabeledContent("playkit.attemptLimit") { Text(verbatim: PlayTimedDisplayLocalization.count(cap, locale: locale)) } }
            if let result = PlayKitScreenProjection(kind: kind, segment: segment).typeInResultKey {
                Text(LocalizedStringKey(result)).accessibilityIdentifier("playkit.type.result")
            }
        }
        ZStack {
            Circle().stroke(CYColor.bgRaised, lineWidth: 14)
            Circle().trim(from: 0, to: clockProgress).stroke(timing.phase == .measured ? (resultTone ?? CYColor.textPrimary) : CYColor.textPrimary, style: StrokeStyle(lineWidth: 14, lineCap: .round))
                .rotationEffect(.degrees(-90)).animation(.linear(duration: 0.05), value: clockProgress)
            Text(verbatim: clockLabel).font(.system(size: 76, weight: .bold, design: .rounded)).monospacedDigit()
                .foregroundStyle(CYColor.textPrimary).minimumScaleFactor(0.5).lineLimit(1).padding(CYSpacing.xl)
        }
        .frame(maxWidth: 300).aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
        .sensoryFeedback(.impact(weight: .medium), trigger: timing.phase == .running)
        .sensoryFeedback(trigger: timing.phase == .measured) { _, now in now ? (stopwatchOutcome == false ? .warning : .success) : nil }
        .accessibilityElement(children: .ignore)
        .accessibilityValue(Text(verbatim: clockLabel))
        .accessibilityLabel(Text(kind == .stopwatch && running && elapsed >= 1000 ? "playkit.stopwatch.hidden" : "playkit.challenge.clock"))
        if timing.phase == .idle || timing.phase == .interrupted {
            CYPillButton("playkit.challenge.start") { start() }
                .disabled(!enabled || !validConfiguration).accessibilityIdentifier("playkit.challenge.start")
        }
        if timing.phase == .running && kind != .countdown {
            CYPillButton(kind == .stopwatch ? "playkit.stopwatch.stop" : "playkit.type.finish") {
                timing.measure(now: ProcessInfo.processInfo.systemUptime); elapsed = timing.elapsedMilliseconds; typingFocused = false
            }.disabled(!enabled).accessibilityIdentifier("playkit.challenge.measure")
        }
        if timing.phase == .measured, kind == .stopwatch, let card = stopwatchCard { card }
        if timing.phase == .measured {
            CYPillButton("playkit.review") { reviewMeasurement() }
                .disabled(!enabled || (kind == .typeIn && input.isEmpty)).accessibilityIdentifier("playkit.challenge.submit")
        }
        if !validConfiguration { CYEmptyState(systemImage: "exclamationmark.triangle", "playkit.configurationInvalid") }
    }
    /// Local pre-review readout only; the server still grades the submission. Unknown tolerance gives a neutral card, never a verdict.
    private var stopwatchOutcome: Bool? {
        guard kind == .stopwatch, timing.phase == .measured, let tolerance = segment["toleranceMs"].integer else { return nil }
        return abs(timing.elapsedMilliseconds - Int(seconds * 1000)) <= tolerance
    }
    private var resultTone: Color? {
        guard let outcome = stopwatchOutcome else { return nil }
        return outcome ? CYColor.successText : CYColor.warningText
    }
    private var stopwatchCard: PlayTimedResultCard? {
        let stopped = timing.elapsedMilliseconds, diff = stopped - Int(seconds * 1000)
        return PlayTimedResultCard(outcome: stopwatchOutcome,
            value: PlayTimedDisplayLocalization.seconds(Double(stopped) / 1000, locale: locale),
            target: PlayTimedDisplayLocalization.seconds(seconds, locale: locale),
            delta: (diff >= 0 ? "+" : "−") + PlayTimedDisplayLocalization.seconds(Double(abs(diff)) / 1000, locale: locale))
    }
    private var validConfiguration: Bool {
        if kind == .reaction { return true }
        if kind == .typeIn { return seconds.isFinite && seconds >= 0 && seconds <= 3600 && !(segment["target"].text ?? "").isEmpty }
        return seconds.isFinite && seconds > 0 && seconds <= 3600
    }
    /// Type-in still drains from its local measurement. The countdown has no server instant, so its ring stays empty.
    private var clockProgress: CGFloat {
        if kind == .countdown { return 0 }
        guard kind == .typeIn, seconds > 0 else { return 1 }
        return CGFloat(max(0, min(1, 1 - Double(elapsed) / (seconds * 1000))))
    }
    private var clockLabel: String {
        if kind == .stopwatch && timing.phase == .running && elapsed >= 1000 { return "—.—" }
        if kind == .countdown { return "—" }
        if kind == .typeIn {
            if seconds <= 0 { return PlayTimedDisplayLocalization.seconds(Double(elapsed) / 1000, locale: locale) }
            return PlayTimedDisplayLocalization.seconds(max(0, seconds - Double(elapsed) / 1000), precision: .tenths, locale: locale)
        }
        return PlayTimedDisplayLocalization.seconds(Double(elapsed) / 1000, locale: locale)
    }
    @ViewBuilder private var reactionStage: some View {
        LabeledContent("playkit.reaction.round") { Text(verbatim: PlayTimedDisplayLocalization.round(current: reaction.roundsMilliseconds.count, total: reaction.rounds, locale: locale)).monospacedDigit() }
        if let goal = segment["goalMs"].integer, goal > 0 { LabeledContent("playkit.reaction.goal") { Text(verbatim: PlayTimedDisplayLocalization.milliseconds(goal, locale: locale)) } }
        if reaction.phase == .idle || reaction.phase == .interrupted {
            VStack(spacing: CYSpacing.lg) {
                Image(systemName: "hand.tap.fill").font(.system(size: 44, weight: .semibold)).foregroundStyle(CYColor.textSecondary)
                Text(verbatim: ChannelCopy.text("圆圈变绿时立刻点按，别抢跑。", "Tap the circle the moment it turns green. Don't jump the gun.", locale: locale))
                    .font(CYTypography.body).foregroundStyle(CYColor.textPrimary).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 10) {
                    ForEach(0..<min(reaction.rounds, 10), id: \.self) { index in
                        Circle().fill(index < reaction.roundsMilliseconds.count ? CYColor.successText : CYColor.bgRaised).frame(width: 12, height: 12)
                    }
                }.accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity).padding(CYSpacing.xl)
            .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
            CYPillButton("playkit.challenge.start") { start() }.disabled(!enabled)
        } else if reaction.phase == .waiting || reaction.phase == .signal {
            Button {
                reaction.tap(now: ProcessInfo.processInfo.systemUptime); onDirty()
            } label: {
                let go = reaction.phase == .signal
                ZStack {
                    Circle().fill(go ? CYColor.successText : CYColor.bgElevated)
                    Circle().strokeBorder(go ? Color.white.opacity(0.5) : CYColor.borderStrong, lineWidth: 4)
                    VStack(spacing: CYSpacing.sm) {
                        Image(systemName: go ? "hand.tap.fill" : "hourglass").font(.system(size: 44, weight: .semibold))
                        Text(go ? "playkit.reaction.tap" : "playkit.reaction.wait").font(CYTypography.sectionTitle)
                    }.foregroundStyle(go ? Color.black : CYColor.textSecondary).padding(CYSpacing.lg)
                }
                .frame(maxWidth: 300).aspectRatio(1, contentMode: .fit).frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.impact(weight: .heavy), trigger: reaction.phase == .signal)
            .disabled(!enabled).accessibilityIdentifier("playkit.reaction.target")
        } else if reaction.phase == .early || reaction.phase == .betweenRounds {
            if reaction.phase == .early { CYStatusChip("playkit.reaction.early", tone: .warning, systemImage: "exclamationmark.circle") }
            CYPillButton("playkit.reaction.next", style: .secondary) { reaction.arm(now: ProcessInfo.processInfo.systemUptime, randomUnit: Double.random(in: 0...1)); ticker = UUID() }.disabled(!enabled)
        }
        ForEach(Array(reaction.roundsMilliseconds.enumerated()), id: \.offset) { index, ms in
            HStack { Text(verbatim: PlayTimedDisplayLocalization.count(index + 1, locale: locale)); Spacer(); Text(verbatim: PlayTimedDisplayLocalization.milliseconds(ms, locale: locale)).monospacedDigit() }
        }
        if reaction.phase == .measured, !reaction.roundsMilliseconds.isEmpty {
            let avg = reaction.roundsMilliseconds.reduce(0, +) / reaction.roundsMilliseconds.count
            let goal = segment["goalMs"].integer.flatMap { $0 > 0 ? $0 : nil }
            PlayTimedResultCard(outcome: goal.map { avg <= $0 }, value: PlayTimedDisplayLocalization.milliseconds(avg, locale: locale),
                                target: goal.map { PlayTimedDisplayLocalization.milliseconds($0, locale: locale) }, delta: nil)
                .sensoryFeedback(.success, trigger: reaction.phase == .measured)
        }
        if reaction.phase == .measured {
            CYPillButton("playkit.review") { requestReview("SUBMIT_REACTION", ["times": .array(reaction.roundsMilliseconds.map(PlayWireValue.int))], {}) }
                .disabled(!enabled)
        }
    }
    private func start() {
        guard enabled, validConfiguration else { return }
        requestReview("START_CHALLENGE", ["game": .string(kind.rawValue)]) {
            guard mounted, active, scenePhase == .active else { return }
            expectedRevision = currentRevisionIdentity?() ?? revisionIdentity
            expired = false; onDirty()
            if kind == .reaction { reaction.beginAfterAcknowledgement(now: ProcessInfo.processInfo.systemUptime, randomUnit: Double.random(in: 0...1)) }
            else { input = ""; elapsed = 0; timing.beginAfterAcknowledgement(now: ProcessInfo.processInfo.systemUptime); typingFocused = kind == .typeIn }
            ticker = UUID()
        }
    }
    private func reviewMeasurement() {
        guard timing.phase == .measured else { return }
        switch kind {
        case .countdown: requestReview("SUBMIT_COUNTDOWN", [:], {})
        case .stopwatch: requestReview("SUBMIT_STOPWATCH", ["stoppedMs": .int(timing.elapsedMilliseconds)], {})
        case .typeIn: requestReview("SUBMIT_TYPE_IN", ["text": .string(input), "elapsedMs": .int(timing.elapsedMilliseconds)], {})
        default: break
        }
    }
    private func interrupt() {
        timing.interrupt(); reaction.interrupt(); typingFocused = false; ticker = UUID()
    }
}

/// A new server revision supplies the round configuration; local measurements never carry over.
/// Keep the original absent/nonpositive fallback and Core bounds unchanged.
enum PlayTimedReactionConfiguration {
    static func makeRun(segment: PlayWireValue) -> PlayKitReactionRun {
        let rounds = segment["rounds"].integer ?? 3
        return PlayKitReactionRun(rounds: rounds > 0 ? rounds : 3)
    }
}


/// Clear result card shown after a measurement and before review: icon + words + number, so colour is never the only signal.
/// `outcome == nil` means the pass line is unknown and no verdict is claimed.
struct PlayTimedResultCard: View {
    let outcome: Bool?
    let value: String
    let target: String?
    let delta: String?
    @Environment(\.locale) private var locale
    private var tone: Color { outcome == true ? CYColor.successText : outcome == false ? CYColor.warningText : CYColor.textSecondary }
    private var icon: String { outcome == true ? "checkmark.circle.fill" : outcome == false ? "arrow.triangle.2.circlepath.circle.fill" : "stopwatch.fill" }
    private var headline: String {
        switch outcome {
        case true: return ChannelCopy.text("正中目标", "Right on target", locale: locale)
        case false: return ChannelCopy.text("差一点，再来一次", "So close, try again", locale: locale)
        case nil: return ChannelCopy.text("你的成绩", "Your result", locale: locale)
        }
    }
    var body: some View {
        VStack(spacing: CYSpacing.sm) {
            Image(systemName: icon).font(.system(size: 34, weight: .semibold)).foregroundStyle(tone)
            Text(verbatim: headline).font(CYTypography.cardTitle).foregroundStyle(CYColor.textPrimary)
            Text(verbatim: value).font(.system(size: 44, weight: .bold, design: .rounded)).monospacedDigit()
                .minimumScaleFactor(0.5).lineLimit(1).foregroundStyle(CYColor.textPrimary)
            if target != nil || delta != nil {
                Text(verbatim: [target.map { ChannelCopy.text("目标 \($0)", "Target \($0)", locale: locale) },
                                delta.map { ChannelCopy.text("偏差 \($0)", "Off by \($0)", locale: locale) }].compactMap { $0 }.joined(separator: "  ·  "))
                    .font(CYTypography.meta).foregroundStyle(CYColor.textSecondary).multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity).padding(CYSpacing.xl)
        .background(CYColor.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: CYRadius.xl, style: .continuous).stroke(tone.opacity(0.5), lineWidth: 1))
        .accessibilityElement(children: .combine)
    }
}
