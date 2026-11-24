import SwiftUI

// Celebration runtime + views (e4). Engine: CYCelebrationEngine.swift. Spec: docs/release/motion-spec-celebration.md.
// Three callers today: stamp slam (overlay), badge unlock (full-screen cover), roam summary (large sheet).
// No sound assets: the haptic map carries the beat. Under Reduce Motion every piece cross-fades and plays one haptic.

// MARK: - Copy

/// Bilingual copy from the voice guide (ux-strategy 4.6). Numbers are never formatted here; unknown stays a dash.
struct CYCelebrationCopy {
    let copy: CYKitCopy
    init(locale: Locale) { copy = CYKitCopy(locale: locale) }

    var stampLine: String { copy("Stamped. You were here.", "盖章成功，算你来过") }
    var stampEyebrow: String { copy("City stamp", "城市印章") }
    var shareStamp: String { copy("Share stamp", "分享这枚章") }
    var badgeEyebrow: String { copy("New badge", "新徽章") }
    var shareBadge: String { copy("Share badge", "分享徽章") }
    var keepBadge: String { copy("Keep in passport", "收进护照") }
    var walkTitle: String { copy("This walk", "这一趟") }
    var kmUnit: String { copy("km", "公里") }
    var tilesUnit: String { copy("tiles", "格") }
    var stampsUnit: String { copy("stamps", "枚章") }
    var tilesLit: String { copy("tiles lit", "格已点亮") }
    var shareWalk: String { copy("Share this walk", "分享这一趟") }
    var done: String { copy("Done", "完成") }
    var shareTitle: String { copy("Share", "分享") }
    var shareRendering: String { copy("Preparing your card", "正在生成卡片") }
    var shareAction: String { copy("Share card", "分享卡片") }
    var shareFailed: String { copy("Couldn't prepare the card. Try again.", "卡片生成失败，请再试一次") }
    var routeLabel: String { copy("Route of this walk", "这一趟的路线") }

    func badgeLine(name: String) -> String { "\(badgeEyebrow) · \(CYUnknown.text(name))" }

    func roamLine(_ p: CYRoamSummaryPayload) -> String {
        let km = "\(CYUnknown.decimal(p.kilometers)) \(kmUnit)"
        let tiles = "\(CYUnknown.count(p.tiles)) \(tilesUnit)"
        let stamps = "\(CYUnknown.count(p.stamps)) \(stampsUnit)"
        return "\(walkTitle)\(copy(": ", "：")) \(km) · \(tiles) · \(stamps)"
    }

    func announcement(for payload: CYCelebrationPayload) -> String {
        switch payload {
        case .stamp(let p):
            guard let place = p.place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty else { return stampLine }
            return "\(stampLine) \(place)"
        case .badge(let p): return badgeLine(name: p.name)
        case .roamSummary(let p): return roamLine(p)
        }
    }
}

// MARK: - Runtime

/// Drives `CYCelebrationState` with a real clock: plays the haptics (one at a time, never closer than 150 ms),
/// posts the VoiceOver announcement and wakes the machine at its next deadline. Own one per app session.
@MainActor @Observable
final class CYCelebrationCenter {
    private(set) var state = CYCelebrationState()
    var locale: Locale = .current
    /// Replaceable for fixtures; the default posts a VoiceOver announcement.
    @ObservationIgnored var announcer: @MainActor (String) -> Void = { text in AccessibilityNotification.Announcement(text).post() }
    /// Replaceable for fixtures; the default plays the real haptic.
    @ObservationIgnored var haptics: @MainActor (CYHaptics) -> Void = { $0.play() }

    @ObservationIgnored private var tickTask: Task<Void, Never>?
    @ObservationIgnored private var hapticTask: Task<Void, Never>?
    @ObservationIgnored private var lastPlayed: TimeInterval = -.infinity

    var current: CYCelebrationEvent? { state.current }

    private static func now() -> TimeInterval { ProcessInfo.processInfo.systemUptime }

    func enqueue(_ payload: CYCelebrationPayload) { apply(.enqueue(payload)) }
    func dismiss() { apply(.dismiss) }
    /// Dismisses only if `id` is still the active celebration (a late binding callback must not close the next one).
    func dismiss(ifCurrent id: Int) { if state.current?.id == id { apply(.dismiss) } }
    func setReduceMotion(_ value: Bool) { apply(.setReduceMotion(value)) }
    func setAssistive(_ value: Bool) { apply(.setAssistive(value)) }
    /// Stops the auto-dismiss clock of the active celebration (a share sheet is open on top of it).
    func hold(ifCurrent id: Int) { if state.current?.id == id { apply(.hold) } }

    private func apply(_ action: CYCelebrationAction) {
        let now = Self.now()
        let effects = state.reduce(action, now: now)
        var cues: [(CYHaptics, TimeInterval)] = []
        for effect in effects {
            switch effect {
            case .present: break
            case .announce(let event): announcer(CYCelebrationCopy(locale: locale).announcement(for: event.payload))
            case .haptic(let haptic, let at): cues.append((haptic, at))
            case .dismiss:
                hapticTask?.cancel()
                cues.removeAll()
            }
        }
        if !cues.isEmpty { runHaptics(cues) }
        scheduleTick(now: now)
    }

    private func runHaptics(_ cues: [(CYHaptics, TimeInterval)]) {
        hapticTask?.cancel()
        hapticTask = Task { [weak self] in
            for (haptic, at) in cues {
                // Timer jitter must never squeeze two cues closer than the engine's interval.
                let due = max(at, (self?.lastPlayed ?? 0) + CYCelebrationState.minimumHapticInterval)
                let wait = due - Self.now()
                if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
                guard !Task.isCancelled, let self else { return }
                self.lastPlayed = Self.now()
                self.haptics(haptic)
            }
        }
    }

    private func scheduleTick(now: TimeInterval) {
        tickTask?.cancel()
        guard let deadline = state.nextDeadline else { return }
        tickTask = Task { [weak self] in
            let wait = deadline - Self.now()
            if wait > 0 { try? await Task.sleep(for: .seconds(wait)) }
            guard !Task.isCancelled else { return }
            self?.apply(.tick)
        }
    }
}

// MARK: - Host

extension View {
    /// Mounts the celebration surfaces once, high in the tree (stamp overlay, badge cover, roam-summary sheet).
    /// Share opens a `CYShareCard` sheet from the cover / summary itself; `onShare` is only an observer of the tap.
    /// `shareEnabled: false` hides Share (Keep / Done become the one primary).
    func cyCelebrations(_ center: CYCelebrationCenter, shareEnabled: Bool = true, onShare: ((CYCelebrationEvent) -> Void)? = nil) -> some View {
        modifier(CYCelebrationHost(center: center, shareEnabled: shareEnabled, onShare: onShare))
            .environment(\.cyCelebrationCenter, center)
    }
}

/// Environment access for screens that enqueue a celebration without owning a host (the stamp camera, pushed under
/// `RoamBrowserView`). nil outside a host: callers simply skip the moment.
private struct CYCelebrationCenterKey: EnvironmentKey { static let defaultValue: CYCelebrationCenter? = nil }
extension EnvironmentValues {
    var cyCelebrationCenter: CYCelebrationCenter? {
        get { self[CYCelebrationCenterKey.self] }
        set { self[CYCelebrationCenterKey.self] = newValue }
    }
}

extension View {
    /// Only the stamp overlay of `cyCelebrations`, for a view that sits above the host's layer (inside a sheet).
    func cyStampOverlay(_ center: CYCelebrationCenter?, shareEnabled: Bool = true) -> some View {
        modifier(CYStampOverlayHost(center: center, shareEnabled: shareEnabled))
    }
}

struct CYStampOverlayHost: ViewModifier {
    let center: CYCelebrationCenter?
    let shareEnabled: Bool

    private var stamp: (CYCelebrationEvent, CYStampPayload)? {
        if let event = center?.current, case .stamp(let p) = event.payload { return (event, p) }
        return nil
    }

    func body(content: Content) -> some View {
        content
            .overlay {
                if let center, let (event, payload) = stamp {
                    CYStampSlamView(payload: payload, shareEnabled: shareEnabled, onHold: { center.hold(ifCurrent: event.id) }) { center.dismiss(ifCurrent: event.id) }
                        .id(event.id)
                        .transition(.opacity)
                }
            }
            .animation(CYMotion.reduced, value: stamp?.0.id)
    }
}

private struct CYCelebrationHost: ViewModifier {
    let center: CYCelebrationCenter
    let shareEnabled: Bool
    let onShare: ((CYCelebrationEvent) -> Void)?
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.locale) private var locale

    private var badge: (CYCelebrationEvent, CYBadgePayload)? {
        if let event = center.current, case .badge(let p) = event.payload { return (event, p) }
        return nil
    }
    private var roam: (CYCelebrationEvent, CYRoamSummaryPayload)? {
        if let event = center.current, case .roamSummary(let p) = event.payload { return (event, p) }
        return nil
    }

    /// Item binding so the cover/sheet keeps its content while it animates out.
    private func binding(_ event: CYCelebrationEvent?) -> Binding<CYCelebrationEvent?> {
        Binding(
            get: { event },
            set: { new in if new == nil, let event { center.dismiss(ifCurrent: event.id) } }
        )
    }

    func body(content: Content) -> some View {
        content
            .modifier(CYStampOverlayHost(center: center, shareEnabled: shareEnabled))
            .fullScreenCover(item: binding(badge?.0)) { event in
                if case .badge(let payload) = event.payload {
                    CYBadgeUnlockCover(
                        payload: payload,
                        shareEnabled: shareEnabled,
                        onShare: { onShare?(event) },
                        onKeep: { center.dismiss(ifCurrent: event.id) }
                    )
                }
            }
            .sheet(item: binding(roam?.0)) { event in
                if case .roamSummary(let payload) = event.payload {
                    CYRoamSummaryView(
                        payload: payload,
                        shareEnabled: shareEnabled,
                        onShare: { onShare?(event) },
                        onDone: { center.dismiss(ifCurrent: event.id) }
                    )
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
                }
            }
            .onAppear {
                center.locale = locale
                center.setReduceMotion(reduceMotion)
                center.setAssistive(voiceOver)
            }
            .onChange(of: locale) { _, new in center.locale = new }
            .onChange(of: reduceMotion) { _, new in center.setReduceMotion(new) }
            .onChange(of: voiceOver) { _, new in center.setAssistive(new) }
    }
}

// MARK: - Stamp slam

/// Choreography 5A (specs/design-wave3.md), every beat derived from one clock so it can be checked against the table:
///   0 ms     seal rises 40 pt and grows to 1.15 (pressed straight onto the ground, no card)
///   120 ms   seal drops (impactHeavy from the engine) and squashes to 0.92, the card dips 0.985
///   120-420  lantern ring expands 1 to 2.4x and fades, a second thinner ring follows 60 ms later
///   250 ms   success haptic (the engine keeps cues 150 ms apart, so it logs at about 270 ms)
///   300-1100 `CYBurst`, 36 lantern particles from the seal
///   450 ms   title and place rise 18 pt from below (after the squash has settled)
///   600 ms   passport mini-page (top right) flips once, the count rolls on `.numericText` (a dash when unknown)
///   900 ms   Share pill enters (hidden when sharing is off); auto-dismiss at 2.4 s, tap anywhere to dismiss early
/// Reduce Motion: the finished state cross-fades in, no particles, no flip.
struct CYStampSlamView: View {
    let payload: CYStampPayload
    var shareEnabled = true
    /// Called when Share is tapped so the host can stop the auto-dismiss clock while the sheet is open.
    var onHold: (() -> Void)?
    let onDismiss: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var start = Date()
    @State private var finished = false
    @State private var countShown = false
    @State private var sharing = false

    private static let hold = 1.4
    private static let sealBox: CGFloat = 236
    private static let sealSide: CGFloat = 170

    var body: some View {
        let copy = CYCelebrationCopy(locale: locale)
        TimelineView(.animation(paused: finished || reduceMotion)) { timeline in
            let e = reduceMotion ? 99 : timeline.date.timeIntervalSince(start)
            ZStack {
                CYNight.ink0.opacity(0.72 * min(1, e / 0.15)).ignoresSafeArea()
                VStack(spacing: CYSpacing.xl) {
                    seal(at: e)
                    titleBlock(copy, at: e)
                }
                .padding(CYSpacing.xxl)
                .contentShape(Rectangle())
                .onTapGesture(perform: onDismiss)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(verbatim: copy.announcement(for: .stamp(payload))))
                .accessibilityAddTraits([.isModal, .isButton])
                .accessibilityAction(.escape, onDismiss)
                .accessibilityIdentifier("cy.celebration.stamp")
                passport(copy, at: e)
                if shareEnabled { sharePill(copy, at: e) }
                if e >= 0.3 {
                    CYBurst(origin: UnitPoint(x: 0.5, y: 0.42), count: 48, duration: 1.4, reach: 210).ignoresSafeArea()
                }
            }
        }
        .sheet(isPresented: $sharing) {
            CYCelebrationShareSheet(content: CYCelebrationShare.stamp(payload, locale: locale))
        }
        .task { await play() }
    }

    // MARK: Beats

    private func ease(_ x: Double) -> Double { 1 - pow(1 - min(max(x, 0), 1), 3) }
    private func span(_ e: Double, _ from: Double, _ to: Double) -> Double { min(max((e - from) / (to - from), 0), 1) }

    /// Seal pose at `e` seconds: uniform scale, rise in pt, opacity, and the contact squash (x, y).
    private func pose(_ e: Double) -> (scale: Double, rise: Double, opacity: Double, squash: (Double, Double)) {
        if reduceMotion { return (1, 0, 1, (1, 1)) }
        if e < 0.12 { let u = ease(e / 0.12); return (1 + 0.15 * u, -40 * u, min(1, e / 0.06), (1, 1)) }
        if e < 0.22 { let u = (e - 0.12) / 0.10; let q = u * u; return (1.15 - 0.23 * q, -40 * (1 - q), 1, (1, 1)) }
        let d = e - 0.22
        // Two frames (about 34 ms) of hard contact: scaleY 0.9, a little wider; then the spring settles it.
        let squash: (Double, Double) = d < 0.034 ? (1.04, 0.9) : (1, 1)
        return (1 - 0.08 * exp(-7 * d) * cos(16 * d), 0, 1, squash)
    }

    private func seal(at e: Double) -> some View {
        let p = pose(e)
        let ringA = span(e, 0.12, 0.42), ringB = span(e, 0.18, 0.48), bleed = span(e, 0.22, 0.80)
        let landed = span(e, 0.12, 0.40)
        return ZStack {
            Circle().fill(CYNight.glow(radius: Self.sealSide / 2))
                .frame(width: Self.sealSide * 2.6, height: Self.sealSide * 2.6)
                .opacity(reduceMotion ? 0.8 : 0.9 * landed)
            if !reduceMotion {
                // Ink bleed: a soft wet halo that spreads past the seal edge and dries, then the two crisp rings.
                Circle().fill(CYNight.lantern.opacity(0.35))
                    .frame(width: Self.sealSide, height: Self.sealSide)
                    .blur(radius: 9)
                    .scaleEffect(0.95 + 0.30 * ease(bleed)).opacity(bleed > 0 ? 0.8 * (1 - bleed) : 0)
                Circle().strokeBorder(CYNight.lantern, lineWidth: 3)
                    .frame(width: Self.sealSide, height: Self.sealSide)
                    .scaleEffect(1 + 1.4 * ease(ringA)).opacity(ringA > 0 ? 0.8 * (1 - ringA) : 0)
                Circle().strokeBorder(CYNight.lanternHot, lineWidth: 1.5)
                    .frame(width: Self.sealSide, height: Self.sealSide)
                    .scaleEffect(1 + 1.4 * ease(ringB)).opacity(ringB > 0 ? 0.5 * (1 - ringB) : 0)
            }
            sealFace
                .scaleEffect(p.scale)
                .scaleEffect(x: p.squash.0, y: p.squash.1, anchor: .bottom)
                .offset(y: p.rise)
                .opacity(p.opacity)
        }
        .frame(width: Self.sealBox, height: Self.sealBox)
        .animation(CYMotion.reduced, value: reduceMotion)
    }

    /// A brass seal impression: serrated edge, inner ring, glyph engraved (dark cut with a light lower lip).
    private var sealFace: some View {
        let s = Self.sealSide
        return ZStack {
            CYSerratedCircle(teeth: 36, depth: 0.035)
                .fill(LinearGradient(colors: [CYNight.lanternHot, CYNight.lantern, CYNight.ember], startPoint: .topLeading, endPoint: .bottomTrailing))
            CYSerratedCircle(teeth: 36, depth: 0.035)
                .stroke(Color.white.opacity(0.35), lineWidth: 0.75)
            Circle().strokeBorder(CYNight.ink0.opacity(0.55), lineWidth: 3).padding(s * 0.11)
            Circle().strokeBorder(CYNight.ink0.opacity(0.35), style: StrokeStyle(lineWidth: 1.5, dash: [1.5, 5])).padding(s * 0.17)
            Circle().strokeBorder(Color.white.opacity(0.30), lineWidth: 1).padding(s * 0.11 + 3)
            ZStack {
                Image(systemName: payload.symbol).font(.system(size: s * 0.38, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.45)).offset(x: 1, y: 1.5)
                Image(systemName: payload.symbol).font(.system(size: s * 0.38, weight: .bold))
                    .foregroundStyle(CYNight.ink0.opacity(0.82))
            }
        }
        .frame(width: s, height: s)
        .shadow(color: CYNight.lantern.opacity(0.35), radius: 16)
    }

    private func titleBlock(_ copy: CYCelebrationCopy, at e: Double) -> some View {
        let u = reduceMotion ? 1 : ease(span(e, 0.45, 0.70))
        return VStack(spacing: CYSpacing.xs) {
            Text(verbatim: copy.stampLine)
                .cyText(.sheetTitle)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            if let place = payload.place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
                Text(verbatim: place).cyText(.bodyCompact).foregroundStyle(.white.opacity(0.8))
            }
        }
        .offset(y: 18 * (1 - u))
        .opacity(u)
    }

    /// Top-right mini page: flips once at 600 ms, the number rolls (dash while unknown).
    private func passport(_ copy: CYCelebrationCopy, at e: Double) -> some View {
        let flip = reduceMotion ? 0 : ease(span(e, 0.60, 1.0))
        let appear = reduceMotion ? 1 : span(e, 0.5, 0.6)
        return VStack {
            HStack {
                Spacer()
                HStack(spacing: CYSpacing.xs) {
                    Text(verbatim: countText)
                        .cyText(.cardTitle).monospacedDigit()
                        .foregroundStyle(.white)
                        .contentTransition(reduceMotion ? .opacity : .numericText())
                    Image(systemName: "book.closed.fill")
                        .font(.system(.title2, weight: .semibold))
                        .foregroundStyle(CYNight.lanternHot)
                        .frame(width: 48, height: 48)
                        .background(CYNight.ink2, in: RoundedRectangle(cornerRadius: CYRadius.sm, style: .continuous))
                        .rotation3DEffect(.degrees(360 * flip), axis: (x: 0, y: 1, z: 0))
                }
                .opacity(appear)
            }
            Spacer()
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.top, CYSpacing.xxl)
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var countText: String {
        guard let total = payload.passportCount, total >= 0 else { return CYUnknown.dash }
        return CYUnknown.count(countShown || reduceMotion ? total : max(0, total - 1))
    }

    private func sharePill(_ copy: CYCelebrationCopy, at e: Double) -> some View {
        let u = reduceMotion ? 1 : ease(span(e, 0.90, 1.10))
        return VStack {
            Spacer()
            CYPillButton(verbatim: copy.shareStamp, style: .primary) {
                onHold?()
                sharing = true
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
            .padding(.bottom, CYSpacing.lg)
            .offset(y: 16 * (1 - u))
            .opacity(u)
            .allowsHitTesting(e >= 0.90)
        }
    }

    private func play() async {
        if reduceMotion { return }
        let clock = ContinuousClock()
        let t0 = clock.now
        start = .now
        try? await clock.sleep(until: t0 + .milliseconds(600))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: CYMotion.Duration.quick)) { countShown = true }
        try? await clock.sleep(until: t0 + .seconds(Self.hold))
        guard !Task.isCancelled else { return }
        finished = true
    }
}

// MARK: - Badge unlock

/// Choreography 5B (heyozi), one clock, no pile of competing animations (specs/design-wave3.md):
///   0 ms      ground fades to `indigo` over `ink0`
///   150-600   dark silhouette of the medal at 0.2x fills white and lands on an ease-out-back overshoot (impactMedium at 450),
///             blurred lantern copies bloom behind it
///   600-900   horizon arc draws in under the medal
///   700-1300  seven stars orbit in (success haptic at 1000); the real medal takes over from the silhouette at 600
///   1100 ms   eyebrow + name rise 14 pt; 1400 a foil sheen sweeps the medal once
///   1500 ms   Share pill enters and the buttons go live (under 1.8 s to interactive); swipe down keeps at any time.
/// Reduce Motion: the finished state cross-fades in over 200 ms with one success haptic. Low Power: bloom without blur copies.
struct CYBadgeUnlockCover: View {
    let payload: CYBadgePayload
    var shareEnabled = true
    var onShare: (() -> Void)?
    let onKeep: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var start = Date()
    @State private var finished = false
    @State private var shown = false
    @State private var sharing = false

    private static let medalSide: CGFloat = 168
    /// Piecewise-linear phase of `CYStarBloom` against elapsed seconds, so beats land on the millisecond table.
    static func phase(at e: Double) -> Double {
        if e <= 0.15 { return 0 }
        if e <= 0.60 { return 0.45 * (e - 0.15) / 0.45 }
        if e <= 1.30 { return 0.45 + 0.55 * (e - 0.60) / 0.70 }
        return 1
    }
    static func span(_ e: Double, _ from: Double, _ to: Double) -> Double { min(max((e - from) / (to - from), 0), 1) }

    private var isZh: Bool { locale.identifier.hasPrefix("zh") }
    private var nameFont: Font { .system(size: 34, weight: isZh ? .semibold : .heavy, design: isZh ? .default : .rounded) }

    var body: some View {
        let copy = CYCelebrationCopy(locale: locale)
        TimelineView(.animation(paused: finished || reduceMotion)) { timeline in
            let e = reduceMotion ? 99 : timeline.date.timeIntervalSince(start)
            // Idle drift of the stars after the choreography has landed (no drift under Low Power).
            let drift = (e > 1.3 && CYLightBudget.shadersAllowed) ? (e - 1.3) * 0.25 : 0
            ZStack {
                ground(at: e)
                VStack(spacing: CYSpacing.xxl) {
                    Spacer(minLength: CYSpacing.xxxl)
                    stage(at: e, drift: drift)
                    titleBlock(copy, at: e)
                    Spacer(minLength: CYSpacing.lg)
                    buttons(copy, at: e)
                }
                .padding(.horizontal, CYSpacing.xxl)
                .padding(.bottom, CYSpacing.lg)
                // New badge (210:10045, r4): no particle bursts. xrefs-1 §3 row 13 rejects sparkle particles; the
                // badge art is the one object of this moment.
            }
            .opacity(reduceMotion ? (shown ? 1 : 0) : 1)
            // Every moment is skippable by a tap (skill-r2 SR2-49): a tap before the buttons land jumps to the end.
            .contentShape(Rectangle())
            .onTapGesture { if e < Self.settled { start = .distantPast } }
        }
        .gesture(
            DragGesture(minimumDistance: 24).onEnded { value in
                if value.translation.height > 80 { onKeep() }
            }
        )
        .accessibilityAction(.escape, onKeep)
        .sheet(isPresented: $sharing) {
            CYCelebrationShareSheet(content: CYCelebrationShare.badge(payload, locale: locale))
        }
        .accessibilityIdentifier("cy.celebration.badge")
        .task { await play() }
    }

    private func ground(at e: Double) -> some View {
        LinearGradient(colors: [CYNight.indigo, CYNight.ink0], startPoint: .top, endPoint: .bottom)
            .opacity(reduceMotion ? 1 : Self.span(e, 0, 0.15))
            .background(CYNight.ink0)
            .ignoresSafeArea()
    }

    private func stage(at e: Double, drift: Double) -> some View {
        let phase = Self.phase(at: e)
        let cheap = !CYLightBudget.shadersAllowed || reduceTransparency
        let kind = CYBadgeKind(seed: payload.id)
        let land = CYStarBloom<CYBadgeShape>.landScale(phase)
        // Live foil once the medal has taken over (1400 ms); a static highlight before that and under Reduce Motion / Low Power.
        let foil: Double? = (!reduceMotion && CYLightBudget.shadersAllowed && e >= 1.4) ? e : nil
        return ZStack {
            CYStarBloom(shape: CYBadgeShape(kind: kind), phase: reduceMotion ? 1 : phase, spin: drift, size: Self.medalSide, cheap: cheap)
            CYCraftedMedal(kind: kind, seed: payload.id, symbol: payload.symbol, size: Self.medalSide, foilTime: foil)
                .scaleEffect(reduceMotion ? 1 : land)
                .opacity(reduceMotion ? 1 : CYStarBloom<CYBadgeShape>.objectOpacity(phase))
        }
        .frame(height: 230)
        .accessibilityHidden(true)
    }

    private func titleBlock(_ copy: CYCelebrationCopy, at e: Double) -> some View {
        let u = reduceMotion ? 1 : CYStarBloom<CYBadgeShape>.easeOutBack(Self.span(e, 1.1, 1.4)) * Self.span(e, 1.1, 1.3)
        return VStack(spacing: CYSpacing.sm) {
            Text(verbatim: copy.badgeEyebrow)
                .cyText(.label)
                .textCase(.uppercase)
                .tracking(isZh ? 1 : 0.6)
                .foregroundStyle(CYNight.lantern)
            Text(verbatim: CYUnknown.text(payload.name))
                .font(nameFont)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
        }
        .fixedSize(horizontal: false, vertical: true)
        .offset(y: 14 * (1 - u))
        .opacity(min(1, u))
    }

    /// The choreography is settled (buttons in) by 1.5 s, the SR2-49 ceiling for a moment.
    static let settled: Double = 1.5

    @ViewBuilder private func buttons(_ copy: CYCelebrationCopy, at e: Double) -> some View {
        let u = reduceMotion ? 1 : Self.span(e, 1.3, Self.settled)
        VStack(spacing: CYSpacing.sm) {
            if shareEnabled {
                CYPillButton(verbatim: copy.shareBadge) { onShare?(); sharing = true }
                CYPillButton(verbatim: copy.keepBadge, style: .tertiary, action: onKeep)
            } else {
                CYPillButton(verbatim: copy.keepBadge, action: onKeep)
            }
        }
        .offset(y: 16 * (1 - u))
        .opacity(u)
        .allowsHitTesting(e >= Self.settled)
    }

    private func play() async {
        if reduceMotion {
            withAnimation(.easeInOut(duration: CYMotion.Duration.quick)) { shown = true }
            return
        }
        start = .now
        // Park the clock once everything has landed; the idle drift needs it, so only Low Power stops early.
        try? await Task.sleep(for: .seconds(2.0))
        guard !Task.isCancelled else { return }
        if !CYLightBudget.shadersAllowed { finished = true }
    }
}

// MARK: - Roam summary

/// Hero km (rolling, very large) centered; the route in a rounded map-like card (no route: the tiles-lit stat over a fog
/// glyph, never a made-up loop); tiles and stamps as two supporting tiles; the voice-table line; Share / Done pinned at
/// the bottom. The three numbers roll up staggered 50 ms on `.numericText`, the route draws after them, so at most
/// three animations run at once. An unknown number is a dash and does not roll.
struct CYRoamSummaryView: View {
    let payload: CYRoamSummaryPayload
    var shareEnabled = true
    var onShare: (() -> Void)?
    let onDone: () -> Void
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @State private var sharing = false

    var body: some View {
        let copy = CYCelebrationCopy(locale: locale)
        VStack(spacing: CYSpacing.xl) {
            Text(verbatim: copy.walkTitle)
                .cyText(.label)
                .textCase(.uppercase)
                .foregroundStyle(palette.textSecondary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, CYSpacing.xxl)
            CYRollingStat(target: payload.kilometers, fractionDigits: 1, unit: copy.kmUnit, delay: 0, emphasis: .hero)
            CYRoamRouteCard(payload: payload, copy: copy)
                .frame(maxHeight: .infinity)
            HStack(spacing: CYSpacing.md) {
                supportTile(CYRollingStat(target: payload.tiles.map(Double.init), fractionDigits: 0, unit: copy.tilesUnit, delay: 0.05, emphasis: .tile))
                supportTile(CYRollingStat(target: payload.stamps.map(Double.init), fractionDigits: 0, unit: copy.stampsUnit, delay: 0.10, emphasis: .tile))
            }
            // The announcement already reads this line; keep it visual so VoiceOver does not hear it twice.
            Text(verbatim: copy.roamLine(payload))
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
                .multilineTextAlignment(.center)
                .accessibilityHidden(true)
            VStack(spacing: CYSpacing.sm) {
                if shareEnabled {
                    CYPillButton(verbatim: copy.shareWalk) { onShare?(); sharing = true }
                    CYPillButton(verbatim: copy.done, style: .tertiary, action: onDone)
                } else {
                    CYPillButton(verbatim: copy.done, action: onDone)
                }
            }
        }
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.bottom, CYSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.bgPage.ignoresSafeArea())
        .sheet(isPresented: $sharing) {
            CYCelebrationShareSheet(
                content: CYCelebrationShare.walk(payload, locale: locale),
                routeContent: payload.route.isEmpty ? nil : CYCelebrationShare.walk(payload, locale: locale, includeRoute: true))
        }
        .accessibilityIdentifier("cy.celebration.roam")
    }

    private func supportTile(_ stat: CYRollingStat) -> some View {
        stat
            .padding(.vertical, CYSpacing.lg)
            .frame(maxWidth: .infinity)
            .background(palette.bgElevated, in: RoundedRectangle(cornerRadius: CYRadius.md, style: .continuous))
    }
}

/// The route panel. With a route: faint map-like grid and the route drawn on. Without one: a fog glyph and the
/// tiles-lit stat (a dash when unknown); nothing is invented.
struct CYRoamRouteCard: View {
    let payload: CYRoamSummaryPayload
    let copy: CYCelebrationCopy
    @Environment(\.cyPalette) private var palette

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(palette.bgElevated)
            if payload.route.isEmpty {
                VStack(spacing: CYSpacing.sm) {
                    Image(systemName: "cloud.fog.fill")
                        .font(.system(size: 44, weight: .regular))
                        .foregroundStyle(palette.textTertiary)
                        .accessibilityHidden(true)
                    Text(verbatim: "\(CYUnknown.count(payload.tiles)) \(copy.tilesLit)")
                        .cyText(.cardTitle)
                        .foregroundStyle(palette.textPrimary)
                        .accessibilityHidden(true)
                }
                .padding(CYSpacing.lg)
            } else {
                CYRouteGrid().stroke(palette.borderSubtle.opacity(0.6), lineWidth: 1)
                CYRouteDraw(points: payload.route, label: copy.routeLabel)
                    .padding(CYSpacing.xl)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .frame(minHeight: 160)
        .accessibilityIdentifier(payload.route.isEmpty ? "cy.celebration.roam.noroute" : "cy.celebration.roam.routecard")
    }
}

/// Decorative street-grid hint for the route panel.
private struct CYRouteGrid: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let step: CGFloat = 36
        var x = step
        while x < rect.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: rect.height)); x += step }
        var y = step
        while y < rect.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: rect.width, y: y)); y += step }
        return path
    }
}

/// One rolling number with its unit. `target == nil` is unknown: a dash, never a rolled zero.
struct CYRollingStat: View {
    let target: Double?
    let fractionDigits: Int
    let unit: String
    var delay: TimeInterval = 0
    var emphasis: Emphasis = .tile
    enum Emphasis { case hero, tile }
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 96
    @State private var shown: Double = 0
    @State private var started = false

    private var known: Double? {
        guard let target, target.isFinite, target >= 0 else { return nil }
        return target
    }
    private var finalText: String { CYUnknown.decimal(known, fractionDigits: fractionDigits) }
    private var text: String {
        guard known != nil else { return CYUnknown.dash }
        return CYUnknown.decimal(started || reduceMotion ? shown : 0, fractionDigits: fractionDigits)
    }

    var body: some View {
        VStack(spacing: CYSpacing.xs) {
            Text(verbatim: text)
                .font(emphasis == .hero ? .system(size: heroSize, weight: .bold, design: .rounded) : CYTypography.dataXL)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: shown))
            Text(verbatim: unit)
                .cyText(.meta)
                .foregroundStyle(palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: unit))
        .accessibilityValue(Text(verbatim: finalText))
        .task { await roll() }
    }

    private func roll() async {
        guard let known else { return }
        if reduceMotion {
            shown = known
            return
        }
        try? await Task.sleep(for: .seconds(delay))
        guard !Task.isCancelled else { return }
        started = true
        withAnimation(.easeOut(duration: CYMotion.Duration.slow)) { shown = known }
    }
}

/// Circle with a serrated (postage-stamp / seal) edge: `teeth` small notches, `depth` as a fraction of the radius.
struct CYSerratedCircle: Shape {
    var teeth = 36
    var depth: CGFloat = 0.035
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let c = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2, inner = outer * (1 - depth)
        let steps = teeth * 2
        for i in 0..<steps {
            let a = Double(i) / Double(steps) * 2 * .pi
            let r = i % 2 == 0 ? outer : inner
            let pt = CGPoint(x: c.x + CGFloat(cos(a)) * r, y: c.y + CGFloat(sin(a)) * r)
            if i == 0 { path.move(to: pt) } else { path.addLine(to: pt) }
        }
        path.closeSubpath()
        return path
    }
}
