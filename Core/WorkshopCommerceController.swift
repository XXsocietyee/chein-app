import Foundation
import Observation

/// Recovery intent contains no token, payment parameter or licensed asset. Scoped to account AND API realm.
@MainActor public final class WorkshopCommercePendingStore {
    private let storage: any TemplateAuthoringStorage
    private let scope: String
    private var key: String { "workshop-commerce-v1." + Data(scope.utf8).base64EncodedString() }
    private struct Record: Codable { let scope: String; let intent: WorkshopCommerceIntent; var cancellationRequested: Bool? }
    public init(storage: any TemplateAuthoringStorage, context: RuntimeDependencyContext) {
        self.storage = storage
        scope = [context.baseURL.absoluteString, context.session.namespace, String(context.session.accountID)]
            .map { "\($0.utf8.count):\($0)" }.joined(separator: ":")
    }
    public func load() throws -> WorkshopCommerceIntent? {
        guard let data = try storage.read(key) else { return nil }
        guard data.count <= 16384, let record = try? JSONDecoder().decode(Record.self, from: data), record.scope == scope else { throw WorkshopCommerceIssue.storageUnavailable }
        return record.intent
    }
    public func save(_ intent: WorkshopCommerceIntent) throws {
        if let previous = try load() { guard previous == intent else { throw WorkshopCommerceIssue.pendingConflict }; return }
        try storage.write(JSONEncoder().encode(Record(scope: scope, intent: intent, cancellationRequested: nil)), key: key)
        guard try load() == intent else { throw WorkshopCommerceIssue.storageUnavailable }
    }
    public func isCancellationRequested() throws -> Bool {
        guard let bytes = try storage.read(key) else { return false }
        guard bytes.count <= 16384, let value = try? JSONDecoder().decode(Record.self, from: bytes), value.scope == scope else { throw WorkshopCommerceIssue.storageUnavailable }
        return value.cancellationRequested == true
    }
    public func requestCancellation(_ intent: WorkshopCommerceIntent) throws {
        guard try load() == intent else { throw WorkshopCommerceIssue.pendingConflict }
        try storage.write(JSONEncoder().encode(Record(scope: scope, intent: intent, cancellationRequested: true)), key: key)
        guard try load() == intent, try isCancellationRequested() else { throw WorkshopCommerceIssue.storageUnavailable }
    }
    public func complete(_ order: WorkshopCommerceOrder) throws {
        guard order.terminal, let pending = try load(), pending.requestId == order.requestId, pending.offerId == order.offerId else { throw WorkshopCommerceIssue.pendingConflict }
        try storage.remove(key); guard try storage.read(key) == nil else { throw WorkshopCommerceIssue.storageUnavailable }
    }
}

@MainActor @Observable public final class WorkshopCommerceController {
    public private(set) var offers: [WorkshopCommerceOffer] = []
    public private(set) var hasMoreOffers = false
    public private(set) var offer: WorkshopCommerceOffer?
    public private(set) var order: WorkshopCommerceOrder?
    public private(set) var acquiredLicense: WorkshopCommerceLicenseSnapshot?
    public private(set) var licenses: [WorkshopCommerceLicense] = []
    public private(set) var hasMoreLicenses = false
    public private(set) var licensesMessageKey: String?
    public private(set) var licenseSnapshot: WorkshopCommerceLicenseSnapshot?
    public private(set) var ownedReleaseRecord: WorkshopOwnedReleaseRecord?
    public private(set) var ownedReleaseReadUnavailable = false
    public private(set) var reversalStatus: WorkshopBuyerReversalStatus?
    public private(set) var reversalStatusUnavailable = false
    public private(set) var cancellationNotice: String?
    public private(set) var licenseSnapshotLoading = false
    public private(set) var licenseSnapshotMessageKey: String?
    public private(set) var busy = false
    public private(set) var messageKey: String?
    private let service: any WorkshopCommerceServing
    private let pending: WorkshopCommercePendingStore
    private let nativePurchases: (any WorkshopCommerceNativePurchasing)?
    private var recoveryRequested = false
    private var recoveryAllowsOriginalRequestReplay = false
    private var invalidated = false
    private var licenseReadRevision: UInt64 = 0
    public init(service: any WorkshopCommerceServing, pending: WorkshopCommercePendingStore,
                nativePurchases: (any WorkshopCommerceNativePurchasing)? = nil) {
        self.service = service; self.pending = pending; self.nativePurchases = nativePurchases
        nativePurchases?.startUpdates { [weak self] in await self?.recover(allowOriginalRequestReplay: false) }
    }
    public var isCurrent: Bool { !invalidated && (try? service.checkSession()) != nil }
    public func invalidate() {
        invalidated = true; recoveryRequested = false; recoveryAllowsOriginalRequestReplay = false
        nativePurchases?.invalidate(); service.invalidate()
        closeLicenseSnapshot(); cancellationNotice = nil; acquiredLicense = nil; licenses = []; hasMoreLicenses = false
    }
    private func finishOperation() {
        busy = false
        if recoveryRequested && !invalidated {
            recoveryRequested = false
            let allowReplay = recoveryAllowsOriginalRequestReplay
            recoveryAllowsOriginalRequestReplay = false
            Task { [weak self] in await self?.recover(allowOriginalRequestReplay: allowReplay) }
        }
    }
    public var canAcquire: Bool {
        guard !invalidated, service.canAcquire, !busy, order?.terminal != false,
              let offer, offer.hasSupportedTerms, service.permitsPurchase(offer), offer.priceMinor == 0 || nativePurchases != nil else { return false }
        do { return try pending.load() == nil } catch { return false }
    }
    public var canCancel: Bool {
        guard !invalidated, service.canCancelOrder, !busy, order?.terminal != true else { return false }
        do { return try pending.load() != nil } catch { return false }
    }
    public var canPay: Bool {
        guard (try? pending.isCancellationRequested()) == false else { return false }
        return !invalidated && offer.map { service.permitsPurchase($0) && $0.offerId == order?.offerId } == true && nativePurchases != nil && !busy &&
        order.map { !$0.cancellationRequested && ($0.state == .created || $0.state == .nativeReady) } == true
    }
    public func loadOffers(more: Bool = false) async {
        guard !busy, !invalidated, !more || hasMoreOffers else { return }
        busy = true; defer { finishOperation() }
        do {
            let page = try await service.offers(before: more ? offers.last?.offerId : nil)
            guard page.count <= 50, Set(page.map(\.offerId)).count == page.count else { throw WorkshopCommerceIssue.malformed }
            if more {
                guard Set(offers.map(\.offerId)).isDisjoint(with: page.map(\.offerId)) else { throw WorkshopCommerceIssue.malformed }
                offers += page
            } else { offers = page }
            hasMoreOffers = page.count == 50; if messageKey == "error.catalogUnavailable" { messageKey = nil }
        } catch { messageKey = "error.catalogUnavailable" }
    }
    public func preview(_ offerId: String) async {
        guard !busy, !invalidated else { return }; busy = true; defer { finishOperation() }
        do { offer = try await service.offer(offerId); messageKey = nil } catch { messageKey = "error.offerUnavailable" }
    }
    /// A failed page never discards already displayed rows or advances the server cursor.
    public func loadLicenses(more: Bool = false) async {
        guard !busy, !invalidated, !more || hasMoreLicenses else { return }
        busy = true; defer { finishOperation() }
        await refreshLicenses(more: more)
    }
    private func refreshLicenses(more: Bool = false) async {
        do {
            let page = try await service.licenses(before: more ? licenses.last?.licenseId : nil)
            try service.checkSession()
            guard !invalidated, page.count <= 50, Set(page.map(\.licenseId)).count == page.count,
                  page.allSatisfy({ !$0.published && !$0.executable }) else { throw WorkshopCommerceIssue.malformed }
            if more {
                guard Set(licenses.map(\.licenseId)).isDisjoint(with: page.map(\.licenseId)) else { throw WorkshopCommerceIssue.malformed }
                licenses += page
            } else { licenses = page }
            hasMoreLicenses = page.count == 50; licensesMessageKey = nil
        } catch {
            if isCurrent { licensesMessageKey = "error.licensesUnavailable" }
            else { licenses = []; hasMoreLicenses = false }
        }
    }
    /// Detail is always re-read by license ID and joined through its own order, not the
    /// current catalog selection. Returning, switching selection or identity invalidates late reads.
    public func loadLicenseSnapshot(_ id: String) async {
        guard isCurrent else { closeLicenseSnapshot(); return }
        closeLicenseSnapshot(); let revision = licenseReadRevision
        licenseSnapshotLoading = true
        defer { if revision == licenseReadRevision { licenseSnapshotLoading = false } }
        do {
            let value = try await service.license(id)
            guard isCurrent, revision == licenseReadRevision else { return }
            guard value.licenseId == id else { throw WorkshopCommerceIssue.malformed }
            let originalOrder = try await service.order(value.orderKey)
            guard isCurrent, revision == licenseReadRevision else { return }
            let frozenOffer = try await service.orderOffer(originalOrder.orderKey)
            let snapshot = try WorkshopCommerceLicenseSnapshot(license: value, order: originalOrder, offer: frozenOffer)
            try service.checkSession()
            guard !invalidated, revision == licenseReadRevision else { return }
            licenseSnapshot = snapshot
            if service.canReadOwnedRelease {
                do {
                    let record = try await service.ownedReleaseRecord(id)
                    guard isCurrent, revision == licenseReadRevision else { return }
                    guard record.matches(snapshot) else { throw WorkshopCommerceIssue.malformed }
                    ownedReleaseRecord = record
                } catch {
                    guard isCurrent, revision == licenseReadRevision else { return }
                    ownedReleaseReadUnavailable = true
                }
            } else { ownedReleaseReadUnavailable = true }
            if service.canReadReversalStatus {
                do {
                    let status = try await service.reversalStatus(originalOrder.orderKey)
                    guard isCurrent, revision == licenseReadRevision else { return }
                    guard status.matches(snapshot) else { throw WorkshopCommerceIssue.malformed }
                    reversalStatus = status
                } catch {
                    guard isCurrent, revision == licenseReadRevision else { return }
                    reversalStatusUnavailable = true
                }
            } else { reversalStatusUnavailable = true }
        } catch {
            guard revision == licenseReadRevision else { return }
            licenseSnapshot = nil
            licenseSnapshotMessageKey = isCurrent ? "error.licenseUnavailable" : "error.licenseSessionChanged"
        }
    }
    public func closeLicenseSnapshot() {
        ownedReleaseRecord = nil; ownedReleaseReadUnavailable = false
        licenseReadRevision &+= 1; licenseSnapshot = nil; reversalStatus = nil; reversalStatusUnavailable = false
        licenseSnapshotLoading = false; licenseSnapshotMessageKey = nil
    }
    /// Must be called only after the view's explicit price + frozen-terms confirmation.
    /// Compatibility entry for existing callers; normal UI supplies its captured review explicitly.
    public func confirmPurchase() async {
        guard let offer else { return }
        await confirmPurchase(reviewedOffer: offer)
    }
    public func confirmPurchase(reviewedOffer: WorkshopCommerceOffer) async {
        // Confirm the exact price, original version and complete terms shown in the review sheet.
        // A newer selection or refreshed scope never inherits an earlier confirmation.
        guard canAcquire, let offer, offer == reviewedOffer else { return }; busy = true; defer { finishOperation() }
        do {
            guard try pending.load() == nil else { throw WorkshopCommerceIssue.pendingConflict }
            let intent = WorkshopCommerceIntent(offer: offer); try pending.save(intent); cancellationNotice = nil
            order = nil; acquiredLicense = nil
            let result = try await service.create(intent, offer: offer)
            let original = try await adoptOriginal(result, requested: intent)
            try await accept(result, intent: original); messageKey = nil
            if original != intent { recoveryRequested = true }
        } catch { messageKey = "error.purchaseUnknown" }
    }
    /// Passive entry/foreground/StoreKit wakeups pass false. Only an explicit recovery action
    /// may replay the exact durable request after authoritative absence, never after UNKNOWN.
    public func recover(allowOriginalRequestReplay: Bool = true) async {
        guard !invalidated else { return }
        guard !busy else {
            recoveryRequested = true
            recoveryAllowsOriginalRequestReplay = recoveryAllowsOriginalRequestReplay || allowOriginalRequestReplay
            return
        }
        busy = true; defer { finishOperation() }
        do {
            var awaitingNativeFinish = false
            if var intent = try pending.load() {
                if try pending.isCancellationRequested() {
                    // Cancellation intent retires purchase recovery. Reopen only observes this same request.
                    let lookup = try await service.lookupRequest(intent.requestId)
                    guard lookup.found == (lookup.order != nil) else { throw WorkshopCommerceIssue.malformed }
                    if let observed = lookup.order {
                        let frozenOffer = try await service.orderOffer(observed.orderKey)
                        try validate(observed, intent: intent, offer: frozenOffer)
                        offer = frozenOffer
                        // Cancellation can race with a completed original Apple transaction.
                        // Only recover that same transaction; never purchase, create or recancel.
                        let native = try await recoverNative(observed, offer: frozenOffer)
                        try await accept(native.order, intent: intent, nativeFinished: native.finished)
                        cancellationNotice = native.order.state == .cancelled ? "原订单已取消。" :
                            (native.order.state == .paid || native.order.state == .acquiredFree ? "原订单已授予许可，不能作为未付款订单取消；退款仍按原处理流程。" : "原取消结果尚未终结，只回读原订单，不重新创建或支付。")
                        messageKey = native.order.state == .paid && frozenOffer.channel == "APPLE_STOREKIT" && !native.finished
                            ? "error.transactionRecoveryPending" : (native.unavailable ? "error.recoveryUnknown" : nil)
                    } else {
                        cancellationNotice = "原取消请求尚无可读结果；保留同一请求，不重新创建或支付。"
                        messageKey = "error.cancelUnknown"
                    }
                    await refreshLicenses(); return
                }
                let lookup = try await service.lookupRequest(intent.requestId)
                guard lookup.found == (lookup.order != nil) else { throw WorkshopCommerceIssue.malformed }
                var result: WorkshopCommerceOrder
                if let existing = lookup.order {
                    // Lookup is exact-request authority. Only an explicit create may return an
                    // earlier non-consumable order for adoption; a passive lookup cannot do so.
                    guard existing.requestId == intent.requestId, existing.offerId == intent.offerId else { throw WorkshopCommerceIssue.malformed }
                    result = existing
                }
                else {
                    guard allowOriginalRequestReplay else { throw WorkshopCommerceIssue.unavailable }
                    // Authoritative absence permits replay of the SAME original request, never
                    // a fresh UUID or a native payment call. DB uniqueness resolves in-flight races.
                    let approved = try await service.offer(intent.offerId)
                    guard approved.terms.hash == intent.termsHash else { throw WorkshopCommerceIssue.pendingConflict }
                    result = try await service.create(intent, offer: approved)
                }
                intent = try await adoptOriginal(result, requested: intent)
                let frozenOffer = try await service.orderOffer(result.orderKey)
                guard frozenOffer.offerId == intent.offerId, frozenOffer.terms.hash == intent.termsHash else { throw WorkshopCommerceIssue.malformed }
                offer = frozenOffer
                if !result.terminal { result = try await service.reconcile(result.orderKey) }
                let native = try await recoverNative(result, offer: frozenOffer)
                result = native.order
                try await accept(result, intent: intent, nativeFinished: native.finished)
                awaitingNativeFinish = result.state == .paid && frozenOffer.channel == "APPLE_STOREKIT" && !native.finished
                if native.unavailable && !awaitingNativeFinish { throw WorkshopCommerceIssue.unavailable }
            } else if let nativePurchases {
                // Reinstall/new-device recovery has no client request ledger. Signed Apple evidence
                // locates the original server order; the backend still enforces the current buyer.
                try await nativePurchases.restoreOwned()
            }
            await refreshLicenses()
            messageKey = awaitingNativeFinish ? "error.transactionRecoveryPending" : nil
        } catch { await refreshLicenses(); messageKey = "error.recoveryUnknown" }
    }
    /// Apple delivery acknowledgment is separate from the durable server order/license.
    /// A queue/query failure must not hide a verified historical grant or clear its pending key.
    private func recoverNative(_ original: WorkshopCommerceOrder, offer: WorkshopCommerceOffer) async throws
        -> (order: WorkshopCommerceOrder, finished: Bool, unavailable: Bool) {
        try service.checkSession()
        guard original.offerId == offer.offerId, original.amountMinor == offer.priceMinor,
              original.currency == offer.currency else { throw WorkshopCommerceIssue.malformed }
        guard let nativePurchases, offer.channel == "APPLE_STOREKIT", original.amountMinor > 0,
              original.state != .created, original.state != .cancelled else { return (original, false, false) }
        do {
            guard let recovered = try await nativePurchases.recover(order: original, offer: offer) else { return (original, false, false) }
            try service.checkSession()
            guard recovered.state == .paid, recovered.orderKey == original.orderKey,
                  recovered.requestId == original.requestId, recovered.offerId == original.offerId,
                  recovered.amountMinor == original.amountMinor, recovered.currency == original.currency else {
                throw WorkshopCommerceIssue.malformed
            }
            return (recovered, true, false)
        } catch {
            try service.checkSession() // Do not turn account/approval replacement into a fallback success.
            return (original, false, true)
        }
    }
    public func pay() async {
        guard canPay, let order, let offer, let nativePurchases else { return }
        busy = true; defer { finishOperation() }
        do {
            let prepared = try await service.startPayment(order, offer: offer)
            guard prepared.orderKey == order.orderKey, prepared.requestId == order.requestId,
                  prepared.offerId == order.offerId, prepared.amountMinor == order.amountMinor,
                  prepared.currency == order.currency else { throw WorkshopCommerceIssue.malformed }
            self.order = prepared
            var resolved: WorkshopCommerceOrder?
            if prepared.state == .nativeReady && !prepared.cancellationRequested {
                do { resolved = try await nativePurchases.purchase(order: prepared, offer: offer) }
                catch { /* Unknown dispatch/result remains recoverable through the original server order. */ }
            } else if prepared.state == .paid {
                resolved = try await nativePurchases.recover(order: prepared, offer: offer)
            }
            let observed: WorkshopCommerceOrder
            if let resolved { observed = resolved } else { observed = try await service.reconcile(order.orderKey) }
            guard let requested = try pending.load() else { throw WorkshopCommerceIssue.pendingConflict }
            let original = try await adoptOriginal(observed, requested: requested)
            try await accept(observed, intent: original, nativeFinished: resolved != nil)
            messageKey = resolved == nil ? "error.paymentUnknown" : nil
        } catch { messageKey = "error.paymentUnknown" }
    }
    public func cancel() async {
        guard canCancel else { return }; busy = true; defer { finishOperation() }
        do {
            guard let intent = try pending.load() else { throw WorkshopCommerceIssue.pendingConflict }
            try pending.requestCancellation(intent) // Durable before dispatch; old records decode as no cancellation.
            cancellationNotice = "取消请求已保存；未终结时只查询原订单。"
            let result = try await service.cancelRequest(intent)
            offer = try await service.orderOffer(result.orderKey)
            try await accept(result, intent: intent); messageKey = result.terminal ? nil : "error.cancelUnknown"
            cancellationNotice = result.state == .cancelled ? "原订单已取消。" : "取消尚未终结；以原订单和许可当前状态为准。"
        } catch { messageKey = "error.cancelUnknown" }
    }
    /// A non-consumable already has an owner-bound original order. Retire only the
    /// undispatched new intent, then durably adopt the server's original request/terms.
    private func adoptOriginal(_ result: WorkshopCommerceOrder, requested: WorkshopCommerceIntent) async throws -> WorkshopCommerceIntent {
        if result.requestId == requested.requestId { return requested }
        let originalOffer = try await service.orderOffer(result.orderKey)
        guard result.offerId == requested.offerId, originalOffer.offerId == requested.offerId,
              originalOffer.terms.hash == requested.termsHash, originalOffer.channel == "APPLE_STOREKIT",
              result.amountMinor == originalOffer.priceMinor, result.currency == originalOffer.currency else { throw WorkshopCommerceIssue.malformed }
        let cancelled = try await service.cancelRequest(requested)
        guard cancelled.state == .cancelled, cancelled.requestId == requested.requestId else {
            // A dispatched newer intent remains UNKNOWN; an older receipt cannot prove it uncharged.
            throw WorkshopCommerceIssue.pendingConflict
        }
        try pending.complete(cancelled)
        let original = WorkshopCommerceIntent(requestId: result.requestId, offerId: originalOffer.offerId, termsHash: originalOffer.terms.hash)
        try pending.save(original); offer = originalOffer
        return original
    }
    private func accept(_ result: WorkshopCommerceOrder, intent: WorkshopCommerceIntent, nativeFinished: Bool = false) async throws {
        try service.checkSession()
        guard let offer else { throw WorkshopCommerceIssue.malformed }
        try validate(result, intent: intent, offer: offer)
        var receipt: WorkshopCommerceLicenseSnapshot?
        if result.state == .paid || result.state == .acquiredFree {
            let value = try await service.verifiedLicense(result, offer: offer, requireActive: false)
            receipt = try WorkshopCommerceLicenseSnapshot(license: value, order: result, offer: offer)
        }
        try service.checkSession(); order = result; acquiredLicense = receipt
        // Keep the original request until StoreKit acknowledgment also completes. If the process
        // dies after server PAID, recovery still has the order key needed to match Apple's queue.
        let needsNativeFinish = result.state == .paid && offer.channel == "APPLE_STOREKIT" && !nativeFinished
        if result.terminal && !needsNativeFinish { try pending.complete(result) }
        // A failed optional list must not turn a verified original grant back into UNKNOWN.
        await refreshLicenses()
    }
    private func validate(_ result: WorkshopCommerceOrder, intent: WorkshopCommerceIntent, offer: WorkshopCommerceOffer) throws {
        guard result.requestId == intent.requestId, result.offerId == intent.offerId,
              offer.offerId == intent.offerId, offer.terms.hash == intent.termsHash,
              result.amountMinor == offer.priceMinor, result.currency == offer.currency,
              result.amountMinor >= 0, ["CNY", "USD"].contains(result.currency) else { throw WorkshopCommerceIssue.malformed }
    }
    /// Existing target picker can pass this command after its authoritative preview. No install-success projection.
    public func reserve(_ command: WorkshopCommerceInstall) async throws -> WorkshopCommerceReservation {
        guard !busy else { throw WorkshopCommerceIssue.pendingConflict }
        let result = try await service.reserve(command)
        guard result.requestId == command.requestId, result.licenseId == command.licenseId,
              result.targetId == command.targetId, result.releaseId == command.releaseId,
              !result.published, !result.executable else { throw WorkshopCommerceIssue.malformed }
        return result
    }
}
