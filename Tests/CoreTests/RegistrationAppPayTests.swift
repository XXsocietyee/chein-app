#if DEBUG
import XCTest
@testable import QuestifyCore

/// Owner check 11-28 05:35 (mp-activity P0): in-app pay uses `pay/app`, and one readback decides the result.
final class RegistrationAppPayTests: XCTestCase {
    func testInAppChannelIsTheAppRoute() {
        XCTAssertEqual(RegistrationAppPayResolver.inAppChannel, .app)
        XCTAssertEqual(RegistrationAppPayResolver.inAppChannel.routePath, "/api/registration/pay/app")
    }

    func testPaidReadbackWinsOverAnyProviderReturn() {
        for providerReturn in [TopicSelfPlayProviderReturn.returned, .cancelled, .failed, .unknown] {
            XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: providerReturn, paymentStatus: 2), .paid)
        }
    }

    func testCancelledOrFailedWithoutPaymentOffersPayAgain() {
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .cancelled, paymentStatus: 0), .cancelled)
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .failed, paymentStatus: nil), .cancelled)
    }

    func testProviderReturnIsNeverProofOfPayment() {
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .returned, paymentStatus: 0), .checking)
        XCTAssertEqual(RegistrationAppPayResolver.stage(providerReturn: .unknown, paymentStatus: nil), .checking)
    }

    func testRefreshOnlyMovesToPaidOnPaidStatus() {
        XCTAssertEqual(RegistrationAppPayResolver.refreshed(paymentStatus: 2), .paid)
        XCTAssertEqual(RegistrationAppPayResolver.refreshed(paymentStatus: 1), .checking)
        XCTAssertEqual(RegistrationAppPayResolver.refreshed(paymentStatus: nil), .checking)
    }
}
#endif
