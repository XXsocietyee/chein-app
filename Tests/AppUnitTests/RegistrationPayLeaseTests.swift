import Foundation
import XCTest
@testable import Questify

/// fix/1128-cn-pay P0-2: the app-side pay lease admits the exact multipart request `RegistrationPayService` builds
/// for `POST /api/registration/pay/app` (form field `id`), and nothing else.
@MainActor final class RegistrationPayLeaseTests: XCTestCase {
    private final class RecordingPayTransport: HTTPTransport, @unchecked Sendable {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data(#"{"code":200,"msg":"ok","data":{"registrationId":41}}"#.utf8), 200)
        }
    }

    private var previous: (@Sendable (ReleaseMoneyWriteKind) -> Bool)?

    override func setUp() {
        super.setUp()
        previous = ReleaseMoneyWriteSwitch.testDerivation
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
    }

    override func tearDown() {
        ReleaseMoneyWriteSwitch.testDerivation = previous
        super.tearDown()
    }

    private func payAppRequest() throws -> URLRequest {
        let configuration = try APIConfiguration(baseURL: URL(string: "https://api.example.com/prod-api/")!)
        return try RegistrationPayService.makeRequest(configuration: configuration, token: "fixture-pay-token",
                                                      registrationID: 41, channel: .app)
    }

    func testCanonicalPayAppRequestPassesTheLease() async throws {
        let wire = RecordingPayTransport()
        let lease = RegistrationPayBridge.RegistrationPayLease(underlying: wire, expectedHost: "api.example.com")
        _ = try await lease.send(try payAppRequest())
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests.first?.url?.path, "/prod-api/api/registration/pay/app")
    }

    func testTamperedBodyOrQueryIsRefused() async throws {
        let wire = RecordingPayTransport()
        let lease = RegistrationPayBridge.RegistrationPayLease(underlying: wire, expectedHost: "api.example.com")
        var extra = try payAppRequest()
        extra.httpBody = Data("id=41&payChannel=JSAPI".utf8)
        do { _ = try await lease.send(extra); XCTFail("an altered body must not pass") } catch {}
        var query = try payAppRequest()
        query.url = URL(string: "https://api.example.com/prod-api/api/registration/pay/app?id=41")
        do { _ = try await lease.send(query); XCTFail("a query must not pass") } catch {}
        XCTAssertTrue(wire.requests.isEmpty)
    }
}
