import Foundation

/// Roam fog spec stage 1 (§1b). Level of detail from the on-screen size of one geohash-7 cell (≈153 m).
public enum FogLevelOfDetail: Equatable {
    case summary, cell6, cell7

    public static let cell7Threshold = 6.0
    public static let cell6Threshold = 2.0
    public static let hysteresis = 0.2
    public static let cellMeters = 153.0

    public static func cellPixels(metersPerPixel: Double) -> Double {
        metersPerPixel > 0 && metersPerPixel.isFinite ? cellMeters / metersPerPixel : 0
    }

    /// Switches finer only once `cellPixels` clears the threshold by 20 %, and coarser only once it falls 20 % below it.
    public static func resolve(cellPixels px: Double, previous: Self) -> Self {
        var level = previous
        while level != .cell7, px >= (level == .summary ? cell6Threshold : cell7Threshold) * (1 + hysteresis) {
            level = level == .summary ? .cell6 : .cell7
        }
        while level != .summary, px < (level == .cell7 ? cell7Threshold : cell6Threshold) * (1 - hysteresis) {
            level = level == .cell7 ? .cell6 : .summary
        }
        return level
    }

    /// First resolution with no previous level: nominal thresholds.
    public static func resolve(cellPixels px: Double) -> Self {
        px >= cell7Threshold ? .cell7 : (px >= cell6Threshold ? .cell6 : .summary)
    }
}

/// 8-bit alpha of explored ground: 255 confirmed, 128 pending-only, 0 hidden. `summary` carries no pixels.
public struct FogMask: Equatable {
    public static let confirmedAlpha: UInt8 = 255
    public static let pendingAlpha: UInt8 = 128
    public let width, height: Int
    public let alpha: [UInt8]
    public let window: FogMercatorWindow
    public let lod: FogLevelOfDetail
    public let revision: Int

    /// Alpha at pixel (x, y); row 0 is the north edge. 0 outside the mask.
    public func alpha(x: Int, y: Int) -> UInt8 {
        guard x >= 0, y >= 0, x < width, y < height else { return 0 }
        return alpha[y * width + x]
    }
    /// Pixel under a lat/lng point, nil when outside the mask window.
    public func pixel(latitude: Double, longitude: Double) -> (x: Int, y: Int)? {
        guard width > 0, height > 0 else { return nil }
        let mx = FogMercatorWindow.x(longitude: longitude), my = FogMercatorWindow.y(latitude: latitude)
        guard mx >= window.minX, mx < window.maxX, my > window.minY, my <= window.maxY else { return nil }
        let px = Int((mx - window.minX) / window.width * Double(width)), py = Int((window.maxY - my) / window.height * Double(height))
        return (min(px, width - 1), min(py, height - 1))
    }
}

public enum FogMaskRasterizer {
    public static let maxSide = 512
    public static let margin = 0.25

    /// `window` is the exact area to cover (callers pass the viewport expanded by `margin`). The buffer is at most
    /// `maxSide` on its long side; a pixel is filled when its centre lies inside the cell rectangle.
    public static func rasterize(confirmed: FogCellBitmap, pending: FogCellBitmap, window: FogMercatorWindow,
                                 lod: FogLevelOfDetail, soften: Bool, revision: Int) -> FogMask {
        guard lod != .summary, window.width > 0, window.height > 0, window.metersPerPixel > 0 else {
            return FogMask(width: 0, height: 0, alpha: [], window: window, lod: lod, revision: revision)
        }
        let scale = min(1 / window.metersPerPixel, Double(maxSide) / max(window.width, window.height))
        let w = max(1, min(maxSide, Int((window.width * scale).rounded(.up))))
        let h = max(1, min(maxSide, Int((window.height * scale).rounded(.up))))
        var buffer = [UInt8](repeating: 0, count: w * h)
        // Per-axis scale so the buffer spans the window exactly.
        let sx = Double(w) / window.width, sy = Double(h) / window.height

        func fill(south: Double, west: Double, north: Double, east: Double, value: UInt8) {
            let r = FogMercatorWindow.rect(south: south, west: west, north: north, east: east)
            guard window.intersects(minX: r.minX, minY: r.minY, maxX: r.maxX, maxY: r.maxY) else { return }
            let x0 = max(0, Int(((r.minX - window.minX) * sx - 0.5).rounded(.up)))
            let x1 = min(w - 1, Int(((r.maxX - window.minX) * sx - 0.5).rounded(.up)) - 1)
            let y0 = max(0, Int(((window.maxY - r.maxY) * sy - 0.5).rounded(.up)))
            let y1 = min(h - 1, Int(((window.maxY - r.minY) * sy - 0.5).rounded(.up)) - 1)
            guard x0 <= x1, y0 <= y1 else { return }
            for y in y0...y1 { for x in x0...x1 { buffer[y * w + x] = max(buffer[y * w + x], value) } }
        }

        switch lod {
        case .cell7:
            var pendingOnly = pending
            pendingOnly.subtract(confirmed)
            for cell in pendingOnly.cells(in: window, state: .pendingSync) { fill(south: cell.south, west: cell.west, north: cell.north, east: cell.east, value: FogMask.pendingAlpha) }
            for cell in confirmed.cells(in: window) { fill(south: cell.south, west: cell.west, north: cell.north, east: cell.east, value: FogMask.confirmedAlpha) }
        case .cell6:
            var pendingOnly = pending
            pendingOnly.subtract(confirmed)
            let keys = Set(confirmed.parents.keys).union(pendingOnly.parents.keys).sorted()
            for key in keys {
                for v6 in 0..<32 {
                    let c = confirmed.parents[key]?.childCount(v6: v6) ?? 0
                    let p = pendingOnly.parents[key]?.childCount(v6: v6) ?? 0
                    guard c + p > 0 else { continue }
                    let code = key.geohash5 + String(FogCellBitmap.alphabet[v6])
                    guard let b = FogGeohash.bounds(of: code) else { continue }
                    let value = min(255, (Int(FogMask.confirmedAlpha) * c + Int(FogMask.pendingAlpha) * p) / 32)
                    fill(south: b.south, west: b.west, north: b.north, east: b.east, value: UInt8(value))
                }
            }
        case .summary:
            break
        }
        if soften { buffer = boxBlur(buffer, w: w, h: h) }
        return FogMask(width: w, height: h, alpha: buffer, window: window, lod: lod, revision: revision)
    }

    /// Rebuild when there is no mask, the bitmaps changed, the viewport left the rasterized window (margin used up),
    /// or the level of detail (with hysteresis) changed.
    public static func needsRebuild(current: FogMask?, viewport: FogMercatorWindow, bitmapRevision: Int) -> Bool {
        guard let current else { return true }
        if current.revision != bitmapRevision { return true }
        let wanted = FogLevelOfDetail.resolve(cellPixels: FogLevelOfDetail.cellPixels(metersPerPixel: viewport.metersPerPixel), previous: current.lod)
        if wanted != current.lod { return true }
        return !current.window.contains(viewport)
    }

    private static func boxBlur(_ src: [UInt8], w: Int, h: Int) -> [UInt8] {
        guard w > 2, h > 2 else { return src }
        var out = src
        for y in 1..<(h - 1) {
            for x in 1..<(w - 1) {
                var sum = 0
                for dy in -1...1 { for dx in -1...1 { sum += Int(src[(y + dy) * w + x + dx]) } }
                out[y * w + x] = UInt8(sum / 9)
            }
        }
        return out
    }
}
