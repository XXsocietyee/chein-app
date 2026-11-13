import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// G4 roam extras. Ports `pages/roam/index` (`_archiveFinishedRecords`, `_loadShopStripVisitors`),
/// `utils/roam-shop-visitors.js` and `utils/roam-share-snapshot.js#revokeShareSnapshots`.
/// All three are form posts (`app.sendRequest` POST without a header).
public struct RoamPlayerExtrasService {
    public static let sessionRecordsPath = "api/roam/session/records"
    public static let shareRevokePath = "api/roam/share/revoke"
    public static let shopVisitorsPath = "api/roam/shop/visitors"

    let client: PlayerCapabilityClient
    public init(client: PlayerCapabilityClient) { self.client = client }

    // MARK: Session records (finished-session archive)

    public struct TileRecord: Equatable {
        public let tile: String
        public let collectedAt: Int64
        public init(tile: String, collectedAt: Int64) { self.tile = tile; self.collectedAt = collectedAt }
    }
    public static let recordBatchMax = 200
    private static let geohash = Set("0123456789bcdefghjkmnpqrstuvwxyz")

    /// `archiveRecords`: 7-character geohash tiles with a positive original collection time, or no archive at all.
    public static func validRecords(_ records: [TileRecord]) -> Bool {
        !records.isEmpty && records.count <= recordBatchMax && records.allSatisfy { record in
            record.tile.count == 7 && record.tile.allSatisfy { geohash.contains($0) } && record.collectedAt > 0
        }
    }

    func recordsRequest(sessionID: Int, clientSessionKey: String?, records: [TileRecord]) throws -> URLRequest {
        guard sessionID > 0, Self.validRecords(records) else { throw PlayerCapabilityFailure.invalid }
        let rows = records.map { ["tile": SquareGovernanceJSON.string($0.tile), "collectedAt": .integer(Int($0.collectedAt))] }
        let encoder = JSONEncoder(); encoder.outputFormatting = [.sortedKeys]
        let json = String(decoding: try encoder.encode(rows), as: UTF8.self)
        var fields = [("sessionId", String(sessionID))]
        if let key = clientSessionKey, !key.isEmpty { fields.append(("clientSessionKey", key)) }
        fields.append(("records", json))
        return try client.formRequest(Self.sessionRecordsPath, fields: fields)
    }

    /// One batch. Accepted only when the server echoes the session, `CLIENT_REPORTED`, and the distinct tile count;
    /// anything else keeps the pending tiles (「原行程补传暂未确认，待核记录仍保留」).
    public func archive(sessionID: Int, clientSessionKey: String?, records: [TileRecord]) async throws -> Int {
        let raw = try await client.write(try recordsRequest(sessionID: sessionID, clientSessionKey: clientSessionKey, records: records))
        let distinct = Set(records.map(\.tile)).count
        guard PlayerCapabilityClient.positiveID(raw["sessionId"]) == sessionID, raw["evidenceType"].string == "CLIENT_REPORTED",
              raw["acceptedRecords"].int == distinct else { throw PlayerCapabilityFailure.outcomeUnknown }
        return distinct
    }

    // MARK: Share revoke

    /// Revokes every share snapshot of this account. `data: {}` → an empty form body.
    /// False keeps the caller's pending mark so the next publish revokes first.
    public func revokeShareSnapshots() async -> Bool {
        guard let request = try? client.formRequest(Self.shareRevokePath, fields: []),
              (try? await client.write(request)) != nil else { return false }
        return true
    }

    // MARK: Shop visitors (BL-70)

    public static let visitorSourceMax = 20
    public static let visitorFaceMax = 5

    public struct VisitorSource: Hashable {
        /// 1 = roam point (`_roamId`), 2 = registered merchant (`regId`).
        public let sourceType: Int
        public let sourceID: Int
        public init(sourceType: Int, sourceID: Int) { self.sourceType = sourceType; self.sourceID = sourceID }
    }
    public struct Visitors: Equatable {
        public let faces: [URL]
        public let total: Int
        /// 「N 人打过卡」
        public var label: String { "\(total) 人打过卡" }
    }

    /// `buildVisitorRequests`: grouped by type, de-duplicated, at most 20 ids per group.
    public static func visitorRequests(_ sources: [VisitorSource]) -> [(sourceType: Int, sourceIDs: String)] {
        var groups: [Int: [Int]] = [:]
        var order: [Int] = []
        for source in sources where (source.sourceType == 1 || source.sourceType == 2) && source.sourceID > 0 {
            if groups[source.sourceType] == nil { groups[source.sourceType] = []; order.append(source.sourceType) }
            if !groups[source.sourceType]!.contains(source.sourceID), groups[source.sourceType]!.count < visitorSourceMax {
                groups[source.sourceType]!.append(source.sourceID)
            }
        }
        return order.sorted().map { ($0, groups[$0]!.map(String.init).joined(separator: ",")) }
    }

    /// `shapeVisitorRows`: total ≤ 0 or a bad row is dropped; faces are http(s) only, at most five.
    public static func visitorRows(sourceType: Int, _ raw: SquareGovernanceJSON) -> [VisitorSource: Visitors] {
        var out: [VisitorSource: Visitors] = [:]
        for row in raw.array ?? [] {
            guard let id = PlayerCapabilityClient.positiveID(row["sourceId"]), let total = row["total"].int, total > 0 else { continue }
            let faces = (row["avatars"].array ?? []).compactMap { value -> URL? in
                let text = PlayerCapabilityClient.text(value)
                guard text.hasPrefix("http://") || text.hasPrefix("https://") else { return nil }
                return URL(string: text)
            }
            out[VisitorSource(sourceType: sourceType, sourceID: id)] = Visitors(faces: Array(faces.prefix(visitorFaceMax)), total: total)
        }
        return out
    }

    /// Failures change nothing: the avatar stack is extra information and never blocks the card.
    public func visitors(for sources: [VisitorSource]) async -> [VisitorSource: Visitors] {
        var merged: [VisitorSource: Visitors] = [:]
        for group in Self.visitorRequests(sources) {
            guard let request = try? client.formRequest(Self.shopVisitorsPath, fields: [
                ("sourceType", String(group.sourceType)), ("sourceIds", group.sourceIDs)
            ]), let raw = try? await client.read(request) else { continue }
            merged.merge(Self.visitorRows(sourceType: group.sourceType, raw)) { _, new in new }
        }
        return merged
    }
}
