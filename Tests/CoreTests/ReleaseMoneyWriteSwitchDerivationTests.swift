import XCTest
@testable import QuestifyCore

/// Owner 2026-11-13: money ON for TEST/DEBUG only. With no derivation installed every kind is off; an installed
/// derivation is the only way a DEBUG/TEST build opens a money write. Release keeps `static let … = false`.
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
        let source = try String(contentsOf: URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Core/ChinaReviewedRouteCapability.swift"), encoding: .utf8)
        let body = try XCTUnwrap(source.components(separatedBy: "public enum ReleaseMoneyWriteSwitch {").last)
        let release = try XCTUnwrap(body.components(separatedBy: "#else").dropFirst().first?.components(separatedBy: "#endif").first)
        for name in ["paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled", "refundEnabled", "hostCancelRefundEnabled"] {
            XCTAssertTrue(release.contains("public static let \(name) = false"), name)
        }
    }
}
