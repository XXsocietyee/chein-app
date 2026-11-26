import SwiftUI
import UIKit

/// The island itself: a black capsule anchored on the safe-area top. On Dynamic Island iPhones it grows out of the
/// hardware island; elsewhere it drops from under the status bar. Compact (icon + one line) morphs into the expanded
/// card (title, subtitle, up to two actions) with one spring. Reduce Motion: fade only.
@MainActor struct IslandOverlay: View {
    let center: IslandCenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale
    @State private var dragOffset: CGFloat = 0

    /// Spec M4 morph spring.
    static let spring = Animation.spring(response: 0.42, dampingFraction: 0.78)

    var body: some View {
        GeometryReader { proxy in
            let hasIsland = proxy.safeAreaInsets.top >= 51
            ZStack(alignment: .top) {
                if let item = center.current {
                    IslandCard(item: item, expanded: center.isExpanded, reduceMotion: reduceMotion,
                               center: center)
                        .frame(maxWidth: center.isExpanded ? 420 : 360)
                        .padding(.horizontal, center.isExpanded ? 8 : 12)
                        .offset(y: dragOffset)
                        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { center.interactiveFrame = $0 }
                        .gesture(drag)
                        .transition(entrance(hasIsland: hasIsland))
                        .id(item.id)
                }
            }
            .frame(maxWidth: .infinity)
            // Dynamic Island iPhones: the hardware island's top edge (11 pt); others: just under the status bar.
            .padding(.top, hasIsland ? 11 : max(proxy.safeAreaInsets.top, 20) + 4)
            .ignoresSafeArea(edges: .top)
        }
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Self.spring, value: center.current?.id)
        .animation(reduceMotion ? .easeInOut(duration: 0.2) : Self.spring, value: center.isExpanded)
        .sensoryFeedback(.impact(weight: .light), trigger: center.presentationCount)
        .onChange(of: center.presentationCount) { _, _ in announce() }
    }

    private func entrance(hasIsland: Bool) -> AnyTransition {
        if reduceMotion { return .opacity }
        if hasIsland {
            // Grows out of the hardware island: starts at its size at the top centre and springs open.
            return .scale(scale: 0.35, anchor: .top).combined(with: .opacity)
        }
        return .move(edge: .top).combined(with: .opacity)
    }

    /// Swipe up dismisses (the island follows the finger); a pull down rubber-bands and expands.
    private var drag: some Gesture {
        DragGesture(minimumDistance: 6)
            .onChanged { value in
                center.setInteracting(true)
                let y = value.translation.height
                dragOffset = y < 0 ? y : 18 * log1p(y / 18)
            }
            .onEnded { value in
                let y = value.translation.height
                let predicted = value.predictedEndTranslation.height
                withAnimation(reduceMotion ? .easeInOut(duration: 0.2) : Self.spring) {
                    if y < -28 || predicted < -90 {
                        center.dismiss()
                    } else if y > 20 {
                        center.expand()
                    }
                    dragOffset = 0
                }
                center.setInteracting(false)
            }
    }

    private func announce() {
        guard let item = center.current else { return }
        let kind = appLocalized(String.LocalizationValue(stringLiteral: item.kind.accessibilityKindKey), locale: locale)
        let parts = [kind, item.title.resolved(locale: locale), item.subtitle?.resolved(locale: locale)].compactMap { $0 }
        AccessibilityNotification.Announcement(parts.joined(separator: ", ")).post()
    }
}

/// Compact capsule and expanded card share one container so the shape and size morph together.
@MainActor private struct IslandCard: View {
    let item: IslandItem
    let expanded: Bool
    let reduceMotion: Bool
    let center: IslandCenter

    private var content: AnyTransition { reduceMotion ? .opacity : AnyTransition(.blurReplace) }

    var body: some View {
        Group {
            if expanded { expandedBody.transition(content) } else { compactBody.transition(content) }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: expanded ? .infinity : nil)
        .background(Color.black, in: RoundedRectangle(cornerRadius: expanded ? 32 : 22, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: expanded ? 32 : 22, style: .continuous))
        .onTapGesture { center.tap() }
        .environment(\.colorScheme, .dark)
        .accessibilityElement(children: expanded ? .contain : .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
        .accessibilityHint(Text(expanded ? "island.a11y.hint.expanded" : "island.a11y.hint.compact"))
        .accessibilityAction { center.tap() }
        .accessibilityAction(named: Text("island.dismiss")) { center.dismiss() }
        .accessibilityAction(.escape) { center.dismiss() }
        .accessibilityActions {
            ForEach(item.actions.prefix(2)) { action in
                Button { center.perform(action) } label: { action.title.text }
            }
        }
        .accessibilityIdentifier("island.card")
    }

    private var accessibilityLabel: Text {
        var label = Text(LocalizedStringKey(item.kind.accessibilityKindKey)) + Text(verbatim: ", ") + item.title.text
        if let subtitle = item.subtitle { label = label + Text(verbatim: ", ") + subtitle.text }
        return label
    }

    // MARK: Compact: icon + one line, 37 pt tall at rest.

    private var compactBody: some View {
        HStack(spacing: 8) {
            icon(size: 22)
            item.title.text
                .font(.subheadline.weight(.semibold))
                .lineLimit(1)
            if let media = item.media { mediaTrailing(media) }
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 37)
        .padding(.vertical, 3)
    }

    // MARK: Expanded: artwork, title, subtitle, up to two actions.

    private var expandedBody: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                icon(size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    item.title.text
                        .font(.headline)
                        .lineLimit(2)
                    if let subtitle = item.subtitle {
                        subtitle.text
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(item.kind == .hint ? 6 : 3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if let media = item.media { mediaTrailing(media) }
            }
            if !rowActions.isEmpty {
                HStack(spacing: 8) {
                    ForEach(rowActions) { action in actionButton(action) }
                }
            }
        }
        .padding(16)
    }

    /// Media keeps play / pause next to the artwork; the row shows the rest (at most two).
    private var rowActions: [IslandAction] {
        Array(item.actions.filter { item.media == nil || !$0.keepsIsland }.prefix(2))
    }

    @ViewBuilder private func actionButton(_ action: IslandAction) -> some View {
        let label = Group {
            if let symbol = action.systemImage {
                Label { action.title.text } icon: { Image(systemName: symbol) }
            } else {
                action.title.text
            }
        }
        .frame(maxWidth: .infinity)
        if action.prominent {
            Button(role: action.role) { center.perform(action) } label: { label }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .accessibilityIdentifier("island.action.prominent")
        } else {
            Button(role: action.role) { center.perform(action) } label: { label }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.large)
                .accessibilityIdentifier("island.action.secondary")
        }
    }

    @ViewBuilder private func icon(size: CGFloat) -> some View {
        let playing = item.media?.isPlaying == true
        ZStack {
            if size > 30 {
                Circle().fill(item.kind.tint.opacity(0.22))
            }
            Image(systemName: item.symbol)
                .font(size > 30 ? .title3 : .subheadline)
                .foregroundStyle(item.kind.tint)
                .symbolEffect(.variableColor.iterative, isActive: playing && !reduceMotion)
                .symbolEffect(.bounce, value: reduceMotion ? 0 : center.presentationCount)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }

    /// Media: elapsed time while playing, and the play / pause action as a round button.
    @ViewBuilder private func mediaTrailing(_ media: IslandMedia) -> some View {
        if media.isPlaying, let since = media.playingSince {
            Text(timerInterval: since...since.addingTimeInterval(24 * 60 * 60), countsDown: false)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(maxWidth: 52)
        }
        if let toggle = item.actions.first(where: { $0.keepsIsland }) {
            Button { center.perform(toggle) } label: {
                Image(systemName: media.isPlaying ? "pause.fill" : "play.fill")
                    .font(.body)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(toggle.title.text)
            .accessibilityIdentifier("island.media.toggle")
        }
    }
}
