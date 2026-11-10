import XCTest
@testable import QuestifyCore

/// w2-20: mini-program im/list `tabOf`, badge counts, `fmtTime` and chat `fmtAbs`.
final class IMInboxTests: XCTestCase {
    private func rows(_ values: [[String: Any]]) throws -> [MessagingConversation] {
        try JSONDecoder().decode([MessagingConversation].self, from: JSONSerialization.data(withJSONObject: values))
    }
    private func china(_ text: String) throws -> Date { try XCTUnwrap(IMInboxTime.parse(text)) }

    func testTabsFollowSourceTypeMappingAndKeepGroupsNativeOnly() throws {
        let list = try rows([
            ["conversationId": 1, "type": 1], ["conversationId": 2, "type": 2], ["conversationId": 3, "type": 3],
            ["conversationId": 4, "type": 4], ["conversationId": 5], ["conversationId": 6, "type": 9]
        ])
        let summary = IMInboxSummary(conversations: list)
        XCTAssertEqual(summary.rows(for: .direct).map(\.id), [1, 3, 5, 6])
        XCTAssertEqual(summary.rows(for: .system).map(\.id), [2])
        XCTAssertEqual(summary.rows(for: .group).map(\.id), [4])
        XCTAssertEqual(summary.visibleTabs, [.direct, .system, .group])
        XCTAssertEqual(summary.initialTab, .direct)
    }
    func testGroupTabOnlyAppearsWithGroupRows() throws {
        XCTAssertEqual(IMInboxSummary(conversations: []).visibleTabs, [.direct, .system])
        XCTAssertEqual(IMInboxSummary(conversations: []).initialTab, .direct)
        let groups = IMInboxSummary(conversations: try rows([["conversationId": 4, "type": 4]]))
        XCTAssertEqual(groups.initialTab, .group)
    }
    func testBadgesExcludeMutedRowsLikeTheGlobalRedDot() throws {
        let summary = IMInboxSummary(conversations: try rows([
            ["conversationId": 1, "type": 1, "unread": 3, "muted": 0],
            ["conversationId": 2, "type": 1, "unread": 5, "muted": 1],
            ["conversationId": 3, "type": 3, "unread": 2],
            ["conversationId": 4, "type": 2, "unread": 7, "muted": "1"],
            ["conversationId": 5, "type": 2, "unread": 1, "muted": "maybe"]
        ]))
        XCTAssertEqual(summary.badge(for: .direct), 5)
        XCTAssertEqual(summary.badge(for: .system), 1, "unknown muted is not treated as muted")
        XCTAssertTrue(summary.hasUnread)
        XCTAssertFalse(IMInboxSummary(conversations: try rows([["conversationId": 1, "unread": 0]])).hasUnread)
    }
    func testBadgeTextCapsAtNinetyNinePlus() {
        XCTAssertNil(IMInboxSummary.badgeText(nil)); XCTAssertNil(IMInboxSummary.badgeText(0))
        XCTAssertEqual(IMInboxSummary.badgeText(7), "7"); XCTAssertEqual(IMInboxSummary.badgeText(99), "99")
        XCTAssertEqual(IMInboxSummary.badgeText(100), "99+")
    }
    func testWallClockStringsAreAnchoredToChinaTime() throws {
        let date = try china("2026-10-19 08:30:00")
        XCTAssertEqual(date, Date(timeIntervalSince1970: 1_792_369_800))
        XCTAssertEqual(try china("2026-10-19T08:30:00.123"), date.addingTimeInterval(0))
        XCTAssertEqual(IMInboxTime.parse("2026-10-19T00:30:00Z"), date)
        XCTAssertEqual(IMInboxTime.parse("1792369800"), date)
        XCTAssertNil(IMInboxTime.parse("2026-02-30 10:00:00"))
        XCTAssertNil(IMInboxTime.parse("yesterday"))
        XCTAssertNil(IMInboxTime.parse(nil))
    }
    func testListTimeTextMatchesSourceBuckets() throws {
        let now = try china("2026-10-19 12:00:00") // Monday
        XCTAssertEqual(IMInboxTime.listText("2026-10-19 11:59:30", now: now), .justNow)
        XCTAssertEqual(IMInboxTime.listText("2026-10-19 11:15:00", now: now), .minutesAgo(45))
        XCTAssertEqual(IMInboxTime.listText("2026-10-19 08:05:00", now: now), .clock("08:05"))
        XCTAssertEqual(IMInboxTime.listText("2026-10-18 23:00:00", now: now), .yesterday)
        XCTAssertEqual(IMInboxTime.listText("2026-10-15 09:00:00", now: now), .weekday(4))
        XCTAssertEqual(IMInboxTime.listText("2026-09-01 09:00:00", now: now), .monthDay(month: 9, day: 1))
        XCTAssertNil(IMInboxTime.listText("", now: now))
    }
    func testChatDividersFollowFiveMinuteGaps() throws {
        let now = try china("2026-10-19 12:00:00")
        let page = try JSONDecoder().decode(MessagingPage.self, from: Data(#"""
        {"list":[
          {"id":1,"conversationId":9,"status":0,"createTime":"2026-10-18 21:00:00"},
          {"id":2,"conversationId":9,"status":0,"createTime":"2026-10-18 21:04:00"},
          {"id":3,"conversationId":9,"status":0},
          {"id":4,"conversationId":9,"status":0,"createTime":"2026-10-18 21:10:00"},
          {"id":5,"conversationId":9,"status":0,"createTime":"2026-10-19 09:01:00"},
          {"id":6,"conversationId":9,"status":0,"createTime":"2026-10-01 09:01:00"}
        ],"hasMore":false}
        """#.utf8))
        let dividers = IMInboxTime.dividers(for: page.messages, now: now)
        XCTAssertEqual(dividers[1], .yesterday(clock: "21:00"))
        XCTAssertNil(dividers[2]); XCTAssertNil(dividers[3])
        XCTAssertEqual(dividers[4], .yesterday(clock: "21:10"))
        XCTAssertEqual(dividers[5], .today(clock: "09:01"))
        XCTAssertNil(dividers[6], "an older out-of-order stamp is not more than five minutes after its predecessor")
    }
    func testMessagesPageDecodesOnlyLiteralBlockFlags() throws {
        func page(_ extra: String) throws -> MessagingPage {
            try JSONDecoder().decode(MessagingPage.self, from: Data(#"{"list":[],"hasMore":false\#(extra)}"#.utf8))
        }
        let blocked = try page(#","blocked":true,"blockedByMe":false"#)
        XCTAssertEqual(blocked.blocked, true); XCTAssertEqual(blocked.blockedByMe, false)
        let absent = try page("")
        XCTAssertNil(absent.blocked); XCTAssertNil(absent.blockedByMe)
        XCTAssertNil(try page(#","blocked":"yes""#).blocked)
    }
    func testPreviewPolicySilentRefreshAndReadReceiptTriggerPolicy() throws {
        let conversation = try XCTUnwrap(rows([
            ["conversationId": 11, "type": 1, "lastMsgText": "  周末集合点确认  "]
        ]).first)
        XCTAssertEqual(IMConversationPreviewPolicy.defaultPolicy, .redactedPlaceholder)
        XCTAssertEqual(IMConversationPreviewPolicy.resolve(for: conversation), "打开会话查看消息")
        XCTAssertNil(conversation.lastMessageText)
        XCTAssertEqual(
            IMConversationPreviewPolicy.resolve(for: conversation, policy: .serverPreviewWhenUnrecalled),
            "打开会话查看消息"
        )
        XCTAssertEqual(
            IMConversationPreviewPolicy.serverPreviewWhenUnrecalled.previewText(serverPreview: "  周末集合点确认  "),
            "周末集合点确认"
        )
        XCTAssertEqual(
            IMConversationPreviewPolicy.resolve(for: conversation, policy: .serverPreviewWhenUnrecalled, isRecalled: true),
            "打开会话查看消息"
        )
        XCTAssertEqual(
            IMConversationPreviewPolicy.serverPreviewWhenUnrecalled.previewText(serverPreview: "   "),
            "打开会话查看消息"
        )

        let refreshing = IMSilentRefreshPresentation(isRefreshingWithSnapshot: true)
        XCTAssertEqual(refreshing.statusText, "正在刷新消息")
        let idle = IMSilentRefreshPresentation(isLoading: false, hasSnapshot: true)
        XCTAssertFalse(idle.isRefreshingWithSnapshot)
        XCTAssertNil(idle.statusText)

        XCTAssertEqual(IMReadReceiptTriggerPolicy.defaultPolicy, .explicitUserActionOnly)
        XCTAssertFalse(IMReadReceiptTriggerPolicy.explicitUserActionOnly.shouldAutoMarkRead)
        XCTAssertFalse(IMReadReceiptTriggerPolicy.autoOnLoadWhenGranted(imReadGranted: false).shouldAutoMarkRead)
        XCTAssertTrue(IMReadReceiptTriggerPolicy.autoOnLoadWhenGranted(imReadGranted: true).shouldAutoMarkRead)
        XCTAssertTrue(IMReadReceiptTriggerPolicy.autoOnLoadWhenGranted(imReadGranted: true).shouldAutoMarkRead(unreadCount: 2))
        XCTAssertFalse(IMReadReceiptTriggerPolicy.autoOnLoadWhenGranted(imReadGranted: true).shouldAutoMarkRead(unreadCount: 0))
    }
}

/// CB229: message-center list phases. Unknown counts stay an em dash.
final class IMListPageReadyTests: XCTestCase {
    private func rows(_ values: [[String: Any]]) throws -> [MessagingConversation] {
        try JSONDecoder().decode([MessagingConversation].self, from: JSONSerialization.data(withJSONObject: values))
    }

    func testConversationKindsStayTheExistingContract() {
        XCTAssertEqual(MessagingConversationKind(rawValue: 1), .direct)
        XCTAssertEqual(MessagingConversationKind(rawValue: 2), .system)
        XCTAssertEqual(MessagingConversationKind(rawValue: 3), .merchant)
        XCTAssertEqual(MessagingConversationKind(rawValue: 4), .group)
        XCTAssertEqual(MessagingConversationKind(rawValue: nil), .unknown)
        XCTAssertEqual(MessagingConversationKind(rawValue: 0), .unknown)
        XCTAssertEqual(MessagingConversationKind(rawValue: 5), .unknown)
        XCTAssertEqual(MessagingConversationKind(rawValue: 99), .unknown)
        XCTAssertEqual(MessagingConversationKind(rawValue: -1), .unknown)
    }

    func testUnknownUnreadIsAnEmDashAndLiteralZeroStaysZero() throws {
        XCTAssertEqual(IMListPageReady.unknownMark, "—")
        XCTAssertEqual(IMListPageReady.conversationsPath, "api/im/conversations")
        XCTAssertFalse(IMListPageReady.conversationsPath.contains("http"))
        XCTAssertNil(IMListPageReady.rowUnreadBadge(0))
        XCTAssertEqual(IMListPageReady.rowUnreadExact(0), "0")
        XCTAssertEqual(IMListPageReady.rowUnreadExact(nil), "—")
        XCTAssertEqual(IMListPageReady.rowUnreadBadge(nil), "—")
        XCTAssertNotEqual(IMListPageReady.rowUnreadExact(nil), "0")
        XCTAssertEqual(IMListPageReady.rowUnreadBadge(100), "99+")

        let mixed = try rows([
            ["conversationId": 1, "type": 1, "unread": 3, "muted": 0],
            ["conversationId": 2, "type": 1, "muted": 0],
            ["conversationId": 3, "type": 2, "unread": 1, "muted": 0]
        ])
        guard case .ready(let snapshot) = IMListPageReady.project(mixed) else {
            return XCTFail("expected a ready list")
        }
        XCTAssertEqual(snapshot.rows.map(\.kind), [.direct, .direct, .system])
        XCTAssertEqual(snapshot.directUnread, "—")
        XCTAssertEqual(snapshot.systemUnread, "1")
        XCTAssertNotEqual(snapshot.directUnread, "3")
        XCTAssertNotEqual(snapshot.directUnread, "0")
        XCTAssertEqual(IMListPageReady.countText(for: .ready(snapshot)), "3")
        XCTAssertFalse(snapshot.showsReadAll)
        XCTAssertFalse(snapshot.showsSquare)
        XCTAssertFalse(snapshot.showsCoopInviteStrip)
        XCTAssertFalse(snapshot.showsGroupTab)
        let onlyUnknown = try rows([["conversationId": 8, "type": 1, "muted": 0]])
        guard case .ready(let unknownOnly) = IMListPageReady.project(onlyUnknown, grants: .init(readAll: true)) else {
            return XCTFail("expected a ready list")
        }
        XCTAssertEqual(unknownOnly.directUnread, "—")
        XCTAssertFalse(unknownOnly.showsReadAll)
        guard case .ready(let granted) = IMListPageReady.project(mixed, grants: .init(readAll: true, square: true, coopInviteStrip: true)) else {
            return XCTFail("expected a ready list")
        }
        XCTAssertTrue(granted.showsReadAll)
        XCTAssertFalse(granted.showsSquare)
        XCTAssertTrue(granted.showsCoopInviteStrip)
        XCTAssertEqual(granted.directUnread, "—")

        let hidden = IMListPageReady.project([])
        guard case .empty(let state) = hidden else { return XCTFail("expected empty") }
        XCTAssertFalse(state.showsSquare)
        XCTAssertFalse(state.showsCoopInviteStrip)
        XCTAssertEqual(IMListPageReady.countText(for: hidden), "0")
        XCTAssertEqual(IMListPageReady.unreadText(for: hidden, tab: .direct), "0")
        guard case .empty(let open) = IMListPageReady.project([], grants: .init(square: true, coopInviteStrip: true)) else {
            return XCTFail("expected empty")
        }
        XCTAssertTrue(open.showsSquare)
        XCTAssertTrue(open.showsCoopInviteStrip)
    }

    func testMutedUnknownUnreadDoesNotPoisonAKnownTotal() throws {
        let rows = try rows([
            ["conversationId": 1, "type": 1, "unread": 3, "muted": 0],
            ["conversationId": 2, "type": 1, "muted": 1],
            ["conversationId": 4, "type": 4, "muted": 1]
        ])
        guard case .ready(let snapshot) = IMListPageReady.project(rows, grants: .init(readAll: true)) else {
            return XCTFail("expected a ready list")
        }
        XCTAssertEqual(snapshot.directUnread, "3")
        XCTAssertEqual(snapshot.groupUnread, "0")
        XCTAssertTrue(snapshot.showsGroupTab)
        XCTAssertEqual(snapshot.visibleTabs, [.direct, .system, .group])
        XCTAssertTrue(snapshot.showsReadAll)
        XCTAssertFalse(snapshot.showsSquare)
        XCTAssertEqual(snapshot.rows.map(\.kind), [.direct, .direct, .group])
    }

#if DEBUG
    func testFixtureDataKeepsExistingKindsAndUnknownUnread() throws {
        let rows = try IMListFixtureData.conversations(IMListFixtureData.list)
        XCTAssertEqual(rows.map(\.kind), [.direct, .system, .merchant, .group, .unknown, .direct])
        XCTAssertEqual(rows.map(\.type), [1, 2, 3, 4, 9, 1] as [Int?])
        guard case .ready(let snapshot) = IMListPageReady.project(rows, grants: .init(square: true)) else {
            return XCTFail("expected a ready list")
        }
        XCTAssertEqual(snapshot.rows[3].kind, .group)
        XCTAssertEqual(snapshot.rows[4].kind, .unknown)
        XCTAssertEqual(snapshot.rows[4].tab, .direct)
        XCTAssertEqual(snapshot.rows[5].unreadExact, "—")
        XCTAssertNotEqual(snapshot.rows[5].unreadExact, "0")
        XCTAssertEqual(snapshot.directUnread, "—")
        XCTAssertFalse(snapshot.showsSquare)
        XCTAssertFalse(snapshot.showsCoopInviteStrip)
        XCTAssertFalse(snapshot.showsReadAll)
        XCTAssertEqual(try IMListFixtureData.conversations(IMListFixtureData.empty), [])
    }
#endif

    func testLoadingErrorAndUnknownDoNotGuessZero() {
        XCTAssertEqual(IMListPageCoordinator().phase, .loading)
        for phase in [IMListPageReady.Phase.loading, .error, .unknown] {
            XCTAssertEqual(IMListPageReady.countText(for: phase), "—")
            XCTAssertEqual(IMListPageReady.unreadText(for: phase, tab: .system), "—")
            XCTAssertNotEqual(IMListPageReady.countText(for: phase), "0")
        }
    }
}

@MainActor final class IMListPageReadyLoadTests: XCTestCase {
    private final class Reader: MessagingReading {
        var isConfigured = true
        var identity: MessagingReadIdentity? = .init(accountID: 7, epoch: 1)
        var fail: Error?
        var reads = 0
        var payload: [[String: Any]] = [["conversationId": 1, "type": 1, "unread": 2, "muted": 0]]
        func messagingConversations() async throws -> [MessagingConversation] {
            reads += 1
            if let fail { throw fail }
            return try JSONDecoder().decode([MessagingConversation].self, from: JSONSerialization.data(withJSONObject: payload))
        }
        func messagingMessages(conversationID: Int, cursor: Int) async throws -> MessagingPage {
            throw APIError.notConfigured
        }
    }

    func testReloadUsesTheConversationsReadAndHidesAMissingReader() async {
        let reader = Reader()
        var coordinator = IMListPageCoordinator()
        await coordinator.reload(using: reader)
        guard case .ready(let snapshot) = coordinator.phase else { return XCTFail("expected ready") }
        XCTAssertEqual(reader.reads, 1)
        XCTAssertEqual(snapshot.rows.map(\.id), [1])
        XCTAssertEqual(snapshot.directUnread, "2")
        XCTAssertFalse(snapshot.showsReadAll)

        reader.isConfigured = false
        await coordinator.reload(using: reader)
        guard case .ready = coordinator.phase else { return XCTFail("a later gap keeps the snapshot") }
        XCTAssertEqual(reader.reads, 1)

        var fresh = IMListPageCoordinator()
        await fresh.reload(using: reader)
        XCTAssertEqual(fresh.phase, .unknown)
        XCTAssertEqual(IMListPageReady.countText(for: fresh.phase), "—")
        XCTAssertEqual(reader.reads, 1)

        let signedOut = Reader()
        signedOut.identity = nil
        var hidden = IMListPageCoordinator()
        await hidden.reload(using: signedOut)
        XCTAssertEqual(hidden.phase, .unknown)
        XCTAssertEqual(signedOut.reads, 0)
        XCTAssertEqual(IMListPageReady.unreadText(for: hidden.phase, tab: .direct), "—")
    }

    func testFailureAndCancellationDoNotBecomeAnEmptyList() async {
        let reader = Reader()
        reader.fail = APIError.unauthorized
        var coordinator = IMListPageCoordinator()
        await coordinator.reload(using: reader)
        XCTAssertEqual(coordinator.phase, .error)
        XCTAssertNotEqual(IMListPageReady.countText(for: coordinator.phase), "0")

        reader.fail = nil
        await coordinator.reload(using: reader)
        guard case .ready = coordinator.phase else { return XCTFail("expected ready") }
        reader.fail = CancellationError()
        await coordinator.reload(using: reader)
        guard case .ready = coordinator.phase else { return XCTFail("cancellation keeps the snapshot") }

        var cancelled = IMListPageCoordinator()
        await cancelled.reload(using: reader)
        XCTAssertEqual(cancelled.phase, .unknown)
        XCTAssertEqual(IMListPageReady.unreadText(for: cancelled.phase, tab: .direct), "—")
    }
}
