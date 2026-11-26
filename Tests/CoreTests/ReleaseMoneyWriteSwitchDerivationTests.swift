import XCTest
@testable import QuestifyCore

/// Owner 2026-11-25: Release and DEBUG/TEST share one host derivation. With none installed every kind is off.
/// Virtual goods stay off in the installed derivation. There is no Release-only `static let … = false`.
final class ReleaseMoneyWriteSwitchDerivationTests: XCTestCase {
    func testOffByDefaultAndFollowsAnInstalledDerivation() {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        for kind in ReleaseMoneyWriteKind.allCases { XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(kind)) }
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
        ReleaseMoneyWriteSwitch.testDerivation = { $0 == .payment }
        XCTAssertTrue(ReleaseMoneyWriteSwitch.paymentEnabled)
        XCTAssertFalse(ReleaseMoneyWriteSwitch.blocks("/api/registration/pay"))
        XCTAssertTrue(ReleaseMoneyWriteSwitch.blocks("/api/asset/withdraw"))
    }

    func testReleaseBuildKeepsCompileTimeConstants() throws {
        defer { ReleaseMoneyWriteSwitch.testDerivation = nil }
        ReleaseMoneyWriteSwitch.testDerivation = nil
        for kind in ReleaseMoneyWriteKind.allCases { XCTAssertFalse(ReleaseMoneyWriteSwitch.isEnabled(kind)) }
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Core/ChinaReviewedRouteCapability.swift"), encoding: .utf8)
        let body = try XCTUnwrap(source.components(separatedBy: "public enum ReleaseMoneyWriteSwitch {").last)
        XCTAssertFalse(body.contains("#else"))
        for name in ["payment", "payout", "withdrawal", "virtualGoods", "refund", "hostCancelRefund"] {
            XCTAssertTrue(body.contains("public static var \(name)Enabled: Bool { testDerivation?(.{name}) ?? false }"), name)
            XCTAssertFalse(body.contains("\(name)Enabled = true"), name)
        }
    }
}
