import SwiftUI

/// MKT-10-1 (MP BL-77, `subpackageMember/coupon/coupon-summary.js`): the merchant coupon page's 累计领取 / 累计核销
/// tiles. The MP reads `{ couponTotal, received, verified }` and hides the tiles when `couponTotal` is not a positive
/// integer (no coupons) or when either count is missing or invalid. Counts are never filled with 0.
enum CouponPageSummary {
    static func shape(_ data: PlayWireValue) -> MerchantCouponSummary? {
        func count(_ value: PlayWireValue) -> Int? {
            guard let n = value.tolerantInteger, n >= 0 else { return nil }
            return n
        }
        guard let total = count(data["couponTotal"]), total > 0,
              let received = count(data["received"]), let verified = count(data["verified"]) else { return nil }
        return MerchantCouponSummary(totalClaimed: received, totalRedeemed: verified)
    }
}

extension AppSession {
    /// MKT-10-1: one silent read of `POST /api/merchant/coupon-summary` (MP `loadSummary`, merchant scope only).
    /// A failure, a refusal or a changed session hides the tiles; it never blocks the list.
    func merchantCouponSummary() async -> MerchantCouponSummary? {
        guard let context = currentRuntimeDependencyContext else { return nil }
        let epoch = context.session.epoch, account = context.session.accountID
        let service = MemberGapService(baseURL: context.baseURL, token: { [weak self] in
            guard let now = self?.currentRuntimeDependencyContext, now.session.epoch == epoch,
                  now.session.accountID == account else { return nil }
            return now.session.token
        }, transport: runtimeHTTPTransport)
        guard case .ok(let data, _) = await service.fetchMerchantCouponSummary() else { return nil }
        guard let now = currentRuntimeDependencyContext, now.session.epoch == epoch, now.session.accountID == account else { return nil }
        return CouponPageSummary.shape(data)
    }
}
