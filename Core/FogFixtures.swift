#if DEBUG
import Foundation

/// DEBUG-only synthetic walk for the fog tests and design fixtures (roam-fog-engine §1e). Never mounted on a live path.
/// Coordinates are literal GCJ-02 values near People's Square, Shanghai; they are not a real person's trail.
public enum FogFixtures {
    public struct Sample: Equatable {
        public let latitude, longitude: Double
        public let accuracyMeters: Double
        /// Seconds between the measurement and its receipt (stale when outside -2...30).
        public let ageSeconds: Double
    }

    /// 26 samples: 10 steps east (~85 m apart), a low-accuracy fix, a stale fix, a step back, a jump of ~1.1 km,
    /// 6 steps north, a low-accuracy fix, a second jump (~3 km) and 4 steps east.
    public static let shanghaiPeoplesSquareWalk: [Sample] = ([
        (31.2304, 121.4737, 8, 1),
        (31.2304, 121.4746, 8, 1),
        (31.2304, 121.4755, 8, 1),
        (31.2304, 121.4764, 8, 1),
        (31.2304, 121.4773, 8, 1),
        (31.2304, 121.4782, 8, 1),
        (31.2304, 121.4791, 8, 1),
        (31.2304, 121.48, 8, 1),
        (31.2304, 121.4809, 8, 1),
        (31.2304, 121.4818, 8, 1),
        (31.2304, 121.4829, 150, 2),
        (31.2305, 121.4838, 9, 60),
        (31.2304, 121.4827, 8, 1),
        (31.2404, 121.4737, 8, 1),
        (31.2412, 121.4737, 8, 1),
        (31.242, 121.4737, 8, 1),
        (31.2428, 121.4737, 8, 1),
        (31.2436, 121.4737, 8, 1),
        (31.2444, 121.4737, 8, 1),
        (31.2452, 121.4737, 8, 1),
        (31.23, 121.47, 200, 1),
        (31.22, 121.46, 8, 1),
        (31.22, 121.4609, 8, 1),
        (31.22, 121.4618, 8, 1),
        (31.22, 121.4627, 8, 1),
        (31.22, 121.4636, 8, 1),
    ] as [(Double, Double, Double, Double)]).map { Sample(latitude: $0.0, longitude: $0.1, accuracyMeters: $0.2, ageSeconds: $0.3) }

    /// The cells a live session would reveal, using the same rules as `RoamLiveSessionController`: accuracy <= 80 m,
    /// age in -2...30 s, steps < 3 m ignored, a step > 120 m resets the anchor and reveals nothing.
    public static func revealedCodes(_ walk: [Sample]) -> [String] {
        var previous: RoamCoordinate?
        var codes: [String] = []
        for sample in walk {
            guard sample.accuracyMeters <= 80, (-2.0...30.0).contains(sample.ageSeconds),
                  let point = RoamCoordinate(latitude: sample.latitude, longitude: sample.longitude) else { continue }
            if let anchor = previous {
                let distance = RoamExperienceMath.distanceMeters(anchor, point)
                if distance < 3 { continue }
                if distance > 120 { previous = point; continue }
            }
            previous = point
            if let code = RoamExperienceMath.tileKey(point), !codes.contains(code) { codes.append(code) }
        }
        return codes
    }

    public static func bitmap(_ codes: [String]) throws -> FogCellBitmap {
        var out = FogCellBitmap()
        for code in codes { try out.insert(FogCell(grid: .legacyRoamTile, code: code)) }
        return out
    }
}
#endif
