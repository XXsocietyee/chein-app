import Foundation

public enum WorkshopCommerceIssue: Error { case disabled, invalid, staleSession, unavailable, malformed, unauthorized, pendingConflict, storageUnavailable }
public struct WorkshopCommerceTerms: Codable, Equatable {
    public let version, hash, contentHash: String
    public let commercialUse: Bool
    public let allowedRegions: [String]
    public let installationLimit: Int64
    public let useDuration, updatePolicy, redistribution, refundPolicyReference: String
    /// Original server-issued scope, not a client license or a new grant. Legacy terms omit it.
    public let compositionRights: WorkshopCommerceCompositionRights?
    public init(version: String, hash: String, contentHash: String, commercialUse: Bool, allowedRegions: [String],
                installationLimit: Int64, useDuration: String, updatePolicy: String, redistribution: String,
                refundPolicyReference: String, compositionRights: WorkshopCommerceCompositionRights? = nil) {
        self.version = version; self.hash = hash; self.contentHash = contentHash; self.commercialUse = commercialUse
        self.allowedRegions = allowedRegions; self.installationLimit = installationLimit; self.useDuration = useDuration
        self.updatePolicy = updatePolicy; self.redistribution = redistribution; self.refundPolicyReference = refundPolicyReference
        self.compositionRights = compositionRights
    }
}
/// Exact consumer of ModCompositionRights.Grant/Proposal. IDs and booleans are displayed as
/// frozen scope, never converted to current venue consent, installation quota or runtime authority.
public struct WorkshopCommerceCompositionRights: Codable, Equatable {
    public struct Scope: Codable, Equatable {
        public let authors, installationSubjects, venues: [Int64]
        public let regions: [String]
        public let commercialUse, translation, adaptation, remix, embeddedRedistribution: Bool
        public let evidenceReferences: [String]
        public let venueScopeVersion: String?
        public let venuePoiIds: [Int64]?
    }
    public let profile, applicationRequestId, decisionId: String
    public let author, reviewer: Int64
    public let sourceKind: String
    public let sourceId, auditTaskId: Int64
    public let sourceHash, draftHash, packageId, packageVersion, releaseId, contentHash: String
    public let scope: Scope
    public let approvedAt, grantHash: String
    public var hasExplicitPhysicalVenues: Bool {
        scope.venueScopeVersion == "original-owned-poi-v1" && scope.venuePoiIds?.isEmpty == false
    }
    /// Structural/identity checks only. The original server remains the signature, rights and
    /// current-use authority. An unknown profile must not silently drop its restrictions.
    public func matches(_ offer: WorkshopCommerceOffer) -> Bool {
        matches(releaseId: offer.releaseId, contentHash: offer.terms.contentHash, creatorId: offer.creatorId,
                allowedRegions: offer.terms.allowedRegions, commercialUse: offer.terms.commercialUse)
    }
    /// The upgrade reader carries the same frozen terms, not a synthetic purchase offer.
    public func matches(releaseId expectedRelease: String, contentHash expectedContent: String, creatorId: Int64,
                        allowedRegions: [String], commercialUse: Bool) -> Bool {
        func ids(_ values: [Int64]) -> Bool {
            !values.isEmpty && values.count <= 128 && values.allSatisfy { $0 > 0 } && Set(values).count == values.count
        }
        func digest(_ value: String) -> Bool { value.range(of: #"\A[0-9a-f]{64}\z"#, options: .regularExpression) != nil }
        let physicalScopeValid = (scope.venueScopeVersion == nil && scope.venuePoiIds == nil) ||
            (hasExplicitPhysicalVenues && scope.venuePoiIds.map(ids) == true)
        return profile == "first-party-h5-composition-rights-v1" && author == creatorId && author > 0 && reviewer > 0 && author != reviewer &&
            sourceId > 0 && auditTaskId > 0 && ["TEMPLATE", "TOPIC"].contains(sourceKind) &&
            releaseId == expectedRelease && contentHash == expectedContent &&
            [sourceHash, draftHash, contentHash, grantHash].allSatisfy(digest) &&
            ids(scope.authors) && ids(scope.installationSubjects) && ids(scope.venues) && physicalScopeValid &&
            !scope.regions.isEmpty && scope.regions.count <= 32 && Set(scope.regions).count == scope.regions.count &&
            Set(scope.regions).isSubset(of: Set(allowedRegions)) &&
            (!scope.commercialUse || commercialUse) && scope.remix && scope.embeddedRedistribution &&
            !scope.evidenceReferences.isEmpty && scope.evidenceReferences.count <= 32
    }
}
public struct WorkshopCommerceOffer: Decodable, Equatable {
    public let offerId, moduleId, releaseId: String
    public let creatorId: Int64
    public let title, currency: String
    public let priceMinor: Int64
    public let platform, market, productType, channel: String?
    public let terms: WorkshopCommerceTerms
    public var hasSupportedTerms: Bool { terms.compositionRights?.matches(self) ?? true }
}
public struct WorkshopCommerceIntent: Codable, Equatable {
    public let requestId, offerId, termsHash: String
    public init(requestId: String, offerId: String, termsHash: String) { self.requestId=requestId; self.offerId=offerId; self.termsHash=termsHash }
    public init(offer: WorkshopCommerceOffer) { requestId = UUID().uuidString.lowercased(); offerId = offer.offerId; termsHash = offer.terms.hash }
}
public struct WorkshopCommerceOrder: Codable, Equatable {
    public enum State: String, Codable { case created = "CREATED", nativeReady = "NATIVE_READY", submitting = "SUBMITTING", awaitingPayment = "AWAITING_PAYMENT", unknown = "UNKNOWN", paid = "PAID", acquiredFree = "ACQUIRED_FREE", cancelled = "CANCELLED" }
    public let orderKey, requestId, offerId: String
    public let state: State
    public let licenseId: String?
    public let amountMinor: Int64
    public let currency: String
    public let cancellationRequested: Bool
    public let paymentParameters: [String: String]
    public var terminal: Bool { state == .paid || state == .acquiredFree || state == .cancelled }
}
public struct WorkshopCommerceLicense: Decodable, Equatable, Identifiable {
    public let licenseId, orderKey, moduleId, purchasedVersionId, acquisition, status, acquiredAt: String
    public let terms: WorkshopCommerceTerms
    public let usedInstallations: Int64
    public let suspensionReason: String?
    public let published, executable: Bool
    public var id: String { licenseId }
}
/// A buyer-owned receipt joined to its ORIGINAL order offer, never today's catalog price or terms.
/// License status/usage may change; acquired version, price and terms remain the frozen grant.
public struct WorkshopCommerceLicenseSnapshot: Equatable {
    public let license: WorkshopCommerceLicense
    public let order: WorkshopCommerceOrder
    public let offer: WorkshopCommerceOffer
    public init(license: WorkshopCommerceLicense, order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) throws {
        guard order.state == .paid || order.state == .acquiredFree,
              order.licenseId == license.licenseId, order.orderKey == license.orderKey,
              order.offerId == offer.offerId, order.amountMinor == offer.priceMinor, order.currency == offer.currency,
              license.moduleId == offer.moduleId, license.purchasedVersionId == offer.releaseId,
              license.terms == offer.terms, offer.hasSupportedTerms,
              license.acquisition == (order.state == .paid ? "PAID" : "FREE"),
              (order.state == .acquiredFree ? order.amountMinor == 0 : order.amountMinor > 0),
              ["ACTIVE", "SUSPENDED", "REVOKED"].contains(license.status), license.usedInstallations >= 0,
              !license.published, !license.executable else { throw WorkshopCommerceIssue.malformed }
        self.license = license; self.order = order; self.offer = offer
    }
}
/// Narrow controller dependency for deterministic interrupted-flow tests. Production still uses
/// the isolated owner/approval-fenced WorkshopCommerceService; this is not a second transport.
@MainActor public protocol WorkshopCommerceServing: AnyObject {
    var canAcquire: Bool { get }
    var canCancelOrder: Bool { get }
    var canReadReversalStatus: Bool { get }
    var canReadOwnedRelease: Bool { get }
    func ownedReleaseRecord(_ licenseID: String) async throws -> WorkshopOwnedReleaseRecord
    func reversalStatus(_ orderKey: String) async throws -> WorkshopBuyerReversalStatus
    func permitsPurchase(_ offer: WorkshopCommerceOffer) -> Bool
    func checkSession() throws
    func invalidate()
    func offers(before: String?) async throws -> [WorkshopCommerceOffer]
    func offer(_ id: String) async throws -> WorkshopCommerceOffer
    func create(_ intent: WorkshopCommerceIntent, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder
    func lookupRequest(_ id: String) async throws -> WorkshopCommercePurchaseLookup
    func orderOffer(_ key: String) async throws -> WorkshopCommerceOffer
    func order(_ key: String) async throws -> WorkshopCommerceOrder
    func startPayment(_ order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder
    func verifiedLicense(_ order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer, requireActive: Bool) async throws -> WorkshopCommerceLicense
    func reconcile(_ key: String) async throws -> WorkshopCommerceOrder
    func cancelRequest(_ intent: WorkshopCommerceIntent) async throws -> WorkshopCommerceOrder
    func licenses(before: String?) async throws -> [WorkshopCommerceLicense]
    func license(_ id: String) async throws -> WorkshopCommerceLicense
    func reserve(_ command: WorkshopCommerceInstall) async throws -> WorkshopCommerceReservation
}
public struct WorkshopBuyerReversalStatus: Decodable, Equatable {
    public struct Item: Decodable, Equatable { public let reversalKey, requestId, kind, state: String; public let buyerMinor: Int64; public let queryObservation, queryAttemptedAt: String?; public let queryAttempted: Bool? }
    public let schema, orderKey, offerId, moduleId, releaseId, contentHash, termsHash, currency, orderState: String
    public let licenseId, licenseState: String?
    public let totalMinor, refundedBuyerMinor, chargedBackBuyerMinor, revision: Int64
    public let cancellationRequested: Bool
    public let reversals: [Item]
    public let chargebackQueryCapability: String?
    public func matches(_ snapshot: WorkshopCommerceLicenseSnapshot) -> Bool {
        schema == "mod-buyer-reversal-status-v1" && orderKey == snapshot.order.orderKey && offerId == snapshot.offer.offerId &&
        licenseId == snapshot.license.licenseId && moduleId == snapshot.license.moduleId && releaseId == snapshot.license.purchasedVersionId &&
        contentHash == snapshot.license.terms.contentHash && termsHash == snapshot.license.terms.hash && currency == snapshot.order.currency &&
        WorkshopCommerceOrder.State(rawValue: orderState) != nil && totalMinor == snapshot.order.amountMinor && refundedBuyerMinor >= 0 && chargedBackBuyerMinor >= 0 &&
        refundedBuyerMinor <= totalMinor && chargedBackBuyerMinor <= totalMinor - refundedBuyerMinor && revision >= 0 &&
        ["ACTIVE", "SUSPENDED", "REVOKED"].contains(licenseState ?? "") && reversals.count <= 100 &&
        Set(reversals.map(\.reversalKey)).count == reversals.count && reversals.allSatisfy {
            !$0.reversalKey.isEmpty && !$0.requestId.isEmpty && ["REFUND", "CHARGEBACK"].contains($0.kind) &&
            ["PREPARED", "SUBMITTING", "UNKNOWN", "PROCESSING", "SUCCEEDED", "REJECTED"].contains($0.state) && $0.buyerMinor > 0 && $0.buyerMinor <= totalMinor
        }
    }
}
public extension WorkshopCommerceServing {
    var canCancelOrder: Bool { false }
    var canReadReversalStatus: Bool { false }
    var canReadOwnedRelease: Bool { false }
    func ownedReleaseRecord(_ licenseID: String) async throws -> WorkshopOwnedReleaseRecord { throw WorkshopCommerceIssue.disabled }
    func reversalStatus(_ orderKey: String) async throws -> WorkshopBuyerReversalStatus { throw WorkshopCommerceIssue.disabled }
}
public struct WorkshopCommerceInstall: Codable, Equatable {
    public let requestId, licenseId, releaseId, contentHash, termsHash, region: String
    public let commercialUse: Bool
    public let targetType: String
    public let targetId, targetRevision: Int64
    public let targetPayloadHash: String
}
public struct WorkshopCommerceReservation: Decodable {
    public let requestId, state, licenseId, releaseId, expiresAt: String
    public let targetId: Int64
    public let published, executable: Bool
}
/// Separately supplied reviewed deployment decision. Login, existing metadata approval or SDK availability never create one.
public struct WorkshopCommerceApproval {
    public let revision = UUID()
    public let context: RuntimeDependencyContext
    public let expiresAt: Date
    public let readApprovalReference: String
    public let cancellationApprovalReference, reversalStatusReadApprovalReference: String?
    public let ownedReleaseReadApprovalReference: String?
    public let digitalPurchaseApprovalReference: String?
    public let installApprovalReference: String?
    public let platform, market, productType, channel: String
    /// Reviewed app/product identity, not populated from server parameters or device language.
    /// Empty values keep native StoreKit launch off even when read access is approved.
    public let storeKitBundleID: String?
    public let storeKitProductIDs: Set<String>
    public let storeKitEnvironment: String?
    public init(context: RuntimeDependencyContext, expiresAt: Date, readApprovalReference: String,
                digitalPurchaseApprovalReference: String? = nil, installApprovalReference: String? = nil, platform: String, market: String, productType: String, channel: String,
                storeKitBundleID: String? = nil, storeKitProductIDs: Set<String> = [], storeKitEnvironment: String? = nil, cancellationApprovalReference: String? = nil, reversalStatusReadApprovalReference: String? = nil, ownedReleaseReadApprovalReference: String? = nil) throws {
        _ = try APIConfiguration(baseURL: context.baseURL)
        guard context.session.accountID > 0, !readApprovalReference.isEmpty, expiresAt.timeIntervalSince1970.isFinite,
              platform == "IOS", ["CN", "US"].contains(market), context.market.rawValue == market,
              productType == "DIGITAL_MOD", channel == "APPLE_STOREKIT",
              storeKitEnvironment == nil || WorkshopStoreKitEnvironment.admits(storeKitEnvironment) else { throw WorkshopCommerceIssue.invalid }
        for reference in [cancellationApprovalReference, reversalStatusReadApprovalReference, ownedReleaseReadApprovalReference].compactMap({ $0 }) {
            guard !reference.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { throw WorkshopCommerceIssue.invalid }
        }
        self.ownedReleaseReadApprovalReference = ownedReleaseReadApprovalReference
        self.cancellationApprovalReference = cancellationApprovalReference; self.reversalStatusReadApprovalReference = reversalStatusReadApprovalReference
        self.context = context; self.expiresAt = expiresAt; self.readApprovalReference = readApprovalReference
        self.digitalPurchaseApprovalReference = digitalPurchaseApprovalReference; self.installApprovalReference = installApprovalReference
        self.platform = platform; self.market = market; self.productType = productType; self.channel = channel
        self.storeKitBundleID = storeKitBundleID; self.storeKitProductIDs = storeKitProductIDs
        self.storeKitEnvironment = storeKitEnvironment
    }
    public func matches(_ context: RuntimeDependencyContext) -> Bool {
        ContentDraftContextFence.matches(self.context, context) && self.context.session.role == context.session.role && context.market.rawValue == market && Date() < expiresAt
    }
    public func recognizes(_ offer: WorkshopCommerceOffer) -> Bool {
        offer.platform == platform && offer.market == market && offer.productType == productType && offer.channel == channel
    }
    public func permits(_ offer: WorkshopCommerceOffer) -> Bool {
        guard let reference = digitalPurchaseApprovalReference, !reference.isEmpty else { return false }
        guard offer.hasSupportedTerms, offer.priceMinor >= 0, offer.currency == (market == "CN" ? "CNY" : "USD") else { return false }
        return offer.priceMinor == 0 || recognizes(offer)
    }
}

/// Workshop MODs are digital goods sold through StoreKit IAP only. Release admits the App Store `PRODUCTION`
/// environment alone; a DEBUG/TEST build also admits the App Store `SANDBOX` (the TEST backend verifies sandbox
/// transactions against its own configured environment). Local Xcode testing uses `Config/QuestifyWorkshopSandbox.storekit`.
public enum WorkshopStoreKitEnvironment {
    public static func admits(_ value: String?) -> Bool {
        if value == "PRODUCTION" { return true }
        #if DEBUG || TEST
        return value == "SANDBOX"
        #else
        return false
        #endif
    }
}

/// Read-only server context is fetched again for recovery. Never persist this token or any JWS.
public struct WorkshopStoreKitParameters: Equatable {
    public let orderKey, productID, bundleID, storefront: String
    public let appAccountToken: UUID
    public init(_ values: [String: String], order: WorkshopCommerceOrder, approval: WorkshopCommerceApproval) throws {
        guard values["channel"] == "APPLE_STOREKIT", WorkshopStoreKitEnvironment.admits(values["environment"]),
              values["environment"] == approval.storeKitEnvironment, values["orderKey"] == order.orderKey,
              let productID = values["productId"], !productID.isEmpty, approval.storeKitProductIDs.contains(productID),
              let bundleID = values["bundleId"], !bundleID.isEmpty, bundleID == approval.storeKitBundleID,
              let rawToken = values["appAccountToken"], let token = UUID(uuidString: rawToken),
              rawToken.lowercased() == token.uuidString.lowercased(),
              token != UUID(uuidString: "00000000-0000-0000-0000-000000000000"),
              let storefront = values["storefront"], storefront == (approval.market == "CN" ? "CHN" : "USA"),
              order.amountMinor > 0, order.currency == (approval.market == "CN" ? "CNY" : "USD") else {
            throw WorkshopCommerceIssue.malformed
        }
        self.orderKey = order.orderKey; self.productID = productID; self.bundleID = bundleID
        self.storefront = storefront; self.appAccountToken = token
    }
}
public struct WorkshopCommercePurchaseLookup: Decodable {
    public let found: Bool
    public let order: WorkshopCommerceOrder?
}
public struct WorkshopCommerceNativeDispatch: Decodable {
    public let orderKey: String
    public let dispatchAllowed: Bool
}
/// A StoreKit transaction is only evidence for server verification, never a license authority.
@MainActor public protocol WorkshopCommerceNativePurchasing: AnyObject {
    func startUpdates(_ onUpdate: @escaping @MainActor () async -> Void)
    func invalidate()
    func restoreOwned() async throws
    func purchase(order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder?
    /// Returns only after backend PAID + real matching license + Transaction.finish(). No match returns nil.
    func recover(order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder?
}

/// Current original release record, not a launch/install permission and never inferred from refunds.
public struct WorkshopOwnedReleaseRecord: Decodable, Equatable {
    public let schema, licenseId, moduleId, releaseId, contentHash, termsHash: String
    public let licenseState, useDuration, artifactStatus, scope, runtimeAuthorization: String
    public let artifactIdentityMatched: Bool
    public let blockReason: String?
    public func matches(_ snapshot: WorkshopCommerceLicenseSnapshot) -> Bool {
        schema == "mod-owned-release-record-v1" && scope == "ORIGINAL_PURCHASED_ARTIFACT_RECORD_ONLY" &&
        runtimeAuthorization == "REQUIRES_ORIGINAL_CURRENT_RUNTIME_CHECKS" && licenseId == snapshot.license.licenseId &&
        moduleId == snapshot.license.moduleId && releaseId == snapshot.license.purchasedVersionId &&
        contentHash == snapshot.license.terms.contentHash && termsHash == snapshot.license.terms.hash && useDuration == snapshot.license.terms.useDuration &&
        ["ACTIVE", "SUSPENDED", "REVOKED", "UNKNOWN"].contains(licenseState) && !artifactStatus.isEmpty
    }
}
