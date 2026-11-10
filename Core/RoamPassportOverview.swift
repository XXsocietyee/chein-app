import Foundation

/// P005 passport metrics describe only this device's bounded saved records, never account-wide
/// lifetime totals. Reuse the existing checked sum; absent fields remain absent, not measured zero.
public struct RoamPassportSummary: Equatable {
    public let trips: Int
    public let knownKilometers: Double?
    public let tripsWithDistance: Int
    public let knownShopVisits: Int?
    public let tripsWithShops: Int
    public let activeDays: Int?
    public let tripsWithDate: Int
    public let timeZoneIdentifier: String
    public var hasPartialMetrics: Bool {
        tripsWithDistance < trips || tripsWithShops < trips || tripsWithDate < trips ||
        knownKilometers == nil || knownShopVisits == nil || activeDays == nil
    }
    public init(records: [RoamHistoryRecord], timeZone: TimeZone = .current) throws {
        guard records.count <= 50, Set(records.map(\.ts)).count == records.count else { throw RoamExperienceFailure.historyUnreadable }
        let summary = RoamHistorySummary(records)
        trips = summary.trips; tripsWithDistance = summary.tripsWithDistance; tripsWithShops = summary.tripsWithShops
        knownKilometers = records.isEmpty || summary.tripsWithDistance > 0 ? summary.knownKilometers : nil
        knownShopVisits = records.isEmpty || summary.tripsWithShops > 0 ? summary.knownShops : nil
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = timeZone
        var days: Set<Date> = []; var dated = 0
        for record in records {
            // Existing native history renders dates from the saved millisecond timestamp. Do not
            // invent a date from a legacy display string such as "8.8", which has no year or zone.
            guard record.ts > 0, record.ts <= 253_402_300_799_999, let date = record.recordedAt,
                  let interval = calendar.dateInterval(of: .day, for: date) else { continue }
            days.insert(interval.start); dated += 1
        }
        tripsWithDate = dated; activeDays = records.isEmpty || dated > 0 ? days.count : nil
        timeZoneIdentifier = timeZone.identifier
    }
    /// UNKNOWN metrics render as an em dash. A present zero stays numeric, including `"0.0"` kilometres.
    public static let unknownText = "—"
    public var tripsText: String { String(trips) }
    public var shopsText: String { knownShopVisits.map(String.init) ?? Self.unknownText }
    public var daysText: String { activeDays.map(String.init) ?? Self.unknownText }
    public var kilometersText: String {
        guard let knownKilometers, knownKilometers.isFinite else { return Self.unknownText }
        return String(format: "%.1f", locale: Locale(identifier: "en_US_POSIX"), knownKilometers)
    }
}

/// Home passport tab states for `pages/roam/index`. Loading and error have no measured totals.
/// An empty local journal is a known zero, not an unknown and not a failure.
public enum RoamHomeIndexPassportRead: Equatable {
    case loading, empty, error, ready
}

public struct RoamHomeIndexPassportPresentation: Equatable {
    public let read: RoamHomeIndexPassportRead
    public let tripsText: String
    public let shopsText: String
    public let daysText: String
    public let kilometersText: String
    @MainActor public init(phase: RoamPassportOverviewState.Phase) {
        let unknown = RoamPassportSummary.unknownText
        switch phase {
        case .unloaded:
            read = .loading
            tripsText = unknown; shopsText = unknown; daysText = unknown; kilometersText = unknown
        case .failed:
            read = .error
            tripsText = unknown; shopsText = unknown; daysText = unknown; kilometersText = unknown
        case .loaded(let summary):
            read = summary.trips == 0 ? .empty : .ready
            tripsText = summary.tripsText
            shopsText = summary.shopsText
            daysText = summary.daysText
            kilometersText = summary.kilometersText
        }
    }
}

public struct RoamPassportReadOwner: Equatable, Hashable {
    public let readerID: ObjectIdentifier
    public let scopeKey: String?
    public let epoch: UInt64?
    @MainActor public init(reader: any RoamExperienceReading) {
        let identity = reader.identity
        readerID = ObjectIdentifier(reader); scopeKey = identity?.scope.storageKey; epoch = identity?.epoch
    }
}
@MainActor public struct RoamPassportOverviewState {
    public enum Phase { case unloaded, loaded(RoamPassportSummary), failed(Error) }
    private var owner: RoamPassportReadOwner?
    private var value: Phase = .unloaded
    public init() {}
    public func phase(reader: any RoamExperienceReading) -> Phase {
        owner == RoamPassportReadOwner(reader: reader) ? value : .unloaded
    }
    public mutating func invalidate() { owner = nil; value = .unloaded }
    public mutating func load(reader: any RoamExperienceReading, timeZone: TimeZone = .current) {
        invalidate()
        let snapshot = RoamPassportReadOwner(reader: reader)
        owner = snapshot
        guard snapshot.scopeKey != nil else { value = .failed(APIError.unauthorized); return }
        do {
            // isConfigured gates remote experience reads, not the existing local history contract.
            let records = try reader.history()
            guard snapshot == RoamPassportReadOwner(reader: reader) else { invalidate(); return }
            let summary = try RoamPassportSummary(records: records, timeZone: timeZone)
            guard snapshot == RoamPassportReadOwner(reader: reader) else { invalidate(); return }
            value = .loaded(summary)
        } catch {
            guard snapshot == RoamPassportReadOwner(reader: reader) else { invalidate(); return }
            value = .failed(error)
        }
    }
}
