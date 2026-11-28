import Foundation
import XCTest
@testable import QuestifyCore

/// Owner correction 11-28 04:45: Alipay beside WeChat Pay, stub-tested (no SDK binary).
@MainActor final class AlipaySDKPaymentAdapterTests: XCTestCase {
    private final class Driver: AlipaySDKPaymentDriving {
        var isLinked = true
        var immediate: String?
        private(set) var orders: [String] = []
        private(set) var schemes: [String] = []
        var results: [(String) -> Void] = []
        func pay(orderString: String, fromScheme: String, result: @escaping (String) -> Void) {
            orders.append(orderString); schemes.append(fromScheme)
            if let immediate { result(immediate) } else { results.append(result) }
        }
        func handle(_ url: URL, result: @escaping (String) -> Void) -> Bool { result("9000"); return true }
    }
    private func configuration() throws -> AlipaySDKPaymentConfiguration { try .init(appScheme: "chengyinpay") }
    private func context() throws -> RuntimeDependencyContext {
        .init(market: .china, baseURL: URL(string: "https://example.com/api/")!, role: "player",
              session: try .init(accountID: 7, epoch: 1, namespace: "fixture", token: "synthetic"))
    }
    private let parameters = ["orderString": "app_id=synthetic&biz_content=%7B%7D&sign=synthetic"]

    func testDefaultGateNeverSends() async throws {
        let driver = Driver(), scope = try context()
        let adapter = AlipaySDKPaymentAdapter(driver: driver, configuration: try configuration(), context: { scope })
        XCTAssertFalse(adapter.isConfigured)
        let outcome = await adapter.pay(registrationID: 701, parameters: parameters)
        XCTAssertEqual(outcome, .unknown); XCTAssertTrue(driver.orders.isEmpty)
    }

    func testUnlinkedSDKIsNotConfigured() throws {
        let driver = Driver(), scope = try context(); driver.isLinked = false
        let adapter = AlipaySDKPaymentAdapter(driver: driver, configuration: try configuration(), allowed: { true }, context: { scope })
        XCTAssertFalse(adapter.isConfigured)
    }

    func testOrderStringAndSchemeReachTheSDK() async throws {
        let driver = Driver(), scope = try context(); driver.immediate = "9000"
        let adapter = AlipaySDKPaymentAdapter(driver: driver, configuration: try configuration(), allowed: { true }, context: { scope })
        let outcome = await adapter.pay(registrationID: 701, parameters: parameters)
        XCTAssertEqual(outcome, .returned)
        XCTAssertEqual(driver.orders, [parameters["orderString"]!]); XCTAssertEqual(driver.schemes, ["chengyinpay"])
        XCTAssertNil(adapter.pendingRegistrationID)
    }

    func testResultStatusMapping() {
        XCTAssertEqual(AlipaySDKPaymentAdapter.outcome(resultStatus: "9000"), .returned)
        XCTAssertEqual(AlipaySDKPaymentAdapter.outcome(resultStatus: "6001"), .cancelled)
        XCTAssertEqual(AlipaySDKPaymentAdapter.outcome(resultStatus: "8000"), .unknown)
        XCTAssertEqual(AlipaySDKPaymentAdapter.outcome(resultStatus: "6004"), .unknown)
        XCTAssertEqual(AlipaySDKPaymentAdapter.outcome(resultStatus: "4000"), .failed)
    }

    func testMissingOrderStringFailsClosed() async throws {
        let driver = Driver(), scope = try context()
        let adapter = AlipaySDKPaymentAdapter(driver: driver, configuration: try configuration(), allowed: { true }, context: { scope })
        let outcome = await adapter.pay(registrationID: 701, parameters: ["orderString": ""])
        XCTAssertEqual(outcome, .unknown); XCTAssertTrue(driver.orders.isEmpty)
    }

    func testURLCallbackOnlyWhilePendingOnSafepayRoute() async throws {
        let driver = Driver(), scope = try context()
        let adapter = AlipaySDKPaymentAdapter(driver: driver, configuration: try configuration(), allowed: { true }, context: { scope })
        XCTAssertFalse(adapter.acceptsURL(URL(string: "chengyinpay://safepay/?result=x")!))
        let task = Task { await adapter.pay(registrationID: 701, parameters: self.parameters) }
        for _ in 0..<30 { await Task.yield() }
        XCTAssertEqual(adapter.pendingRegistrationID, 701)
        XCTAssertFalse(adapter.acceptsURL(URL(string: "chengyinpay://other/")!))
        XCTAssertFalse(adapter.acceptsURL(URL(string: "otherapp://safepay/")!))
        XCTAssertTrue(adapter.handle(URL(string: "chengyinpay://safepay/?result=x")!))
        let outcome = await task.value
        XCTAssertEqual(outcome, .returned)
    }

    func testInvalidSchemeIsRejected() {
        XCTAssertThrowsError(try AlipaySDKPaymentConfiguration(appScheme: ""))
        XCTAssertThrowsError(try AlipaySDKPaymentConfiguration(appScheme: "9bad"))
        XCTAssertThrowsError(try AlipaySDKPaymentConfiguration(appScheme: "has space"))
    }
}
