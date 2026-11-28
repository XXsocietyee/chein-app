import XCTest
@testable import QuestifyCore

final class ChannelDiscordMessagingTests: XCTestCase {

    // MARK: - 1. Message List Grouping Logic (Author/Time Bursts, Replies, Attachments, Reactions)

    func testSameAuthorMessagesWithinFiveMinutesGroupIntoSingleBurst() throws {
        let now = try XCTUnwrap(IMInboxTime.parse("2026-04-17T14:10:00"))
        let messages = [
            ChannelTranscriptMessage.make(
                id: 101,
                conversationID: 10,
                senderID: 501,
                senderName: "林深",
                type: 1,
                content: "大家今晚八点夜跑集合",
                createdAt: "2026-04-17T14:00:00"
            ),
            ChannelTranscriptMessage.make(
                id: 102,
                conversationID: 10,
                senderID: 501,
                senderName: "林深",
                type: 1,
                content: "记得带头灯和反光背心",
                createdAt: "2026-04-17T14:02:30"
            )
        ]

        let groups = ChannelMessageBurstGrouper.group(
            messages: messages,
            roleBadgeByMemberID: [501: "主理人"],
            now: now
        )

        XCTAssertEqual(groups.count, 1)
        let burst = try XCTUnwrap(groups.first)
        XCTAssertEqual(burst.senderID, 501)
        XCTAssertEqual(burst.senderRoleBadge, "主理人")
        XCTAssertEqual(burst.items.count, 2)
        XCTAssertTrue(burst.items[0].isFirstInBurst)
        XCTAssertFalse(burst.items[1].isFirstInBurst)
        XCTAssertFalse(burst.items[0].supportsReactions)
        XCTAssertFalse(ChannelMessageBurstGrouper.backendSupportsReactions)
    }

    func testAuthorChangeOrFiveMinuteGapStartsNewBurstGroup() throws {
        let now = try XCTUnwrap(IMInboxTime.parse("2026-04-17T15:00:00"))
        let messages = [
            ChannelTranscriptMessage.make(
                id: 201,
                conversationID: 10,
                senderID: 501,
                senderName: "林深",
                type: 1,
                content: "第一条",
                createdAt: "2026-04-17T14:00:00"
            ),
            ChannelTranscriptMessage.make(
                id: 202,
                conversationID: 10,
                senderID: 502,
                senderName: "阿泽",
                type: 1,
                content: "收到！",
                createdAt: "2026-04-17T14:01:00"
            ),
            ChannelTranscriptMessage.make(
                id: 203,
                conversationID: 10,
                senderID: 502,
                senderName: "阿泽",
                type: 1,
                content: "六分钟后的补充说明",
                createdAt: "2026-04-17T14:07:30"
            )
        ]

        let groups = ChannelMessageBurstGrouper.group(messages: messages, now: now)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[0].senderID, 501)
        XCTAssertEqual(groups[1].senderID, 502)
        XCTAssertEqual(groups[2].senderID, 502)
        XCTAssertNotNil(groups[2].precedingDividerText)
    }

    func testSystemMessagesAndRecalledMessagesDoNotMergeIntoUserBurst() throws {
        let now = try XCTUnwrap(IMInboxTime.parse("2026-04-17T14:10:00"))
        let messages = [
            ChannelTranscriptMessage.make(
                id: 301,
                conversationID: 10,
                senderID: 501,
                senderName: "林深",
                type: 1,
                content: "正常消息",
                statusWireValue: 0,
                createdAt: "2026-04-17T14:00:00"
            ),
            ChannelTranscriptMessage.make(
                id: 302,
                conversationID: 10,
                senderID: 501,
                senderName: "林深",
                type: 1,
                content: "秘密内容",
                statusWireValue: 1, // recalled
                createdAt: "2026-04-17T14:00:30"
            ),
            ChannelTranscriptMessage.make(
                id: 303,
                conversationID: 10,
                senderID: 0,
                senderName: "系统",
                type: 99,
                content: "新成员加入了频道",
                statusWireValue: 0,
                createdAt: "2026-04-17T14:01:00"
            )
        ]

        let groups = ChannelMessageBurstGrouper.group(messages: messages, now: now)
        XCTAssertEqual(groups.count, 3)
        XCTAssertEqual(groups[1].items.first?.displayBody, "该消息已撤回")
        XCTAssertTrue(groups[2].isSystemGroup)
    }

    func testReplyThreadExtractionAndAttachmentProjections() throws {
        let messages = [
            ChannelTranscriptMessage.make(
                id: 401,
                conversationID: 10,
                senderID: 501,
                senderName: "林深",
                type: 2,
                content: "https://cdn.example.com/club/route-map.jpg",
                mediaURL: "https://cdn.example.com/club/route-map.jpg",
                createdAt: "2026-04-17T14:00:00"
            ),
            ChannelTranscriptMessage.make(
                id: 402,
                conversationID: 10,
                senderID: 502,
                senderName: "阿泽",
                type: 1,
                content: "> #401 路线图很清晰，集合点在北门吗？",
                createdAt: "2026-04-17T14:01:00"
            )
        ]

        let groups = ChannelMessageBurstGrouper.group(messages: messages)
        XCTAssertEqual(groups.count, 2)

        let firstAttachments = groups[0].items[0].attachments
        XCTAssertEqual(firstAttachments.count, 1)
        XCTAssertEqual(firstAttachments[0].kind, .image)
        XCTAssertTrue(firstAttachments[0].isOriginApproved)

        let replyRef = try XCTUnwrap(groups[1].items[0].replyReference)
        XCTAssertEqual(replyRef.replyToMessageID, 401)
        XCTAssertEqual(replyRef.replyAuthorName, "林深")
        XCTAssertEqual(replyRef.threadReplyCount, 1)
    }

    // MARK: - 2. Send State Machine (Pending / Sending / Sent / Failed / Retry with Send-Receipt)

    func testSendStateMachineTransitionsAndSendReceiptRecovery() {
        var machine = ChannelSendStateMachine(conversationID: 88, accountEpoch: 1)

        // 1. Optimistic enqueue -> pending
        let pending = machine.enqueueOptimistic(
            clientMessageID: "cid-001",
            senderID: 501,
            content: "今晚八点集合",
            createdAt: "2026-04-17T12:00:00"
        )
        XCTAssertEqual(pending.phase, .pending)
        XCTAssertEqual(pending.attemptCount, 0)

        // 2. Mark sending
        let sending = machine.markSending(clientMessageID: "cid-001")
        XCTAssertEqual(sending?.phase, .sending)
        XCTAssertEqual(sending?.attemptCount, 1)

        // 3. Transport timeout -> mark failed
        let failed = machine.markFailed(clientMessageID: "cid-001", reason: "NETWORK_TIMEOUT")
        XCTAssertEqual(failed?.phase, .failed)
        XCTAssertTrue(failed?.canRetry == true)

        // 4. Retry consults `POST /api/im/send-receipt` first: if found, reconciles to `.sent` without resending
        XCTAssertTrue(machine.beginRetryWithReceiptCheck(clientMessageID: "cid-001"))
        let serverMessage = ChannelTranscriptMessage.make(
            id: 9001,
            conversationID: 88,
            senderID: 501,
            type: 1,
            content: "今晚八点集合",
            createdAt: "2026-04-17T12:00:02",
            clientMessageID: "cid-001"
        ).wireMessage

        let resolution = machine.resolveRetryAfterReceiptCheck(
            clientMessageID: "cid-001",
            receiptResult: .found(serverMessage)
        )
        XCTAssertEqual(resolution, .reconciledFromReceipt(serverMessage))
        XCTAssertEqual(machine.recordsByClientID["cid-001"]?.phase, .sent)
        XCTAssertEqual(machine.recordsByClientID["cid-001"]?.attemptCount, 1)
    }

    func testSendStateMachineResendsWithIdenticalClientMessageIDWhenReceiptNotFound() {
        var machine = ChannelSendStateMachine(conversationID: 88)
        _ = machine.enqueueOptimistic(clientMessageID: "cid-002", senderID: 501, content: "第二条消息")
        _ = machine.markSending(clientMessageID: "cid-002")
        _ = machine.markFailed(clientMessageID: "cid-002", reason: "OFFLINE")

        XCTAssertTrue(machine.beginRetryWithReceiptCheck(clientMessageID: "cid-002"))
        let resolution = machine.resolveRetryAfterReceiptCheck(
            clientMessageID: "cid-002",
            receiptResult: .notFound
        )
        XCTAssertEqual(resolution, .resendRequired(clientMessageID: "cid-002", attempt: 2))
        XCTAssertEqual(machine.recordsByClientID["cid-002"]?.phase, .sending)

        // Subsequent poll delivers the server message -> mergedTranscript deduplicates
        let polled = [
            ChannelTranscriptMessage.make(
                id: 9002,
                conversationID: 88,
                senderID: 501,
                type: 1,
                content: "第二条消息",
                createdAt: "2026-04-17T12:01:00",
                clientMessageID: "cid-002"
            )
        ]
        let merged = machine.mergedTranscript(serverMessages: polled)
        XCTAssertEqual(merged.count, 1)
        XCTAssertEqual(merged.first?.wireMessage.id, 9002)
        XCTAssertEqual(machine.recordsByClientID["cid-002"]?.phase, .sent)
    }

    // MARK: - 3. Unread Counts, Category Grouping, Mute Exclusion, and Fail-Closed Read State

    func testUnreadAndMentionCountsGroupByCategoryAndExcludeMutedChannels() {
        let listing = ChannelDirectoryListing(
            clubID: 77,
            categories: [
                ChannelDirectoryCategory(id: 10, clubID: 77, name: "赛事通知", position: 1),
                ChannelDirectoryCategory(id: 20, clubID: 77, name: "日常交流", position: 2)
            ],
            channels: [
                ChannelDirectoryEntry(
                    id: 1001,
                    clubID: 77,
                    categoryID: 10,
                    name: "重要公告",
                    kind: 2,
                    visibility: 0,
                    position: 1,
                    myState: ChannelDirectoryMyState(
                        lastReadMessageID: 10,
                        lastReadAt: nil,
                        notifyPref: 0,
                        unreadCount: 4,
                        readStateAvailable: true
                    )
                ),
                ChannelDirectoryEntry(
                    id: 1002,
                    clubID: 77,
                    categoryID: 20,
                    name: "装备吹水",
                    kind: 1,
                    visibility: 0,
                    position: 1,
                    myState: ChannelDirectoryMyState(
                        lastReadMessageID: 20,
                        lastReadAt: nil,
                        notifyPref: 2, // muted
                        unreadCount: 15,
                        readStateAvailable: true
                    )
                ),
                ChannelDirectoryEntry(
                    id: 1003,
                    clubID: 77,
                    categoryID: 20,
                    name: "夜跑约伴",
                    kind: 1,
                    visibility: 0,
                    position: 2,
                    myState: ChannelDirectoryMyState(
                        lastReadMessageID: 30,
                        lastReadAt: nil,
                        notifyPref: 0,
                        unreadCount: 120,
                        readStateAvailable: true
                    )
                ),
                ChannelDirectoryEntry(
                    id: 1004,
                    clubID: 77,
                    categoryID: 20,
                    name: "状态未知频道",
                    kind: 1,
                    visibility: 0,
                    position: 3,
                    myState: ChannelDirectoryMyState(
                        lastReadMessageID: nil,
                        lastReadAt: nil,
                        notifyPref: 0,
                        unreadCount: 0,
                        readStateAvailable: false
                    )
                )
            ]
        )

        let projection = ChannelCategoryDirectoryProjection(
            listing: listing,
            mentionCountsByChannelID: [1002: 3, 1003: 1]
        )

        XCTAssertEqual(projection.groups.count, 2)
        // Total unmuted unread = 4 (channel 1001) + 120 (channel 1003) = 124; muted channel 1002 (15) excluded
        XCTAssertEqual(projection.totalUnmutedUnreadCount, 124)
        XCTAssertEqual(projection.totalUnreadBadgeText, "99+")
        // Mentions include muted channel 1002 (3) + channel 1003 (1) = 4
        XCTAssertEqual(projection.totalMentionCount, 4)
        XCTAssertTrue(projection.hasUnavailableReadState)

        let dailyGroup = projection.groups[1]
        let mutedChannel = dailyGroup.channels[0]
        XCTAssertTrue(mutedChannel.isMuted)
        XCTAssertNil(mutedChannel.unreadBadgeText)
        XCTAssertEqual(mutedChannel.mentionBadgeText, "@3")

        let highUnreadChannel = dailyGroup.channels[1]
        XCTAssertEqual(highUnreadChannel.unreadBadgeText, "99+")

        let unavailableChannel = dailyGroup.channels[2]
        XCTAssertFalse(unavailableChannel.readStateAvailable)
        XCTAssertNil(unavailableChannel.unreadCount)
        XCTAssertNil(unavailableChannel.unreadBadgeText)

        // Marking channel 1003 read clears its unread and mention count
        let afterRead = projection.markingChannelRead(
            1003,
            listing: listing,
            mentionCountsByChannelID: [1002: 3, 1003: 1]
        )
        XCTAssertEqual(afterRead.totalUnmutedUnreadCount, 4)
        XCTAssertEqual(afterRead.totalMentionCount, 3)
    }

    // MARK: - 4. Moderation Permission Checks & App Store Guideline 1.2 Safety

    func testModerationPermissionChecksAndSafetyRules() {
        let unacceptedDefaultPolicy = ChannelSafetyModerationPolicy(
            clubID: 77,
            viewerMemberID: 601,
            viewerRoleTier: .member,
            capabilities: ChannelModerationCapabilities()
        )
        XCTAssertFalse(unacceptedDefaultPolicy.hasAcceptedChannelRules)

        let memberPolicy = ChannelSafetyModerationPolicy(
            clubID: 77,
            viewerMemberID: 601,
            viewerRoleTier: .member,
            capabilities: ChannelModerationCapabilities(),
            hasAcceptedChannelRules: true
        )
        let adminPolicy = ChannelSafetyModerationPolicy(
            clubID: 77,
            viewerMemberID: 501,
            viewerRoleTier: .operatorAdmin,
            capabilities: ChannelModerationCapabilities(
                canManageMembers: true,
                canManageBans: true,
                canManageContent: true
            ),
            hasAcceptedChannelRules: true
        )

        let otherMessage = ChannelTranscriptMessage.make(
            id: 7001,
            conversationID: 1001,
            senderID: 602,
            type: 1,
            content: "测试消息"
        ).wireMessage
        let ownMessage = ChannelTranscriptMessage.make(
            id: 7002,
            conversationID: 1001,
            senderID: 601,
            type: 1,
            content: "我自己的消息"
        ).wireMessage

        // Report message: allowed on other's message, forbidden on own message
        XCTAssertEqual(
            memberPolicy.validateReportMessage(message: otherMessage, reason: "垃圾广告"),
            .success(.reportMessage(messageID: 7001, reason: "垃圾广告"))
        )
        XCTAssertEqual(
            memberPolicy.validateReportMessage(message: ownMessage, reason: "误报自己"),
            .failure(.cannotTargetSelf)
        )

        // Delete message: ordinary member can delete own message, cannot delete other's; admin can delete other's
        XCTAssertEqual(
            memberPolicy.validateDeleteMessage(channelID: 1001, message: ownMessage),
            .success(.deleteMessage(clubID: 77, channelID: 1001, messageID: 7002))
        )
        XCTAssertEqual(
            memberPolicy.validateDeleteMessage(channelID: 1001, message: otherMessage),
            .failure(.insufficientModerationPermission)
        )
        XCTAssertEqual(
            adminPolicy.validateDeleteMessage(channelID: 1001, message: otherMessage),
            .success(.deleteMessage(clubID: 77, channelID: 1001, messageID: 7001))
        )

        // Remove member: blocked for ordinary member, blocked when target is owner or holds active role assignment
        let ownerItem = ChannelMemberRoleItem(
            memberID: 500,
            nickname: "创始人",
            tier: .owner,
            roleCode: "CLUB_OWNER",
            badgeLabel: "主理人"
        )
        let delegatedStaff = ChannelMemberRoleItem(
            memberID: 603,
            nickname: "领队小王",
            tier: .eventStaff,
            roleCode: "EVENT_LEAD",
            badgeLabel: "活动领队",
            holdsActiveRoleAssignment: true
        )
        let regularMember = ChannelMemberRoleItem(
            memberID: 604,
            nickname: "普通队员",
            tier: .member,
            roleCode: "CLUB_MEMBER",
            badgeLabel: "成员"
        )

        XCTAssertEqual(
            memberPolicy.validateRemoveMember(target: regularMember),
            .failure(.insufficientModerationPermission)
        )
        XCTAssertEqual(
            adminPolicy.validateRemoveMember(target: ownerItem),
            .failure(.cannotTargetClubOwner)
        )
        XCTAssertEqual(
            adminPolicy.validateRemoveMember(target: delegatedStaff),
            .failure(.targetHoldsActiveRoleAssignment)
        )
        XCTAssertEqual(
            adminPolicy.validateRemoveMember(target: regularMember),
            .success(.removeMember(clubID: 77, targetMemberID: 604))
        )

        // Unban member: platform ban (`source == "PLATFORM"`) cannot be unbanned by club admin
        let platformBan = ChannelModerationBanRecord(
            id: 91,
            targetMemberID: 604,
            nickname: "普通队员",
            source: "PLATFORM",
            status: "ACTIVE",
            reasonCode: "FRAUD",
            reasonText: "平台风控封禁"
        )
        XCTAssertEqual(
            adminPolicy.validateUnbanMember(banRow: platformBan, reason: "误封"),
            .failure(.platformBanCannotBeUnbannedByClubAdmin)
        )

        // Channel rules admission & revoke isolation respected
        let revokedAdminPolicy = ChannelSafetyModerationPolicy(
            clubID: 77,
            viewerMemberID: 501,
            viewerRoleTier: .owner,
            capabilities: ChannelModerationCapabilities(canManageMembers: true, canManageBans: true, canManageContent: true),
            hasAcceptedChannelRules: true,
            isChannelAccessRevoked: true
        )
        XCTAssertEqual(
            revokedAdminPolicy.validateDeleteMessage(channelID: 1001, message: otherMessage),
            .failure(.channelRevokedOrBanned)
        )
    }

    func testContentFilterHookHidesBlockedSendersAndMasksObjectionableTerms() {
        let filter = ChannelContentFilterHook(
            blockedSenderIDs: [666],
            mutedKeywords: ["赌博", "外挂"],
            maskObjectionableContent: true
        )
        let blockedMessage = ChannelTranscriptMessage.make(
            id: 8001,
            conversationID: 10,
            senderID: 666,
            type: 1,
            content: "正常文字但来自被拉黑用户"
        )
        let objectionableMessage = ChannelTranscriptMessage.make(
            id: 8002,
            conversationID: 10,
            senderID: 602,
            type: 1,
            content: "这里有外挂和赌博链接"
        )

        XCTAssertTrue(filter.shouldHideMessageImmediately(blockedMessage.wireMessage))
        let groups = ChannelMessageBurstGrouper.group(
            messages: [blockedMessage, objectionableMessage],
            contentFilter: filter
        )
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups[0].senderID, 602)
        XCTAssertTrue(groups[0].items[0].isFilteredBySafetyHook)
        XCTAssertFalse(groups[0].items[0].displayBody.contains("外挂"))
        XCTAssertFalse(groups[0].items[0].displayBody.contains("赌博"))
    }

    // MARK: - 5. Polling Backoff & Viewport Paging / New-Message Jump

    func testPollingBackoffScheduleAndViewportNewMessageJump() {
        var backoff = ChannelPollingBackoffSchedule()
        XCTAssertEqual(backoff.nextDelayMilliseconds, 8_000)

        backoff.recordFailure(httpStatus: 502)
        XCTAssertEqual(backoff.nextDelayMilliseconds, 16_000)
        backoff.recordFailure(httpStatus: 503)
        XCTAssertEqual(backoff.nextDelayMilliseconds, 32_000)
        backoff.recordSuccess()
        XCTAssertEqual(backoff.nextDelayMilliseconds, 8_000)

        backoff.recordFailure(errorCode: "IM_HISTORY_ACCESS_DENIED", httpStatus: 403)
        XCTAssertTrue(backoff.isStoppedForTerminalError)
        XCTAssertNil(backoff.nextDelayMilliseconds)

        // Viewport scrolled up -> incoming message triggers new-message jump pill
        let initial = [
            ChannelTranscriptMessage.make(id: 10, conversationID: 1, senderID: 501, type: 1, content: "M1")
        ]
        var viewport = ChannelTranscriptViewportState(initialMessages: initial, hasMoreOlderPages: true)
        viewport.updateScrollDistanceFromBottom(320) // scrolled up (>120pt)
        XCTAssertFalse(viewport.isNearBottom)

        viewport.applyPolledMessages(
            [
                ChannelTranscriptMessage.make(id: 11, conversationID: 1, senderID: 502, type: 1, content: "M2"),
                ChannelTranscriptMessage.make(id: 12, conversationID: 1, senderID: 503, type: 1, content: "M3")
            ],
            viewerAccountID: 501
        )
        XCTAssertTrue(viewport.showNewMessageJumpBanner)
        XCTAssertEqual(viewport.pendingNewMessageCount, 2)
        XCTAssertEqual(viewport.firstUnreadNewMessageID, 11)

        let jumpTarget = viewport.jumpToBottomClearingNewMessages()
        XCTAssertEqual(jumpTarget, 11)
        XCTAssertFalse(viewport.showNewMessageJumpBanner)
        XCTAssertEqual(viewport.pendingNewMessageCount, 0)
    }

    // MARK: - Bilingual copy

    func testPlaceholdersAndTierTitlesFollowLocale() {
        let en = Locale(identifier: "en")
        let zh = Locale(identifier: "zh-Hans")
        let hidden = ChannelTranscriptMessage.make(id: 9001, conversationID: 10, senderID: 501, type: 1, content: "x")
        let filter = ChannelContentFilterHook(locale: en)
        XCTAssertEqual(ChannelCopy.text("主理人", "Owner", locale: en), "Owner")
        XCTAssertEqual(ChannelCopy.text("主理人", "Owner", locale: zh), "主理人")
        XCTAssertEqual(ChannelMemberRoleTier.owner.sectionTitle(locale: en), "Owner")
        XCTAssertEqual(ChannelMemberRoleTier.owner.sectionTitle(locale: zh), ChannelMemberRoleTier.owner.sectionTitle)
        XCTAssertEqual(filter.evaluate(message: hidden.wireMessage).displayText, "x")
        // en-layout r3: English follows the locale hour cycle ("Today 8:30 AM"); Chinese keeps the MP HH:mm.
        XCTAssertTrue(ChannelMessageBurstGrouper.formatDivider(.today(clock: "08:30"), locale: en).hasPrefix("Today 8:30"))
        XCTAssertEqual(ChannelMessageBurstGrouper.formatDivider(.today(clock: "08:30")), "今天 08:30")
        XCTAssertTrue(ChannelMessageBurstGrouper.formatDivider(.date(month: 11, day: 7, clock: "09:00"), locale: en).hasPrefix("Nov 7, 9:00"))
        XCTAssertEqual(ChannelMessageBurstGrouper.formatDivider(.date(month: 11, day: 7, clock: "09:00"), locale: zh), "11月7日 09:00") // mp-club r3 pass 39: locale date, not raw MM-dd
    }

    func testClubRecordDecodesMyJoinReviewReasonAndTrimsBlank() throws {
        let rejectedJSON = Data("""
        {"id": 42, "name": "夜行探索社", "myJoinStatus": 2, "myJoinReviewReason": "  请补充真实常住城市与探险经历  "}
        """.utf8)
        let rejected = try JSONDecoder().decode(ClubRecord.self, from: rejectedJSON)
        XCTAssertEqual(rejected.myJoinStatus, 2)
        XCTAssertEqual(rejected.myJoinReviewReason, "请补充真实常住城市与探险经历")

        let blankJSON = Data("""
        {"id": 43, "name": "夜行探索社", "myJoinStatus": 2, "myJoinReviewReason": "   "}
        """.utf8)
        let blank = try JSONDecoder().decode(ClubRecord.self, from: blankJSON)
        XCTAssertEqual(blank.myJoinStatus, 2)
        XCTAssertNil(blank.myJoinReviewReason)
    }

    // MARK: - 6. G2 Real Club/Channel Moderation, Rules Gate, Channel Reporting & Dynamic Channel Loading

    @MainActor
    func testRulesAcceptanceGateDefaultsToFalseAndPersistsAcrossCoordinators() async {
        let rulesStore = InMemoryChannelRulesAcceptanceStore()
        let blockedStore = InMemoryChannelBlockedUsersStore()
        let service = ControllableSafetyServiceSpy()

        let coordinator = ClubChannelModerationCoordinator(
            clubID: 88,
            viewerMemberID: 501,
            viewerRoleTier: .owner,
            capabilities: ChannelModerationCapabilities(
                canManageMembers: true,
                canManageBans: true,
                canManageContent: true,
                canManageRoles: true
            ),
            rulesVersion: 2,
            rulesStore: rulesStore,
            blockedUsersStore: blockedStore,
            service: service
        )

        XCTAssertFalse(coordinator.hasAcceptedRules)
        XCTAssertFalse(coordinator.policy.hasAcceptedChannelRules)

        // Gated action fails with .channelAdmissionRequired before rules are accepted
        let ownMsg = ChannelTranscriptMessage.make(
            id: 7100,
            conversationID: 2001,
            senderID: 501,
            type: 1,
            content: "测试撤回"
        ).wireMessage
        let deleteBeforeAccept = await coordinator.deleteMessage(channelID: 2001, message: ownMsg)
        XCTAssertFalse(deleteBeforeAccept)
        XCTAssertTrue(service.recordedEndpoints.isEmpty)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, true)
        XCTAssertEqual(coordinator.feedbackBanner?.canRetry, false)

        // Accept rules -> persists in store and unlocks gated actions
        coordinator.acceptChannelRules()
        XCTAssertTrue(coordinator.hasAcceptedRules)
        XCTAssertTrue(rulesStore.hasAcceptedRules(clubID: 88, viewerMemberID: 501, rulesVersion: 2))

        // Re-instantiating with same rulesVersion preserves acceptance; higher rulesVersion requires re-acceptance
        let reloadedSameVersion = ClubChannelModerationCoordinator(
            clubID: 88,
            viewerMemberID: 501,
            viewerRoleTier: .owner,
            rulesVersion: 2,
            rulesStore: rulesStore,
            blockedUsersStore: blockedStore,
            service: service
        )
        XCTAssertTrue(reloadedSameVersion.hasAcceptedRules)

        let reloadedNewerVersion = ClubChannelModerationCoordinator(
            clubID: 88,
            viewerMemberID: 501,
            viewerRoleTier: .owner,
            rulesVersion: 3,
            rulesStore: rulesStore,
            blockedUsersStore: blockedStore,
            service: service
        )
        XCTAssertFalse(reloadedNewerVersion.hasAcceptedRules)
    }

    @MainActor
    func testAllModerationHandlersEnforceSuccessOnlyAfterServiceReturnsAndSupportRetry() async {
        let rulesStore = InMemoryChannelRulesAcceptanceStore(initialAcceptedVersions: ["77:501": 1])
        let blockedStore = InMemoryChannelBlockedUsersStore()
        let service = ControllableSafetyServiceSpy()
        let en = Locale(identifier: "en")

        let coordinator = ClubChannelModerationCoordinator(
            clubID: 77,
            viewerMemberID: 501,
            viewerRoleTier: .owner,
            capabilities: ChannelModerationCapabilities(
                canManageMembers: true,
                canManageBans: true,
                canManageContent: true,
                canManageRoles: true
            ),
            rulesVersion: 1,
            rulesStore: rulesStore,
            blockedUsersStore: blockedStore,
            service: service
        )
        XCTAssertTrue(coordinator.hasAcceptedRules)

        let targetMessage = ChannelTranscriptMessage.make(
            id: 9101,
            conversationID: 3001,
            senderID: 602,
            type: 1,
            content: "违规内容"
        ).wireMessage
        let targetMember = ChannelMemberRoleItem(
            memberID: 602,
            nickname: "违规成员",
            tier: .member,
            roleCode: "MEMBER",
            badgeLabel: "成员"
        )

        // 1. reportMessage: failure -> error banner + retryable, no false success; retry -> success
        service.shouldFail = true
        let reportMsgFail = await coordinator.reportMessage(
            message: targetMessage,
            reason: "Spam advertisement",
            activeChannelID: 3001,
            locale: en
        )
        XCTAssertFalse(reportMsgFail)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, true)
        XCTAssertEqual(coordinator.feedbackBanner?.canRetry, true)
        XCTAssertFalse(coordinator.feedbackBanner?.message.contains("Report submitted") ?? true)

        service.shouldFail = false
        let reportMsgRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(reportMsgRetry)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, false)
        XCTAssertTrue(coordinator.feedbackBanner?.message.contains("Report submitted") ?? false)
        XCTAssertEqual(service.recordedEndpoints.last, .reportMessage(messageID: 9101, reason: "Spam advertisement"))

        // 2. reportUser: failure -> retry -> success
        service.shouldFail = true
        let reportUserFail = await coordinator.reportUser(
            targetMemberID: 602,
            nickname: "违规成员",
            reasonCode: "HARASSMENT",
            detail: "Harassing DMs",
            activeChannelID: 3001,
            locale: en
        )
        XCTAssertFalse(reportUserFail)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, true)
        XCTAssertEqual(coordinator.feedbackBanner?.canRetry, true)

        service.shouldFail = false
        let reportUserRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(reportUserRetry)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, false)
        XCTAssertEqual(
            service.recordedEndpoints.last,
            .reportClubUser(clubID: 77, targetMemberID: 602, reasonCode: "HARASSMENT", detail: "Harassing DMs")
        )

        // 3. reportChannel: failure -> retry -> success
        service.shouldFail = true
        let reportChannelFail = await coordinator.reportChannel(
            channelID: 3001,
            channelName: "general-chat",
            reasonCode: "SPAM_SCAM",
            detail: "Phishing links in channel",
            locale: en
        )
        XCTAssertFalse(reportChannelFail)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, true)
        XCTAssertEqual(coordinator.feedbackBanner?.canRetry, true)

        service.shouldFail = false
        let reportChannelRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(reportChannelRetry)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, false)
        XCTAssertEqual(
            service.recordedEndpoints.last,
            .reportChannel(clubID: 77, channelID: 3001, reasonCode: "SPAM_SCAM", detail: "Phishing links in channel")
        )

        // 4. blockUser & unblockUser: failure does NOT hide content or persist block; retry DOES hide & persist
        service.shouldFail = true
        let blockFail = await coordinator.blockUser(
            targetMemberID: 602,
            nickname: "违规成员",
            shouldBlock: true,
            activeChannelID: 3001,
            locale: en
        )
        XCTAssertFalse(blockFail)
        XCTAssertFalse(coordinator.blockedSenderIDs.contains(602))
        XCTAssertFalse(blockedStore.blockedUserIDs(clubID: 77, viewerMemberID: 501).contains(602))

        service.shouldFail = false
        let blockRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(blockRetry)
        XCTAssertTrue(coordinator.blockedSenderIDs.contains(602))
        XCTAssertTrue(blockedStore.blockedUserIDs(clubID: 77, viewerMemberID: 501).contains(602))
        XCTAssertEqual(service.recordedEndpoints.last, .blockUser(targetMemberID: 602))

        // Verify blocked user's content is immediately hidden in burst groups
        let filterAfterBlock = ChannelContentFilterHook(blockedSenderIDs: coordinator.blockedSenderIDs)
        let groupsAfterBlock = ChannelMessageBurstGrouper.group(
            messages: [ChannelTranscriptMessage(wireMessage: targetMessage)],
            contentFilter: filterAfterBlock
        )
        XCTAssertTrue(groupsAfterBlock.isEmpty)

        // Unblock user: failure keeps user blocked; retry unblocks
        service.shouldFail = true
        let unblockFail = await coordinator.blockUser(
            targetMemberID: 602,
            nickname: "违规成员",
            shouldBlock: false,
            activeChannelID: 3001,
            locale: en
        )
        XCTAssertFalse(unblockFail)
        XCTAssertTrue(coordinator.blockedSenderIDs.contains(602))

        service.shouldFail = false
        let unblockRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(unblockRetry)
        XCTAssertFalse(coordinator.blockedSenderIDs.contains(602))
        XCTAssertEqual(service.recordedEndpoints.last, .unblockUser(targetMemberID: 602))

        // 5. muteChannel: failure does NOT toggle mute; retry toggles mute
        service.shouldFail = true
        let muteFail = await coordinator.muteChannel(conversationID: 3001, muted: true, locale: en)
        XCTAssertFalse(muteFail)
        XCTAssertFalse(coordinator.mutedChannelIDs.contains(3001))

        service.shouldFail = false
        let muteRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(muteRetry)
        XCTAssertTrue(coordinator.mutedChannelIDs.contains(3001))
        XCTAssertEqual(service.recordedEndpoints.last, .muteChannel(conversationID: 3001, muted: true))

        // 6. deleteMessage: failure does NOT delete message; retry deletes message
        service.shouldFail = true
        let deleteFail = await coordinator.deleteMessage(channelID: 3001, message: targetMessage, locale: en)
        XCTAssertFalse(deleteFail)
        XCTAssertFalse(coordinator.deletedMessageIDs.contains(9101))

        service.shouldFail = false
        let deleteRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(deleteRetry)
        XCTAssertTrue(coordinator.deletedMessageIDs.contains(9101))
        XCTAssertEqual(service.recordedEndpoints.last, .deleteMessage(clubID: 77, channelID: 3001, messageID: 9101))

        // 7. removeMember: failure does NOT remove member; retry removes member
        service.shouldFail = true
        let removeFail = await coordinator.removeMember(target: targetMember, activeChannelID: 3001, locale: en)
        XCTAssertFalse(removeFail)
        XCTAssertFalse(coordinator.removedMemberIDs.contains(602))

        service.shouldFail = false
        let removeRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(removeRetry)
        XCTAssertTrue(coordinator.removedMemberIDs.contains(602))
        XCTAssertEqual(service.recordedEndpoints.last, .removeMember(clubID: 77, targetMemberID: 602))

        // 8. banMember & unbanMember: failure does NOT add/remove ban; retry adds/removes ban
        let secondMember = ChannelMemberRoleItem(
            memberID: 603,
            nickname: "恶意刷屏号",
            tier: .member,
            roleCode: "MEMBER",
            badgeLabel: "成员"
        )
        service.shouldFail = true
        let banFail = await coordinator.banMember(
            target: secondMember,
            reasonCode: "SPAM",
            reasonText: "Repeated spam flooding",
            activeChannelID: 3001,
            locale: en
        )
        XCTAssertFalse(banFail)
        XCTAssertTrue(coordinator.activeBans.isEmpty)

        service.shouldFail = false
        let banRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(banRetry)
        XCTAssertEqual(coordinator.activeBans.count, 1)
        XCTAssertEqual(coordinator.activeBans.first?.targetMemberID, 603)
        XCTAssertEqual(
            service.recordedEndpoints.last,
            .banMember(clubID: 77, targetMemberID: 603, reasonCode: "SPAM", reasonText: "Repeated spam flooding")
        )

        let createdBan = coordinator.activeBans[0]
        service.shouldFail = true
        let unbanFail = await coordinator.unbanMember(
            banRow: createdBan,
            reason: "Appeal approved",
            activeChannelID: 3001,
            locale: en
        )
        XCTAssertFalse(unbanFail)
        XCTAssertEqual(coordinator.activeBans.count, 1)

        service.shouldFail = false
        let unbanRetry = await coordinator.retryLastFailedAction(locale: en)
        XCTAssertTrue(unbanRetry)
        XCTAssertTrue(coordinator.activeBans.isEmpty)
        XCTAssertEqual(
            service.recordedEndpoints.last,
            .unbanMember(clubID: 77, banID: createdBan.id, reason: "Appeal approved")
        )
    }

    @MainActor
    func testCoreClubChannelSafetyServiceRoutesThroughCoreWritersAndLoadsRealClubChannels() async throws {
        let imSafetySpy = IMSafetyWriterSpy()
        let imExpandedSpy = IMExpandedWriterSpy()
        let messageWriterSpy = MessageActionWriterSpy()
        let clubManagementSpy = ClubManagementAccessSpy()
        let messagingReaderSpy = ClubChannelMessagingReaderSpy(clubID: 77)
        var deletedTriplets: [(Int, Int, Int)] = []

        let coreService = CoreClubChannelSafetyService(
            imSafetyWriter: { imSafetySpy },
            imExpandedWriter: { imExpandedSpy },
            messageWriter: { messageWriterSpy },
            messagingReader: { messagingReaderSpy },
            clubManagementAccess: { clubManagementSpy },
            channelMessageDeleteDispatcher: { clubID, channelID, messageID in
                deletedTriplets.append((clubID, channelID, messageID))
            }
        )

        let clubData = Data("""
        {"id": 77, "name": "山野俱乐部", "isOwner": true, "isJoined": true}
        """.utf8)
        let club = try JSONDecoder().decode(ClubRecord.self, from: clubData)

        // 1. Dynamic channel loading from MessagingReading (verifying NO hardcoded 101/102/103)
        let workspace = try await coreService.loadChannelWorkspace(club: club, viewerMemberID: 501)
        let loadedChannelIDs = workspace.listing.channels.map(\.id)
        XCTAssertEqual(loadedChannelIDs, [8801, 8802])
        XCTAssertFalse(loadedChannelIDs.contains(101))
        XCTAssertFalse(loadedChannelIDs.contains(102))
        XCTAssertFalse(loadedChannelIDs.contains(103))
        XCTAssertEqual(workspace.initialMessagesByChannelID[8801]?.count, 1)
        XCTAssertEqual(workspace.initialMessagesByChannelID[8801]?.first?.wireMessage.content, "真实频道历史消息")

        // 2. Route reportMessage, reportChannel, blockUser, unblockUser through IMSafetyWriting
        try await coreService.performModeration(.reportMessage(messageID: 555, reason: "Abuse"), activeChannelID: 8801)
        // The real message id and the reason the user chose are sent (not the fixed literal).
        XCTAssertEqual(imSafetySpy.actions.last, .reportWithReason(conversationID: 8801, messageID: 555, reason: "Abuse"))

        // A channel report has no message id: it must not be sent to api/im/report as one. With no governance
        // route configured it fails closed and the IM writer sees nothing new.
        let actionsBeforeChannelReport = imSafetySpy.actions
        do {
            try await coreService.performModeration(
                .reportChannel(clubID: 77, channelID: 8801, reasonCode: "SPAM", detail: "Raid"),
                activeChannelID: 8801
            )
            XCTFail("reportChannel must fail closed without a governance route")
        } catch let error as ChannelSafetyServiceError {
            guard case .serviceUnavailable = error else { return XCTFail("unexpected \(error)") }
        }
        XCTAssertEqual(imSafetySpy.actions, actionsBeforeChannelReport)

        try await coreService.performModeration(.blockUser(targetMemberID: 602), activeChannelID: 8801)
        XCTAssertEqual(imSafetySpy.actions.last, .block(conversationID: 8801, targetMemberID: 602))

        try await coreService.performModeration(.unblockUser(targetMemberID: 602), activeChannelID: 8801)
        XCTAssertEqual(imSafetySpy.actions.last, .unblock(conversationID: 8801, targetMemberID: 602))

        // 3. Route muteChannel & sendChannelMessage through IMExpandedWriting
        try await coreService.performModeration(.muteChannel(conversationID: 8801, muted: true), activeChannelID: 8801)
        XCTAssertEqual(imExpandedSpy.mutations.last, .mute(conversationID: 8801, muted: true))

        let sentServerID = try await coreService.sendChannelMessage(
            clubID: 77,
            channelID: 8801,
            clientMessageID: "client-msg-01",
            content: "Hello channel",
            replyToMessageID: nil
        )
        XCTAssertEqual(sentServerID, 9901)

        // 4. Route removeMember through ClubManagementAccess & deleteMessage through dispatcher
        try await coreService.performModeration(.removeMember(clubID: 77, targetMemberID: 602), activeChannelID: 8801)
        XCTAssertEqual(clubManagementSpy.removedMembers.last?.clubID, 77)
        XCTAssertEqual(clubManagementSpy.removedMembers.last?.memberID, 602)

        try await coreService.performModeration(
            .deleteMessage(clubID: 77, channelID: 8801, messageID: 555),
            activeChannelID: 8801
        )
        XCTAssertEqual(deletedTriplets.count, 1)
        XCTAssertEqual(deletedTriplets.first?.0, 77)
        XCTAssertEqual(deletedTriplets.first?.1, 8801)
        XCTAssertEqual(deletedTriplets.first?.2, 555)
    }
}

// MARK: - Test Doubles for G2 Moderation & Channel Directory

@MainActor
private final class ControllableSafetyServiceSpy: ClubChannelSafetyServing {
    var shouldFail = false
    private(set) var recordedEndpoints: [ChannelSafetyModerationEndpoint] = []

    func loadChannelWorkspace(club: ClubRecord, viewerMemberID: Int) async throws -> ClubChannelWorkspacePayload {
        if shouldFail {
            throw ChannelSafetyServiceError.channelDirectoryUnavailable
        }
        let listing = ChannelDirectoryListing(
            clubID: Int64(club.id),
            categories: [ChannelDirectoryCategory(id: 10, clubID: Int64(club.id), name: "动态分组", position: 10)],
            channels: [
                ChannelDirectoryEntry(
                    id: 8801,
                    clubID: Int64(club.id),
                    categoryID: 10,
                    name: "路线交流",
                    kind: 1,
                    visibility: 0,
                    position: 10
                )
            ]
        )
        return ClubChannelWorkspacePayload(listing: listing, initialMessagesByChannelID: [8801: []])
    }

    func performModeration(_ endpoint: ChannelSafetyModerationEndpoint, activeChannelID: Int) async throws {
        if shouldFail {
            throw ChannelSafetyServiceError.operationFailed(reason: "Simulated network error")
        }
        recordedEndpoints.append(endpoint)
    }

    func sendChannelMessage(
        clubID: Int,
        channelID: Int,
        clientMessageID: String,
        content: String,
        replyToMessageID: Int?
    ) async throws -> Int {
        if shouldFail {
            throw ChannelSafetyServiceError.messageSendUnavailable
        }
        return 9001
    }
}

@MainActor
private final class IMSafetyWriterSpy: IMSafetyWriting {
    var identity: MessagingReadIdentity? = MessagingReadIdentity(accountID: 501, epoch: 1)
    private(set) var actions: [IMSafetyAction] = []

    func permits(_ action: IMSafetyAction) -> Bool {
        true
    }

    func perform(_ action: IMSafetyAction, expectedIdentity: MessagingReadIdentity) async throws {
        actions.append(action)
    }
}

@MainActor
private final class IMExpandedWriterSpy: IMExpandedWriting {
    var isConfigured: Bool = true
    var identity: MessagingReadIdentity? = MessagingReadIdentity(accountID: 501, epoch: 1)
    private(set) var mutations: [IMMutation] = []

    func perform(_ mutation: IMMutation, expectedIdentity: MessagingReadIdentity) async throws -> IMMutationReceipt {
        mutations.append(mutation)
        switch mutation {
        case .start(let targetMemberID):
            return .started(conversationID: targetMemberID)
        case .read, .readCursor:
            return .read
        case .mute(_, let muted):
            return .muted(muted)
        case .send:
            let msg = ChannelTranscriptMessage.make(
                id: 9901,
                conversationID: 8801,
                senderID: 501,
                type: 1,
                content: "Hello channel"
            ).wireMessage
            return .sent(msg)
        }
    }

    func upload(_ selection: IMMediaSelection, consent: IMMediaConsent, expectedIdentity: MessagingReadIdentity) async throws -> URL {
        throw APIError.notConfigured
    }
}

@MainActor
private final class MessageActionWriterSpy: MessageActionWriting {
    var isConfigured: Bool = true
    var identity: MessagingReadIdentity? = MessagingReadIdentity(accountID: 501, epoch: 1)
    private(set) var intents: [MessageTextIntent] = []

    func send(_ intent: MessageTextIntent, expectedIdentity: MessagingReadIdentity) async throws -> MessagingMessage {
        intents.append(intent)
        return ChannelTranscriptMessage.make(
            id: 9901,
            conversationID: intent.conversationID,
            senderID: expectedIdentity.accountID,
            type: 1,
            content: intent.content
        ).wireMessage
    }
}

@MainActor
private final class ClubManagementAccessSpy: ClubManagementAccess {
    var identity: ClubReadIdentity? = ClubReadIdentity(accountID: 501, epoch: 1)
    var isConfigured: Bool = true
    private(set) var removedMembers: [(clubID: Int, memberID: Int)] = []

    func snapshot(clubID: Int) async throws -> ClubManagementSnapshot {
        throw APIError.notConfigured
    }

    func perform(
        _ action: ClubManagementAction,
        clubID: Int,
        memberID: Int,
        expectedIdentity: ClubReadIdentity
    ) async throws -> ClubActionReceipt {
        if action == .remove {
            removedMembers.append((clubID, memberID))
        }
        return ClubActionReceipt(state: "removed", message: "OK")
    }
}

@MainActor
private final class ClubChannelMessagingReaderSpy: MessagingReading {
    let clubID: Int
    var isConfigured: Bool = true
    var identity: MessagingReadIdentity? = MessagingReadIdentity(accountID: 501, epoch: 1)

    init(clubID: Int) {
        self.clubID = clubID
    }

    func messagingConversations() async throws -> [MessagingConversation] {
        let json = Data("""
        [
            {
                "conversationId": 8801,
                "type": 4,
                "unread": 2,
                "muted": 0,
                "counterparty": {
                    "id": 8801,
                    "nickname": "山野路线讨论",
                    "bizKey": "club_\(clubID)"
                }
            },
            {
                "conversationId": 8802,
                "type": 4,
                "unread": 0,
                "muted": 1,
                "counterparty": {
                    "id": 8802,
                    "nickname": "装备跳蚤市场",
                    "bizKey": "club_\(clubID)"
                }
            }
        ]
        """.utf8)
        return try JSONDecoder().decode([MessagingConversation].self, from: json)
    }

    func messagingMessages(conversationID: Int, cursor: Int) async throws -> MessagingPage {
        let msg = ChannelTranscriptMessage.make(
            id: 7701,
            conversationID: conversationID,
            senderID: 602,
            type: 1,
            content: "真实频道历史消息"
        ).wireMessage
        let pageJSON = Data("""
        {
            "list": [
                {
                    "id": 7701,
                    "conversationId": \(conversationID),
                    "senderId": 602,
                    "msgType": 1,
                    "content": "真实频道历史消息",
                    "status": 0
                }
            ],
            "hasMore": false,
            "blocked": false,
            "blockedByMe": false
        }
        """.utf8)
        _ = msg
        return try JSONDecoder().decode(MessagingPage.self, from: pageJSON)
    }
}


// MARK: - Finding 3 fail-closed safety tests

@MainActor
final class ChannelSafetyFailClosedTests: XCTestCase {
    private func service(imSafety: IMSafetyWriterSpy, messageWriter: MessageActionWriterSpy? = nil,
                         deleteDispatcher: ((Int, Int, Int) async throws -> Void)? = nil) -> CoreClubChannelSafetyService {
        CoreClubChannelSafetyService(
            imSafetyWriter: { imSafety },
            messageWriter: { messageWriter ?? MessageActionWriterSpy() },
            channelMessageDeleteDispatcher: deleteDispatcher
        )
    }

    /// FP-H2: the local block store is only a cache. Without a server-capable service nothing is cached and
    /// no success banner is shown; a server-confirmed block routes through `api/im/block` first.
    func testBlockWithoutServiceNeverCachesLocallyOrReportsSuccess() async {
        let store = InMemoryChannelBlockedUsersStore()
        let coordinator = ClubChannelModerationCoordinator(clubID: 77, viewerMemberID: 501, viewerRoleTier: .member,
                                                           blockedUsersStore: store, service: nil)
        let ok = await coordinator.blockUser(targetMemberID: 602, nickname: "x", shouldBlock: true, activeChannelID: 3001, locale: Locale(identifier: "en"))
        XCTAssertFalse(ok)
        XCTAssertFalse(coordinator.blockedSenderIDs.contains(602))
        XCTAssertTrue(store.blockedUserIDs(clubID: 77, viewerMemberID: 501).isEmpty)
        XCTAssertEqual(coordinator.feedbackBanner?.isError, true)
        XCTAssertEqual(coordinator.feedbackBanner?.canRetry, true)
        XCTAssertEqual(ChannelSafetyModerationEndpoint.blockUser(targetMemberID: 602).apiPath, "api/im/block")
    }

    func testSingleMessageDeleteWithoutPerMessageRouteFailsClosedAndNeverHidesChannel() async {
        let spy = IMSafetyWriterSpy()
        let core = service(imSafety: spy)
        do {
            try await core.performModeration(.deleteMessage(clubID: 77, channelID: 8801, messageID: 555), activeChannelID: 8801)
            XCTFail("delete must fail closed")
        } catch let error as ChannelSafetyServiceError {
            guard case .unsupported(let endpoint) = error else { return XCTFail("unexpected \(error)") }
            XCTAssertEqual(endpoint, .deleteMessage(clubID: 77, channelID: 8801, messageID: 555))
            XCTAssertTrue(error.localizedDescription(locale: Locale(identifier: "en")).contains("not deleted")
                          || error.localizedDescription(locale: Locale(identifier: "en")).contains("was not deleted"))
        } catch { XCTFail("unexpected \(error)") }
        XCTAssertTrue(spy.actions.isEmpty, "no api/im/delete (hide conversation) may be issued for one message")
    }

    func testMemberAndChannelReportsNeverSendAnIDAsMessageID() async {
        let spy = IMSafetyWriterSpy()
        let core = service(imSafety: spy)
        for endpoint in [ChannelSafetyModerationEndpoint.reportClubUser(clubID: 77, targetMemberID: 602, reasonCode: "SPAM", detail: ""),
                         .reportChannel(clubID: 77, channelID: 8801, reasonCode: "SPAM", detail: "")] {
            do {
                try await core.performModeration(endpoint, activeChannelID: 8801)
                XCTFail("must fail closed without a governance route")
            } catch let error as ChannelSafetyServiceError {
                guard case .serviceUnavailable = error else { return XCTFail("unexpected \(error)") }
            } catch { XCTFail("unexpected \(error)") }
        }
        XCTAssertTrue(spy.actions.isEmpty)
    }

    func testMessageReportCarriesRealMessageIDAndUserChosenReason() async throws {
        let spy = IMSafetyWriterSpy()
        let core = service(imSafety: spy)
        try await core.performModeration(.reportMessage(messageID: 555, reason: "HARASSMENT: rude"), activeChannelID: 8801)
        let action = try XCTUnwrap(spy.actions.last)
        XCTAssertEqual(action.path, "api/im/report")
        XCTAssertEqual(action.fields, ["message_id": "555", "reason": "HARASSMENT: rude"])
        XCTAssertNotEqual(action.fields["reason"], IMSafetyAction.reportReason)
        XCTAssertEqual(IMSafetyAction.report(conversationID: 1, messageID: 2).fields["reason"], IMSafetyAction.reportReason,
                       "the 1:1 chat literal stays unchanged")
    }

    func testRetryOfSameDraftSendsSameIdempotencyID() async throws {
        let writer = MessageActionWriterSpy()
        let core = service(imSafety: IMSafetyWriterSpy(), messageWriter: writer)
        let draftID = "w6-12-" + UUID().uuidString.lowercased()
        for _ in 0..<3 {
            _ = try await core.sendChannelMessage(clubID: 77, channelID: 8801, clientMessageID: draftID, content: "hi", replyToMessageID: nil)
        }
        let ids = writer.intents.map(\.clientMessageID)
        XCTAssertEqual(ids.count, 3)
        XCTAssertEqual(Set(ids).count, 1, "retries must reuse one idempotency id")
        XCTAssertEqual(ids[0].count, 32)
        let other = "w6-12-" + UUID().uuidString.lowercased()
        XCTAssertNotEqual(CoreClubChannelSafetyService.stableIdempotencyID(for: other), ids[0])
        let hex = String(repeating: "ab", count: 16)
        XCTAssertEqual(CoreClubChannelSafetyService.stableIdempotencyID(for: hex), hex)
    }
}
