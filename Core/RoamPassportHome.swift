import Foundation

/// Mini-program pages/roam/index 漫游护照 tab (`_loadIntroPassport`): four local readings, five
/// tiles and two play cards. Every number comes from this device's saved roam records; unknown
/// metrics stay unknown rather than zero.
public struct RoamPassportHome: Equatable {
    public enum Tile: String, CaseIterable, Identifiable {
        case history, stamp, badge, goals, capsule
        public var id: String { rawValue }
        public var titleKey: String { "roam.w208.passport.tile.\(rawValue)" }
        /// 探索目标 / 时光胶囊 shipped with the 2026-10-14 roam launch and carry a NEW mark.
        public var isNew: Bool { self == .goals || self == .capsule }
        /// Fixed subtitle for tiles without a count.
        public var subtitleKey: String? { self == .history || self == .stamp ? nil : "roam.w208.passport.tile.\(rawValue).sub" }
        public var symbol: String {
            switch self {
            case .history: return "point.topleft.down.to.point.bottomright.curvepath"
            case .stamp: return "photo.on.rectangle"
            case .badge: return "star"
            case .goals: return "flag"
            case .capsule: return "clock"
            }
        }
    }
    public enum Play: String, CaseIterable, Identifiable {
        /// 官方活动 is closed by product decision: the card keeps its slot and a tap does nothing.
        case event, discover
        public var id: String { rawValue }
        public var isClosed: Bool { self == .event }
        public var titleKey: String { "roam.w208.passport.play.\(rawValue)" }
        public var subtitleKey: String { "roam.w208.passport.play.\(rawValue).sub" }
    }
    public let summary: RoamPassportSummary
    public let stamps: Int
    /// `utils/roam-passport-tiles.js` `latestTrackThumb`. Empty means the page keeps its illustration.
    public let latestTrackThumbnail: String
    /// `latestStampImage`. Empty means the page keeps its illustration. Not a medal-wall fetch.
    public let latestStampImage: String
    public init(records: [RoamHistoryRecord], timeZone: TimeZone = .current) throws {
        latestTrackThumbnail = Self.latestTrackThumbnail(records)
        latestStampImage = Self.latestStampImage(records)
        summary = try RoamPassportSummary(records: records, timeZone: timeZone)
        stamps = records.reduce(0) { $0 + $1.photos.count }
    }

    public static func latestTrackThumbnail(_ records: [RoamHistoryRecord]) -> String {
        let row = newestFirst(records).first { trackPoints($0.track).count >= 2 }
        guard let row else { return "" }
        let pts = trackPoints(row.track)
        let lats = pts.map(\.lat), lngs = pts.map(\.lng)
        let minLat = lats.min() ?? 0, maxLat = lats.max() ?? 0
        let minLng = lngs.min() ?? 0, maxLng = lngs.max() ?? 0
        let kx = cos(((minLat + maxLat) / 2) * .pi / 180)
        let w = max((maxLng - minLng) * kx, 1e-6), h = max(maxLat - minLat, 1e-6)
        let size = 100.0, pad = 16.0, scale = (size - pad * 2) / max(w, h)
        let ox = (size - w * scale) / 2, oy = (size - h * scale) / 2
        let xy = pts.map { p in
            fixed1((p.lng - minLng) * kx * scale + ox) + "," + fixed1((maxLat - p.lat) * scale + oy)
        }
        let end = xy.last?.split(separator: ",").map(String.init) ?? ["0", "0"]
        let svg = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100 100\">"
            + "<rect width=\"100\" height=\"100\" fill=\"#1C1C1E\"/>"
            + "<polyline points=\"" + xy.joined(separator: " ") + "\" fill=\"none\" stroke=\"#C8F36A\" stroke-width=\"3\" stroke-linecap=\"round\" stroke-linejoin=\"round\"/>"
            + "<circle cx=\"" + (end.first ?? "0") + "\" cy=\"" + (end.dropFirst().first ?? "0") + "\" r=\"4\" fill=\"#C8F36A\"/></svg>"
        return "data:image/svg+xml;base64," + Data(svg.utf8).base64EncodedString()
    }

    public static func latestStampImage(_ records: [RoamHistoryRecord]) -> String {
        for record in newestFirst(records) {
            if let photo = record.photos.last(where: { !$0.isEmpty }) { return photo }
        }
        return ""
    }

    private static func newestFirst(_ records: [RoamHistoryRecord]) -> [RoamHistoryRecord] {
        records.enumerated().sorted { lhs, rhs in
            let left = Double(lhs.element.ts), right = Double(rhs.element.ts)
            if left != right { return left > right }
            return lhs.offset < rhs.offset
        }.map(\.element)
    }

    private static func trackPoints(_ track: [RoamHistoryPoint]) -> [(lat: Double, lng: Double)] {
        track.compactMap { point in
            guard point.lat.isFinite, point.lng.isFinite else { return nil }
            return (point.lat, point.lng)
        }
    }

    private static func fixed1(_ value: Double) -> String {
        let rounded = (value * 10).rounded(.toNearestOrAwayFromZero) / 10
        let shown = rounded == 0 ? 0 : rounded
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), shown)
    }
    /// History and album captions are counts (N 次旅程 / N 张邮票); the other tiles read their own pages.
    public func count(_ tile: Tile) -> Int? {
        switch tile {
        case .history: return summary.trips
        case .stamp: return stamps
        case .badge, .goals, .capsule: return nil
        }
    }
}

/// Mini-program header states above the two tabs, from this device's write-ahead journal only.
/// `finishPending` needs a check (上次漫游需要核对); `unfinished` is a recovered walk notice.
public enum RoamHomeRecoveryBanner: Equatable {
    case needsCheck, recovered
    public init?(status: RoamLocalWalkStatus) {
        switch status {
        case .finishPending: self = .needsCheck
        case .unfinished: self = .recovered
        case .none, .unavailable: return nil
        }
    }
    public var titleKey: String { self == .needsCheck ? "roam.w208.recovery.needsCheck" : "roam.w208.recovery.recovered" }
    public var accessibilityID: String { self == .needsCheck ? "roam.home.recovery.needsCheck" : "roam.home.recovery.recovered" }
}
