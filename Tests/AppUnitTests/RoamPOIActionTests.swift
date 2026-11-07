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
