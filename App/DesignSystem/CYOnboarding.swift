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

// MARK: - Pager

struct OnboardingFlow: View {
    @State private var state: OnboardingState
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.dynamicTypeSize) private var typeSize
    var onRegister: () -> Void
    var onGuest: () -> Void
    /// Host-supplied trailing control in the top bar (the Welcome "more" menu: language, drafts, settings).
    var topAccessory: AnyView?

    init(initialStep: OnboardingStep = .welcome, topAccessory: AnyView? = nil, onRegister: @escaping () -> Void, onGuest: @escaping () -> Void) {
        _state = State(initialValue: OnboardingState(step: initialStep))
        self.topAccessory = topAccessory
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

    var body: some View {
        ZStack {
            OnboardingBackdrop(stepIndex: step.rawValue)
            VStack(spacing: 0) {
                topBar
                if !heroHidden {
                    OnboardingHero(step: step, done: state.demoDone)
                        .frame(height: typeSize >= .accessibility1 ? 160 : 260)
                        .accessibilityHidden(true)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: CYSpacing.lg) {
                        OnboardingDemo(step: step, stacked: typeSize >= .accessibility1, done: state.demoDone.contains(step)) {
                            send(.demoCompleted(step))
                        }
                        OnboardingCopy(step: step, direction: state.direction)
                    }
                    .padding(.horizontal, CYSpacing.xxl)
                    .padding(.top, CYSpacing.md)
                    .frame(maxWidth: 620, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.basedOnSize)
            }
        }
        .safeAreaInset(edge: .bottom) { footer }
        .simultaneousGesture(pagingDrag)
        .cyHaptic(.selection, trigger: step)
        .accessibilityAction(.escape) { send(.skip) }
    }

    private var topBar: some View {
        HStack {
            Text(verbatim: "城瘾")
                .font(.system(.title3, design: .rounded).weight(.heavy))
                .foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if step.showsSkip {
                Button("onboarding.skip") { send(.skip) }
                    .font(.subheadline.weight(.semibold))
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
            CYPillButton(step.isFinal ? "onboarding.createAccount" : "onboarding.continue", style: .primary) { send(.tapPrimary) }
                .animation(CYMotion.resolve(OBMotion.page, reduceMotion: reduceMotion), value: step.isFinal)
                .accessibilityIdentifier(step.isFinal ? "welcome.player" : "onboarding.primary")
            if step.isFinal {
                Button("welcome.browse") { send(.tapGuest) }
                    .font(CYTypography.bodyCompact.weight(.semibold))
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
            CYColor.bgPage
            GeometryReader { geo in
                RadialGradient(
                    colors: [CYColor.accent.opacity(0.10 + 0.04 * Double(stepIndex)), .clear],
                    center: UnitPoint(x: 0.5, y: 1.1), startRadius: 0, endRadius: geo.size.width * 0.9)
            }
            .animation(OBMotion.page, value: stepIndex)
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

    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.sm) {
            Text(step.eyebrowKey)
                .font(.caption.weight(.semibold))
                .textCase(.uppercase)
                .tracking(1.5)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(step.titleKey)
                .font(CYTypography.display)
                .foregroundStyle(CYColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("onboarding.title")
            Text(step.bodyKey)
                .font(CYTypography.body)
                .foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
                .font(CYTypography.caption)
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
    @State private var tilt: CGSize = .zero
    @State private var breathing = false

    var body: some View {
        GeometryReader { geo in
            let base = min(geo.size.width, geo.size.height)
            let size = base * (step.isFinal ? 0.46 : 0.82)
            ZStack {
                CityDisc(tilt: reduceMotion ? .zero : tilt, softSpecular: !reduceTransparency)
                    .frame(width: size, height: size)
                stepLayer(size: size)
                    .id(step)
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .scale(scale: 0.92)))
            }
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.height) * -8), axis: (1, 0, 0), perspective: 0.6)
            .rotation3DEffect(.degrees(reduceMotion ? 0 : Double(tilt.width) * 8), axis: (0, 1, 0), perspective: 0.6)
            .offset(y: breathing && !reduceMotion ? -5 : 0)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                guard !reduceMotion else { return }
                withAnimation(OBMotion.idle) { breathing = true }
            }
        }
    }

    @ViewBuilder private func stepLayer(size: CGFloat) -> some View {
        switch step {
        case .welcome: FogWindow(size: size, tilt: tilt)
        case .roam: GOFace(size: size, lit: done.contains(.roam))
        case .stamps: StampSeal(size: size, stamped: done.contains(.stamps))
        case .clubs: AvatarOrbit(size: size, count: done.contains(.clubs) ? 6 : 5)
        case .consent: AppMark(size: size)
        }
    }
}

/// Layered metal disc. The specular highlight slides opposite to the tilt (fake lighting).
struct CityDisc: View {
    var tilt: CGSize
    var softSpecular: Bool
    var body: some View {
        let shape = Circle()
        ZStack {
            shape.fill(RadialGradient(
                colors: [CYRGB(hex: 0x2A2A30).swiftUIColor, CYRGB(hex: 0x0E0E11).swiftUIColor],
                center: UnitPoint(x: 0.35, y: 0.3), startRadius: 0, endRadius: 320))
            shape.strokeBorder(AngularGradient(
                colors: [.white.opacity(0.55), .white.opacity(0.05), .white.opacity(0.35), .white.opacity(0.05), .white.opacity(0.55)],
                center: .center), lineWidth: 3)
            if softSpecular {
                shape.fill(.white.opacity(0.18)).blur(radius: 28).clipShape(shape)
                    .offset(x: -tilt.width * 36 - 40, y: -tilt.height * 36 - 50)
                    .blendMode(.plusLighter)
                    .clipShape(shape)
            }
        }
        .shadow(color: .black.opacity(0.6), radius: 24, y: 14)
    }
}

/// Step 1: a cover-art map seen through a torn window in the fog; the window follows the drag.
struct FogWindow: View {
    let size: CGFloat
    let tilt: CGSize
    var body: some View {
        let inner = size * 0.86
        ZStack {
            CYCoverArt(seed: "welcome-fog-map", symbol: "map", showsDebugLabel: false, showsGlyph: false)
                .frame(width: inner, height: inner)
                .clipShape(Circle())
            Circle()
                .fill(RadialGradient(
                    colors: [.clear, CYRGB(hex: 0x0A0A0B).swiftUIColor.opacity(0.92)],
                    center: UnitPoint(x: 0.5 + tilt.width * 0.3, y: 0.5 + tilt.height * 0.3),
                    startRadius: inner * 0.12, endRadius: inner * 0.5))
                .frame(width: inner, height: inner)
        }
    }
}

/// Step 2: the GO coin. Lights up (fog clears) once the hold demo is done.
struct GOFace: View {
    let size: CGFloat
    let lit: Bool
    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(AngularGradient(colors: [.white, .white.opacity(0.25), .white, .white.opacity(0.25), .white], center: .center), lineWidth: 6)
                .frame(width: size * 0.78, height: size * 0.78)
            Text(verbatim: "GO")
                .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                .foregroundStyle(.white.opacity(lit ? 1 : 0.6))
                .shadow(color: .white.opacity(lit ? 0.5 : 0), radius: 14)
        }
        .animation(OBMotion.demoSuccess, value: lit)
    }
}

/// Step 3: serrated seal (36 teeth) plus ink ring; drops and squashes when stamped.
struct StampSeal: View {
    let size: CGFloat
    let stamped: Bool
    @QuestifyReduceMotion private var reduceMotion
    var body: some View {
        ZStack {
            Canvas { ctx, canvas in
                let c = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
                let outer = min(canvas.width, canvas.height) / 2, inner = outer * 0.92
                var path = Path()
                let teeth = 36
                for i in 0..<(teeth * 2) {
                    let angle = Double(i) / Double(teeth * 2) * 2 * .pi
                    let r = i.isMultiple(of: 2) ? outer : inner
                    let p = CGPoint(x: c.x + CGFloat(cos(angle)) * r, y: c.y + CGFloat(sin(angle)) * r)
                    if i == 0 { path.move(to: p) } else { path.addLine(to: p) }
                }
                path.closeSubpath()
                ctx.fill(path, with: .color(.white.opacity(0.92)))
            }
            .frame(width: size * 0.72, height: size * 0.72)
            Circle().strokeBorder(CYRGB(hex: 0x0E0E11).swiftUIColor.opacity(0.7), lineWidth: 3).frame(width: size * 0.52, height: size * 0.52)
            Image(systemName: "checkmark").font(.system(.title, design: .rounded).weight(.heavy)).foregroundStyle(CYRGB(hex: 0x0E0E11).swiftUIColor)
            if stamped && !reduceMotion {
                Circle().strokeBorder(.white.opacity(0.5), lineWidth: 2).frame(width: size * 0.9, height: size * 0.9)
                    .transition(.scale(scale: 0.6).combined(with: .opacity))
            }
        }
        .offset(y: stamped ? 14 : -14)
        .scaleEffect(x: 1, y: stamped ? 1 : 0.94)
        .animation(reduceMotion ? CYMotion.reduced : OBMotion.demoSuccess, value: stamped)
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
                Circle().strokeBorder(.white.opacity(0.16), lineWidth: 1).frame(width: radius * 2, height: radius * 2)
                ForEach(0..<count, id: \.self) { i in
                    let angle = t * 0.25 + Double(i) / Double(count) * 2 * .pi
                    CYCoverArt(seed: "orbit-\(i)", showsDebugLabel: false, showsGlyph: false)
                        .frame(width: size * 0.2, height: size * 0.2)
                        .clipShape(Circle())
                        .overlay(Circle().strokeBorder(.white.opacity(0.5), lineWidth: 1.5))
                        .offset(x: CGFloat(cos(angle)) * radius, y: CGFloat(sin(angle)) * radius)
                }
                Text(verbatim: "\(count)")
                    .font(.system(.title, design: .rounded).weight(.heavy))
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
        Text(verbatim: "城瘾")
            .font(.system(.title2, design: .rounded).weight(.heavy))
            .foregroundStyle(.white)
            .minimumScaleFactor(0.5)
            .lineLimit(1)
            .frame(width: size * 0.8)
    }
}

// MARK: - Demos

/// One 10-second taste of the real mechanic. Demos never gate Continue and always have a plain-tap path.
struct OnboardingDemo: View {
    let step: OnboardingStep
    let stacked: Bool
    let done: Bool
    let onComplete: () -> Void

    var body: some View {
        Group {
            switch step {
            case .welcome:
                Label("onboarding.welcome.hint", systemImage: "hand.draw")
                    .font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                    .accessibilityHidden(true)
            case .roam: GOHoldDemo(stacked: stacked, done: done, onComplete: onComplete)
            case .stamps:
                DemoRow(stacked: stacked, done: done, buttonKey: "onboarding.stamps.action", doneKey: "onboarding.stamps.done",
                        promptKey: "onboarding.stamps.prompt", symbol: "seal", haptic: .impactHeavy, onComplete: onComplete)
            case .clubs:
                DemoRow(stacked: stacked, done: done, buttonKey: "onboarding.clubs.action", doneKey: "onboarding.clubs.done",
                        promptKey: "onboarding.clubs.prompt", symbol: "person.badge.plus", haptic: .impactMedium, onComplete: onComplete)
            case .consent:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
    let onComplete: () -> Void
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        let layout = stacked ? AnyLayout(VStackLayout(alignment: .leading, spacing: CYSpacing.md)) : AnyLayout(HStackLayout(spacing: CYSpacing.lg))
        layout {
            Button(action: onComplete) {
                Label(buttonKey, systemImage: done ? "checkmark" : symbol)
                    .font(CYTypography.bodyCompact.weight(.semibold))
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
                .font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .animation(reduceMotion ? CYMotion.reduced : OBMotion.demoSuccess, value: done)
        .cyHaptic(haptic, trigger: done) { old, new in !old && new }
    }
}

/// Press and hold GO for 0.9 s: three rings, progress ring, haptic ticks. VoiceOver gets a one-step action.
private struct GOHoldDemo: View {
    let stacked: Bool
    let done: Bool
    let onComplete: () -> Void
    @QuestifyReduceMotion private var reduceMotion
    @State private var progress: CGFloat = 0

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
                    .overlay(Text(verbatim: "GO").font(.headline.weight(.heavy)).foregroundStyle(CYColor.textInverse))
                Circle().trim(from: 0, to: done ? 1 : progress)
                    .stroke(CYColor.textSecondary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90)).frame(width: 62, height: 62)
            }
            .frame(width: 72, height: 72)
            .contentShape(Circle())
            .onLongPressGesture(minimumDuration: 0.9, perform: {
                progress = 0; onComplete()
            }, onPressingChanged: { pressing in
                withAnimation(pressing ? .linear(duration: 0.9) : CYMotion.release) { progress = pressing && !reduceMotion ? 1 : 0 }
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("onboarding.roam.demo.label"))
            .accessibilityHint(Text("onboarding.roam.demo.hint"))
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onComplete() }
            .accessibilityIdentifier("onboarding.demo")
            Text(done ? "onboarding.roam.done" : "onboarding.roam.prompt")
                .font(CYTypography.bodyCompact).foregroundStyle(CYColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .animation(reduceMotion ? CYMotion.reduced : OBMotion.demoSuccess, value: done)
        .cyHaptic(.impactHeavy, trigger: done) { old, new in !old && new }
    }
}
