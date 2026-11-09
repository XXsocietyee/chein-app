import Foundation

/// P8 `GET /api/play/player-journey/memory`.
/// Moments are counted, not copied, so another person's photo address cannot be shown.
/// `NO_PRIVATE_PHOTO_SHARE_CONSENT_FACT`, and a missing consent fact, keep other private photos hidden.
/// An unknown participant count is an em dash. It is not "no companions" and it is not 0.
/// The read does not publish, grant a reward, or open a friend relationship.

public struct PWaveRunMemoryFact: Equatable, Sendable {
    public static let noPhotoAssociationCopy = "暂无照片"
    public static let consentAbsentToken = "NO_PRIVATE_PHOTO_SHARE_CONSENT_FACT"

    public let momentCount: Int?
    public let participantCount: PWaveNumberFact
    public let identityPolicy: String?
    public let photoShareCapability: String?
    public let consentFactAbsent: Bool

    public var momentCountText: String { PWaveCountText.text(momentCount) }
    public var participantText: String { participantCount.displayText }
    public var noCompanions: Bool { participantCount.literal == 0 }
    public var showsNoPhotoAssociation: Bool { momentCount == nil || momentCount == 0 }
    public var otherPrivatePhotosVisible: Bool { false }
    public var createsFriendRelation: Bool { false }
    public var mixesAccountAlbum: Bool { false }
    public var publicSharePerformed: Bool { false }

    public init(momentCount: Int?, participantCount: PWaveNumberFact, identityPolicy: String?,
                photoShareCapability: String?, consentFactAbsent: Bool) {
        self.momentCount = momentCount
        self.participantCount = participantCount
        self.identityPolicy = identityPolicy
        self.photoShareCapability = photoShareCapability
        self.consentFactAbsent = consentFactAbsent
    }
}

public struct PWaveThemeHistoryFact: Equatable, Sendable {
    public let sessionIDs: [String]
    public var fillsCurrentContent: Bool { false }
    public var opensAnotherRunOnMismatch: Bool { false }

    public init(sessionIDs: [String]) {
        self.sessionIDs = sessionIDs
    }
}

public enum PWaveRunMemory {
    public static func decode(data: Data, status: Int, supported: Set<String>) -> PWavePresentation<PWaveRunMemoryFact> {
        PWaveServerCapability.presentation(data: data, status: status, supported: supported) { root, payload in
            fact(payload, consentWalk: root)
        }
    }

    public static func decodeHistory(data: Data, status: Int, supported: Set<String>) -> PWavePresentation<PWaveThemeHistoryFact> {
        PWaveServerCapability.presentation(data: data, status: status, supported: supported) { _, payload in
            history(payload)
        }
    }

    static func fact(_ payload: PlayWireValue, consentWalk: PlayWireValue) -> PWaveServerFact<PWaveRunMemoryFact> {
        guard let object = payload.object else { return .unknown }
        let moments = PWaveCountText.arrayCount(object, "moments")
        let participants = object.keys.contains("participantCount")
            ? PWaveNumberFact.parse(object["participantCount"] ?? .null) : .unknown
        let policy = PWaveEnvelope.text(object["identityPolicy"] ?? .null)
        let share = PWaveEnvelope.text(object["photoShareCapability"] ?? .null)
        let tokenPresent = PWaveWalk.contains(PWaveRunMemoryFact.consentAbsentToken, in: consentWalk)
        let consentAbsent = share == nil || share == PWaveRunMemoryFact.consentAbsentToken || tokenPresent
        let classified = object.keys.contains("moments") || object.keys.contains("participantCount")
            || policy != nil || share != nil || tokenPresent
        guard classified else { return .unknown }
        return .ready(PWaveRunMemoryFact(momentCount: moments, participantCount: participants,
                                         identityPolicy: policy, photoShareCapability: share,
                                         consentFactAbsent: consentAbsent))
    }

    static func history(_ payload: PlayWireValue) -> PWaveServerFact<PWaveThemeHistoryFact> {
        guard case .array(let items) = payload else { return .unknown }
        if items.isEmpty { return .empty }
        var ids: [String] = []
        for item in items {
            guard let object = item.object, object.keys.contains("sessionId") else { return .unknown }
            switch PWaveIdentifierFact.parse(object["sessionId"] ?? .null) {
            case .text(let raw): ids.append(raw)
            case .integer(let number): ids.append(String(number))
            case .unknown: return .unknown
            }
        }
        return .ready(PWaveThemeHistoryFact(sessionIDs: ids))
    }
}
