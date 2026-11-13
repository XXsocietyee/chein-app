import Foundation

/// Mini-program `pages/play/finish-route-recommendation.js` + `index.js
/// loadFinishRouteRecommendation` (附近下一程 on the finish sheet).
/// Gated by the server feature `finishNearbyRoute` (default false). The origin is the
/// most recently completed node's server coordinate; the App never samples device
/// location for this card (the mini-program's `_loc` branch is not ported).
public struct PlayFinishOrigin: Equatable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public init?(latitude: Double?, longitude: Double?) {
        guard let latitude, let longitude, latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude), latitude != 0 || longitude != 0 else { return nil }
        self.latitude = latitude; self.longitude = longitude
    }

    /// `resolveOrigin` without the device-location branch: done nodes with a coordinate,
    /// newest `doneAt` first; equal or missing `doneAt` keeps server order.
    public static func resolve(_ nodes: [(done: Bool, latitude: Double?, longitude: Double?, doneAt: Double?)]) -> PlayFinishOrigin? {
        let completed = nodes.enumerated().compactMap { index, node -> (Int, Double, PlayFinishOrigin)? in
            guard node.done, let origin = PlayFinishOrigin(latitude: node.latitude, longitude: node.longitude) else { return nil }
            return (index, node.doneAt ?? 0, origin)
        }
        return completed.sorted { $0.1 != $1.1 ? $0.1 > $1.1 : $0.0 < $1.0 }.first?.2
    }

    public static func resolve(nodes: [PlayNode]) -> PlayFinishOrigin? {
        resolve(nodes.map { (done: $0.done == true, latitude: $0.latitude, longitude: $0.longitude, doneAt: nil) })
    }
}

/// One `api/activity/list` row, only the fields the card reads.
public struct PlayFinishRouteRow: Decodable, Equatable, Sendable {
    public let id: Int
    public let name: String?
    public let imgUrl: String?
    public let topicId: Int?
    public let distance: Double?
    public let addressName: String?
    public let address: String?
    /// Wire spelling `minAmout`.
    public let minAmout: Decimal?
    /// Server `endDate` (`yyyy-MM-dd HH:mm[:ss]`, Beijing). Nil keeps the list's public gate.
    public let endDate: String?
    private enum CodingKeys: String, CodingKey { case id, name, imgUrl, topicId, distance, addressName, address, minAmout, endDate }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        guard let id = try c.playInt(.id), id > 0 else { throw APIError.malformedResponse }
        self.id = id
        name = try? c.decodeIfPresent(String.self, forKey: .name)
        imgUrl = try? c.decodeIfPresent(String.self, forKey: .imgUrl)
        topicId = try? c.playInt(.topicId)
        distance = c.playCoordinate(.distance)
        addressName = try? c.decodeIfPresent(String.self, forKey: .addressName)
        address = try? c.decodeIfPresent(String.self, forKey: .address)
        minAmout = (try? c.decodeIfPresent(Decimal.self, forKey: .minAmout)) ?? (try? c.decodeIfPresent(String.self, forKey: .minAmout)).flatMap { Decimal(string: $0) }
        endDate = try? c.decodeIfPresent(String.self, forKey: .endDate)
    }

    /// U08-02 `stillOpen`: a row whose server end time has passed is not a candidate one can still sign up for.
    /// A missing or unreadable end time keeps the row (the list's own public gate applies).
    public func stillOpen(at now: Date) -> Bool {
        guard let endDate, let end = Self.beijing(endDate) else { return true }
        return end > now
    }

    static func beijing(_ text: String) -> Date? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        for format in ["yyyy-MM-dd HH:mm:ss", "yyyy-MM-dd'T'HH:mm:ss", "yyyy-MM-dd HH:mm", "yyyy-MM-dd'T'HH:mm"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: trimmed) { return date }
        }
        return nil
    }
}

/// U08-02 exposure identity. One impression id links a tap to that exposure, with the source run and topic,
/// so a recommendation can be traced to the run it came from. A tap opens the detail page only; it is not a sign-up.
public struct PlayFinishRouteImpression: Equatable, Sendable {
    public let impressionID: String
    public let sourceActivityID: String?
    public let sourceTopicID: String?
    public let sourceRunID: String?

    public init(impressionID: String, sourceActivityID: String?, sourceTopicID: String?, sourceRunID: String?) {
        self.impressionID = impressionID
        self.sourceActivityID = sourceActivityID
        self.sourceTopicID = sourceTopicID
        self.sourceRunID = sourceRunID
    }

    /// `impressionSource`: `frr-<base36 millis>-<random>`.
    public static func make(activityID: Int?, topicID: Int?, runID: String?, now: Date = Date(),
                            entropy: String = JourneyLoopSource.randomEntropy()) -> PlayFinishRouteImpression {
        let millis = UInt64(max(0, (now.timeIntervalSince1970 * 1000).rounded(.down)))
        let positive: (Int?) -> String? = { $0.flatMap { $0 > 0 ? String($0) : nil } }
        let run = runID.flatMap { JourneyLoopSource.isID($0) ? $0 : nil }
        return PlayFinishRouteImpression(impressionID: "frr-" + String(millis, radix: 36) + "-" + entropy,
                                         sourceActivityID: positive(activityID), sourceTopicID: positive(topicID), sourceRunID: run)
    }

    /// `trackProperties` for the click event (placement `play_finish`).
    public func trackProperties(mode: Int?) -> [String: String] {
        var out = ["placement": "play_finish", "impressionId": impressionID]
        if let mode { out["mode"] = String(mode) }
        if let sourceActivityID { out["sourceActivityId"] = sourceActivityID }
        if let sourceTopicID { out["sourceTopicId"] = sourceTopicID }
        if let sourceRunID { out["sourceRunId"] = sourceRunID }
        return out
    }
}

public struct PlayFinishRouteCard: Equatable, Sendable {
    public enum Price: Equatable, Sendable {
        /// ¥N 起
        case from(Decimal)
        /// 免费 (server amount 0, never inferred from a missing price)
        case free
    }
    public let activityID: Int
    /// nil → 附近路线
    public let title: String?
    public let coverURL: String?
    public let distanceMeters: Double?
    public let address: String?
    public let price: Price?
    /// Set by the coordinator when the card is shown.
    public var impression: PlayFinishRouteImpression?

    /// `pickCandidate`: first row that is neither the current activity nor the current topic and is still open.
    /// No candidate simply ends the section; the ending itself is unaffected.
    public static func pick(_ rows: [PlayFinishRouteRow], currentActivityID: Int?, currentTopicID: Int?, now: Date = Date()) -> PlayFinishRouteCard? {
        guard let row = rows.first(where: { row in
            (currentActivityID.map { row.id != $0 } ?? true) && (currentTopicID.map { row.topicId != $0 } ?? true)
                && row.stillOpen(at: now)
        }) else { return nil }
        let title = row.name.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let cover = row.imgUrl?.split(separator: ",", omittingEmptySubsequences: false).first.map(String.init).flatMap { $0.isEmpty ? nil : $0 }
        let address = [row.addressName, row.address].compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.first { !$0.isEmpty }
        let price: Price? = row.minAmout.map { $0 > 0 ? .from($0) : .free }
        return PlayFinishRouteCard(activityID: row.id, title: title, coverURL: cover, distanceMeters: row.distance.flatMap { $0 >= 0 ? $0 : nil }, address: address, price: price, impression: nil)
    }

    /// `utils/geo.js distanceText`: ≥1000 m → one decimal km, else whole metres.
    public static func distanceParts(_ meters: Double) -> (value: String, kilometres: Bool) {
        meters >= 1000 ? (String(format: "%.1f", (meters / 100).rounded() / 10), true) : (String(Int(meters.rounded())), false)
    }
}

extension PlayExperienceService {
    /// `POST api/activity/list {is_my:0, sort_type:1, pageNum:1, pageSize:5, longitude, latitude}`.
    public func finishRouteRows(origin: PlayFinishOrigin, token: String) async throws -> [PlayFinishRouteRow] {
        let fields = ["is_my": "0", "sort_type": "1", "pageNum": "1", "pageSize": "5",
                      "longitude": String(origin.longitude), "latitude": String(origin.latitude)]
        let raw = try await request("api/activity/list", form: fields, capability: .reads, token: token)
        return (raw["rows"].array ?? []).compactMap { try? $0.decoded(PlayFinishRouteRow.self) }
    }
}

public protocol PlayFinishRouteReading: AnyObject {
    @MainActor func rows(origin: PlayFinishOrigin) async throws -> [PlayFinishRouteRow]
}

@available(macOS 14.0, *)
@MainActor @Observable public final class PlayFinishRouteRecommendationCoordinator {
    public private(set) var card: PlayFinishRouteCard?
    public private(set) var isVisible = false
    private let featureEnabled: Bool
    private let reader: (any PlayFinishRouteReading)?
    private let currentActivityID: Int?
    private let currentTopicID: Int?
    private let sourceRunID: String?
    private let now: () -> Date
    private var epoch: UInt64 = 0

    /// `featureEnabled` is the server `finishNearbyRoute` flag; absent means false.
    public init(featureEnabled: Bool, reader: (any PlayFinishRouteReading)?, currentActivityID: Int?, currentTopicID: Int?,
                sourceRunID: String? = nil, now: @escaping () -> Date = Date.init) {
        self.featureEnabled = featureEnabled; self.reader = reader
        self.currentActivityID = currentActivityID; self.currentTopicID = currentTopicID
        self.sourceRunID = sourceRunID; self.now = now
    }

    /// Finish sheet opened. Failures and empty pages simply show no card.
    public func show(origin: PlayFinishOrigin?, isPreview: Bool = false) async {
        epoch &+= 1; let request = epoch
        isVisible = true; card = nil
        guard featureEnabled, !isPreview, let reader, let origin else { return }
        guard let rows = try? await reader.rows(origin: origin), request == epoch, isVisible else { return }
        let at = now()
        card = PlayFinishRouteCard.pick(rows, currentActivityID: currentActivityID, currentTopicID: currentTopicID, now: at).map { picked in
            var shown = picked
            shown.impression = PlayFinishRouteImpression.make(activityID: currentActivityID, topicID: currentTopicID, runID: sourceRunID, now: at)
            return shown
        }
    }

    /// Finish sheet hidden: late responses are dropped.
    public func hide() { epoch &+= 1; isVisible = false; card = nil }
}
