import ImageIO
import SwiftUI
import UIKit

/// List artwork for the home, discover, and club feeds.
/// Uses the existing bounded loader and the existing byte cache. Full-size bitmaps are not stored.
enum PlayerFeedImages {
    static let store = CYCachedAsyncImageStore(capacity: 64)

    @MainActor
    static func image(for url: URL, maxPixel: Int) async -> UIImage? {
        let key = "\(maxPixel)|\(url.absoluteString)"
        if let cached = store.peek(key) {
            store.touch(key)
            return UIImage(data: cached)
        }
        guard let origin = ObjectCardMediaPolicy.origin(url.absoluteString) else { return nil }
        let thumb: Data
        do {
            thumb = try await store.coalesce(key) {
                let loader = ObjectCardBoundedImageLoader(policy: .init(approvedOrigins: [origin]))
                let bytes = try await loader.image(url: url.absoluteString)
                guard let thumb = try await PlayerFeedJSON.perform({ thumbnailJPEG(bytes, maxPixel: maxPixel) }) else {
                    throw CYCachedAsyncImageFailure.unavailable
                }
                return thumb
            }
        } catch {
            return nil
        }
        if Task.isCancelled { return store.peek(key).flatMap { UIImage(data: $0) } }
        guard store.insert(thumb, for: key) else { return nil }
        return UIImage(data: thumb)
    }
}

private func thumbnailJPEG(_ data: Data, maxPixel: Int) -> Data? {
    let side = max(1, maxPixel)
    guard let source = CGImageSourceCreateWithData(data as CFData, [kCGImageSourceShouldCache: false] as CFDictionary) else { return nil }
    let options: [CFString: Any] = [
        kCGImageSourceCreateThumbnailFromImageAlways: true,
        kCGImageSourceCreateThumbnailWithTransform: true,
        kCGImageSourceThumbnailMaxPixelSize: side,
        kCGImageSourceShouldCacheImmediately: true
    ]
    guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
    let out = NSMutableData()
    guard let dest = CGImageDestinationCreateWithData(out, "public.jpeg" as CFString, 1, nil) else { return nil }
    CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary)
    guard CGImageDestinationFinalize(dest) else { return nil }
    return out as Data
}

/// Placeholder while the existing loader runs, then the cached thumbnail, or the failure view.
struct PlayerFeedRemoteImage<Placeholder: View, Failure: View>: View {
    let url: URL
    var maxPixel: Int
    @ViewBuilder var placeholder: () -> Placeholder
    @ViewBuilder var failure: () -> Failure
    @State private var phase: Phase = .waiting

    private enum Phase {
        case waiting
        case ready(UIImage)
        case failed
    }

    var body: some View {
        Group {
            switch phase {
            case .waiting:
                placeholder()
            case .failed:
                failure()
            case .ready(let image):
                Image(uiImage: image).resizable().scaledToFill().accessibilityLabel(Text("media.destination.image"))
            }
        }
        .task(id: url) {
            phase = .waiting
            guard let image = await PlayerFeedImages.image(for: url, maxPixel: maxPixel) else {
                if !Task.isCancelled { phase = .failed }
                return
            }
            if !Task.isCancelled { phase = .ready(image) }
        }
    }
}
