import Foundation
import Observation

/// One closed approval per bundle feature. Same bounds as `FreeExploreBundleReadApproval`:
/// China, player/club/merchant, valid token, at most 24 hours. `permitsWrites` defaults to false.
/// Shipped composition never mints one. Refund POSTs also require `BundleMoneyWriteGate`, which stays closed.
@MainActor @Observable final class BundleFeatureApproval {
    let context: RuntimeDependencyContext
    let feature: BundleCompositionFeature
    let revision = UUID()
    let expiresAt: Date
    let permitsWrites: Bool
    private(set) var revoked = false
    @ObservationIgnored private var expiry: Task<Void, Never>?

    init(context: RuntimeDependencyContext, feature: BundleCompositionFeature, expiresAt: Date, permitsWrites: Bool = false) throws {
        let duration = expiresAt.timeIntervalSinceNow
        guard context.market == .china, context.session.accountID > 0,
              ["player", "club", "merchant"].contains(context.role),
              AuthRequestBuilder.isValidToken(context.session.token), duration > 0,
              duration.isFinite, duration <= 86_400 else { throw APIError.invalidConfiguration }
        self.context = context
        self.feature = feature
        self.expiresAt = expiresAt
        self.permitsWrites = permitsWrites
        expiry = Task { @MainActor [weak self] in
            guard let end = self?.expiresAt else { return }
            let delay = max(0, end.timeIntervalSinceNow)
            do { try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) }
            catch { return }
            self?.revoke()
        }
    }

    func matches(_ context: RuntimeDependencyContext) -> Bool {
        !revoked && Date() < expiresAt && self.context == context
    }

    func revoke() { revoked = true; expiry?.cancel(); expiry = nil }
    deinit { expiry?.cancel() }
}

enum BundleCompositionFeature: String {
    case read, cancel, appeal, transfer, refund, shelf, voucher, offer, review, renewal
}

/// Defaults are nil closures. A reviewed deployment does not fill them.
@MainActor struct BundleApprovalSet {
    var read: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var cancel: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var appeal: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var transfer: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var refund: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var shelf: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var voucher: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var offer: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var review: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    var renewal: @MainActor (RuntimeDependencyContext) -> BundleFeatureApproval? = { _ in nil }
    static var closed: BundleApprovalSet { BundleApprovalSet() }
}

/// What a session can hand a screen. Shipped value is `.closed`: every provider is nil.
@MainActor struct BundleSessionPorts {
    var read: (@MainActor (FreeExploreLaunchID, Set<String>) -> BundleReadTransport?)? = nil
    var cancel: (@MainActor () -> BundleCancelTransport?)? = nil
    var appeal: (@MainActor () -> BundleAppealTransport?)? = nil
    var transfer: (@MainActor (BundleTransferPendingStore) -> BundleTransferTransport?)? = nil
    var refund: (@MainActor (FreeExploreLaunchID) -> (any BundleRefundServing)?)? = nil
    var shelf: (any BundleShelfClient)? = nil
    var voucher: (any BundleVoucherServing)? = nil
    var offer: (any BundleOfferClient)? = nil
    var review: (any BundleReviewServing)? = nil
    var renewal: (any BundleRenewalServing)? = nil

    static var closed: BundleSessionPorts { BundleSessionPorts() }

    var providersAreNil: Bool {
        read == nil && cancel == nil && appeal == nil && transfer == nil && refund == nil
            && shelf == nil && voucher == nil && offer == nil && review == nil && renewal == nil
    }
}

extension AppCompositionRoot {
    func makeFreeExploreBundleReadHost(registrationID: Int64, context: RuntimeDependencyContext,
        scope: RegionalSessionStorageScope, currentContext: @escaping () -> RuntimeDependencyContext?,
        originCurrent: @escaping () -> Bool, unauthorized: @escaping () -> Void) -> FreeExploreBundleReadHost? {
        guard let reviewed, reviewed.storageScope == scope, reviewed.regional.market == context.market,
              reviewed.regional.apiConfiguration?.baseURL == context.baseURL,
              context.session.namespace == scope.service else { return nil }
        return FreeExploreBundleReadHost(registrationID: registrationID, accountID: Int64(context.session.accountID),
            context: context, approval: freeExploreBundleReadApproval(context), currentContext: currentContext,
            currentApproval: { self.freeExploreBundleReadApproval(context) }, originCurrent: originCurrent,
            storage: freeExploreBundleReadStorage(scope), transport: makeTransport(), unauthorized: unauthorized)
    }

    func makeBundlePorts(session: AppSession) -> BundleSessionPorts {
        guard let context = session.currentRuntimeDependencyContext else { return .closed }
        let readApproval = bundleApprovals.read(context)
        let cancelApproval = bundleApprovals.cancel(context)
        let appealApproval = bundleApprovals.appeal(context)
        let transferApproval = bundleApprovals.transfer(context)
        let refundApproval = bundleApprovals.refund(context)
        let shelfApproval = bundleApprovals.shelf(context)
        let voucherApproval = bundleApprovals.voucher(context)
        let offerApproval = bundleApprovals.offer(context)
        let reviewApproval = bundleApprovals.review(context)
        let renewalApproval = bundleApprovals.renewal(context)
        let none = [readApproval, cancelApproval, appealApproval, transferApproval, refundApproval,
                    shelfApproval, voucherApproval, offerApproval, reviewApproval, renewalApproval].allSatisfy { $0 == nil }
        if none { return .closed }
        let current: () -> RuntimeDependencyContext? = { [weak session] in
            guard let live = session?.currentRuntimeDependencyContext, live == context else { return nil }
            return live
        }
        let unauthorized: () -> Void = { [weak session] in
            session?.expireIfMatching(error: APIError.unauthorized, stamp: context.session.epoch, credential: context.session.token)
        }
        // Built port by port: one large initializer expression exceeded the type checker.
        var ports = BundleSessionPorts()
        if accepted(readApproval, feature: .read, context: context) {
            ports.read = { [self] (id: FreeExploreLaunchID, receipts: Set<String>) -> BundleReadTransport? in
                self.makeBundleReadTransport(registrationID: id, receiptRequestIDs: receipts, context: context,
                    approval: readApproval, current: { current() != nil }, denied: { readApproval?.revoke() })
            }
        }
        if accepted(cancelApproval, feature: .cancel, context: context) {
            ports.cancel = { [self] () -> BundleCancelTransport? in
                self.makeBundleCancelTransport(context: context, approval: cancelApproval, current: current, denied: { cancelApproval?.revoke() })
            }
        }
        if accepted(appealApproval, feature: .appeal, context: context) {
            ports.appeal = { [self] () -> BundleAppealTransport? in
                self.makeBundleAppealTransport(context: context, approval: appealApproval, current: current, unauthorized: unauthorized)
            }
        }
        if accepted(transferApproval, feature: .transfer, context: context) {
            ports.transfer = { [self] (store: BundleTransferPendingStore) -> BundleTransferTransport? in
                self.makeBundleTransferTransport(pending: store, context: context, approval: transferApproval, current: current, denied: { transferApproval?.revoke() })
            }
        }
        if accepted(refundApproval, feature: .refund, context: context) {
            ports.refund = { [self] (registrationID: FreeExploreLaunchID) -> (any BundleRefundServing)? in
                self.makeBundleRefundClient(registrationID: registrationID, context: context, approval: refundApproval,
                    current: current, unauthorized: unauthorized)
            }
        }
        ports.shelf = makeUnavailableShelf(context: context, approval: shelfApproval)
        ports.voucher = makeUnavailableVoucher(context: context, approval: voucherApproval)
        ports.offer = makeUnavailableOffer(context: context, approval: offerApproval)
        ports.review = makeUnavailableReview(context: context, approval: reviewApproval)
        ports.renewal = makeUnavailableRenewal(context: context, approval: renewalApproval)
        return ports
    }

    func makeBundleReadTransport(registrationID: FreeExploreLaunchID, receiptRequestIDs: Set<String>,
        context: RuntimeDependencyContext, approval: BundleFeatureApproval?, current: @escaping () -> Bool,
        denied: @escaping () -> Void) -> BundleReadTransport? {
        guard accepted(approval, feature: .read, context: context) else { return nil }
        return try? BundleReadTransport(baseURL: context.baseURL, authorization: context.session.token,
            registrationID: registrationID, receiptRequestIDs: receiptRequestIDs, underlying: makeTransport(),
            current: current, denied: denied)
    }

    func makeBundleCancelTransport(context: RuntimeDependencyContext, approval: BundleFeatureApproval?,
        current: @escaping () -> RuntimeDependencyContext?, denied: @escaping () -> Void) -> BundleCancelTransport? {
        guard accepted(approval, feature: .cancel, context: context) else { return nil }
        let allowed: () -> Bool = { approval?.permitsWrites == true && approval?.matches(context) == true && current() == context }
        return try? BundleCancelTransport(context: context, underlying: makeTransport(), current: current, writeAllowed: allowed, denied: denied)
    }

    func makeBundleAppealTransport(context: RuntimeDependencyContext, approval: BundleFeatureApproval?,
        current: @escaping () -> RuntimeDependencyContext?, unauthorized: @escaping () -> Void) -> BundleAppealTransport? {
        guard accepted(approval, feature: .appeal, context: context) else { return nil }
        let allowed: () -> Bool = { approval?.permitsWrites == true && approval?.matches(context) == true && current() == context }
        return try? BundleAppealTransport(baseURL: context.baseURL, token: context.session.token, underlying: makeTransport(),
            isCurrent: { current() == context }, writeAllowed: allowed, onUnauthorized: unauthorized)
    }

    func makeBundleTransferTransport(pending: BundleTransferPendingStore, context: RuntimeDependencyContext,
        approval: BundleFeatureApproval?, current: @escaping () -> RuntimeDependencyContext?,
        denied: @escaping () -> Void) -> BundleTransferTransport? {
        guard accepted(approval, feature: .transfer, context: context) else { return nil }
        let allowed: () -> Bool = { approval?.permitsWrites == true && approval?.matches(context) == true && current() == context }
        return BundleTransferTransport(context: context, pending: pending, underlying: makeTransport(),
            current: current, permitsWrites: allowed, denied: denied)
    }

    func makeBundleRefundClient(registrationID: FreeExploreLaunchID, context: RuntimeDependencyContext,
        approval: BundleFeatureApproval?, current: @escaping () -> RuntimeDependencyContext?,
        unauthorized: @escaping () -> Void) -> (any BundleRefundServing)? {
        guard accepted(approval, feature: .refund, context: context),
              let launch = try? launchSession(context) else { return nil }
        let allowed: () -> Bool = {
            BundleMoneyWriteGate.allowsRefundApply && approval?.permitsWrites == true && approval?.matches(context) == true && current() == context
        }
        guard let transport = try? BundleRefundTransport(context: context, registrationID: registrationID,
            underlying: makeTransport(), current: current, writeAllowed: allowed, denied: { approval?.revoke() }) else { return nil }
        return try? BundleRefundHTTPClient(session: launch, authorization: context.session.token, transport: transport,
            currentSession: { current() == context ? launch : nil }, writeAllowed: allowed, onUnauthorized: { _ in unauthorized() })
    }

    private func accepted(_ approval: BundleFeatureApproval?, feature: BundleCompositionFeature, context: RuntimeDependencyContext) -> Bool {
        guard let approval, approval.feature == feature, approval.matches(context), bundleReady(context) else { return false }
        return true
    }

    private func bundleReady(_ context: RuntimeDependencyContext) -> Bool {
        guard let reviewed, reviewed.regional.market == context.market,
              reviewed.regional.apiConfiguration?.baseURL == context.baseURL,
              reviewed.storageScope.service == context.session.namespace else { return false }
        return true
    }

    private func launchSession(_ context: RuntimeDependencyContext) throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: context.baseURL, accountID: Int64(context.session.accountID),
            market: context.market.rawValue, namespace: context.session.namespace, role: context.role,
            epoch: context.session.epoch, token: context.session.token)
    }

    private func makeUnavailableShelf(context: RuntimeDependencyContext, approval: BundleFeatureApproval?) -> (any BundleShelfClient)? {
        guard accepted(approval, feature: .shelf, context: context) else { return nil }
        return UnavailableBundleShelfClient()
    }

    private func makeUnavailableVoucher(context: RuntimeDependencyContext, approval: BundleFeatureApproval?) -> (any BundleVoucherServing)? {
        guard accepted(approval, feature: .voucher, context: context) else { return nil }
        return UnavailableBundleVoucherClient()
    }

    private func makeUnavailableOffer(context: RuntimeDependencyContext, approval: BundleFeatureApproval?) -> (any BundleOfferClient)? {
        guard accepted(approval, feature: .offer, context: context) else { return nil }
        return UnavailableBundleOfferClient()
    }

    private func makeUnavailableReview(context: RuntimeDependencyContext, approval: BundleFeatureApproval?) -> (any BundleReviewServing)? {
        guard accepted(approval, feature: .review, context: context) else { return nil }
        return UnavailableBundleReviewClient()
    }

    private func makeUnavailableRenewal(context: RuntimeDependencyContext, approval: BundleFeatureApproval?) -> (any BundleRenewalServing)? {
        guard accepted(approval, feature: .renewal, context: context) else { return nil }
        return BundleRenewalUnavailableService()
    }
}
