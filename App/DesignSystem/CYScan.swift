import SwiftUI

// QR scan + success choreography kit (CYScan). Spec: docs/release/motion-spec-qr.md (adapted from the advisor spec).
// Pure state machine (`CYScanMachine`) + presentation pieces. Network / verification calls stay in the host
// view model: it feeds `verifyOK` / `verifyFailed` and renders `CYScanState`.

// MARK: - State machine

enum CYScanKind: Equatable { case ticket, stamp, club }

enum CYScanFailure: Equatable {
    case notChein, invalid, offline, timeout, cameraDenied
    case used(at: String?)
    case expired(until: String?)
    case wrongVenue(String?)
    case clubUnavailable

    /// Retryable failures cool down and resume scanning on their own.
    var isRetryable: Bool {
        switch self {
        case .notChein, .invalid, .offline, .timeout: return true
        case .used, .expired, .wrongVenue, .cameraDenied, .clubUnavailable: return false
        }
    }
    /// Keeps the view's lifetime pin so pointing at the same code never re-fires (`used`).
    var pinsPayload: Bool { if case .used = self { return true } else { return false } }
}

enum CYScanReward: Equatable {
    case checkedIn(title: String)
    case stamp(name: String, total: Int)
    case joined(club: String)
    /// Stamp scanned offline: saved locally, uploads when online.
    case queued
}

enum CYScanPhaseKey: Equatable { case idle, scanning, detected, verifying, success, failure, cooldown }

enum CYScanState: Equatable {
    case idle
    case scanning
    case detected(payload: String)
    case verifying(payload: String)
    case success(CYScanReward)
    case failure(CYScanFailure)
    case cooldown

    var phaseKey: CYScanPhaseKey {
        switch self {
        case .idle: return .idle
        case .scanning: return .scanning
        case .detected: return .detected
        case .verifying: return .verifying
        case .success: return .success
        case .failure: return .failure
        case .cooldown: return .cooldown
        }
    }
    /// The result card (collapsed QR) replaces the viewfinder.
    var showsCard: Bool {
        switch self {
        case .detected, .verifying, .success: return true
        default: return false
        }
    }
    var sweepActive: Bool { self == .scanning }
}

enum CYScanEvent: Equatable {
    case appear, cameraGranted, cameraDenied, cameraUnavailable
    case codeFound(String), codeLost
    case detectSettled                       // +120 ms after `detected`
    case verifyOK(CYScanReward), verifyFailed(CYScanFailure), verifyTimeout
    case offlineQueued
    case failureSettled                      // +600 ms after a failure
    case cooldownElapsed                     // 1.2 s later
    case tapRetry, tapManualEntry, backgrounded, dismiss
}

/// Value-type reducer. `online` / `validate` are read per event so a host can pass live values.
struct CYScanMachine: Equatable {
    var kind: CYScanKind
    private(set) var state: CYScanState = .idle
    private(set) var lastFailedPayload: String?
    private var currentPayload: String?

    init(kind: CYScanKind) { self.kind = kind }

    @discardableResult
    mutating func send(_ event: CYScanEvent, online: Bool = true, validate: (String) -> Bool = { _ in true }) -> CYScanState {
        switch (state, event) {
        case (.idle, .cameraGranted):
            state = .scanning
        case (_, .cameraDenied):
            state = .failure(.cameraDenied)
        case (.scanning, .codeFound(let payload)):
            guard payload != lastFailedPayload else { break }
            if validate(payload) {
                currentPayload = payload
                state = .detected(payload: payload)
            } else {
                lastFailedPayload = payload
                state = .failure(.notChein)
            }
        case (.detected(let payload), .detectSettled):
            if online { state = .verifying(payload: payload) }
            else if kind == .stamp { state = .success(.queued) }
            else { state = .failure(.offline) }
        case (.verifying, .verifyOK(let reward)):
            state = .success(reward)
        case (.verifying, .offlineQueued):
            state = .success(.queued)
        case (.verifying, .verifyFailed(let failure)):
            if failure.pinsPayload { lastFailedPayload = currentPayload }
            state = .failure(failure)
        case (.verifying, .verifyTimeout):
            state = .failure(.timeout)
        // Backgrounding mid-verify cancels; the host re-queries the server on resume and never replays success.
        case (.verifying, .backgrounded), (.detected, .backgrounded):
            state = .idle
        case (.failure(let failure), .failureSettled):
            if failure.isRetryable { state = .cooldown }
        case (.cooldown, .cooldownElapsed):
            state = .scanning
        case (.failure(let failure), .tapRetry):
            if failure != .cameraDenied, failure != .clubUnavailable { state = .scanning }
        case (_, .dismiss):
            state = .idle
        default:
            break   // duplicate scans while detected / verifying, late events, etc. are ignored
        }
        return state
    }
}

// MARK: - Scan line

/// Scan line: 2 pt, success colour with a soft glow, ping-pong sweep. TimelineView + Canvas (no @State churn).
/// Paused when inactive; absent under Reduce Motion.
struct CYScanSweep: View {
    var active: Bool
    var period: Double = 1.6
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        if reduceMotion {
            Color.clear.accessibilityHidden(true)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !active)) { context in
                Canvas { graphics, size in
                    let seconds = context.date.timeIntervalSinceReferenceDate
                    let phase = seconds.truncatingRemainder(dividingBy: period) / period
                    let eased = 0.5 - 0.5 * cos(Double.pi * 2 * phase)
                    let y = size.height * CGFloat(eased)
                    let glow = Path(CGRect(x: 0, y: y - 10, width: size.width, height: 20))
                    graphics.fill(glow, with: .linearGradient(
                        Gradient(colors: [.clear, palette.success.opacity(0.35), .clear]),
                        startPoint: CGPoint(x: 0, y: y - 10), endPoint: CGPoint(x: 0, y: y + 10)))
                    graphics.fill(Path(CGRect(x: 0, y: y - 1, width: size.width, height: 2)), with: .color(palette.success))
                }
                .opacity(active ? 1 : 0)
                .animation(.easeOut(duration: 0.12), value: active)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

// MARK: - Viewfinder

private struct CYBracketShape: Shape {
    var arm: CGFloat = 28
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect
        path.move(to: CGPoint(x: r.minX, y: r.minY + arm)); path.addLine(to: CGPoint(x: r.minX, y: r.minY)); path.addLine(to: CGPoint(x: r.minX + arm, y: r.minY))
        path.move(to: CGPoint(x: r.maxX - arm, y: r.minY)); path.addLine(to: CGPoint(x: r.maxX, y: r.minY)); path.addLine(to: CGPoint(x: r.maxX, y: r.minY + arm))
        path.move(to: CGPoint(x: r.maxX, y: r.maxY - arm)); path.addLine(to: CGPoint(x: r.maxX, y: r.maxY)); path.addLine(to: CGPoint(x: r.maxX - arm, y: r.maxY))
        path.move(to: CGPoint(x: r.minX + arm, y: r.maxY)); path.addLine(to: CGPoint(x: r.minX, y: r.maxY)); path.addLine(to: CGPoint(x: r.minX, y: r.maxY - arm))
        return path
    }
}

/// Square viewfinder: the host's camera/still `preview` clipped inside four corner brackets and the sweep line.
/// A failure flashes the brackets red once and nudges the frame sideways (matches the result mark's failure nudge).
struct CYViewfinder<Preview: View>: View {
    var state: CYScanState
    var side: CGFloat = 240
    @ViewBuilder var preview: () -> Preview
    @Environment(\.cyPalette) private var palette
    @Environment(\.dynamicTypeSize) private var typeSize
    @QuestifyReduceMotion private var reduceMotion
    @State private var nudge: CGFloat = 0
    @State private var flash = false

    private var size: CGFloat { typeSize.isAccessibilitySize ? min(side, 200) : side }
    private var isFailure: Bool { state.phaseKey == .failure }

    var body: some View {
        ZStack {
            preview()
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
                .accessibilityHidden(true)
            CYScanSweep(active: state.sweepActive)
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
            bracketLayer
        }
        .frame(width: size, height: size)
        .offset(x: nudge)
        .onChange(of: isFailure) { _, failed in
            guard failed else { return }
            flash = true
            if reduceMotion {
                Task { try? await Task.sleep(for: .milliseconds(360)); flash = false }
            } else {
                nudge = 7
                withAnimation(.spring(response: 0.3, dampingFraction: 0.35)) { nudge = 0 }
                withAnimation(.easeIn(duration: 0.12)) { flash = true }
                Task { try? await Task.sleep(for: .milliseconds(120)); withAnimation(.easeOut(duration: 0.24)) { flash = false } }
            }
        }
    }

    @ViewBuilder private var bracketLayer: some View {
        let brackets = CYBracketShape()
            .stroke(flash ? palette.danger : palette.textPrimary.opacity(0.85), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
            .frame(width: size, height: size)
        if reduceMotion && state.sweepActive {
            // No sweep under Reduce Motion: the brackets breathe instead (opacity only).
            TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { context in
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2.4) / 2.4
                brackets.opacity(0.8 + 0.2 * cos(Double.pi * 2 * t))
            }
        } else {
            brackets
        }
    }
}

// MARK: - Result mark, orbit dots, count-up

enum CYScanMarkKind: Equatable { case pending, success, failure }

/// Pending arc -> ring + check strokes -> bloom. Self-contained (no dependency on the purchase kit).
/// Reduce Motion: drawn complete at once.
struct CYScanMark: View {
    var kind: CYScanMarkKind
    var size: CGFloat = 72
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var ring: CGFloat = 0
    @State private var stroke: CGFloat = 0
    @State private var bloom: CGFloat = 0.82

    private struct CheckShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.width * 0.28, y: rect.height * 0.53))
            path.addLine(to: CGPoint(x: rect.width * 0.44, y: rect.height * 0.68))
            path.addLine(to: CGPoint(x: rect.width * 0.72, y: rect.height * 0.35))
            return path
        }
    }
    private struct CrossShape: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.width * 0.32, y: rect.height * 0.32)); path.addLine(to: CGPoint(x: rect.width * 0.68, y: rect.height * 0.68))
            path.move(to: CGPoint(x: rect.width * 0.68, y: rect.height * 0.32)); path.addLine(to: CGPoint(x: rect.width * 0.32, y: rect.height * 0.68))
            return path
        }
    }

    var body: some View {
        ZStack {
            switch kind {
            case .pending:
                Circle().stroke(palette.textPrimary.opacity(0.15), lineWidth: 3)
                TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: reduceMotion)) { context in
                    let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.1) / 1.1
                    Circle().trim(from: 0, to: 0.28)
                        .stroke(palette.textPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(reduceMotion ? 0 : 360 * turn))
                }
            case .success:
                Circle().trim(from: 0, to: ring)
                    .stroke(palette.success, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                CheckShape().trim(from: 0, to: stroke)
                    .stroke(palette.success, style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            case .failure:
                Circle().stroke(palette.danger, lineWidth: 4)
                CrossShape().trim(from: 0, to: stroke)
                    .stroke(palette.danger, style: StrokeStyle(lineWidth: 5, lineCap: .round))
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(kind == .success ? bloom : 1)
        .onAppear { draw(kind) }
        .onChange(of: kind) { _, new in draw(new) }
        .accessibilityHidden(true)
    }

    private func draw(_ new: CYScanMarkKind) {
        guard new != .pending else { return }
        if reduceMotion { ring = 1; stroke = 1; bloom = 1; return }
        ring = 0; stroke = 0; bloom = 0.82
        withAnimation(.easeOut(duration: 0.35)) { ring = 1 }
        withAnimation(.easeInOut(duration: 0.4).delay(0.2)) { stroke = 1 }
        withAnimation(CYMotion.entrance) { bloom = 1 }
    }
}

/// Three 4 pt dots born at the mark centre, one revolution out to a wider orbit, fading in the last 30%.
struct CYOrbitDots: View {
    var fire: Bool
    var count = 3
    /// Orbit starts at `radius` and widens by `spread` (defaults suit the 72 pt mark).
    var radius: CGFloat = 28
    var spread: CGFloat = 16
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var progress: CGFloat = 0

    var body: some View {
        ZStack {
            ForEach(0..<count, id: \.self) { index in
                Circle().fill(palette.success).frame(width: 4, height: 4)
                    .offset(y: -(radius + spread * progress))
                    .rotationEffect(.degrees(Double(index) * 360 / Double(count) + 360 * Double(progress)))
                    .opacity(progress >= 1 || progress == 0 ? 0 : (progress > 0.7 ? Double(1 - (progress - 0.7) / 0.3) : 1))
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
        .onChange(of: fire) { _, on in
            guard on, !reduceMotion else { return }
            progress = 0
            withAnimation(.easeOut(duration: 0.6)) { progress = 1 }
        }
    }
}

private struct CYCountValue: View, Animatable {
    var value: Double
    var animatableData: Double { get { value } set { value = newValue } }
    var body: some View { Text(Int(value.rounded()), format: .number).monospacedDigit() }
}

/// Counter that rolls `from` -> `to` over 0.6 s when `fire` turns true and lands on exactly `to`.
/// Two soft `.selection` ticks at 50% and 100%. Reduce Motion: a single swap, the ticks still fire.
struct CYCountUp: View {
    var from: Int
    var to: Int
    var fire: Bool
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown: Double?

    var body: some View {
        CYCountValue(value: shown ?? Double(from))
            .minimumScaleFactor(0.7)
            .lineLimit(1)
            .onAppear { if fire { run() } }
            .onChange(of: fire) { _, on in if on { run() } }
            .accessibilityLabel(Text(verbatim: "\(to)"))
    }

    private func run() {
        guard shown != Double(to) else { return }
        if reduceMotion { shown = Double(to) } else { withAnimation(.easeOut(duration: 0.6)) { shown = Double(to) } }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300)); CYHaptics.selection.play()
            try? await Task.sleep(for: .milliseconds(300)); CYHaptics.selection.play()
        }
    }
}

// MARK: - Result card

/// Copy the host supplies for the card; the card owns timing only.
struct CYScanCardContent {
    var title: Text
    var subtitle: Text?
    /// Reward counter (stamp total, points): rolls from -> to once the title has landed.
    var counter: (from: Int, to: Int, label: Text)?
    var announcement: String
}

/// Collapsed-QR card: pending arc, then (t = success): mark completes, orbit dots +200 ms, title +300 ms,
/// count-up +400 ms, CTA +1200 ms. The pending arc is always visible for at least 700 ms.
struct CYScanResultCard: View {
    var state: CYScanState
    var content: CYScanCardContent?
    var doneTitle: LocalizedStringKey = "scan.done"
    var onDone: () -> Void = {}
    var pendingHold: Duration = .milliseconds(700)

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var pendingSince = ContinuousClock.now
    @State private var mark: CYScanMarkKind = .pending
    private static func succeeded(_ old: CYScanMarkKind, _ new: CYScanMarkKind) -> Bool { new == .success }
    @State private var orbit = false
    @State private var titleIn = false
    @State private var countIn = false
    @State private var ctaIn = false
    @AccessibilityFocusState private var titleFocused: Bool

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            ZStack {
                CYScanMark(kind: mark, size: 72)
                CYOrbitDots(fire: orbit)
            }
            .frame(width: 96, height: 96)
            if mark == .pending {
                Text("scan.verifying").cyText(.body).foregroundStyle(palette.textSecondary)
            }
            if let content {
                VStack(spacing: CYSpacing.xs) {
                    content.title.cyText(.cardTitle).foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityFocused($titleFocused)
                    if let subtitle = content.subtitle {
                        subtitle.cyText(.body).foregroundStyle(palette.textSecondary).multilineTextAlignment(.center)
                    }
                }
                .opacity(titleIn ? 1 : 0)
                .offset(y: titleIn || reduceMotion ? 0 : 10)
                if let counter = content.counter {
                    HStack(spacing: CYSpacing.sm) {
                        CYCountUp(from: counter.from, to: counter.to, fire: countIn)
                            .cyText(.cardTitle).foregroundStyle(palette.success)
                        counter.label.cyText(.body).foregroundStyle(palette.textSecondary)
                    }
                    .opacity(titleIn ? 1 : 0)
                    .accessibilityElement(children: .combine)
                }
            }
            if ctaIn {
                CYPillButton(doneTitle, action: onDone)
                    .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(CYSpacing.xl)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .cyHaptic(.success, trigger: mark, where: Self.succeeded)
        .task(id: state) { await sequence() }
    }

    private func sequence() async {
        guard case .success = state else {
            if state.phaseKey == .detected || state.phaseKey == .verifying {
                if state.phaseKey == .detected { pendingSince = .now }
                mark = .pending; orbit = false; titleIn = false; countIn = false; ctaIn = false
            }
            return
        }
        let animated = !reduceMotion
        let remaining = pendingHold - (ContinuousClock.now - pendingSince)
        if animated, remaining > .zero { try? await Task.sleep(for: remaining) }
        guard !Task.isCancelled else { return }
        mark = .success
        if let content { AccessibilityNotification.Announcement(content.announcement).post() }
        if !animated {
            titleIn = true; countIn = true; ctaIn = true; orbit = false
            titleFocused = true
            return
        }
        try? await Task.sleep(for: .milliseconds(200)); guard !Task.isCancelled else { return }
        orbit = true
        try? await Task.sleep(for: .milliseconds(100)); guard !Task.isCancelled else { return }
        withAnimation(CYMotion.entrance) { titleIn = true }
        titleFocused = true
        try? await Task.sleep(for: .milliseconds(100)); guard !Task.isCancelled else { return }
        countIn = true
        try? await Task.sleep(for: .milliseconds(800)); guard !Task.isCancelled else { return }
        withAnimation(CYMotion.entrance) { ctaIn = true }
    }
}

// MARK: - Failure banner

/// Reason copy below the viewfinder, never over the camera. Keys: `scan.fail.<kind>.title` / `.body`.
struct CYScanFailureBanner: View {
    var failure: CYScanFailure
    var onRetry: () -> Void = {}
    var onManual: (() -> Void)?
    var onSettings: (() -> Void)?
    var onViewPass: (() -> Void)?
    @Environment(\.cyPalette) private var palette

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Label { title.cyText(.cardTitle) } icon: { Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(palette.danger) }
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
            body_.cyText(.body).foregroundStyle(palette.textSecondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: CYSpacing.sm) {
                switch failure {
                case .notChein: EmptyView()
                case .invalid:
                    CYPillButton("scan.retry", style: .secondary, action: onRetry)
                    if let onManual { CYPillButton("scan.manual", style: .secondary, action: onManual) }
                case .used, .expired, .wrongVenue:
                    if let onViewPass { CYPillButton("scan.viewPass", action: onViewPass) }
                    else { CYPillButton("scan.retry", style: .secondary, action: onRetry) }
                case .offline, .timeout:
                    CYPillButton("scan.retry", action: onRetry)
                case .cameraDenied:
                    if let onSettings { CYPillButton("scan.settings", action: onSettings) }
                    if let onManual { CYPillButton("scan.manual", style: .secondary, action: onManual) }
                case .clubUnavailable:
                    CYPillButton("scan.back", style: .secondary, action: onRetry)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(CYSpacing.lg)
        .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    private var title: Text {
        switch failure {
        case .notChein: return Text("scan.fail.notChein.title")
        case .invalid: return Text("scan.fail.invalid.title")
        case .used: return Text("scan.fail.used.title")
        case .expired: return Text("scan.fail.expired.title")
        case .wrongVenue: return Text("scan.fail.wrongVenue.title")
        case .offline: return Text("scan.fail.offline.title")
        case .timeout: return Text("scan.fail.timeout.title")
        case .cameraDenied: return Text("scan.fail.cameraDenied.title")
        case .clubUnavailable: return Text("scan.fail.club.title")
        }
    }
    private var body_: Text {
        switch failure {
        case .notChein: return Text("scan.fail.notChein.body")
        case .invalid: return Text("scan.fail.invalid.body")
        case .used(let at): return at.map { Text("scan.fail.used.body \($0)") } ?? Text("scan.fail.used.bodyNoTime")
        case .expired(let until): return until.map { Text("scan.fail.expired.body \($0)") } ?? Text("scan.fail.expired.bodyNoDate")
        case .wrongVenue(let venue): return venue.map { Text("scan.fail.wrongVenue.body \($0)") } ?? Text("scan.fail.wrongVenue.bodyNoVenue")
        case .offline: return Text("scan.fail.offline.body")
        case .timeout: return Text("scan.fail.timeout.body")
        case .cameraDenied: return Text("scan.fail.cameraDenied.body")
        case .clubUnavailable: return Text("scan.fail.club.body")
        }
    }
}

// MARK: - Stage (viewfinder <-> card)

/// One stage for the whole flow. `preview` is the host's camera layer / still; the viewfinder and the result
/// card share the "code" geometry id, so the frozen code appears to collapse into the card. Reduce Motion: the
/// two cross-fade with no matched geometry. Detect / failure haptics live here, success haptic in the card.
struct CYScanStage<Preview: View>: View {
    var state: CYScanState
    var card: CYScanCardContent?
    var onDone: () -> Void = {}
    @ViewBuilder var preview: () -> Preview
    @Namespace private var namespace
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        let animation: Animation = reduceMotion ? CYMotion.reduced : .spring(response: 0.42, dampingFraction: 0.86)
        let key = state.phaseKey
        let animated = stageContent.animation(animation, value: state.showsCard)
        return hapticStage(animated, key: key)
    }

    private func hapticStage<V: View>(_ content: V, key: CYScanPhaseKey) -> some View {
        let detected = content.cyHaptic(.impactMedium, trigger: key) { (_: CYScanPhaseKey, new: CYScanPhaseKey) in new == .detected }
        let failed = detected.cyHaptic(.warning, trigger: key) { (_: CYScanPhaseKey, new: CYScanPhaseKey) in new == .failure }
        return failed.cyHaptic(.impactLight, trigger: key) { (old: CYScanPhaseKey, new: CYScanPhaseKey) in old == .idle && new == .scanning }
    }

    @ViewBuilder private var stageContent: some View {
        if state.showsCard {
            CYScanResultCard(state: state, content: card, onDone: onDone)
                .frame(maxWidth: 340)
                .modifier(CYScanMatched(namespace: namespace, enabled: !reduceMotion))
                .transition(.opacity)
        } else {
            CYViewfinder(state: state, preview: preview)
                .modifier(CYScanMatched(namespace: namespace, enabled: !reduceMotion))
                .transition(.opacity)
        }
    }
}

private struct CYScanMatched: ViewModifier {
    let namespace: Namespace.ID
    let enabled: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if enabled { content.matchedGeometryEffect(id: "code", in: namespace) } else { content }
    }
}
