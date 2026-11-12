#if canImport(QuestifyCore)
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import QuestifyCore

/// pages/club/badges/index counts and the offline fixture. No live route is added.
@MainActor final class ClubBadgePageReadyTests: XCTestCase {
    private final class Wire: HTTPTransport {
        var handler: (URLRequest) throws -> (Data, Int) = { _ in (Data(), 503) }
        var requests: [URLRequest] = []
        var holdFirst = false
        var onHeld: (() -> Void)?
        private var continuation: CheckedContinuation<Void, Never>?
        private var opened = false
        func send(_ request: URLRequest) async throws -> (Data, Int) {
            requests.append(request)
            if holdFirst {
                holdFirst = false
                await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                    if opened { cont.resume() } else { continuation = cont }
                    onHeld?()
                }
            }
            return try handler(request)
        }
        func resume() {
            opened = true
            continuation?.resume()
            continuation = nil
        }
    }

    @MainActor private final class Scenario {
        let source: ClubBadgeOriginalConsumerRecoveryTests.Fixture
        let wire = Wire()
        var owner = true
        var badgesStatus = 200
        var badgeRows: [[String: Any]] = [["badgeCode": "CLUB7_1", "badgeName": "Trail", "clubId": 7]]
        var memberStatus = 200
        var memberRows: [[String: Any]] = [["memberId": 42, "nickname": "Ada", "role": 0, "isOwner": false]]
        lazy var service = ClubBadgeManagementService(context: source.context, clubID: 7, transport: wire,
            current: { self.source.current }, approval: { _ in self.source.approval })
        lazy var flow = ClubBadgeManagementFlow(service: service, journal: source.journal)
        init() throws {
            source = try ClubBadgeOriginalConsumerRecoveryTests.Fixture()
            wire.handler = { [unowned self] request in
                let path = request.url?.path ?? ""
                if path.hasSuffix("api/club/detail") {
                    return (try self.source.envelope(data: ["id": 7, "isOwner": self.owner]), 200)
                }
                if path.hasSuffix("api/club/badge/list") {
                    if self.badgesStatus != 200 { return (Data(), self.badgesStatus) }
                    return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": self.badgeRows]), 200)
                }
                if path.hasSuffix("api/club/members") {
                    if self.memberStatus != 200 { return (Data(), self.memberStatus) }
                    return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": self.memberRows]), 200)
                }
                if path.hasSuffix("api/club/badge/original-receipt") {
                    return (try JSONSerialization.data(withJSONObject: ["code": 200, "data": self.unknownBody]), 200)
                }
                throw ClubBadgeManagementFailure.invalid
            }
        }
        var unknownBody: [String: Any] = ["state": "UNKNOWN"]
    }

    func testLiteralZeroStaysZeroAndMissingOrUnknownStaysEmDash() throws {
        XCTAssertEqual(ClubBadgeCountText.literal(0), "0")
        XCTAssertEqual(ClubBadgeCountText.literal(nil as Int?), ClubBadgeCountText.unknown)
        XCTAssertEqual(ClubBadgeCountText.literal(-1), ClubBadgeCountText.unknown)
        XCTAssertEqual(ClubBadgeCountText.unknown, "—")
        let unknown = try receipt(state: "UNKNOWN", badgeId: 0, memberId: 0, appliedAt: 0, auditId: 0, badgeCode: nil)
        XCTAssertEqual(unknown.badgeIDText, "—")
        XCTAssertEqual(unknown.memberIDText, "—")
        XCTAssertEqual(unknown.auditIDText, "—")
        XCTAssertEqual(unknown.appliedAtText, "—")
        XCTAssertFalse([unknown.badgeIDText, unknown.memberIDText, unknown.auditIDText, unknown.appliedAtText].contains("0"))
        let created = try receipt(state: "CREATED", badgeId: 11, memberId: nil, appliedAt: 1_800_000_000_000, auditId: 15, badgeCode: "CLUB7_1")
        XCTAssertEqual(created.badgeIDText, "11")
        XCTAssertEqual(created.appliedAtText, "1800000000000")
        XCTAssertEqual(created.auditIDText, "15")
        XCTAssertEqual(created.memberIDText, "—")
    }

    func testLoadingAndErrorCountsAreEmDashWhileEmptyIsZero() async throws {
        let loading = try Scenario()
        loading.wire.holdFirst = true
        let held = expectation(description: "first badge read is waiting")
        loading.wire.onHeld = { held.fulfill() }
        let task = Task { await loading.flow.refresh() }
        await fulfillment(of: [held], timeout: 2)
        XCTAssertEqual(loading.flow.screenState, .loading)
        XCTAssertEqual(loading.flow.badgeCountText, "—")
        XCTAssertEqual(loading.flow.memberCountText, "—")
        XCTAssertEqual(loading.flow.unconfirmedBadgeIDText, "—")
        loading.wire.resume()
        await task.value
        XCTAssertEqual(loading.flow.screenState, .ready)
        XCTAssertEqual(loading.flow.badgeCountText, "1")

        let empty = try Scenario()
        empty.badgeRows = []
        await empty.flow.refresh()
        XCTAssertEqual(empty.flow.screenState, .empty)
        XCTAssertEqual(empty.flow.badgeCountText, "0")

        let failed = try Scenario()
        failed.badgesStatus = 503
        await failed.flow.refresh()
        XCTAssertEqual(failed.flow.screenState, .error)
        XCTAssertEqual(failed.flow.badgeCountText, "—")
        XCTAssertTrue(failed.flow.badges.isEmpty)

        let hidden = try Scenario()
        hidden.source.approval = nil
        XCTAssertEqual(hidden.flow.screenState, .notAvailable)
        XCTAssertEqual(hidden.flow.badgeCountText, "—")
    }

    func testMemberPickerEmptyIsZeroAndFailureIsEmDash() async throws {
        let empty = try Scenario()
        empty.memberRows = []
        await empty.flow.refresh()
        XCTAssertEqual(empty.flow.memberCountText, "—")
        await empty.flow.openGrant(try XCTUnwrap(empty.flow.badges.first))
        XCTAssertEqual(empty.flow.memberPickerState, .empty)
        XCTAssertEqual(empty.flow.memberCountText, "0")

        let failed = try Scenario()
        await failed.flow.refresh()
        failed.memberStatus = 503
        await failed.flow.openGrant(try XCTUnwrap(failed.flow.badges.first))
        XCTAssertEqual(failed.flow.memberPickerState, .error)
        XCTAssertEqual(failed.flow.memberCountText, "—")
    }

    func testUnconfirmedOriginalResultDoesNotBecomeAZeroBadgeId() async throws {
        let s = try Scenario()
        let fields: [String: Any] = ["clubId": 7, "badgeName": "Trail"]
        let entry = try ClubBadgeManagementEntry(context: s.source.context, clubID: 7, operation: "CREATE", fields: fields)
        try s.source.journal.reserve(entry, context: s.source.context)
        s.unknownBody = [
            "protocolVersion": 1, "clubId": 7, "actorMemberId": entry.accountID,
            "requestId": entry.requestID, "operation": "CREATE", "sourceSHA256": entry.sourceSHA256,
            "state": "UNKNOWN"
        ]
        await s.flow.refresh()
        XCTAssertEqual(s.flow.resultPresentation, .unknown)
        XCTAssertEqual(s.flow.unconfirmedBadgeIDText, "—")
        XCTAssertEqual(s.flow.screenState, .ready)
        XCTAssertEqual(s.flow.badgeCountText, "1")
        XCTAssertEqual(s.flow.badges.count, 1)
    }

    func testLiveBadgeRoutesStayWiredAndReceiptStaysHidden() {
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/club/badge/list"), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/club/badge/create"), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/club/badge/grant"), .liveInProduction)
        XCTAssertEqual(ChinaReviewedRouteCapability.mark(for: "/api/club/badge/original-receipt"), .missing)
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/badge/list"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/badge/create"))
        XCTAssertTrue(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/badge/grant"))
        XCTAssertFalse(ChinaReviewedRouteCapability.admitsChinaProductionCall("/api/club/badge/original-receipt"))
    }

    func testPlayerFirstLaunchDoesNotSurfaceBadgeManagement() throws {
        let welcome = try source("App/WelcomeView.swift")
        XCTAssertTrue(welcome.contains("static let showsMerchantChoice = false"))
        XCTAssertFalse(welcome.contains("ClubBadge"))
        XCTAssertFalse(welcome.contains("paymentEnabled = true"))
        XCTAssertFalse(welcome.contains("payoutEnabled = true"))
        XCTAssertFalse(welcome.contains("withdrawalEnabled = true"))
        XCTAssertFalse(welcome.contains("virtualGoodsEnabled = true"))
        let composition = try source("App/AppCompositionRoot.swift")
        XCTAssertTrue(composition.contains("clubBadgeManagementApproval: @escaping @MainActor (RuntimeDependencyContext) -> ClubBadgeManagementApproval? = { _ in nil }"))
    }

    func testStringCatalogHasBothLanguagesAndPageIdentifiers() throws {
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: repoRoot().appendingPathComponent("docs/release/ui-strings-pages-club-badges-index.json")))
        XCTAssertEqual(catalog.page, "pages/club/badges/index")
        XCTAssertEqual(catalog.table, "ClubBadge")
        XCTAssertEqual(catalog.unknownNumber.en, "—")
        XCTAssertEqual(catalog.unknownNumber.zhHans, "—")
        XCTAssertEqual(catalog.accessibilityIdentifiers, ClubBadgePageAccessibility.catalog)
        let keys: Set<String> = [
            "title", "loading", "readError", "refresh", "unknown", "recover", "receipt.CREATED",
            "receipt.GRANTED", "receipt.ALREADY_GRANTED", "checkResult", "create", "grant", "unnamed",
            "cancel", "recipient", "confirmGrant", "name", "description", "limits", "confirmCreate",
            "storageUnavailable", "actionNeedsReview", "notSent", "historicalResult", "empty",
            "ownerOnly", "notAvailable", "membersLoading", "membersError", "membersEmpty", "retry", "ownerMark"
        ]
        XCTAssertEqual(Set(catalog.strings.keys), keys)
        for (key, pair) in catalog.strings {
            XCTAssertFalse(pair.en.isEmpty, key)
            XCTAssertFalse(pair.zhHans.isEmpty, key)
            XCTAssertFalse(pair.en.contains("http://") || pair.en.contains("https://"), key)
            XCTAssertFalse(pair.zhHans.contains("http://") || pair.zhHans.contains("https://"), key)
        }
        XCTAssertEqual(catalog.strings["title"]?.en, "Club badges")
        XCTAssertEqual(catalog.strings["title"]?.zhHans, "俱乐部徽章")
        XCTAssertEqual(catalog.strings["empty"]?.en, "No club badges yet.")
        XCTAssertEqual(catalog.strings["empty"]?.zhHans, "还没有俱乐部徽章。")
        XCTAssertEqual(catalog.accessibilityIdentifiers["entry"], "club.badges.entry")
    }

    #if DEBUG
    func testDebugFixtureDataHasNoNetworkAndUnknownIsEmDash() throws {
        let ready = try ClubBadgeManagementFixtureData.readyList()
        let records = try ClubBadgeManagementFixtureData.records(from: ready)
        XCTAssertEqual(records.map(\.badgeCode), [ClubBadgeManagementFixtureData.badgeCode])
        XCTAssertEqual(try ClubBadgeManagementFixtureData.records(from: ClubBadgeManagementFixtureData.emptyList()).count, 0)
        let error = try JSONSerialization.jsonObject(with: ClubBadgeManagementFixtureData.errorEnvelope()) as? [String: Any]
        XCTAssertEqual(error?["code"] as? Int, 500)
        let receipt = try JSONDecoder().decode(ClubBadgeOriginalReceipt.self, from: ClubBadgeManagementFixtureData.unknownReceipt(actorMemberId: 7))
        XCTAssertEqual(receipt.state, "UNKNOWN")
        XCTAssertNil(receipt.badgeId)
        XCTAssertEqual(receipt.badgeIDText, "—")
        XCTAssertEqual(receipt.memberIDText, "—")
        XCTAssertEqual(receipt.auditIDText, "—")
        XCTAssertEqual(receipt.appliedAtText, "—")
        let blob = [ready, try ClubBadgeManagementFixtureData.emptyList(), try ClubBadgeManagementFixtureData.errorEnvelope(), try ClubBadgeManagementFixtureData.unknownReceipt(actorMemberId: 7)]
            .compactMap { String(data: $0, encoding: .utf8) }.joined()
        for forbidden in ["http://", "https://", "token", "secret", "showsMerchantChoice", "paymentEnabled", "payoutEnabled", "withdrawalEnabled", "virtualGoodsEnabled"] {
            XCTAssertFalse(blob.localizedCaseInsensitiveContains(forbidden), forbidden)
        }
    }
    #endif

    private func receipt(state: String, badgeId: Int?, memberId: Int?, appliedAt: Int64?, auditId: Int?, badgeCode: String?) throws -> ClubBadgeOriginalReceipt {
        var fields: [String: Any] = [
            "protocolVersion": 1, "clubId": 7, "actorMemberId": 7,
            "requestId": "11111111-1111-4111-8111-111111111111", "operation": "CREATE",
            "sourceSHA256": String(repeating: "ab", count: 32), "state": state
        ]
        fields["badgeId"] = badgeId.map { $0 as Any } ?? NSNull()
        fields["memberId"] = memberId.map { $0 as Any } ?? NSNull()
        fields["appliedAt"] = appliedAt.map { $0 as Any } ?? NSNull()
        fields["auditId"] = auditId.map { $0 as Any } ?? NSNull()
        fields["badgeCode"] = badgeCode.map { $0 as Any } ?? NSNull()
        return try JSONDecoder().decode(ClubBadgeOriginalReceipt.self, from: JSONSerialization.data(withJSONObject: fields))
    }

    private func source(_ relative: String) throws -> String {
        try String(contentsOf: repoRoot().appendingPathComponent(relative), encoding: .utf8)
    }

    private func repoRoot() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }
}

private struct Catalog: Decodable {
    struct Pair: Decodable {
        let en: String
        let zhHans: String
        enum CodingKeys: String, CodingKey { case en; case zhHans = "zh-Hans" }
    }
    let page: String
    let table: String
    let unknownNumber: Pair
    let strings: [String: Pair]
    let accessibilityIdentifiers: [String: String]
}
#endif
