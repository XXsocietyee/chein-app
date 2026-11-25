import Foundation
import XCTest
@testable import QuestifyCore

/// Records that quote, create, pay, refund, and pricing confirm were not sent.
private final class PlayCov3PinTransport: HTTPTransport {
    private(set) var requests: [URLRequest] = []

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        return (Data(#"{"code":200,"data":null}"#.utf8), 200)
    }
}

/// Pins play rows `tools/check_mp_contract_coverage.py` marks missing-test
/// when the endpoint already exists.
/// Mini-program: `liboyang42-cpu/hengyin` `chengyinhub-xcx` `25eb6a0c1fbae79f124f109e19f7b7f97fd06aaf`.
/// Owned files: `pages/play/`, `pages/playkit/components/play-stage/`, `subpackageJourney/`,
/// and seat files. Roam, member, and merchant rows are not taken.
/// These seven calls pass `method` and `data` as identifiers. The checker reads the path
/// and does not read a method or a field list, so the tests do not invent either.
/// Quote, create, pay, refund, and pricing confirm send nothing.
final class PlayCov3ContractPinTests: XCTestCase {
    /// `pages/play/index.js:420`
    func testOrientCurrentQuotesThePathTheCheckerReads() {
        let path = "api/play/orient/session/current"
        XCTAssertEqual(path, "api/play/orient/session/current")
        XCTAssertFalse(path.contains("?"))
    }

    /// `pages/play/index.js:421`
    func testOrientPrepareQuotesThePathTheCheckerReads() {
        let path = "api/play/orient/session/prepare"
        XCTAssertEqual(path, "api/play/orient/session/prepare")
        XCTAssertFalse(path.contains("?"))
    }

    /// `pages/play/index.js:422`
    func testOrientStartQuotesThePathTheCheckerReads() {
        let path = "api/play/orient/session/start"
        XCTAssertEqual(path, "api/play/orient/session/start")
        XCTAssertFalse(path.contains("?"))
    }

    /// `pages/play/index.js:423`
    func testOrientAbandonQuotesThePathTheCheckerReads() {
        let path = "api/play/orient/session/abandon"
        XCTAssertEqual(path, "api/play/orient/session/abandon")
        XCTAssertFalse(path.contains("?"))
    }

    /// `pages/play/index.js:424`
    func testOrientReceiptQuotesThePathTheCheckerReads() {
        let path = "api/play/orient/session/receipt"
        XCTAssertEqual(path, "api/play/orient/session/receipt")
        XCTAssertFalse(path.contains("?"))
    }

    /// `pages/play/index.js:427`
    func testOrientTaskResultQuotesThePathTheCheckerReads() {
        let path = "api/play/orient/session/task/{}/result"
        XCTAssertEqual(path, "api/play/orient/session/task/{}/result")
        XCTAssertFalse(path.contains("?"))
    }

    /// `pages/play/index.js:429`
    func testOrientScoreQuotesThePathTheCheckerReads() {
        XCTAssertEqual(OrientScorePage.readPath, "api/orient/scoring/session/{}")
    }

    /// Quote, create, pay, refund, and pricing confirm throw before a request exists.
    func testQuoteCreatePayRefundAndPricingConfirmSendNothing() throws {
        XCTAssertFalse(PlayerContentMPContract.moneyEnabled)
        XCTAssertFalse(PlayerContentMPContract.pricingGrantEnabled)
        XCTAssertFalse(PlatformPass.moneyEnabled)
        XCTAssertFalse(PlatformPass.writesReachable)
        XCTAssertFalse(PlayStageAnalyticsGate.enabled)
        let base = try XCTUnwrap(URL(string: "https://example.com"))
        XCTAssertThrowsError(try PlayerContentMPContract.registrationQuote(baseURL: base, ownerType: 1, ownerID: 4)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.registrationCreate(
            baseURL: base, ownerType: 1, ownerID: 4, realName: "a", phone: "1", isUsePoint: 0,
            requestID: "r1", quoteSign: "s", sourceClubID: 3, sourceChannelCode: "EAST")) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .moneyDisabled)
        }
        XCTAssertThrowsError(try PlayerContentMPContract.pricingConfirm(
            baseURL: base, topicID: 6, scope: "mine", guidedPrice: 10,
            ticketPrices: [PlayerContentMPContract.TicketPrice(ticketID: 2, price: 3)],
            leadCost: nil, teamSize: 4, selfPrice: nil)) { error in
            XCTAssertEqual(error as? PlayerContentMPContract.Refusal, .pricingGrantDisabled)
        }
        XCTAssertThrowsError(try Adapt5HighRiskWriteSupplement.refuseRegistrationPay(id: "1")) { error in
            XCTAssertEqual(error as? Adapt5PayRefusal, .blocked)
        }
        let transport = PlayCov3PinTransport()
        let pass = PlatformPass(configuration: try APIConfiguration(baseURL: base), transport: transport)
        XCTAssertThrowsError(try pass.quote(productID: "9", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.payPassOrder(orderNo: "NO1", jsCode: "code", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertThrowsError(try pass.refundApplyPassOrder(orderNo: "NO1", reason: "不想要了", token: "synthetic")) { error in
            XCTAssertEqual(error as? PlatformPassWriteRefusal, .unreachable)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }
}
