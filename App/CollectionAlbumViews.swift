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

/// `album-head`: the 收集册 title and the segment chips (selected chip solid).
struct CollectionAlbumHead: View {
    let segments: [CollectionAlbumSegment]
    let active: CollectionAlbumSegment
    let select: (CollectionAlbumSegment) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: CYSpacing.md) {
            Text("u10.album.title").font(CYTypography.display).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: CYSpacing.sm) {
                ForEach(segments, id: \.self) { segment in
                    let on = segment == active
                    Button { select(segment) } label: {
                        Text(segment.title).font(CYTypography.label)
                            .foregroundStyle(on ? CYNight.ink0 : CYColor.textPrimary)
                            .padding(.horizontal, CYSpacing.xl).frame(minHeight: 44)
                            .background(on ? Color.white : CYNight.ink0, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(on ? [.isSelected] : [])
                    .accessibilityIdentifier("collection.album.segment.\(segment.rawValue)")
                }
            }
            .accessibilityElement(children: .contain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, CYSpacing.lg).padding(.top, CYSpacing.sm).padding(.bottom, CYSpacing.md)
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        .navigationBarTitleDisplayMode(.inline)
        .cyDomainPageBackground()
        .accessibilityIdentifier("collection.album")
    }
}
