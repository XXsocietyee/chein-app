import Foundation
#if canImport(ActivityKit) && os(iOS)
import ActivityKit
#endif

/// Display-only Live Activity values shared by the app and the `QuestifyLiveActivity` widget extension.
/// This file is compiled into both targets; it holds no account, token, coordinate or server identifier.
/// `story` (native r2 M4): story audio playing; started by the app's `QuestLiveActivityCenter`, never by Core mapping.
public enum QuestLiveActivityKind: String, Codable, Hashable, Sendable { case roam, play, story }
/// Which play flow a `.play` activity belongs to (native r2 M4). Nil keeps the original play layout.
public enum QuestLiveActivityMode: String, Codable, Hashable, Sendable { case orientation, explore }
public enum QuestLiveActivityStatus: String, Codable, Hashable, Sendable { case active, paused, finished }

/// ActivityKit `ContentState`. Roam fields are nil for play, play fields are nil for roam.
public struct QuestLiveActivityContent: Codable, Hashable, Sendable {
    public var status: QuestLiveActivityStatus
    /// Whole seconds counted so far. Nil means this session shows no timer.
    public var elapsedSeconds: Int?
    /// Wall-clock start for the system timer (`now - elapsedSeconds`), only while `status == .active`.
    public var runningSince: Date?
    public var distanceMeters: Int?
    public var placesRevealed: Int?
    public var stopName: String?
    /// 1-based position of the current stop among the visible stops.
    public var stopIndex: Int?
    public var stopCount: Int?
    public var cluesSolved: Int?
    public var cluesTotal: Int?
    /// Native r2 M4 (all optional, so content encoded by an older build still decodes):
    /// the play flow, the straight-line distance to the next stop, and the story audio clip.
    public var mode: QuestLiveActivityMode?
    public var nextDistanceMeters: Int?
    public var mediaTitle: String?
    public var mediaPlaying: Bool?
    public init(status: QuestLiveActivityStatus, elapsedSeconds: Int? = nil, runningSince: Date? = nil,
                distanceMeters: Int? = nil, placesRevealed: Int? = nil, stopName: String? = nil, stopIndex: Int? = nil,
                stopCount: Int? = nil, cluesSolved: Int? = nil, cluesTotal: Int? = nil,
                mode: QuestLiveActivityMode? = nil, nextDistanceMeters: Int? = nil,
                mediaTitle: String? = nil, mediaPlaying: Bool? = nil) {
        self.status = status; self.elapsedSeconds = elapsedSeconds; self.runningSince = runningSince
        self.distanceMeters = distanceMeters; self.placesRevealed = placesRevealed; self.stopName = stopName
        self.stopIndex = stopIndex; self.stopCount = stopCount; self.cluesSolved = cluesSolved; self.cluesTotal = cluesTotal
        self.mode = mode; self.nextDistanceMeters = nextDistanceMeters
        self.mediaTitle = mediaTitle; self.mediaPlaying = mediaPlaying
    }
    /// Range for `Text(timerInterval:)` while the timer runs; nil when paused, finished or untimed.
    public var timerInterval: ClosedRange<Date>? {
        guard status == .active, let runningSince else { return nil }
        return runningSince...runningSince.addingTimeInterval(QuestLiveActivityText.timerHorizon)
    }
}

/// Plain-text values for the Live Activity views. Labels are localized by the widget's own catalog.
public enum QuestLiveActivityText {
    /// The system timer needs an upper bound; a walk or run never shows a value past it.
    public static let timerHorizon: TimeInterval = 24 * 60 * 60
    /// `850 m` under one kilometre, `1.2 km` from one kilometre. Nil distance shows an em dash.
    public static func distance(_ meters: Int?) -> String {
        guard let meters, meters >= 0 else { return "—" }
        if meters < 1000 { return "\(meters) m" }
        let tenths = (meters + 50) / 100
        return "\(tenths / 10).\(tenths % 10) km"
    }
    /// `mm:ss` under one hour, `h:mm:ss` from one hour (same shape as `PlayRunElapsedText`).
    public static func elapsed(_ seconds: Int?) -> String {
        guard let seconds, seconds >= 0 else { return "—" }
        let h = seconds / 3600, m = (seconds % 3600) / 60, s = seconds % 60
        func two(_ value: Int) -> String { value < 10 ? "0\(value)" : "\(value)" }
        return h > 0 ? "\(h):\(two(m)):\(two(s))" : "\(two(m)):\(two(s))"
    }
    /// `2/5`, or an em dash when either side is unknown.
    public static func fraction(_ done: Int?, _ total: Int?) -> String {
        guard let done, let total, total > 0 else { return "—" }
        return "\(min(done, total))/\(total)"
    }
}

#if canImport(ActivityKit) && os(iOS)
/// Static attributes. `title` is the activity or topic name for play and nil for roam.
public struct QuestLiveActivityAttributes: ActivityAttributes {
    public typealias ContentState = QuestLiveActivityContent
    public let kind: QuestLiveActivityKind
    public let title: String?
    public init(kind: QuestLiveActivityKind, title: String?) { self.kind = kind; self.title = title }
}
#endif
