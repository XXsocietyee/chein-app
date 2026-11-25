import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private final class MPGapMockTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var responseBody = #"{"code":200,"data":{}}"#
    var statusCode = 200

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(responseBody.utf8), statusCode)
    }
}

final class MPGapG1Tests: XCTestCase {
    func testTopicTemplatePreviewFromWireBuildsDeckAndChecks() throws {
        let json = """
        {
          "name": "老城寻踪",
          "productType": 1,
          "totalTime": 5400,
          "finishMedalName": "城市行者",
          "chapters": [{"name": "第一章", "nodeCount": 4}, {"name": "第二章", "nodeCount": 3}],
          "games": [{"title": "线索推理", "duration": 15}, {"title": "密码破译", "duration": 20}]
        }
        """
        let wire = try JSONDecoder().decode(PlayWireValue.self, from: Data(json.utf8))
        let preview = TopicTemplatePreviewData.fromWire(wire, templateID: 42)
        XCTAssertEqual(preview.name, "老城寻踪")
        XCTAssertEqual(preview.cards.count, 3)
        XCTAssertTrue(preview.cards[0].isCover)
        XCTAssertEqual(preview.cards[0].steps, ["线索推理", "密码破译"])
        XCTAssertEqual(preview.checks, ["2 章节 · 7 节点", "约 1 小时30 分", "勋章「城市行者」"])
    }

    func testObjectCardRenameValidatorClampsTo64() {
        let long = String(repeating: "城", count: 80)
        let clamped = ObjectCardRenameValidator.clamped(long)
        XCTAssertEqual(clamped.count, 64)
        XCTAssertFalse(ObjectCardRenameValidator.isValid("   "))
        XCTAssertTrue(ObjectCardRenameValidator.isValid("外滩记忆"))
    }

    func testOrientAppealValidatorRequiresNodeIDForMissingTask() {
        XCTAssertFalse(OrientAppealValidator.isValid(kind: .appeal, entryID: nil, nodeIDText: "", reason: "漏记了"))
        XCTAssertFalse(OrientAppealValidator.isValid(kind: .appeal, entryID: nil, nodeIDText: "abc", reason: "漏记了"))
        XCTAssertTrue(OrientAppealValidator.isValid(kind: .appeal, entryID: nil, nodeIDText: "102", reason: "漏记了"))
        XCTAssertTrue(OrientAppealValidator.isValid(kind: .appeal, entryID: "e1", nodeIDText: "", reason: "计分有误"))
    }

    func testReportAppealValidatorClampsAndValidates() {
        let over = String(repeating: "a", count: 1200)
        XCTAssertEqual(ReportAppealValidator.clamp(over).count, 1000)
        XCTAssertFalse(ReportAppealValidator.isValid("\n "))
        XCTAssertTrue(ReportAppealValidator.isValid("核查事实补充说明"))
    }

    func testMerchantCouponSummaryDecodesFromWire() throws {
        let wire = try JSONDecoder().decode(
            PlayWireValue.self,
            from: Data(#"{"totalClaimed":18,"totalRedeemed":7}"#.utf8)
        )
        let summary = MerchantCouponSummary.fromWire(wire)
        XCTAssertEqual(summary.totalClaimed, 18)
        XCTAssertEqual(summary.totalRedeemed, 7)
    }

    @MainActor
    func testServicesBuildExpectedPaths() async {
        let transport = MPGapMockTransport()
        let baseURL = URL(string: "https://example.com")!

        let pc = PlayerContentGapService(baseURL: baseURL, token: { "valid-token-123" }, transport: transport)
        _ = await pc.fetchTopicRouteNodes(topicID: 9)
        _ = await pc.checkOrientSafety(topicID: 9)

        let pr = PlayRoamGapService(baseURL: baseURL, token: { "valid-token-123" }, transport: transport)
        _ = await pr.fetchNearbyRunners(latitude: 31.23, longitude: 121.47)
        _ = await pr.deleteComment(id: 55)

        let mb = MemberGapService(baseURL: baseURL, token: { "valid-token-123" }, transport: transport)
        _ = await mb.fetchMerchantCouponSummary()
        _ = await mb.submitReportAppeal(reportID: 3, reason: "复核", requestID: "req-1")

        XCTAssertEqual(String(data: transport.requests[2].httpBody ?? Data(), encoding: .utf8), "lat=31.23&lng=121.47&radius=3000")
        let urls = transport.requests.compactMap { $0.url?.path }
        XCTAssertEqual(urls, [
            "/api/play/nodes",
            "/api/orient/safety/check",
            "/api/roam/nearby-runners",
            "/api/comment/delete",
            "/api/merchant/coupon-summary",
            "/api/community-trust/reports/appeal"
        ])
    }

    func testRunnersPreferencesAndNoGreetPath() throws {
        let wire = try JSONDecoder().decode(PlayWireValue.self, from: Data(#"[{"memberId":2,"lat":"31.2","lng":121.4,"elapsedSec":30,"shopPhotos":[{"name":"店","image":"a"},{"name":"空"}]}]"#.utf8))
        let runners = RoamNearbyRunner.normalized(wire.array ?? [])
        XCTAssertEqual(runners.count, 1)
        XCTAssertEqual(runners[0].nickname, "漫游者")
        XCTAssertEqual(runners[0].elapsedLabel, "00:30")
        XCTAssertEqual(runners[0].sinceLabel, "刚出发")
        XCTAssertEqual(runners[0].shopPhotos.map(\.image), ["a"])
        XCTAssertFalse(runners[0].greeted)
        let source = PlayRoamGapService.paths
        XCTAssertTrue(source.contains("api/roam/nearby-runners"))
        XCTAssertFalse(source.contains("api/roam/greet"))
        let defaults = UserDefaults(suiteName: "r8-play-roam-prefs")!
        defaults.removePersistentDomain(forName: "r8-play-roam-prefs")
        XCTAssertTrue(PlatformBGMPreference.isEnabled(in: defaults))
        PlatformBGMPreference.set(false, in: defaults)
        XCTAssertFalse(PlatformBGMPreference.isEnabled(in: defaults))
        XCTAssertTrue(PlatformNarrationAutoplayPreference.isEnabled(in: defaults))
        XCTAssertFalse(RoamFogPreference.fogOff(in: defaults))
        XCTAssertTrue(RoamFogPreference.setFogOff(true, in: defaults))
        XCTAssertTrue(RoamFogPreference.fogOff(in: defaults))
        XCTAssertEqual(FreeMapKind.read(in: defaults), .black)
        XCTAssertTrue(FreeMapKind.save(.year2077, in: defaults))
        XCTAssertEqual(FreeMapKind.read(in: defaults), .year2077)
        XCTAssertEqual(FreeMapKind.year2077.label, "2077")
        XCTAssertFalse(PlayReducedMotionPreference.isEnabled(in: defaults))
        defaults.set(true, forKey: PlayReducedMotionPreference.legacyKey)
        XCTAssertTrue(PlayReducedMotionPreference.isEnabled(in: defaults))
        PlayReducedMotionPreference.set(false, in: defaults)
        XCTAssertFalse(PlayReducedMotionPreference.isEnabled(in: defaults))
    }
}
