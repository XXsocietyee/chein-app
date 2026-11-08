import XCTest
@testable import QuestifyCore
import Foundation

// Deterministic JSON copied from docs/owner-plan/bundle-gap.md §4 (shapes only, synthetic values).
// No network, no clock, no Keychain.
enum BNDFixtures {
    static let policy = #"{"version":"F3P1-20261022","freeCancelHours":12,"partialRefundMinRatio":0.20,"monthlyVoluntaryWaivers":1}"#

    static let legacyOrder = #"""
    {"registrationId":9001,"registrationNo":"R-9001","parentOrderNo":"P-1","paymentStatus":2,"registrationStatus":2,"bundle":null}
    """#

    /// Primary-branch shape: numeric ids, "yyyy-MM-dd HH:mm:ss" strings on domain objects, epoch ms on grant validity.
    static func orderView(unitStatus: String = "AVAILABLE", ids: Bool = true) -> String {
        func id(_ n: Int) -> String { ids ? "\(n)" : "\"\(n)\"" }
        return #"""
        {"registrationId":\#(id(9001)),"registrationNo":"R-9001","parentOrderNo":"P-1","paymentStatus":2,"registrationStatus":2,
         "bundle":{
          "order":{"id":\#(id(1)),"registrationId":\#(id(9001)),"holderMemberId":\#(id(5)),"topicId":\#(id(101)),"activityId":null,
                   "productVersion":"pv-sha","quotaVersion":"qv-sha","policyVersion":"F3P1-20261022",
                   "contractVersion":"cv-sha","settlementRuleVersion":"srv-1","snapshotJson":"{\"product\":{}}",
                   "paidAmount":199.00,"validFrom":"2026-11-01 00:00:00","validTo":"2027-11-01 00:00:00",
                   "idempotencyKey":"bundle-order:9001","requestFingerprint":"fp-sha","createTime":"2026-11-01 00:00:00"},
          "balances":[{"grantId":\#(id(1)),"holderMemberId":\#(id(5)),"chapterId":\#(id(11)),"grantNo":1,"grantType":"PURCHASE",
                       "unitsTotal":1,"counts":{"AVAILABLE":1,"RESERVED":0,"REDEEMED":0,"FORFEITED":0,"HELD":0,"REFUND_PENDING":0,"REFUNDED":0},
                       "validFrom":1793491200000,"validTo":1825027200000,"expired":false}],
          "units":[{"id":\#(id(21)),"grantId":\#(id(1)),"registrationId":\#(id(9001)),"holderMemberId":\#(id(5)),"chapterId":\#(id(11)),
                    "unitSeq":1,"unitCode":"UC-0001","unitValue":49.75,"status":"\#(unitStatus)","redemptionId":null,"reservationId":null,
                    "statusReason":null,"version":0,"createTime":"2026-11-01 00:00:00","updateTime":"2026-11-01 00:00:00",
                    "grantNo":1,"validFrom":"2026-11-01 00:00:00","validTo":"2027-11-01 00:00:00"}],
          "reservations":[{"id":\#(id(31)),"unitId":\#(id(21)),"registrationId":\#(id(9001)),"holderMemberId":\#(id(5)),"chapterId":\#(id(11)),
                           "offerId":\#(id(7)),"merchantId":\#(id(3)),"startAt":"2026-12-01 12:00:00","status":"BOOKED",
                           "idempotencyKey":"k-1","requestFingerprint":"fp-r","closedAt":null,"version":0,
                           "createTime":"2026-11-01 00:00:00","updateTime":"2026-11-01 00:00:00"}],
          "exitCases":[{"id":\#(id(1)),"unitId":\#(id(21)),"registrationId":\#(id(9001)),"holderMemberId":\#(id(5)),"exitedOfferId":\#(id(7)),
                        "reservationId":null,"decision":"SWAP_CONSENTED","targetOfferId":\#(id(8)),"idempotencyKey":"x-1",
                        "requestFingerprint":"fp-x","createTime":"2026-11-01 00:00:00"}],
          "policy":\#(policy)
         }}
        """#
    }

    static let cancelQuoteWaived = #"""
    {"reservationId":31,"registrationId":9001,"holderMemberId":5,"version":0,"status":"BOOKED","asOf":1767000000000,
     "useWaiver":true,"outcome":"WAIVED","expectedOutcome":"WAIVED:2026-11","canCancel":true,"waiverMonth":"2026-11"}
    """#

    static let receiptNotFound = #"{"requestId":"bundle-order:9001","receipt":"NOT_FOUND"}"#
    static let receiptNotFoundParked = #"{"requestId":"bundle-order:9001","receipt":"NOT_FOUND","outcome":"UNKNOWN"}"#
    static func receiptFound() -> String { #"{"requestId":"bundle-order:9001","receipt":"FOUND","order":\#(orderView())}"# }

    static let exitOptions = #"""
    {"registrationId":9001,"unitId":21,"holderMemberId":5,"merchantExited":true,
     "targets":[{"offerId":8,"merchantName":"M","validEnd":1825027200000}],"refundSubmissionAvailable":false}
    """#
}

final class BNDContractsDecodingTests: XCTestCase {
    private func decode<T: Decodable>(_ type: T.Type, _ json: String) throws -> T {
        try JSONDecoder().decode(type, from: Data(json.utf8))
    }
    private func id(_ n: Int64) throws -> FreeExploreLaunchID { try FreeExploreLaunchID(n) }

    func testDecodesOrderViewWithAllUnitFields() throws {
        let view = try decode(BundleOrderView.self, BNDFixtures.orderView())
        let bundle = try XCTUnwrap(view.bundle)
        XCTAssertEqual(view.registrationId, try id(9001))
        XCTAssertEqual(bundle.order.holderMemberId, try id(5))
        XCTAssertEqual(bundle.order.paidAmount.text, "199")
        XCTAssertNil(bundle.order.activityId)
        XCTAssertNil(bundle.refundHold)
        let unit = try XCTUnwrap(bundle.units.first)
        XCTAssertEqual(unit.id, try id(21)); XCTAssertEqual(unit.grantId, try id(1))
        XCTAssertEqual(unit.registrationId, try id(9001)); XCTAssertEqual(unit.holderMemberId, try id(5))
        XCTAssertEqual(unit.chapterId, try id(11)); XCTAssertEqual(unit.unitSeq, 1)
        XCTAssertEqual(unit.unitCode, "UC-0001"); XCTAssertEqual(unit.unitValue.text, "49.75")
        XCTAssertEqual(unit.status, "AVAILABLE"); XCTAssertTrue(unit.isKnown)
        XCTAssertNil(unit.redemptionId); XCTAssertNil(unit.reservationId); XCTAssertNil(unit.statusReason)
        XCTAssertEqual(unit.version, 0); XCTAssertEqual(unit.grantNo, 1)
        XCTAssertEqual(unit.validFrom.raw, "2026-11-01 00:00:00")
        // Bare strings are Asia/Shanghai: 2026-11-01 00:00 CST == 2026-10-31T16:00:00Z == 1793462400000.
        XCTAssertEqual(unit.validFrom.epochMs, 1_793_462_400_000)
        let balance = try XCTUnwrap(bundle.balances.first)
        XCTAssertEqual(balance.counts["AVAILABLE"], 1); XCTAssertEqual(balance.counts.count, 7)
        XCTAssertEqual(balance.validFrom.epochMs, 1_793_491_200_000); XCTAssertFalse(balance.expired)
        XCTAssertEqual(bundle.reservations.first?.status, "BOOKED")
        XCTAssertEqual(bundle.exitCases.first?.decision, "SWAP_CONSENTED")
        XCTAssertEqual(bundle.exitCases.first?.targetOfferId, try id(8))
        XCTAssertEqual(bundle.policy.version, "F3P1-20261022")
        XCTAssertEqual(bundle.policy.freeCancelHours, 12); XCTAssertEqual(bundle.policy.monthlyVoluntaryWaivers, 1)
        XCTAssertFalse(bundle.policy.partialRefundMinRatio.text.isEmpty)
    }

    func testDecodesLegacyOrderBundleNull() throws {
        let view = try decode(BundleOrderView.self, BNDFixtures.legacyOrder)
        XCTAssertNil(view.bundle)
        XCTAssertEqual(view.registrationId, try id(9001)); XCTAssertEqual(view.paymentStatus, 2)
    }

    func testDecodesParkedStringIdsAndPrimaryNumericIds() throws {
        let primary = try decode(BundleOrderView.self, BNDFixtures.orderView(ids: true))
        let parked = try decode(BundleOrderView.self, BNDFixtures.orderView(ids: false))
        XCTAssertEqual(primary, parked)
        // Long ids beyond Double precision survive as text.
        let big = #"{"id":"9007199254740993","unitId":"21","registrationId":"9001","holderMemberId":"5","exitedOfferId":"7","reservationId":null,"decision":"REFUND_UNFULFILLED","targetOfferId":null,"idempotencyKey":"x","requestFingerprint":"f"}"#
        XCTAssertEqual(try decode(BundleExitCase.self, big).id.text, "9007199254740993")
        // Parked-only refundHold decodes when present; its absence on primary was asserted above.
        let hold = try decode(BundleRefundHold.self, #"{"registrationId":"9001","refundId":"88","refundNo":"RF-1","cashAmount":"199.00","state":"PENDING","version":2}"#)
        XCTAssertEqual(hold.state, "PENDING"); XCTAssertEqual(hold.cashAmount?.text, "199.00")
        // Non-positive ids are malformed, never silently zero.
        XCTAssertThrowsError(try decode(BundleExitCase.self, big.replacingOccurrences(of: "\"unitId\":\"21\"", with: "\"unitId\":0")))
    }

    func testUnknownUnitStatusDecodes() throws {
        let view = try decode(BundleOrderView.self, BNDFixtures.orderView(unitStatus: "FUTURE_SERVER_STATE"))
        let unit = try XCTUnwrap(view.bundle?.units.first)
        XCTAssertEqual(unit.status, "FUTURE_SERVER_STATE"); XCTAssertFalse(unit.isKnown)
        for known in BundleStatusCatalog.knownUnitStatuses {
            let v = try decode(BundleOrderView.self, BNDFixtures.orderView(unitStatus: known))
            XCTAssertEqual(v.bundle?.units.first?.isKnown, true, known)
        }
    }

    func testDecodesCancelQuoteWaivedExpectedOutcome() throws {
        let quote = try decode(BundleCancelQuote.self, BNDFixtures.cancelQuoteWaived)
        XCTAssertEqual(quote.expectedOutcome, "WAIVED:2026-11")
        XCTAssertEqual(quote.outcome, "WAIVED"); XCTAssertTrue(quote.useWaiver); XCTAssertTrue(quote.canCancel)
        XCTAssertEqual(quote.waiverMonth, "2026-11"); XCTAssertEqual(quote.reservationId, try id(31))
        XCTAssertEqual(quote.version, 0); XCTAssertEqual(quote.status, "BOOKED")
        XCTAssertEqual(quote.asOf.epochMs, 1_767_000_000_000)
    }

    func testReceiptNotFoundIsNotProofOfNoWrite() throws {
        let plain = try decode(BundleOrderReceipt.self, BNDFixtures.receiptNotFound)
        XCTAssertEqual(plain.receipt, .notFound); XCTAssertNil(plain.order); XCTAssertNil(plain.outcome)
        XCTAssertFalse(plain.provesNoWrite)
        let parked = try decode(BundleOrderReceipt.self, BNDFixtures.receiptNotFoundParked)
        XCTAssertEqual(parked.outcome, "UNKNOWN"); XCTAssertFalse(parked.provesNoWrite)
        let found = try decode(BundleOrderReceipt.self, BNDFixtures.receiptFound())
        XCTAssertEqual(found.receipt, .found); XCTAssertNotNil(found.order?.bundle)
        // An unrecognised receipt state is malformed, not "no write".
        XCTAssertThrowsError(try decode(BundleOrderReceipt.self, #"{"requestId":"r","receipt":"AMBIGUOUS"}"#))
    }

    func testDecodesExitOptions() throws {
        let options = try decode(BundleExitOptions.self, BNDFixtures.exitOptions)
        XCTAssertTrue(options.merchantExited); XCTAssertFalse(options.refundSubmissionAvailable)
        XCTAssertEqual(options.targets.first?.offerId, try id(8))
        XCTAssertEqual(options.targets.first?.validEnd?.epochMs, 1_825_027_200_000)
    }
}
