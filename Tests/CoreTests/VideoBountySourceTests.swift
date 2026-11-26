import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class VideoBountySourceTests: XCTestCase {
    func testReadsAreTheMineListsAndTheCampaignList() async throws {
        let wire = Wire(body: Data(#"{"code":200,"data":[]}"#.utf8))
        let source = try make(wire)
        _ = try await source.submissions(token: "session-token")
        _ = try await source.accruals(token: "session-token")
        _ = try await source.campaigns(token: "session-token")
        XCTAssertEqual(wire.requests.map { $0.httpMethod }, ["GET", "GET", "GET"])
        XCTAssertEqual(wire.requests.map { $0.url?.path }, [
            "/api/video-bounty/submission/mine",
            "/api/video-bounty/accrual/mine",
            "/api/video-bounty/campaign/list"
        ])
        XCTAssertTrue(wire.requests.allSatisfy { $0.url?.query == nil })
    }

    func testCampaignListKeepsOnlyServerRows() {
        let payload = Data(#"""
        {"code":200,"data":[
          {"campaignKey":"spring","title":"Spring","description":"Open","windowDays":14,"ratePerThousand":3,"perVideoCap":100,"budget":9,"payoutState":2},
          {"title":"Missing key","windowDays":7},
          {"campaignKey":"  ","title":"Blank"},
          {"campaignKey":12,"title":"Numeric key"},
          {"campaignKey":"fall","windowDays":true,"description":""}
        ]}
        """#.utf8)
        let rows = VideoBountySource.campaigns(in: VideoBountySource.envelope(data: payload, status: 200, receiptReread: false))
        XCTAssertEqual(rows, [
            VideoBountyCampaign(campaignKey: "spring", title: "Spring", description: "Open", windowDays: 14),
            VideoBountyCampaign(campaignKey: "fall", title: nil, description: nil, windowDays: nil)
        ])
    }

    func testEmptyCampaignListStaysEmptyAndANonArrayDoesNotBecomeOne() {
        let empty = VideoBountySource.envelope(data: Data(#"{"code":200,"data":[]}"#.utf8), status: 200, receiptReread: false)
        XCTAssertEqual(VideoBountySource.campaigns(in: empty), [])
        let object = VideoBountySource.envelope(data: Data(#"{"code":200,"data":{"campaignKey":"made-up"}}"#.utf8), status: 200, receiptReread: false)
        XCTAssertNil(VideoBountySource.campaigns(in: object))
    }

    func testMissingAmountIsNilAndARecordedZeroStaysZero() {
        let payload = Data(#"""
        {"code":200,"data":[
          {"id":1,"payableAmount":null,"currency":"CNY","basisViews":null,"groupBasisViews":4,"payoutState":2,"ratePerThousand":9,"grossAmount":9},
          {"id":2,"payableAmount":0,"basisViews":3,"groupBasisViews":3},
          {"id":3,"payableAmount":"12.30","currency":"USD","basisViews":8,"groupBasisViews":11},
          {"id":4,"payableAmount":true}
        ]}
        """#.utf8)
        let rows = VideoBountySource.accruals(in: VideoBountySource.envelope(data: payload, status: 200, receiptReread: false))
        XCTAssertEqual(rows, [
            VideoBountyAccrualFact(id: "1", amountText: nil, views: nil, groupViews: 4),
            VideoBountyAccrualFact(id: "2", amountText: "¥0.00", views: 3, groupViews: 3),
            VideoBountyAccrualFact(id: "3", amountText: "USD 12.30", views: 8, groupViews: 11),
            VideoBountyAccrualFact(id: "4", amountText: nil, views: nil, groupViews: nil)
        ])
    }

    func testSubmissionRulesMatchTheMiniProgram() {
        let payload = Data(#"""
        {"code":200,"data":[
          {"id":7,"platform":"tiktok","sourceUrl":"https://www.tiktok.com/v/1","statusLabel":"REJECTED","reviewNote":"no","windowEndsAt":"2026-11-30 00:00:00"},
          {"id":8,"platform":"other","statusLabel":"APPROVED","windowEndsAt":"2026-11-30 00:00:00","reviewNote":"hidden"},
          {"id":9,"statusLabel":"CANCELLED"},
          {"id":"0","statusLabel":"SUBMITTED"}
        ]}
        """#.utf8)
        let rows = VideoBountySource.submissions(in: VideoBountySource.envelope(data: payload, status: 200, receiptReread: false))
        XCTAssertEqual(rows?.count, 3)
        XCTAssertEqual(rows?[0].canAppeal, true)
        XCTAssertEqual(rows?[0].canCancel, true)
        XCTAssertEqual(rows?[0].reviewNote, "no")
        XCTAssertNil(rows?[0].windowEndText)
        XCTAssertEqual(rows?[1].windowEndText, "2026.11.30")
        XCTAssertEqual(rows?[1].canAppeal, false)
        XCTAssertEqual(rows?[1].canCancel, false)
        XCTAssertNil(rows?[1].platform)
        XCTAssertNil(rows?[1].reviewNote)
        XCTAssertEqual(rows?[2].statusLabel, "CANCELLED")
        XCTAssertEqual(rows?[2].canCancel, false)
    }

    func testUnknownSubmitStaysOnTheSameRequestIdUntilAConfirmedAnswer() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(statuses: [503, 503, 409], bodies: [
            Data(#"{"code":503,"msg":"busy"}"#.utf8),
            Data(#"{"code":503,"msg":"busy"}"#.utf8),
            Data(#"{"code":409,"reasonCode":"VIDEO_ALREADY_SUBMITTED","msg":"dup"}"#.utf8)
        ])
        let source = try make(wire, store: store)
        let first = try await source.submit(campaignKey: "spring", topicID: "15", platform: "tiktok",
                                            sourceURL: " https://www.tiktok.com/v/1 ", originGroupKey: " ", token: "session-token")
        XCTAssertFalse(first.confirmed)
        XCTAssertFalse(first.receiptReread)
        let saved = store.read(VideoBountyRequestKey.submit)
        XCTAssertEqual(saved, JourneyLoopSource.makeRequestID(prefix: "vbsub", nowMillis: 1_700_000_000_000, entropy: "abcd1234"))
        let firstBody = try XCTUnwrap(wire.requests[0].httpBody)

        let again = try await source.submit(campaignKey: "other", topicID: "99", platform: "youtube",
                                            sourceURL: "https://youtu.be/nope", originGroupKey: "changed", token: "session-token")
        XCTAssertFalse(again.confirmed)
        XCTAssertTrue(again.receiptReread)
        XCTAssertEqual(wire.requests[1].httpBody, firstBody)
        XCTAssertEqual(store.read(VideoBountyRequestKey.submit), saved)

        let receipt = try await source.rereadSubmit(token: "session-token")
        XCTAssertTrue(receipt.confirmed)
        XCTAssertFalse(receipt.ok)
        XCTAssertEqual(receipt.reasonCode, "VIDEO_ALREADY_SUBMITTED")
        XCTAssertTrue(receipt.receiptReread)
        XCTAssertEqual(wire.requests[2].httpBody, firstBody)
        XCTAssertNil(store.read(VideoBountyRequestKey.submit))
        XCTAssertEqual(wire.requests.map { $0.url?.path }, Array(repeating: "/api/video-bounty/submission", count: 3))
        let object = try XCTUnwrap(json(firstBody))
        XCTAssertEqual(object["requestId"] as? String, saved)
        XCTAssertEqual(object["campaignKey"] as? String, "spring")
        XCTAssertEqual((object["topicId"] as? NSNumber)?.intValue, 15)
        XCTAssertEqual(object["platform"] as? String, "tiktok")
        XCTAssertEqual(object["sourceUrl"] as? String, "https://www.tiktok.com/v/1")
        XCTAssertTrue(object["originGroupKey"] is NSNull)
    }

    func testAppealAndCancelLockTheirOwnIdsAndASuccessClearsOnlyThatId() async throws {
        let store = JourneyMemoryRequestStore()
        let wire = Wire(statuses: [500, 200], bodies: [
            Data(#"{"code":500}"#.utf8),
            Data(#"{"code":200,"data":{"id":44,"statusLabel":"CANCELLED"}}"#.utf8)
        ])
        let source = try make(wire, store: store)
        let appeal = try await source.appeal(submissionID: "44", note: "  explain  ", token: "session-token")
        XCTAssertFalse(appeal.confirmed)
        let appealID = store.read(VideoBountyRequestKey.appeal("44"))
        XCTAssertNotNil(appealID)
        let cancel = try await source.cancel(submissionID: "44", token: "session-token")
        XCTAssertTrue(cancel.ok)
        XCTAssertFalse(cancel.receiptReread)
        XCTAssertNil(store.read(VideoBountyRequestKey.cancel("44")))
        XCTAssertEqual(store.read(VideoBountyRequestKey.appeal("44")), appealID)
        XCTAssertEqual(wire.requests[0].url?.path, "/api/video-bounty/submission/44/appeal")
        XCTAssertEqual(wire.requests[1].url?.path, "/api/video-bounty/submission/44/cancel")
        let appealBody = try XCTUnwrap(json(wire.requests[0].httpBody))
        XCTAssertEqual(appealBody["note"] as? String, "explain")
        XCTAssertEqual(appealBody["requestId"] as? String, appealID)
        let cancelBody = try XCTUnwrap(json(wire.requests[1].httpBody))
        XCTAssertEqual(cancelBody["requestId"] as? String,
                       JourneyLoopSource.makeRequestID(prefix: "vbcxl", nowMillis: 1_700_000_000_000, entropy: "abcd1234"))
        XCTAssertEqual(cancelBody.count, 1)
    }

    func testRereadWithoutASavedIdSendsNothing() async throws {
        let wire = Wire()
        let source = try make(wire)
        do {
            _ = try await source.rereadCancel(submissionID: "44", token: "session-token")
            XCTFail("missing")
        } catch VideoBountyRefusal.noSavedRequest {}
        do {
            _ = try await source.submit(campaignKey: "spring", topicID: "0", platform: "tiktok",
                                       sourceURL: "https://www.tiktok.com/v/1", originGroupKey: "", token: "session-token")
            XCTFail("topic")
        } catch VideoBountyRefusal.invalidRequest {}
        XCTAssertTrue(wire.requests.isEmpty)
    }

    func testChinaGrantAdmitsOnlyTheVideoBountyPathsThisClientCalls() {
        for path in VideoBountySource.paths {
            XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/video-bounty/submission/44/appeal"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/video-bounty/submission/44/cancel"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/video-bounty/submission/44/attribution"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/video-bounty/campaign/9/attribution"))
        for path in [
            "/api/video-bounty/payout",
            "/api/video-bounty/withdraw",
            "/api/video-bounty/redeem",
            "/api/video-bounty/wallet"
        ] {
            XCTAssertFalse(VideoBountySource.paths.contains(path), path)
            XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall(path), path)
        }
        // The affiliate summary GET is admitted by the separate player-journey owner grant (cloud-stubs-affiliate); never a bounty path.
        XCTAssertFalse(VideoBountySource.paths.contains("/api/marketing/affiliate/summary"))
        // 679 + orient scoring session recovery.
        XCTAssertEqual(ChinaReviewedRouteCapability.wiredPatternCount, 680)
        XCTAssertFalse(VideoBountySource.paths.contains { path in
            ["payout", "withdraw", "redeem", "wallet"].contains { path.contains($0) }
        })
        XCTAssertTrue(VideoBountySource.paths.contains("/api/video-bounty/submission/{}/attribution"))
    }

    func testChinaHostSendsTheCampaignList() async throws {
        let wire = Wire(body: Data(#"{"code":200,"data":[]}"#.utf8))
        let source = try VideoBountySource(configuration: APIConfiguration(baseURL: URL(string: "https://www.chengyinhub.com/prod-api/")!),
                                           transport: wire, nowMillis: { 1_700_000_000_000 }, entropy: { "abcd1234" })
        let list = try await source.campaigns(token: "session-token")
        XCTAssertTrue(list.ok)
        XCTAssertEqual(wire.requests[0].url?.path, "/prod-api/api/video-bounty/campaign/list")
    }

    private func make(_ wire: Wire, store: JourneyMemoryRequestStore = JourneyMemoryRequestStore()) throws -> VideoBountySource {
        try VideoBountySource(configuration: APIConfiguration(baseURL: URL(string: "https://example.test")!),
                              transport: wire, store: store, nowMillis: { 1_700_000_000_000 }, entropy: { "abcd1234" })
    }

    private func json(_ data: Data?) -> [String: Any]? {
        guard let data else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var bodies: [Data]
        var statuses: [Int]
        var body: Data
        init(body: Data = Data(#"{"code":200}"#.utf8), statuses: [Int] = [], bodies: [Data] = []) {
            self.body = body
            self.statuses = statuses
            self.bodies = bodies
        }
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            let status = statuses.isEmpty ? 200 : statuses.removeFirst()
            let payload = bodies.isEmpty ? body : bodies.removeFirst()
            return (payload, status)
        }
    }
}
