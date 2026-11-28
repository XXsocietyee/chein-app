import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// Motion + haptics kit (E1). Spec: docs/release/motion-spec.md.
// Every moving piece is gated on Reduce Motion (system, in-app setting, or the DEBUG `--uitesting-reduce-motion`
// launch argument); the fallback is an instant change or a short cross-fade, never a slide or scale.

// MARK: - Haptics

/// The one haptics map. Pages never pick a generator themselves.
/// | case | use |
/// | `.selection` | tab change, chip / segment pick, pager page |
/// | `.success` | join, save, order paid, badge unlock, stamp |
/// | `.warning` | blocked action, validation stop |
/// | `.error` | wrong answer, rejected validation, lost CITY challenge (City Monopoly spec §5; validation stops stay `.warning`) |
/// | `.impactLight` | pull-to-refresh trigger, sheet detent snap |
/// | `.impactMedium` | primary commit (register, check-in) |
/// | `.impactHeavy` | GO press |
/// | `.impactRigid` | CITY defense held (City Monopoly spec §5) |
enum CYHaptics: Equatable {
    case selection, success, warning, error, impactLight, impactMedium, impactHeavy, impactRigid

    var event: HapticEvent {
        switch self {
        case .selection: return .selection
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .impactLight: return .impactLight
        case .impactMedium: return .impactMedium
        case .impactHeavy: return .impactHeavy
        case .impactRigid: return .impactRigid
        }
    }

    var sensory: SensoryFeedback {
        switch self {
        case .selection: return .selection
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .impactLight: return .impact(weight: .light)
        case .impactMedium: return .impact(weight: .medium)
        case .impactHeavy: return .impact(weight: .heavy)
        case .impactRigid: return .impact(flexibility: .rigid)
        }
    }

    /// Imperative form routed through `HapticsService` with 120 ms cooldown and in-app/system gating.
    @MainActor func play() {
        UIKitHapticsDriver.ensureInstalled()
        HapticsService.shared.play(event)
    }
}

extension View {
    /// Declarative haptic routed through `HapticsService`: plays `haptic` whenever `trigger` changes.
    func cyHaptic<T: Equatable>(_ haptic: CYHaptics, trigger: T) -> some View {
        cyHapticEvent(haptic.event, trigger: trigger)
    }
    /// Plays `haptic` through `HapticsService` only for transitions accepted by `condition(old, new)`.
    func cyHaptic<T: Equatable>(_ haptic: CYHaptics, trigger: T, where condition: @escaping (T, T) -> Bool) -> some View {
        cyHapticEvent(haptic.event, trigger: trigger, where: condition)
    }
}

/// Typed Bool transitions for `cyHaptic(_:trigger:where:)` and `sensoryFeedback(_:trigger:condition:)` (coordinator
/// 04:20 compile rule: no untyped `{ old, new in }` closures in view bodies).
enum CYHapticTransition {
    /// false → true.
    static func turnedOn(_ old: Bool, _ new: Bool) -> Bool { !old && new }
    /// Any change that ends true.
    static func isOn(_ old: Bool, _ new: Bool) -> Bool { new }
    /// Any change that ends false.
    static func turnedOff(_ old: Bool, _ new: Bool) -> Bool { !new }
    /// Any change that ends with a value.
    static func isSet<Value>(_ old: Value?, _ new: Value?) -> Bool { new != nil }
    /// nil → a value.
    static func becameSet<Value>(_ old: Value?, _ new: Value?) -> Bool { old == nil && new != nil }
    /// The count went up.
    static func increased(_ old: Int, _ new: Int) -> Bool { new > old }
    /// Any change that ends non-empty (a new face, a new roll).
    static func nonEmpty<Value: Collection>(_ old: Value, _ new: Value) -> Bool { !new.isEmpty }
    /// A change from one value to another (not the first set, not a clear).
    static func bothSet<Value>(_ old: Value?, _ new: Value?) -> Bool { old != nil && new != nil }
}

// MARK: - Tokens

/// THE motion token set (xrefs-1 B.0, Figma Library › Motion `402:647` "Motion tokens · one set"). Eight springs, the
/// durations, delays and staggers, all in one place. `CityTokens` only aliases these; no screen defines its own spring.
///
/// | token | response / damping | use |
/// | `press` | 0.12 / 0.90 | touch-down, scale 1 → 0.97 |
/// | `release` | 0.25 / 0.70 | touch-up, chip and pin select (pin 1 → 1.15) |
/// | `standard` | 0.30 / 0.85 | change in place: insert, delete, button fill, wizard step, capsule width |
/// | `entrance` | 0.35 / 0.80 | one entrance per container: empty state, seat arrival, toast enter |
/// | `sheet` | 0.38 / 0.86 | sheets and toasts |
/// | `moment` | 0.42 / 0.80 | result beats inside a moment: deed band, headline, chips |
/// | `seal` | 0.40 / 0.55 | the one playful spring: seal, medal, die landing |
/// | `hero` | 0.45 / 0.86 | continuity: claim photo → deed, Mini → sheet, die across stages |
/// | `reduced` | easeInOut 0.20 s | the Reduce Motion fallback of every row (haptics stay) |
enum CYMotion {
    enum Duration {
        static let instant: Double = 0.12    // press-down, chip tick, toggle
        static let quick: Double = 0.20      // fades, reveals, cross-fades, skeleton to content, tab swap
        static let standard: Double = 0.35   // list insert/delete, hero entrance, ring fill
        static let slow: Double = 0.60       // celebration land, flip, count-up
        /// Alias kept for existing callers; it is `standard` on the four-step grid.
        static let emphasized: Double = standard
        /// `.contentTransition(.numericText(value:))` roll of 积分, totals and stats (only on a real change).
        static let numericRoll: Double = 0.30
        /// Exits and hides are always shorter than the entrance (reveal 250 → hide 200).
        static let hide: Double = 0.20
        /// The hold ring: `linear(duration: 0.8)`; letting go early snaps back on `release`.
        static let hold: Double = 0.80
        /// `CYWave` single pass on 圈下了 / 拿下 (rare tier only).
        static let successWave: Double = 0.45
        /// Rent arriving: 0 → total in three steps.
        static let countUp: Double = 0.80
    }
    /// Delays measured from the cause (seconds).
    enum Delay {
        /// The deed band starts 250 ms after the photo starts moving (not after it lands).
        static let heroBand: Double = 0.25
        /// The success wave starts at the seal's contact.
        static let successWave: Double = 0.78
        /// An in-place Done holds 600 ms, then its sheet dismisses.
        static let sheetDismiss: Double = 0.60
        /// Moment beats.
        static let momentDeed: Double = 0.35
        static let momentSeal: Double = 0.60
        static let momentText: Double = 0.95
        static let momentActions: Double = 1.25
        /// A toast's trailing action (查看) enters 300 ms after its state change.
        static let toastAction: Double = 0.30
        /// The dice total rolls 400 ms after the die lands.
        static let totalRoll: Double = 0.40
    }
    /// Non-uniform staggers (seconds). Never `index × constant` for a short group.
    enum Stagger {
        /// Moment chips: 0 / 50 / 90 ms.
        static let chips: [Double] = [0, 0.05, 0.09]
        /// Per digit, from the cause side; the whole number lands inside 300 ms.
        static let digit: Double = 0.045
        /// AI rewrite fields from the top: 0 / 40 / 70 / 90 ms.
        static let rewrite: [Double] = [0, 0.04, 0.07, 0.09]
        /// The delay of item `index` in a capped list (the last value repeats).
        static func delay(_ index: Int, in list: [Double] = chips) -> Double {
            guard let last = list.last else { return 0 }
            return index < list.count ? list[max(0, index)] : last
        }
    }
    enum Scale {
        /// Press dip. Never below 0.95.
        static let press: CGFloat = 0.97
        /// A selected map pin.
        static let pinSelected: CGFloat = 1.15
    }
    /// Touch-down. 120 ms.
    static let press = Animation.spring(response: 0.12, dampingFraction: 0.9)
    /// Touch-up. Slight overshoot, lands in about 0.25 s. Also chip and pin select.
    static let release = Animation.spring(response: 0.25, dampingFraction: 0.7)
    /// Default content motion: change in place (insert, delete, reorder, button fill, wizard step, capsule width).
    static let standard = Animation.spring(response: 0.3, dampingFraction: 0.85)
    /// Entrances (one per container: empty state, seat arrival, toast enter).
    static let entrance = Animation.spring(response: 0.35, dampingFraction: 0.8)
    /// Sheets and toasts (was `CityTokens.sheetSpring`).
    static let sheet = Animation.spring(response: 0.38, dampingFraction: 0.86)
    /// Result beats inside a moment: deed band, headline, chips (was `CityTokens.deedSpring`).
    static let moment = Animation.spring(response: 0.42, dampingFraction: 0.80)
    /// The one playful spring: seal, medal, die landing (was `CityTokens.sealSpring`).
    static let seal = Animation.spring(response: 0.40, dampingFraction: 0.55)
    /// Continuity: claim photo → deed, Mini → sheet, die across stages (was `CityTokens.heroSpring`).
    static let hero = Animation.spring(response: 0.45, dampingFraction: 0.86)
    /// A number rolling to a new value (`numericText`), 300 ms.
    static let numericRoll = Animation.snappy(duration: Duration.numericRoll)
    /// Exits and hides (200 ms, shorter than the entrance).
    static let hide = Animation.easeOut(duration: Duration.hide)
    /// Reduce Motion replacement: a short cross-fade.
    static let reduced = Animation.easeInOut(duration: Duration.quick)

    /// `animation` normally, the cross-fade when Reduce Motion is on.
    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation { reduceMotion ? reduced : animation }
}

extension View {
    /// A number that rolls in fixed-width digits when `value` really changes (xrefs-1 Adopt 3): `.monospacedDigit()`,
    /// `.contentTransition(.numericText(value:))` and `CYMotion.numericRoll`. Reduce Motion: the digits cross-fade.
    /// Never use it on a live counter (HUD timer, distance): those are plain tabular digits.
    func cyNumericRoll(_ value: Double) -> some View { modifier(CYNumericRoll(value: value)) }

    /// `.animation(_, value:)` that degrades to a cross-fade under Reduce Motion.
    func cyAnimation<V: Equatable>(_ animation: Animation = CYMotion.standard, value: V) -> some View {
        modifier(CYAnimationModifier(animation: animation, value: value))
    }
}

private struct CYNumericRoll: ViewModifier {
    let value: Double
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        content
            .monospacedDigit()
            .contentTransition(reduceMotion ? .opacity : .numericText(value: value))
            .animation(CYMotion.resolve(CYMotion.numericRoll, reduceMotion: reduceMotion), value: value)
    }
}

private struct CYAnimationModifier<V: Equatable>: ViewModifier {
    let animation: Animation
    let value: V
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        content.animation(CYMotion.resolve(animation, reduceMotion: reduceMotion), value: value)
    }
}

// MARK: - Press feedback

private struct CYPressHandledKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True inside a `CYPressableStyle` button, so kit cards do not scale a second time.
    var cyPressHandled: Bool {
        get { self[CYPressHandledKey.self] }
        set { self[CYPressHandledKey.self] = newValue }
    }
}

/// THE press feel: scale 0.97 on a 120 ms spring, released on a 250 ms spring. Reduce Motion: a dim, no scale.
/// Kit views (`CYImageCard`, `CYListRow`, `CYPillButton`) apply it themselves; use this style (or `.cyPressable()`)
/// for custom tappable cards.
struct CYPressableStyle: ButtonStyle {
    var scale: CGFloat = 0.97
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .environment(\.cyPressHandled, true)
            .cyPressEffect(configuration.isPressed && isEnabled, scale: scale, reduceMotion: reduceMotion)
    }
}

extension ButtonStyle where Self == CYPressableStyle {
    static var cyPressable: CYPressableStyle { CYPressableStyle() }
}

extension View {
    /// `.buttonStyle(CYPressableStyle())`.
    func cyPressable() -> some View { buttonStyle(CYPressableStyle()) }

    /// The shared scale/dim response for a pressed state.
    func cyPressEffect(_ pressed: Bool, scale: CGFloat = 0.97, reduceMotion: Bool) -> some View {
        self
            .scaleEffect(pressed && !reduceMotion ? scale : 1)
            .opacity(pressed && reduceMotion ? 0.7 : 1)
            .animation(reduceMotion ? CYMotion.reduced : (pressed ? CYMotion.press : CYMotion.release), value: pressed)
    }

    /// Press feedback for kit views (`CYImageCard`, `CYListRow`, ...). Gesture-free: it reads the pressed state that an
    /// enclosing `CYPressButtonStyle` publishes, so it can never compete with a NavigationLink/Button/List tap (a
    /// simultaneous LongPressGesture here swallowed every List NavigationLink tap on the iOS 27 runtime). Without that
    /// style it does nothing and the parent's own highlight (List row, `.plain` dim) is the feedback.
    func cyPressTracking() -> some View { modifier(CYPressTracking()) }
}

private struct CYPressedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True while the enclosing `CYPressButtonStyle` button is held down.
    var cyIsPressed: Bool {
        get { self[CYPressedKey.self] }
        set { self[CYPressedKey.self] = newValue }
    }
}

/// Publishes the button's pressed state to `cyPressTracking()` views in its label and draws nothing itself, so only the
/// kit card scales (not the label's surrounding chrome); disabled dims like `.plain`. Use it on Buttons/NavigationLinks outside a List row, or on
/// borderless buttons inside one; a List NavigationLink row keeps the system row highlight instead.
struct CYPressButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isEnabled ? 1 : 0.5)
            .environment(\.cyIsPressed, configuration.isPressed && isEnabled)
    }
}

extension ButtonStyle where Self == CYPressButtonStyle {
    static var cyPressTracked: CYPressButtonStyle { CYPressButtonStyle() }
}

private struct CYPressTracking: ViewModifier {
    @Environment(\.cyIsPressed) private var pressed
    @Environment(\.cyPressHandled) private var handled
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        if handled {
            content
        } else {
            content.cyPressEffect(pressed, reduceMotion: reduceMotion)
        }
    }
}

// MARK: - Hero transition (card to detail)

extension View {
    /// Mark the card that a detail zooms out of. iOS 18+, and not under Reduce Motion; iOS 17 keeps the default push.
    func cyHeroSource<ID: Hashable>(_ id: ID, in namespace: Namespace.ID, cornerRadius: CGFloat = CYRadius.lg) -> some View {
        modifier(CYHeroSource(id: id, namespace: namespace, cornerRadius: cornerRadius))
    }
    /// Apply to the detail's root view. Pairs with `cyHeroSource` on the same `id` and namespace.
    func cyHeroDestination<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        modifier(CYHeroDestination(id: id, namespace: namespace))
    }
}

private struct CYHeroSource<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID
    var cornerRadius: CGFloat = CYRadius.lg
    @QuestifyReduceMotion private var reduceMotion
    @State private var size: CGSize = .zero
    /// The clip never exceeds half the source's shorter side. The pill token (`CYRadius.pill`, 499.5) on a 44 pt button
    /// left the resting source invisible on iOS 27 (activity footer 立即报名, integ-r3 verify): the configuration also
    /// clips the resting source, and a radius that far past the shape does not clamp to a capsule there.
    private var clampedRadius: CGFloat {
        guard size.width > 0, size.height > 0 else { return min(cornerRadius, CYRadius.xl) }
        return min(cornerRadius, min(size.width, size.height) / 2)
    }
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            // matchedTransitionSource only accepts RoundedRectangle clips (not CYFoilClip): the .circular corner style
            // keeps radius = side / 2 a true circle (a .continuous one turns into a diamond).
            // No `.background` here: the configuration also applies to the resting source and replaced the seal's own fill.
            content
                .onGeometryChange(for: CGSize.self) { $0.size } action: { size = $0 }
                .matchedTransitionSource(id: id, in: namespace) { source in
                    source.clipShape(RoundedRectangle(cornerRadius: clampedRadius, style: .circular))
                }
        } else {
            content
        }
    }
}

private struct CYHeroDestination<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID
    @QuestifyReduceMotion private var reduceMotion
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.navigationTransition(.zoom(sourceID: id, in: namespace))
        } else {
            content
        }
    }
}

// MARK: - Scroll-driven effects

extension View {
    /// Header artwork that stretches and scales when pulled down and parallaxes (moves at half speed) when scrolled up.
    /// Put it on the first view inside a `ScrollView`; pass the header's resting height.
    func cyHeroParallax(height: CGFloat) -> some View { modifier(CYHeroParallax(height: height)) }

    /// Cards in a vertical scroll ease in from 0.96 scale and 0.6 opacity at the screen edges. LazyVStack/ScrollView only.
    func cyScrollReveal() -> some View { modifier(CYScrollReveal()) }

    /// Pinned bar at the top of a scroll view. Material blur (solid surface under Reduce Transparency) that fades in
    /// once the content scrolls beneath it. Apply to the `ScrollView` / `List`.
    func cyStickyHeader<Header: View>(@ViewBuilder _ header: () -> Header) -> some View {
        modifier(CYStickyHeader(header: header()))
    }
}

private struct CYHeroParallax: ViewModifier {
    let height: CGFloat
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        if reduceMotion {
            content.frame(height: height)
        } else {
            content
                .frame(height: height)
                .visualEffect { view, proxy in
                    let y = proxy.frame(in: .scrollView).minY
                    let stretch = max(0, y)
                    let scale = 1 + stretch / max(height, 1)
                    return view
                        .scaleEffect(scale, anchor: .bottom)
                        .offset(y: y > 0 ? -stretch : -y * 0.5)
                }
        }
    }
}

private struct CYScrollReveal: ViewModifier {
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content.scrollTransition(.animated(.easeOut(duration: CYMotion.Duration.quick)).threshold(.visible(0.15))) { view, phase in
                view
                    .opacity(phase.isIdentity ? 1 : 0.6)
                    .scaleEffect(phase.isIdentity ? 1 : 0.96)
            }
        }
    }
}

private struct CYStickyHeader<Header: View>: ViewModifier {
    let header: Header
    @State private var scrolled = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.cyPalette) private var palette

    func body(content: Content) -> some View {
        tracked(content)
            .safeAreaInset(edge: .top, spacing: 0) {
                header
                    .frame(maxWidth: .infinity)
                    .background {
                        ZStack {
                            if reduceTransparency { palette.bgElevated } else { Rectangle().fill(.ultraThinMaterial) }
                        }
                        .opacity(scrolled ? 1 : 0)
                        .overlay(alignment: .bottom) { Divider().opacity(scrolled ? 1 : 0) }
                        .ignoresSafeArea(edges: .top)
                    }
                    .cyAnimation(.easeOut(duration: CYMotion.Duration.quick), value: scrolled)
            }
    }

    @ViewBuilder private func tracked(_ content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content.onScrollGeometryChange(for: Bool.self) { $0.contentOffset.y + $0.contentInsets.top > 4 } action: { _, new in scrolled = new }
        } else {
            content.onAppear { scrolled = true }
        }
    }
}

// MARK: - List motion

/// Remembers which first-screen cards already appeared, so the stagger plays once per screen (hold in `@State`).
@MainActor final class CYStaggerGate {
    fileprivate var shown: Set<Int> = []
    init() {}
}

extension View {
    /// First screen of cards fades and rises in, 50 ms apart, for the first six items only and only once per `gate`.
    func cyStaggeredAppear(index: Int, gate: CYStaggerGate) -> some View {
        modifier(CYStaggeredAppear(index: index, gate: gate))
    }
    /// Insert: scale from 0.96 and fade. Delete: fade. Reduce Motion: fade only. Drive with `.cyAnimation(value: ids)`.
    func cyRowTransition() -> some View { modifier(CYRowTransition()) }
}

private struct CYStaggeredAppear: ViewModifier {
    static let maxItems = 6
    let index: Int
    let gate: CYStaggerGate
    @State private var visible: Bool
    @QuestifyReduceMotion private var reduceMotion

    init(index: Int, gate: CYStaggerGate) {
        self.index = index
        self.gate = gate
        _visible = State(initialValue: index >= Self.maxItems || gate.shown.contains(index))
    }

    func body(content: Content) -> some View {
        content
            .opacity(visible || reduceMotion ? 1 : 0)
            .offset(y: visible || reduceMotion ? 0 : 14)
            .onAppear {
                guard !visible else { return }
                gate.shown.insert(index)
                withAnimation(CYMotion.entrance.delay(Double(index) * 0.05)) { visible = true }
            }
    }
}

private struct CYRowTransition: ViewModifier {
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        content.transition(reduceMotion ? .opacity : .asymmetric(insertion: .scale(scale: 0.96).combined(with: .opacity), removal: .opacity))
    }
}

/// Skeleton to content cross-fade (`quick`, 0.20 s). Under Reduce Motion the swap is instant.
struct CYContentSwap<Skeleton: View, Content: View>: View {
    let isLoading: Bool
    @ViewBuilder var skeleton: () -> Skeleton
    @ViewBuilder var content: () -> Content
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        ZStack {
            if isLoading {
                skeleton().transition(.opacity)
            } else {
                content().transition(.opacity)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: CYMotion.Duration.quick), value: isLoading)
    }
}

// MARK: - Pull to refresh

extension View {
    /// `.refreshable` with a light tick at release and a floor of 0.45 s so a fast reload never flashes the spinner.
    func cyRefreshable(_ action: @escaping @Sendable () async -> Void) -> some View {
        refreshable {
            await MainActor.run { CYHaptics.impactLight.play() }
            let start = ContinuousClock.now
            await action()
            let floor = Duration.milliseconds(450)
            let elapsed = ContinuousClock.now - start
            if elapsed < floor { try? await Task.sleep(for: floor - elapsed) }
        }
    }
}

// MARK: - Entrance

extension View {
    /// One-shot entrance: fade, small rise and scale from 0.9. Reduce Motion: appears at once.
    func cyEntrance(delay: Double = 0, scale: CGFloat = 0.9) -> some View { modifier(CYEntrance(delay: delay, scale: scale)) }
}

private struct CYEntrance: ViewModifier {
    let delay: Double
    let scale: CGFloat
    @State private var shown = false
    @QuestifyReduceMotion private var reduceMotion
    func body(content: Content) -> some View {
        content
            .opacity(shown || reduceMotion ? 1 : 0)
            .scaleEffect(shown || reduceMotion ? 1 : scale)
            .offset(y: shown || reduceMotion ? 0 : 10)
            .onAppear {
                guard !shown else { return }
                withAnimation(CYMotion.entrance.delay(delay)) { shown = true }
            }
    }
}

/// `cyHeroSource` when the host supplied a namespace, otherwise nothing.
struct CYOptionalHeroSource<ID: Hashable>: ViewModifier {
    let id: ID
    let namespace: Namespace.ID?
    @ViewBuilder func body(content: Content) -> some View {
        if let namespace { content.cyHeroSource(id, in: namespace) } else { content }
    }
}


// MARK: - Shared hero namespace (continuity)

private struct CYHeroNamespaceKey: EnvironmentKey { static let defaultValue: Namespace.ID? = nil }

extension EnvironmentValues {
    /// The tab root's hero namespace. A host owns one `@Namespace`, publishes it with `cyHeroNamespace(_:)`, and every card
    /// below marks itself with `cyHeroSourceInherited(_:)` without threading the namespace through initializers.
    /// nil (previews, fixtures that do not publish one) means "no continuity": cards behave as plain buttons.
    var cyHeroNamespace: Namespace.ID? {
        get { self[CYHeroNamespaceKey.self] }
        set { self[CYHeroNamespaceKey.self] = newValue }
    }
}

extension View {
    func cyHeroNamespace(_ namespace: Namespace.ID) -> some View { environment(\.cyHeroNamespace, namespace) }

    /// `cyHeroSource` using the inherited namespace. `isEnabled: false` lets one of several copies of the same item opt out,
    /// so a namespace never holds two sources for one id.
    func cyHeroSourceInherited<ID: Hashable>(_ id: ID, isEnabled: Bool = true, cornerRadius: CGFloat = CYRadius.lg) -> some View {
        modifier(CYInheritedHeroSource(id: id, isEnabled: isEnabled, cornerRadius: cornerRadius))
    }

    /// `cyHeroDestination` plus the iOS 17 / Reduce-Motion-free fallback: where the zoom is unavailable the plain push gets
    /// a short rise-and-fade entrance so the detail still lands instead of snapping in.
    func cyHeroDestinationWithFallback<ID: Hashable>(_ id: ID, in namespace: Namespace.ID) -> some View {
        modifier(CYHeroFallbackEntrance()).cyHeroDestination(id, in: namespace)
    }

    /// Detail title that settles from just below its resting place while the hero zooms, so the card's title reads as
    /// travelling into the page title. Offset-led: the title never drops below half opacity, so it does not blink.
    func cyHeroTitleRise(delay: Double = 0.06) -> some View { modifier(CYHeroTitleRise(delay: delay)) }
}

private struct CYInheritedHeroSource<ID: Hashable>: ViewModifier {
    let id: ID
    let isEnabled: Bool
    let cornerRadius: CGFloat
    @Environment(\.cyHeroNamespace) private var namespace
    @ViewBuilder func body(content: Content) -> some View {
        if isEnabled, let namespace { content.cyHeroSource(id, in: namespace, cornerRadius: cornerRadius) } else { content }
    }
}

/// iOS 17 only (the zoom needs iOS 18): the detail enters with a short rise + fade. Reduce Motion: nothing.
private struct CYHeroFallbackEntrance: ViewModifier {
    @QuestifyReduceMotion private var reduceMotion
    @State private var shown = false
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *) {
            content
        } else if reduceMotion {
            content
        } else {
            content
                .opacity(shown ? 1 : 0)
                .offset(y: shown ? 0 : 28)
                .onAppear {
                    guard !shown else { return }
                    withAnimation(CYMotion.entrance) { shown = true }
                }
        }
    }
}

private struct CYHeroTitleRise: ViewModifier {
    let delay: Double
    @QuestifyReduceMotion private var reduceMotion
    @State private var settled = false
    func body(content: Content) -> some View {
        content
            .offset(y: settled || reduceMotion ? 0 : 16)
            .opacity(settled || reduceMotion ? 1 : 0.5)
            .onAppear {
                guard !settled else { return }
                withAnimation(CYMotion.entrance.delay(delay)) { settled = true }
            }
    }
}


// MARK: - Zoom destination background

extension View {
    /// Page background for a zoom destination. On iOS 18 (zoom, no Reduce Motion) it starts transparent and fades in after the
    /// zoom has opened, so the destination never lays an opaque ink rounded blob over the source page while it is still
    /// visible. iOS 17 (plain push) and Reduce Motion get the opaque background at once: a sliding page must not be see-through.
    func cyHeroZoomPageBackground() -> some View { modifier(CYHeroZoomPageBackground()) }
}

private struct CYHeroZoomPageBackground: ViewModifier {
    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var settled = false
    private var zooms: Bool { if #available(iOS 18.0, *) { return !reduceMotion } else { return false } }
    func body(content: Content) -> some View {
        content
            .background(palette.bgPage.ignoresSafeArea().opacity(zooms && !settled ? 0 : 1))
            .onAppear {
                guard zooms, !settled else { return }
                withAnimation(.easeOut(duration: 0.2).delay(0.3)) { settled = true }
            }
    }
}
