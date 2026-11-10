import XCTest
@testable import QuestifyCore

final class ActivityPublishingPageReadinessTests: XCTestCase {
    func testCountKeepsZeroAndRendersUnknownAsEmDash() {
        XCTAssertEqual(ActivityPublishingPageReadiness.unknownDisplay, "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .number(0)).display, "0")
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .number(0)).value, 0)
        XCTAssertFalse(ActivityPublishingPageReadiness.Count(json: .number(0)).isUnknown)
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .string("0")).display, "0")
        XCTAssertNil(ActivityPublishingPageReadiness.Count(json: nil).value)
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: nil).display, "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .string("UNKNOWN")).display, "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .string("")).display, "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .string("00")).display, "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .bool(false)).display, "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.Count(json: .number(Decimal(string: "1.5")!)).display, "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.draftQuantity(""), "—")
        XCTAssertEqual(ActivityPublishingPageReadiness.draftQuantity("0"), "0")
        XCTAssertEqual(ActivityPublishingPageReadiness.draftQuantity("12"), "12")
    }

    func testOptionPhasesAreLoadingEmptyErrorAndReady() throws {
        let loading = ActivityPublishingPageReadiness.OptionList.resolve(loading: true, failed: false, rows: [])
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertNil(loading.messageKey)

        let empty = try ActivityPublishingPageReadiness.options(kind: .categories(activity: true), payload: try ActivityPublishingFixtureData.json(ActivityPublishingFixtureData.emptyCategories))
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.messageKey, "publishModes.empty")
        XCTAssertTrue(empty.rows.isEmpty)

        let failed = ActivityPublishingPageReadiness.OptionList.resolve(loading: false, failed: true, rows: [PublishingOption(id: 1, name: "Synthetic")])
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.messageKey, "publishModes.readFailed")
        XCTAssertTrue(failed.rows.isEmpty)

        let ready = try ActivityPublishingPageReadiness.options(kind: .categories(activity: true), payload: try ActivityPublishingFixtureData.json(ActivityPublishingFixtureData.categories))
        XCTAssertEqual(ready.phase, .ready)
        XCTAssertEqual(ready.rows.map(\.name), ["Synthetic walk"])
        XCTAssertThrowsError(try ActivityPublishingPageReadiness.options(kind: .collaborators(keyword: ""), payload: try ActivityPublishingFixtureData.json(ActivityPublishingFixtureData.malformedOptions)))
    }

    func testUnknownFollowIsEmDashAndZeroFollowStaysZero() throws {
        let missing = try objectRow(ActivityPublishingFixtureData.collaboratorsUnknownFollow)
        XCTAssertEqual(ActivityPublishingPageReadiness.collaboratorFollowText(missing), "—")
        let existing = try PublishingContracts.options(try ActivityPublishingFixtureData.json(ActivityPublishingFixtureData.collaboratorsUnknownFollow), kind: .collaborators(keyword: ""))
        XCTAssertEqual(existing.first?.detail, "—")

        let zero = try objectRow(ActivityPublishingFixtureData.collaboratorsZeroFollow)
        XCTAssertEqual(ActivityPublishingPageReadiness.collaboratorFollowText(zero), "0")
        let zeroRows = try PublishingContracts.options(try ActivityPublishingFixtureData.json(ActivityPublishingFixtureData.collaboratorsZeroFollow), kind: .collaborators(keyword: ""))
        XCTAssertEqual(zeroRows.first?.detail, "0")

        let word = try objectRow(ActivityPublishingFixtureData.collaboratorsUnknownWord)
        XCTAssertEqual(ActivityPublishingPageReadiness.collaboratorFollowText(word), "—")
    }

    func testSnapshotPrefersUnknownThenLoadingThenErrorThenEmpty() {
        let empty = ActivityPublishingPageReadiness.OptionList.resolve(loading: false, failed: false, rows: [])
        let loading = ActivityPublishingPageReadiness.OptionList.resolve(loading: true, failed: true, rows: [])
        XCTAssertEqual(ActivityPublishingPageReadiness.snapshot(options: empty, submission: .unknown).phase, .unknown)
        XCTAssertEqual(ActivityPublishingPageReadiness.messageKey(for: .unknown), "publishModes.unknown")
        XCTAssertEqual(ActivityPublishingPageReadiness.snapshot(options: loading, submission: nil).phase, .loading)
        XCTAssertEqual(ActivityPublishingPageReadiness.snapshot(options: empty, submission: .notSent).phase, .error)
        XCTAssertEqual(ActivityPublishingPageReadiness.snapshot(options: empty, submission: .rejected("denied")).phase, .error)
        XCTAssertEqual(ActivityPublishingPageReadiness.snapshot(options: empty, submission: nil).phase, .empty)
        XCTAssertEqual(ActivityPublishingPageReadiness.submissionPhase(.acknowledged), .ready)
    }

    func testCapabilityUsesLiveReadsAndKeepsMissingCreateRequestsHidden() throws {
        let known = try body(ActivityPublishingFixtureData.capabilityKnown)
        let gate = ActivityPublishingPageReadiness.CapabilityGate.parse(known)
        XCTAssertTrue(gate.activityAllowed)
        XCTAssertEqual(gate.remaining.display, "3")
        assertMoneyAndMerchantStayOff(gate)

        let unknown = ActivityPublishingPageReadiness.CapabilityGate.parse(try body(ActivityPublishingFixtureData.capabilityUnknownQuota))
        XCTAssertTrue(unknown.activityAllowed)
        XCTAssertEqual(unknown.remaining.display, "—")
        XCTAssertNil(unknown.remaining.value)
        assertMoneyAndMerchantStayOff(unknown)

        let zero = ActivityPublishingPageReadiness.CapabilityGate.parse(try body(ActivityPublishingFixtureData.capabilityZeroQuota))
        XCTAssertEqual(zero.remaining.display, "0")
        XCTAssertEqual(zero.remaining.value, 0)

        let absent = ActivityPublishingPageReadiness.CapabilityGate.parse(nil)
        XCTAssertFalse(absent.activityAllowed)
        XCTAssertEqual(absent.remaining.display, "—")
        assertMoneyAndMerchantStayOff(absent)

        XCTAssertTrue(ActivityPublishingPageReadiness.supportingReads().allSatisfy(ActivityPublishingPageReadiness.supportingReadIsLive))
        XCTAssertFalse(ActivityPublishingPageReadiness.createRequestRecoveryOffered)
        XCTAssertTrue(ActivityPublishingPageReadiness.createRequestRecoveryHidden)
        for path in ActivityPublishingPageReadiness.createRequestPaths {
            XCTAssertTrue(ActivityPublishingPageReadiness.createRequestPathStaysHidden(path))
            XCTAssertNotEqual(ChinaReviewedRouteCapability.mark(for: path), .liveInProduction)
        }
    }

    private func assertMoneyAndMerchantStayOff(_ gate: ActivityPublishingPageReadiness.CapabilityGate) {
        XCTAssertFalse(gate.showsMerchantChoice)
        XCTAssertFalse(gate.paymentEnabled)
        XCTAssertFalse(gate.payoutEnabled)
        XCTAssertFalse(gate.withdrawalEnabled)
        XCTAssertFalse(gate.virtualGoodsEnabled)
    }

    private func body(_ text: String) throws -> [String: ProjectEditJSON] {
        try XCTUnwrap(try ActivityPublishingFixtureData.json(text).object)
    }

    private func objectRow(_ text: String) throws -> [String: ProjectEditJSON] {
        let payload = try ActivityPublishingFixtureData.json(text)
        let row = try XCTUnwrap(payload.object?["rows"]?.array?.first?.object)
        return row
    }
}
