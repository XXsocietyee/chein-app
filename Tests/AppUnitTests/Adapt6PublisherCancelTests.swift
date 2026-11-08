import XCTest
@testable import Questify

/// ADAPT-6. Fixtures mirror ApiTopicController.topicCancelPreview / ApiActivityController.activityCancelPreview
/// (AjaxResult {code,msg,data}). Pure adapter checks; no network.
final class Adapt6PublisherCancelTests: XCTestCase {
    private let topicPreview = #"{"code":200,"msg":"操作成功","data":{"paidPlayers":3,"cancellationEpoch":2}}"#
    private let activityPreview = #"{"code":200,"msg":"操作成功","data":{"paidPlayers":4}}"#

    private func data(_ envelope: String) throws -> ProjectEditJSON {
        let json = try JSONDecoder().decode(ProjectEditJSON.self, from: Data(envelope.utf8))
        return try XCTUnwrap(json.object?["data"])
    }

    func testLiteralRoutes() throws {
        let topic = try PublisherCancelRoute(.topic), activity = try PublisherCancelRoute(.activity)
        XCTAssertEqual(topic.cancelPath, "api/topic/cancel")
        XCTAssertEqual(topic.previewPath, "api/topic/cancel_preview")
        XCTAssertEqual(activity.cancelPath, "api/activity/cancel")
        XCTAssertEqual(activity.previewPath, "api/activity/cancel_preview")
    }

    func testTemplateIsRefusedBeforeAnyRequest() {
        XCTAssertThrowsError(try PublisherCancelRoute(.template)) { XCTAssertEqual($0 as? PublisherLifecycleError, .forbidden) }
    }

    func testTopicPreviewCarriesEpoch() throws {
        let preview = try PublisherCancelPreviewData(route: .topic, data: data(topicPreview))
        XCTAssertEqual(preview.paidPlayers, 3)
        XCTAssertEqual(preview.cancellationEpoch, 2)
    }

    func testTopicPreviewWithoutEpochIsIncomplete() throws {
        XCTAssertThrowsError(try PublisherCancelPreviewData(route: .topic, data: data(activityPreview)))
    }

    func testActivityPreviewHasNoEpoch() throws {
        let preview = try PublisherCancelPreviewData(route: .activity, data: data(activityPreview))
        XCTAssertEqual(preview.paidPlayers, 4)
        XCTAssertNil(preview.cancellationEpoch)
    }

    func testNegativeOrMissingCountIsRejected() throws {
        XCTAssertThrowsError(try PublisherCancelPreviewData(route: .activity, data: data(#"{"code":200,"data":{}}"#)))
        XCTAssertThrowsError(try PublisherCancelPreviewData(route: .activity, data: data(#"{"code":200,"data":{"paidPlayers":-1}}"#)))
    }

    func testTopicCancelFieldsCarryScopeAndEpoch() throws {
        let fields = try PublisherCancelFields.cancel(route: .topic, id: 5, reason: "Weather", scope: "MERCHANT", epoch: 2)
        XCTAssertEqual(fields, ["id": .string("5"), "reason": .string("Weather"), "scope": .string("MERCHANT"), "cancellationEpoch": .string("2")])
    }

    func testTopicCancelWithoutEpochOmitsField() throws {
        let fields = try PublisherCancelFields.cancel(route: .topic, id: 5, reason: "Weather", scope: nil, epoch: nil)
        XCTAssertEqual(fields, ["id": .string("5"), "reason": .string("Weather")])
    }

    func testActivityCancelNeverSendsScopeOrEpoch() throws {
        let fields = try PublisherCancelFields.cancel(route: .activity, id: 5, reason: "Weather", scope: "MERCHANT", epoch: 2)
        XCTAssertEqual(fields, ["id": .string("5"), "reason": .string("Weather")])
    }

    func testInvalidIdentityIsRejected() {
        XCTAssertThrowsError(try PublisherCancelFields.cancel(route: .topic, id: 0, reason: "x", scope: nil, epoch: nil))
        XCTAssertThrowsError(try PublisherCancelFields.cancel(route: .topic, id: 1, reason: "x", scope: nil, epoch: -1))
    }

    func testRewardStaffRoutesKeepCouponOrderOnly() {
        XCTAssertEqual(RewardPledgeRoutes.staffRedeem,
                       ["api/coupon/qr-token", "api/coupon/status", "api/coupon/verification", "api/coupon/myrecvlist"])
        XCTAssertFalse(RewardPledgeRoutes.staffRedeem.contains { $0.hasPrefix("api/rewards/pledge/") })
    }
}
