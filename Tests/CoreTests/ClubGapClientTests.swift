import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

final class ClubGapClientTests: XCTestCase {
    private let base = URL(string: "https://test.example/prod-api/")!

    func testExportStaysUnsentUntilPayoutAndNeverTreatsAnErrorAsSuccess() async {
        let script = ClubGapScript()
        let client = ClubGapClient(baseURL: base, transport: script)
        let call = ClubGapSurface.all.first { $0.path == ClubGapPaths.settlementsExport }!.call()
        let withheld = await client.perform(call, token: "token", allowsPayout: false, allowsMerchantWrite: false)
        XCTAssertEqual(withheld, .withheld)
        XCTAssertFalse(withheld.sent)
        XCTAssertFalse(withheld.succeeded)
        XCTAssertEqual(withheld.message, "\u{2014}")
        XCTAssertNotEqual(withheld.message, "0")
        XCTAssertTrue(script.sent.isEmpty)

        script.result = .success((Data(#"{"code":403,"msg":"没有结算权限","errorCode":"FORBIDDEN"}"#.utf8), 403))
        let refused = await client.perform(call, token: "token", allowsPayout: true, allowsMerchantWrite: false)
        XCTAssertTrue(refused.sent)
        XCTAssertFalse(refused.succeeded)
        XCTAssertEqual(refused.code, 403)
        XCTAssertEqual(refused.errorCode, "FORBIDDEN")
        XCTAssertEqual(script.sent.count, 1)
    }

    func testSuccessRequiresHTTPAndBodyCodeAndUnknownStaysAnEmDash() async {
        let script = ClubGapScript()
        script.result = .success((Data(#"{"code":200,"data":{"payout":false}}"#.utf8), 200))
        let client = ClubGapClient(baseURL: base, transport: script)
        let call = ClubGapSurface.all.first { $0.path == ClubGapPaths.channels }!.call()
        let ready = await client.perform(call, token: "token", allowsPayout: false, allowsMerchantWrite: false)
        XCTAssertTrue(ready.succeeded)
        XCTAssertEqual(ready.message, "\u{2014}")
        XCTAssertNotEqual(ready.message, "0")

        script.result = .success((Data(#"{"code":true,"msg":"0"}"#.utf8), 200))
        let boolCode = await client.perform(call, token: "token", allowsPayout: false, allowsMerchantWrite: false)
        XCTAssertFalse(boolCode.succeeded)
        XCTAssertNil(boolCode.code)

        script.result = .success((Data(#"{"msg":"ok"}"#.utf8), 200))
        let missing = await client.perform(call, token: "token", allowsPayout: false, allowsMerchantWrite: false)
        XCTAssertFalse(missing.succeeded)
    }

    func testMerchantWriteIsWithheldAndLeadUsesGET() async throws {
        let script = ClubGapScript()
        let client = ClubGapClient(baseURL: base, transport: script)
        let invite = ClubGapSurface.merchantInvite(topicID: 2, recipientID: 9)
        let withheld = await client.perform(invite, token: "token", allowsPayout: false, allowsMerchantWrite: false)
        XCTAssertEqual(withheld, .withheld)
        XCTAssertTrue(script.sent.isEmpty)

        let lead = ClubGapSurface.all.first { $0.path == ClubGapPaths.lead }!.call()
        let request = try ClubGapClient.request(baseURL: base, call: lead, token: "token")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertNil(request.httpBody)
        XCTAssertEqual(request.url?.absoluteString, "https://test.example/prod-api/api/club/lead?activityId=2")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "token")
    }

    func testGuestPostSendsAndASignedOutWriteDoesNot() async {
        let script = ClubGapScript()
        script.result = .success((Data(#"{"code":200,"msg":"ok"}"#.utf8), 200))
        let client = ClubGapClient(baseURL: base, transport: script)
        let posts = ClubGapSurface.all.first { $0.path == ClubGapPaths.post }!.call()
        let guest = await client.perform(posts, token: nil, allowsPayout: false, allowsMerchantWrite: false)
        XCTAssertTrue(guest.succeeded)
        XCTAssertEqual(script.sent.count, 1)

        let roles = ClubGapSurface.all.first { $0.path == ClubGapPaths.roles }!.call()
        let signedOut = await client.perform(roles, token: nil, allowsPayout: false, allowsMerchantWrite: false)
        XCTAssertEqual(signedOut, .withheld)
        XCTAssertEqual(script.sent.count, 1)
    }

    func testCatalogCoversEveryNamedPath() {
        XCTAssertEqual(ClubGapSurface.all.map(\.path), ClubGapPaths.catalog)
        XCTAssertEqual(ClubGapPaths.catalog.count, 22)
        XCTAssertFalse(ClubGapPaths.catalog.contains(ClubGapPaths.merchantCooperationWrite))
    }
}

private final class ClubGapScript: HTTPTransport, @unchecked Sendable {
    var sent: [URLRequest] = []
    var result: Result<(Data, Int), Error> = .success((Data("{}".utf8), 200))
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        sent.append(request)
        return try result.get()
    }
}
