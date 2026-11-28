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
    /// MP `readfail` / `micdenied`: reports a failed read (true = permission denied or no sensor) without a review.
    let reportFailure: ((Bool) -> Void)?
    @State private var stage: PlayKitSensorStageModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kind: PlayKitScreenKind, segment: PlayWireValue, enabled: Bool, active: Bool,
         onDirty: @escaping () -> Void, requestReview: @escaping PlayKitReviewRequest,
         revisionIdentity: String = "", currentRevisionIdentity: (() -> String)? = nil,
         makeSensorProvider: (@MainActor () -> any PlayKitSensorProviding)? = nil,
         reportFailure: ((Bool) -> Void)? = nil,
         publish: @escaping (NativeGameSubmit?) -> Void) {
        self.kind = kind; self.segment = segment; self.enabled = enabled; self.active = active
        self.onDirty = onDirty; self.requestReview = requestReview
        self.revisionIdentity = revisionIdentity; self.currentRevisionIdentity = currentRevisionIdentity
        self.publish = publish; self.reportFailure = reportFailure
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
                            .foregroundStyle(CYColor.warningText)
                            .accessibilityIdentifier("playkit.sensor.issue")
                    }
                }
            }
            if showsSkip {
                Section {
                    Button("playkit.sensor.skip") {
                        requestReview(PlayKitSensorStation.skipAction, ["game": .string(kind.rawValue)], {})
                    }
                    .accessibilityIdentifier("playkit.sensor.skip")
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
        .modifier(NativeSensorFailureReport(kind: kind, issue: stage.issue, report: reportFailure))
    }

    /// MP `bl__skip` / `cp__skip`: 跳过这一站 only when the server says `canSkip` (two failed reads, the author
    /// switch or a leader release), never while a run is open or once skipped.
    private var showsSkip: Bool {
        PlayKitSensorStation.offersSkip(segment) && enabled && active
            && (stage.phase == .idle || stage.phase == .interrupted)
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
        }
    }

    /// MP `g-kicker` + sub lines (ballshake / quiethold / shout / compass): the server `kicker` leads when present,
    /// then the kit's own line and 这一站已跳过 when skipped. The quiet-hold `sub` and the compass `hint` sit on the
    /// board under the figure (MP `qt__s`, `cp__hint`).
    @ViewBuilder private var kicker: some View {
        Group {
            // The shell title falls back to the kicker (`PlayKitProjection.title`); never print it twice.
            if let line = serverText("kicker"), line != (segment["title"].text ?? segment["question"].text ?? segment["kicker"].text ?? "") {
                Text(verbatim: line).font(.headline).foregroundStyle(.primary)
            }
            switch kind {
            case .ballShake:
                Text("playkit.ball.kicker \(stage.ball.goal)")
                if stage.ball.limitSeconds > 0 { Text("playkit.ball.limitLine \(decimal(stage.ball.limitSeconds))") }
            case .quietHold:
                if serverText("kicker") == nil { Text("playkit.quiet.kicker") }
            case .shout:
                if serverText("kicker") == nil { Text("playkit.shout.kicker") }
            case .compass:
                if serverText("kicker") == nil { Text("playkit.compass.kicker") }
            default: EmptyView()
            }
            if segment["skipped"].bool == true { Text("playkit.sensor.skipped") }
        }
        .font(.footnote)
        .foregroundStyle(.secondary)
        .accessibilityIdentifier("playkit.sensor.kicker")
    }

    /// MP `rewardNote(rewardCeiling)`: only the server's XP_BADGE_ONLY ceiling earns a line; anything else says nothing.
    private var xpBadgeOnly: Bool { segment["rewardCeiling"].text == "XP_BADGE_ONLY" }

    private func serverText(_ key: String) -> String? {
        let text = segment[key].text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return text.isEmpty ? nil : text
    }

    @ViewBuilder private var liveSection: some View {
        Section {
            if stage.phase == .authorizing {
                CYLoadingState()
            } else if stage.phase == .calibrating {
                NativeSensorCalibrationView(kind: kind, startedAt: stage.calibrationStartedAt ?? Date(), seconds: stage.calibrationSeconds)
            }
            board
        } header: {
            Text(LocalizedStringKey("playkit.sensor.phase." + stage.phase.rawValue))
                .accessibilityIdentifier("playkit.sensor.phase")
        }
        .sensoryFeedback(.impact(weight: .light), trigger: stage.ball.hits) { old, next in kind == .ballShake && next > old }
        .sensoryFeedback(.warning, trigger: kind == .quietHold && stage.quiet.exceeded, condition: CYHapticTransition.turnedOn)
        .sensoryFeedback(.alignment, trigger: kind == .compass && stage.compass.aligned, condition: CYHapticTransition.turnedOn)
        .sensoryFeedback(.success, trigger: stage.phase == .measured, condition: CYHapticTransition.turnedOn)
    }

    @ViewBuilder private var board: some View {
        switch kind {
        case .ballShake:
            bigValue("\(stage.ball.hits) / \(stage.ball.goal)", label: "playkit.ball.hits")
                .accessibilityLabel(Text("playkit.ball.hits"))
                .accessibilityValue(Text("a11y.value.ofTotal \(stage.ball.hits) \(stage.ball.goal)"))
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
        case .quietHold:
            // MP `playkit-quiethold`: no level bar — the green / orange / red band lives on the figure itself.
            let level = stage.quiet.level
            let color: Color = level > stage.quiet.stopThreshold ? .red : level > stage.quiet.warningThreshold ? .orange : .green
            audioFigure(decimal(max(0, stage.quiet.targetSeconds - stage.quiet.heldSeconds)),
                        color: stage.phase == .running ? color : .primary)
            if let sub = serverText("sub") { Text(verbatim: sub).foregroundStyle(.secondary) }
            if xpBadgeOnly { Text("playkit.rewardNote.xpBadgeOnly").font(.footnote).foregroundStyle(.secondary) }
            if stage.quiet.exceeded { Label("playkit.quiet.limitReached", systemImage: "speaker.wave.3").foregroundStyle(CYColor.dangerText) }
        case .shout:
            // MP `playkit-shout`: figure (seconds left) → one plain line → safety line before the run; no level bar.
            let running = stage.phase == .running
            let loud = running && stage.shout.loud
            audioFigure(decimal(max(0, stage.shout.targetSeconds - stage.shout.heldSeconds)), color: loud ? .red : .primary)
            if running {
                Text(LocalizedStringKey(loud ? "playkit.shout.keepGoing" : "playkit.shout.louder"))
                    .font(.headline)
                    .foregroundStyle(loud ? CYColor.dangerText : Color.primary)
                    .frame(maxWidth: .infinity)
            } else {
                Text("playkit.shout.goal \(decimal(stage.shout.targetSeconds))")
                    .frame(maxWidth: .infinity)
            }
            if xpBadgeOnly { Text("playkit.rewardNote.xpBadgeOnly").font(.footnote).foregroundStyle(.secondary) }
            if !running {
                Text("playkit.shout.safe").font(.footnote).foregroundStyle(.secondary)
            }
        case .compass:
            // MP `playkit-compass` order: dial → heading figure (running) → hold / done / how-to + 提示 → drift line → safety line.
            NativeCompassDial(compass: stage.compass, running: stage.phase == .running, reduceMotion: reduceMotion)
            if stage.phase == .running, let heading = stage.compass.heading {
                Text(verbatim: "\(Int(heading.rounded()) % 360)°")
                    .cyText(.dataXL)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .foregroundStyle(stage.compass.aligned ? Color.green : Color.primary)
                    .frame(maxWidth: .infinity)
                    .accessibilityLabel(Text("playkit.compass.heading"))
                    .accessibilityValue(Text(verbatim: "\(Int(heading.rounded()) % 360)°"))
            }
            compassStatus
            if stage.phase == .running, stage.compass.heading != nil, stage.compass.lowAccuracy {
                Label("playkit.compass.lowAccuracy", systemImage: "exclamationmark.triangle").foregroundStyle(CYColor.warningText)
            }
            if (stage.phase == .idle || stage.phase == .interrupted), segment["done"].bool != true {
                Text("playkit.compass.safe").font(.footnote).foregroundStyle(.secondary)
            }
            if xpBadgeOnly { Text("playkit.rewardNote.xpBadgeOnly").font(.footnote).foregroundStyle(.secondary) }
        default:
            EmptyView()
        }
    }

    /// MP `cp__hold` / `cp__s` / `cp__how` + `cp__hint`: one line under the figure, then the 已对准 mark when done.
    @ViewBuilder private var compassStatus: some View {
        let done = segment["done"].bool == true && segment["skipped"].bool != true
        if stage.phase == .running, stage.compass.aligned {
            Label {
                Text("playkit.compass.holdLeft \(decimal(max(0, stage.compass.holdSeconds - stage.compass.heldSeconds)))")
                    .monospacedDigit()
            } icon: {
                Image(systemName: "scope")
            }
            .foregroundStyle(.green)
        } else if stage.phase == .running, stage.compass.heading == nil {
            Text("playkit.compass.waitingHeading").foregroundStyle(.secondary)
        } else if done {
            Text("playkit.compass.doneLine").foregroundStyle(.secondary)
            Label("playkit.compass.doneMark", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.green)
        } else {
            if stage.phase == .running {
                Label {
                    Text(LocalizedStringKey(stage.compass.signedDelta > 0 ? "playkit.compass.turnRight" : "playkit.compass.turnLeft"))
                        + Text(verbatim: " \(Int(abs(stage.compass.signedDelta).rounded()))°")
                } icon: {
                    Image(systemName: stage.compass.signedDelta > 0 ? "arrow.turn.up.right" : "arrow.turn.up.left")
                }
            } else {
                Text("playkit.compass.how")
            }
            if let hint = serverText("hint") {
                (Text("playkit.compass.hintLabel").bold() + Text(verbatim: " ") + Text(verbatim: hint))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// MP `g-figure` for the audio kits: seconds left, coloured by the live band, labelled for VoiceOver.
    private func audioFigure(_ value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(verbatim: value)
                .cyText(.dataXL)
                .monospacedDigit()
                .contentTransition(.numericText())
                .foregroundStyle(color)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: color)
            Text("playkit.sensor.secondsLeft").font(.subheadline).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
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
        // MP: once skipped the start button is gone (`wx:elif="{{!skipped}}"`).
        guard segment["skipped"].bool != true else { return nil }
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

/// MP `cp__dial`: the dial is the phone's facing (top = where you face). The rose turns with the heading, the white
/// lubber line marks the top, the green arc is the tolerance zone, the arrow points at the target and turns green
/// inside the zone; the hold ring fills while aligned. Drawn with system shapes and SF Symbols, no images.
@MainActor struct NativeCompassDial: View {
    let compass: PlayKitCompassRun
    let running: Bool
    let reduceMotion: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var size: CGFloat = 240

    private var hasHeading: Bool { compass.heading != nil }
    private var tone: Color { compass.aligned ? .green : .red }

    var body: some View {
        ZStack {
            Circle().strokeBorder(.quaternary, lineWidth: 2)
            if running, compass.aligned {
                Circle()
                    .trim(from: 0, to: min(1, compass.heldSeconds / max(0.1, compass.holdSeconds)))
                    .stroke(Color.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(2)
            }
            Circle()
                .trim(from: 0, to: min(1, compass.tolerance / 180))
                .stroke(Color.green.opacity(0.6), style: StrokeStyle(lineWidth: 6, lineCap: .butt))
                .rotationEffect(.degrees(-90 - compass.tolerance))
                .padding(10)
            rose
                .rotationEffect(.degrees(compass.roseDegrees))
                .animation(reduceMotion ? nil : .linear(duration: 0.16), value: compass.roseDegrees)
            VStack {
                Capsule().fill(.primary).frame(width: 3, height: 18)
                Spacer()
            }
            arrow
                .rotationEffect(.degrees(hasHeading ? compass.needleDegrees : 0))
                .animation(reduceMotion ? nil : .linear(duration: 0.16), value: compass.needleDegrees)
                .opacity(hasHeading ? 1 : 0.35)
            Circle().fill(.primary).frame(width: 12, height: 12)
        }
        .frame(width: min(size, 300), height: min(size, 300))
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("playkit.compass.dial"))
    }

    private var rose: some View {
        ZStack {
            ForEach(0..<72, id: \.self) { index in
                VStack {
                    Capsule()
                        .fill(index % 6 == 0 ? AnyShapeStyle(.secondary) : AnyShapeStyle(.tertiary))
                        .frame(width: index % 6 == 0 ? 2 : 1, height: index % 6 == 0 ? 12 : 6)
                    Spacer()
                }
                .padding(.top, 16)
                .rotationEffect(.degrees(Double(index) * 5))
            }
            if hasHeading {
                ForEach(0..<12, id: \.self) { index in
                    VStack {
                        label(index * 30)
                        Spacer()
                    }
                    .padding(.top, 32)
                    .rotationEffect(.degrees(Double(index) * 30))
                }
            }
        }
    }

    @ViewBuilder private func label(_ degrees: Int) -> some View {
        switch degrees {
        case 0: Text("playkit.compass.north").font(.headline).foregroundStyle(CYColor.dangerText)
        case 90: Text("playkit.compass.east").font(.subheadline.weight(.semibold))
        case 180: Text("playkit.compass.south").font(.subheadline.weight(.semibold))
        case 270: Text("playkit.compass.west").font(.subheadline.weight(.semibold))
        default: Text(verbatim: "\(degrees)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
    }

    private var arrow: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Image(systemName: "arrowtriangle.up.fill")
                    .font(.title)
                    .foregroundStyle(tone)
                Capsule().fill(tone.opacity(0.5)).frame(width: 3)
            }
            .padding(.top, 58)
            .frame(maxHeight: .infinity)
            Color.clear.frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}


/// MP `cy-play-calibrate` (play-stage, before ballshake / quiethold / shout): the kit's label
/// (拿成你打算玩的姿势 / 先听一下这儿有多吵), a bar that fills over the calibration window, then
/// 别动，量一下这儿的底子. One alert-style VoiceOver element, as the MP `aria-label`.
@MainActor struct NativeSensorCalibrationView: View {
    let kind: PlayKitScreenKind
    let startedAt: Date
    let seconds: TimeInterval

    private var labelKey: LocalizedStringKey {
        LocalizedStringKey(kind == .ballShake ? "playkit.calibrate.ball" : "playkit.calibrate.audio")
    }

    var body: some View {
        VStack(spacing: CYSpacing.sm) {
            Text(labelKey)
                .font(.headline)
                .multilineTextAlignment(.center)
            ProgressView(timerInterval: startedAt...startedAt.addingTimeInterval(seconds), countsDown: false) {
                EmptyView()
            } currentValueLabel: {
                EmptyView()
            }
            .tint(.primary)
            .frame(maxWidth: 220)
            Text("playkit.calibrate.sub")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, CYSpacing.sm)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(labelKey))
        .accessibilityValue(Text("playkit.calibrate.sub"))
        .accessibilityIdentifier("playkit.sensor.calibrating")
    }
}

/// MP `readfail` / `micdenied` (`playkit-view.js` P-23, round 11 i1): every failed read is reported once to
/// the server, which counts it toward the skip threshold. A denied permission or a missing sensor counts in
/// full (`denied: true`); a user stop or a background interruption is not a failure.
@MainActor struct NativeSensorFailureReport: ViewModifier {
    let kind: PlayKitScreenKind
    let issue: PlayKitSensorError?
    let report: ((Bool) -> Void)?

    func body(content: Content) -> some View {
        content.onChange(of: issue) { (old: PlayKitSensorError?, next: PlayKitSensorError?) in changed(old, next) }
    }

    private func changed(_ old: PlayKitSensorError?, _ next: PlayKitSensorError?) {
        guard let report, let next, next != old, let denied = Self.denied(kind: kind, issue: next) else { return }
        report(denied)
    }

    /// nil = not a reportable failure.
    static func denied(kind: PlayKitScreenKind, issue: PlayKitSensorError) -> Bool? {
        switch issue {
        case .permissionDenied: return kind != .ballShake
        case .sensorUnavailable: return kind == .compass
        case .missingSamples: return false
        case .interrupted, .configurationUnavailable: return nil
        }
    }
}
