import Foundation

/// fix-1128b-social gap #4 (audit H-06a, H-13a) and gap #27 (H-13b, O-11c).
/// The 发布 tab "+" (自由探索 / 城市定向 / 互动), the club 发布活动 sheet and 我的项目 activity 编辑 send the same
/// routes the mini-program sends (pages/publish/fabu, pages/publish/activity, subpackageMember/myproject). The server
/// still checks the account and the club role. Pricing writes, refunds, payouts and merchant routes are not in this list.
/// Kept outside `wiredPatterns` so `wiredPatternCount` does not move.
public enum PublishingTabRoutes {
    /// `BusinessRuntimeFeature.publishingRead` paths the shipped player/club composition grants. The AI draft quota is a
    /// separate `.publishingAIQuota` grant and is deliberately left out.
    public static let readPaths: [String] = [
        "api/project/state-requests/context", "api/project/state-requests/read", "api/activity/create-requests/read",
        "api/publish/home", "api/publisher/identity/status", "api/category/list", "api/user/list",
        "api/template/my-list", "api/project/my"
    ]
    /// `BusinessRuntimeFeature.publishingWrite` paths (activity create envelope, project state envelope, own deletes).
    public static let writePaths: [String] = [
        "api/project/state-requests/submit", "api/activity/create-requests/submit",
        "api/activity/create-requests/resume-post-processing", "api/activity/publish", "api/topic/create",
        "api/topic/delete", "api/topic/update_user_status", "api/activity/delete", "api/activity/update_publish_status",
        "api/template/delete", "api/template/updateLibraryStatus"
    ]
    /// Gap #27: 我的项目 → 编辑 reads the activity (`api/activity/info`) and saves it (`api/activity/update`,
    /// ApiActivityController.java:995 `@RequestBody CmsActivityPublishRequest`).
    public static let activityEditingPaths: [String] = ["api/activity/info", "api/activity/update"]

    /// Composition-transport admission set (relative, no leading slash).
    public static var all: Set<String> { Set(readPaths + writePaths + activityEditingPaths) }

    /// China production allow-list keys (leading slash), used by `ChinaReviewedRouteCapability.admitsChinaProductionCall`.
    public static let productionOwnerGrant: Set<String> = Set((readPaths + writePaths + activityEditingPaths).map { "/" + $0 })
}
