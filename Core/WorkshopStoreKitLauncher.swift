import Foundation
#if canImport(StoreKit) && os(iOS)
import StoreKit
#endif

/// Default-off, iOS-only digital-goods launcher. It never uses the physical-goods WeChat driver.
@MainActor public enum WorkshopStoreKitFactory {
    public static func make(service: WorkshopCommerceService, approval: WorkshopCommerceApproval) -> (any WorkshopCommerceNativePurchasing)? {
        #if canImport(StoreKit) && os(iOS)
        guard !approval.readApprovalReference.isEmpty,
              approval.channel == "APPLE_STOREKIT", WorkshopStoreKitEnvironment.admits(approval.storeKitEnvironment),
              let bundleID = approval.storeKitBundleID, !bundleID.isEmpty,
              Bundle.main.bundleIdentifier == bundleID, !approval.storeKitProductIDs.isEmpty,
              (try? service.checkSession()) != nil else { return nil }
        return WorkshopStoreKitLauncher(service: service, approval: approval)
        #else
        return nil
        #endif
    }
}

#if canImport(StoreKit) && os(iOS)
@MainActor private final class WorkshopStoreKitLauncher: WorkshopCommerceNativePurchasing {
    private let service: WorkshopCommerceService
    private let approval: WorkshopCommerceApproval
    private var updates: Task<Void, Never>?
    private var revoked = false
    init(service: WorkshopCommerceService, approval: WorkshopCommerceApproval) {
        self.service = service; self.approval = approval
    }
    deinit { updates?.cancel() }
    func invalidate() { revoked = true; updates?.cancel(); updates = nil }
    private func check() throws {
        guard !revoked else { throw WorkshopCommerceIssue.staleSession }
        try service.checkSession()
    }
    func startUpdates(_ onUpdate: @escaping @MainActor () async -> Void) {
        guard updates == nil, !revoked else { return }
        updates = Task { [weak self] in
            for await _ in StoreKit.Transaction.updates {
                guard !Task.isCancelled, let self else { return }
                do { try self.check() } catch { return }
                // A wake-up only: recovery must re-fetch the original server-owned context,
                // then match its account token. Do not grant or finish from this callback.
                await onUpdate()
            }
        }
    }
    private func parameters(_ values: [String: String], order: WorkshopCommerceOrder,
                            offer: WorkshopCommerceOffer) throws -> WorkshopStoreKitParameters {
        try check()
        guard approval.recognizes(offer), offer.channel == "APPLE_STOREKIT",
              offer.platform == "IOS", offer.market == approval.market, offer.productType == "DIGITAL_MOD",
              order.offerId == offer.offerId, order.amountMinor == offer.priceMinor,
              order.currency == offer.currency else { throw WorkshopCommerceIssue.disabled }
        let value = try WorkshopStoreKitParameters(values, order: order, approval: approval)
        guard Bundle.main.bundleIdentifier == value.bundleID else { throw WorkshopCommerceIssue.disabled }
        return value
    }
    func purchase(order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder? {
        guard approval.permits(offer), order.state == .nativeReady, !order.cancellationRequested else { throw WorkshopCommerceIssue.disabled }
        let context = try parameters(order.paymentParameters, order: order, offer: offer)
        // Resolve an existing non-consumable before asking Apple to purchase. A receipt with an
        // older account token must recover its original server order, never bind to this new one.
        for await existing in StoreKit.Transaction.currentEntitlements {
            try check()
            if case .verified(let transaction) = existing, transaction.productID == context.productID {
                return try await restoreExisting(existing, expectedOffer: offer)
            }
        }
        guard AppStore.canMakePayments else { throw WorkshopCommerceIssue.unavailable }
        try check()
        let products = try await Product.products(for: [context.productID])
        try check()
        guard products.count == 1, let product = products.first, product.id == context.productID,
              product.type == .nonConsumable, product.priceFormatStyle.currencyCode == order.currency,
              product.price == Decimal(order.amountMinor) / Decimal(100),
              let storefront = await Storefront.current, storefront.countryCode == context.storefront else {
            throw WorkshopCommerceIssue.malformed
        }
        try check()
        // Server-persisted, single-use gate. A timeout/false/unknown result NEVER dispatches purchase.
        guard try await service.nativeDispatch(order, offer: offer) else {
            return try await recover(order: order, offer: offer)
        }
        try check()
        guard let storefront = await Storefront.current, storefront.countryCode == context.storefront else {
            throw WorkshopCommerceIssue.malformed
        }
        try check()
        let result = try await product.purchase(options: [.appAccountToken(context.appAccountToken), .quantity(1)])
        try check()
        switch result {
        case .success(let verification):
            if case .verified(let transaction) = verification, transaction.appAccountToken != context.appAccountToken {
                return try await restoreExisting(verification, expectedOffer: offer)
            }
            return try await submit(verification, context: context, order: order, offer: offer)
        case .pending, .userCancelled:
            // Neither cancellation nor Ask to Buy proves the provider outcome. Keep the server gate
            // and durable original intent unresolved; later recovery must never call purchase again.
            return nil
        @unknown default:
            return nil
        }
    }
    func restoreOwned() async throws {
        try check(); var seen = Set<UInt64>(); var unavailable = false
        for await result in StoreKit.Transaction.unfinished {
            try check()
            guard case .verified(let transaction) = result, approval.storeKitProductIDs.contains(transaction.productID), seen.insert(transaction.id).inserted else { continue }
            do { _ = try await restoreExisting(result, expectedOffer: nil) } catch { unavailable = true }
        }
        for await result in StoreKit.Transaction.currentEntitlements {
            try check()
            guard case .verified(let transaction) = result, approval.storeKitProductIDs.contains(transaction.productID), seen.insert(transaction.id).inserted else { continue }
            do { _ = try await restoreExisting(result, expectedOffer: nil) } catch { unavailable = true }
        }
        if unavailable { throw WorkshopCommerceIssue.unavailable }
    }
    private func restoreExisting(_ verification: VerificationResult<StoreKit.Transaction>, expectedOffer: WorkshopCommerceOffer?) async throws -> WorkshopCommerceOrder {
        try check()
        guard case .verified(let transaction) = verification, approval.storeKitProductIDs.contains(transaction.productID),
              transaction.productType == .nonConsumable, transaction.ownershipType == .purchased,
              transaction.appBundleID == approval.storeKitBundleID, transaction.environment == .production,
              transaction.storefront.countryCode == (approval.market == "CN" ? "CHN" : "USA"), transaction.appAccountToken != nil else { throw WorkshopCommerceIssue.malformed }
        // No client UUID lookup and no adoption across accounts. The server verifies signatures,
        // resolves its own token, checks buyer ownership, then does a fresh signed Apple lookup.
        let original = try await service.restoreNative(signedTransaction: verification.jwsRepresentation)
        let frozen = try await service.orderOffer(original.orderKey)
        guard approval.recognizes(frozen), expectedOffer == nil || frozen == expectedOffer else { throw WorkshopCommerceIssue.malformed }
        let context = try WorkshopStoreKitParameters(try await service.nativeContext(original), order: original, approval: approval)
        guard context.productID == transaction.productID, context.appAccountToken == transaction.appAccountToken else { throw WorkshopCommerceIssue.malformed }
        let license = try await service.verifiedLicense(original, offer: frozen, requireActive: false)
        guard (license.status == "ACTIVE" && transaction.revocationDate == nil) || (license.status == "REVOKED" && transaction.revocationDate != nil) else { throw WorkshopCommerceIssue.unavailable }
        try check(); await transaction.finish(); try check(); return original
    }
    func recover(order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder? {
        try check()
        guard order.amountMinor > 0, order.state != .cancelled, order.state != .created, offer.channel == "APPLE_STOREKIT" else { return nil }
        let values = try await service.nativeContext(order)
        let context = try parameters(values, order: order, offer: offer)
        // StoreKit owns the durable queue. No client purchased/dispatched flag, JWS, token or
        // substitute receipt is persisted. Recovery never asks StoreKit to buy the product again.
        for await result in StoreKit.Transaction.unfinished {
            try check()
            if let observed = try await submit(result, context: context, order: order, offer: offer) { return observed }
        }
        for await result in StoreKit.Transaction.currentEntitlements {
            try check()
            if let observed = try await submit(result, context: context, order: order, offer: offer) { return observed }
        }
        return nil
    }
    private func submit(_ verification: VerificationResult<StoreKit.Transaction>, context: WorkshopStoreKitParameters,
                        order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder? {
        try check()
        // Local verification is a defense-in-depth filter, NOT ownership/payment authority.
        guard case .verified(let transaction) = verification,
              transaction.appAccountToken == context.appAccountToken,
              transaction.productID == context.productID, transaction.productType == .nonConsumable,
              transaction.appBundleID == context.bundleID, transaction.environment == .production,
              transaction.storefront.countryCode == context.storefront,
              transaction.ownershipType == .purchased else { return nil }
        let observed = try await service.nativeTransaction(order, signedTransaction: verification.jwsRepresentation)
        try check()
        guard observed.state == .paid, observed.orderKey == order.orderKey,
              observed.requestId == order.requestId, observed.offerId == order.offerId,
              observed.amountMinor == order.amountMinor, observed.currency == order.currency else {
            throw WorkshopCommerceIssue.unavailable
        }
        // Backend performs official JWS verification AND a fresh Apple server query. Only its
        // Historical PAID order plus an exact ACTIVE license acknowledges delivery. A signed
        // revocation plus exact REVOKED license acknowledges removal, never grants rights.
        let license = try await service.verifiedLicense(observed, offer: offer, requireActive: false)
        guard (license.status == "ACTIVE" && transaction.revocationDate == nil) ||
              (license.status == "REVOKED" && transaction.revocationDate != nil) else {
            throw WorkshopCommerceIssue.unavailable
        }
        try check()
        await transaction.finish()
        try check()
        return observed
    }
}
#endif
