import Foundation

/// Exact mini-program paths for the merchant-coop coverage lane that starts at
/// `pages/merchant/decor/coop-setting/index.js` on hengyin `chengyinhub-xcx` `25eb6a0c`.
/// Each literal is the URL the page sends. Payout, refund, withdrawal, and both IM
/// mark-read switches stay off; nothing in this type builds or sends a request.
public enum MerchantCoopLaneBContract {
    /// `pages/merchant/verify-records/index.js` POST with no body.
    public static let arrivalsTodayPath = "api/merchant/desk/arrivals/today"

    /// `pages/merchant/reviews/reply-recovery.js` chooses one of these three POST urls
    /// inside the callback passed to its local `request`. The checker records that outer
    /// call, which has no url of its own.
    public static let reviewReplyPath = "api/merchant/reviews/reply"
    public static let reviewReplyUpdatePath = "api/merchant/reviews/reply/update"
    public static let reviewReplyDeletePath = "api/merchant/reviews/reply/delete"
}
