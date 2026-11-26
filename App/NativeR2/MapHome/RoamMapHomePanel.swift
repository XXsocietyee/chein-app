import SwiftUI

/// The map home's bottom panel (P-034). A system `.sheet` is presented above the `TabView` and hides the
/// tab bar, so the panel lives inside the 漫游 tab, as in Find My: the Apple Maps detents
/// (`RoamMapHomeModel.detents`), a drag indicator, and the map stays interactive above it. The tab bar
/// is never covered and the other tabs stay one tap away.
/// No custom look: system background, system drag-indicator shape, system spring.
@MainActor struct RoamMapHomePanel<Content: View>: View {
    @Binding var detent: PresentationDetent
    /// Height of the tab's safe area (status bar to tab bar).
    let available: CGFloat
    @ViewBuilder let content: () -> Content

    @State private var dragTranslation: CGFloat = 0
    @State private var isDragging = false

    private var restingHeight: CGFloat { RoamMapHomePanelMetrics.height(of: detent, available: available) }
    private var currentHeight: CGFloat {
        let full = RoamMapHomePanelMetrics.height(of: .large, available: available)
        return min(full, max(RoamMapHomePanelMetrics.height(of: RoamMapHomeModel.peek, available: available), restingHeight - dragTranslation))
    }

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: currentHeight, alignment: .top)
        .frame(maxWidth: .infinity)
        .background(.background)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 10, topTrailingRadius: 10, style: .continuous))
        .animation(isDragging ? nil : .snappy, value: detent)
        .accessibilityIdentifier("roam.mapHome.panel")
    }

    /// The sheet grabber: drag between detents; VoiceOver swipes up / down to change the detent.
    private var dragIndicator: some View {
        Capsule()
            .fill(.tertiary)
            .frame(width: 36, height: 5)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 4)
                    .onChanged { value in
                        isDragging = true
                        dragTranslation = value.translation.height
                    }
                    .onEnded { value in
                        let target = restingHeight - value.predictedEndTranslation.height
                        let next = nearestDetent(to: target)
                        isDragging = false
                        withAnimation(.snappy) {
                            dragTranslation = 0
                            detent = next
                        }
                    }
            )
            .accessibilityElement()
            .accessibilityLabel(Text("nativeR2.mapHome.panel.handle"))
            .accessibilityValue(Text(detentValueKey))
            .accessibilityAdjustableAction { direction in
                if direction == .increment { step(by: 1) } else if direction == .decrement { step(by: -1) }
            }
            .accessibilityIdentifier("roam.mapHome.panel.handle")
    }

    private var detentValueKey: LocalizedStringKey {
        if detent == .large { return "nativeR2.mapHome.panel.large" }
        if detent == .medium { return "nativeR2.mapHome.panel.medium" }
        return "nativeR2.mapHome.panel.peek"
    }

    private func nearestDetent(to height: CGFloat) -> PresentationDetent {
        RoamMapHomeModel.detents.min { lhs, rhs in
            abs(RoamMapHomePanelMetrics.height(of: lhs, available: available) - height) < abs(RoamMapHomePanelMetrics.height(of: rhs, available: available) - height)
        } ?? RoamMapHomeModel.peek
    }

    private func step(by offset: Int) {
        let detents = RoamMapHomeModel.detents
        let index = detents.firstIndex(of: detent) ?? 0
        let next = min(detents.count - 1, max(0, index + offset))
        withAnimation(.snappy) { detent = detents[next] }
    }
}

/// Detent heights of `RoamMapHomePanel`, outside the generic type so callers need no `Content`.
@MainActor enum RoamMapHomePanelMetrics {
    /// Height of the panel at `detent` inside `available` points.
    static func height(of detent: PresentationDetent, available: CGFloat) -> CGFloat {
        let full = max(available, RoamMapHomeModel.peekHeight)
        if detent == .large { return full }
        if detent == .medium { return max(RoamMapHomeModel.peekHeight, full * 0.5) }
        return min(RoamMapHomeModel.peekHeight, full)
    }

    /// Bottom inset for the map so its controls and the user location stay above the panel.
    /// Past `.medium` the map no longer moves.
    static func mapInset(detent: PresentationDetent, available: CGFloat) -> CGFloat {
        min(height(of: detent, available: available), height(of: .medium, available: available))
    }
}
