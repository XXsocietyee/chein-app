import XCTest
@testable import QuestifyCore

final class PublishFabuPageModelTests: XCTestCase {
    private let dash = "—"

    func testEmptyAndUnknownAreAnEmDashAndZeroStaysZero() {
        XCTAssertEqual(dash, "\u{2014}")
        let empty = PublishFabuPageModel.project(coordinatorState: .idle, messageKey: nil, home: proHome(remaining: .number(2)), chapterCount: 0)
        XCTAssertEqual(empty.phase, .empty)
        XCTAssertEqual(empty.text, dash)
        XCTAssertEqual(empty.chapters.text, dash)
        XCTAssertNotEqual(empty.chapters.text, "0")
        XCTAssertEqual(empty.quota, readyQuota(2))
        let zero = PublishFabuPageModel.project(coordinatorState: .idle, messageKey: nil, home: proHome(remaining: .number(0)), chapterCount: 3)
        XCTAssertEqual(zero.phase, .ready)
        XCTAssertEqual(zero.text, "0")
        XCTAssertEqual(zero.quota.text, "0")
        XCTAssertEqual(zero.chapters.text, "3")
        let numeric = PublishFabuPageModel.project(coordinatorState: .idle, messageKey: nil, home: proHome(remaining: .string("0")), chapterCount: 2)
        XCTAssertEqual(numeric.quota.phase, .unknown)
        XCTAssertEqual(numeric.quota.text, dash)
        XCTAssertFalse(numeric.quota.text.contains("0"))
    }

    func testMissingCapabilityStaysHiddenAndDoesNotGuessZero() {
        for home in [nil as [String: ProjectEditJSON]?, [:], ["permission": .object([:])], ["permission": .object(["canProPublish": .bool(false)])], ["permission": .object(["canProPublish": .string("true")])], ["permission": .null]] {
            let hidden = PublishFabuPageModel.project(coordinatorState: .idle, messageKey: nil, home: home, chapterCount: 0)
            XCTAssertFalse(hidden.visible)
            XCTAssertEqual(hidden.phase, .unknown)
            XCTAssertEqual(hidden.text, dash)
            XCTAssertEqual(hidden.accessibilityIdentifier, PublishFabuAccessibility.hidden)
            XCTAssertEqual(hidden.quota.text, dash)
            XCTAssertEqual(hidden.chapters.text, dash)
            XCTAssertNotEqual(hidden.chapters.text, "0")
        }
        XCTAssertFalse(PublishFabuPageProjection.opensPlayerFirstEntry)
        XCTAssertFalse(PublishFabuPageProjection.registersRoute)
        XCTAssertFalse(PublishFabuPageProjection.marksRouteLive)
    }

    func testLoadingHidesAStaleZeroAndUnknownOutcomeDoesNotShowIt() {
        let loading = PublishFabuPageModel.project(coordinatorState: .loading, messageKey: "0", home: proHome(remaining: .number(0)), chapterCount: 0)
        XCTAssertEqual(loading.phase, .loading)
        XCTAssertEqual(loading.text, "")
        XCTAssertFalse(loading.visible)
        XCTAssertFalse(loading.text.contains(dash))
        XCTAssertFalse(loading.quota.text.contains("0"))
        XCTAssertFalse(loading.chapters.text.contains("0"))
        for state in [PublishFabuCoordinatorState.reviewing, .submitting] {
            let busy = PublishFabuPageModel.project(coordinatorState: state, messageKey: nil, home: proHome(remaining: .number(0)), chapterCount: 0)
            XCTAssertEqual(busy.phase, .loading)
            XCTAssertEqual(busy.text, "")
        }
        for state in [PublishFabuCoordinatorState.unknown, .notSent] {
            let unknown = PublishFabuPageModel.project(coordinatorState: state, messageKey: nil, home: proHome(remaining: .number(0)), chapterCount: 4)
            XCTAssertEqual(unknown.phase, .unknown)
            XCTAssertEqual(unknown.text, dash)
            XCTAssertFalse(unknown.visible)
            XCTAssertEqual(unknown.quota.text, dash)
            XCTAssertFalse(unknown.quota.text.contains("0"))
        }
    }

    func testErrorKeepsARealTokenAndNumericTokensStayUnknown() {
        let failed = PublishFabuPageModel.project(coordinatorState: .blocked, messageKey: " projectEdit.loadFailed ", home: proHome(remaining: .number(0)), chapterCount: 0)
        XCTAssertEqual(failed.phase, .error)
        XCTAssertEqual(failed.text, "projectEdit.loadFailed")
        XCTAssertTrue(failed.visible)
        XCTAssertEqual(failed.accessibilityIdentifier, PublishFabuAccessibility.error)
        XCTAssertEqual(failed.quota.text, dash)
        XCTAssertNotEqual(failed.quota.text, "0")
        for token in ["", "  ", "UNKNOWN", "unknown", "0", "0.0", "12", dash] {
            let state = PublishFabuPageModel.project(coordinatorState: .rejected, messageKey: token, home: proHome(remaining: .number(1)), chapterCount: 1)
            XCTAssertEqual(state.phase, .unknown, token)
            XCTAssertEqual(state.text, dash, token)
            XCTAssertFalse(state.text.contains("0"))
        }
        let gated = PublishFabuPageModel.project(coordinatorState: .blocked, messageKey: "projectEdit.loadFailed", home: nil, chapterCount: 2)
        XCTAssertFalse(gated.visible)
        XCTAssertEqual(gated.accessibilityIdentifier, PublishFabuAccessibility.hidden)
        XCTAssertEqual(gated.text, dash)
    }

    func testKnownChapterCountAndMissingQuotaStayDistinct() {
        let missingQuota = PublishFabuPageModel.project(coordinatorState: .acknowledged, messageKey: nil, home: proHome(remaining: nil), chapterCount: 2)
        XCTAssertEqual(missingQuota.phase, .ready)
        XCTAssertEqual(missingQuota.text, "2")
        XCTAssertEqual(missingQuota.quota.phase, .unknown)
        XCTAssertEqual(missingQuota.quota.text, dash)
        let bothMissing = PublishFabuPageModel.project(coordinatorState: .simulated, messageKey: nil, home: proHome(remaining: .null), chapterCount: nil)
        XCTAssertEqual(bothMissing.phase, .unknown)
        XCTAssertTrue(bothMissing.visible)
        XCTAssertEqual(bothMissing.quota.text, dash)
        XCTAssertEqual(bothMissing.chapters.phase, .unknown)
        let negative = PublishFabuPageModel.project(coordinatorState: .idle, messageKey: nil, home: proHome(remaining: .number(1)), chapterCount: -1)
        XCTAssertEqual(negative.chapters.phase, .unknown)
        XCTAssertEqual(negative.text, "1")
    }

    @MainActor func testCoordinatorWiringUsesTheLiveStateAndDoesNotOpenPlayerEntry() {
        let coordinator = ProjectEditCoordinator(initial: .init(draft: .init()), service: ProjectEditDisabledService(), store: ProjectEditLocalStore(storage: ProjectEditMemoryStorage()), currentSession: { nil })
        XCTAssertEqual(PublishFabuCoordinatorState(matching: coordinator.state), .idle)
        let hidden = coordinator.fabuPageModel(home: nil, chapterCount: 0)
        XCTAssertFalse(hidden.visible)
        XCTAssertEqual(hidden.text, dash)
        XCTAssertFalse(PublishFabuPageProjection.opensPlayerFirstEntry)
        let pairs: [(ProjectEditCoordinator.State, PublishFabuCoordinatorState)] = [
            (.idle, .idle), (.loading, .loading), (.reviewing, .reviewing), (.submitting, .submitting),
            (.simulated, .simulated), (.acknowledged, .acknowledged), (.unknown, .unknown),
            (.rejected, .rejected), (.notSent, .notSent), (.blocked, .blocked)
        ]
        for (state, expected) in pairs {
            XCTAssertEqual(PublishFabuCoordinatorState(matching: state), expected)
        }
    }

    private func proHome(remaining: ProjectEditJSON?) -> [String: ProjectEditJSON] {
        var body: [String: ProjectEditJSON] = ["permission": .object(["canProPublish": .bool(true)])]
        if let remaining { body["quota"] = .object(["themesRemaining": remaining]) }
        return body
    }

    private func readyQuota(_ number: Int) -> PublishFabuFieldState {
        PublishFabuFieldState(phase: .ready, text: String(number), reason: "ready.quota", accessibilityIdentifier: PublishFabuAccessibility.quota)
    }
}
