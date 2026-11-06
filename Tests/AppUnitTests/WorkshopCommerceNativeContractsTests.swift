import XCTest
@testable import Questify

/// Deterministic contracts only. No Product.products, purchase, network, receipt or credential fixture.
@MainActor final class WorkshopCommerceNativeContractsTests: XCTestCase {
    private func context(_ id: Int = 7, epoch: UInt64 = 1) throws -> RuntimeDependencyContext {
        .init(market: .unitedStates, baseURL: URL(string: "https://example.com/native")!, role: "player",
              session: try .init(accountID: id, epoch: epoch, namespace: "synthetic-commerce", token: "synthetic"))
    }
    private func approval(_ context: RuntimeDependencyContext, purchase: String? = nil) throws -> WorkshopCommerceApproval {
        try .init(context: context, expiresAt: .distantFuture, readApprovalReference: "reviewed-read", digitalPurchaseApprovalReference: purchase,
                  platform: "IOS", market: "US", productType: "DIGITAL_MOD", channel: "APPLE_STOREKIT",
                  storeKitBundleID: "test.bundle", storeKitProductIDs: ["mod.release"], storeKitEnvironment: "PRODUCTION")
    }
    private func offer() -> WorkshopCommerceOffer {
        .init(offerId: "offer", moduleId: "module", releaseId: "release", creatorId: 9, title: "Reviewed MOD", currency: "USD", priceMinor: 100,
              platform: "IOS", market: "US", productType: "DIGITAL_MOD", channel: "APPLE_STOREKIT",
              terms: .init(version: "v1", hash: String(repeating: "a", count: 64), contentHash: String(repeating: "b", count: 64),
                           commercialUse: false, allowedRegions: ["US-NY"], installationLimit: 1, useDuration: "PERPETUAL_PURCHASED_VERSION",
                           updatePolicy: "EXACT_PURCHASED_VERSION", redistribution: "PROHIBITED", refundPolicyReference: "reviewed-refund"))
    }
    func testReadApprovalDoesNotAuthorizePurchaseAndContextIsAccountEpochBound() throws {
        let original = try context(), read = try approval(original), purchase = try approval(original, purchase: "reviewed-purchase")
        XCTAssertTrue(read.recognizes(offer())); XCTAssertFalse(read.permits(offer())); XCTAssertTrue(purchase.permits(offer()))
        XCTAssertFalse(read.matches(try context(8))); XCTAssertFalse(read.matches(try context(epoch: 2)))
    }
    func testNativeContextRejectsSandboxWrongProductOrderAndActorToken() throws {
        let grant = try approval(context(), purchase: "reviewed-purchase")
        let order = WorkshopCommerceOrder(orderKey: "MOD123", requestId: "request", offerId: "offer", state: .nativeReady, licenseId: nil,
                                          amountMinor: 100, currency: "USD", cancellationRequested: false, paymentParameters: [:])
        let valid = ["channel": "APPLE_STOREKIT", "environment": "PRODUCTION", "orderKey": "MOD123", "productId": "mod.release", "bundleId": "test.bundle", "storefront": "USA", "appAccountToken": "95245135-3916-4bdc-9ea7-a5e041dd824d"]
        XCTAssertNoThrow(try WorkshopStoreKitParameters(valid, order: order, approval: grant))
        for (key, value) in [("environment", "SANDBOX"), ("orderKey", "another-order"), ("productId", "unapproved"), ("bundleId", "wrong.bundle"), ("storefront", "CHN"), ("appAccountToken", "00000000-0000-0000-0000-000000000000")] {
            var changed = valid; changed[key] = value
            XCTAssertThrowsError(try WorkshopStoreKitParameters(changed, order: order, approval: grant))
        }
    }
}

/// Synthetic, in-memory controller tests. Never submits a real claim or uses StoreKit/network.
@MainActor final class WorkshopCommerceFreeLicenseFlowTests: XCTestCase {
    private func setup(_ service: FreeLicenseService) throws -> (WorkshopCommerceController, WorkshopCommercePendingStore, FreeLicenseStorage) {
        let context = RuntimeDependencyContext(market: .unitedStates, baseURL: URL(string: "https://example.com/native")!, role: "player",
            session: try .init(accountID: 7, epoch: 1, namespace: "synthetic-free-license", token: "synthetic"))
        let storage = FreeLicenseStorage(), pending = WorkshopCommercePendingStore(storage: storage, context: context)
        return (.init(service: service, pending: pending), pending, storage)
    }
    func testFreeClaimKeepsVerifiedResultWhenOptionalListFails() async throws {
        let service = FreeLicenseService(); service.listFails = true
        let (controller, pending, _) = try setup(service)
        await controller.preview("free-offer"); await controller.confirmPurchase()
        XCTAssertEqual(service.created.count, 1)
        XCTAssertEqual(controller.order?.state, .acquiredFree)
        XCTAssertEqual(controller.acquiredLicense?.license.acquisition, "FREE")
        XCTAssertEqual(controller.acquiredLicense?.offer.terms, service.originalOffer.terms)
        XCTAssertNil(try pending.load()); XCTAssertNil(controller.messageKey)
        XCTAssertEqual(controller.licensesMessageKey, "error.licensesUnavailable")
        XCTAssertFalse(controller.acquiredLicense!.license.published)
        XCTAssertFalse(controller.acquiredLicense!.license.executable)
    }
    func testLostResponseRecoversSameRequestAfterOriginalOfferWithdrawnWithoutReclaiming() async throws {
        let service = FreeLicenseService(); service.loseCreateResponse = true
        let (first, pending, _) = try setup(service)
        await first.preview("free-offer"); await first.confirmPurchase()
        let original = try XCTUnwrap(pending.load())
        XCTAssertEqual(first.messageKey, "error.purchaseUnknown"); XCTAssertNil(first.acquiredLicense)
        service.catalogUnavailable = true; service.listFails = true
        let reopened = WorkshopCommerceController(service: service, pending: pending)
        await reopened.recover()
        XCTAssertEqual(service.created.count, 1)
        XCTAssertEqual(service.lookedUp, [original.requestId])
        XCTAssertEqual(reopened.order?.requestId, original.requestId)
        XCTAssertEqual(reopened.acquiredLicense?.license.terms, service.originalOffer.terms)
        XCTAssertEqual(service.catalogReads, 1) // Only the original explicit preview.
        XCTAssertNil(try pending.load()); XCTAssertNil(reopened.messageKey)
    }
    func testUnknownLookupNeverRepostsOrInventsReceiptFromOwnedList() async throws {
        let service = FreeLicenseService(); service.loseCreateResponse = true
        let (controller, pending, _) = try setup(service)
        await controller.preview("free-offer"); await controller.confirmPurchase()
        let original = try XCTUnwrap(pending.load()); service.lookupFails = true
        await controller.recover(); await controller.recover()
        XCTAssertEqual(service.created.count, 1)
        XCTAssertEqual(try pending.load(), original)
        XCTAssertNil(controller.order); XCTAssertNil(controller.acquiredLicense)
        XCTAssertEqual(controller.messageKey, "error.recoveryUnknown")
    }
    func testAuthoritativeAbsenceReusesOnlyDurableOriginalRequest() async throws {
        let service = FreeLicenseService(), (controller, pending, _) = try setup(service)
        let original = WorkshopCommerceIntent(requestId: "original-request", offerId: "free-offer", termsHash: service.originalOffer.terms.hash)
        try pending.save(original)
        await controller.recover()
        XCTAssertEqual(service.created, [original]); XCTAssertEqual(controller.order?.requestId, original.requestId)
        XCTAssertNil(try pending.load())
    }
    func testLicenseDetailUsesOriginalOrderNotCurrentPaidOfferAndReturnKeepsCatalog() async throws {
        let service = FreeLicenseService(); service.seed()
        let (controller, _, _) = try setup(service)
        service.catalogOffer = FreeLicenseService.offer(id: "new-paid-offer", price: 500, termsVersion: "new-terms")
        await controller.preview("new-paid-offer")
        await controller.loadLicenseSnapshot("license-a")
        let detail = try XCTUnwrap(controller.licenseSnapshot)
        XCTAssertEqual(detail.order.amountMinor, 0); XCTAssertEqual(detail.license.acquisition, "FREE")
        XCTAssertEqual(detail.license.terms.version, "original-terms")
        XCTAssertEqual(detail.offer.offerId, "free-offer"); XCTAssertEqual(service.catalogReads, 1)
        controller.closeLicenseSnapshot()
        XCTAssertNil(controller.licenseSnapshot)
        XCTAssertEqual(controller.offer?.offerId, "new-paid-offer")
        XCTAssertTrue(service.created.isEmpty)
    }
    func testSuspensionReasonIsServerFactAndMissingReasonStaysMissing() async throws {
        let service = FreeLicenseService(); service.seed(status: "SUSPENDED", reason: "Reviewed suspension reference")
        let (controller, _, _) = try setup(service)
        await controller.loadLicenseSnapshot("license-a")
        XCTAssertEqual(controller.licenseSnapshot?.license.suspensionReason, "Reviewed suspension reference")
        service.seed(status: "REVOKED", reason: nil)
        await controller.loadLicenseSnapshot("license-a")
        XCTAssertEqual(controller.licenseSnapshot?.license.status, "REVOKED")
        XCTAssertNil(controller.licenseSnapshot?.license.suspensionReason)
        XCTAssertTrue(service.created.isEmpty)
    }
    func testDetailFailureClearsPriorReceiptAndDoesNotChangeSelectedCatalog() async throws {
        let service = FreeLicenseService(); service.seed()
        let (controller, _, _) = try setup(service)
        await controller.preview("free-offer"); await controller.loadLicenseSnapshot("license-a")
        XCTAssertNotNil(controller.licenseSnapshot)
        await controller.loadLicenseSnapshot("missing-license")
        XCTAssertNil(controller.licenseSnapshot)
        XCTAssertEqual(controller.licenseSnapshotMessageKey, "error.licenseUnavailable")
        XCTAssertEqual(controller.offer?.offerId, "free-offer")
    }
    func testWrongLicenseResponseCannotOpenAnotherLicense() async throws {
        let service = FreeLicenseService(); service.seed(); service.wrongLicenseResponse = true
        let (controller, _, _) = try setup(service)
        await controller.loadLicenseSnapshot("somebody-else-license")
        XCTAssertNil(controller.licenseSnapshot); XCTAssertTrue(service.orderReads.isEmpty)
        XCTAssertEqual(controller.licenseSnapshotMessageKey, "error.licenseUnavailable")
    }
    func testLateReadAfterReturnDoesNotReopenReceipt() async throws {
        let service = FreeLicenseService(); service.seed(); service.delayLicense = true
        let (controller, _, _) = try setup(service)
        let task = Task { await controller.loadLicenseSnapshot("license-a") }
        while service.waiting == nil { await Task.yield() }
        controller.closeLicenseSnapshot(); service.resumeLicense()
        await task.value
        XCTAssertNil(controller.licenseSnapshot); XCTAssertFalse(controller.licenseSnapshotLoading)
        XCTAssertTrue(service.orderReads.isEmpty)
    }
    func testLateOldSelectionCannotReplaceNewSelection() async throws {
        let service = FreeLicenseService(); service.seed(); service.seed(id: "license-b"); service.delayLicense = true
        let (controller, _, _) = try setup(service)
        let old = Task { await controller.loadLicenseSnapshot("license-a") }
        while service.waiting == nil { await Task.yield() }
        service.delayLicense = false
        await controller.loadLicenseSnapshot("license-b")
        service.resumeLicense(); await old.value
        XCTAssertEqual(controller.licenseSnapshot?.license.licenseId, "license-b")
    }
    func testInvalidationClearsReceiptsAndIgnoresPriorAccountResponse() async throws {
        let service = FreeLicenseService(); service.seed()
        let (controller, _, _) = try setup(service)
        await controller.loadLicenses(); service.delayLicense = true
        let old = Task { await controller.loadLicenseSnapshot("license-a") }
        while service.waiting == nil { await Task.yield() }
        controller.invalidate(); service.resumeLicense(); await old.value
        XCTAssertFalse(controller.isCurrent); XCTAssertTrue(controller.licenses.isEmpty)
        XCTAssertNil(controller.licenseSnapshot); XCTAssertNil(controller.acquiredLicense)
        XCTAssertTrue(service.orderReads.isEmpty)
    }
    func testPaginationUsesActualLastLicenseIdAndKeepsRowsOnFailure() async throws {
        let service = FreeLicenseService()
        for i in 0..<51 { service.seed(id: String(format: "license-%03d", i)) }
        let (controller, _, _) = try setup(service)
        await controller.loadLicenses()
        XCTAssertEqual(controller.licenses.count, 50); XCTAssertTrue(controller.hasMoreLicenses)
        let cursor = try XCTUnwrap(controller.licenses.last?.licenseId)
        service.listFails = true; await controller.loadLicenses(more: true)
        XCTAssertEqual(controller.licenses.count, 50); XCTAssertTrue(controller.hasMoreLicenses)
        service.listFails = false; await controller.loadLicenses(more: true)
        XCTAssertEqual(service.listCursors, [nil, cursor, cursor])
        XCTAssertEqual(controller.licenses.count, 51); XCTAssertFalse(controller.hasMoreLicenses)
        XCTAssertNil(controller.licensesMessageKey)
    }
    func testRepeatedPageIsRejectedWithoutAppendingOrAdvancing() async throws {
        let service = FreeLicenseService()
        for i in 0..<50 { service.seed(id: String(format: "license-%03d", i)) }
        let (controller, _, _) = try setup(service)
        await controller.loadLicenses(); let original = controller.licenses
        service.repeatFirstPage = true; await controller.loadLicenses(more: true)
        XCTAssertEqual(controller.licenses, original); XCTAssertTrue(controller.hasMoreLicenses)
        XCTAssertEqual(controller.licensesMessageKey, "error.licensesUnavailable")
    }
    func testSnapshotRejectsCurrentOfferPriceTermsOrWrongOriginalOrder() throws {
        let service = FreeLicenseService(); service.seed()
        let license = try XCTUnwrap(service.owned["license-a"]), order = try XCTUnwrap(service.orders[license.orderKey])
        XCTAssertNoThrow(try WorkshopCommerceLicenseSnapshot(license: license, order: order, offer: service.originalOffer))
        XCTAssertThrowsError(try WorkshopCommerceLicenseSnapshot(license: license, order: order,
            offer: FreeLicenseService.offer(id: "free-offer", price: 500)))
        XCTAssertThrowsError(try WorkshopCommerceLicenseSnapshot(license: license, order: order,
            offer: FreeLicenseService.offer(id: "free-offer", termsVersion: "replaced-terms")))
        service.seed(id: "license-b")
        XCTAssertThrowsError(try WorkshopCommerceLicenseSnapshot(license: license, order: service.orders["order-license-b"]!, offer: service.originalOffer))
    }
}

@MainActor private final class FreeLicenseStorage: TemplateAuthoringStorage {
    var values: [String: Data] = [:]
    func read(_ key: String) throws -> Data? { values[key] }
    func write(_ data: Data, key: String) throws { values[key] = data }
    func remove(_ key: String) throws { values.removeValue(forKey: key) }
}
@MainActor private final class FreeLicenseService: WorkshopCommerceServing {
    var current = true, listFails = false, lookupFails = false, catalogUnavailable = false
    var loseCreateResponse = false, wrongLicenseResponse = false, delayLicense = false, repeatFirstPage = false
    var created: [WorkshopCommerceIntent] = [], lookedUp: [String] = [], listCursors: [String?] = [], orderReads: [String] = []
    var catalogReads = 0
    let originalOffer = FreeLicenseService.offer(id: "free-offer")
    var catalogOffer = FreeLicenseService.offer(id: "free-offer")
    var orders: [String: WorkshopCommerceOrder] = [:], owned: [String: WorkshopCommerceLicense] = [:]
    var waiting: CheckedContinuation<WorkshopCommerceLicense, Error>?
    private var waitingValue: WorkshopCommerceLicense?
    var canAcquire: Bool { current }
    func permitsPurchase(_ offer: WorkshopCommerceOffer) -> Bool { current }
    func checkSession() throws { guard current else { throw WorkshopCommerceIssue.staleSession } }
    func invalidate() { current = false }
    nonisolated static func offer(id: String, price: Int64 = 0, termsVersion: String = "original-terms") -> WorkshopCommerceOffer {
        .init(offerId: id, moduleId: "module", releaseId: "original-release", creatorId: 9, title: "Synthetic MOD", currency: "USD", priceMinor: price,
            platform: nil, market: nil, productType: nil, channel: nil,
            terms: .init(version: termsVersion, hash: String(repeating: "a", count: 64), contentHash: String(repeating: "b", count: 64),
                commercialUse: false, allowedRegions: ["US-NY"], installationLimit: 2, useDuration: "PERPETUAL_PURCHASED_VERSION",
                updatePolicy: "EXACT_PURCHASED_VERSION", redistribution: "PROHIBITED", refundPolicyReference: "synthetic-reference"))
    }
    func seed(id: String = "license-a", request: String = "original-request", status: String = "ACTIVE", reason: String? = nil) {
        let key = "order-" + id
        orders[key] = .init(orderKey: key, requestId: request, offerId: originalOffer.offerId, state: .acquiredFree, licenseId: id,
            amountMinor: 0, currency: "USD", cancellationRequested: false, paymentParameters: [:])
        owned[id] = .init(licenseId: id, orderKey: key, moduleId: originalOffer.moduleId, purchasedVersionId: originalOffer.releaseId,
            acquisition: "FREE", status: status, acquiredAt: "2026-10-21T00:00:00Z", terms: originalOffer.terms, usedInstallations: 0,
            suspensionReason: reason, published: false, executable: false)
    }
    func offers(before: String?) async throws -> [WorkshopCommerceOffer] { try checkSession(); return [catalogOffer] }
    func offer(_ id: String) async throws -> WorkshopCommerceOffer {
        try checkSession(); catalogReads += 1
        guard !catalogUnavailable, catalogOffer.offerId == id else { throw WorkshopCommerceIssue.unavailable }; return catalogOffer
    }
    func create(_ intent: WorkshopCommerceIntent, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder {
        try checkSession(); created.append(intent); seed(request: intent.requestId)
        if loseCreateResponse { throw WorkshopCommerceIssue.unavailable }
        return orders["order-license-a"]!
    }
    func lookupRequest(_ id: String) async throws -> WorkshopCommercePurchaseLookup {
        try checkSession(); lookedUp.append(id); if lookupFails { throw WorkshopCommerceIssue.unavailable }
        let found = orders.values.first { $0.requestId == id }; return .init(found: found != nil, order: found)
    }
    func orderOffer(_ key: String) async throws -> WorkshopCommerceOffer { try checkSession(); guard orders[key] != nil else { throw WorkshopCommerceIssue.unavailable }; return originalOffer }
    func order(_ key: String) async throws -> WorkshopCommerceOrder {
        try checkSession(); orderReads.append(key); guard let value = orders[key] else { throw WorkshopCommerceIssue.unavailable }; return value
    }
    func startPayment(_ order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws -> WorkshopCommerceOrder { throw WorkshopCommerceIssue.disabled }
    func verifiedLicense(_ order: WorkshopCommerceOrder, offer: WorkshopCommerceOffer, requireActive: Bool) async throws -> WorkshopCommerceLicense {
        guard let id = order.licenseId else { throw WorkshopCommerceIssue.malformed }
        let value = try await license(id); _ = try WorkshopCommerceLicenseSnapshot(license: value, order: order, offer: offer)
        guard !requireActive || value.status == "ACTIVE" else { throw WorkshopCommerceIssue.malformed }; return value
    }
    func reconcile(_ key: String) async throws -> WorkshopCommerceOrder { try await order(key) }
    func cancelRequest(_ intent: WorkshopCommerceIntent) async throws -> WorkshopCommerceOrder { throw WorkshopCommerceIssue.disabled }
    func licenses(before: String?) async throws -> [WorkshopCommerceLicense] {
        try checkSession(); listCursors.append(before); if listFails { throw WorkshopCommerceIssue.unavailable }
        return Array(owned.values.filter { before == nil || repeatFirstPage || $0.licenseId < before! }.sorted { $0.licenseId > $1.licenseId }.prefix(50))
    }
    func license(_ id: String) async throws -> WorkshopCommerceLicense {
        try checkSession()
        guard let value = owned[wrongLicenseResponse ? "license-a" : id] else { throw WorkshopCommerceIssue.unavailable }
        if delayLicense {
            waitingValue = value
            return try await withCheckedThrowingContinuation { waiting = $0 }
        }
        return value
    }
    func resumeLicense() { let continuation = waiting; waiting = nil; if let value = waitingValue { continuation?.resume(returning: value) }; waitingValue = nil }
    func reserve(_ command: WorkshopCommerceInstall) async throws -> WorkshopCommerceReservation { throw WorkshopCommerceIssue.disabled }
}
