import SwiftUI

/// Station / station-game picture from `PlayStationImageResolver`. Fixed aspect ratio and
/// fill cropping. The last tier is `CYCoverArt` (the same cover surface as other cards),
/// never a hardcoded dark color, a person placeholder, or an empty gap.
struct PlayStationArtwork: View {
    let image: PlayStationImage
    var title: String = ""
    var aspectRatio: CGFloat = 16.0 / 9.0
    var cornerRadius: CGFloat = 14
    /// False keeps the cover only (a stale play snapshot must not start new loads).
    var loads: Bool = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var url: URL? {
        guard loads, let source = image.source else { return nil }
        return QuestifyCardArtwork.safeURL(PlayStationImageResolver.secured(source))
    }

    var body: some View {
        CYCoverArt(seed: title.isEmpty ? "station" : title, showsDebugLabel: false, cornerRadius: 0)
            .aspectRatio(aspectRatio, contentMode: .fit)
            .overlay {
                if let url {
                    AsyncImage(url: url, transaction: Transaction(animation: reduceMotion ? nil : CYMotion.reduced)) { phase in
                        if let picture = phase.image {
                            picture.resizable().scaledToFill().transition(.opacity)
                        } else { Color.clear }
                    }
                }
            }
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .accessibilityHidden(true)
    }
}
