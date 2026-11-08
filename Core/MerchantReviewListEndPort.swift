import Foundation

/// Port-2: mini-program reviews list shows "已经到底了" once everything is loaded and at least one review exists
/// (pages/merchant/reviews/index.wxml `review-list-end`). Presentation-only.
public enum MerchantReviewListEndPort {
    public static func showsEnd(hasMore: Bool, loadedCount: Int) -> Bool { !hasMore && loadedCount > 0 }
}
