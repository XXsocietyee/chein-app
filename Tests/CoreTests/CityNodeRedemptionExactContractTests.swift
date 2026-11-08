#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

private actor ExactRedeemTransport: MerchantBusinessTestTransport {
    var response = ""
    var throwAfterSend = false
    private(set) var requests: [URLRequest] = []
    let access = #"{"code":200,"data":{"active":true,"merchant":{"id":19},"roleCode":"MERCHANT_CHECKIN","permissions":["merchant:verify"]}}"#
    func setResponse(_ value: String) { response = value }
    func fail() { throwAfterSend = true }
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        if request.url!.path.hasSuffix("access/me") { return (Data(access.utf8), 200) }
        if throwAfterSend { throw URLError(.timedOut) }
        return (Data(response.utf8), 200)
    }
}

/// Current (hardened) city-node redemption contract: only the exact original success text with a
/// matching poi/member echo is a success; every other decodable body stays UNKNOWN and locks the target.
final class CityNodeRedemptionExactContractTests: XCTestCase {
    private let code = "v1.2.citynode_9.0.fixture.signature"
    private let success = "{\"code\":200,\"msg\":\"核销成功,券已发放玩家\",\"data\":{\"poiId\":2,\"memberId\":9,\"couponId\":3,\"couponGranted\":true}}"
    private func service(_ t: ExactRedeemTransport) throws -> MerchantBusinessService {
        .init(configuration: try .init(baseURL: URL(string: "https://example.com/test/")!), readTransport: t, testingMutationTransport: t)
    }
    @MainActor private func confirmed(_ t: ExactRedeemTransport, journal: MerchantBusinessMemoryIntentStore) async throws -> CityNodeRedemptionCoordinator {
        let session = try MerchantBusinessSession(accountID: 8, epoch: 1, token: "synthetic")
        let c = CityNodeRedemptionCoordinator(service: try service(t), journal: journal, currentSession: { session })
        await c.prepare(code)
        let id = try XCTUnwrap(c.review).id
        await c.confirm(id)
        return c
    }
    @MainActor func testExactOriginalSuccessIsRedeemedAndReleasesLock() async throws {
        let t = ExactRedeemTransport(), journal = MerchantBusinessMemoryIntentStore()
        await t.setResponse(success)
        let c = try await confirmed(t, journal: journal)
        XCTAssertEqual(c.result?.redeemed, true)
        XCTAssertEqual(c.result?.message, "核销成功,券已发放玩家")
        XCTAssertNil(c.pendingScope)
        XCTAssertTrue(try journal.intents().isEmpty)
        let requests = await t.requests
        XCTAssertEqual(requests.filter { $0.url!.path.hasSuffix("citynode/redeem") }.count, 1)
    }
    @MainActor func testExactKnownRefusalIsFailedAndReleasesLock() async throws {
        let t = ExactRedeemTransport(), journal = MerchantBusinessMemoryIntentStore()
        await t.setResponse(#"{"code":500,"msg":"玩家未到店打卡,或该券已核销"}"#)
        let c = try await confirmed(t, journal: journal)
        XCTAssertEqual(c.result?.redeemed, false)
        XCTAssertEqual(c.result?.isUnknown, false)
        XCTAssertEqual(c.result?.message, "玩家未到店打卡,或该券已核销")
        XCTAssertTrue(try journal.intents().isEmpty)
        c.next()
        XCTAssertNil(c.result)
        await c.prepare("v1.2.citynode_10.0.fixture.signature")
        XCTAssertNotNil(c.review)
    }
    @MainActor func testInexactSuccessMessageStaysUnknownAndLocksTarget() async throws {
        let t = ExactRedeemTransport(), journal = MerchantBusinessMemoryIntentStore()
        await t.setResponse(#"{"code":200,"msg":"已发放测试券"}"#)
        let c = try await confirmed(t, journal: journal)
        XCTAssertEqual(c.result?.isUnknown, true)
        XCTAssertEqual(c.result?.redeemed, false)
        XCTAssertEqual(c.pendingScope, .target)
        XCTAssertEqual(try journal.intents().count, 1)
        // The same target cannot be submitted again, even after Next.
        c.next()
        await c.prepare(code)
        XCTAssertNil(c.review)
        XCTAssertEqual(c.failure, "merchant.cityRedeem.pending")
        let requests = await t.requests
        XCTAssertEqual(requests.filter { $0.url!.path.hasSuffix("citynode/redeem") }.count, 1)
    }
    @MainActor func testTransportTimeoutIsUnknownNotFailure() async throws {
        let t = ExactRedeemTransport(), journal = MerchantBusinessMemoryIntentStore()
        let session = try MerchantBusinessSession(accountID: 8, epoch: 1, token: "synthetic")
        let c = CityNodeRedemptionCoordinator(service: try service(t), journal: journal, currentSession: { session })
        await c.prepare(code)
        let id = try XCTUnwrap(c.review).id
        await t.fail()
        await c.confirm(id)
        XCTAssertEqual(c.result?.isUnknown, true)
        XCTAssertEqual(try journal.intents().count, 1)
    }
}
#endif
