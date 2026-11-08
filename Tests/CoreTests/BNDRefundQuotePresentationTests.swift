import XCTest
@testable import QuestifyCore
import Foundation

final class BNDRefundQuotePresentationTests: XCTestCase {
    private func quote(route: String, breach: Bool, amount: String = "0.00", ratio: String = "0.1259",
                       reason: String = "server reason") throws -> FreeExploreLaunchRefundQuote {
        let json: [String: Any] = ["route": route, "amount": amount, "totalValue": "80.00",
            "remainingValue": "10.07", "remainingRatio": ratio, "afterSalesForMerchantBreach": breach,
            "reason": reason, "policyVersion": "server-version"]
        return try JSONDecoder().decode(FreeExploreLaunchRefundQuote.self,
                                        from: try JSONSerialization.data(withJSONObject: json))
    }
    private func source(_ relative: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        return try String(contentsOf: root.appendingPathComponent(relative), encoding: .utf8)
    }

    func testRouteNotRefundableShowsAfterSalesPointerWhenBreachFlag() throws {
        let flagged = BundleRefundQuotePresentation(quote: try quote(route: "NOT_REFUNDABLE", breach: true))
        XCTAssertEqual(flagged.route, .notRefundable)
        XCTAssertEqual(flagged.routeTitleKey, "routeNotRefundableTitle")
        XCTAssertTrue(flagged.showsAfterSalesPointer)
        XCTAssertEqual(flagged.afterSalesPointerKey, "afterSalesPointer")
        let plain = BundleRefundQuotePresentation(quote: try quote(route: "NOT_REFUNDABLE", breach: false))
        XCTAssertFalse(plain.showsAfterSalesPointer)
        XCTAssertNil(plain.afterSalesPointerKey)
    }

    func testNoApplyButtonExists() throws {
        let view = try source("App/BundleRefundQuoteView.swift")
        for token in ["Button", "onTapGesture", "NavigationLink", "confirmationDialog"] {
            XCTAssertFalse(view.contains(token), "view must have no action control: \(token)")
        }
        XCTAssertFalse(BundleRefundQuotePresentation.allKeys.contains { $0.lowercased().contains("apply") })
        XCTAssertTrue(BundleRefundQuotePresentation.allKeys.contains("quoteOnlyNotice"))
        let shown = BundleRefundQuotePresentation(quote: try quote(route: "ORIGINAL_METHOD", breach: false))
        XCTAssertEqual(shown.quoteOnlyNoticeKey, "quoteOnlyNotice")
    }

    func testNoClientSideRatioOrAmountComputation() throws {
        // Server values pass through verbatim, including shapes a client calculation would normalise.
        let p = BundleRefundQuotePresentation(quote: try quote(route: "PLATFORM_BALANCE", breach: false,
                                                                amount: "10.07", ratio: "0.1259"))
        XCTAssertEqual(p.amountText, "10.07"); XCTAssertEqual(p.remainingRatioText, "0.1259")
        XCTAssertEqual(p.remainingValueText, "10.07"); XCTAssertEqual(p.totalValueText, "80.00")
        XCTAssertEqual(p.serverReason, "server reason"); XCTAssertEqual(p.policyVersion, "server-version")
        // Source-text scan: no arithmetic or numeric conversion in the new files.
        for file in ["Core/BundleRefundQuotePresentation.swift", "App/BundleRefundQuoteView.swift"] {
            let text = try source(file)
            for token in ["Decimal(", "NSDecimalNumber", "Double(", "Float(", "Int(", "multipliedBy", "dividing",
                          "NumberFormatter", "String(format", " * ", " / ", " + ", " - ", "0.2"] {
                XCTAssertFalse(text.contains(token), "\(file) must not compute: \(token)")
            }
        }
    }

    func testUnknownRouteFallsBack() throws {
        let p = BundleRefundQuotePresentation(quote: try quote(route: "FUTURE_SERVER_ROUTE", breach: false))
        XCTAssertEqual(p.route, .unknown("FUTURE_SERVER_ROUTE"))
        XCTAssertEqual(p.routeTitleKey, "routeUnknownTitle"); XCTAssertEqual(p.routeBodyKey, "routeUnknownBody")
        XCTAssertEqual(p.amountText, "0.00")
        XCTAssertEqual(BundleRefundRoute(serverValue: "ORIGINAL_METHOD"), .originalMethod)
        XCTAssertEqual(BundleRefundRoute(serverValue: "PLATFORM_BALANCE"), .platformBalance)
    }
}
