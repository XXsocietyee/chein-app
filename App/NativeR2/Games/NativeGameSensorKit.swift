import SwiftUI

// Template 3 · sensors (compass, ballshake, shout, quiethold).
// Apple reference: Fitness workout (one big live value + Gauge), Compass app (heading readout).
// Logic is `PlayKitSensorChallengeView`'s, unchanged: the same `PlayKitSensorStageModel`
// (calibrate → START_CHALLENGE review → run → measured → SUBMIT_*), the same Core run
// machines and payloads. Only the drawing changes; the primary action goes to the bottom bar.
@MainActor struct NativeGameSensorKit: View {
    let kind: PlayKitScreenKind
    let segment: PlayWireValue
    let enabled: Bool
    let active: Bool
    let onDirty: () -> Void
    let requestReview: PlayKitReviewRequest
    let revisionIdentity: String
    let currentRevisionIdentity: (() -> String)?
    let publish: (NativeGameSubmit?) -> Void
    @State private var stage: PlayKitSensorStageModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kind: PlayKitScreenKind, segment: PlayWireValue, enabled: Bool, active: Bool,
         onDirty: @escaping () -> Void, requestReview: @escaping PlayKitReviewRequest,
         revisionIdentity: String = "", currentRevisionIdentity: (() -> String)? = nil,
         makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil,
         publish: @escaping (NativeGameSubmit?) -> Void) {
        self.kind = kind; self.segment = segment; self.enabled = enabled; self.active = active
        self.onDirty = onDirty; self.requestReview = requestReview
        self.revisionIdentity = revisionIdentity; self.currentRevisionIdentity = currentRevisionIdentity
        self.publish = publish
        // Empty by default. Having a device implementation is not acceptance of a backend
        // contract, a privacy declaration or a sensor grant.
        _stage = State(initialValue: PlayKitSensorStageModel(kind: kind, segment: segment,
            provider: makeSensorProvider?() ?? PlayKitDormantSensorProvider(), revisionIdentity: revisionIdentity))
    }

    var body: some View {
        Group {
            purposeSection
                .onAppear { stage.isActive = active }
                .onChange(of: revisionIdentity) { _, next in stage.updateRevision(next, segment: segment) }
                .onChange(of: active) { _, value in stage.isActive = value; if !value { stage.interrupt(.interrupted) } }
                .onChange(of: scenePhase) { _, value in
                    // An OS permission prompt can make the scene inactive before there is any stream.
                    // Background always invalidates the whole attempt.
                    if value == .background || (value != .active && stage.phase != .authorizing) { stage.interrupt(.interrupted) }
                }
                .onChange(of: submitKey, initial: true) { _, _ in publish(primaryAction) }
                .onDisappear { stage.interrupt(.interrupted) }
            if let issue = stage.issue, issue == .permissionDenied || issue == .sensorUnavailable || issue == .configurationUnavailable {
                Section { permissionView(issue) }
            } else if !stage.supported {
                Section { permissionView(.configurationUnavailable) }
            } else {
                liveSection
                if let issue = stage.issue {
                    Section {
                        Label(LocalizedStringKey("playkit.sensor.error." + issue.rawValue), systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                            .accessibilityIdentifier("playkit.sensor.issue")
                    }
                }
            }
            if [.authorizing, .calibrating, .running, .ready].contains(stage.phase) {
                Section {
                    Button("playkit.sensor.stop", role: .cancel) { stage.interrupt(.interrupted) }
                        .accessibilityIdentifier("playkit.sensor.stop")
                }
            }
        }
        .accessibilityIdentifier("playkit.sensor." + kind.rawValue)
    }

    // MARK: Sections

    private var purposeSection: some View {
        Section {
            Text(LocalizedStringKey("playkit.sensor.purpose." + kind.rawValue))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier("playkit.sensor.purpose")
            kicker
        } footer: {
            if kind == .quietHold || kind == .shout { Text("playkit.sensor.audioPrivacy") }
            else if kind == .compass { Text("playkit.compass.caution") }
        }
    }

    /// MP `g-kicker` + sub lines (ballshake / quiethold / shout / compass): the server `kicker` leads when present,
    /// then the kit's own line, the server `sub` (quiet hold) or `hint` (compass), and 这一站已跳过 when skipped.
    @ViewBuilder private var kicker: some View {
        Group {
            if let line = serverText("kicker") {
                Text(verbatim: line).font(.headline).foregroundStyle(.primary)
            }
            switch kind {
            case .ballShake:
                Text("playkit.ball.kicker \(stage.ball.goal)")
                if stage.ball.limitSeconds > 0 { Text("playkit.ball.limitLine \(decimal(stage.ball.limitSeconds))") }
            case .quietHold:
                if serverText("kicker") == nil { Text("playkit.quiet.kicker") }
                if let sub = serverText("sub") { Text(verbatim: sub) }
            case .shout:
                if serverText("kicker") == nil { Text("playkit.shout.kicker") }
            case .compass:
                if serverText("kicker") == nil { Text("playkit.compass.kicker") }
                if let hint = serverText("hint") { Text(verbatim: hint) }
            default: EmptyView()
            }
            if segment["skipped"].bool == true { Text("playkit.sensor.skipped") }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("playkit.sensor.kicker")
    }

    private func serverText(_ key: String) -> String? {
        let text = segment[key].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    @ViewBuilder private var liveSection: some View {
        Section {
            if stage.phase == .authorizing {
                ProgressView().frame(maxWidth: .infinity)
            } else if stage.phase == .calibrating {
                ProgressView {
                    Text(LocalizedStringKey(kind == .ballShake ? "playkit.ball.calibration" : "playkit.audio.calibration"))
                }
                .frame(maxWidth: .infinity)
                .accessibilityLabel(Text("playkit.sensor.calibrating"))
            }
            board
        } header: {
            Text(LocalizedStringKey("playkit.sensor.phase." + stage.phase.rawValue))
                .accessibilityIdentifier("playkit.sensor.phase")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stage.ball.hits) { old, next in kind == .ballShake && next > old }
        .sensoryFeedback(.warning, trigger: stage.quiet.exceeded) { old, next in kind == .quietHold && !old && next }
        .sensoryFeedback(.alignment, trigger: stage.compass.aligned) { old, next in kind == .compass && !old && next }
        .sensoryFeedback(.success, trigger: stage.phase == .measured) { old, next in !old && next }
    }

    @ViewBuilder private var board: some View {
        switch kind {
        case .ballShake:
            bigValue("\(stage.ball.hits) / \(stage.ball.goal)", label: "playkit.ball.hits")
            if stage.ball.limitSeconds > 0 {
                Gauge(value: max(0, stage.ball.limitSeconds - stage.ball.elapsedSeconds), in: 0...max(0.1, stage.ball.limitSeconds)) {
                    Text("playkit.sensor.secondsLeft")
                } currentValueLabel: {
                    Text(verbatim: decimal(max(0, stage.ball.limitSeconds - stage.ball.elapsedSeconds))).monospacedDigit()
                }
                .gaugeStyle(.linearCapacity)
            }
            // The ball is game content (owner decision in the spec): one SF Symbol on a plain fill.
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    Rectangle().fill(.quaternary)
                    Image(systemName: "circle.fill")
                        .resizable()
                        .foregroundStyle(.tint)
                        .frame(width: geometry.size.width * 26 / 300, height: geometry.size.width * 26 / 300)
                        .position(x: geometry.size.width * stage.ball.x / 300, y: geometry.size.height * stage.ball.y / 420)
                }
                .clipped()
            }
            .aspectRatio(300.0 / 420.0, contentMode: .fit)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("playkit.ball.board"))
            Text("playkit.ball.instruction").font(.footnote).foregroundStyle(.secondary)
            if NativeR2Flags.motion2 {
                // Motion r2 R4: each hit from the kit's CoreMotion reader stirs the snow globe; it settles after.
                MotionR2SnowGlobe(shakes: stage.ball.hits)
            }
        case .quietHold, .shout:
            let level = kind == .quietHold ? stage.quiet.level : stage.shout.level
            let warning = kind == .quietHold ? stage.quiet.warningThreshold : stage.shout.warningThreshold
            let threshold = kind == .quietHold ? stage.quiet.stopThreshold : stage.shout.loudThreshold
            let held = kind == .quietHold ? stage.quiet.heldSeconds : stage.shout.heldSeconds
            let total = kind == .quietHold ? stage.quiet.targetSeconds : stage.shout.targetSeconds
            let color: Color = level > threshold ? .red : level > warning ? .orange : .green
            bigValue(decimal(max(0, total - held)), label: "playkit.sensor.secondsLeft")
            Gauge(value: min(max(level, 0), 1), in: 0...1) {
                Text("playkit.audio.livePeak")
            }
            .gaugeStyle(.linearCapacity)
            .tint(color)
            Label(LocalizedStringKey(level > threshold ? "playkit.audio.hot" : level > warning ? "playkit.audio.warning" : "playkit.audio.quiet"),
                  systemImage: level > threshold ? "waveform" : "waveform.path")
                .foregroundStyle(color)
            ProgressView(value: min(held, total), total: max(0.1, total)) { Text("playkit.sensor.holdProgress") }
            if kind == .quietHold { Text("playkit.quiet.relative").font(.footnote).foregroundStyle(.secondary) }
            if kind == .quietHold, stage.quiet.exceeded { Label("playkit.quiet.limitReached", systemImage: "speaker.wave.3").foregroundStyle(.red) }
            if kind == .shout { Text("playkit.shout.continuous").font(.footnote).foregroundStyle(.secondary) }
        case .compass:
            VStack(spacing: 8) {
                Image(systemName: "location.north.fill")
                    .font(.largeTitle)
                    .foregroundStyle(stage.compass.aligned ? Color.green : Color.accentColor)
                    .rotationEffect(.degrees(stage.compass.needleDegrees))
                    .opacity(stage.compass.heading == nil ? 0.25 : 1)
                    .animation(reduceMotion ? nil : .linear(duration: 0.15), value: stage.compass.needleDegrees)
                    .accessibilityHidden(true)
                Text(verbatim: stage.compass.heading.map { "\(Int($0.rounded()) % 360)°" } ?? "—")
                    .cyText(.dataXL)
                    .contentTransition(.numericText())
                    .accessibilityLabel(Text("playkit.compass.heading"))
            }
            .frame(maxWidth: .infinity)
            LabeledContent { Text(verbatim: "\(Int(stage.compass.target))°").monospacedDigit() } label: { Text("playkit.compass.target") }
            if stage.compass.heading != nil {
                if stage.compass.lowAccuracy { Label("playkit.compass.lowAccuracy", systemImage: "exclamationmark.triangle").foregroundStyle(.orange) }
                else if stage.compass.aligned { Label("playkit.compass.hold", systemImage: "scope") }
                else {
                    Label {
                        Text(LocalizedStringKey(stage.compass.signedDelta > 0 ? "playkit.compass.turnRight" : "playkit.compass.turnLeft"))
                            + Text(verbatim: " \(Int(abs(stage.compass.signedDelta).rounded()))°")
                    } icon: {
                        Image(systemName: stage.compass.signedDelta > 0 ? "arrow.turn.up.right" : "arrow.turn.up.left")
                    }
                }
            } else {
                Text("playkit.compass.waitingHeading").foregroundStyle(.secondary)
            }
            Gauge(value: min(stage.compass.heldSeconds, stage.compass.holdSeconds), in: 0...max(0.1, stage.compass.holdSeconds)) {
                Text("playkit.sensor.holdProgress")
            } currentValueLabel: {
                Text(verbatim: decimal(max(0, stage.compass.holdSeconds - stage.compass.heldSeconds))).monospacedDigit()
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .frame(maxWidth: .infinity)
        default:
            EmptyView()
        }
    }

    private func bigValue(_ value: String, label: LocalizedStringKey) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .cyText(.dataXL)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label).font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    /// Permission denied / no sensor: a system empty state with Open Settings (denied only).
    @ViewBuilder private func permissionView(_ issue: PlayKitSensorError) -> some View {
        if issue == .permissionDenied {
            switch kind {
            case .compass:
                NativeGamePermissionView(title: "nativeGames.permission.location", systemImage: "location.slash",
                                         description: "nativeGames.permission.location.detail", retry: retry)
            case .shout, .quietHold:
                NativeGamePermissionView(title: "nativeGames.permission.mic", systemImage: "mic.slash",
                                         description: "nativeGames.permission.mic.detail", retry: retry)
            default:
                NativeGamePermissionView(title: "nativeGames.permission.motion", systemImage: "figure.walk.motion",
                                         description: "nativeGames.permission.motion.detail", retry: retry)
            }
        } else {
            NativeGamePermissionView(title: "nativeGames.permission.sensor", systemImage: "sensor",
                                     description: "playkit.sensor.error.configurationUnavailable", showsSettings: false)
        }
    }

    private var retry: (() -> Void)? {
        guard enabled, active, stage.supported else { return nil }
        return { onDirty(); stage.begin(active: active) }
    }

    // MARK: Bottom-bar action

    private var submitKey: String {
        "\(stage.phase.rawValue)|\(enabled)|\(active)|\(stage.supported)|\(stage.payload != nil)"
    }

    private var primaryAction: NativeGameSubmit? {
        switch stage.phase {
        case .measured:
            return NativeGameSubmit(title: Text("playkit.review"), enabled: enabled && active && stage.payload != nil,
                                    identifier: "playkit.sensor.review", action: {
                guard let payload = stage.payload else { return }
                requestReview(stage.submitAction, payload, {})
            })
        case .ready:
            return NativeGameSubmit(title: Text("playkit.sensor.reviewStart"), enabled: enabled && active,
                                    identifier: "playkit.sensor.start", action: {
                let token = stage.attempt
                requestReview("START_CHALLENGE", ["game": .string(kind.rawValue)]) {
                    // Called only after a successful, current server acknowledgement.
                    if stage.startAfterAcknowledgement(attempt: token, revisionIdentity: currentRevisionIdentity?() ?? revisionIdentity) { onDirty() }
                }
            })
        case .idle, .interrupted:
            return NativeGameSubmit(title: Text(LocalizedStringKey(kind == .compass ? "playkit.compass.begin" : "playkit.sensor.calibrate")),
                                    enabled: enabled && active && stage.supported,
                                    identifier: "playkit.sensor.calibrate", action: { onDirty(); stage.begin(active: active) })
        default:
            return nil
        }
    }

    private func decimal(_ number: Double) -> String { String(format: "%.1f", number) }
}
