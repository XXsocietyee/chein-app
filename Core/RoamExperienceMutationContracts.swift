import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Source-backed dormant request construction. These descriptors are NOT authority to perform
/// an action. A real device fix must come from a reviewed provider; a search center is not one.
public enum RoamExperienceMutation: Equatable {
    case reveal(sessionID: Int, tiles: [String])
    case discover(sessionID: Int, poiID: Int, fix: RoamDeviceFix)
    case shopVisit(sessionID: Int, sourceType: Int, sourceID: Int, fix: RoamDeviceFix)
    /// `track`: the walk's GCJ-02 points, as the MP sends them (pages/roam/index.js sendFinish, ≤600 points).
    case finish(sessionID: Int, poiIDs: [Int], distanceMeters: Int, track: [RoamCoordinate] = [])
    case presence(sessionID: Int, fix: RoamDeviceFix, explorationPercent: Int)
    case checkin(name: String, place: RoamCoordinate, fix: RoamDeviceFix)
    case completeNode(poiID: Int, fix: RoamDeviceFix, answer: String, photoURL: String, code: String)
    case toggleFavorite(poiID: Int)
    case issueVoucher(poiID: Int)
    case createStamp(pictureURL: String, caption: String, idempotencyKey: String)
    case exchangeStamp(givenStampID: Int)

    public var path: String {
        switch self {
        case .reveal: return "api/roam/reveal"
        case .discover: return "api/roam/poi/discover"
        case .shopVisit: return "api/roam/shop/visit"
        case .finish: return "api/roam/finish"
        case .presence: return "api/roam/presence"
        case .checkin: return "api/roam/checkin"
        case .completeNode(let id, _, _, _, _): return "api/city/nodes/\(id)/complete"
        case .toggleFavorite(let id): return "api/city/nodes/\(id)/favorite"
        case .issueVoucher: return "api/verify/citynode/issue"
        case .createStamp: return "api/roam/stamp/create"
        case .exchangeStamp: return "api/roam/stamp/exchange"
        }
    }
    /// These switches cannot be configured by a backend response, launch flag, or caller argument.
    public var productionEnabled: Bool {
        switch self {
        case .presence: return RoamExperienceCapabilities.presence
        case .issueVoucher: return RoamExperienceCapabilities.voucherIssue
        case .createStamp: return RoamExperienceCapabilities.mediaUpload
        case .exchangeStamp: return RoamExperienceCapabilities.stampExchange
        default: return false // Each action needs its own independent acceptance gate.
        }
    }
    /// MP sendFinish: keep every `ceil(n / 600)`-th point plus the last one, so at most about 600 points leave the device.
    public static func finishTrack(_ track: [RoamCoordinate]) -> [RoamCoordinate] {
        guard !track.isEmpty else { return [] }
        let step = max(1, Int((Double(track.count) / 600).rounded(.up)))
        var kept: [RoamCoordinate] = []
        for (index, point) in track.enumerated() where index % step == 0 || index == track.count - 1 {
            kept.append(point)
        }
        return kept
    }
    public func fields() throws -> [String: String] {
        func positive(_ id: Int) throws { guard id > 0 else { throw APIError.invalidRequest } }
        func coordinates(_ fix: RoamDeviceFix) throws -> [String: String] {
            guard fix.datum == .gcj02 else { throw APIError.invalidRequest }
            return ["lat": String(fix.coordinate.latitude), "lng": String(fix.coordinate.longitude)]
        }
        switch self {
        case .reveal(let id, let tiles):
            guard id >= 0, !tiles.isEmpty, tiles.allSatisfy(RoamExperienceMath.isValidTile) else { throw APIError.invalidRequest }
            return ["sessionId": String(id), "tiles": tiles.joined(separator: ",")]
        case .discover(let id, let poi, let fix):
            try positive(id); try positive(poi)
            return try coordinates(fix).merging(["sessionId": String(id), "poiId": String(poi)]) { _, new in new }
        case .shopVisit(let id, let type, let source, let fix):
            try positive(id); try positive(source); guard type == 1 || type == 2 else { throw APIError.invalidRequest }
            return try coordinates(fix).merging(["sessionId": String(id), "sourceType": String(type), "sourceId": String(source)]) { _, new in new }
        case .finish(let id, let pois, let distance, let track):
            try positive(id); guard distance >= 0, pois.allSatisfy({ $0 > 0 }) else { throw APIError.invalidRequest }
            var fields = ["sessionId": String(id), "poiIds": pois.map(String.init).joined(separator: ","), "distanceM": String(distance)]
            let points = Self.finishTrack(track)
            if points.count > 1 {
                fields["track"] = "[" + points.map { "[\($0.latitude),\($0.longitude)]" }.joined(separator: ",") + "]"
            }
            return fields
        case .presence(let id, let fix, let percent):
            try positive(id); guard (0...99).contains(percent) else { throw APIError.invalidRequest }
            return try coordinates(fix).merging(["sessionId": String(id), "explorePct": String(percent)]) { _, new in new }
        case .checkin(let name, let place, let fix):
            guard !name.isEmpty, fix.datum == .gcj02 else { throw APIError.invalidRequest }
            return ["name": name, "poiLat": String(place.latitude), "poiLng": String(place.longitude),
                    "curLat": String(fix.coordinate.latitude), "curLng": String(fix.coordinate.longitude)]
        case .completeNode(let poi, let fix, let answer, let photo, let code):
            try positive(poi)
            return try coordinates(fix).merging(["answer": answer, "photoUrl": photo, "code": code]) { _, new in new }
        case .toggleFavorite(let poi): try positive(poi); return [:]
        case .issueVoucher(let poi): try positive(poi); return ["poiId": String(poi)]
        case .createStamp(let picture, let caption, let key):
            guard !picture.isEmpty, !key.isEmpty, RoamExperienceMath.validCaption(caption),
                  !key.unicodeScalars.contains(where: { CharacterSet.controlCharacters.contains($0) }) else { throw APIError.invalidRequest }
            return ["picUrl": picture, "caption": caption, "idempotencyKey": key]
        case .exchangeStamp(let id): try positive(id); return ["givenStampId": String(id)]
        }
    }
    public func request(configuration: APIConfiguration, token: String) throws -> URLRequest {
        let fields = try fields()
        let isFavorite: Bool
        if case .toggleFavorite = self { isFavorite = true } else { isFavorite = false }
        return try AuthRequestBuilder.makeFormRequest(url: configuration.baseURL.appendingPathComponent(path), fields: fields,
                                                     token: token, includesBody: !isFavorite)
    }
}
/// Injection boundary for deterministic offline tests. Production uses RoamDormantMutationAdapter.
/// Return the source's complete JSON envelope; a code=200 alone is never a receipt of rewards.
@MainActor public protocol RoamExperienceMutationExecuting: AnyObject {
    var isAvailable: Bool { get }
    func execute(_ mutation: RoamExperienceMutation) async throws -> Data
}
/// Dormant transport adapter. Reveal, finish, presence, voucher, and the other still-off mutations
/// are denied before credentials or transport. Stamp create and exchange pass that gate and then
/// require a session; a nil session throws unauthorized and does not call the transport.
@MainActor public final class RoamDormantMutationAdapter: RoamExperienceMutationExecuting {
    public var isAvailable: Bool { false }
    private let configuration: APIConfiguration
    private let transport: any HTTPTransport
    private let currentSession: () -> RoamExperienceSession?
    public init(configuration: APIConfiguration, transport: any HTTPTransport, currentSession: @escaping () -> RoamExperienceSession?) {
        self.configuration = configuration; self.transport = transport; self.currentSession = currentSession
    }
    public func execute(_ mutation: RoamExperienceMutation) async throws -> Data {
        guard mutation.productionEnabled else { throw RoamExperienceFailure.capabilityUnavailable }
        guard let snapshot = currentSession() else { throw APIError.unauthorized }
        guard snapshot.identity.scope.deployment == configuration.baseURL.absoluteString else { throw RoamExperienceFailure.scopeMismatch }
        let request = try mutation.request(configuration: configuration, token: snapshot.mutationToken)
        try Task.checkCancellation()
        do {
            let (data, status) = try await transport.send(request)
            try Task.checkCancellation()
            guard currentSession() == snapshot else { throw CancellationError() }
            if status == 401 { throw APIError.unauthorized }
            guard (200..<300).contains(status) else { throw APIError.httpStatus(status) }
            _ = try RoamMutationReceiptDecoder.status(data)
            return data
        } catch {
            guard !Task.isCancelled, currentSession() == snapshot else { throw CancellationError() }
            throw error
        }
    }
}
public enum RoamMutationReceiptDecoder {
    private struct Status: Decodable { let code: Int }
    private struct Envelope<T: Decodable>: Decodable { let data: T }
    public static func status(_ data: Data) throws -> Int {
        guard let value = try? JSONDecoder().decode(Status.self, from: data) else { throw APIError.malformedResponse }
        if value.code == 401 { throw APIError.unauthorized }
        guard value.code == 200 else { throw APIError.businessCode(value.code) }
        return value.code
    }
    public static func value<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        _ = try status(data)
        guard let value = try? JSONDecoder().decode(Envelope<T>.self, from: data) else { throw APIError.malformedResponse }
        return value.data
    }
}
public struct RoamStampCreatedReceipt: Decodable, Equatable {
    public let id: Int
    public let idempotent: Bool
    enum CodingKeys: String, CodingKey { case id, idempotent }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(Int.self, forKey: .id)
        guard id > 0 else { throw APIError.malformedResponse }
        idempotent = try c.decodeIfPresent(Bool.self, forKey: .idempotent) ?? false
    }
}
public struct RoamStampExchangeReceipt: Decodable, Equatable {
    public let exchanged: Bool
    public let reason: String?
    public let stamp: RoamAlbumStamp?
    public let idempotent: Bool
    enum CodingKeys: String, CodingKey { case exchanged, reason, stamp, idempotent }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        exchanged = try c.decode(Bool.self, forKey: .exchanged)
        reason = try c.decodeIfPresent(String.self, forKey: .reason)
        stamp = try c.decodeIfPresent(RoamAlbumStamp.self, forKey: .stamp)
        idempotent = try c.decodeIfPresent(Bool.self, forKey: .idempotent) ?? false
        if exchanged, let stamp, !stamp.isVisible { throw APIError.malformedResponse }
    }
}
/// MP pages/roam/index.js `onPoiTap` result branches: tooFar → 离得有点远，走近点; participating + poiId → open the
/// `roam-poi-detail` scene; participating == false → 点亮 (+xp 探索值 on the first visit, else 已点亮过); any other
/// code-200 body → 这个地点暂时没有可记录的信息 (`nothingToRecord`), never a silent "already lit".
public enum RoamCheckinDisposition: Equatable {
    case tooFar
    case needsScan(poiID: Int)
    case lit(firstVisit: Bool, awardedXP: Int)
    case nothingToRecord
}
public struct RoamCheckinReceipt: Decodable, Equatable {
    public let disposition: RoamCheckinDisposition
    enum CodingKeys: String, CodingKey { case tooFar, participating, poiId, firstVisit, xp }
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        if try c.decodeIfPresent(Bool.self, forKey: .tooFar) == true { disposition = .tooFar; return }
        if try c.decodeIfPresent(Bool.self, forKey: .participating) == true {
            let poi = try c.decode(Int.self, forKey: .poiId)
            guard poi > 0 else { throw APIError.malformedResponse }
            disposition = .needsScan(poiID: poi); return
        }
        guard try c.decodeIfPresent(Bool.self, forKey: .participating) == false else { disposition = .nothingToRecord; return }
        let first = try c.decodeIfPresent(Bool.self, forKey: .firstVisit) ?? false
        let xp = try c.decodeIfPresent(Int.self, forKey: .xp) ?? 0
        guard xp >= 0 else { throw APIError.malformedResponse }
        disposition = .lit(firstVisit: first, awardedXP: first ? xp : 0)
    }
}
