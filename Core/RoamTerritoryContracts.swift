import Foundation

/// Merged Roam + CITY territory contracts. Owners earn in-game POINTS only (`revenueMode == "POINTS"`),
/// never money. GPS fixes use GCJ-02 to match the backend coordinate datum.
public enum RoamTerritoryError: Error, Equatable {
    case notCurrent
    case unauthorized
    case rejected(status: Int, code: String, message: String?)
    case malformed
}

public struct RoamTerritoryItem: Decodable, Equatable, Identifiable, Sendable {
    public let territoryId: String?
    public let poiId: Int64?
    public let boardId: String?
    public let seasonId: String?
    public let propertyId: String?
    public let pointId: String?
    public let trackIndex: Int?
    public let title: String?
    public let latitude: Double
    public let longitude: Double
    public let radiusM: Int
    public let ownerMemberId: Int64?
    public let ownerNickname: String?
    public let holderTeamId: String?
    public let claimed: Bool
    public let status: String
    public let protectedUntilMillis: Int64?
    public let isProtected: Bool
    public let claimPhotoUrl: String?
    public let checkinTollPoints: Int64
    public let ownerRevenuePoints: Int64
    public let checkinCount: Int64
    public let revenueTotalPoints: Int64
    public let distanceM: Double?

    public var id: String {
        territoryId ?? propertyId ?? pointId ?? (poiId.map { "poi-\($0)" } ?? "\(latitude),\(longitude)")
    }
}

public struct RoamTerritoryNearbyResponse: Decodable, Equatable, Sendable {
    public let boardId: String?
    public let regionId: String?
    public let seasonId: String?
    public let revenueMode: String
    public let items: [RoamTerritoryItem]
}

public struct RoamTerritoryClaimRequest: Encodable, Equatable, Sendable {
    public let requestId: String
    public let lat: Double
    public let lng: Double
    public let accuracyM: Double?
    public let photoUrl: String
    public let poiId: Int64?
    public let boardId: String?
    public let propertyId: String?
    public let pointId: String?
    public let title: String?

    public init(requestId: String = UUID().uuidString.lowercased(),
                lat: Double, lng: Double, accuracyM: Double? = nil,
                photoUrl: String, poiId: Int64? = nil, boardId: String? = nil,
                propertyId: String? = nil, pointId: String? = nil, title: String? = nil) {
        self.requestId = requestId
        self.lat = lat
        self.lng = lng
        self.accuracyM = accuracyM
        self.photoUrl = photoUrl
        self.poiId = poiId
        self.boardId = boardId
        self.propertyId = propertyId
        self.pointId = pointId
        self.title = title
    }
}

public struct RoamTerritoryClaimReceipt: Decodable, Equatable, Sendable {
    public let idempotentReplay: Bool?
    public let territoryId: String?
    public let boardId: String?
    public let seasonId: String?
    public let propertyId: String?
    public let poiId: Int64?
    public let ownerMemberId: Int64?
    public let plausibilityStatus: String?
    public let proofMethod: String?
    public let protectionSeconds: Int64?
    public let protectedUntilMillis: Int64?
}

public struct RoamTerritoryCheckinRequest: Encodable, Equatable, Sendable {
    public let requestId: String
    public let territoryId: String?
    public let poiId: Int64?
    public let lat: Double
    public let lng: Double
    public let accuracyM: Double?
    public let photoUrl: String?

    public init(requestId: String = UUID().uuidString.lowercased(),
                territoryId: String? = nil, poiId: Int64? = nil,
                lat: Double, lng: Double, accuracyM: Double? = nil, photoUrl: String? = nil) {
        self.requestId = requestId
        self.territoryId = territoryId
        self.poiId = poiId
        self.lat = lat
        self.lng = lng
        self.accuracyM = accuracyM
        self.photoUrl = photoUrl
    }
}

public struct RoamTerritoryCheckinReceipt: Decodable, Equatable, Sendable {
    public let idempotentReplay: Bool?
    public let checkinId: String?
    public let territoryId: String?
    public let ownerMemberId: Int64?
    public let selfVisit: Bool
    public let cooldownActive: Bool
    public let visitorPointsSpent: Int64
    public let ownerRevenuePoints: Int64
    public let revenueMode: String
    public let plausibilityStatus: String?
    public let distanceM: Double?
}

public struct RoamTerritoryLeaderEntry: Decodable, Equatable, Identifiable, Sendable {
    public let ownerMemberId: Int64
    public let ownerNickname: String?
    public let territoryCount: Int
    public let totalCheckins: Int64
    public let totalRevenuePoints: Int64

    public var id: Int64 { ownerMemberId }
}

public struct RoamTerritoryTopEntry: Decodable, Equatable, Identifiable, Sendable {
    public let territoryId: String
    public let title: String?
    public let boardId: String?
    public let seasonId: String?
    public let propertyId: String?
    public let poiId: Int64?
    public let ownerMemberId: Int64
    public let ownerNickname: String?
    public let checkinCount: Int64
    public let revenueTotalPoints: Int64

    public var id: String { territoryId }
}

public struct RoamTerritoryLeaderboardResponse: Decodable, Equatable, Sendable {
    public let boardId: String?
    public let seasonId: String?
    public let revenueMode: String
    public let leaders: [RoamTerritoryLeaderEntry]
    public let topTerritories: [RoamTerritoryTopEntry]
}

public struct RoamTerritoryRow: Decodable, Equatable, Identifiable, Sendable {
    public let territoryId: String
    public let poiId: Int64?
    public let boardId: String?
    public let seasonId: String?
    public let propertyId: String?
    public let pointId: String?
    public let title: String?
    public let latitude: Double?
    public let longitude: Double?
    public let radiusM: Int?
    public let ownerMemberId: Int64?
    public let claimPhotoUrl: String?
    public let checkinTollPoints: Int64?
    public let ownerRevenuePoints: Int64?
    public let revenueMode: String?
    public let checkinCount: Int64?
    public let revenueTotalPoints: Int64?
    public let status: String?
    public let version: Int64?
    public let claimedAtMillis: Int64?
    public let protectedUntilMillis: Int64?

    public var id: String { territoryId }
}
