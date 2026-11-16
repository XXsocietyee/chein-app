import Foundation

/// Acceptance R2 F-14. Routes the China production backend does not serve yet (true gaps in `RePoint10Routes`) but the
/// TEST backend does: the topic edit-request (publish / cloud-draft) receipts and publish-status. A DEBUG
/// `--e2e-test-host` run names the production base URL and only rewrites it to the TEST host after every route guard has
/// run, so the production route table refused them and the topic review sheet fell back to "发布暂不可用".
///
/// Only the DEBUG E2E composition turns this on (`RegionalLaunchConfiguration.composition`). Release compiles a constant
/// false, so production never admits these paths. No path here moves money.
public enum TestHostOnlyRouteAdmission {
    public static let rawPaths: [String] = [
        "/api/topic/edit-requests/read",
        "/api/topic/edit-requests/submit",
        "/api/topic/edit-requests/resume-post-processing",
        "/api/topic/publish-status"
    ]
    public static let paths: Set<String> = Set(rawPaths.map(ChinaReviewedRouteCapability.normalized))

    #if DEBUG || TEST
    /// DEBUG/TEST only. Off by default; a unit test that turns it on must turn it off again.
    nonisolated(unsafe) public static var testHostActive = false
    #else
    public static let testHostActive = false
    #endif

    /// `path` is a `ChinaReviewedRouteCapability.normalized` key.
    public static func admits(_ path: String) -> Bool {
        testHostActive && paths.contains(path)
    }
}
