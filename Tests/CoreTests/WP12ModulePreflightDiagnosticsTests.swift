import Foundation
import XCTest
@testable import QuestifyCore

/// Synthetic wire bytes only. Drives the real service + coordinator through a recording transport.
@MainActor final class WP12ModulePreflightDiagnosticsTests: XCTestCase {
    private final class Current { var binding: NativeAttributeAuthorBinding; init(_ b: NativeAttributeAuthorBinding) { binding = b } }
    private static let row = String(NativeAttributeAuthorTestFixtures.extendedRow)
    private static func list() -> Data { Data("{\"code\":200,\"topicId\":88,\"configVersion\":4,\"data\":[\(row)]}".utf8) }
    private static func preflight(version: Int = 4, ready: Bool = false, issues: String) -> Data {
        Data("{\"code\":200,\"data\":{\"topicId\":88,\"configVersion\":\(version),\"ready\":\(ready),\"issues\":[\(issues)]}}".utf8)
    }
    private static let errorIssue = #"{"level":"error","code":"MODULE_MISSING","message":"缺少模块","field":"moduleKey","nodeId":5}"#
    private static let warnIssue = #"{"level":"warn","code":"MODULE_EMPTY","message":"模块为空","field":"title"}"#

    private func setup(_ preflight: @escaping () -> Data) async throws
        -> (NativeAttributeAuthorRecordingTransport, NativeAttributeAuthorCoordinator, Current) {
        let binding = try NativeAttributeAuthorTestFixtures.binding(), current = Current(binding)
        let wire = NativeAttributeAuthorRecordingTransport()
        wire.response = { request in
            (request.path == "api/topic/module-preflight" ? preflight() : Self.list(), 200)
        }
        let service = NativeAttributeAuthorService(transport: wire, current: { current.binding }, contract: .versionedCandidate)
        let coordinator = NativeAttributeAuthorCoordinator(binding: binding, service: service, store: .init(storage: NativeAttributeAuthorMemoryStorage()))
        await coordinator.load()
        XCTAssertNotNil(coordinator.draft)
        return (wire, coordinator, current)
    }

    func testFieldAndNodeDiagnosticsDecoded() async throws {
        let (_, coordinator, _) = try await setup { Self.preflight(issues: Self.errorIssue + "," + Self.warnIssue) }
        await coordinator.readModulePreflight()
        let result = try XCTUnwrap(coordinator.modulePreflightResult)
        XCTAssertEqual(result.issues.count, 2)
        XCTAssertEqual(result.issues[0].level, "error"); XCTAssertEqual(result.issues[0].code, "MODULE_MISSING")
        XCTAssertEqual(result.issues[0].field, "moduleKey"); XCTAssertEqual(result.issues[0].nodeID, 5)
        XCTAssertEqual(result.issues[1].level, "warn"); XCTAssertEqual(result.issues[1].field, "title"); XCTAssertNil(result.issues[1].nodeID)
        XCTAssertFalse(result.ready)
        // An issue without `field` is not a valid module-preflight issue.
        let (_, other, _) = try await setup { Self.preflight(issues: #"{"level":"error","code":"X","message":"m"}"#) }
        await other.readModulePreflight()
        XCTAssertNil(other.modulePreflightResult)
    }

    func testRevalidateBoundToSavedVersion() async throws {
        let (wire, coordinator, _) = try await setup { Self.preflight(ready: true, issues: "") }
        await coordinator.readModulePreflight()
        await coordinator.readModulePreflight()
        let reads = wire.requests.filter { $0.path == "api/topic/module-preflight" }
        XCTAssertEqual(reads.count, 2)
        XCTAssertNotEqual(reads[0].requestKey, reads[1].requestKey)
        for read in reads {
            XCTAssertEqual(read.binding, coordinator.binding)
            XCTAssertEqual(read.query["topicId"], "88")
            XCTAssertFalse(read.mutates)
        }
        XCTAssertEqual(coordinator.modulePreflightResult?.configVersion, coordinator.binding.sourceConfigVersion)
    }

    func testReadyDoesNotImplyPublish() async throws {
        let (wire, coordinator, _) = try await setup { Self.preflight(ready: true, issues: Self.warnIssue) }
        let phaseBefore = coordinator.phase
        await coordinator.readModulePreflight()
        XCTAssertEqual(coordinator.modulePreflightResult?.ready, true)
        XCTAssertEqual(coordinator.phase, phaseBefore)
        XCTAssertNil(coordinator.projectResult); XCTAssertNil(coordinator.pending)
        XCTAssertNotEqual(coordinator.phase, .confirmed)
        XCTAssertTrue(wire.requests.allSatisfy { !$0.mutates })
        XCTAssertFalse(wire.requests.contains { $0.path.contains("publish") && $0.path != "api/topic/publish-check" })
    }

    func testStaleVersionPreflightDiscarded() async throws {
        // Server answers for a different config version than the saved binding.
        let (_, coordinator, _) = try await setup { Self.preflight(version: 5, ready: true, issues: "") }
        await coordinator.readModulePreflight()
        XCTAssertNil(coordinator.modulePreflightResult)
        XCTAssertEqual(coordinator.issue, "nativeAttribute.stale")
        // The owner binding moves while the request is in flight: the late answer is discarded.
        let (wire, moving, current) = try await setup { Self.preflight(ready: true, issues: "") }
        wire.beforeFinal = nil
        let previous = wire.response
        wire.response = { request in
            if request.path == "api/topic/module-preflight" {
                current.binding = try NativeAttributeAuthorTestFixtures.binding(epoch: 2)
            }
            return try await previous(request)
        }
        await moving.readModulePreflight()
        XCTAssertNil(moving.modulePreflightResult)
    }
}
