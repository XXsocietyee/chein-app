#if canImport(QuestifyCore)
import XCTest
@testable import QuestifyCore

@available(macOS 14.0, *)
@MainActor final class NearbyMerchantPermissionStateTests: XCTestCase {
    private let date = Date(timeIntervalSince1970: 1_700_000_000)

    @MainActor private final class DeniedLocation: RoamDeviceLocationProviding {
        var calls = 0
        func currentFix() async throws -> RoamDeviceFix { calls += 1; throw PlayExperienceError.disabled }
        func stop() {}
    }
    @MainActor private final class GoodLocation: RoamDeviceLocationProviding {
        func currentFix() async throws -> RoamDeviceFix {
            try RoamDeviceFix(coordinate: XCTUnwrap(RoamCoordinate(latitude: 39.9, longitude: 116.4)), accuracyMeters: 5,
                              measuredAt: Date(timeIntervalSince1970: 1_700_000_000), datum: .wgs84)
        }
        func stop() {}
    }
    @MainActor private final class FailingReader: CoopFlowReading {
        var session: CoopFlowSession?
        var failure: Error
        var reads = 0
        init(failure: Error) throws {
            self.failure = failure
            session = try CoopFlowSession(accountID: 7, epoch: 1, token: "synthetic")
        }
        func read(_ resource: CoopFlowRead) async throws -> CoopFlowJSON { reads += 1; throw failure }
        func settlement(source: CoopFlowSettlement.Source, id: Int) async throws -> CoopFlowSettlement { throw CoopFlowFailure.unavailable }
    }

    func testDeniedLocationGrantIsDistinctRecoverableStateAndNeverReads() async throws {
        let reader = try FailingReader(failure: CoopFlowFailure.unavailable)
        let location = DeniedLocation()
        let model = NearbyMerchantCoordinator(reader: reader, location: location, approved: { true }, now: { self.date })
        await model.search(purposeAccepted: true)
        XCTAssertEqual(model.phase, .locationDenied)
        XCTAssertEqual(reader.reads, 0)
        XCTAssertTrue(model.rows.isEmpty)
        XCTAssertFalse(model.isBusy)
        // Retry is the same explicit action and stays denied until the grant changes.
        await model.search(purposeAccepted: true)
        XCTAssertEqual(location.calls, 2)
        XCTAssertEqual(model.phase, .locationDenied)
    }

    func testServerPermissionRefusalIsPermissionDeniedNotGenericFailure() async throws {
        let reader = try FailingReader(failure: CoopFlowFailure.permission)
        let model = NearbyMerchantCoordinator(reader: reader, location: GoodLocation(), approved: { true }, now: { self.date })
        await model.search(purposeAccepted: true)
        XCTAssertEqual(reader.reads, 1)
        XCTAssertEqual(model.phase, .permissionDenied)
        XCTAssertTrue(model.rows.isEmpty)
        reader.failure = CoopFlowFailure.server(403, nil)
        await model.search(purposeAccepted: true)
        XCTAssertEqual(model.phase, .permissionDenied)
    }

    func testOtherReadFailureRemainsRetryableFailure() async throws {
        let reader = try FailingReader(failure: CoopFlowFailure.server(500, nil))
        let model = NearbyMerchantCoordinator(reader: reader, location: GoodLocation(), approved: { true }, now: { self.date })
        await model.search(purposeAccepted: true)
        XCTAssertEqual(model.phase, .failed)
        reader.failure = CoopFlowFailure.malformed
        await model.search(purposeAccepted: true)
        XCTAssertEqual(model.phase, .failed)
        XCTAssertEqual(reader.reads, 2)
    }
}
#endif
