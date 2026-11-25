import ImageIO
import SwiftUI
import UIKit

/// BWALL-2 (MP badge-wall wxml:48-58 `<image src="{{item.image}}">`): the server badge art, read only through the
/// bounded `ObjectCardImageLoading` (exact origins, size and redirect limits; no `AsyncImage` bypass).
/// The MP default `badge-demo.png` is the placeholder and the fallback. A locked badge is drawn desaturated.
@MainActor struct ObjectBadgeTileArtwork: View {
    let url: String
    let locked: Bool
    @Environment(\.objectCardMedia) private var media
    @State private var image: UIImage?
    @State private var loadedURL: String?

    var body: some View {
        Group {
            if let image, loadedURL == url {
                Image(uiImage: image).resizable().scaledToFit()
            } else {
                MPAsset.BadgeMedal.badgeDemo.resizable().scaledToFit()
            }
        }
        .saturation(locked ? 0 : 1)
        .opacity(locked ? 0.55 : 1)
        .accessibilityHidden(true)
        .task(id: url) { await load() }
    }

    private func load() async {
        let requested = url
        image = nil; loadedURL = nil
        guard let media, !requested.isEmpty, URL(string: requested)?.scheme == "https" else { return }
        do {
            let data = try await media.image(url: requested)
            try Task.checkCancellation()
            guard data.count <= ObjectCardMediaPolicy.maximumBytes,
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
                  let width = properties[kCGImagePropertyPixelWidth] as? NSNumber,
                  let height = properties[kCGImagePropertyPixelHeight] as? NSNumber,
                  width.doubleValue * height.doubleValue <= 16_000_000,
                  let decoded = UIImage(data: data), requested == url else { return }
            image = decoded; loadedURL = requested
        } catch {
            // Cancelled, refused by the media policy or failed: keep the MP default art.
        }
    }
}
