import Foundation

/// Round 9 m2 #1 `play-trail.js` `createPlayTrail`: the player's own walked points for the run.
/// It only consumes fixes the page already has (foreground); it never opens its own background watch.
/// The team sync (`team-trail.js`) reads `points()` and uploads only the ones walked since its last success.
public struct TeamWalkedTrail: Equatable {
    public static let minStepMeters = 8.0      // MIN_STEP_M: standing jitter is not a step
    public static let maxAccuracyMeters = 60.0 // MAX_ACCURACY_M: too coarse to draw
    public static let maxPoints = 4000         // MAX_POINTS: past this, simplify to 1000

    public private(set) var points: [TeamTrailPoint] = []
    public init() {}

    /// `note(loc)`: true when the fix was kept.
    @discardableResult public mutating func note(latitude: Double, longitude: Double, accuracy: Double?) -> Bool {
        guard latitude.isFinite, longitude.isFinite else { return false }
        if let accuracy, accuracy.isFinite, accuracy > Self.maxAccuracyMeters { return false }
        let point = TeamTrailPoint(latitude: latitude, longitude: longitude)
        if let last = points.last, Self.playDistance(last, point) < Self.minStepMeters { return false }
        points.append(point)
        if points.count > Self.maxPoints { points = Self.simplify(points, maxPoints: 1000, epsilonMeters: 3) }
        return true
    }

    public mutating func clear() { points = [] }

    /// `play-trail.js` `distM` (equirectangular at the mid latitude, earth radius 6371 km).
    static func playDistance(_ a: TeamTrailPoint, _ b: TeamTrailPoint) -> Double {
        let rad = Double.pi / 180
        let x = (b.longitude - a.longitude) * rad * cos(((a.latitude + b.latitude) / 2) * rad)
        let y = (b.latitude - a.latitude) * rad
        return (x * x + y * y).squareRoot() * 6_371_000
    }

    /// `roam-track-simplify.js` `simplifyTrack`: keep both ends, then the largest deviations first
    /// until `maxPoints` (capped at 1000), never by index thinning.
    static func simplify(_ source: [TeamTrailPoint], maxPoints requested: Int, epsilonMeters: Double) -> [TeamTrailPoint] {
        guard source.count > 2 else { return source }
        let maxPoints = min(max(requested, 2), 1000)
        var keep: Set<Int> = [0, source.count - 1]
        var candidates: [(start: Int, end: Int, index: Int, distance: Double)] = []
        func addSegment(_ start: Int, _ end: Int) {
            var index = -1, distance = epsilonMeters
            var i = start + 1
            while i < end {
                let d = perpendicularMeters(source[i], source[start], source[end])
                if d > distance { distance = d; index = i }
                i += 1
            }
            if index >= 0 { candidates.append((start, end, index, distance)) }
        }
        addSegment(0, source.count - 1)
        while !candidates.isEmpty, keep.count < maxPoints {
            var best = 0
            for i in candidates.indices.dropFirst() where candidates[i].distance > candidates[best].distance { best = i }
            let segment = candidates.remove(at: best)
            keep.insert(segment.index)
            addSegment(segment.start, segment.index)
            addSegment(segment.index, segment.end)
        }
        return keep.sorted().map { source[$0] }
    }

    private static func geoDistance(_ a: TeamTrailPoint, _ b: TeamTrailPoint) -> Double {
        let dy = (b.latitude - a.latitude) * 111_320
        let dx = (b.longitude - a.longitude) * 111_320 * cos(a.latitude * .pi / 180)
        return (dx * dx + dy * dy).squareRoot()
    }

    private static func perpendicularMeters(_ point: TeamTrailPoint, _ a: TeamTrailPoint, _ b: TeamTrailPoint) -> Double {
        let scale = 111_320 * cos(a.latitude * .pi / 180)
        let dx = (b.longitude - a.longitude) * scale, dy = (b.latitude - a.latitude) * 111_320
        let lengthSquared = dx * dx + dy * dy
        if lengthSquared < 1e-18 { return geoDistance(a, point) }
        let px = (point.longitude - a.longitude) * scale, py = (point.latitude - a.latitude) * 111_320
        let t = max(0, min(1, (px * dx + py * dy) / lengthSquared))
        let ex = px - t * dx, ey = py - t * dy
        return (ex * ex + ey * ey).squareRoot()
    }
}
