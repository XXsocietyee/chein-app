import XCTest
@testable import QuestifyCore
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

@MainActor final class BNDRefundProgressModelTests: XCTestCase {
    private func quote(route: String = "ORIGINAL_METHOD", amount: String = "49.75") throws -> FreeExploreLaunchRefundQuote {
        let json: [String: Any] = ["route": route, "amount": amount, "totalValue": "80.00",
            "remainingValue": "10.07", "remainingRatio": "0.1259", "afterSalesForMerchantBreach": false,
            "reason": "server reason", "policyVersion": "server-version"]
        return try JSONDecoder().decode(FreeExploreLaunchRefundQuote.self, from: try JSONSerialization.data(withJSONObject: json))
    }
    private func id(_ n: Int64) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(n) }
    private func command(route: String = "ORIGINAL_METHOD", amount: String = "49.75",
                         order: [Int64] = [21, 22], proposed: [Int64]? = nil) throws -> BundleRefundApplyCommand {
        let units = try order.map(id)
        let picked = try (proposed ?? order).map(id)
        return try BundleRefundApplyCommand(quote: quote(route: route, amount: amount), registrationId: id(9001),
                                             orderUnitIDs: units, proposedUnitIDs: picked, idempotencyKey: "refund-key-1")
    }
    private func session() throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: URL(string: "https://example.test")!, accountID: 5, market: "CN",
                                     namespace: "test", role: "player", epoch: 1, token: "synthetic-test-credential")
    }
    private func envelope(_ state: String) -> (Data, Int) {
        (Data(#"{"code":200,"msg":"ok","data":{"registrationId":9001,"state":"\#(state)","refundNo":"R-1"}}"#.utf8), 200)
    }
    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    func testApplyCarriesServerQuoteRouteAndAmountVerbatim() throws {
        let made = try command(route: "PLATFORM_BALANCE", amount: "10.07")
        XCTAssertEqual(made.expectedRoute, "PLATFORM_BALANCE")
        XCTAssertEqual(made.expectedAmount, "10.07")
        XCTAssertEqual(made.unitIDs.map(\.text), ["21", "22"])
        let odd = try quote(route: "ORIGINAL_METHOD", amount: "0.00")
        let model = BundleRefundProgressModel(quote: odd, registrationId: try id(9001), orderUnitIDs: [try id(21)])
        XCTAssertEqual(model.expectedRoute, "ORIGINAL_METHOD")
        XCTAssertEqual(model.expectedAmount, "0.00")
        XCTAssertFalse(model.canApply)
        XCTAssertEqual(model.phase, .unavailable)
    }

    func testPartialUnitSelectionRejected() throws {
        XCTAssertFalse(BundleRefundApplyCommand.isWholeOrder(orderUnitIDs: [try id(21), try id(22)], proposed: [try id(21)]))
        XCTAssertTrue(BundleRefundApplyCommand.isWholeOrder(orderUnitIDs: [try id(21), try id(22)], proposed: [try id(22), try id(21)]))
        XCTAssertThrowsError(try command(proposed: [21])) { error in
            XCTAssertEqual(error as? FreeExploreLaunchFailure, .invalid)
        }
    }

    func testProcessingUnknownAndManualPayoutAreNotRefunded() {
        for state in ["PROCESSING", "PENDING", "HELD", "REFUND_PENDING", "UNKNOWN", "MANUAL_PAYOUT", "MANUAL", "APPROVED", "REJECTED", "FUTURE"] {
            let presentation = BundleRefundProgressPresentation(state: state, refundNo: "R-1")
            XCTAssertFalse(presentation.showsRefunded, state)
            XCTAssertNotEqual(presentation.titleEn, "Refunded", state)
        }
        let done = BundleRefundProgressPresentation(state: "REFUNDED", refundNo: " R-9 ")
        XCTAssertTrue(done.showsRefunded)
        XCTAssertEqual(done.titleEn, "Refunded")
        XCTAssertEqual(done.refundNo, "R-9")
        XCTAssertNil(BundleRefundProgressPresentation(state: "PROCESSING", refundNo: "  ").refundNo)
    }

    func testUnavailableClientDoesNotApply() async throws {
        let client = UnavailableBundleRefundClient()
        XCTAssertFalse(client.permitsWrites)
        let model = BundleRefundProgressModel(quote: try quote(), registrationId: try id(9001),
                                              orderUnitIDs: [try id(21)], client: client)
        await model.apply(idempotencyKey: "refund-key-1")
        XCTAssertEqual(model.phase, .unavailable)
        do {
            _ = try await client.apply(try command())
            XCTFail("unavailable client must not apply")
        } catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .disabled) }
    }

    func testClosedGateDoesNotSendEvenWhenWriteClosureIsTrue() async throws {
        let wire = BNDTransport()
        wire.handler = { _ in self.envelope("REFUNDED") }
        let launch = try session()
        let client = try BundleRefundHTTPClient(session: launch, authorization: "synthetic-test-credential", transport: wire,
                                                currentSession: { launch }, writeAllowed: { true })
        XCTAssertFalse(client.permitsWrites)
        XCTAssertFalse(BundleMoneyWriteGate.allowsRefundApply)
        XCTAssertFalse(BundleMoneyWriteGate.allowsPayment)
        XCTAssertFalse(BundleMoneyWriteGate.allowsPayout)
        XCTAssertFalse(BundleMoneyWriteGate.allowsWithdrawal)
        XCTAssertFalse(BundleMoneyWriteGate.allowsVirtualGoods)
        do {
            _ = try await client.apply(try command())
            XCTFail("refund apply must stay disabled")
        } catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .disabled) }
        XCTAssertTrue(wire.requests.isEmpty)
        let spy = SpyRefund(permitsWrites: true)
        let model = BundleRefundProgressModel(quote: try quote(), registrationId: try id(9001), orderUnitIDs: [try id(21), try id(22)], client: spy)
        await model.apply(idempotencyKey: "refund-key-1")
        XCTAssertEqual(spy.applied, 0)
        XCTAssertFalse(model.canApply)
    }

    func testProgressReadDoesNotTreatProcessingAsRefunded() async throws {
        let wire = BNDTransport()
        let launch = try session()
        let client = try BundleRefundHTTPClient(session: launch, authorization: "synthetic-test-credential", transport: wire,
                                                currentSession: { launch })
        for state in ["PROCESSING", "UNKNOWN", "MANUAL_PAYOUT", "APPROVED"] {
            wire.handler = { _ in self.envelope(state) }
            let presentation = try await client.progress(registrationID: id(9001))
            XCTAssertEqual(presentation.serverState, state)
            XCTAssertFalse(presentation.showsRefunded)
            XCTAssertEqual(wire.requests.last?.httpMethod, "GET")
            XCTAssertEqual(wire.requests.last?.url?.path, "/api/free-explore/bundle/order/refund")
            XCTAssertEqual(wire.requests.last?.url?.query, "registrationId=9001")
            XCTAssertNil(wire.requests.last?.httpBody)
        }
        wire.handler = { _ in self.envelope("REFUNDED") }
        let done = try await client.progress(registrationID: id(9001))
        XCTAssertTrue(done.showsRefunded)
        XCTAssertFalse(wire.requests.contains { $0.httpMethod == "POST" })
    }

    func testNoClientSideAmountComputation() throws {
        let files = ["Core/BundleRefundClient.swift", "Core/BundleRefundProgressModel.swift",
                     "App/BundleRefundApplyView.swift", "App/BundleRefundProgressView.swift", "App/BundleRefundTransport.swift"]
        for file in files {
            let text = try source(file)
            for token in ["Decimal(", "NSDecimalNumber", "Double(", "Float(", "NumberFormatter", "String(format", "0.20", "0.2"] {
                XCTAssertFalse(text.contains(token), "\(file) must not compute: \(token)")
            }
        }
        let client = try source("Core/BundleRefundClient.swift")
        XCTAssertTrue(client.contains("expectedRoute"))
        XCTAssertTrue(client.contains("expectedAmount"))
        XCTAssertTrue(client.contains("allowsRefundApply"))
        let apply = try source("App/BundleRefundApplyView.swift")
        XCTAssertFalse(apply.contains("Toggle"))
        XCTAssertFalse(apply.contains("ForEach"))
        XCTAssertTrue(apply.contains("if model.canApply"))
        let progress = try source("App/BundleRefundProgressView.swift")
        XCTAssertTrue(progress.contains("showsRefunded"))
        XCTAssertTrue(progress.contains("if !presentation.showsRefunded"))
    }
}

@MainActor private final class SpyRefund: BundleRefundServing {
    var permitsWrites: Bool
    var applied = 0
    init(permitsWrites: Bool) { self.permitsWrites = permitsWrites }
    func apply(_ command: BundleRefundApplyCommand) async throws -> BundleRefundProgressPresentation {
        applied += 1
        return BundleRefundProgressPresentation(state: "REFUNDED", refundNo: "n")
    }
    func progress(registrationID: FreeExploreLaunchID) async throws -> BundleRefundProgressPresentation {
        BundleRefundProgressPresentation(state: "PROCESSING", refundNo: nil)
    }
}
