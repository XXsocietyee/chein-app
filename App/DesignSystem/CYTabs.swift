import SwiftUI

/// Tab visual/behavioural variants from DESIGN.md Part 4 (`underline`, `segmented`, `chip`, `sticky`).
public enum CYTabsVariant: Sendable, Hashable {
    case underline
    case segmented
    case chip
    case sticky
}

/// Tab descriptor for `CYTabs`.
public struct CYTabItem<ID: Hashable>: Identifiable {
    public let id: ID
    public let title: String
    public let badgeCount: Int?
    public let systemImage: String?

    public init(id: ID, title: String, badgeCount: Int? = nil, systemImage: String? = nil) {
        self.id = id
        self.title = title
        self.badgeCount = badgeCount
        self.systemImage = systemImage
    }
}

/// Pure state-to-token resolver for `CYTabs`.
enum CYTabsTokens {
    struct Resolved {
        let foreground: Color
        let badgeForeground: Color
        let indicatorFill: Color?
        let trackFill: Color?
        let divider: Color?
        let containerBackground: Color?
    }

    static func resolve(variant: CYTabsVariant, isSelected: Bool, in palette: CYDomainPalette) -> Resolved {
        switch variant {
        case .underline, .sticky:
            return Resolved(
                foreground: isSelected ? palette.textPrimary : palette.textSecondary,
                badgeForeground: isSelected ? palette.textPrimary : palette.textTertiary,
                indicatorFill: isSelected ? palette.textPrimary : nil,
                trackFill: nil,
                divider: palette.borderSubtle,
                containerBackground: variant == .sticky ? palette.bgPage : nil
            )
        case .segmented:
            // Native restyle (native-ios-r1 §3.7): drawn like `UISegmentedControl` (fill track, raised thumb, label
            // ink), so it reads as `Picker(.segmented)` while keeping one accessibility identifier per segment.
            return Resolved(
                foreground: isSelected ? palette.textPrimary : palette.textSecondary,
                badgeForeground: isSelected ? palette.textPrimary : palette.textTertiary,
                indicatorFill: isSelected ? palette.segmentThumb : nil,
                trackFill: palette.bgSurfaceSubtle,
                divider: nil,
                containerBackground: nil
            )
        case .chip:
            let chip = CYFilterChip.tokens(isSelected: isSelected, in: palette)
            return Resolved(
                foreground: chip.foreground,
                badgeForeground: chip.countForeground,
                indicatorFill: chip.background,
                trackFill: nil,
                divider: nil,
                containerBackground: nil
            )
        }
    }
}


/// Indicator and content timing for `CYTabs` (continuity r1, task 7). Not new product tokens: the edge lag is
/// `CYMotion.Duration.instant`, the rest is the brief's 400 to 450 ms indicator budget split between the two edges.
enum CYTabsMotion {
    /// Each edge travels on ease-in-out for this long (a move within the screen).
    static let edge: Double = 0.30
    /// The back edge leaves this long after the front edge, so the whole move is 0.42 s.
    static let lag: Double = CYMotion.Duration.instant
    static var total: Double { edge + lag }
    /// Height lost at the longest stretch.
    static let squash: CGFloat = 0.15
    /// With two ease-in-out edges `lag / edge` = 0.4 apart, the gap between them peaks at about 60% of the travel.
    static let peakGap: CGFloat = 0.6
    /// Labels cross over (weight and colour) while the indicator is mid-way.
    static let labels = Animation.easeInOut(duration: 0.28).delay(0.06)
    /// Reduce Motion: the indicator jumps with a fade.
    static let reducedFade = Animation.easeInOut(duration: 0.15)
    /// Content: the old view leaves in the first ~30%, the new one enters after ~45% of the move.
    static let contentOut = Animation.easeIn(duration: 0.12)
    static let contentIn = Animation.easeOut(duration: 0.24).delay(0.18)
    static let contentOffset: CGFloat = CYSpacing.lg
}

/// Rest boxes of every tab's indicator (the underline bar or the segment pill), keyed by tab index, in the bar's space.
private struct CYTabsIndicatorFrames: PreferenceKey {
    static let defaultValue: [Int: CGRect] = [:]
    static func reduce(value: inout [Int: CGRect], nextValue: () -> [Int: CGRect]) {
        value.merge(nextValue()) { $1 }
    }
}

/// The indicator while it travels: its two edges are animated separately (additive ease-in-out), so the front edge
/// leaves first and the back edge follows.
private struct CYTabsFlight: Equatable {
    var minX: CGFloat
    var maxX: CGFloat
    var restWidth: CGFloat
    var travel: CGFloat
}

/// One indicator drawn from its two edges. Stretching lowers the height by up to `CYTabsMotion.squash`. It is drawn in a
/// background layer, so nothing reflows while it moves.
private struct CYTabsIndicatorShape: Shape {
    var minX: CGFloat
    var maxX: CGFloat
    var midY: CGFloat
    var height: CGFloat
    let restWidth: CGFloat
    let travel: CGFloat
    /// nil draws a capsule.
    let cornerRadius: CGFloat?

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, AnimatablePair<CGFloat, CGFloat>> {
        get { AnimatablePair(AnimatablePair(minX, maxX), AnimatablePair(midY, height)) }
        set {
            minX = newValue.first.first
            maxX = newValue.first.second
            midY = newValue.second.first
            height = newValue.second.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let width = max(maxX - minX, 0)
        let stretch = max(width - restWidth, 0) / max(travel * CYTabsMotion.peakGap, 1)
        let h = height * (1 - CYTabsMotion.squash * min(stretch, 1))
        let box = CGRect(x: minX, y: midY - h / 2, width: width, height: h)
        let radius = min(cornerRadius ?? h / 2, h / 2, width / 2)
        return Path(roundedRect: box, cornerRadius: max(radius, 0), style: .continuous)
    }
}

/// Shared tab switcher across `underline`, `segmented`, `chip`, and `sticky` modes.
/// Active indicator always uses neutral high-contrast tokens (`textPrimary`), never violet.
/// Motion (continuity r1): one indicator travels between the tabs like `CYNightTabBar`'s pill. Its front edge leaves first
/// and its back edge follows `CYTabsMotion.lag` later, so it stretches on the way (losing up to 15% of its height) and
/// settles in 0.42 s; the labels' weight and colour cross over. Reduce Motion: the indicator jumps with a 150 ms fade.
public struct CYTabs<ID: Hashable>: View {
    private let items: [CYTabItem<ID>]
    @Binding private var selection: ID
    private let variant: CYTabsVariant

    @Environment(\.cyPalette) private var palette
    @QuestifyReduceMotion private var reduceMotion
    @State private var frames: [Int: CGRect] = [:]
    @State private var flight: CYTabsFlight?
    @State private var flightTask: Task<Void, Never>?

    private static var space: String { "cy.tabs.bar" }

    public init(
        items: [CYTabItem<ID>],
        selection: Binding<ID>,
        variant: CYTabsVariant = .underline
    ) {
        self.items = items
        self._selection = selection
        self.variant = variant
    }

    public var body: some View {
        switch variant {
        case .underline:
            underlineBar
        case .segmented:
            segmentedBar
        case .chip:
            chipBar
        case .sticky:
            let tokens = CYTabsTokens.resolve(variant: .sticky, isSelected: true, in: palette)
            underlineBar
                .background(tokens.containerBackground ?? palette.bgPage)
                .zIndex(85)
        }
    }

    private var selectedIndex: Int? { items.firstIndex { $0.id == selection } }

    @ViewBuilder
    private var underlineBar: some View {
        let shouldScroll = items.count >= 5
        let barTokens = CYTabsTokens.resolve(variant: variant, isSelected: false, in: palette)
        VStack(spacing: 0) {
            if shouldScroll {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: CYSpacing.lg) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            underlineTabButton(item, index: index, fillsWidth: false)
                        }
                    }
                    .padding(.horizontal, CYSpacing.pageHorizontal)
                    .modifier(indicatorLayer(cornerRadius: nil))
                }
            } else {
                HStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        underlineTabButton(item, index: index, fillsWidth: true)
                    }
                }
                .padding(.horizontal, CYSpacing.pageHorizontal)
                .modifier(indicatorLayer(cornerRadius: nil))
            }
            Rectangle()
                .fill(barTokens.divider ?? palette.borderSubtle)
                .frame(height: 0.5)
        }
    }

    private func underlineTabButton(_ item: CYTabItem<ID>, index: Int, fillsWidth: Bool) -> some View {
        let isSelected = item.id == selection
        return Button {
            select(item.id)
        } label: {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                crossingLabel(item, isSelected: isSelected) { tokens, selectedStyle in
                    HStack(spacing: CYSpacing.xs) {
                        if let systemImage = item.systemImage {
                            Image(systemName: systemImage)
                                .font(CYTypography.caption.weight(.semibold))
                        }
                        Text(verbatim: item.title)
                            .font(CYTypography.label.weight(selectedStyle ? .bold : .semibold))
                        if let badgeCount = item.badgeCount, badgeCount > 0 {
                            Text(verbatim: "\(badgeCount)")
                                .cyText(.micro, weight: .bold, monospacedDigit: true)
                                .foregroundStyle(tokens.badgeForeground)
                        }
                    }
                    .foregroundStyle(tokens.foreground)
                    .cyWrapText(alignment: .center)
                }
                Spacer(minLength: 0)
                // The rest box of the underline; the indicator itself is drawn once, behind the row.
                Color.clear
                    .frame(width: 24, height: 2.5)
                    .background(indicatorFrameReporter(index))
            }
            .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: CYSpacing.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var segmentedBar: some View {
        let trackFill = CYTabsTokens.resolve(variant: .segmented, isSelected: false, in: palette).trackFill ?? palette.bgSurfaceSubtle
        return HStack(spacing: CYSpacing.xs) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isSelected = item.id == selection
                Button {
                    select(item.id)
                } label: {
                    crossingLabel(item, isSelected: isSelected) { tokens, selectedStyle in
                        HStack(spacing: CYSpacing.xs) {
                            if let systemImage = item.systemImage {
                                Image(systemName: systemImage)
                                    .font(.footnote.weight(.semibold))
                            }
                            Text(verbatim: item.title)
                                .font(.subheadline.weight(selectedStyle ? .semibold : .medium))
                                .cyWrapText(alignment: .center)
                        }
                        .foregroundStyle(tokens.foreground)
                    }
                    .frame(maxWidth: .infinity, minHeight: 36)
                    .background(indicatorFrameReporter(index))
                    .frame(minHeight: CYSpacing.minTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .modifier(indicatorLayer(cornerRadius: CYRadius.inner - 1))
        .padding(2)
        .background(RoundedRectangle(cornerRadius: CYRadius.inner + 1, style: .continuous).fill(trackFill))
    }

    private var chipBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: CYSpacing.sm) {
                ForEach(items) { item in
                    CYFilterChip(
                        verbatim: item.title,
                        systemImage: item.systemImage,
                        count: item.badgeCount,
                        isSelected: item.id == selection
                    ) {
                        select(item.id)
                    }
                }
            }
            .padding(.horizontal, CYSpacing.pageHorizontal)
        }
        .overlay(alignment: .trailing) {
            LinearGradient(
                colors: [palette.bgPage.opacity(0), palette.bgPage],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: 24)
            .allowsHitTesting(false)
        }
    }

    // MARK: Labels

    /// Both weights are laid out on top of each other and cross-fade, so the weight and the colour change together and
    /// the tab never changes width (no neighbour reflows when bold lands). VoiceOver reads one element: title, badge value.
    private func crossingLabel<Row: View>(
        _ item: CYTabItem<ID>,
        isSelected: Bool,
        @ViewBuilder row: (CYTabsTokens.Resolved, Bool) -> Row
    ) -> some View {
        let off = CYTabsTokens.resolve(variant: variant, isSelected: false, in: palette)
        let on = CYTabsTokens.resolve(variant: variant, isSelected: true, in: palette)
        let badge = item.badgeCount.flatMap { $0 > 0 ? "\($0)" : nil } ?? ""
        return ZStack {
            row(off, false).opacity(isSelected ? 0 : 1)
            row(on, true).opacity(isSelected ? 1 : 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: item.title))
        .accessibilityValue(Text(verbatim: badge))
    }

    // MARK: Indicator

    private func indicatorFrameReporter(_ index: Int) -> some View {
        GeometryReader { proxy in
            Color.clear.preference(
                key: CYTabsIndicatorFrames.self,
                value: [index: proxy.frame(in: .named(Self.space))]
            )
        }
    }

    private func indicatorLayer(cornerRadius: CGFloat?) -> CYTabsIndicatorLayer {
        CYTabsIndicatorLayer(
            space: Self.space,
            selectedIndex: selectedIndex,
            flight: reduceMotion ? nil : flight,
            reduceMotion: reduceMotion,
            fill: CYTabsTokens.resolve(variant: variant, isSelected: true, in: palette).indicatorFill ?? palette.textPrimary,
            cornerRadius: cornerRadius,
            frames: $frames
        )
    }

    private func select(_ id: ID) {
        guard id != selection else { return }
        if reduceMotion {
            withAnimation(CYTabsMotion.reducedFade) { selection = id }
            return
        }
        if let from = selectedIndex,
           let to = items.firstIndex(where: { $0.id == id }),
           let fromBox = frames[from],
           let toBox = frames[to] {
            fly(from: fromBox, to: toBox)
        }
        withAnimation(CYTabsMotion.labels) { selection = id }
    }

    /// Front edge now, back edge `lag` later, both on ease-in-out; a new tap retargets from wherever the edges are
    /// (the edge animations are additive, so nothing jumps), and the task that would land the old move is cancelled.
    private func fly(from fromBox: CGRect, to toBox: CGRect) {
        // From rest, start from the box on screen; mid-flight, keep the edges where they are heading.
        let current = flight ?? CYTabsFlight(minX: fromBox.minX, maxX: fromBox.maxX, restWidth: fromBox.width, travel: 0)
        let forward = toBox.midX >= (current.minX + current.maxX) / 2
        flight = CYTabsFlight(
            minX: current.minX,
            maxX: current.maxX,
            restWidth: toBox.width,
            travel: abs(toBox.midX - fromBox.midX)
        )
        let edge = Animation.easeInOut(duration: CYTabsMotion.edge)
        withAnimation(edge) {
            if forward { flight?.maxX = toBox.maxX } else { flight?.minX = toBox.minX }
        }
        flightTask?.cancel()
        flightTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(CYTabsMotion.lag * 1000)))
            if Task.isCancelled { return }
            withAnimation(edge) {
                if forward { flight?.minX = toBox.minX } else { flight?.maxX = toBox.maxX }
            }
            try? await Task.sleep(for: .milliseconds(Int(CYTabsMotion.edge * 1000) + 40))
            if Task.isCancelled { return }
            // Landed: hand the indicator back to the live rest box (same values, so nothing moves).
            var landing = Transaction()
            landing.disablesAnimations = true
            withTransaction(landing) { flight = nil }
        }
    }
}

/// Draws the one indicator behind the tab row and keeps the rest boxes for the next move.
private struct CYTabsIndicatorLayer: ViewModifier {
    let space: String
    let selectedIndex: Int?
    let flight: CYTabsFlight?
    let reduceMotion: Bool
    let fill: Color
    let cornerRadius: CGFloat?
    @Binding var frames: [Int: CGRect]

    func body(content: Content) -> some View {
        content
            .coordinateSpace(name: space)
            .backgroundPreferenceValue(CYTabsIndicatorFrames.self) { boxes in
                indicator(boxes)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .onPreferenceChange(CYTabsIndicatorFrames.self) { frames = $0 }
    }

    @ViewBuilder
    private func indicator(_ boxes: [Int: CGRect]) -> some View {
        if reduceMotion {
            // Reduce Motion: every slot keeps its own indicator and only the selected one is opaque, so a change is a
            // 150 ms fade in place with no travel.
            ZStack {
                ForEach(boxes.keys.sorted(), id: \.self) { index in
                    if let box = boxes[index] {
                        shape(minX: box.minX, maxX: box.maxX, box: box, restWidth: box.width, travel: 0)
                            .opacity(index == selectedIndex ? 1 : 0)
                    }
                }
            }
        } else if let selectedIndex, let box = boxes[selectedIndex] {
            if let flight {
                shape(minX: flight.minX, maxX: flight.maxX, box: box, restWidth: flight.restWidth, travel: flight.travel)
            } else {
                shape(minX: box.minX, maxX: box.maxX, box: box, restWidth: box.width, travel: 0)
            }
        }
    }

    private func shape(minX: CGFloat, maxX: CGFloat, box: CGRect, restWidth: CGFloat, travel: CGFloat) -> some View {
        CYTabsIndicatorShape(
            minX: minX,
            maxX: maxX,
            midY: box.midY,
            height: box.height,
            restWidth: restWidth,
            travel: travel,
            cornerRadius: cornerRadius
        )
        .fill(fill)
    }
}

// MARK: - Tab content

extension View {
    /// The content under a `CYTabs` bar, keyed by the selection: the new content comes in from the side of the chosen tab
    /// (a trailing tab's content from the trailing side) and the old content leaves the other way, a short offset plus
    /// opacity. The old view fades in the first ~30% of the indicator's move, the new one after ~45%. Reduce Motion: a
    /// 150 ms cross-fade. `order` is the tabs' order (the same ids as the `CYTabItem`s).
    func cyTabContent<ID: Hashable>(_ selection: ID, order: [ID]) -> some View {
        modifier(CYTabContentModifier(selection: selection, order: order))
    }
}

/// Shared by the inserted and the removed view. An exit reads its direction when it starts (the removed view keeps the
/// transition from its last render), so the direction lives in a reference both transitions read at that moment.
private final class CYTabContentDirection {
    var index: Int?
    var forward = true
}

private struct CYTabContentModifier<ID: Hashable>: ViewModifier {
    let selection: ID
    let order: [ID]
    @State private var direction = CYTabContentDirection()
    @QuestifyReduceMotion private var reduceMotion

    func body(content: Content) -> some View {
        let index = order.firstIndex(of: selection)
        if let index {
            if let last = direction.index, last != index { direction.forward = index > last }
            direction.index = index
        }
        return ZStack {
            content
                .id(selection)
                .transition(transition)
        }
    }

    private var transition: AnyTransition {
        if reduceMotion { return AnyTransition.opacity.animation(CYTabsMotion.reducedFade) }
        return .asymmetric(
            insertion: .modifier(
                active: CYTabContentShift(direction: direction, phase: .entering),
                identity: CYTabContentShift(direction: direction, phase: .settled)
            ).animation(CYTabsMotion.contentIn),
            removal: .modifier(
                active: CYTabContentShift(direction: direction, phase: .leaving),
                identity: CYTabContentShift(direction: direction, phase: .settled)
            ).animation(CYTabsMotion.contentOut)
        )
    }
}

private struct CYTabContentShift: ViewModifier {
    enum Phase { case entering, settled, leaving }
    let direction: CYTabContentDirection
    let phase: Phase
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        // Forward (a trailing tab) enters from the trailing side and pushes the old content toward the leading side.
        let trailing: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        let sign: CGFloat = (direction.forward ? 1 : -1) * trailing
        let dx: CGFloat
        switch phase {
        case .entering: dx = sign * CYTabsMotion.contentOffset
        case .settled: dx = 0
        case .leaving: dx = -sign * CYTabsMotion.contentOffset
        }
        return content
            .offset(x: dx)
            .opacity(phase == .settled ? 1 : 0)
    }
}
