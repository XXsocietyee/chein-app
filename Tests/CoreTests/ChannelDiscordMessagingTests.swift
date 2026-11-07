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
        let memberPolicy = ChannelSafetyModerationPolicy(
            clubID: 77,
            viewerMemberID: 601,
            viewerRoleTier: .member,
            capabilities: ChannelModerationCapabilities()
        )
        let adminPolicy = ChannelSafetyModerationPolicy(
            clubID: 77,
            viewerMemberID: 501,
            viewerRoleTier: .operatorAdmin,
            capabilities: ChannelModerationCapabilities(
                canManageMembers: true,
                canManageBans: true,
                canManageContent: true
            )
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
        let platformBan = ClubOpsBanRow(
            id: 91,
            memberID: 604,
            nickname: "普通队员",
            avatar: "",
            status: "ACTIVE",
            source: "PLATFORM",
            reasonCode: "FRAUD",
            reasonText: "平台风控封禁",
            expiresText: "永久",
            createdText: "04-17 10:00",
            platformOnly: true
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
}
