import XCTest
@testable import Questify

@MainActor final class BNDOrderStatusViewTests: XCTestCase {
    private let token = "synthetic-test-credential"
    private let base = URL(string: "https://example.test")!
    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        var status = 200
        var body = Data(#"{"code":200,"data":{}}"#.utf8)
        func send(_ request: URLRequest) async throws -> (Data, Int) { requests.append(request); return (body, status) }
    }
    private func transport(_ wire: Wire, current: @escaping () -> Bool = { true }, denied: @escaping () -> Void = {}) throws -> BundleReadTransport {
        try BundleReadTransport(baseURL: base, authorization: token, registrationID: FreeExploreLaunchID(9001),
                                receiptRequestIDs: ["bundle-order:9001"], underlying: wire, current: current, denied: denied)
    }
    private func request(_ path: String, query: String, method: String = "GET", auth: String? = nil) -> URLRequest {
        var r = URLRequest(url: URL(string: "https://example.test/api/free-explore/bundle/\(path)?\(query)")!)
        r.httpMethod = method
        r.setValue(auth ?? token, forHTTPHeaderField: "Authorization")
        return r
    }

    func testNotFoundReceiptIsNotShownAsFailed() {
        typealias P = BundleOrderStatusPresentation
        XCTAssertEqual(P.banner(for: .polling(attempt: 2)), .confirming)
        XCTAssertEqual(P.banner(for: .stillUnconfirmed), .stillConfirming)
        XCTAssertNotEqual(P.banner(for: .stillUnconfirmed), .failed)
        XCTAssertEqual(P.bannerKey(.stillConfirming), "order.receipt.stillConfirming")
        XCTAssertEqual(P.banner(for: .failed(.malformed)), .failed)
        XCTAssertEqual(P.banner(for: .readUnavailable), .unavailable)
        XCTAssertEqual(P.banner(for: .idle), .none)
        XCTAssertNil(P.bannerKey(.none))
    }

    func testActivationKeysAreServerStatesAndNeverPaidCopy() {
        typealias P = BundleOrderStatusPresentation
        XCTAssertEqual(P.activationKey(.active), "activation.active")
        XCTAssertEqual(P.activationKey(.pending), "activation.pending")
        XCTAssertEqual(P.activationKey(.unknown), "activation.unknown")
        XCTAssertNil(P.unitStatusKey("NEW_STATE")) // unknown => raw server string shown, no invented copy
        XCTAssertEqual(P.unitStatusKey("AVAILABLE"), "unit.status.AVAILABLE")
    }

    func testReadTransportAllowsOnlyBoundOrderAndReceiptGETs() async throws {
        let wire = Wire(); let gate = try transport(wire)
        _ = try await gate.send(request("order", query: "registrationId=9001"))
        _ = try await gate.send(request("order/receipt", query: "requestId=bundle-order:9001"))
        XCTAssertEqual(wire.requests.count, 2)
        let rejected: [URLRequest] = [
            request("order", query: "registrationId=9002"),
            request("order/receipt", query: "requestId=bundle-order:9002"),
            request("order", query: "registrationId=9001", method: "POST"),
            request("reservation/31/cancel", query: "x=1"),
            request("order", query: "registrationId=9001", auth: "other-credential-value"),
        ]
        for r in rejected {
            do { _ = try await gate.send(r); XCTFail("must reject \(r.url?.absoluteString ?? "")") } catch {}
        }
        XCTAssertEqual(wire.requests.count, 2) // nothing rejected reached the wire
    }

    func testReadTransport403RetiresAndStaleSessionBlocks() async throws {
        let wire = Wire(); wire.status = 403
        var denied = 0
        let gate = try transport(wire, denied: { denied += 1 })
        do { _ = try await gate.send(request("order", query: "registrationId=9001")); XCTFail("403 must throw") } catch {}
        XCTAssertEqual(denied, 1)
        XCTAssertFalse(gate.isCurrent)
        let stale = try transport(Wire(), current: { false })
        do { _ = try await stale.send(request("order", query: "registrationId=9001")); XCTFail("stale must throw") } catch {}
    }
}
