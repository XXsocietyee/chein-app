import SwiftUI
import CoreGraphics

// Roam fog spec stage 2 (§1b): a Canvas scrim with the explored area cut out by an alpha mask. Pure draw: no state,
// no location, no network. The mask (Core `FogMask`) is rebuilt by `FogMaskCache` only when the bitmap, the window or the
// level of detail changes; a camera tick only moves `windowRect`.

// MARK: - Scrim colour

/// Fog scrim colour and finish. `token` is the style manifest's `fogOverlay` (candidate: grey at 0.35, both appearances,
/// plain). `reveal` is the visible-fog look: a desaturated haze at ~0.62 with soft noise, a vignette toward the screen
/// edges, a warm glow on the frontier and a shimmering dashed outline on unconfirmed ground. The night haze is a lighter
/// slate and the day haze a darker one, so the cleared ground reads against both a dark and a light basemap.
struct FogScrimStyle: Equatable {
    let red, green, blue, opacity: Double
    /// Soft noise blobs over the scrim.
    var texture = false
    /// Extra darkening toward the screen edges (0 = none; opacity of black at the corners).
    var vignette = 0.0
    /// Warm ring on the frontier of confirmed ground.
    var frontierGlow = false

    static func token(_ appearance: MapAppearance, manifest: MapVisualStyleManifest = .candidate) -> FogScrimStyle {
        let c = manifest.color(.fogOverlay, appearance)
        return FogScrimStyle(red: c.red, green: c.green, blue: c.blue, opacity: c.opacity)
    }
    static func reveal(_ appearance: MapAppearance) -> FogScrimStyle {
        switch appearance {
        case .day: return FogScrimStyle(red: 0.17, green: 0.19, blue: 0.24, opacity: 0.62, texture: true, vignette: 0.30, frontierGlow: true)
        case .night: return FogScrimStyle(red: 0.36, green: 0.39, blue: 0.47, opacity: 0.62, texture: true, vignette: 0.34, frontierGlow: true)
        }
    }
    /// Same colour and opacity with no texture, vignette or glow: flat, for exact pixel assertions.
    var plain: FogScrimStyle { FogScrimStyle(red: red, green: green, blue: blue, opacity: opacity) }
    var color: Color { Color(red: red, green: green, blue: blue).opacity(opacity) }
}

// MARK: - Feathering

/// Union of rounded blobs: blur the binary explored field, then stretch it through a smoothstep. A single cell becomes a
/// soft disc-like blob, neighbours merge into one organic region, and the interior stays fully clear.
enum FogFeather {
    static let low: Float = 0.18, high: Float = 0.62

    /// Three box passes per axis (close to a Gaussian). Outside the buffer counts as unexplored.
    static func blur(_ field: [Float], w: Int, h: Int, radius: Int) -> [Float] {
        guard radius > 0, w > 0, h > 0 else { return field }
        var a = field, b = field
        for _ in 0..<3 {
            boxRows(a, &b, w: w, h: h, r: radius)
            boxColumns(b, &a, w: w, h: h, r: radius)
        }
        return a
    }
    private static func boxRows(_ src: [Float], _ dst: inout [Float], w: Int, h: Int, r: Int) {
        let norm = 1 / Float(2 * r + 1)
        for y in 0..<h {
            let row = y * w
            var sum: Float = 0
            for x in 0..<min(r, w) { sum += src[row + x] }
            for x in 0..<w {
                if x + r < w { sum += src[row + x + r] }
                if x - r - 1 >= 0 { sum -= src[row + x - r - 1] }
                dst[row + x] = sum * norm
            }
        }
    }
    private static func boxColumns(_ src: [Float], _ dst: inout [Float], w: Int, h: Int, r: Int) {
        let norm = 1 / Float(2 * r + 1)
        for x in 0..<w {
            var sum: Float = 0
            for y in 0..<min(r, h) { sum += src[y * w + x] }
            for y in 0..<h {
                if y + r < h { sum += src[(y + r) * w + x] }
                if y - r - 1 >= 0 { sum -= src[(y - r - 1) * w + x] }
                dst[y * w + x] = sum * norm
            }
        }
    }
    static func smooth(_ v: Float) -> Float {
        let t = min(max((v - low) / (high - low), 0), 1)
        return t * t * (3 - 2 * t)
    }
    /// 0 inside and outside, 1 at the middle of the roll-off; squared so the ring is thin.
    static func ring(_ clear: Float) -> Float { let r = 4 * clear * (1 - clear); return r * r }
    /// Frontier rim: a very thin core (about a third of the roll-off, ~2-3 pt).
    static func rim(_ clear: Float) -> Float { let r = 4 * clear * (1 - clear); return pow(r, 6) }
    /// Frontier bloom: the whole roll-off, drawn at low opacity so the rim fades with distance.
    static func bloom(_ clear: Float) -> Float { 4 * clear * (1 - clear) }
}

// MARK: - Mask images

/// CGImages derived once per mask (never per frame), all premultiplied black so only alpha carries data.
/// `cutout`: feathered explored ground (confirmed plus pending) for `destinationOut`. `glow`: thin rim on the confirmed
/// frontier; `bloom`: the wide soft halo around it. `pendingRing`: ring around unconfirmed-only ground, drawn dashed.
struct FogMaskImages {
    let cutout: CGImage
    let glow: CGImage?
    let bloom: CGImage?
    let pendingRing: CGImage?

    /// Pixels of feather radius per geohash-7 cell width (a cell is ~152.8 mercator meters wide at every latitude).
    static let featherPerCell = 0.38
    static let cellMercatorMeters = 152.8

    /// nil for an empty mask (summary level of detail or no window).
    static func make(_ mask: FogMask) -> FogMaskImages? {
        let w = mask.width, h = mask.height
        guard w > 0, h > 0, mask.alpha.count == w * h else { return nil }
        let n = w * h
        var confirmed = [Float](repeating: 0, count: n), pending = confirmed
        for i in 0..<n {
            let a = mask.alpha[i]
            if mask.lod == .cell6 { confirmed[i] = Float(a) / 255 }
            else if a >= 200 { confirmed[i] = 1 }
            else if (100...160).contains(a) { pending[i] = 1 }
        }
        let cellPx = cellMercatorMeters * Double(w) / max(mask.window.width, 1)
        let radius = max(1, Int((cellPx * featherPerCell).rounded()))
        let c = FogFeather.blur(confirmed, w: w, h: h, radius: radius).map(FogFeather.smooth)
        var union = confirmed
        for i in 0..<n { union[i] = max(confirmed[i], pending[i]) }
        let u = FogFeather.blur(union, w: w, h: h, radius: radius).map(FogFeather.smooth)
        guard let cutout = image(u.map { UInt8(min(max($0, 0), 1) * 255) }, w: w, h: h) else { return nil }
        let glow = image((0..<n).map { UInt8(FogFeather.rim(c[$0]) * 255) }, w: w, h: h)
        let bloom = image((0..<n).map { UInt8(FogFeather.bloom(c[$0]) * 255) }, w: w, h: h)
        var ring: CGImage?
        if pending.contains(1) {
            let p = FogFeather.blur(pending, w: w, h: h, radius: radius).map(FogFeather.smooth)
            ring = image((0..<n).map { UInt8(FogFeather.ring(p[$0]) * (1 - c[$0]) * 255) }, w: w, h: h)
        }
        return FogMaskImages(cutout: cutout, glow: glow, bloom: bloom, pendingRing: ring)
    }

    private static func image(_ alpha: [UInt8], w: Int, h: Int) -> CGImage? {
        var rgba = [UInt8](repeating: 0, count: w * h * 4)
        for i in 0..<(w * h) { rgba[i * 4 + 3] = alpha[i] }
        guard let provider = CGDataProvider(data: Data(rgba) as CFData) else { return nil }
        return CGImage(width: w, height: h, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: w * 4,
                       space: CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
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
        // Feathering happens in `FogMaskImages`, so the Core mask stays crisp (exact bytes at cell centres).
        let rebuilt = FogMaskRasterizer.rasterize(confirmed: confirmed, pending: pending,
                                                  window: viewport.expanded(by: FogMaskRasterizer.margin), lod: lod,
                                                  soften: false, revision: revision)
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

/// Scrim over the basemap with the explored area cut out (`destinationOut`) through a feathered mask, a warm glow on the
/// confirmed frontier, and a dashed shimmering outline around unconfirmed ground (state is never colour-only). Ticks only
/// while wipes or the shimmer are live. Hidden from accessibility and hit testing.
struct FogOverlayLayer: View {
    let mask: FogMask
    let images: FogMaskImages?
    /// Where `mask.window` lands in this view's coordinate space.
    let windowRect: CGRect
    var style: FogScrimStyle
    var wipes: [FogWipeDraw] = []
    /// Extra canvas blur on the cut-out (points). The mask is already feathered; 0 by default.
    var softEdgeRadius: CGFloat = 0
    /// Animate the dashed outline. False under Reduce Motion or Low Power: the dashes stay still.
    var shimmer = false
    var clock: () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }

    init(mask: FogMask, images: FogMaskImages?, windowRect: CGRect, appearance: MapAppearance,
         wipes: [FogWipeDraw] = [], softEdgeRadius: CGFloat = 0, shimmer: Bool = false,
         clock: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
        self.init(mask: mask, images: images, windowRect: windowRect, style: .reveal(appearance), wipes: wipes,
                  softEdgeRadius: softEdgeRadius, shimmer: shimmer, clock: clock)
    }

    init(mask: FogMask, images: FogMaskImages?, windowRect: CGRect, style: FogScrimStyle, wipes: [FogWipeDraw] = [],
         softEdgeRadius: CGFloat = 0, shimmer: Bool = false, clock: @escaping () -> TimeInterval = { Date().timeIntervalSinceReferenceDate }) {
        self.mask = mask; self.images = images; self.windowRect = windowRect; self.style = style
        self.wipes = wipes; self.softEdgeRadius = softEdgeRadius; self.shimmer = shimmer; self.clock = clock
    }

    /// Lantern gold (CYNight.lantern): the fog edge is the one place light shows on the map.
    private static let warm = CYNight.lantern

    var body: some View {
        Group {
            if wipes.isEmpty && !(shimmer && (images?.pendingRing != nil || (style.frontierGlow && images?.glow != nil))) {
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
                if style.texture { drawTexture(&layer, size: size) }
                if style.vignette > 0 {
                    layer.fill(Path(full), with: .radialGradient(
                        Gradient(stops: [.init(color: .clear, location: 0.35), .init(color: .black.opacity(style.vignette), location: 1)]),
                        center: CGPoint(x: size.width / 2, y: size.height / 2), startRadius: 0, endRadius: hypot(size.width, size.height) / 2))
                }
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
            if style.frontierGlow, let glow = images?.glow {
                // Breathes on a 2.2 s cycle (+-15 %) unless motion is reduced; `shimmer` is false then (static edge).
                let breath = shimmer ? 1 + 0.15 * sin(now * 2 * .pi / 2.2) : 1
                if let bloom = images?.bloom {
                    ctx.drawLayer { layer in
                        layer.clip(to: Path(windowRect))
                        layer.fill(Path(full), with: .color(Self.warm.opacity(0.22 * breath)))
                        layer.blendMode = .destinationIn
                        layer.draw(layer.resolve(Image(decorative: bloom, scale: 1)), in: windowRect)
                    }
                }
                ctx.drawLayer { layer in
                    layer.clip(to: Path(windowRect))
                    layer.fill(Path(full), with: .color(Self.warm.opacity(0.58 * breath)))
                    layer.blendMode = .destinationIn
                    layer.draw(layer.resolve(Image(decorative: glow, scale: 1)), in: windowRect)
                }
            }
            if let ring = images?.pendingRing {
                ctx.drawLayer { layer in
                    layer.clip(to: Path(windowRect))
                    // Dashes: diagonal stripes 4 pt on, 5 pt off, crawling slowly when the shimmer runs.
                    let phase = shimmer ? CGFloat((now * 14).truncatingRemainder(dividingBy: 9)) : 0
                    var dashes = Path()
                    var x = -size.height + phase
                    while x < size.width {
                        dashes.move(to: CGPoint(x: x, y: size.height)); dashes.addLine(to: CGPoint(x: x + size.height, y: 0)); x += 9
                    }
                    let pulse = shimmer ? 0.75 + 0.25 * sin(now * 3) : 0.9
                    layer.stroke(dashes, with: .color(Color.white.opacity(pulse)), lineWidth: 4)
                    layer.blendMode = .destinationIn
                    layer.draw(layer.resolve(Image(decorative: ring, scale: 1)), in: windowRect)
                }
            }
        }
    }

    /// Deterministic soft blobs (lighter and darker) so the haze is not a flat fill. Screen-anchored.
    private func drawTexture(_ layer: inout GraphicsContext, size: CGSize) {
        var seed: UInt64 = 0x9E37_79B9_7F4A_7C15
        func next() -> CGFloat {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return CGFloat(seed >> 11) / CGFloat(1 << 53)
        }
        for i in 0..<40 {
            let c = CGPoint(x: next() * size.width, y: next() * size.height)
            let r = 50 + next() * 90
            let tint: Color = i.isMultiple(of: 2) ? .white.opacity(0.07) : .black.opacity(0.10)
            layer.fill(Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                       with: .radialGradient(Gradient(colors: [tint, tint.opacity(0)]), center: c, startRadius: 0, endRadius: r))
        }
    }
}
