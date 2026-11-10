import XCTest
@testable import QuestifyCore

final class ClubCheckinRailTests: XCTestCase {
    private func reached(_ step: ClubGovernanceValue, status: ClubGovernanceValue = .string("VERIFIED")) -> [Bool] {
        ClubCheckinRail(railStep: step, statusCode: status).stops.map(\.reached)
    }
    func testStopsLightThroughServerStepInSourceOrder() {
        let rail = ClubCheckinRail(railStep: .integer(2), statusCode: .string("VERIFIED"))
        XCTAssertEqual(rail.stops.map(\.step), [.signed, .contacted, .verified, .reviewed])
        XCTAssertEqual(rail.stops.map(\.reached), [true, true, true, false])
        XCTAssertEqual(rail.stops.map(\.current), [false, false, true, false])
        XCTAssertFalse(rail.refunded)
        XCTAssertEqual(reached(.integer(0)), [true, false, false, false])
        XCTAssertEqual(reached(.integer(3)), [true, true, true, true])
    }
    func testRefundedOrUnknownStepLightsNothing() {
        let refunded = ClubCheckinRail(railStep: .integer(-1), statusCode: .string("REFUNDED"))
        XCTAssertEqual(refunded.stops.map(\.reached), [false, false, false, false])
        XCTAssertTrue(refunded.refunded)
        for value: ClubGovernanceValue in [.null, .string("2"), .decimal(1.5), .bool(true)] {
            XCTAssertEqual(reached(value), [false, false, false, false])
            XCTAssertTrue(ClubCheckinRail(railStep: value, statusCode: .null).stops.allSatisfy { !$0.current })
        }
    }
    func testOutOfRangeStepHasNoCurrentStop() {
        let rail = ClubCheckinRail(railStep: .integer(9), statusCode: .null)
        XCTAssertEqual(rail.stops.map(\.reached), [true, true, true, true])
        XCTAssertFalse(rail.stops.contains { $0.current })
    }
    func testStateTitlesAndTimeFormatting() {
        XCTAssertEqual(ClubCheckinRail.stateTitle(for: nil, recordPresent: false), "核销记录不存在")
        XCTAssertEqual(ClubCheckinRail.stateTitle(for: .forbidden), "无权查看该核销记录")
        XCTAssertEqual(ClubCheckinRail.stateTitle(for: .rejected(code: 403, message: nil)), "无权查看该核销记录")
        XCTAssertEqual(ClubCheckinRail.stateTitle(for: .rejected(code: 500, message: "err")), "核销详情加载失败")
        let rail = ClubCheckinRail(
            railStep: .integer(1),
            statusCode: .string("CONTACTED"),
            sessionTime: .string("2026-10-19T14:30:00"),
            statusTime: .string("2026-10-19 15:00:00")
        )
        XCTAssertEqual(rail.sessionTimeText, "2026-10-19 14:30")
        XCTAssertEqual(rail.statusTimeText, "2026-10-19 15:00")
    }

    func testMissingCapabilityStaysHiddenAndDoesNotInventARoute() {
        let hidden = ClubCheckinDetailPage.bind(clientCapabilityPresent: false, loading: true, value: Self.record(registration: .integer(121), railStep: .integer(0)))
        XCTAssertNil(hidden.phase)
        XCTAssertFalse(hidden.showsContent)
        XCTAssertFalse(hidden.serverFactPresent)
        XCTAssertEqual(ClubCheckinDetailPage.readPath, ClubGovernanceRead.checkin.path)
        XCTAssertEqual(ClubCheckinDetailPage.readPath, "api/club/crm/checkin/detail")
        XCTAssertFalse(hidden.showsMerchantChoice)
        XCTAssertFalse(hidden.showsRefundAction)
        XCTAssertFalse(hidden.refundDispatchEnabled)
        XCTAssertFalse(hidden.paymentEnabled)
        XCTAssertFalse(hidden.payoutEnabled)
        XCTAssertFalse(hidden.withdrawalEnabled)
    }

    func testLoadingEmptyErrorAndUnknownDoNotBecomeZero() {
        let loading = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, loading: true)
        XCTAssertEqual(loading.phase, .some(.loading))
        XCTAssertFalse(loading.showsContent)
        let idle = ClubCheckinDetailPage.bind(clientCapabilityPresent: true)
        XCTAssertNil(idle.phase)
        let empty = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: .object([:]))
        XCTAssertEqual(empty.phase, .some(.empty))
        XCTAssertEqual(ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: .array([])).phase, .some(.empty))
        XCTAssertEqual(ClubCheckinDetailPage.bind(clientCapabilityPresent: true, recordPresent: false).phase, .some(.empty))
        XCTAssertEqual(ClubCheckinDetailPage.emptyTitleKey, "club.gov.empty")
        XCTAssertEqual(ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: .null).phase, .some(.unknown))
        XCTAssertEqual(ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: .string("0")).phase, .some(.unknown))
        let denied = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, failure: .forbidden)
        XCTAssertEqual(denied.phase, .some(.error(.denied)))
        XCTAssertEqual(ClubCheckinRail.StateKind.denied.titleKey, "club.checkin.state.denied")
        let missing = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, failure: .rejected(code: 404, message: nil))
        XCTAssertEqual(missing.phase, .some(.error(.missing)))
        XCTAssertEqual(ClubCheckinRail.StateKind.missing.title, "核销记录不存在")
        XCTAssertEqual(ClubCheckinRail.StateKind.missing.titleKey, "club.checkin.state.missing")
        let failed = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, failure: .malformed)
        XCTAssertEqual(failed.phase, .some(.error(.error)))
        XCTAssertEqual(ClubCheckinRail.StateKind.error.title, "核销详情加载失败")
        XCTAssertEqual(ClubCheckinRail.StateKind.error.titleKey, "club.checkin.state.error")
    }

    func testLiteralZeroStaysZeroAndUnknownNumbersStayEmDash() {
        let zero = try XCTUnwrap(ready(Self.record(registration: .integer(0), railStep: .integer(0), extra: [
            "paidAmountText": .integer(0), "displayName": .null, "ticketText": .string("UNKNOWN"),
            "orderTimeText": .string("0"), "storeName": .string("  "), "sessionTime": .integer(0),
            "canRefund": .string("true"), "avatar": .string("UNKNOWN")
        ])))
        XCTAssertEqual(zero.registrationIDText, "0")
        XCTAssertEqual(zero.railStepText, "0")
        XCTAssertEqual(zero.rail.stops.map(\.reached), [true, false, false, false])
        XCTAssertEqual(zero.paidAmountText, "0")
        XCTAssertEqual(zero.orderTimeText, "0")
        XCTAssertEqual(zero.sessionTimeText, "0")
        XCTAssertNil(zero.avatar)
        XCTAssertEqual(zero.displayName, "—")
        XCTAssertEqual(zero.ticketText, "—")
        XCTAssertEqual(zero.storeName, "—")
        XCTAssertFalse(zero.serverCanRefund)
        XCTAssertEqual(ClubCheckinDetailPage.display(.decimal(12.5)), "12.5")
        XCTAssertEqual(ClubCheckinDetailPage.display(.decimal(0)), "0")
        XCTAssertEqual(ClubCheckinDetailPage.numberText(.string("0")), "—")
        XCTAssertEqual(ClubCheckinDetailPage.numberText(.decimal(1.5)), "—")
        XCTAssertEqual(ClubCheckinDetailPage.numberText(.null), "—")
        XCTAssertEqual(ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: .object(["registrationId": .string("0"), "railStep": .integer(2)])).phase, .some(.unknown))
        XCTAssertEqual(ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: .object(["registrationId": .decimal(0), "railStep": .string("2")])).phase, .some(.unknown))
        let stepped = try XCTUnwrap(ready(Self.record(registration: .integer(121), railStep: .string("2"), extra: ["paidAmountText": .object(["amount": .integer(0)])])))
        XCTAssertEqual(stepped.railStepText, "—")
        XCTAssertEqual(stepped.paidAmountText, "—")
        XCTAssertEqual(stepped.rail.stops.map(\.reached), [false, false, false, false])
        XCTAssertFalse(stepped.serverCanRefund)
    }

    func testServerCanRefundDoesNotEnableDispatch() {
        let facts = try XCTUnwrap(ready(Self.record(registration: .integer(121), railStep: .integer(1), extra: ["canRefund": .bool(true), "statusCode": .string("PENDING")])))
        XCTAssertTrue(facts.serverCanRefund)
        let page = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: Self.record(registration: .integer(121), railStep: .integer(1), extra: ["canRefund": .bool(true)]))
        XCTAssertFalse(page.showsRefundAction)
        XCTAssertFalse(page.refundDispatchEnabled)
        XCTAssertFalse(page.paymentEnabled)
        XCTAssertFalse(page.payoutEnabled)
        XCTAssertFalse(page.withdrawalEnabled)
        XCTAssertFalse(page.showsMerchantChoice)
        if case .ready = page.phase {} else { XCTFail("expected a ready record") }
    }

    private func ready(_ value: ClubGovernanceValue) -> ClubCheckinDetailPage.Facts? {
        guard case .ready(let facts)? = ClubCheckinDetailPage.bind(clientCapabilityPresent: true, value: value).phase else { return nil }
        return facts
    }
    private static func record(registration: ClubGovernanceValue, railStep: ClubGovernanceValue, extra: [String: ClubGovernanceValue] = [:]) -> ClubGovernanceValue {
        var fields: [String: ClubGovernanceValue] = ["registrationId": registration, "railStep": railStep, "statusCode": .string("PENDING")]
        for (key, value) in extra { fields[key] = value }
        return .object(fields)
    }
}
