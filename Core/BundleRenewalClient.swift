import Foundation

// MARK: - Bundle renewal intent (IWP-8b; EP-BND-23 / T-14)
// Intent only: the server records WILL_RENEW | MAYBE | NO. There is no price, no price lock, no new order,
// no payment and no notification promise anywhere in this contract.
// The backend endpoint does not exist yet (bundle-gap.md EP-BND-23 MISSING-BOTH), so this file defines the
// wire shapes and an injected service protocol whose default is "unavailable". No HTTP client is built here:
// the path/shape of `<RenewalIntent>` is not confirmed. Nothing here is wired into AppSession or composition.

public enum BundleRenewalIntent: String, Codable, Equatable, CaseIterable {
    case willRenew = "WILL_RENEW"
    case maybe = "MAYBE"
    case no = "NO"
}

/// `POST renewal-intent` body: `{ registrationId, intent, note?, idempotencyKey }`.
public struct BundleRenewalCommand: Encodable, Equatable {
    public static let noteLimit = 200
    public let registrationId: FreeExploreLaunchID
    public let intent: BundleRenewalIntent
    public let note: String?
    public let idempotencyKey: String
    /// A blank note becomes nil. A note over 200 characters is rejected, never truncated.
    public init(registrationId: FreeExploreLaunchID, intent: BundleRenewalIntent,
                note: String?, idempotencyKey: String) throws {
        let trimmed = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleaned = (trimmed?.isEmpty ?? true) ? nil : trimmed
        if let cleaned, cleaned.count > Self.noteLimit { throw FreeExploreLaunchFailure.invalid }
        guard (1...64).contains(idempotencyKey.utf8.count),
              idempotencyKey.utf8.allSatisfy({ (48...57).contains($0) || (65...90).contains($0) || (97...122).contains($0) || $0 == 45 || $0 == 95 }) else {
            throw FreeExploreLaunchFailure.invalid
        }
        self.registrationId = registrationId; self.intent = intent
        self.note = cleaned; self.idempotencyKey = idempotencyKey
    }
}

/// Server `<RenewalIntent>`. Shape is a best guess from bundle-backend-spec.md B-23; only the identity and
/// intent fields are required, everything else is optional and unknown keys (including any money key) are ignored.
public struct BundleRenewalRecord: Decodable, Equatable {
    public let id: FreeExploreLaunchID
    public let registrationId: FreeExploreLaunchID
    public let holderMemberId: FreeExploreLaunchID?
    /// Kept as a string: an unknown server value is shown as unrecognised, never mapped to a guess.
    public let intent: String
    public let note: String?
    public let supersedesId: FreeExploreLaunchID?
    public let idempotencyKey: String?
    public let createTime: BundleTimestamp?
    public var knownIntent: BundleRenewalIntent? { BundleRenewalIntent(rawValue: intent) }
}

/// Injected seam. No production implementation exists until the backend ships EP-BND-23.
@MainActor public protocol BundleRenewalServing: AnyObject {
    var isCurrent: Bool { get }
    var permitsWrites: Bool { get }
    /// `nil` means the holder has not recorded an intent yet.
    func latestIntent(registrationID: FreeExploreLaunchID) async throws -> BundleRenewalRecord?
    func submitIntent(_ command: BundleRenewalCommand) async throws -> BundleRenewalRecord
}

/// Default: every call fails with `.disabled`. Returns no data and never fabricates any.
@MainActor public final class BundleRenewalUnavailableService: BundleRenewalServing {
    public init() {}
    public var isCurrent: Bool { true }
    public var permitsWrites: Bool { false }
    public func latestIntent(registrationID: FreeExploreLaunchID) async throws -> BundleRenewalRecord? {
        throw FreeExploreLaunchFailure.disabled
    }
    public func submitIntent(_ command: BundleRenewalCommand) async throws -> BundleRenewalRecord {
        throw FreeExploreLaunchFailure.disabled
    }
}
