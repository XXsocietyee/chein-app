import SwiftUI
import CoreGraphics

// Roam fog spec stage 2 (§1b): a Canvas scrim with the explored area cut out by an alpha mask. Pure draw: no state,
// no location, no network. The mask (Core `FogMask`) is rebuilt by `FogMaskCache` only when the bitmap, the window or the
// level of detail changes; a camera tick only moves `windowRect`.

// MARK: - Scrim colour

/// Fog scrim colour. `token` is the style manifest's `fogOverlay` (candidate: grey at 0.35, both appearances).
struct FogScrimStyle: Equatable {
    let red, green, blue, opacity: Double

    static func token(_ appearance: MapAppearance, manifest: MapVisualStyleManifest = .candidate) -> FogScrimStyle {
        let c = manifest.color(.fogOverlay, appearance)
        return FogScrimStyle(red: c.red, green: c.green, blue: c.blue, opacity: c.opacity)
    }
    var color: Color { Color(red: red, green: green, blue: blue).opacity(opacity) }

    #if DEBUG
    /// Deep blue-black scrim for the DEBUG fixtures: the 0.35 grey token is nearly invisible on the dark backdrop.
    static let darkFixture = FogScrimStyle(red: 0.03, green: 0.04, blue: 0.08, opacity: 0.78)
    #endif
}

// MARK: - Mask images

/// CGImages derived once per mask (never per frame). `cutout` carries the explored alpha for `destinationOut`;
/// `pendingBand` marks the pending-only plateau (alpha 128) so the hatch pass can be clipped to it at draw time.
struct FogMaskImages {
    let cutout: CGImage
    let pendingBand: CGImage?

    static let pendingBandRange: ClosedRange<UInt8> = 120...136

    /// nil for an empty mask (summary level of detail or no window).
    static func make(_ mask: FogMask) -> FogMaskImages? {
        guard mask.width > 0, mask.height > 0, mask.alpha.count == mask.width * mask.height,
              let cutout = image(mask.alpha, w: mask.width, h: mask.height, interpolate: true) else { return nil }
        let band = mask.alpha.map { pendingBandRange.contains($0) ? UInt8(255) : UInt8(0) }
        let pending = band.contains(255) ? image(band, w: mask.width, h: mask.height, interpolate: true) : nil
        return FogMaskImages(cutout: cutout, pendingBand: pending)
    }

    /// Premultiplied black: only alpha carries data.
    private static func image(_ alpha: [UInt8], w: Int, h: Int, interpolate: Bool) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) { rgba[i * 4 + 3] = alpha[i] }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: interpolate, intent: .defaultIntent)
    }
}

// MARK: - Geometry (flat, north-up camera: screen space is an affine image of Web Mercator)

enum FogWindowGeometry {
    static func latitude(y: Double) -> Double { atan(sinh(y / FogMercatorWindow.earthRadius)) * 180 / .pi }
    static func longitude(x: Double) -> Double { x / FogMercatorWindow.earthRadius * 180 / .pi }

    /// The visible window from the basemap coordinates under the north-west and south-east screen corners (two
    /// `MapProxy.convert` calls). `metersPerPixel` is ground meters per point at the window centre.
    static func viewport(northWest: RoamCoordinate, southEast: RoamCoordinate, pointSize: CGSize) -> FogMercatorWindow? {
        guard pointSize.width > 0, pointSize.height > 0 else { return nil }
        let minX = FogMercatorWindow.x(longitude: northWest.longitude), maxX = FogMercatorWindow.x(longitude: southEast.longitude)
        let maxY = FogMercatorWindow.y(latitude: northWest.latitude), minY = FogMercatorWindow.y(latitude: southEast.latitude)
        guard maxX > minX, maxY > minY else { return nil }
        let centerLatitude = (northWest.latitude + southEast.latitude) / 2
        let ground = (maxX - minX) / Double(pointSize.width) * cos(centerLatitude * .pi / 180)
        return FogMercatorWindow(minX: minX, minY: minY, maxX: maxX, maxY: maxY, metersPerPixel: ground)
    }

    /// Viewport centred on a coordinate at a ground scale; the fixtures and the pixel tests use it.
    static func viewport(center: RoamCoordinate, pointSize: CGSize, groundMetersPerPoint: Double) -> FogMercatorWindow {
        let merc = groundMetersPerPoint / max(cos(center.latitude * .pi / 180), 0.01)
        let cx = FogMercatorWindow.x(longitude: center.longitude), cy = FogMercatorWindow.y(latitude: center.latitude)
        let halfW = Double(pointSize.width) / 2 * merc, halfH = Double(pointSize.height) / 2 * merc
        return FogMercatorWindow(minX: cx - halfW, minY: cy - halfH, maxX: cx + halfW, maxY: cy + halfH, metersPerPixel: groundMetersPerPoint)
    }

    /// Where a mercator window lands on screen when `viewport` fills `pointSize` (y flips: row 0 is north).
    static func rect(of window: FogMercatorWindow, in viewport: FogMercatorWindow, pointSize: CGSize) -> CGRect {
        guard viewport.width > 0, viewport.height > 0 else { return .zero }
        let sx = Double(pointSize.width) / viewport.width, sy = Double(pointSize.height) / viewport.height
        return CGRect(x: (window.minX - viewport.minX) * sx, y: (viewport.maxY - window.maxY) * sy,
                      width: window.width * sx, height: window.height * sy)
    }

    static func point(latitude: Double, longitude: Double, in viewport: FogMercatorWindow, pointSize: CGSize) -> CGPoint {
        let sx = Double(pointSize.width) / viewport.width, sy = Double(pointSize.height) / viewport.height
        return CGPoint(x: (FogMercatorWindow.x(longitude: longitude) - viewport.minX) * sx,
                       y: (viewport.maxY - FogMercatorWindow.y(latitude: latitude)) * sy)
    }

    /// Screen rect of a geohash cell.
    static func rect(of cell: FogRenderCell, in viewport: FogMercatorWindow, pointSize: CGSize) -> CGRect {
        let r = FogMercatorWindow.rect(south: cell.south, west: cell.west, north: cell.north, east: cell.east)
        return rect(of: FogMercatorWindow(minX: r.minX, minY: r.minY, maxX: r.maxX, maxY: r.maxY, metersPerPixel: viewport.metersPerPixel),
                    in: viewport, pointSize: pointSize)
    }
}

// MARK: - Rebuild gate

/// Holds the current mask and its images. `resolve` rebuilds only when the bitmap revision changed, the viewport left the
/// rasterized window (the 25 % margin is used up), the level of detail changed (with hysteresis), or the power
/// constraint flipped. Reference type on purpose: reading it from a view body must not publish state.
@MainActor final class FogMaskCache {
    private(set) var mask: FogMask?
    private(set) var images: FogMaskImages?
    private(set) var rebuildCount = 0
    private var constrained = false

    func resolve(confirmed: FogCellBitmap, pending: FogCellBitmap, revision: Int, viewport: FogMercatorWindow,
                 constrained: Bool) -> (mask: FogMask, images: FogMaskImages?) {
        if let mask, !FogMaskRasterizer.needsRebuild(current: mask, viewport: viewport, bitmapRevision: revision), constrained == self.constrained {
            return (mask, images)
        }
        let cellPixels = FogLevelOfDetail.cellPixels(metersPerPixel: viewport.metersPerPixel)
        let lod = mask.map { FogLevelOfDetail.resolve(cellPixels: cellPixels, previous: $0.lod) } ?? FogLevelOfDetail.resolve(cellPixels: cellPixels)
        // Low Power or thermal pressure: skip the softening pass.
        let rebuilt = FogMaskRasterizer.rasterize(confirmed: confirmed, pending: pending,
                                                  window: viewport.expanded(by: FogMaskRasterizer.margin), lod: lod,
                                                  soften: !constrained, revision: revision)
        mask = rebuilt; images = FogMaskImages.make(rebuilt); self.constrained = constrained
        rebuildCount += 1
        return (rebuilt, images)
    }
}

// MARK: - Layer

/// One in-flight radial wipe in screen points.
struct FogWipeDraw: Equatable {
    let cellRect: CGRect
    let center: CGPoint
    let start: TimeInterval
    let duration: TimeInterval
}

/// Scrim over the basemap with the explored area cut out (`destinationOut`), a hatch over unconfirmed cells (state is never
/// colour-only), and a soft roll-off. Ticks only while wipes are in flight. Hidden from accessibility and hit testing.
struct FogOverlayLayer: View {
    let mask: FogMask
    let images: FogMaskImages?
    /// Where `mask.window` lands in this view's coordinate space.
    let windowRect: CGRect
    var style: FogScrimStyle
    var wipes: [FogWipeDraw] = []
    /// Blur radius (points) applied to the cut-out for the cloud-like edge; 0 under Low Power.
    var softEdgeRadius: CGFloat = 3
    var clock: () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }

    init(mask: FogMask, images: FogMaskImages?, windowRect: CGRect, appearance: MapAppearance,
         manifest: MapVisualStyleManifest = .candidate, wipes: [FogWipeDraw] = [], softEdgeRadius: CGFloat = 3,
         clock: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
        self.init(mask: mask, images: images, windowRect: windowRect, style: .token(appearance, manifest: manifest),
                  wipes: wipes, softEdgeRadius: softEdgeRadius, clock: clock)
    }

    init(mask: FogMask, images: FogMaskImages?, windowRect: CGRect, style: FogScrimStyle, wipes: [FogWipeDraw] = [],
         softEdgeRadius: CGFloat = 3, clock: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
        self.mask = mask; self.images = images; self.windowRect = windowRect; self.style = style
        self.wipes = wipes; self.softEdgeRadius = softEdgeRadius; self.clock = clock
    }

    var body: some View {
        Group {
            if wipes.isEmpty {
                canvas(now: 0)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { _ in canvas(now: clock()) }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .accessibilityIdentifier("roam.fog.layer")
    }

    private func canvas(now: TimeInterval) -> some View {
        Canvas(opaque: false, rendersAsynchronously: false) { ctx, size in
            let full = CGRect(origin: .zero, size: size)
            ctx.drawLayer { layer in
                layer.fill(Path(full), with: .color(style.color))
                layer.blendMode = .destinationOut
                if let cutout = images?.cutout {
                    var cut = layer
                    if softEdgeRadius > 0 { cut.addFilter(.blur(radius: softEdgeRadius)) }
                    cut.draw(layer.resolve(Image(decorative: cutout, scale: 1)), in: windowRect)
                }
                for wipe in wipes {
                    let p = RevealChoreographer.progress(start: wipe.start, duration: wipe.duration, at: now)
                    guard p > 0 else { continue }
                    let r = hypot(wipe.cellRect.width, wipe.cellRect.height) * CGFloat(p) * 1.6
                    var inner = layer
                    inner.clip(to: Path(wipe.cellRect))
                    inner.fill(Path(ellipseIn: CGRect(x: wipe.center.x - r, y: wipe.center.y - r, width: r * 2, height: r * 2)),
                               with: .radialGradient(Gradient(colors: [.black, .black, .black.opacity(0)]),
                                                     center: wipe.center, startRadius: 0, endRadius: max(r, 1)))
                }
            }
            if let band = images?.pendingBand {
                ctx.drawLayer { layer in
                    var hatch = Path()
                    var x = -size.height
                    while x < size.width {
                        hatch.move(to: CGPoint(x: x, y: size.height)); hatch.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 6
                    }
                    layer.stroke(hatch, with: .color(Color.white.opacity(0.35)), lineWidth: 1)
                    layer.blendMode = .destinationIn
                    layer.draw(layer.resolve(Image(decorative: band, scale: 1)), in: windowRect)
                }
            }
        }
    }
}
