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
    var badgeEyebrow: String { copy("New badge", "新徽章") }
    var shareBadge: String { copy("Share badge", "分享徽章") }
    var keepBadge: String { copy("Keep in passport", "收进护照") }
    var walkTitle: String { copy("This walk", "这一趟") }
    var kmUnit: String { "km" }
    var tilesUnit: String { copy("tiles", "格") }
    var stampsUnit: String { copy("stamps", "枚章") }
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
    }
}

private struct CYCelebrationHost: ViewModifier {
    let center: CYCelebrationCenter
    let shareEnabled: Bool
    let onShare: ((CYCelebrationEvent) -> Void)?
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOver
    @Environment(\.locale) private var locale

    private var stamp: (CYCelebrationEvent, CYStampPayload)? {
        if let event = center.current, case .stamp(let p) = event.payload { return (event, p) }
        return nil
    }
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
            .overlay {
                if let (event, payload) = stamp {
                    CYStampSlamView(payload: payload) { center.dismiss(ifCurrent: event.id) }
                        .id(event.id)
                        .transition(.opacity)
                }
            }
            .animation(CYMotion.reduced, value: stamp?.0.id)
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

/// Seal drops 40 pt, squashes 1.0 to 0.92 to 1.0 on `spring(0.32, 0.55)`, an ink ring expands and fades over 0.5 s,
/// then the line fades in. Reduce Motion: the finished state cross-fades in. Tap anywhere to dismiss early.
struct CYStampSlamView: View {
    let payload: CYStampPayload
    let onDismiss: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @State private var step = 0
    @State private var ring: CGFloat = 0
    @State private var lineShown = false

    private static let ink = Color(red: 0.98, green: 0.45, blue: 0.40)

    private var scale: CGFloat {
        if reduceMotion { return 1 }
        switch step {
        case 0: return 1.15
        case 1: return 0.92
        default: return 1
        }
    }

    var body: some View {
        let copy = CYCelebrationCopy(locale: locale)
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()
            VStack(spacing: CYSpacing.xl) {
                ZStack {
                    Circle()
                        .strokeBorder(Self.ink, lineWidth: 3)
                        .scaleEffect(1 + ring * 0.6)
                        .opacity(Double(0.6 * (1 - ring)))
                    seal
                        .scaleEffect(scale)
                        .offset(y: step == 0 && !reduceMotion ? -40 : 0)
                        .opacity(step == 0 && !reduceMotion ? 0 : 1)
                }
                .frame(width: 170, height: 170)
                VStack(spacing: CYSpacing.xs) {
                    Text(verbatim: copy.stampLine)
                        .font(CYTypography.sheetTitle)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    if let place = payload.place?.trimmingCharacters(in: .whitespacesAndNewlines), !place.isEmpty {
                        Text(verbatim: place).font(CYTypography.bodyCompact).foregroundStyle(.white.opacity(0.8))
                    }
                }
                .opacity(lineShown || reduceMotion ? 1 : 0)
            }
            .padding(CYSpacing.xxl)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onDismiss)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(verbatim: copy.announcement(for: .stamp(payload))))
        .accessibilityAddTraits([.isModal, .isButton])
        .accessibilityAction(.escape, onDismiss)
        .accessibilityIdentifier("cy.celebration.stamp")
        .task { await play() }
    }

    private var seal: some View {
        ZStack {
            Circle().strokeBorder(Self.ink, lineWidth: 6)
            Circle().strokeBorder(Self.ink.opacity(0.7), style: StrokeStyle(lineWidth: 2, dash: [2, 6])).padding(16)
            Image(systemName: payload.symbol)
                .font(.system(size: 64, weight: .bold))
                .foregroundStyle(Self.ink)
        }
        .frame(width: 170, height: 170)
        .background(Circle().fill(Self.ink.opacity(0.10)))
        .shadow(color: Self.ink.opacity(0.35), radius: 16)
    }

    private func play() async {
        if reduceMotion {
            step = 2
            return
        }
        withAnimation(.easeIn(duration: CYMotion.Duration.quick)) { step = 1 }
        try? await Task.sleep(for: .seconds(0.22))
        guard !Task.isCancelled else { return }
        withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { step = 2 }
        withAnimation(.easeOut(duration: 0.5)) { ring = 1 }
        try? await Task.sleep(for: .seconds(0.2))
        guard !Task.isCancelled else { return }
        withAnimation(.easeOut(duration: CYMotion.Duration.quick)) { lineShown = true }
    }
}

// MARK: - Badge unlock

/// Full-screen cover: medal lands on `spring(0.6, 0.58)` from 1.4x over a radial glow (background, not overlay),
/// one confetti burst, eyebrow + name, Share primary and Keep secondary. Swipe down also keeps. Without an `onShare`
/// the Share button is absent and Keep becomes the one primary.
struct CYBadgeUnlockCover: View {
    let payload: CYBadgePayload
    var shareEnabled = true
    var onShare: (() -> Void)?
    let onKeep: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @Environment(\.locale) private var locale
    @State private var landed = false
    @State private var burst = 0
    @State private var sharing = false

    var body: some View {
        let copy = CYCelebrationCopy(locale: locale)
        ZStack {
            palette.bgPage.ignoresSafeArea()
            VStack(spacing: CYSpacing.xxl) {
                Spacer(minLength: CYSpacing.xxxl)
                CYBadgeMedal(seed: payload.id, symbol: payload.symbol, size: 168)
                    .scaleEffect(landed || reduceMotion ? 1 : 1.4)
                    .opacity(landed || reduceMotion ? 1 : 0)
                    .background { glow }
                    .frame(height: 230)
                VStack(spacing: CYSpacing.sm) {
                    Text(verbatim: copy.badgeEyebrow)
                        .font(CYTypography.label)
                        .textCase(.uppercase)
                        .foregroundStyle(palette.textSecondary)
                    Text(verbatim: CYUnknown.text(payload.name))
                        .font(CYTypography.display)
                        .foregroundStyle(palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .accessibilityAddTraits(.isHeader)
                }
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: CYSpacing.lg)
                VStack(spacing: CYSpacing.sm) {
                    if shareEnabled {
                        CYPillButton(verbatim: copy.shareBadge) { onShare?(); sharing = true }
                        CYPillButton(verbatim: copy.keepBadge, style: .tertiary, action: onKeep)
                    } else {
                        CYPillButton(verbatim: copy.keepBadge, action: onKeep)
                    }
                }
            }
            .padding(.horizontal, CYSpacing.xxl)
            .padding(.bottom, CYSpacing.lg)
            CYConfettiBurst(trigger: burst)
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
        .task { await land() }
    }

    private var glow: some View {
        Circle()
            .fill(RadialGradient(colors: [Color(red: 1.0, green: 0.84, blue: 0.40).opacity(0.5), .clear], center: .center, startRadius: 8, endRadius: 190))
            .frame(width: 380, height: 380)
            .opacity(landed || reduceMotion ? 1 : 0)
            .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: CYMotion.Duration.slow), value: landed)
            .accessibilityHidden(true)
    }

    private func land() async {
        if reduceMotion {
            landed = true
            return
        }
        withAnimation(.spring(response: 0.6, dampingFraction: 0.58)) { landed = true }
        try? await Task.sleep(for: .seconds(0.3))
        guard !Task.isCancelled else { return }
        burst += 1
    }
}

// MARK: - Roam summary

/// "This walk: 2.4 km · 31 tiles · 2 stamps". Three numbers roll up staggered 50 ms on `.numericText`; an unknown
/// number is a dash and does not roll. At most three animations run at once.
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
        VStack(spacing: CYSpacing.xxl) {
            Text(verbatim: copy.walkTitle)
                .font(CYTypography.sheetTitle)
                .foregroundStyle(palette.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .padding(.top, CYSpacing.xxl)
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: CYSpacing.lg) { stats(copy) }
                VStack(spacing: CYSpacing.lg) { stats(copy) }
            }
            .frame(maxWidth: .infinity)
            if !payload.route.isEmpty {
                CYRouteDraw(points: payload.route, label: copy.routeLabel)
                    .frame(maxWidth: .infinity, maxHeight: 220)
            }
            Spacer(minLength: CYSpacing.lg)
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

    @ViewBuilder private func stats(_ copy: CYCelebrationCopy) -> some View {
        CYRollingStat(target: payload.kilometers, fractionDigits: 1, unit: copy.kmUnit, delay: 0)
        CYRollingStat(target: payload.tiles.map(Double.init), fractionDigits: 0, unit: copy.tilesUnit, delay: 0.05)
        CYRollingStat(target: payload.stamps.map(Double.init), fractionDigits: 0, unit: copy.stampsUnit, delay: 0.10)
    }
}

/// One rolling number with its unit. `target == nil` is unknown: a dash, never a rolled zero.
struct CYRollingStat: View {
    let target: Double?
    let fractionDigits: Int
    let unit: String
    var delay: TimeInterval = 0
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette
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
                .font(CYTypography.data2XL)
                .monospacedDigit()
                .foregroundStyle(palette.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .contentTransition(reduceMotion ? .opacity : .numericText(value: shown))
            Text(verbatim: unit)
                .font(CYTypography.meta)
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
