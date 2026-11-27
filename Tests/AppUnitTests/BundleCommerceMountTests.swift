import XCTest
@testable import Questify

@MainActor final class BundleCommerceMountTests: XCTestCase {
    func testAbsentCapabilityHidesEveryEntry() throws {
        let china = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        XCTAssertTrue(BundleCommerceCatalog.visible(baseURL: china, capabilityAvailable: false).isEmpty)
    }

    func testNilBaseHidesEveryEntry() {
        XCTAssertTrue(BundleCommerceCatalog.visible(baseURL: nil, capabilityAvailable: true).isEmpty)
    }

    func testChinaShowsOnlyAdmittedReads() throws {
        let china = try XCTUnwrap(URL(string: ReviewedMarketLaunch.chinaProductionBaseURL))
        XCTAssertEqual(
            BundleCommerceCatalog.visible(baseURL: china, capabilityAvailable: true),
            // MKT-7-2: 评价 reads the live merchant/reviews contract.
            // Stale expectation: Handover 23 (owner correction 2026-11-13, docs/release/receipts/cur-be-gap-play.md)
            // admits `/api/free-explore/bundle/shelf` as a non-money read in
            // `ChinaReviewedRouteCapability.playGapOwnerGrant` (landed in 7623036a3), so the shelf entry is admitted too.
            [.shelf, .orderStatus, .refundQuote, .cancel, .exitSwap, .review]
        )
    }

    func testFixtureHostMountsEveryNonMoneyEntry() throws {
        let fixture = try XCTUnwrap(URL(string: "https://example.test"))
        XCTAssertEqual(
            BundleCommerceCatalog.visible(baseURL: fixture, capabilityAvailable: true),
            BundleCommerceEntry.allCases
        )
    }

    func testMoneyActionsStayUnmounted() {
        XCTAssertFalse(BundleCommerceCatalog.mountsMoneyActions)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.payoutEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.withdrawalEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.virtualGoodsEnabled)
        for entry in BundleCommerceEntry.allCases {
            XCTAssertNil(ReleaseMoneyWriteSwitch.kind(for: entry.route))
            XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks(entry.route))
        }
    }

    func testQuoteTransportAllowsOnlyTheBoundGet() async throws {
        let context = try Self.context()
        let registration = try FreeExploreLaunchID(41)
        let allowed = try XCTUnwrap(BundleCommerceReadTransport.refundQuoteURL(base: context.baseURL, registrationID: registration))
        let wire = Wire()
        let gate = BundleCommerceReadTransport(context: context, allowed: [allowed], underlying: wire,
                                               current: { true }, denied: {})
        let session = try Self.session(context)
        let service = FreeExploreLaunchService(session: session, transport: gate,
                                                currentSession: { session }, reservationAllowed: { false },
                                                onUnauthorized: { _ in })
        do { _ = try await service.refundQuote(registrationID: registration) } catch {}
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests.first?.httpMethod, "GET")
        XCTAssertNil(wire.requests.first?.httpBody)
        XCTAssertEqual(wire.requests.first?.url?.absoluteString, allowed)

        var post = URLRequest(url: context.baseURL.appendingPathComponent("api/free-explore/bundle/reservation/41/cancel"))
        post.httpMethod = "POST"
        post.httpBody = Data("{}".utf8)
        post.setValue(context.session.token, forHTTPHeaderField: "Authorization")
        do {
            _ = try await gate.send(post)
            XCTFail("a cancel POST must not leave the read gate")
        } catch {}
        XCTAssertEqual(wire.requests.count, 1)
    }

    func testCancelWriteIsNotSentWhenDisabled() async throws {
        let context = try Self.context()
        let session = try Self.session(context)
        let wire = Wire()
        let reservation = try FreeExploreLaunchID(41)
        let quotes = BundleCommerceReadTransport.cancelQuoteURLs(base: context.baseURL, reservationID: reservation)
        XCTAssertEqual(quotes.count, 2)
        let gate = BundleCommerceReadTransport(context: context, allowed: quotes, underlying: wire,
                                               current: { true }, denied: {})
        let client = try BundleAPIClient(session: session, authorization: context.session.token,
                                          transport: gate, currentSession: { session },
                                          writeAllowed: { false }, onUnauthorized: { _ in })
        do {
            _ = try await client.cancel(reservationID: reservation, useWaiver: false, expectedOutcome: "CANCELLED")
            XCTFail("cancel must stay disabled")
        } catch let error as FreeExploreLaunchFailure {
            XCTAssertEqual(error, .disabled)
        }
        XCTAssertTrue(wire.requests.isEmpty)

        do { _ = try await client.cancelQuote(reservationID: reservation, useWaiver: false) } catch {}
        XCTAssertEqual(wire.requests.count, 1)
        XCTAssertEqual(wire.requests.first?.httpMethod, "GET")
        XCTAssertEqual(wire.requests.first?.url?.absoluteString, quotes[0])
    }

    private static func context() throws -> RuntimeDependencyContext {
        try RuntimeDependencyContext(market: .china, baseURL: URL(string: "https://example.test")!, role: "player",
            session: PlayExperienceSession(accountID: 7, epoch: 1, namespace: "test-realm",
                                           token: "synthetic-token-1", role: "player"))
    }

    private static func session(_ context: RuntimeDependencyContext) throws -> FreeExploreLaunchSession {
        try FreeExploreLaunchSession(baseURL: context.baseURL, accountID: Int64(context.session.accountID),
            market: context.market.rawValue, namespace: context.session.namespace, role: context.role,
            epoch: context.session.epoch, token: context.session.token)
    }

    private final class Wire: HTTPTransport {
        var requests: [URLRequest] = []
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            return (Data("{}".utf8), 500)
        }
    }
}
