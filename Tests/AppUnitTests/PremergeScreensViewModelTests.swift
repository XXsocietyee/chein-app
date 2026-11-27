import XCTest
import SwiftUI
@testable import Questify
#if canImport(QuestifyCore)
@testable import QuestifyCore
#endif

private final class PremergeTestVault: AppTokenStorage {
    var value: String?
    func read() throws -> String? { value }
    func write(_ token: String) throws { value = token }
    func clear() throws { value = nil }
}

@MainActor
private final class PremergeSessionTransport: HTTPTransport {
    var requests: [URLRequest] = []
    var handlers: [String: (Data, Int)] = [:]

    func send(_ request: URLRequest) async throws -> (Data, Int) {
        requests.append(request)
        let path = request.url?.path ?? ""
        if let override = handlers[path] {
            return override
        }
        let last = request.url?.lastPathComponent ?? ""
        if last == "phone" {
            return (Data(#"{"code":200,"token":"synthetic-premerge-77","data":{"id":77,"role":"player"}}"#.utf8), 200)
        }
        if last == "userInfo" {
            return (Data(#"{"code":200,"appUser":{"id":77,"role":"player"}}"#.utf8), 200)
        }
        return (Data(#"{"code":200,"data":[]}"#.utf8), 200)
    }
}

@MainActor
private final class StubHostCancelAccess: ActivityHostCancelAccess {
    var enabled: Bool = true
    var accountID: Int? = 77
    var previewHandler: (Int) async throws -> ActivityHostCancelPreview = { _ in .paidPlayers(3) }
    var cancelHandler: (Int, String) async throws -> ActivityHostCancelOutcome = { _, _ in .cancelled("已取消活动") }

    func preview(activityID: Int) async throws -> ActivityHostCancelPreview {
        try await previewHandler(activityID)
    }

    func cancel(activityID: Int, reason: String) async throws -> ActivityHostCancelOutcome {
        try await cancelHandler(activityID, reason)
    }
}

@MainActor
final class PremergeScreensViewModelTests: XCTestCase {
    private func makeStorage(vault: PremergeTestVault) -> AppScopedStorageFactory {
        let suite = "premerge-unit-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
        return .init(defaults: defaults, tokenStore: { _ in vault })
    }

    private func makeDeployment() throws -> ReviewedAppDeployment {
        try .init(
            market: .china,
            baseURL: "https://example.test/native",
            approvedBaseURLs: [.china: ["https://example.test/native"]],
            verifiedCapabilities: [.domesticChinaPhone],
            bundleIdentifier: "test.questify.premerge",
            realm: "premerge-tests",
            reads: [.homeAndSearch]
        )
    }

    // MARK: - AppSession+MemberPopups & DeepLinkDirtyTracker

    func testDeepLinkDirtyTrackerAndMemberPopupEnvironmentDefaults() async {
        let tracker = DeepLinkDirtyTracker()
        XCTAssertFalse(tracker.isDirty)
        tracker.isDirty = true
        XCTAssertTrue(tracker.isDirty)

        var values = EnvironmentValues()
        XCTAssertNil(values.deepLinkDirtyTracker)
        values.deepLinkDirtyTracker = tracker
        XCTAssertTrue(values.deepLinkDirtyTracker === tracker)

        XCTAssertNil(values.memberPopupActions.disablePresence)
        XCTAssertNil(values.memberPopupActions.loadOwnedClubs)

        values.memberPopupActions = MemberPopupEnvironmentActions(
            disablePresence: { .disabled },
            loadOwnedClubs: { .failed(message: "测试失败") }
        )
        let customDisable = await values.memberPopupActions.disablePresence?()
        let customClubs = await values.memberPopupActions.loadOwnedClubs?()
        XCTAssertEqual(customDisable, .disabled)
        XCTAssertEqual(customClubs, .failed(message: "测试失败"))
    }

    func testAppSessionMemberPopupClosuresSignedOutAndSignedIn() async throws {
        let transport = PremergeSessionTransport()
        let vault = PremergeTestVault()
        let root = AppCompositionRoot(
            deployment: .reviewed(try makeDeployment()),
            storage: makeStorage(vault: vault),
            makeTransport: { transport },
            sessionDependencies: { _ in .dormant }
        )
        let session = root.makeSession()

        // Signed-out session fails closed / falls back to host onboarding.
        let unauthDisable = await session.disableRoamPresenceVisibility()
        let unauthClub = await session.loadSettingsClubEntry()
        XCTAssertEqual(unauthDisable, .unavailable)
        XCTAssertEqual(unauthClub, .applyForHost)

        // Sign in and verify memberPopupActions forwards server outcomes.
        await session.authChannels.loginWithPhone(phone: "10000000000", code: "123456")
        XCTAssertNotNil(session.account)

        transport.handlers["/native/api/roam/presence-visibility"] = (Data(#"{"code":200,"data":false}"#.utf8), 200)
        // debt/appunit-b: expectation updated per 02c68098f (`ClubService.owned` decodes the MP `/api/club/my` shape
        // `data.owned`, as mp-source pages/shezhi/shezhi.js:123 reads it; a bare `data` array is malformed).
        transport.handlers["/native/api/club/my"] = (
            Data(#"{"code":200,"data":{"owned":[{"id":12,"name":"杭州城南探索社"}]}}"#.utf8),
            200
        )

        let actions = session.memberPopupActions()
        let disableOutcome = await actions.disablePresence?()
        XCTAssertEqual(disableOutcome, .disabled)

        let clubOutcome = await actions.loadOwnedClubs?()
        if case .openClub(let club)? = clubOutcome {
            XCTAssertEqual(club.id, 12)
            XCTAssertEqual(club.name, "杭州城南探索社")
        } else {
            XCTFail("Expected .openClub, got \(String(describing: clubOutcome))")
        }
    }

    // MARK: - ActivityPublishingStatusHelper

    func testActivityPublishingStatusHelperFlagsMissingStepsAndClearsWhenValid() throws {
        let zhLocale = Locale(identifier: "zh-Hans")
        let emptyIssues = ActivityPublishingStatusHelper.issues(for: ActivityPublishDraft(), locale: zhLocale)
        XCTAssertFalse(emptyIssues.isEmpty)
        XCTAssertEqual(Set(emptyIssues.map(\.stepIndex)), Set(0..<ActivityPublishingWizard.steps.count))

        var ticket = ActivityPublishTicket()
        ticket.name = "单人早鸟票"
        ticket.price = "68.00"
        ticket.stock = "30"
        ticket.start = "2026-11-20 10:00:00"
        ticket.end = "2026-11-20 18:00:00"

        var validDraft = ActivityPublishDraft()
        validDraft.name = "南宋御街夜游探索"
        validDraft.description = "沿清河坊历史街区开展城市实景解谜体验。"
        validDraft.coverURL = "https://example.test/cover.png"
        validDraft.place = try PublishingPlace(
            id: "place-1",
            name: "鼓楼广场",
            address: "杭州市上城区中山南路",
            latitude: 30.241,
            longitude: 120.168
        )
        validDraft.addressName = "鼓楼广场"
        validDraft.start = "2026-11-20 10:00:00"
        validDraft.end = "2026-11-20 18:00:00"
        validDraft.playTemplateID = AuthoringPlayTemplateID(rawValue: 9)
        validDraft.categoryIDs = [1]
        validDraft.tickets = [ticket]

        let validIssues = ActivityPublishingStatusHelper.issues(for: validDraft, locale: zhLocale)
        XCTAssertTrue(validIssues.isEmpty, "Unexpected validation issues: \(validIssues)")
    }

    // MARK: - PlayTaskStatusCardMapper

    func testPlayTaskStatusCardMapperStatesAndRouteCompletion() throws {
        let json = """
        {
          "topicId": 88,
          "topicName": "西湖夜游路线",
          "mode": 1,
          "playable": true,
          "registered": true,
          "total": 4,
          "doneCount": 1,
          "nodes": [
            {"nodeId": 1, "name": "断桥残雪", "done": true},
            {"nodeId": 2, "name": "白堤", "done": false, "needAnswer": true},
            {"nodeId": 3, "name": "平湖秋月", "done": false, "needGps": true, "arrived": true},
            {"nodeId": 4, "name": "苏堤", "done": false, "locked": true, "unlockAfterNodeId": 2, "lockReason": "需先完成白堤"}
          ],
          "chapters": []
        }
        """
        let result = try JSONDecoder().decode(PlayNodesResult.self, from: Data(json.utf8))
        let snapshot = try PlaySnapshot(scope: .topic(88), result: result)
        var currentSession: PlayExperienceSession? = try PlayExperienceSession(accountID: 77, epoch: 1, namespace: "premerge", token: "valid-premerge-token")
        let config = try APIConfiguration(baseURL: URL(string: "https://example.test/native")!)
        let service = PlayExperienceService(configuration: config, transport: PremergeSessionTransport(), enabled: [.reads])
        let coordinator = PlayExperienceCoordinator(
            scope: .topic(88),
            service: service,
            recovery: PlayMemoryCompletionRecovery(),
            pausedStorage: PlayMemoryPausedStorage(),
            currentSession: { currentSession }
        )
        let zh = Locale(identifier: "zh-Hans")

        // Route completion mapping
        XCTAssertEqual(PlayTaskStatusCardMapper.routeCompletion(for: result.nodes[0], in: snapshot, currentNodeID: 2), .completed)
        XCTAssertEqual(PlayTaskStatusCardMapper.routeCompletion(for: result.nodes[1], in: snapshot, currentNodeID: 2), .current)
        XCTAssertEqual(PlayTaskStatusCardMapper.routeCompletion(for: result.nodes[2], in: snapshot, currentNodeID: 2), .upcoming)
        XCTAssertEqual(PlayTaskStatusCardMapper.routeCompletion(for: result.nodes[3], in: snapshot, currentNodeID: 2), .locked)

        // State mapping: done node
        let doneState = PlayTaskStatusCardMapper.state(
            node: result.nodes[0], snapshot: snapshot, model: coordinator, locale: zh, ctaTitle: "开始打卡", onOpen: {}, onRefresh: {}
        )
        if case .completed(let receiptNo, let completedAt, _) = doneState {
            XCTAssertEqual(receiptNo, "DONE-1")
            XCTAssertEqual(completedAt, "已完成")
        } else {
            XCTFail("Expected .completed for done node")
        }

        // State mapping: available puzzle node
        let openState = PlayTaskStatusCardMapper.state(
            node: result.nodes[1], snapshot: snapshot, model: coordinator, locale: zh, ctaTitle: "开始打卡", onOpen: {}, onRefresh: {}
        )
        if case .available(let methodLabel, let ctaTitle, _) = openState {
            XCTAssertEqual(methodLabel, "线索解谜")
            XCTAssertEqual(ctaTitle, "开始打卡")
        } else {
            XCTFail("Expected .available for open node")
        }

        // State mapping: arrived task node
        let arrivedState = PlayTaskStatusCardMapper.state(
            node: result.nodes[2], snapshot: snapshot, model: coordinator, locale: zh, ctaTitle: "开始打卡", onOpen: {}, onRefresh: {}
        )
        if case .available(let methodLabel, _, _) = arrivedState {
            XCTAssertEqual(methodLabel, "现场任务 · 已到达")
        } else {
            XCTFail("Expected .available for arrived node")
        }

        // State mapping: locked node resolves prerequisite title
        let lockedState = PlayTaskStatusCardMapper.state(
            node: result.nodes[3], snapshot: snapshot, model: coordinator, locale: zh, ctaTitle: "开始打卡", onOpen: {}, onRefresh: {}
        )
        if case .locked(let requirement, let prereqTitle, _) = lockedState {
            XCTAssertEqual(requirement, "需先完成白堤")
            XCTAssertEqual(prereqTitle, "白堤")
        } else {
            XCTFail("Expected .locked for locked node")
        }
        _ = currentSession
        currentSession = nil
    }

    // MARK: - PageTemplateVoiceOver, Popup Copy & TeamPoolHintSection

    func testPageTemplateVoiceOverAndPopupCopyHelpers() throws {
        XCTAssertEqual(PageTemplateVoiceOver.dash, "\u{2014}")
        let zh = Locale(identifier: "zh-Hans")
        let en = Locale(identifier: "en")
        XCTAssertEqual(PageTemplateVoiceOver.spoken("—", locale: zh), Text("curA11y.unknown", tableName: "CurA11y"))
        XCTAssertNotEqual(PageTemplateVoiceOver.spoken("42", locale: zh), PageTemplateVoiceOver.spoken("—", locale: zh))
        XCTAssertEqual(PageTemplateVoiceOver.spoken("42", locale: en), Text(verbatim: "42"))

        // Money closed returns em-dash when positive flag is true under disabled switch.
        XCTAssertEqual(PlayAreaPopupCopy.moneyText(nil, positive: true), "—")
        XCTAssertEqual(PlayAreaPopupCopy.text("取消", "Cancel", locale: zh), "取消")
        XCTAssertEqual(PlayAreaPopupCopy.text("取消", "Cancel", locale: en), "Cancel")

        XCTAssertEqual(MerchantAreaCopy.cancel(zh), "取消")
        XCTAssertEqual(MerchantAreaCopy.confirm(en), "Confirm")
        XCTAssertEqual(MerchantAreaCopy.gotIt(zh), "知道了")
        XCTAssertEqual(CoopReviewScore.allCases.count, 5)
        XCTAssertEqual(CoopReviewScore.five.scoreValue, 5)
        XCTAssertEqual(CoopReviewScore.one.option(locale: zh).isDestructive, true)

        XCTAssertEqual(MemberPopupCopy.text("关闭", "Close", locale: zh), "关闭")
        XCTAssertEqual(MemberPopupCopy.text("关闭", "Close", locale: en), "Close")

        let unknownPool = try JSONDecoder().decode(
            TeamPoolSnapshot.self,
            from: Data(#"{"teamId":1,"enabled":true,"teamScore":null}"#.utf8)
        )
        let knownZeroPool = try JSONDecoder().decode(
            TeamPoolSnapshot.self,
            from: Data(#"{"teamId":1,"enabled":true,"teamScore":0}"#.utf8)
        )
        XCTAssertEqual(TeamPoolHintSection.scoreText(unknownPool), "—")
        XCTAssertEqual(TeamPoolHintSection.scoreText(knownZeroPool), "0")
        XCTAssertEqual(TeamPoolHintSection.formatDuration(-3), "00:00")
        XCTAssertEqual(TeamPoolHintSection.formatDuration(125), "02:05")
    }

    // MARK: - ActivityHostCancelModel

    func testActivityHostCancelModelTransitions() async {
        let access = StubHostCancelAccess()
        let model = ActivityHostCancelModel(activityID: 101, access: access)

        await model.loadPreview()
        XCTAssertEqual(model.phase, .ready(paidPlayers: 3))
        XCTAssertEqual(model.paidPlayers, 3)
        XCTAssertFalse(model.canSubmit)

        model.reason = "天气原因延期改期"
        XCTAssertTrue(model.canSubmit)

        access.cancelHandler = { _, _ in .rejected(" ") }
        let rejectedOK = await model.submit()
        XCTAssertFalse(rejectedOK)
        XCTAssertEqual(model.submitError, "取消失败")

        access.cancelHandler = { _, _ in .cancelled("已退回全部报名费") }
        let cancelledOK = await model.submit()
        XCTAssertTrue(cancelledOK)
        XCTAssertEqual(model.phase, .cancelled("已退回全部报名费"))

        access.previewHandler = { _ in .unknownCount }
        await model.loadPreview()
        XCTAssertEqual(model.phase, .unknownCount)
        XCTAssertNil(model.paidPlayers)
        XCTAssertFalse(model.canSubmit)

        access.previewHandler = { _ in throw URLError(.cannotConnectToHost) }
        await model.loadPreview()
        XCTAssertEqual(model.phase, .networkError)
    }
}
