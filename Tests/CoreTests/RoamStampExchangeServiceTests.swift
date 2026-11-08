#if canImport(QuestifyCore)
import Foundation
import XCTest
@testable import QuestifyCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Mini `subpackageRoam/citystamp` exchange step through a fake transport.
final class RoamStampExchangeServiceTests: XCTestCase {
    private final class Wire: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        var reply: Result<(Data, Int), Error> = .success((Data(), 200))
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return try reply.get() }
    }
    private func service(_ wire: Wire) throws -> RoamService {
        RoamService(configuration: try APIConfiguration(baseURL: URL(string: "https://example.com/native/")!), transport: wire)
    }
    private func json(_ s: String, status: Int = 200) -> Result<(Data, Int), Error> { .success((Data(s.utf8), status)) }

    func testExchangePostsGivenStampIdAndShowsOnlyServerResult() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":200,"data":{"exchanged":true}}"#)
        let receipt = try await service(wire).exchangeStamp(givenStampID: 8, token: "tok")
        XCTAssertTrue(receipt.exchanged)
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests.first?.url?.path, "/native/api/roam/stamp/exchange")
        XCTAssertEqual(wire.requests.first?.httpMethod, "POST")
        let body = String(data: wire.requests[0].httpBody ?? Data(), encoding: .utf8) ?? ""
        XCTAssertTrue(body.contains("name=\"givenStampId\"\r\n\r\n8\r\n"))
    }
    func testTransportLossIsUnknownOutcomeAndRetrySendsSameStamp() async throws {
        let wire = Wire(); wire.reply = .failure(URLError(.timedOut))
        do { _ = try await service(wire).exchangeStamp(givenStampID: 8, token: "tok"); XCTFail("expected failure") }
        catch { XCTAssertEqual(error as? RoamActionFailure, .unknownOutcome) }
        wire.reply = json(#"{"code":200,"data":{"exchanged":false,"reason":"no stamps yet"}}"#)
        let receipt = try await service(wire).exchangeStamp(givenStampID: 8, token: "tok")
        XCTAssertFalse(receipt.exchanged); XCTAssertEqual(receipt.reason, "no stamps yet")
        XCTAssertEqual(wire.requests.count, 2)
        XCTAssertEqual(wire.requests[0].httpBody == nil, wire.requests[1].httpBody == nil)
    }
    func testBusinessRejectionKeepsServerMessageAndUnauthorizedIsDistinct() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":500,"msg":"Synthetic refusal"}"#)
        do { _ = try await service(wire).exchangeStamp(givenStampID: 8, token: "tok"); XCTFail("expected rejection") }
        catch { XCTAssertEqual(error as? RoamActionFailure, .rejected("Synthetic refusal")) }
        wire.reply = json(#"{"code":401}"#, status: 401)
        do { _ = try await service(wire).exchangeStamp(givenStampID: 8, token: "tok"); XCTFail("expected 401") }
        catch { XCTAssertEqual(error as? APIError, .unauthorized) }
    }
    func testInvalidStampIdNeverReachesTransport() async throws {
        let wire = Wire(); wire.reply = json(#"{"code":200,"data":{"exchanged":true}}"#)
        do { _ = try await service(wire).exchangeStamp(givenStampID: 0, token: "tok"); XCTFail("expected invalid") }
        catch {}
        XCTAssertTrue(wire.requests.isEmpty)
    }
}
#endif
