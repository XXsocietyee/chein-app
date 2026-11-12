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
/// | `.impactLight` | pull-to-refresh trigger, sheet detent snap |
/// | `.impactMedium` | primary commit (register, check-in) |
/// | `.impactHeavy` | GO press |
enum CYHaptics: Equatable {
    case selection, success, warning, impactLight, impactMedium, impactHeavy

    var sensory: SensoryFeedback {
        switch self {
        case .selection: return .selection
        case .success: return .success
        case .warning: return .warning
        case .impactLight: return .impact(weight: .light)
        case .impactMedium: return .impact(weight: .medium)
        case .impactHeavy: return .impact(weight: .heavy)
        }
    }

    /// Imperative form for non-view code (refresh actions). 120 ms cooldown so stacked triggers never buzz twice.
    @MainActor func play() {
        #if canImport(UIKit)
        let now = ProcessInfo.processInfo.systemUptime
        guard now - Self.lastPlayed >= 0.12 else { return }
        Self.lastPlayed = now
        switch self {
        case .selection: UISelectionFeedbackGenerator().selectionChanged()
        case .success: UINotificationFeedbackGenerator().notificationOccurred(.success)
        case .warning: UINotificationFeedbackGenerator().notificationOccurred(.warning)
        case .impactLight: UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .impactMedium: UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .impactHeavy: UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
        }
        #endif
    }
    @MainActor private static var lastPlayed: TimeInterval = 0
}

extension View {
    /// Declarative haptic: plays `haptic` whenever `trigger` changes.
    func cyHaptic<T: Equatable>(_ haptic: CYHaptics, trigger: T) -> some View {
        sensoryFeedback(haptic.sensory, trigger: trigger)
    }
    /// Plays `haptic` only for the transitions `condition(old, new)` accepts (e.g. press down).
    func cyHaptic<T: Equatable>(_ haptic: CYHaptics, trigger: T, where condition: @escaping (T, T) -> Bool) -> some View {
        sensoryFeedback(haptic.sensory, trigger: trigger, condition: condition)
    }
}

// MARK: - Tokens

/// Four durations (0.12 / 0.20 / 0.35 / 0.60 s). Springs are response/damping pairs (see the spec table).
enum CYMotion {
    enum Duration {
        static let instant: Double = 0.12    // press-down, chip tick, toggle
        static let quick: Double = 0.20      // fades, reveals, cross-fades, skeleton to content, tab swap
        static let standard: Double = 0.35   // list insert/delete, hero entrance, ring fill
        static let slow: Double = 0.60       // celebration land, flip, count-up
        /// Alias kept for existing callers; it is `standard` on the four-step grid.
        static let emphasized: Double = standard
    }
    /// Touch-down. 120 ms.
    static let press = Animation.spring(response: 0.12, dampingFraction: 0.9)
    /// Touch-up. Slight overshoot, lands in about 0.25 s.
    static let release = Animation.spring(response: 0.25, dampingFraction: 0.7)
    /// Default content motion (insert, delete, reorder).
    static let standard = Animation.spring(response: 0.3, dampingFraction: 0.85)
    /// Entrances (empty state, staggered cards).
    static let entrance = Animation.spring(response: 0.35, dampingFraction: 0.8)
    /// Reduce Motion replacement: a short cross-fade.
    static let reduced = Animation.easeInOut(duration: Duration.quick)

    /// `animation` normally, the cross-fade when Reduce Motion is on.
    static func resolve(_ animation: Animation, reduceMotion: Bool) -> Animation { reduceMotion ? reduced : animation }
}

extension View {
    /// `.animation(_, value:)` that degrades to a cross-fade under Reduce Motion.
    func cyAnimation<V: Equatable>(_ animation: Animation = CYMotion.standard, value: V) -> some View {
        modifier(CYAnimationModifier(animation: animation, value: value))
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

    /// Press feedback for kit views that sit inside a plain Button/NavigationLink. Tracks the touch with a
    /// simultaneous long-press (cancelled by a scroll), so the parent's tap and scrolling are untouched.
    func cyPressTracking() -> some View { modifier(CYPressTracking()) }
}

private struct CYPressTracking: ViewModifier {
    @GestureState private var pressed = false
    @Environment(\.cyPressHandled) private var handled
    @Environment(\.isEnabled) private var isEnabled
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        if handled {
            content
        } else {
            content
                .cyPressEffect(pressed && isEnabled, reduceMotion: reduceMotion)
                .simultaneousGesture(
                    LongPressGesture(minimumDuration: 60, maximumDistance: 10)
                        .updating($pressed) { value, state, _ in state = value }
                )
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
    @ViewBuilder func body(content: Content) -> some View {
        if #available(iOS 18.0, *), !reduceMotion {
            content.matchedTransitionSource(id: id, in: namespace) { source in
                source.clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
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
