import XCTest
@testable import Questify

@MainActor final class RoamPOIActionTests: XCTestCase {
    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var reply: Result<(Data, Int), Error> = .success((Data(), 200))
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return try reply.get() }
    }
    private func service(_ wire: Wire) throws -> RoamService {
        RoamService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/native/")!), transport: wire)
    }
    private func fix() throws -> RoamDeviceFix {
        try RoamDeviceFix(coordinate: XCTUnwrap(RoamCoordinate(latitude: 31.2, longitude: 121.4)), accuracyMeters: 10, measuredAt: Date(), datum: .gcj02)
    }
    private func json(_ s: String) -> Result<(Data, Int), Error> { .success((Data(s.utf8), 200)) }

    func testFavoriteReturnsServerState() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":200,"data":{"favorited":true}}"#)
        let value = try await service(wire).toggleFavorite(poiID: 7, token: "tok")
        XCTAssertTrue(value)
        XCTAssertEqual(wire.requests.first?.url?.path, "/native/api/city/nodes/7/favorite")
        XCTAssertEqual(wire.requests.first?.httpMethod, "POST")
    }
    func testFavoriteMissingBoolIsMalformed() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":200,"data":{}}"#)
        do { _ = try await service(wire).toggleFavorite(poiID: 7, token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
    }
    func testCompleteSendsFixAndParsesReceipt() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":200,"data":{"needRedeem":false,"alreadyClaimed":true,"poiId":9}}"#)
        let receipt = try await service(wire).completeNode(poiID: 9, fix: try fix(), token: "tok")
        XCTAssertTrue(receipt.alreadyClaimed); XCTAssertFalse(receipt.needRedeem)
        let body = String(data: wire.requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("name=\"lat\"\r\n\r\n31.2")); XCTAssertTrue(body.contains("name=\"lng\"\r\n\r\n121.4"))
    }
    func testCompleteForOtherPOIIsRejectedAsMalformed() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":200,"data":{"needRedeem":false,"poiId":10}}"#)
        do { _ = try await service(wire).completeNode(poiID: 9, fix: try fix(), token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? APIError, .malformedResponse) }
    }
    func testBusinessRejectionCarriesServerMessage() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":500,"msg":"too far"}"#)
        do { _ = try await service(wire).completeNode(poiID: 9, fix: try fix(), token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? RoamActionFailure, .rejected("too far")) }
    }
    func testTransportFailureIsUnknownOutcome() async throws {
        let wire = Wire(); wire.reply = .failure(URLError(.timedOut))
        do { _ = try await service(wire).toggleFavorite(poiID: 1, token: "tok"); XCTFail() } catch { XCTAssertEqual(error as? RoamActionFailure, .unknownOutcome) }
    }
    func testModelIgnoresSecondTapWhileWorkingAndUpdatesState() async throws {
        var calls = 0
        let actions = RoamPOIActions(toggleFavorite: { _ in calls += 1; try await Task.sleep(for: .milliseconds(50)); return true },
                                     complete: { _ in RoamNodeCompletion.preview(needRedeem: false) })
        let model = RoamPOIActionModel()
        model.toggleFavorite(poiID: 1, current: false, actions: actions); model.toggleFavorite(poiID: 1, current: false, actions: actions)
        try await Task.sleep(for: .milliseconds(200))
        XCTAssertEqual(calls, 1); XCTAssertEqual(model.favoriteOverride, true); XCTAssertEqual(model.favoritePhase, .idle)
    }
    func testModelMapsFailures() async throws {
        let actions = RoamPOIActions(toggleFavorite: { _ in true }, complete: { _ in throw RoamActionFailure.locationDenied })
        let model = RoamPOIActionModel(); model.checkIn(poiID: 1, actions: actions)
        try await Task.sleep(for: .milliseconds(100))
        XCTAssertEqual(model.checkInPhase, .failed(.locationDenied))
        XCTAssertEqual(RoamPOIActionModel.map(APIError.unauthorized), .signIn)
        XCTAssertEqual(RoamPOIActionModel.map(RoamActionFailure.rejected("x")), .rejected("x"))
    }
}
extension RoamNodeCompletion {
    static func preview(needRedeem: Bool) -> RoamNodeCompletion {
        try! JSONDecoder().decode(RoamNodeCompletion.self, from: Data(#"{"needRedeem":\#(needRedeem)}"#.utf8))
    }
}

final class RoamLiveWriteAllowlistTests: XCTestCase {
    func testOnlyRoamWritePathsAreAccepted() {
        for ok in ["api/city/nodes/7/favorite", "api/city/nodes/123/complete", "api/roam/stamp/create", "api/roam/stamp/exchange", "api/common/uploadOSS"] {
            XCTAssertTrue(RoamLiveWriteTransport.accepts(ok), ok)
        }
        for bad in ["api/city/nodes/x/favorite", "api/city/nodes//favorite", "api/city/nodes/7/delete", "api/city/nodes/7/favorite/extra",
                    "api/wallet/withdraw", "api/roam/stamp/list", "api/city/nodes/7", "../api/roam/stamp/create"] {
            XCTAssertFalse(RoamLiveWriteTransport.accepts(bad), bad)
        }
    }
    func testLiveRoamProfileAdmitsOnlyFogRevealRoutes() {
        XCTAssertTrue(RoamLiveWriteTransport.acceptsLiveRoam(method: "POST", relative: "api/roam/reveal", hasQuery: false))
        XCTAssertTrue(RoamLiveWriteTransport.acceptsLiveRoam(method: "GET", relative: "api/roam/session", hasQuery: true))
        XCTAssertFalse(RoamLiveWriteTransport.acceptsLiveRoam(method: "POST", relative: "api/roam/reveal", hasQuery: true))
        XCTAssertFalse(RoamLiveWriteTransport.acceptsLiveRoam(method: "POST", relative: "api/roam/presence", hasQuery: false), "presence sharing stays off")
        XCTAssertFalse(RoamLiveWriteTransport.acceptsLiveRoam(method: "GET", relative: "api/wallet/balance", hasQuery: false))
    }
    func testPrivateToolsProfileAdmitsOnlyCapsuleGoalExportAndPassportRoutes() {
        XCTAssertTrue(RoamLiveWriteTransport.acceptsPrivateTools(method: "POST", relative: "api/capsules/create"))
        XCTAssertTrue(RoamLiveWriteTransport.acceptsPrivateTools(method: "GET", relative: "api/capsules/list"))
        XCTAssertTrue(RoamLiveWriteTransport.acceptsPrivateTools(method: "GET", relative: "api/monthly-recap"))
        XCTAssertFalse(RoamLiveWriteTransport.acceptsPrivateTools(method: "POST", relative: "api/monthly-recap"))
        XCTAssertFalse(RoamLiveWriteTransport.acceptsPrivateTools(method: "DELETE", relative: "api/capsules/delete"))
        XCTAssertFalse(RoamLiveWriteTransport.acceptsPrivateTools(method: "POST", relative: "api/wallet/transfer"))
    }
    func testImageOriginsAreHTTPSOnlyAndConfigDriven() throws {
        let base = try XCTUnwrap(URL(string: "https://api.example.com/native/"))
        XCTAssertEqual(RetainedImageOrigin.configured(apiBase: base, extra: nil), ["https://api.example.com"])
        let set = RetainedImageOrigin.configured(apiBase: base, extra: "https://cdn.example.com, http://insecure.example.com, https://img.example.com:8443")
        XCTAssertEqual(set, ["https://api.example.com", "https://cdn.example.com", "https://img.example.com:8443"])
    }
    func testHiddenStampsPersist() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "hidden-stamps-" + UUID().uuidString))
        XCTAssertFalse(RoamHiddenStamps.contains(5, defaults: defaults))
        RoamHiddenStamps.hide(5, defaults: defaults)
        XCTAssertTrue(RoamHiddenStamps.contains(5, defaults: defaults)); XCTAssertFalse(RoamHiddenStamps.contains(6, defaults: defaults))
    }
    @MainActor func testExchangeReceiptDecodes() async throws {
        let json = #"{"code":200,"data":{"exchanged":false,"reason":"no stamps yet"}}"#
        final class W: HTTPTransport { let d: Data; init(_ d: Data) { self.d = d }; func send(_ r: URLRequest) async throws -> (Data, Int) { (d, 200) } }
        let service = RoamService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/")!), transport: W(Data(json.utf8)))
        let receipt = try await service.exchangeStamp(givenStampID: 3, token: "tok")
        XCTAssertFalse(receipt.exchanged); XCTAssertEqual(receipt.reason, "no stamps yet")
    }
}
