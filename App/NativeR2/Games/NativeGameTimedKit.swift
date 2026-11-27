import SwiftUI

// Template 3 · timing (reaction, stopwatch, countdown, typein).
// Apple reference: Clock → Stopwatch / Timer (one big value, start / stop as the prominent action).
// Logic is `PlayKitTimedChallengeView`'s, unchanged: the same `PlayKitTimingRun` /
// `PlayKitReactionRun` machines, START_CHALLENGE before every run, and the same
// SUBMIT_REACTION / SUBMIT_STOPWATCH / SUBMIT_COUNTDOWN / SUBMIT_TYPE_IN payloads.
// The primary action is published to the shell's bottom bar.
@MainActor struct NativeGameTimedKit: View {
    let kind: PlayKitScreenKind
    let segment: PlayWireValue
    let enabled: Bool
    let active: Bool
    let onDirty: () -> Void
    let requestReview: PlayKitReviewRequest
    let revisionIdentity: String
    let currentRevisionIdentity: (() -> String)?
    let publish: (NativeGameSubmit?) -> Void
    @State private var expectedRevision = ""
    @State private var timing = PlayKitTimingRun()
    @State private var reaction: PlayKitReactionRun
    @State private var elapsed = 0
    @State private var input = ""
    @State private var ticker = UUID()
    @State private var mounted = false
    @State private var expired = false
    /// Countdown kit: wall-clock start of the acknowledged run, for the self-updating clock (display only).
    @State private var countdownStart: Date?
    @FocusState private var typingFocused: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.locale) private var locale

    init(kind: PlayKitScreenKind, segment: PlayWireValue, enabled: Bool, active: Bool,
         onDirty: @escaping () -> Void, requestReview: @escaping PlayKitReviewRequest,
         revisionIdentity: String = "", currentRevisionIdentity: (() -> String)? = nil,
         publish: @escaping (NativeGameSubmit?) -> Void) {
        self.kind = kind; self.segment = segment; self.enabled = enabled; self.active = active
        self.onDirty = onDirty; self.requestReview = requestReview
        self.revisionIdentity = revisionIdentity; self.currentRevisionIdentity = currentRevisionIdentity
        self.publish = publish
        _reaction = State(initialValue: PlayTimedReactionConfiguration.makeRun(segment: segment))
    }

    /// Absent or non-finite seconds stay nil. A literal 0 stays 0.
    private var sourceSeconds: Double? {
        let value = segment[kind == .stopwatch ? "targetSeconds" : "seconds"].double
        guard let value, value.isFinite else { return nil }
        return value
    }
    private var seconds: Double { sourceSeconds ?? 0 }
    private var running: Bool { timing.phase == .running || [.waiting, .signal].contains(reaction.phase) }

    var body: some View {
        Group {
            configSection
                .onAppear { mounted = true; expectedRevision = currentRevisionIdentity?() ?? revisionIdentity }
                .onAppear {
                    if kind == .typeIn, input.isEmpty, let accepted = segment["acceptedInput"].text, !accepted.isEmpty { input = accepted }
                }
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
                .onChange(of: submitKey, initial: true) { _, _ in publish(primaryAction) }
                .onDisappear { mounted = false; interrupt() }
            if kind == .reaction { reactionSections } else { timedSections }
            statusSection
        }
    }

    // MARK: Sections

    @ViewBuilder private var configSection: some View {
        Section {
            if kind == .reaction {
                LabeledContent {
                    Text(verbatim: PlayTimedDisplayLocalization.round(current: reaction.roundsMilliseconds.count, total: reaction.rounds, locale: locale)).monospacedDigit()
                } label: { Text("playkit.reaction.round") }
                if let goal = segment["goalMs"].integer, goal > 0 {
                    LabeledContent { Text(verbatim: PlayTimedDisplayLocalization.milliseconds(goal, locale: locale)).monospacedDigit() } label: { Text("playkit.reaction.goal") }
                }
            } else {
                LabeledContent {
                    Text(verbatim: sourceSeconds.map { $0 >= 0 ? PlayTimedDisplayLocalization.seconds($0, locale: locale) : "—" } ?? "—").monospacedDigit()
                } label: { Text("playkit.challenge.target") }
                if kind == .stopwatch {
                    LabeledContent {
                        Text(verbatim: segment["toleranceMs"].integer.map { PlayTimedDisplayLocalization.tolerance($0, locale: locale) } ?? "—").monospacedDigit()
                    } label: { Text("playkit.stopwatch.tolerance") }
                }
                if kind == .typeIn {
                    LabeledContent {
                        Text(verbatim: segment["attempts"].integer.flatMap { $0 >= 0 ? PlayTimedDisplayLocalization.count($0, locale: locale) : nil } ?? "—").monospacedDigit()
                    } label: { Text("playkit.attempts") }
                    LabeledContent {
                        Text(verbatim: segment["tries"].integer.flatMap { $0 >= 0 ? PlayTimedDisplayLocalization.count($0, locale: locale) : nil } ?? "—").monospacedDigit()
                    } label: { Text("playkit.attemptLimit") }
                }
            }
        } footer: {
            if kind == .stopwatch || kind == .reaction {
                // Mini-program footnote: a device reading for fun; backgrounding interrupts the local clock.
                Text("playkit.challenge.localNotice").accessibilityIdentifier("playkit.challenge.localNotice")
            }
        }
    }

    @ViewBuilder private var timedSections: some View {
        if kind == .typeIn {
            Section {
                Text(verbatim: typeInPrompt)
                    .font(.title3.monospaced())
                    .textSelection(.disabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityIdentifier("playkit.type.target")
                TextField("playkit.type.input", text: $input, axis: .vertical)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($typingFocused)
                    .disabled(timing.phase != .running || !enabled)
                    .onChange(of: input) { _, value in if value.count > 4096 { input = String(value.prefix(4096)) }; onDirty() }
                    .accessibilityIdentifier("playkit.type.field")
                if let howTo = segment["howTo"].text?.trimmingCharacters(in: .whitespacesAndNewlines), !howTo.isEmpty {
                    PlayKitHowToButton(text: howTo, identifier: "playkit.type.howTo")
                }
            } header: {
                Text("playkit.type.goalLine \(typeInGoal)")
            } footer: {
                Text(segment["caseSensitive"].bool == true ? "playkit.type.caseSensitive" : "playkit.type.caseInsensitive")
            }
        }
        Section {
            VStack(spacing: 8) {
                if let countdownClock {
                    // Components r1: the countdown counts down by itself and the ring empties (MP playkit-countdown).
                    NativeGameCountdownClock(start: countdownClock, seconds: seconds)
                } else {
                    Text(verbatim: clockLabel)
                        .font(.system(.largeTitle, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .contentTransition(.numericText())
                        .frame(maxWidth: .infinity)
                }
                if kind == .typeIn, seconds > 0 {
                    ProgressView(value: clockProgress).accessibilityHidden(true)
                }
            }
            .padding(.vertical, 8)
            .accessibilityElement(children: .ignore)
            .accessibilityValue(clockAccessibilityValue)
            .accessibilityLabel(Text(kind == .stopwatch && running && elapsed >= 1000 ? "playkit.stopwatch.hidden" : "playkit.challenge.clock"))
            .sensoryFeedback(.impact(weight: .medium), trigger: timing.phase == .running) { _, now in now }
            .sensoryFeedback(trigger: timing.phase == .measured) { _, now in now ? (stopwatchOutcome == false ? .warning : .success) : nil }
            if !validConfiguration {
                ContentUnavailableView("playkit.configurationInvalid", systemImage: "exclamationmark.triangle")
            }
        }
        if timing.phase == .measured, kind == .stopwatch { stopwatchResultSection }
    }

    @ViewBuilder private var reactionSections: some View {
        Section {
            if reaction.phase == .waiting || reaction.phase == .signal {
                let go = reaction.phase == .signal
                Button {
                    reaction.tap(now: ProcessInfo.processInfo.systemUptime); onDirty()
                } label: {
                    VStack(spacing: 12) {
                        Image(systemName: go ? "hand.tap.fill" : "hourglass").font(.largeTitle)
                        Text(go ? "playkit.reaction.tap" : "playkit.reaction.wait").font(.title2.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 56)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.extraLarge)
                .tint(go ? .green : .gray)
                .sensoryFeedback(.impact(weight: .heavy), trigger: go) { _, now in now }
                .disabled(!enabled)
                .accessibilityIdentifier("playkit.reaction.target")
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            } else {
                Label {
                    Text(verbatim: ChannelCopy.text("屏幕变绿时立刻点按，别抢跑。", "Tap the moment it turns green. Don't jump the gun.", locale: locale))
                } icon: {
                    Image(systemName: "hand.tap")
                }
                if reaction.phase == .early {
                    Label("playkit.reaction.early", systemImage: "hare").foregroundStyle(.orange)
                }
            }
        }
        if !reaction.roundsMilliseconds.isEmpty {
            Section {
                ForEach(Array(reaction.roundsMilliseconds.enumerated()), id: \.offset) { index, ms in
                    LabeledContent {
                        Text(verbatim: PlayTimedDisplayLocalization.milliseconds(ms, locale: locale)).monospacedDigit()
                    } label: {
                        Text(verbatim: PlayTimedDisplayLocalization.count(index + 1, locale: locale))
                    }
                }
            }
        }
        if reaction.phase == .measured, !reaction.roundsMilliseconds.isEmpty {
            let avg = reaction.roundsMilliseconds.reduce(0, +) / reaction.roundsMilliseconds.count
            let goal = segment["goalMs"].integer.flatMap { $0 > 0 ? $0 : nil }
            resultSection(outcome: goal.map { avg <= $0 }, value: PlayTimedDisplayLocalization.milliseconds(avg, locale: locale),
                          target: goal.map { PlayTimedDisplayLocalization.milliseconds($0, locale: locale) }, delta: nil)
                .sensoryFeedback(.success, trigger: reaction.phase == .measured) { _, now in now }
        }
    }

    @ViewBuilder private var statusSection: some View {
        if timing.phase == .interrupted || reaction.phase == .interrupted || expired || running {
            Section {
                if timing.phase == .interrupted || reaction.phase == .interrupted {
                    Label("playkit.challenge.interrupted", systemImage: "pause.circle").foregroundStyle(.orange)
                }
                if expired { Label("playkit.challenge.expired", systemImage: "timer").foregroundStyle(.red) }
                if running {
                    Button("playkit.challenge.abort", role: .destructive) { interrupt() }
                        .accessibilityIdentifier("playkit.challenge.abort")
                }
            }
        }
    }

    @ViewBuilder private var stopwatchResultSection: some View {
        let stopped = timing.elapsedMilliseconds
        let diff = stopped - Int(seconds * 1000)
        resultSection(outcome: stopwatchOutcome,
                      value: PlayTimedDisplayLocalization.seconds(Double(stopped) / 1000, locale: locale),
                      target: PlayTimedDisplayLocalization.seconds(seconds, locale: locale),
                      delta: (diff >= 0 ? "+" : "−") + PlayTimedDisplayLocalization.seconds(Double(abs(diff)) / 1000, locale: locale))
    }

    /// Local pre-review readout only; the server still grades. Unknown tolerance claims no verdict.
    private func resultSection(outcome: Bool?, value: String, target: String?, delta: String?) -> some View {
        Section {
            Label {
                Text(verbatim: outcome == true ? ChannelCopy.text("正中目标", "Right on target", locale: locale)
                     : outcome == false ? ChannelCopy.text("差一点，再来一次", "So close, try again", locale: locale)
                     : ChannelCopy.text("你的成绩", "Your result", locale: locale))
            } icon: {
                Image(systemName: outcome == true ? "checkmark.circle.fill" : outcome == false ? "arrow.triangle.2.circlepath.circle.fill" : "stopwatch.fill")
            }
            .foregroundStyle(outcome == true ? Color.green : outcome == false ? Color.orange : Color.secondary)
            Text(verbatim: value).font(.system(.title, design: .rounded).weight(.semibold)).monospacedDigit()
            if let target {
                LabeledContent { Text(verbatim: target).monospacedDigit() } label: { Text("playkit.challenge.target") }
            }
            if let delta {
                LabeledContent { Text(verbatim: delta).monospacedDigit() } label: { Text("nativeGames.timed.delta") }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("nativeGames.timed.result")
    }

    // MARK: Bottom-bar action

    private var submitKey: String {
        "\(timing.phase.rawValue)|\(reaction.phase.rawValue)|\(enabled)|\(active)|\(input.isEmpty)|\(validConfiguration)"
    }

    private var primaryAction: NativeGameSubmit? {
        if kind == .reaction {
            switch reaction.phase {
            case .idle, .interrupted:
                return NativeGameSubmit(title: Text("playkit.challenge.start"), enabled: enabled,
                                        identifier: "playkit.challenge.start", action: { start() })
            case .early, .betweenRounds:
                return NativeGameSubmit(title: Text("playkit.reaction.next"), enabled: enabled, identifier: "playkit.reaction.next", action: {
                    reaction.arm(now: ProcessInfo.processInfo.systemUptime, randomUnit: Double.random(in: 0...1)); ticker = UUID()
                })
            case .measured:
                return NativeGameSubmit(title: Text("playkit.review"), enabled: enabled, identifier: "playkit.challenge.submit", action: {
                    requestReview("SUBMIT_REACTION", ["times": .array(reaction.roundsMilliseconds.map(PlayWireValue.int))], {})
                })
            default:
                return nil
            }
        }
        switch timing.phase {
        case .idle, .interrupted:
            return NativeGameSubmit(title: Text("playkit.challenge.start"), enabled: enabled && validConfiguration,
                                    identifier: "playkit.challenge.start", action: { start() })
        case .running:
            guard kind != .countdown else { return nil }
            return NativeGameSubmit(title: Text(kind == .stopwatch ? "playkit.stopwatch.stop" : "playkit.type.finish"), enabled: enabled,
                                    identifier: "playkit.challenge.measure", action: {
                timing.measure(now: ProcessInfo.processInfo.systemUptime); elapsed = timing.elapsedMilliseconds; typingFocused = false
            })
        case .measured:
            return NativeGameSubmit(title: Text("playkit.review"), enabled: enabled && !(kind == .typeIn && input.isEmpty),
                                    identifier: "playkit.challenge.submit", action: { reviewMeasurement() })
        }
    }

    // MARK: Logic (unchanged from PlayKitTimedChallengeView)

    private var stopwatchOutcome: Bool? {
        guard kind == .stopwatch, timing.phase == .measured, let tolerance = segment["toleranceMs"].integer else { return nil }
        return abs(timing.elapsedMilliseconds - Int(seconds * 1000)) <= tolerance
    }
    private var typeInPrompt: String {
        let text = segment["target"].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? "—" : text
    }
    private var typeInGoal: String {
        sourceSeconds.map { PlayTimedDisplayLocalization.seconds($0, locale: locale) } ?? "—"
    }
    private var validConfiguration: Bool {
        if kind == .reaction { return true }
        guard let seconds = sourceSeconds else { return false }
        if kind == .typeIn { return seconds >= 0 && seconds <= 3600 && typeInPrompt != "—" }
        return seconds > 0 && seconds <= 3600
    }
    /// The running countdown's start, when there is a valid duration to count down from.
    private var countdownClock: Date? {
        guard kind == .countdown, timing.phase == .running, seconds > 0 else { return nil }
        return countdownStart
    }
    private var clockAccessibilityValue: Text {
        if let countdownClock { return NativeGameCountdownClock.accessibilityValue(start: countdownClock, seconds: seconds) }
        return Text(verbatim: clockLabel)
    }
    private var clockProgress: Double {
        guard kind == .typeIn, seconds > 0 else { return 1 }
        return max(0, min(1, 1 - Double(elapsed) / (seconds * 1000)))
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
    private func start() {
        guard enabled, validConfiguration else { return }
        requestReview("START_CHALLENGE", ["game": .string(kind.rawValue)]) {
            guard mounted, active, scenePhase == .active else { return }
            expectedRevision = currentRevisionIdentity?() ?? revisionIdentity
            expired = false; onDirty()
            if kind == .reaction { reaction.beginAfterAcknowledgement(now: ProcessInfo.processInfo.systemUptime, randomUnit: Double.random(in: 0...1)) }
            else {
                input = ""; elapsed = 0; timing.beginAfterAcknowledgement(now: ProcessInfo.processInfo.systemUptime); typingFocused = kind == .typeIn
                countdownStart = kind == .countdown ? Date() : nil
            }
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
