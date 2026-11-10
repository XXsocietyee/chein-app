import XCTest
@testable import QuestifyCore

private final class QuickPublishSimpleReadLog {
    var calls: [PublishingRead] = []
    var resume: CheckedContinuation<ProjectEditJSON, Error>?
    var entered = 0
}

@MainActor final class QuickPublishSimplePageTests: XCTestCase {
    private var both: QuickPublishSimplePageGrant { .init(features: [.publishingRead, .publishingAIQuota]) }
    private var homeOnly: QuickPublishSimplePageGrant { .init(features: [.publishingRead]) }

    func testMissingGrantStaysHiddenAndDoesNotRead() async {
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: .init(features: [])) { query in
            log.calls.append(query); return .null
        }
        XCTAssertEqual(coordinator.snapshot.phase, .hidden)
        await coordinator.load(draft: .init())
        XCTAssertEqual(log.calls, [])
        assertConcealed(coordinator.snapshot, phase: .hidden)
    }

    func testQuotaGrantWithoutHomeStaysHidden() async {
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: .init(features: [.publishingAIQuota])) { query in
            log.calls.append(query); return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.quotaReadyJSON)
        }
        await coordinator.load(draft: .init())
        XCTAssertEqual(log.calls, [])
        assertConcealed(coordinator.snapshot, phase: .hidden)
    }

    func testHomeGrantDoesNotImplyQuotaRead() async {
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: homeOnly) { query in
            log.calls.append(query)
            return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeReadyJSON)
        }
        await coordinator.load(draft: .init())
        XCTAssertEqual(log.calls, [.capability])
        XCTAssertEqual(coordinator.snapshot.phase, .empty)
        XCTAssertFalse(coordinator.snapshot.showsAIQuota)
        XCTAssertEqual(coordinator.snapshot.quotaRemainingText, "—")
        XCTAssertEqual(coordinator.snapshot.themesRemainingText, "3")
    }

    func testGrantedHomeStartsLoadingBeforeAnyRead() {
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { _ in .null }
        XCTAssertEqual(coordinator.snapshot.phase, .loading)
        XCTAssertEqual(coordinator.snapshot.accessibilityIdentifier, QuickPublishSimplePageAccessibility.loading)
        XCTAssertEqual(coordinator.snapshot.messageKey, QuickPublishSimplePageCopy.loading)
        assertUnknownNumbers(coordinator.snapshot)
    }

    func testLoadingStaysLoadingUntilBothReadsFinish() async {
        let started = expectation(description: "home read started")
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { query in
            if query == .capability {
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProjectEditJSON, Error>) in
                    log.resume = continuation
                    started.fulfill()
                }
            }
            XCTAssertEqual(query, .aiQuota)
            return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.quotaReadyJSON)
        }
        let task = Task { await coordinator.load(draft: .init()) }
        await fulfillment(of: [started], timeout: 1)
        XCTAssertEqual(coordinator.snapshot.phase, .loading)
        assertUnknownNumbers(coordinator.snapshot)
        log.resume?.resume(returning: QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeReadyJSON))
        await task.value
        XCTAssertEqual(coordinator.snapshot.phase, .empty)
        XCTAssertEqual(coordinator.snapshot.quotaRemainingText, "2")
        XCTAssertEqual(coordinator.snapshot.quotaLimitText, "4")
        XCTAssertEqual(coordinator.snapshot.themesRemainingText, "3")
        XCTAssertEqual(coordinator.snapshot.messageKey, QuickPublishSimplePageCopy.empty)
        XCTAssertEqual(coordinator.snapshot.accessibilityIdentifier, QuickPublishSimplePageAccessibility.empty)
    }

    func testReadsOnlyExistingHomeAndQuotaPaths() async {
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { query in
            log.calls.append(query)
            switch query {
            case .capability: return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeReadyJSON)
            case .aiQuota: return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.quotaReadyJSON)
            default:
                XCTFail("unexpected read")
                return .null
            }
        }
        var draft = QuickPublishDraft()
        draft.title = "Sample route"
        await coordinator.load(draft: draft)
        XCTAssertEqual(log.calls, [.capability, .aiQuota])
        XCTAssertEqual(log.calls.map(\.request.path), [QuickPublishSimplePageContract.homePath, QuickPublishSimplePageContract.quotaPath])
        XCTAssertEqual(QuickPublishSimplePageContract.home.request.path, "api/publish/home")
        XCTAssertEqual(QuickPublishSimplePageContract.quota.request.path, "api/ai/theme/draft/quota")
        XCTAssertFalse(log.calls.contains { $0.request.path == QuickPublishSimplePageContract.unusedThemeDraftPath })
        XCTAssertEqual(coordinator.snapshot.phase, .ready)
        XCTAssertNil(coordinator.snapshot.messageKey)
        XCTAssertEqual(coordinator.snapshot.accessibilityIdentifier, QuickPublishSimplePageAccessibility.ready)
    }

    func testFailedReadIsErrorAndNotAnEmptyOrZeroQuota() async {
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { _ in
            throw PublishModesError.unavailable
        }
        await coordinator.load(draft: .init())
        XCTAssertEqual(coordinator.snapshot.phase, .error)
        XCTAssertEqual(coordinator.snapshot.messageKey, QuickPublishSimplePageCopy.loadFailed)
        XCTAssertTrue(coordinator.snapshot.showsPage)
        XCTAssertFalse(coordinator.snapshot.showsAIQuota)
        assertUnknownNumbers(coordinator.snapshot)
    }

    func testDeniedSimplePublishStaysHiddenAndDoesNotSurfaceZero() async {
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { query in
            log.calls.append(query)
            return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeDeniedJSON)
        }
        await coordinator.load(draft: .init())
        XCTAssertEqual(log.calls, [.capability])
        assertConcealed(coordinator.snapshot, phase: .hidden)
        XCTAssertNotEqual(coordinator.snapshot.themesRemainingText, "0")
        XCTAssertNil(coordinator.snapshot.themesRemaining.literal)
    }

    func testMalformedPermissionIsErrorAndDoesNotReadQuota() async {
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { query in
            log.calls.append(query)
            return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeMalformedPermissionJSON)
        }
        await coordinator.load(draft: .init())
        XCTAssertEqual(log.calls, [.capability])
        XCTAssertEqual(coordinator.snapshot.phase, .error)
        assertUnknownNumbers(coordinator.snapshot)
    }

    func testMissingPermissionFollowsExistingHomeContract() async {
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { query in
            log.calls.append(query)
            switch query {
            case .capability: return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeImplicitPermissionJSON)
            case .aiQuota: return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.quotaReadyJSON)
            default: return .null
            }
        }
        await coordinator.load(draft: .init())
        XCTAssertEqual(log.calls, [.capability, .aiQuota])
        XCTAssertEqual(coordinator.snapshot.phase, .empty)
        XCTAssertTrue(coordinator.snapshot.showsPage)
    }

    func testLiteralZeroStaysZero() {
        let snapshot = snapshot(home: QuickPublishSimplePageFixture.homeZeroThemesJSON, quota: QuickPublishSimplePageFixture.quotaZeroJSON, draft: .init())
        XCTAssertEqual(snapshot.phase, .empty)
        XCTAssertEqual(snapshot.quotaRemaining.literal, 0)
        XCTAssertEqual(snapshot.quotaRemainingText, "0")
        XCTAssertEqual(snapshot.themesRemaining.literal, 0)
        XCTAssertEqual(snapshot.themesRemainingText, "0")
        XCTAssertNotEqual(snapshot.quotaRemaining, .unknown)
    }

    func testUnlimitedNullCountIsAnEmDashAndNotZero() {
        let snapshot = snapshot(home: QuickPublishSimplePageFixture.homeReadyJSON, quota: QuickPublishSimplePageFixture.quotaUnlimitedJSON, draft: .init())
        XCTAssertEqual(snapshot.phase, .empty)
        XCTAssertEqual(snapshot.quotaRemainingText, QuickPublishSimpleCount.unknownText)
        XCTAssertEqual(snapshot.quotaLimitText, "—")
        XCTAssertNil(snapshot.quotaRemaining.literal)
        XCTAssertNil(snapshot.quotaLimit.literal)
        XCTAssertNotEqual(snapshot.quotaRemainingText, "0")
        XCTAssertEqual(snapshot.themesRemainingText, "3")
    }

    func testUnknownTokenNumericStringAndFractionStayEmDash() {
        for raw in [QuickPublishSimplePageFixture.quotaUnknownJSON, QuickPublishSimplePageFixture.quotaNumericStringJSON, QuickPublishSimplePageFixture.quotaFractionJSON] {
            let snapshot = snapshot(home: QuickPublishSimplePageFixture.homeReadyJSON, quota: raw, draft: .init())
            XCTAssertEqual(snapshot.phase, .unknown, raw)
            XCTAssertEqual(snapshot.quotaRemainingText, "—", raw)
            XCTAssertNil(snapshot.quotaRemaining.literal, raw)
            XCTAssertNotEqual(snapshot.quotaRemainingText, "0", raw)
            XCTAssertNotEqual(snapshot.quotaRemainingText, "2", raw)
            XCTAssertEqual(snapshot.messageKey, QuickPublishSimplePageCopy.unknown)
            XCTAssertEqual(snapshot.accessibilityIdentifier, QuickPublishSimplePageAccessibility.unknown)
        }
        XCTAssertThrowsError(try PublishingAIQuota(.object(["limited": .bool(true), "remaining": .string("UNKNOWN"), "limit": .number(4)])))
    }

    func testMissingThemesIsUnknownEvenWhenQuotaIsKnown() {
        var draft = QuickPublishDraft()
        draft.title = "Sample route"
        let snapshot = snapshot(home: QuickPublishSimplePageFixture.homeMissingThemesJSON, quota: QuickPublishSimplePageFixture.quotaReadyJSON, draft: draft)
        XCTAssertEqual(snapshot.phase, .unknown)
        XCTAssertEqual(snapshot.themesRemainingText, "—")
        XCTAssertNil(snapshot.themesRemaining.literal)
        XCTAssertEqual(snapshot.quotaRemainingText, "2")
        XCTAssertNotEqual(snapshot.themesRemainingText, "0")
    }

    func testBlankTitleWithAStopIsReady() {
        var draft = QuickPublishDraft()
        draft.nodes = [.init()]
        let snapshot = snapshot(home: QuickPublishSimplePageFixture.homeReadyJSON, quota: QuickPublishSimplePageFixture.quotaReadyJSON, draft: draft)
        XCTAssertEqual(snapshot.phase, .ready)
        XCTAssertTrue(snapshot.showsPage)
        XCTAssertTrue(snapshot.showsAIQuota)
    }

    func testWhitespaceTitleStaysEmpty() {
        var draft = QuickPublishDraft()
        draft.title = " \n\t "
        let snapshot = snapshot(home: QuickPublishSimplePageFixture.homeReadyJSON, quota: QuickPublishSimplePageFixture.quotaReadyJSON, draft: draft)
        XCTAssertEqual(snapshot.phase, .empty)
    }

    func testStaleLoadCannotReplaceANewerResult() async {
        let started = expectation(description: "first home read started")
        let log = QuickPublishSimpleReadLog()
        let coordinator = QuickPublishSimplePageCoordinator(grant: both) { query in
            log.entered += 1
            if log.entered == 1 {
                return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<ProjectEditJSON, Error>) in
                    log.resume = continuation
                    started.fulfill()
                }
            }
            switch query {
            case .capability: return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeReadyJSON)
            case .aiQuota: return QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.quotaReadyJSON)
            default: return .null
            }
        }
        let first = Task { await coordinator.load(draft: .init()) }
        await fulfillment(of: [started], timeout: 1)
        var draft = QuickPublishDraft()
        draft.title = "Sample route"
        await coordinator.load(draft: draft)
        XCTAssertEqual(coordinator.snapshot.phase, .ready)
        log.resume?.resume(returning: QuickPublishSimplePageFixture.decode(QuickPublishSimplePageFixture.homeDeniedJSON))
        await first.value
        XCTAssertEqual(coordinator.snapshot.phase, .ready)
        XCTAssertEqual(coordinator.snapshot.quotaRemainingText, "2")
    }

    func testFixtureDataDecodesAndStringsFileMatchesTheModel() throws {
        for raw in [
            QuickPublishSimplePageFixture.homeReadyJSON, QuickPublishSimplePageFixture.homeDeniedJSON,
            QuickPublishSimplePageFixture.quotaReadyJSON, QuickPublishSimplePageFixture.quotaUnknownJSON,
            QuickPublishSimplePageFixture.quotaUnlimitedJSON
        ] {
            XCTAssertNotEqual(QuickPublishSimplePageFixture.decode(raw), .null, raw)
        }
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("docs/release/ui-strings-pages-publish-simple-index.json")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        XCTAssertEqual(root?["page"] as? String, "pages/publish/simple/index")
        let rows = try XCTUnwrap(root?["strings"] as? [[String: Any]])
        let identifiers = try XCTUnwrap(root?["accessibilityIdentifiers"] as? [String])
        XCTAssertEqual(identifiers, QuickPublishSimplePageAccessibility.all)
        var seen = Set<String>()
        var keys = Set<String>()
        for row in rows {
            let key = try XCTUnwrap(row["key"] as? String)
            let en = try XCTUnwrap(row["en"] as? String)
            let zh = try XCTUnwrap(row["zh-Hans"] as? String)
            let identifier = try XCTUnwrap(row["accessibilityIdentifier"] as? String)
            XCTAssertFalse(key.isEmpty)
            XCTAssertFalse(en.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(zh.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertTrue(identifiers.contains(identifier))
            XCTAssertTrue(keys.insert(key).inserted)
            seen.insert(identifier)
            let blob = key + en + zh
            XCTAssertNil(blob.range(of: "http://"))
            XCTAssertNil(blob.range(of: "https://"))
        }
        XCTAssertEqual(seen, Set(identifiers))
        let unknown = try XCTUnwrap(rows.first { $0["key"] as? String == QuickPublishSimplePageCopy.unknown })
        XCTAssertEqual(unknown["en"] as? String, QuickPublishSimpleCount.unknownText)
        XCTAssertEqual(unknown["zh-Hans"] as? String, "—")
        let encoded = String(decoding: try Data(contentsOf: url), as: UTF8.self)
        for banned in ["showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"] {
            XCTAssertNil(encoded.range(of: banned))
        }
    }

    private func snapshot(home: String, quota: String, draft: QuickPublishDraft) -> QuickPublishSimplePageSnapshot {
        QuickPublishSimplePageModel.make(
            grant: both,
            home: .value(QuickPublishSimplePageFixture.decode(home)),
            quota: .value(QuickPublishSimplePageFixture.decode(quota)),
            draft: draft)
    }

    private func assertConcealed(_ snapshot: QuickPublishSimplePageSnapshot, phase: QuickPublishSimplePageSnapshot.Phase) {
        XCTAssertEqual(snapshot.phase, phase)
        XCTAssertFalse(snapshot.showsPage)
        XCTAssertFalse(snapshot.showsAIQuota)
        assertUnknownNumbers(snapshot)
    }

    private func assertUnknownNumbers(_ snapshot: QuickPublishSimplePageSnapshot) {
        XCTAssertEqual(snapshot.quotaRemainingText, "—")
        XCTAssertEqual(snapshot.quotaLimitText, "—")
        XCTAssertEqual(snapshot.themesRemainingText, "—")
        XCTAssertNil(snapshot.quotaRemaining.literal)
        XCTAssertNil(snapshot.quotaLimit.literal)
        XCTAssertNil(snapshot.themesRemaining.literal)
        XCTAssertNotEqual(snapshot.quotaRemainingText, "0")
        XCTAssertNotEqual(snapshot.themesRemainingText, "0")
    }
}
