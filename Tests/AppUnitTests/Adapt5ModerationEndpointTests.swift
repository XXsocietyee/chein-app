import XCTest
@testable import Questify

/// ADAPT-5 worker A. Verified against `ApiCommunityTrustController` (hengyin@4ac8c249):
/// `POST /api/community-trust/reports/submit`, JSON `CommunityReportSubmitRequest`, member token,
/// unauthenticated -> `{"code":401,"msg":"请先登录"}`, null body -> `{"code":400,"msg":"缺少举报参数"}`.
/// The snapshot field is a displayed label only; no request is built from it.
@MainActor final class Adapt5ModerationEndpointTests: XCTestCase {
    private struct AjaxFixture: Decodable { let code: Int; let msg: String }

    func testDefaultReportEndpointNamesTheRealBackendRoute() {
        let snapshot = PublishTopicModerationSnapshot.defaultReady
        XCTAssertEqual(snapshot.ugcReportEndpoint, "api/community-trust/reports/submit")
        XCTAssertNotEqual(snapshot.ugcReportEndpoint, "api/ugc/report")
    }

    func testReadinessCheckIsUnchanged() {
        XCTAssertTrue(PublishTopicModerationSnapshot.defaultReady.isAppStoreGuideline12Compliant)
        let empty = PublishTopicModerationSnapshot(ugcReportEndpoint: "  ")
        XCTAssertFalse(empty.isAppStoreGuideline12Compliant)
    }

    func testBlockEndpointLabelIsLeftAlone() {
        // `/api/ugc/block` is PARTIAL (IM-only block); it must not be repointed or claimed as content block.
        XCTAssertEqual(PublishTopicModerationSnapshot.defaultReady.ugcBlockUserEndpoint, "api/ugc/block")
    }

    func testRealBackendErrorShapesDecode() throws {
        let unauthorized = Data(#"{"msg":"请先登录","code":401}"#.utf8)
        let missing = Data(#"{"msg":"缺少举报参数","code":400}"#.utf8)
        XCTAssertEqual(try JSONDecoder().decode(AjaxFixture.self, from: unauthorized).code, 401)
        XCTAssertEqual(try JSONDecoder().decode(AjaxFixture.self, from: missing).msg, "缺少举报参数")
    }
}
