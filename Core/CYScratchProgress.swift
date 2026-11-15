import Foundation

/// Pure-Foundation grid progress model ported from mini-program `cy-scratch` (`scratch-progress.js`).
public struct CYScratchProgressTracker: Equatable, Sendable {
    public struct Point: Equatable, Sendable {
        public let x: Double
        public let y: Double
        public init(x: Double, y: Double) {
            self.x = x
            self.y = y
        }
    }

    public struct StrokeSegment: Equatable, Sendable {
        public let from: Point
        public let to: Point
        public let radius: Double
        public init(from: Point, to: Point, radius: Double) {
            self.from = from
            self.to = to
            self.radius = radius
        }
    }

    public static let pixelStride: Double = 16
    public static let defaultThreshold: Double = 0.45

    public let width: Double
    public let height: Double
    public let columns: Int
    public let rows: Int
    public let threshold: Double
    public private(set) var segments: [StrokeSegment] = []
    public private(set) var clearedCount: Int = 0
    public private(set) var revealed: Bool = false

    private var grid: [Bool]

    public static func clampThreshold(_ raw: Double?) -> Double {
        guard let raw, raw.isFinite, raw > 0 else { return defaultThreshold }
        return min(1.0, raw)
    }

    public init(width: Double = 320, height: Double = 160, threshold: Double? = nil) {
        let safeW = width.isFinite && width >= Self.pixelStride ? width : 320
        let safeH = height.isFinite && height >= Self.pixelStride ? height : 160
        self.width = safeW
        self.height = safeH
        self.columns = max(1, Int(ceil(safeW / Self.pixelStride)))
        self.rows = max(1, Int(ceil(safeH / Self.pixelStride)))
        self.threshold = Self.clampThreshold(threshold)
        self.grid = Array(repeating: false, count: columns * rows)
    }

    public var totalCells: Int { columns * rows }

    public var progress: Double {
        if revealed { return max(threshold, Double(clearedCount) / Double(max(1, totalCells))) }
        return Double(clearedCount) / Double(max(1, totalCells))
    }

    /// Stamps a rub stroke in normalized or canvas coordinates (matching tracker's width/height).
    /// Returns `true` on the transition that crosses `threshold` for the first time.
    @discardableResult
    public mutating func stamp(from: Point, to: Point, radius: Double = 22) -> Bool {
        guard !revealed else { return false }
        let safeRadius = radius.isFinite && radius > 0 ? radius : 22
        segments.append(StrokeSegment(from: from, to: to, radius: safeRadius))
        let dx = to.x - from.x
        let dy = to.y - from.y
        let distance = hypot(dx, dy)
        let step = max(1, safeRadius * 0.45)
        let steps = max(1, Int(ceil(distance / step)))
        for s in 0...steps {
            let t = Double(s) / Double(steps)
            markCircle(centerX: from.x + dx * t, centerY: from.y + dy * t, radius: safeRadius)
        }
        if progress >= threshold {
            revealed = true
            return true
        }
        return false
    }

    public mutating func revealAll() -> Bool {
        let newlyRevealed = !revealed
        revealed = true
        for index in grid.indices where !grid[index] {
            grid[index] = true
        }
        clearedCount = grid.count
        return newlyRevealed
    }

    private mutating func markCircle(centerX: Double, centerY: Double, radius: Double) {
        let r2 = radius * radius
        let minCol = max(0, Int(floor((centerX - radius) / Self.pixelStride)))
        let maxCol = min(columns - 1, Int(floor((centerX + radius) / Self.pixelStride)))
        let minRow = max(0, Int(floor((centerY - radius) / Self.pixelStride)))
        let maxRow = min(rows - 1, Int(floor((centerY + radius) / Self.pixelStride)))
        guard minCol <= maxCol, minRow <= maxRow else { return }
        for row in minRow...maxRow {
            let cy = (Double(row) + 0.5) * Self.pixelStride
            for col in minCol...maxCol {
                let cx = (Double(col) + 0.5) * Self.pixelStride
                let dist2 = (cx - centerX) * (cx - centerX) + (cy - centerY) * (cy - centerY)
                if dist2 <= r2 {
                    let idx = row * columns + col
                    if !grid[idx] {
                        grid[idx] = true
                        clearedCount += 1
                    }
                }
            }
        }
    }
}
