import XCTest
@testable import QuestifyCore

final class WP11PushMemberBindingTests: XCTestCase {
    private let sandbox = DevicePushRegistrationLifecycle.envSandbox
    private let production = DevicePushRegistrationLifecycle.envProductionLabel

    func testAccountSwitchDropsOldAudience() throws {
        var registry = PushMemberBindingRegistry()
        try registry.bind(memberID: "m1", installationID: "i1", environment: sandbox, token: "fixture-t1")
        XCTAssertTrue(registry.mayDeliver(memberID: "m1", installationID: "i1"))
        let result = try registry.bind(memberID: "m2", installationID: "i1", environment: sandbox, token: "fixture-t1")
        guard case .rebound(let old, _) = result else { return XCTFail("expected rebound") }
        XCTAssertEqual(old.memberID, "m1")
        XCTAssertFalse(registry.mayDeliver(memberID: "m1", installationID: "i1"))
        XCTAssertTrue(registry.mayDeliver(memberID: "m2", installationID: "i1"))
    }

    func testEnvironmentChangeRebindsMember() throws {
        var registry = PushMemberBindingRegistry()
        try registry.bind(memberID: "m1", installationID: "i1", environment: sandbox, token: "fixture-t1")
        let result = try registry.bind(memberID: "m1", installationID: "i1", environment: production, token: "fixture-t2")
        guard case .rebound(let old, let new) = result else { return XCTFail("expected rebound") }
        XCTAssertEqual(old.environment, sandbox)
        XCTAssertEqual(new.environment, production)
        XCTAssertEqual(registry.bindingByInstallation["i1"], new)
        XCTAssertThrowsError(try registry.bind(memberID: "m1", installationID: "i1", environment: "BOGUS", token: "x"))
    }

    func testRevokeDeregistersToken() throws {
        var registry = PushMemberBindingRegistry()
        try registry.bind(memberID: "m1", installationID: "i1", environment: sandbox, token: "fixture-t1")
        let dropped = registry.revoke(installationID: "i1")
        XCTAssertEqual(dropped?.token, "fixture-t1")
        XCTAssertFalse(registry.mayDeliver(memberID: "m1", installationID: "i1"))
        XCTAssertNil(registry.revoke(installationID: "i1"))
    }
}
