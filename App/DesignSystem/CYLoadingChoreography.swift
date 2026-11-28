import SwiftUI

// Loading-to-content choreography (e4 motion system). Spec: docs/release/motion-spec-loading.md.
// Skeleton appears only after 120 ms, stays at least 350 ms once shown, then cross-fades into the content over 0.20 s
// while the first six rows stagger in. Every moving piece is gated on Reduce Motion through `@QuestifyReduceMotion`.

// MARK: - Skeleton timing (show-delay + minimum hold)

enum CYSkeletonTiming {
    static let showDelay: Duration = .milliseconds(120)
    static let minimumHold: Duration = .milliseconds(350)
}

/// Drives `visible` from `isLoading`: true only once the load has run longer than `showDelay`, and false again no
/// sooner than `minimumHold` after it became true, so a fast load never flashes a skeleton and a slow one never blinks.
private struct CYSkeletonTimingModifier: ViewModifier {
    let isLoading: Bool
    @Binding var visible: Bool
    @State private var shownAt: ContinuousClock.Instant?

    func body(content: Content) -> some View {
        content.task(id: isLoading) { await settle() }
    }

    private func settle() async {
        let clock = ContinuousClock()
        if isLoading {
            guard !visible else { return }
            try? await Task.sleep(for: CYSkeletonTiming.showDelay)
            guard !Task.isCancelled else { return }
            shownAt = clock.now
            visible = true
        } else if visible {
            if let shownAt {
                let remaining = CYSkeletonTiming.minimumHold - (clock.now - shownAt)
                if remaining > .zero { try? await Task.sleep(for: remaining) }
            }
            guard !Task.isCancelled else { return }
            visible = false
        }
    }
}

extension View {
    /// Maintains `visible` as the "skeleton is on screen" flag for a load (120 ms show-delay, 350 ms minimum hold).
    func cySkeletonTiming(isLoading: Bool, visible: Binding<Bool>) -> some View {
        modifier(CYSkeletonTimingModifier(isLoading: isLoading, visible: visible))
    }
}

// MARK: - List choreography

/// A list that loads the same way everywhere: `CYPhaseView` (timed skeleton, 0.20 s cross-fade) around a lazy stack whose
/// first six rows stagger in once per screen instance (`CYStaggerGate`). Rows diff with `cyRowTransition`.
struct CYListChoreography<Item: Identifiable, Failure, Row: View>: View {
    let phase: CYPhase<[Item], Failure>
    var skeletonRows = 6
    let loadingLabel: LocalizedStringKey
    var emptySystemImage = "tray"
    let emptyMessage: LocalizedStringKey
    var failureMessage: LocalizedStringKey = "Couldn't load this. Check your connection."
    var spacing: CGFloat = CYSpacing.md
    @ViewBuilder var row: (Item) -> Row

    @State private var gate = CYStaggerGate()

    var body: some View {
        CYPhaseView(
            phase: phase,
            skeletonRows: min(max(skeletonRows, 1), CYStaggerLimit.rows),
            loadingLabel: loadingLabel,
            emptySystemImage: emptySystemImage,
            emptyMessage: emptyMessage,
            failureMessage: failureMessage
        ) { items in
            LazyVStack(spacing: spacing) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    row(item)
                        .cyRowTransition()
                        .cyStaggeredAppear(index: index, gate: gate)
                }
            }
            .cyAnimation(CYMotion.standard, value: items.map(\.id))
        }
    }
}

enum CYStaggerLimit {
    /// Rows that get a stagger delay and rows a skeleton ever shows. Rows from this index on appear with no delay.
    static let rows = 6
}

// MARK: - Load slot (flag-driven screens)

/// `CYPhaseView` for screens that keep their own empty / failure UI and only expose a loading flag:
/// `isLoading` shows the timed skeleton (120 ms delay, 350 ms hold, 0.20 s cross-fade); anything else is `content`.
/// Wrap the WHOLE branch chain, not just the placeholder, so the cross-fade has both sides to blend. While the load
/// has not shown its skeleton yet, `content` is rendered with its own loading branch (use `Color.clear` there).
struct CYLoadSlot<Content: View>: View {
    let isLoading: Bool
    var skeletonRows = 3
    let label: LocalizedStringKey
    var identifier: String? = nil
    /// Screens with several slots announce from only one of them.
    var announces = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        CYPhaseView<Void, Never, Content>(
            phase: isLoading ? .loading : .loaded(()),
            skeletonRows: skeletonRows,
            loadingLabel: label,
            emptyMessage: "",
            announcesChanges: announces,
            loadingIdentifier: identifier
        ) { _ in content() }
    }
}

// MARK: - Stat number

/// Header stat (balance, count, km, streak) whose changed digits roll (`contentTransition(.numericText)`).
/// Same pattern as `CYAnimatedPrice`. `rollsOnAppear` rolls up from zeros on first appearance when the value is at most
/// four digits; longer values just appear. Reduce Motion: a 0.20 s cross-fade, no roll from zero.
/// VoiceOver reads the final string only (the roll is visual).
struct CYStatNumber: View {
    let text: String
    var font: Font = CYTypography.data2XL
    var color: Color? = nil
    var rollsOnAppear = false
    @QuestifyReduceMotion private var reduceMotion
    @Environment(\.cyPalette) private var palette
    @State private var armed = false

    private var shown: String {
        guard rollsOnAppear, !armed, !reduceMotion, Self.digitCount(text) <= 4 else { return text }
        return String(text.map { $0.isNumber ? "0" : $0 })
    }

    var body: some View {
        Text(verbatim: shown)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(color ?? palette.textPrimary)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .contentTransition(reduceMotion ? .opacity : .numericText())
            .animation(reduceMotion ? CYMotion.reduced : CYMotion.standard, value: shown)
            .accessibilityLabel(Text(verbatim: text))
            .onAppear { armed = true }
    }

    private static func digitCount(_ text: String) -> Int { text.filter(\.isNumber).count }
}

// MARK: - Segmented content

/// In-screen tab swap (segmented control or chip tabs): the outgoing content fades over 0.20 s, the incoming one fades in
/// and rises 8 pt. Reduce Motion: cross-fade only. Plays one `.selection` haptic unless the picker already does.
struct CYSegmentedContent<Selection: Hashable, Content: View>: View {
    let selection: Selection
    var haptic = true
    @ViewBuilder var content: () -> Content
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        ZStack {
            content()
                .id(selection)
                .transition(reduceMotion ? .opacity : .asymmetric(insertion: .opacity.combined(with: .offset(y: 8)), removal: .opacity))
        }
        .animation(.easeInOut(duration: CYMotion.Duration.quick), value: selection)
        .cyHaptic(.selection, trigger: selection, where: playsSelectionHaptic)
        .onChange(of: selection) { _, _ in UIAccessibility.post(notification: .layoutChanged, argument: nil) }
    }
}

private extension CYSegmentedContent {
    /// Typed haptic condition: the `.selection` tick plays unless the picker already plays one.
    func playsSelectionHaptic(_ old: Selection, _ new: Selection) -> Bool { haptic }
}
