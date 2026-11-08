import XCTest
@testable import QuestifyCore
import Foundation

// All values synthetic; fixed UTC calendar and injected clocks only.
final class BNDReserveWindowTests: XCTestCase {
    private let day: Int64 = 86_400_000
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }
    // 2030-01-01T12:00:00Z
    private let noon: Int64 = 1_893_499_200_000

    func testWindowIsAtMostFourteenDaysAndNeverBeforeNow() {
        let w = BundleReserveWindow.make(validFromMs: nil, validToMs: nil, serverNowMs: noon,
                                         deviceNowMs: 0, calendar: calendar)
        XCTAssertEqual(w.days.count, 14)
        XCTAssertGreaterThan(w.earliestMs ?? 0, noon)
        XCTAssertFalse(w.contains(noon))
        XCTAssertTrue(w.contains(noon + 1))
        XCTAssertTrue(w.days.allSatisfy { $0.earliestMs > noon })
        // Past validFrom (long ago) must not pull the window before now.
        let past = BundleReserveWindow.make(validFromMs: noon - 100 * day, validToMs: nil, serverNowMs: noon,
                                            deviceNowMs: 0, calendar: calendar)
        XCTAssertEqual(past.earliestMs, noon + 1)
        XCTAssertLessThanOrEqual(past.latestMs ?? .max, noon + 14 * day)
    }

    func testWindowClippedToUnitValidity() {
        let from = noon + 2 * day + 3_600_000
        let to = noon + 4 * day
        let w = BundleReserveWindow.make(validFromMs: from, validToMs: to, serverNowMs: noon,
                                         deviceNowMs: 0, calendar: calendar)
        XCTAssertEqual(w.earliestMs, from)
        XCTAssertEqual(w.latestMs, to)
        XCTAssertFalse(w.contains(from - 1))
        XCTAssertFalse(w.contains(to + 1))
        XCTAssertLessThan(w.days.count, 14)
    }

    func testNoSelectableDayWhenExpired() {
        let expired = BundleReserveWindow.make(validFromMs: nil, validToMs: noon - 1, serverNowMs: noon,
                                               deviceNowMs: 0, calendar: calendar)
        XCTAssertTrue(expired.isEmpty)
        XCTAssertNil(expired.earliestMs)
        let equalNow = BundleReserveWindow.make(validFromMs: nil, validToMs: noon, serverNowMs: noon,
                                                deviceNowMs: 0, calendar: calendar)
        XCTAssertTrue(equalNow.isEmpty, "startAt must be > now")
        let notYet = BundleReserveWindow.make(validFromMs: noon + 30 * day, validToMs: noon + 40 * day,
                                              serverNowMs: noon, deviceNowMs: 0, calendar: calendar)
        XCTAssertFalse(notYet.isEmpty)
        XCTAssertEqual(notYet.days.count, 11)
    }

    func testWindowUsesServerNowNotDeviceClockWhenProvided() {
        let server = BundleReserveWindow.make(validFromMs: nil, validToMs: nil, serverNowMs: noon,
                                              deviceNowMs: noon + 100 * day, calendar: calendar)
        XCTAssertEqual(server.earliestMs, noon + 1)
        let fallback = BundleReserveWindow.make(validFromMs: nil, validToMs: nil, serverNowMs: nil,
                                                deviceNowMs: noon + 100 * day, calendar: calendar)
        XCTAssertEqual(fallback.earliestMs, noon + 100 * day + 1)
    }

    func testStallRendersEveryReasonEnum() throws {
        var keys = Set<String>()
        for value in BundleOfferUnavailableReason.knownServerValues {
            let reason = BundleOfferUnavailableReason(serverValue: value)
            if case .unknown = reason { XCTFail("\(value) must be a known case") }
            XCTAssertNotEqual(reason.copyKey, "reason.generic")
            keys.insert(reason.copyKey)
        }
        XCTAssertEqual(keys.count, 8, "one distinct copy key per server enum value")
        XCTAssertEqual(BundleOfferUnavailableReason(serverValue: "SOMETHING_NEW").copyKey, "reason.generic")
        let json = #"{"offerId":"7","unavailableReasons":["NO_BALANCE","SOMETHING_NEW"],"slots":[]}"#
        let detail = try JSONDecoder().decode(BundleOfferDetail.self, from: Data(json.utf8))
        XCTAssertEqual(detail.reasons, [.noBalance, .unknown("SOMETHING_NEW")])
        XCTAssertTrue(detail.slots.isEmpty)
    }

    func testUnavailableOfferClientNeverReturnsData() async throws {
        do {
            _ = try await UnavailableBundleOfferClient().offer(offerID: try FreeExploreLaunchID(7),
                                                               registrationID: nil, fromMs: nil, toMs: nil)
            XCTFail("must throw")
        } catch { XCTAssertEqual(error as? FreeExploreLaunchFailure, .disabled) }
    }
}
