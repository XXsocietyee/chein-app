import Foundation

/// One UGC review publish. The request id is minted once and reused for that draft.
/// An unknown outcome stays locked on that id; a different draft does not send.
public struct RoamPlaceReviewAttempt: Equatable {
    public var requestID: String?
    public var stars: Int
    public var text: String
    public var locked: Bool

    public static let idle = RoamPlaceReviewAttempt(requestID: nil, stars: 0, text: "", locked: false)

    public init(requestID: String? = nil, stars: Int = 0, text: String = "", locked: Bool = false) {
        self.requestID = requestID
        self.stars = stars
        self.text = text
        self.locked = locked
    }

    public enum Decision: Equatable {
        case send(requestID: String, stars: Int, text: String)
        case hold
    }

    public enum Outcome: Equatable {
        case published, rejected, notSent, unknown
    }

    /// `text` is trimmed here. Invalid input holds without minting an id.
    public func begin(stars: Int, text: String, makeRequestID: () -> String) -> (RoamPlaceReviewAttempt, Decision) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (1...5).contains(stars), !trimmed.isEmpty, trimmed.utf16.count <= 200 else { return (self, .hold) }
        if locked {
            guard let requestID, stars == self.stars, trimmed == self.text else { return (self, .hold) }
            return (self, .send(requestID: requestID, stars: stars, text: trimmed))
        }
        let id = requestID ?? makeRequestID()
        let next = RoamPlaceReviewAttempt(requestID: id, stars: stars, text: trimmed, locked: false)
        return (next, .send(requestID: id, stars: stars, text: trimmed))
    }

    /// Unknown keeps the id. A known result (published, rejected, or not sent) clears it.
    public func resolve(_ outcome: Outcome) -> RoamPlaceReviewAttempt {
        switch outcome {
        case .published, .rejected, .notSent:
            return .idle
        case .unknown:
            guard requestID != nil else { return .idle }
            var copy = self
            copy.locked = true
            return copy
        }
    }
}

/// Process-lifetime lock so a reopened place card retries the same id. Not a credential store.
@MainActor public enum RoamPlaceReviewLockStore {
    private static var values: [String: RoamPlaceReviewAttempt] = [:]

    public static func read(accountID: Int, poiID: Int) -> RoamPlaceReviewAttempt {
        guard accountID > 0, poiID > 0, let stored = values[key(accountID, poiID)], stored.locked else { return .idle }
        return stored
    }

    public static func write(accountID: Int, poiID: Int, _ attempt: RoamPlaceReviewAttempt) {
        guard accountID > 0, poiID > 0 else { return }
        let key = key(accountID, poiID)
        if attempt.locked, attempt.requestID != nil { values[key] = attempt }
        else { values.removeValue(forKey: key) }
    }

    private static func key(_ accountID: Int, _ poiID: Int) -> String { "\(accountID):\(poiID)" }
}
