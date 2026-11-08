import XCTest
@testable import Questify

/// ADAPT-4 group 1. Pins the already-wired Roam POI calls against the response/request shapes of
/// ApiCityNodeController (hengyin@4ac8c249): POST /api/city/nodes/{id}/complete (unannotated Double/String params,
/// i.e. form/multipart-bindable, NOT @RequestBody) and POST /api/city/nodes/{id}/favorite (no body).
/// Fixtures are AjaxResult shapes copied from the controller source: success -> {msg,code:200,data}, error -> {msg,code:500}.
@MainActor final class Adapt4RoamPOIBackendShapeTests: XCTestCase {
    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var reply: (String, Int) = ("{}", 200)
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (Data(reply.0.utf8), reply.1) }
    }
    private func service(_ wire: Wire) throws -> RoamService {
        RoamService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.test/prod-api/")!), transport: wire)
    }
    private func fix() throws -> RoamDeviceFix {
        try RoamDeviceFix(coordinate: XCTUnwrap(RoamCoordinate(latitude: 31.2, longitude: 121.4)), accuracyMeters: 10, measuredAt: Date(), datum: .gcj02)
    }
    // Backend: success("完成", data{couponId,needRedeem,poiId,completed,hint}) for a coupon node.
    private let completeWithCoupon = #"{"msg":"完成","code":200,"data":{"couponId":88,"needRedeem":true,"poiId":9,"completed":false,"hint":"已到店打卡,出示据点核销码给商家即可领券"}}"#
    // Backend: no-coupon node with a badge adds badgeCode/badgeName.
    private let completeWithBadge = #"{"msg":"完成","code":200,"data":{"couponId":null,"needRedeem":false,"badgeCode":"CITY_WALKER","badgeName":"City Walker","poiId":9,"completed":true,"hint":"已到店打卡"}}"#
    // Backend: duplicate completion -> success("你已完成过该据点", {couponId,needRedeem,alreadyClaimed:true}) (no poiId on this branch).
    private let completeAlready = #"{"msg":"你已完成过该据点","code":200,"data":{"couponId":88,"needRedeem":true,"alreadyClaimed":true}}"#
    // Backend: error(msg) -> code 500, no data.
    private let tooFar = #"{"msg":"离据点太远,请到店后再完成","code":500}"#

    func testCompleteWithCouponDecodesNeedRedeemAndPoiId() async throws {
        let wire = Wire(); wire.reply = (completeWithCoupon, 200)
        let r = try await service(wire).completeNode(poiID: 9, fix: try fix(), token: "tok")
        XCTAssertTrue(r.needRedeem); XCTAssertFalse(r.alreadyClaimed); XCTAssertEqual(r.poiID, 9)
    }
    func testCompleteBadgeShapeWithNullCouponDecodes() async throws {
        let wire = Wire(); wire.reply = (completeWithBadge, 200)
        let r = try await service(wire).completeNode(poiID: 9, fix: try fix(), token: "tok")
        XCTAssertFalse(r.needRedeem); XCTAssertEqual(r.poiID, 9)
    }
    func testCompleteAlreadyClaimedBranchHasNoPoiIdAndStillDecodes() async throws {
        let wire = Wire(); wire.reply = (completeAlready, 200)
        let r = try await service(wire).completeNode(poiID: 9, fix: try fix(), token: "tok")
        XCTAssertTrue(r.alreadyClaimed); XCTAssertTrue(r.needRedeem); XCTAssertNil(r.poiID)
    }
    func testCompleteBusinessErrorIsCode500WithHTTP200AndSurfacesServerMessage() async throws {
        let wire = Wire(); wire.reply = (tooFar, 200)
        do { _ = try await service(wire).completeNode(poiID: 9, fix: try fix(), token: "tok"); XCTFail() }
        catch { XCTAssertEqual(error as? RoamActionFailure, .rejected("离据点太远,请到店后再完成")) }
    }
    func testCompleteRequestIsMultipartFormWithBackendParamNamesNotJSON() async throws {
        let wire = Wire(); wire.reply = (completeWithCoupon, 200)
        _ = try await service(wire).completeNode(poiID: 9, fix: try fix(), answer: "a", photoURL: "https://x.test/p.jpg", code: "c", token: "tok")
        let req = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/prod-api/api/city/nodes/9/complete")
        XCTAssertEqual(req.value(forHTTPHeaderField: "Authorization"), "tok")
        XCTAssertTrue(req.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("multipart/form-data; boundary=") == true)
        let body = String(data: req.httpBody ?? Data(), encoding: .utf8) ?? ""
        // Exactly the controller's parameter names: lat, lng, answer, photoUrl, code.
        for name in ["lat", "lng", "answer", "photoUrl", "code"] { XCTAssertTrue(body.contains("name=\"\(name)\""), name) }
        XCTAssertFalse(body.contains("\"poiId\""), "the node id travels in the path only")
        XCTAssertNil(try? JSONSerialization.jsonObject(with: req.httpBody ?? Data()))
    }
    func testFavoriteToggledOffAndOnShapes() async throws {
        let wire = Wire()
        wire.reply = (#"{"msg":"操作成功","code":200,"data":{"favorited":false}}"#, 200)
        let off = try await service(wire).toggleFavorite(poiID: 7, token: "tok")
        wire.reply = (#"{"msg":"操作成功","code":200,"data":{"favorited":true}}"#, 200)
        let on = try await service(wire).toggleFavorite(poiID: 7, token: "tok")
        XCTAssertFalse(off); XCTAssertTrue(on)
    }
    func testFavoriteRequestHasNoBodyAndNoContentType() async throws {
        let wire = Wire(); wire.reply = (#"{"msg":"操作成功","code":200,"data":{"favorited":true}}"#, 200)
        _ = try await service(wire).toggleFavorite(poiID: 7, token: "tok")
        let req = try XCTUnwrap(wire.requests.first)
        XCTAssertEqual(req.httpMethod, "POST")
        XCTAssertEqual(req.url?.path, "/prod-api/api/city/nodes/7/favorite")
        XCTAssertNil(req.httpBody); XCTAssertNil(req.value(forHTTPHeaderField: "Content-Type"))
    }
    func testFavoriteOfflineNodeRejectionSurfacesServerMessage() async throws {
        let wire = Wire(); wire.reply = (#"{"msg":"据点未开放或已下线","code":500}"#, 200)
        do { _ = try await service(wire).toggleFavorite(poiID: 7, token: "tok"); XCTFail() }
        catch { XCTAssertEqual(error as? RoamActionFailure, .rejected("据点未开放或已下线")) }
    }
    func testNonPositiveNodeIdNeverReachesTheWire() async throws {
        let wire = Wire()
        do { _ = try await service(wire).toggleFavorite(poiID: 0, token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? APIError, .invalidRequest) }
        XCTAssertTrue(wire.requests.isEmpty)
    }
}
