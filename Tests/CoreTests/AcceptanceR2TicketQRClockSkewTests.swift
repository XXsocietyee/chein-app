import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// Acceptance R2 F-03: 票夹 → 出示二维码 showed "二维码已过期并清除" at once because the TEST server clock ran
/// ~7 s ahead and the receipt check compared the server's absolute expiry with the device clock (5 s tolerance).
@MainActor final class AcceptanceR2TicketQRClockSkewTests: XCTestCase {
    private let deviceNow = Date(timeIntervalSince1970: 1_000)
    private let target = VerificationCodeTarget(kind: .ticket, id: 31)

    /// A ticket receipt minted at `serverIssue` (server clock, seconds) with `ttl` seconds of life.
    private func receipt(serverIssue: TimeInterval, ttl: Int64 = 300) throws -> VerificationCodeReceipt {
        let expiry = Int64(serverIssue * 1000) + ttl * 1000
        let json = "{\"code\":\"v1.31.topic.\(expiry).9.\(String(repeating: "A", count: 43))\",\"expiresAt\":\(expiry),\"ttlMs\":\(ttl * 1000),\"type\":\"topic\"}"
        return try JSONDecoder().decode(VerificationCodeReceipt.self, from: Data(json.utf8))
    }
    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/native/")!, role: "PLAYER",
              session: try .init(accountID: 7, epoch: 1, namespace: "fixture", token: "synthetic"))
    }
    private func detail() throws -> OrderLifecycleDetail {
        try JSONDecoder().decode(OrderLifecycleDetail.self, from: Data(#"{"id":31,"registrationStatus":2,"verificationStatus":0,"purchaseKind":3,"entitlements":[{"id":1,"status":0}]}"#.utf8))
    }

    func testServerSevenSecondsAheadIsLiveForItsFullTTL() throws {
        let value = try receipt(serverIssue: deviceNow.timeIntervalSince1970 + 7)
        let result = try value.validated(target: target, accountID: 7, requestedAt: deviceNow, now: deviceNow)
        XCTAssertEqual(result.expiry, deviceNow.addingTimeInterval(300))
        XCTAssertNoThrow(try value.validatedCode(target: target, accountID: 7, requestedAt: deviceNow, now: deviceNow))
    }

    func testServerSixtySecondsAheadOrBehindIsStillLiveForItsTTL() throws {
        for offset in [60.0, -60.0] {
            let value = try receipt(serverIssue: deviceNow.timeIntervalSince1970 + offset)
            let receivedAt = deviceNow.addingTimeInterval(0.4)
            let result = try value.validated(target: target, accountID: 7, requestedAt: deviceNow, now: receivedAt)
            XCTAssertEqual(result.expiry, deviceNow.addingTimeInterval(300), "offset \(offset)")
        }
    }

    func testLifetimeIsNeverLongerThanTheServerTTL() throws {
        // Slow network: issued anywhere in [requestedAt, receivedAt]; the earliest instant bounds the expiry.
        let value = try receipt(serverIssue: deviceNow.timeIntervalSince1970 + 3, ttl: 60)
        let result = try value.validated(target: target, accountID: 7, requestedAt: deviceNow, now: deviceNow.addingTimeInterval(3))
        XCTAssertEqual(result.expiry, deviceNow.addingTimeInterval(60))
    }

    func testCodeMintedLongBeforeTheRequestIsExpired() throws {
        // Server minted it 400 s before the request (or its clock is wildly wrong): no trustworthy lifetime.
        let value = try receipt(serverIssue: deviceNow.timeIntervalSince1970 - 400)
        XCTAssertThrowsError(try value.validatedCode(target: target, accountID: 7, requestedAt: deviceNow, now: deviceNow)) {
            XCTAssertEqual($0 as? VerificationCodeFailure, .expired)
        }
    }

    func testResponseArrivingAfterTheTTLIsExpired() throws {
        let value = try receipt(serverIssue: deviceNow.timeIntervalSince1970 + 7, ttl: 30)
        XCTAssertThrowsError(try value.validatedCode(target: target, accountID: 7, requestedAt: deviceNow, now: deviceNow.addingTimeInterval(30))) {
            XCTAssertEqual($0 as? VerificationCodeFailure, .expired)
        }
    }

    func testCoordinatorShowsSkewedCodeLiveThenExpiresAfterTTL() async throws {
        let context = try context()
        let service = SkewedCodeService(receipt: try receipt(serverIssue: deviceNow.timeIntervalSince1970 + 7), detail: try detail())
        var now = deviceNow
        let model = VerificationCodeCoordinator(target: target, service: service, current: { context }, now: { now })
        await model.present()
        XCTAssertEqual(model.phase, .ready)
        XCTAssertNotNil(model.displayCode)
        XCTAssertEqual(model.remainingSeconds, 300)
        // 31s left is still outside the 30s silent-renew lead, so the skewed code is the one on screen.
        now = deviceNow.addingTimeInterval(269); await model.tick()
        XCTAssertEqual(model.phase, .ready); XCTAssertEqual(model.remainingSeconds, 31); XCTAssertNotNil(model.displayCode)
        now = deviceNow.addingTimeInterval(300); await model.tick()
        XCTAssertEqual(model.phase, .expired); XCTAssertNil(model.displayCode)
        XCTAssertEqual(service.issues, 1, "A clock jump past expiry does not mint another code")
    }
}

@MainActor private final class SkewedCodeService: VerificationCodeServing {
    var enabled = true
    let receipt: VerificationCodeReceipt
    let detail: OrderLifecycleDetail
    private(set) var issues = 0
    init(receipt: VerificationCodeReceipt, detail: OrderLifecycleDetail) { self.receipt = receipt; self.detail = detail }
    func issue(_ target: VerificationCodeTarget, context: RuntimeDependencyContext) async throws -> VerificationCodeReceipt {
        issues += 1; return receipt
    }
    func order(id: Int, context: RuntimeDependencyContext) async throws -> OrderLifecycleDetail { detail }
}
