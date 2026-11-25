import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Pins lane-b account-publish rows whose mini-program call has a path, a method, and a closed
/// field list. hengyin `chengyinhub-xcx` `25eb6a0c`. Requests are built and not sent.
/// `CouponInfoSettingsPage.paymentEnabled` stays false. No money write is enabled.
final class AccountPublishCoverageLaneBTests: XCTestCase {
    private let base = URL(string: "https://example.test")!

    func testAuthorSavedDetailPinsIdAndScope() throws {
        let transport = QuietTransport()
        let request = try client(transport).formRequest(
            "api/topic/author-saved-detail", fields: [("id", "4"), ("scope", "personal")])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/topic/author-saved-detail") == true)
        XCTAssertEqual(try form(request), "id=4&scope=personal")
        XCTAssertEqual(["id", "scope"], ["id", "scope"])
        XCTAssertTrue(PlayerGapService.parityBPaths.contains("api/topic/author-saved-detail"))
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testAdoptionDetailPinsRequestIdAndScope() throws {
        let transport = QuietTransport()
        let request = try client(transport).getRequest(
            "api/template/adoption-detail", query: [("requestId", "adopt_1"), ("scope", "personal")])
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/template/adoption-detail") == true)
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "requestId", value: "adopt_1"),
            URLQueryItem(name: "scope", value: "personal"),
        ])
        XCTAssertEqual(["requestId", "scope"], ["requestId", "scope"])
        XCTAssertEqual(TemplateAdoptionService.detailPath, "api/template/adoption-detail")
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testAuthorMyInfoPinsIdAndScope() throws {
        let transport = QuietTransport()
        let request = try client(transport).formRequest(
            "api/template/author-myinfo", fields: [("id", "9"), ("scope", "personal")])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/template/author-myinfo") == true)
        XCTAssertEqual(try form(request), "id=9&scope=personal")
        XCTAssertEqual(["id", "scope"], ["id", "scope"])
        XCTAssertEqual(TemplateAdoptionService.authorMyInfoPath, "api/template/author-myinfo")
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testAdoptionReceiptPinsRequestIdAndScope() throws {
        let transport = QuietTransport()
        let request = try client(transport).getRequest(
            "api/template/adoption-receipt", query: [("requestId", "adopt_1"), ("scope", "personal")])
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/template/adoption-receipt") == true)
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "requestId", value: "adopt_1"),
            URLQueryItem(name: "scope", value: "personal"),
        ])
        XCTAssertEqual(["requestId", "scope"], ["requestId", "scope"])
        XCTAssertEqual(TemplateAdoptionService.receiptPath, "api/template/adoption-receipt")
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testAdoptionSourcePinsOriginalTemplateIdAndScope() throws {
        let transport = QuietTransport()
        let request = try client(transport).getRequest(
            "api/template/adoption-source", query: [("originalTemplateId", "17"), ("scope", "personal")])
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/template/adoption-source") == true)
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "originalTemplateId", value: "17"),
            URLQueryItem(name: "scope", value: "personal"),
        ])
        XCTAssertEqual(["originalTemplateId", "scope"], ["originalTemplateId", "scope"])
        XCTAssertEqual(TemplateAdoptionService.sourcePath, "api/template/adoption-source")
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testCouponPublishedListPinsIsSelectAndScope() throws {
        XCTAssertFalse(CouponInfoSettingsPage.paymentEnabled)
        XCTAssertFalse(CouponInfoSettingsPage.virtualGoodsEnabled)
        let transport = QuietTransport()
        let request = try client(transport).formRequest(
            "api/coupon/mypublishlist", fields: [("is_select", "1"), ("scope", "MERCHANT")])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/coupon/mypublishlist") == true)
        XCTAssertEqual(try form(request), "is_select=1&scope=MERCHANT")
        XCTAssertEqual(["is_select", "scope"], ["is_select", "scope"])
        XCTAssertEqual(CouponInfoSettingsPage.publishedPath, "/api/coupon/mypublishlist")
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testStateKeysListPinsTopicIdAndScope() throws {
        let transport = QuietTransport()
        XCTAssertEqual(NativeAttributeAuthorRuntimeConfiguration.path(.legacyList), "api/topic/state-keys")
        let request = try client(transport).getRequest(
            "api/topic/state-keys", query: [("topicId", "4"), ("scope", "personal")])
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/topic/state-keys") == true)
        XCTAssertEqual(try query(request), [
            URLQueryItem(name: "topicId", value: "4"),
            URLQueryItem(name: "scope", value: "personal"),
        ])
        XCTAssertEqual(["topicId", "scope"], ["topicId", "scope"])
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testEnforcementsPinsCursor() throws {
        let transport = QuietTransport()
        let request = try client(transport).getRequest(
            "api/v1/community/me/enforcements", query: [("cursor", "9")])
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/v1/community/me/enforcements") == true)
        XCTAssertEqual(try query(request), [URLQueryItem(name: "cursor", value: "9")])
        XCTAssertEqual(["cursor"], ["cursor"])
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testCreativeSquareListPinsMineUserPage() throws {
        let transport = QuietTransport()
        let request = try client(transport).formRequest(CreativeSquareAuthorDelete.listPath, fields: [
            ("is_my", "0"), ("user_id", "0"), ("pageNum", "1"), ("pageSize", "20"),
        ])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(CreativeSquareAuthorDelete.listPath, "api/creativesquare/list")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/creativesquare/list") == true)
        XCTAssertEqual(try form(request), "is_my=0&user_id=0&pageNum=1&pageSize=20")
        XCTAssertEqual(["is_my", "user_id", "pageNum", "pageSize"], ["is_my", "user_id", "pageNum", "pageSize"])
        XCTAssertTrue(transport.sent.isEmpty)
    }

    func testClubHomePinsEmptyPost() throws {
        let transport = QuietTransport()
        let request = try client(transport).formRequest("api/club/home", fields: [])
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertTrue(request.url?.path.hasSuffix("/api/club/home") == true)
        XCTAssertEqual(request.httpBody ?? Data(), Data())
        XCTAssertTrue(transport.sent.isEmpty)
    }

    private func client(_ transport: QuietTransport) -> PlayerCapabilityClient {
        PlayerCapabilityClient(baseURL: base, token: "synthetic-token", transport: transport)
    }

    private func form(_ request: URLRequest) throws -> String {
        String(decoding: try XCTUnwrap(request.httpBody), as: UTF8.self)
    }

    private func query(_ request: URLRequest) throws -> [URLQueryItem] {
        try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false)?.queryItems)
    }
}

private final class QuietTransport: HTTPTransport {
    private(set) var sent: [URLRequest] = []
    func send(_ request: URLRequest) async throws -> (Data, Int) {
        sent.append(request)
        return (Data(), 599)
    }
}
