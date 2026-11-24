import SwiftUI

// Onboarding (player, first launch): one "city disc" hero carries five steps; each step has a tiny demo of the
// real mechanic. Presentation only: the flow reports `.register` / `.guest` to its host, which runs the existing
// sign-in sheet / guest browse unchanged. Adapted from docs/release/motion-spec-onboarding.md.

// MARK: - State machine

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome, roam, stamps, clubs, consent
    var id: Int { rawValue }
    var isFinal: Bool { self == .consent }
    var showsSkip: Bool { !isFinal }
    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }

    var eyebrowKey: LocalizedStringKey {
        switch self {
        case .welcome: "onboarding.welcome.eyebrow"
        case .roam: "onboarding.roam.eyebrow"
        case .stamps: "onboarding.stamps.eyebrow"
        case .clubs: "onboarding.clubs.eyebrow"
        case .consent: "onboarding.consent.eyebrow"
        }
    }
    var titleKey: LocalizedStringKey {
        switch self {
        case .welcome: "onboarding.welcome.title"
        case .roam: "onboarding.roam.title"
        case .stamps: "onboarding.stamps.title"
        case .clubs: "onboarding.clubs.title"
        case .consent: "onboarding.consent.title"
        }
    }
    var bodyKey: LocalizedStringKey {
        switch self {
        case .welcome: "onboarding.welcome.body"
        case .roam: "onboarding.roam.body"
        case .stamps: "onboarding.stamps.body"
        case .clubs: "onboarding.clubs.body"
        case .consent: "onboarding.consent.body"
        }
    }
}

struct OnboardingState: Equatable {
    var step: OnboardingStep = .welcome
    var direction: Direction = .forward
    /// Demos that were completed. Unlocks "done" feedback only; never gates Continue.
    var demoDone: Set<OnboardingStep> = []
    enum Direction { case forward, backward }
}

enum OnboardingAction: Equatable {
    case next, back, skip, swipe(OnboardingState.Direction), demoCompleted(OnboardingStep), tapPrimary, tapGuest
}

/// What the host must do. The flow itself never touches sessions, consent or the network.
enum OnboardingEffect: Equatable { case register, guest }

enum OnboardingReducer {
    @discardableResult
    static func reduce(_ s: inout OnboardingState, _ a: OnboardingAction) -> OnboardingEffect? {
        switch a {
        case .next, .swipe(.forward):
            if let n = s.step.next { s.step = n; s.direction = .forward }
        case .back, .swipe(.backward):
            if let p = s.step.previous { s.step = p; s.direction = .backward }
        case .skip:
            s.step = .consent; s.direction = .forward
        case .demoCompleted(let step):
            s.demoDone.insert(step)
        case .tapPrimary:
            if s.step.isFinal { return .register }
            return reduce(&s, .next)
        case .tapGuest:
            if s.step.isFinal { return .guest }
        }
        return nil
    }
}

// MARK: - Motion tokens

enum OBMotion {
    static let page = Animation.spring(response: 0.48, dampingFraction: 0.86)
    static let copyOut = Animation.easeIn(duration: 0.14)
    static let copyIn = CYMotion.entrance.delay(0.10)
    static let demoSuccess = Animation.spring(response: 0.32, dampingFraction: 0.55)
    static let tilt = Animation.interactiveSpring(response: 0.25, dampingFraction: 0.78)
    static let idle = Animation.easeInOut(duration: 2.6).repeatForever(autoreverses: true)
}

/// Disc fill shared by the pager and the hero, so the frame and the drawn circle match.
enum OBHeroMetrics {
    /// Fraction of the hero frame's short side. Accessibility sizes keep the smaller disc.
    static func discFill(accessibility: Bool) -> CGFloat { accessibility ? 0.82 : 0.92 }
}

// MARK: - Pager

struct OnboardingFlow: View {
    @State private var state: OnboardingState
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    var onRegister: () -> Void
    var onGuest: () -> Void
    /// Host-supplied trailing control in the top bar (the Welcome "more" menu: language, drafts, settings).
    var topAccessory: AnyView?
    /// Fixtures only: plays the hold-GO / stamp / join demos and the account-pill morph by themselves (video capture).
    var autoDemo: Bool
    @State private var registered = false
    @Environment(\.locale) private var locale

    init(initialStep: OnboardingStep = .welcome, topAccessory: AnyView? = nil, autoDemo: Bool = false, onRegister: @escaping () -> Void, onGuest: @escaping () -> Void) {
        _state = State(initialValue: OnboardingState(step: initialStep))
        self.topAccessory = topAccessory
        self.autoDemo = autoDemo
        self.onRegister = onRegister
        self.onGuest = onGuest
    }

    private var step: OnboardingStep { state.step }
    private var heroHidden: Bool { typeSize >= .accessibility3 }

    private func send(_ action: OnboardingAction) {
        var next = state
        let effect = OnboardingReducer.reduce(&next, action)
        if next != state { withAnimation(CYMotion.resolve(OBMotion.page, reduceMotion: reduceMotion)) { state = next } }
        switch effect {
        case .register: onRegister()
        case .guest: onGuest()
        case nil: break
        }
    }

    /// Create account: the pill may morph to a green check only while the transition runs, then rests on the label.
    /// Reduce Motion never morphs. The host still opens the existing sign-in gate.
    private func registerTapped() {
        send(.tapPrimary)
        guard !reduceMotion else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) { registered = true }
        CYHaptics.selection.play()
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            CYHaptics.success.play()
            try? await Task.sleep(for: .milliseconds(700))
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) { registered = false }
        }
    }

    var body: some View {
        ZStack {
            OnboardingBackdrop(stepIndex: step.rawValue)
            GeometryReader { geo in
            // Normal phones: the night map fills the band under the wordmark. A reserved band keeps the
            // hint, title and body on screen; the primary pill is pinned in the bottom inset.
            // AX1+ keeps the smaller disc (50 % of width, 34 % of height, 380 pt), still centred.
            // AX3+ hides the hero entirely (`heroHidden`).
            let ax = typeSize >= .accessibility1
            let screenH = geo.size.height + geo.safeAreaInsets.top + geo.safeAreaInsets.bottom
            let copyBand: CGFloat = 256
            let room = max(0, geo.size.height - CYSpacing.minTouchTarget - copyBand)
            let axDisc = min(geo.size.width * 0.50, screenH * 0.34, 380)
            let heroH = ax ? axDisc / OBHeroMetrics.discFill(accessibility: true) : min(room, geo.size.width, 500)
            let centred = max(0, screenH * 0.35 - geo.safeAreaInsets.top - 44 - heroH / 2)
            let topPad = ax ? centred : 0
            VStack(spacing: 0) {
                topBar
                if !heroHidden {
                    OnboardingHero(step: step, done: state.demoDone)
                        .frame(height: heroH)
                        .padding(.top, topPad)
                        .accessibilityHidden(true)
                }
                ScrollView {
                    VStack(alignment: .center, spacing: CYSpacing.lg) {
                        OnboardingDemo(step: step, stacked: typeSize >= .accessibility1, done: state.demoDone.contains(step), autoplay: autoDemo) {
                            send(.demoCompleted(step))
                        }
                        OnboardingCopy(step: step, direction: state.direction)
                    }
                    .padding(.horizontal, CYSpacing.xxl)
                    .padding(.top, CYSpacing.md)
                    .frame(maxWidth: 620, alignment: .center)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
        .simultaneousGesture(pagingDrag)
        .environment(\.colorScheme, .dark)
        .task(id: step) {
            guard autoDemo, step.isFinal else { return }
            try? await Task.sleep(for: .milliseconds(1800))
            guard !Task.isCancelled else { return }
            registerTapped()
        }
        .cyHaptic(.selection, trigger: step)
        .accessibilityAction(.escape) { send(.skip) }
    }

    private var topBar: some View {
        HStack {
            Text(verbatim: "城瘾")
                .font(.system(.title3, design: .rounded).weight(OBType.isChinese(locale) ? .semibold : .heavy))
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if step.showsSkip {
                Button("onboarding.skip") { send(.skip) }
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textSecondary)
                    .frame(minWidth: CYSpacing.minTouchTarget, minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("onboarding.skip")
                    .transition(.opacity)
            }
            if let topAccessory { topAccessory }
        }
        .padding(.horizontal, CYSpacing.xxl)
        .frame(minHeight: CYSpacing.minTouchTarget)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        VStack(spacing: CYSpacing.sm) {
            OnboardingDots(count: OnboardingStep.allCases.count, index: step.rawValue)
                .padding(.bottom, CYSpacing.sm)
            if step.isFinal { OnboardingConsentNote() }
            Group {
                if step.isFinal {
                    OBMorphPill(titleKey: "onboarding.createAccount", done: registered) { registerTapped() }
                        .accessibilityIdentifier("welcome.player")
                } else {
                    CYPillButton("onboarding.continue", style: .primary) { send(.tapPrimary) }
                        .accessibilityIdentifier("onboarding.primary")
                }
            }
            .animation(CYMotion.resolve(OBMotion.page, reduceMotion: reduceMotion), value: step.isFinal)
            if step.isFinal {
                Button("welcome.browse") { send(.tapGuest) }
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textSecondary)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .accessibilityIdentifier("welcome.browse")
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, CYSpacing.xxl)
        .padding(.top, CYSpacing.md)
        .padding(.bottom, CYSpacing.sm)
        .frame(maxWidth: 620)
        .frame(maxWidth: .infinity)
    }

    /// Horizontal swipe pages; vertical drags stay with the scroll view and the hero's own tilt gesture.
    private var pagingDrag: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local).onEnded { v in
            guard abs(v.translation.width) > abs(v.translation.height) * 1.5 else { return }
            if v.translation.width < -80 || v.predictedEndTranslation.width < -300 { send(.swipe(.forward)) }
            else if v.translation.width > 80 || v.predictedEndTranslation.width > 300 { send(.swipe(.backward)) }
        }
    }
}

// MARK: - Backdrop, dots, copy, consent note

struct OnboardingBackdrop: View {
    let stepIndex: Int
    var body: some View {
        ZStack {
            // Warm indigo ground (never pure black: glows need something to land on).
            LinearGradient(stops: [.init(color: CYNight.indigo, location: 0), .init(color: CYNight.ink0, location: 0.82)],
                           startPoint: .top, endPoint: .bottom)
            GeometryReader { geo in
                // Lantern horizon far below the fold, a little warmer on each step.
                RadialGradient(
                    colors: [CYNight.ember.opacity(0.10 + 0.025 * Double(stepIndex)), .clear],
                    center: UnitPoint(x: 0.5, y: 1.12), startRadius: 0, endRadius: geo.size.width * 0.95)
                // The hero's own faint light pool.
                RadialGradient(
                    colors: [CYNight.lantern.opacity(0.07), .clear],
                    center: UnitPoint(x: 0.5, y: 0.25), startRadius: 0, endRadius: geo.size.width * 0.7)
            }
            .animation(OBMotion.page, value: stepIndex)
            OBGrain()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

struct OnboardingDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? CYColor.textPrimary : CYColor.textSecondary.opacity(0.35))
                    .frame(width: i == index ? 20 : 6, height: 6)
            }
        }
        .animation(OBMotion.page, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("onboarding.progress \(String(index + 1)) \(String(count))"))
        .accessibilityIdentifier("onboarding.dots")
    }
}

struct OnboardingCopy: View {
    let step: OnboardingStep
    let direction: OnboardingState.Direction
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.locale) private var locale
    @ScaledMetric(relativeTo: .title) private var zhTitleSize: CGFloat = 30

    var body: some View {
        let zh = OBType.isChinese(locale)
        VStack(alignment: .center, spacing: CYSpacing.sm) {
            Text(step.eyebrowKey)
                .font(.footnote.weight(zh ? .medium : .semibold))
                .textCase(.uppercase)
                .tracking(zh ? 1 : 0.6)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.titleKey)
                // EN: Rounded Heavy. zh-Hans: PingFang Semibold 30 (never Heavy: the strokes clog).
                .font(zh ? .system(size: zhTitleSize, weight: .semibold) : .system(.largeTitle, design: .rounded).weight(.heavy))
                .lineSpacing(3)
                .multilineTextAlignment(.center)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.title")
            Text(step.bodyKey)
                .cyText(.body)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .id(step)
        .transition(reduceMotion ? .opacity : .asymmetric(
            insertion: .opacity.combined(with: .offset(y: direction == .forward ? 16 : -16)).animation(OBMotion.copyIn),
            removal: .opacity.combined(with: .offset(y: -10)).animation(OBMotion.copyOut)))
    }
}

/// The agreement itself is still the existing gate (launch sheet / sign-in requirement). This row only tells the
/// player that creating an account opens it, so no second, competing checkbox exists.
struct OnboardingConsentNote: View {
    var body: some View {
        Label {
            Text("onboarding.consent.note")
                .cyText(.caption)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        } icon: {
            Image(systemName: "checkmark.shield").foregroundStyle(CYColor.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("onboarding.consent")
    }
}

// MARK: - Hero

struct OnboardingHero: View {
    let step: OnboardingStep
    let done: Set<OnboardingStep>
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var gyro = OBTiltSource()
    @State private var tilt: CGSize = .zero
    @State private var breathing = false
    @State private var wave = 0

    var body: some View {
        GeometryReader { geo in
            let base = min(geo.size.width, geo.size.height)
            let fill = OBHeroMetrics.discFill(accessibility: typeSize >= .accessibility1)
            let size = base * (step.isFinal ? 0.62 : fill)
            ZStack {
                CityDisc(tilt: reduceMotion ? .zero : tilt, softSpecular: !reduceTransparency)
                    .frame(width: size, height: size)
                    .background {
                        // Soft lantern halo behind the disc (a background radial, never over content).
                        Circle().fill(CYNight.glow(radius: size * 0.6))
                            .frame(width: size * 1.9, height: size * 1.9)
                            .opacity(0.35)
                            .allowsHitTesting(false)
                    }
                stepLayer(size: size)
                    .id(step)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.height) * -8), axis: (1, 0, 0), perspective: 0.6)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.width) * 8), axis: (0, 1, 0), perspective: 0.6)
            .offset(y: breathing && !reduceMotion ? -5 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // Hold-GO demo done: a ripple crosses the disc as the fog clears (Metal; no-op under RM / Low Power).
            .obWave(origin: CGPoint(x: geo.size.width / 2, y: geo.size.height / 2), trigger: wave)
            .contentShape(Rectangle())
            .gesture(DragGesture(minimumDistance: 0)
                .onChanged { v in
                    guard !reduceMotion else { return }
                    withAnimation(OBMotion.tilt) {
                        tilt = CGSize(width: max(-1, min(1, v.translation.width / 120)), height: max(-1, min(1, v.translation.height / 120)))
                    }
                }
                .onEnded { _ in withAnimation(CYMotion.release) { tilt = .zero } })
            .onAppear {
                if !reduceMotion { withAnimation(OBMotion.idle) { breathing = true } }
                gyro.start(reduceMotion: reduceMotion)
            }
            .onDisappear { gyro.stop() }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { gyro.start(reduceMotion: reduceMotion) } else { gyro.stop() }
            }
            .onChange(of: done.contains(.roam)) { _, cleared in
                if cleared { wave += 1 }
            }
        }
    }

    @ViewBuilder private func stepLayer(size: CGFloat) -> some View {
        switch step {
        case .welcome: FogWindow(size: size, tilt: tilt, gyro: gyro, wordmark: true)
        case .roam:
            ZStack {
                FogWindow(size: size, tilt: tilt, gyro: gyro, revealed: done.contains(.roam), entrance: false)
                GOFace(size: size, lit: done.contains(.roam))
            }
        case .stamps: StampSeal(size: size, stamped: done.contains(.stamps))
        case .clubs: AvatarOrbit(size: size, count: done.contains(.clubs) ? 6 : 5)
        case .consent: AppMark(size: size)
        }
    }
}

/// Night glass disc: indigo body, a lantern-free cold rim. The specular highlight slides opposite to the tilt.
struct CityDisc: View {
    var tilt: CGSize
    var softSpecular: Bool
    var body: some View {
        let shape = Circle()
        ZStack {
            shape.fill(RadialGradient(
                colors: [CYNight.indigo, CYNight.ink1],
                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 320))
            shape.strokeBorder(AngularGradient(
                colors: [CYNight.glassEdgeTop, CYNight.glassEdgeBottom, .white.opacity(0.10), CYNight.glassEdgeBottom, CYNight.glassEdgeTop],
                center: .center), lineWidth: 2)
            if softSpecular {
                shape.fill(.white.opacity(0.10)).blur(radius: 28).clipShape(shape)
                    .offset(x: -tilt.width * 36 - 40, y: -tilt.height * 36 - 50)
                    .blendMode(.plusLighter)
                    .clipShape(shape)
            }
        }
        .shadow(color: CYNight.ink0.opacity(0.6), radius: 24, y: 14)
    }
}

/// Step 1: the city disc is dark fog with six lit windows; a torn window follows the drag and the 城瘾 wordmark blooms
/// at 1.4 s. Step 2 reuses it: `revealed` clears the fog (fade + grow) with a lantern ring.
struct FogWindow: View {
    let size: CGFloat
    let tilt: CGSize
    @ObservedObject var gyro: OBTiltSource
    var revealed = false
    var entrance = true
    var wordmark = false
    @QuestifyReduceMotion private var reduceMotion
    @State private var ring = false

    var body: some View {
        let inner = size * 0.97
        ZStack {
            OBNightMap(
                lit: revealed,
                dragTilt: reduceMotion ? .zero : tilt,
                roll: reduceMotion ? 0 : gyro.roll,
                pitch: reduceMotion ? 0 : gyro.pitch)
                .frame(width: inner, height: inner)
                .clipShape(Circle())
            Circle()
                .fill(RadialGradient(
                    colors: [.clear, CYNight.indigo.opacity(0.72), CYNight.ink0.opacity(0.92)],
                    center: UnitPoint(x: 0.5 + tilt.width * 0.3, y: 0.5 + tilt.height * 0.3),
                    startRadius: inner * 0.24, endRadius: inner * 0.60))
                .frame(width: inner, height: inner)
                .scaleEffect(revealed ? 1.5 : 1)
                .opacity(revealed ? 0 : 1)
                .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: 0.9), value: revealed)
                .clipShape(Circle())
            OBLanternWindows(size: inner, dragTilt: reduceMotion ? .zero : tilt, tilt: gyro, entrance: entrance, dim: revealed)
            if revealed && !reduceMotion {
                Circle().strokeBorder(CYNight.lantern.opacity(ring ? 0 : 0.7), lineWidth: 2)
                    .frame(width: inner, height: inner)
                    .scaleEffect(ring ? 1.25 : 0.35)
                    .onAppear { withAnimation(.easeOut(duration: 0.8)) { ring = true } }
            }
            if wordmark { OBWordmarkBloom(fontSize: min(52, max(28, size * 0.2)), delay: 1.4, intensity: 1) }
        }
        .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: 0.9), value: revealed)
    }
}

/// Step 2: the GO coin. Lights up (fog clears) once the hold demo is done.
struct GOFace: View {
    let size: CGFloat
    let lit: Bool
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AngularGradient(
                    colors: lit
                        ? [CYNight.lanternHot, CYNight.lantern, CYNight.lanternHot, CYNight.ember, CYNight.lanternHot]
                        : [CYNight.glassEdgeTop, CYNight.glassEdgeBottom, CYNight.glassEdgeTop, CYNight.glassEdgeBottom, CYNight.glassEdgeTop],
                    center: .center), lineWidth: 6)
                .frame(width: size * 0.78, height: size * 0.78)
                .shadow(color: CYNight.lantern.opacity(lit ? 0.45 : 0), radius: 16)
            Text(verbatim: "GO")
                .cyText(.dataXL)
                .foregroundStyle(lit ? CYNight.lanternHot : Color.white.opacity(0.72))
                .shadow(color: CYNight.lantern.opacity(lit ? 0.7 : 0), radius: 14)
        }
        .animation(OBMotion.demoSuccess, value: lit)
    }
}

/// Step 3: stamp demo, the section 5A choreography at 70 % scale (lift 28 pt instead of 40, 25 particles instead of 36).
/// 0 anticipation (1.15, rises) -> 120 heavy impact, squash 0.92 -> 120-420 ink ring + wave -> 250 success ->
/// 300-700 lantern burst -> 350 title rises 10 pt -> 600 passport count rolls. Reduce Motion: crossfade to the final
/// state with a single success haptic.
struct StampSeal: View {
    let size: CGFloat
    let stamped: Bool
    @QuestifyReduceMotion private var reduceMotion
    @State private var scale: CGFloat = 1
    @State private var lift: CGFloat = -14
    @State private var ring: CGFloat = 0
    @State private var inked = false
    @State private var titleIn = false
    @State private var count = 0
    @State private var burst = 0
    @State private var wave = 0
    @State private var sequence: Task<Void, Never>?

    var body: some View {
        let seal = size * 0.72
        ZStack {
            OBSealShape()
                .fill(inked ? AnyShapeStyle(LinearGradient(colors: [CYNight.lanternHot, CYNight.lantern], startPoint: .top, endPoint: .bottom)) : AnyShapeStyle(CYNight.glassFill))
                .frame(width: seal, height: seal)
                .shadow(color: CYNight.lantern.opacity(inked ? 0.45 : 0), radius: 18)
            Circle().strokeBorder(CYNight.ink0.opacity(0.7), lineWidth: 3).frame(width: size * 0.52, height: size * 0.52)
            Image(systemName: "checkmark").accessibilityHidden(true).font(.system(.title, design: .rounded).weight(.heavy)).foregroundStyle(CYNight.ink0)
            Circle().strokeBorder(CYNight.lantern.opacity(0.7 * Double(1 - ring)), lineWidth: 2)
                .frame(width: seal, height: seal)
                .scaleEffect(1 + 1.4 * ring)
                .opacity(ring > 0 ? 1 : 0)
        }
        .scaleEffect(scale)
        .offset(y: lift)
        .frame(width: size, height: size)
        .obWave(origin: CGPoint(x: size / 2, y: size / 2), trigger: wave, amp: 7)
        .overlay {
            if burst > 0 { OBBurst(origin: .center, count: 25, duration: 1.0, radius: size * 0.5).id(burst) }
        }
        .overlay(alignment: .bottom) {
            Text("onboarding.stamps.slam")
                .cyText(.bodyMedium)
                .foregroundStyle(CYNight.lanternHot)
                .lineLimit(1).minimumScaleFactor(0.7)
                .offset(y: titleIn ? -size * 0.07 : -size * 0.07 + 10)
                .opacity(titleIn ? 1 : 0)
        }
        .overlay(alignment: .topTrailing) {
            HStack(spacing: 4) {
                Image(systemName: "book.closed").accessibilityHidden(true).font(.caption2.weight(.semibold))
                Text(verbatim: "\(count)").font(.system(.caption, design: .rounded).weight(.bold).monospacedDigit()).contentTransition(.numericText())
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background(Capsule().fill(CYNight.glassFill)).overlay(Capsule().strokeBorder(CYNight.glassEdgeTop, lineWidth: 1))
            .opacity(count > 0 ? 1 : 0)
            .padding(size * 0.04)
        }
        .onAppear { if stamped { settle(animated: false) } }
        .onChange(of: stamped) { _, new in if new { play() } }
        .onDisappear { sequence?.cancel() }
    }

    private func settle(animated: Bool) {
        withAnimation(animated ? CYMotion.reduced : nil) {
            scale = 1; lift = 0; inked = true; titleIn = true; count = 1; ring = 0
        }
    }

    private func play() {
        sequence?.cancel()
        guard !reduceMotion else { settle(animated: true); CYHaptics.success.play(); return }
        sequence = Task { @MainActor in
            func wait(_ ms: Int) async -> Bool { try? await Task.sleep(for: .milliseconds(ms)); return !Task.isCancelled }
            withAnimation(CYMotion.press) { scale = 1.15; lift = -28 }                          // 0 anticipation
            guard await wait(120) else { return }
            CYHaptics.impactHeavy.play()                                                         // 120 impact
            withAnimation(.spring(response: 0.16, dampingFraction: 0.55)) { scale = 0.92; lift = 6; inked = true }
            withAnimation(.easeOut(duration: 0.3)) { ring = 1 }                                  // 120-420 ink ring
            wave += 1
            guard await wait(130) else { return }
            CYHaptics.success.play()                                                             // 250 success
            withAnimation(CYMotion.release) { scale = 1; lift = 0 }
            guard await wait(50) else { return }
            burst += 1                                                                           // 300 burst
            guard await wait(50) else { return }
            withAnimation(CYMotion.entrance) { titleIn = true }                                  // 350 title
            guard await wait(250) else { return }
            withAnimation(CYMotion.standard) { count = 1 }                                       // 600 count rolls
        }
    }
}

/// Step 4: avatar discs orbiting the hero; joining adds a sixth.
struct AvatarOrbit: View {
    let size: CGFloat
    let count: Int
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion || scenePhase != .active)) { timeline in
            let t = reduceMotion ? 0 : timeline.date.timeIntervalSinceReferenceDate
            let radius = size * 0.38
            ZStack {
                Circle().strokeBorder(CYNight.glassEdgeTop, lineWidth: 1).frame(width: radius * 2, height: radius * 2)
                ForEach(0..<count, id: \.self) { i in
                    let angle = t * 0.25 + Double(i) / Double(count) * 2 * .pi
                    let joined = i == count - 1 && count > 5
                    CYCoverArt(seed: "orbit-\(i)", showsDebugLabel: false, showsGlyph: false)
                        .frame(width: size * 0.2, height: size * 0.2)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(joined ? CYNight.lantern : CYNight.glassEdgeTop, lineWidth: joined ? 2 : 1.5))
                        .shadow(color: joined ? CYNight.lantern.opacity(0.55) : .clear, radius: 8)
                        .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
                }
                Text(verbatim: "\(count)")
                    .cyText(.dataXL)
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .frame(width: size, height: size)
        }
        .animation(reduceMotion ? CYMotion.reduced : OBMotion.demoSuccess, value: count)
    }
}

/// Final step: the disc shrinks to the app mark.
struct AppMark: View {
    let size: CGFloat
    var body: some View {
        OBWordmarkBloom(fontSize: max(24, size * 0.26), delay: 0.2, intensity: 0.4)
            .frame(width: size * 0.8)
    }
}

// MARK: - Demos

/// One 10-second taste of the real mechanic. Demos never gate Continue and always have a plain-tap path.
struct OnboardingDemo: View {
    let step: OnboardingStep
    let stacked: Bool
    let done: Bool
    var autoplay = false
    let onComplete: () -> Void

    var body: some View {
        Group {
            switch step {
            case .welcome:
                OBDragHint(titleKey: "onboarding.welcome.hint")
            case .roam: GOHoldDemo(stacked: stacked, done: done, autoplay: autoplay, onComplete: onComplete)
            case .stamps:
                DemoRow(stacked: stacked, done: done, buttonKey: "onboarding.stamps.action", doneKey: "onboarding.stamps.done",
                        promptKey: "onboarding.stamps.prompt", symbol: "seal", haptic: .impactLight, autoplay: autoplay, onComplete: onComplete)
            case .clubs:
                DemoRow(stacked: stacked, done: done, buttonKey: "onboarding.clubs.action", doneKey: "onboarding.clubs.done",
                        promptKey: "onboarding.clubs.prompt", symbol: "person.badge.plus", haptic: .impactMedium, autoplay: autoplay, onComplete: onComplete)
            case .consent:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .frame(minHeight: step == .welcome || step == .consent ? 0 : 56)
    }
}

/// A tap demo: pill-sized control plus a status line that swaps to "done".
private struct DemoRow: View {
    let stacked: Bool
    let done: Bool
    let buttonKey: LocalizedStringKey
    let doneKey: LocalizedStringKey
    let promptKey: LocalizedStringKey
    let symbol: String
    let haptic: CYHaptics
    var autoplay = false
    let onComplete: () -> Void
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md)) : AnyLayout(HStackLayout(spacing: CYSpacing.lg))
        layout {
            Button(action: onComplete) {
                Label(buttonKey, systemImage: done ? "checkmark" : symbol)
                    .cyText(.bodyMedium)
                    .foregroundStyle(CYColor.textPrimary)
                    .padding(.horizontal, CYSpacing.lg)
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .background(Capsule().strokeBorder(CYColor.borderStrong, lineWidth: 1.5))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(done)
            .accessibilityIdentifier("onboarding.demo")
            Text(done ? doneKey : promptKey)
                .cyText(.bodyCompact).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .animation(reduceMotion ? CYMotion.reduced : OBMotion.demoSuccess, value: done)
        .cyHaptic(haptic, trigger: done) { old, new in !old && new }
        .task {
            guard autoplay, !done else { return }
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            onComplete()
        }
    }
}

/// Press and hold GO for 0.9 s: three rings, progress ring, haptic ticks. VoiceOver gets a one-step action.
private struct GOHoldDemo: View {
    let stacked: Bool
    let done: Bool
    var autoplay = false
    let onComplete: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var ticks: Task<Void, Never>?

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md)) : AnyLayout(HStackLayout(spacing: CYSpacing.lg))
        layout {
            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle().stroke(CYColor.textPrimary.opacity(0.35), lineWidth: 1.5)
                        .frame(width: 56, height: 56)
                        .scaleEffect(done ? 1.5 : 1).opacity(done ? 0 : 0.0)
                        .animation(reduceMotion ? CYMotion.reduced : .easeOut(duration: 0.9).delay(Double(i) * 0.15), value: done)
                }
                Circle().fill(CYColor.textPrimary).frame(width: 52, height: 52)
                    .overlay(Text(verbatim: "GO").cyText(.cardTitle, weight: .heavy).foregroundStyle(CYColor.textInverse))
                Circle().trim(from: 0, to: done ? 1 : progress)
                    .stroke(CYNight.lantern, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 62, height: 62)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 0.9, perform: {
                progress = 0; onComplete()
            }, onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: 0.9) : CYMotion.release) { progress = pressing && !reduceMotion ? 1 : 0 }
                ticks?.cancel()
                if pressing { ticks = tickHaptics() }
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("onboarding.roam.demo.label"))
            .accessibilityHint(Text("onboarding.roam.demo.hint"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onComplete() }
            .accessibilityIdentifier("onboarding.demo")
            Text(done ? "onboarding.roam.done" : "onboarding.roam.prompt")
                .cyText(.bodyCompact).foregroundStyle(.white.opacity(0.85))
                .lineLimit(2)
                .minimumScaleFactor(0.85)
                .multilineTextAlignment(stacked ? .leading : .center)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
                .id(done)
                .transition(.opacity)
        }
        // The hint lives in a glass capsule centred under the disc. The label swap is a plain fade (no spring on the
        // layout), so the capsule never resizes mid-animation and clips the text.
        .padding(.leading, CYSpacing.md)
        .padding(.trailing, CYSpacing.xl)
        .padding(.vertical, CYSpacing.xs)
        .obGlassCapsule()
        .animation(.easeInOut(duration: 0.2), value: done)
        .cyHaptic(.impactHeavy, trigger: done) { old, new in !old && new }
        .task {
            // Fixture capture: hold 900 ms (ticks at 200 / 400 ms), then commit.
            guard autoplay, !done else { return }
            try? await Task.sleep(for: .milliseconds(1000))
            guard !Task.isCancelled else { return }
            if !reduceMotion { withAnimation(.linear(duration: 0.9)) { progress = 1 } }
            ticks = tickHaptics()
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            progress = 0
            onComplete()
        }
    }

    /// GO hold ticks (spec 3.6): impactLight at 200 and 400 ms; the commit haptic fires on completion.
    private func tickHaptics() -> Task<Void, Never> {
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            CYHaptics.impactLight.play()
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            CYHaptics.impactLight.play()
        }
    }
}
