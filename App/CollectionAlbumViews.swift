import SwiftUI

/// B62 收集册 (owner P-3, 2026-10-30): 勋章 / 邮票 / 藏品 are three segments of one book. The mini-program keeps three
/// routes and swaps them in place (`redirectTo`, no stack growth); here one screen swaps the segment in place, sliding in
/// from the side it was picked on (a cross-fade under Reduce Motion). A segment without a destination has no chip.
enum CollectionAlbumSegment: String, CaseIterable, Hashable {
    case medal, stamp, object
    var title: LocalizedStringKey {
        switch self {
        case .medal: return "u10.album.medal"
        case .stamp: return "u10.album.stamp"
        case .object: return "u10.album.object"
        }
    }
}

private struct CollectionAlbumHostedKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    /// True inside 收集册: segment screens drop their own cover/title and use the mini-program segment look.
    var collectionAlbumHosted: Bool {
        get { self[CollectionAlbumHostedKey.self] }
        set { self[CollectionAlbumHostedKey.self] = newValue }
    }
}

/// A 收集册 segment screen sets its own inline title only when opened on its own; inside 收集册 the album's
/// 收集册 title is the one title on screen.
private struct CollectionAlbumChildTitle: ViewModifier {
    let key: String.LocalizationValue
    @Environment(\.collectionAlbumHosted) private var hosted
    func body(content: Content) -> some View {
        if hosted { content } else { content.cyPageTitle(key) }
    }
}
extension View {
    func cyAlbumChildTitle(_ key: String.LocalizationValue) -> some View { modifier(CollectionAlbumChildTitle(key: key)) }
}

/// `album-head`: the 勋章 / 邮票 / 藏品 segments as the system segmented control (owner rule 2: one control for
/// in-page tabs; a menu when a long English title or an accessibility text size would truncate a segment). The page
/// title 收集册 is the system inline title (type-and-chrome §2: a pushed page draws no second title in its content).
struct CollectionAlbumHead: View {
    let segments: [CollectionAlbumSegment]
    let active: CollectionAlbumSegment
    let select: (CollectionAlbumSegment) -> Void
    var body: some View {
        Picker(selection: Binding(get: { active }, set: { select($0) })) {
            ForEach(segments, id: \.self) { segment in
                Text(segment.title)
                    .tag(segment)
                    .accessibilityIdentifier("collection.album.segment.\(segment.rawValue)")
            }
        } label: {
            Text(active.title)
        }
        .cyAdaptiveSegmented()
        .labelsHidden()
        .sensoryFeedback(.selection, trigger: active)
        .padding(.horizontal, CYSpacing.pageHorizontal)
        .padding(.top, CYSpacing.sm).padding(.bottom, CYSpacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityIdentifier("collection.album.head")
    }
}

@MainActor struct CollectionAlbumView: View {
    var medal: (() -> AnyView)?
    var stamp: (() -> AnyView)?
    /// Binding stub for 藏品 (object cards). nil hides the chip until the host wires `SessionObjectCardsView`.
    var object: (() -> AnyView)?
    @State private var active: CollectionAlbumSegment
    @State private var forward = true
    @QuestifyReduceMotion private var reduceMotion

    init(initial: CollectionAlbumSegment, medal: (() -> AnyView)? = nil, stamp: (() -> AnyView)? = nil, object: (() -> AnyView)? = nil) {
        self.medal = medal; self.stamp = stamp; self.object = object
        _active = State(initialValue: initial)
    }
    private var segments: [CollectionAlbumSegment] {
        CollectionAlbumSegment.allCases.filter { destination($0) != nil }
    }
    private func destination(_ segment: CollectionAlbumSegment) -> (() -> AnyView)? {
        switch segment {
        case .medal: return medal
        case .stamp: return stamp
        case .object: return object
        }
    }
    var body: some View {
        VStack(spacing: 0) {
            CollectionAlbumHead(segments: segments, active: active) { picked in
                guard picked != active else { return }
                let order = CollectionAlbumSegment.allCases
                forward = (order.firstIndex(of: picked) ?? 0) > (order.firstIndex(of: active) ?? 0)
                if reduceMotion { active = picked } else { withAnimation(CYMotion.standard) { active = picked } }
            }
            ZStack {
                if let content = destination(active) {
                    content()
                        .environment(\.collectionAlbumHosted, true)
                        .id(active)
                        .transition(reduceMotion ? .opacity : .asymmetric(
                            insertion: .move(edge: forward ? .trailing : .leading).combined(with: .opacity),
                            removal: .opacity))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
        }
        .sensoryFeedback(.selection, trigger: active)
        .navigationTitle(Text("u10.album.title"))
        .navigationBarTitleDisplayMode(.inline)
        .cyDomainPageBackground()
        .accessibilityIdentifier("collection.album")
    }
}
