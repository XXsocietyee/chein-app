import SwiftUI

/// Mini-program pages/play/components/playkit-album over album-glass: a full-screen ring of photo
/// cards. The centre card faces you and the neighbours turn on their own vertical axis as they
/// leave. Reduce Motion keeps flat paging. The canvas glass lens with RGB dispersion is not drawn.
@MainActor struct PlayKitAlbumView: View {
    let projection: PlayKitAlbumProjection
    var approvedHosts: Set<String> = []
    /// Photo completion (SUBMIT_ALBUM after an upload). Nil hides the completion button.
    /// Cursor: bind to the photo upload + review path once the album write is wired.
    var complete: (() -> Void)? = nil
    var close: () -> Void
    @State private var current: Int?
    @QuestifyReduceMotion private var reduceMotion

    var body: some View {
        VStack(spacing: CYSpacing.lg) {
            Group { if projection.title.isEmpty { Text("playkit.album.title") } else { Text(verbatim: projection.title) } }
                .cyText(.label).foregroundStyle(CYColor.textPrimary)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("playkit.album.title")
            ring
            let index = current ?? 0
            Text(verbatim: projection.photos.indices.contains(index) ? projection.photos[index].line : " ")
                .cyText(.bodyMedium).foregroundStyle(CYColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("playkit.album.line")
            if !projection.photos.isEmpty {
                Text(verbatim: "\(min(index, projection.photos.count - 1) + 1) / \(projection.photos.count)")
                    .cyText(.meta, monospacedDigit: true).foregroundStyle(CYColor.textTertiary)
                    .accessibilityIdentifier("playkit.album.count")
            }
            if projection.completionEnabled && projection.done {
                Text("playkit.album.locked").cyText(.meta).foregroundStyle(CYColor.textSecondary)
                    .multilineTextAlignment(.center).accessibilityIdentifier("playkit.album.locked")
            }
            if projection.completionEnabled && !projection.done, let complete {
                CYPillButton("playkit.album.complete", action: complete).accessibilityIdentifier("playkit.album.complete")
            }
            CYPillButton("playkit.album.close", style: projection.completionEnabled && !projection.done && complete != nil ? .secondary : .primary,
                         fullWidth: false, action: close)
                .accessibilityIdentifier("playkit.album.close")
        }
        .padding(.vertical, CYSpacing.lg)
        .frame(maxWidth: .infinity)
        .background(CYNight.glow(radius: 180).opacity(0.18).accessibilityHidden(true))
        .accessibilityIdentifier("playkit.album.view")
        .cyDomainScreen(.game)
    }

    @ViewBuilder private var ring: some View {
        if projection.photos.isEmpty {
            RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(CYColor.bgRaised)
                .aspectRatio(420.0 / 620.0, contentMode: .fit).frame(maxHeight: 360)
                .overlay { Image(systemName: "photo.on.rectangle").font(.largeTitle).foregroundStyle(CYColor.textTertiary) }
                .accessibilityHidden(true)
        } else {
            // Captured as a value: the scroll transition closure is Sendable.
            let flat = reduceMotion
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 0) {
                    ForEach(projection.photos) { photo in
                        card(photo)
                            .containerRelativeFrame(.horizontal, count: 5, span: 3, spacing: 0)
                            .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                content
                                    .rotation3DEffect(.degrees(flat ? 0 : phase.value * -55), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
                                    .scaleEffect(flat ? 1 : 1 - abs(phase.value) * 0.12)
                                    .opacity(1 - abs(phase.value) * 0.35)
                            }
                            .id(photo.id)
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, 0, for: .scrollContent)
            .safeAreaPadding(.horizontal, 64)
            .scrollTargetBehavior(.viewAligned)
            .scrollPosition(id: $current)
            .frame(height: 380)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(Text("playkit.album.carousel"))
            .accessibilityAdjustableAction { direction in
                let index = current ?? 0
                switch direction {
                case .increment: current = min(projection.photos.count - 1, index + 1)
                case .decrement: current = max(0, index - 1)
                @unknown default: break
                }
            }
            .accessibilityIdentifier("playkit.album.ring")
        }
    }

    private func card(_ photo: PlayKitAlbumProjection.Photo) -> some View {
        ZStack {
            // native-r3-b: system secondary background; the custom drop shadow is gone (the 3-D scroll transition separates cards).
            RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous).fill(.background.secondary)
            PlayKitArtwork(source: photo.url, approvedHosts: approvedHosts)
        }
        .aspectRatio(420.0 / 620.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: CYRadius.lg, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(photo.line.isEmpty ? Text("playkit.image") : Text(verbatim: photo.line))
    }
}
