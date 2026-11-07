import Foundation

// MARK: - W6 Discord-Style Club Channel Directory Models & Projections

/// Last-message preview attached to a channel row in the club channel directory.
public struct DirectoryMessagePreview: Equatable, Sendable {
    public let messageID: Int64
    public let senderName: String
    public let summaryText: String
    public let createdAt: String?

    public init(
        messageID: Int64,
        senderName: String,
        summaryText: String,
        createdAt: String? = nil
    ) {
        self.messageID = messageID
        self.senderName = senderName
        self.summaryText = summaryText
        self.createdAt = createdAt
    }
}

/// Viewer-scoped read/notification state for a club channel (`my_state`).
public struct ChannelDirectoryMyState: Equatable, Sendable {
    public let lastReadMessageID: Int64?
    public let lastReadAt: String?
    /// `0` = all messages, `1` = mentions only, `2` = muted.
    public let notifyPref: Int
    public let unreadCount: Int
    public let readStateAvailable: Bool

    public init(
        lastReadMessageID: Int64?,
        lastReadAt: String?,
        notifyPref: Int,
        unreadCount: Int,
        readStateAvailable: Bool
    ) {
        self.lastReadMessageID = lastReadMessageID
        self.lastReadAt = lastReadAt
        self.notifyPref = notifyPref
        self.unreadCount = unreadCount
        self.readStateAvailable = readStateAvailable
    }
}

/// Category header in a club's channel directory (`api/club/channels`).
public struct ChannelDirectoryCategory: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let clubID: Int64
    public let name: String
    public let position: Int

    public init(id: Int64, clubID: Int64, name: String, position: Int) {
        self.id = id
        self.clubID = clubID
        self.name = name
        self.position = position
    }
}

/// Individual channel entry in a club's channel directory (`api/club/channels`).
public struct ChannelDirectoryEntry: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let clubID: Int64
    public let categoryID: Int64?
    public let name: String
    /// `0` = category node, `1` = text channel, `2` = announcement (read-only for regular members).
    public let kind: Int
    /// `0` = all club members, `>0` = role-restricted channel.
    public let visibility: Int
    public let position: Int
    public let archivedAt: String?
    public let myState: ChannelDirectoryMyState?
    public let lastMessagePreview: DirectoryMessagePreview?

    public init(
        id: Int64,
        clubID: Int64,
        categoryID: Int64?,
        name: String,
        kind: Int,
        visibility: Int,
        position: Int,
        archivedAt: String? = nil,
        myState: ChannelDirectoryMyState? = nil,
        lastMessagePreview: DirectoryMessagePreview? = nil
    ) {
        self.id = id
        self.clubID = clubID
        self.categoryID = categoryID
        self.name = name
        self.kind = kind
        self.visibility = visibility
        self.position = position
        self.archivedAt = archivedAt
        self.myState = myState
        self.lastMessagePreview = lastMessagePreview
    }
}

/// Complete channel directory snapshot for a club.
public struct ChannelDirectoryListing: Equatable, Sendable {
    public let clubID: Int64
    public let categories: [ChannelDirectoryCategory]
    public let channels: [ChannelDirectoryEntry]

    public init(
        clubID: Int64,
        categories: [ChannelDirectoryCategory],
        channels: [ChannelDirectoryEntry]
    ) {
        self.clubID = clubID
        self.categories = categories
        self.channels = channels
    }
}

/// Category-grouped channel item inside a club's Discord-style channel directory.
public struct ChannelDiscordItemProjection: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let clubID: Int64
    public let categoryID: Int64?
    public let name: String
    public let kind: Int
    public let visibility: Int
    public let position: Int
    public let isReadOnlyAnnouncement: Bool
    public let isArchived: Bool
    public let isMuted: Bool
    public let unreadCount: Int?
    public let mentionCount: Int
    public let readStateAvailable: Bool
    public let lastMessagePreview: DirectoryMessagePreview?

    public init(
        id: Int64,
        clubID: Int64,
        categoryID: Int64?,
        name: String,
        kind: Int,
        visibility: Int,
        position: Int,
        isReadOnlyAnnouncement: Bool,
        isArchived: Bool,
        isMuted: Bool,
        unreadCount: Int?,
        mentionCount: Int,
        readStateAvailable: Bool,
        lastMessagePreview: DirectoryMessagePreview?
    ) {
        self.id = id
        self.clubID = clubID
        self.categoryID = categoryID
        self.name = name
        self.kind = kind
        self.visibility = visibility
        self.position = position
        self.isReadOnlyAnnouncement = isReadOnlyAnnouncement
        self.isArchived = isArchived
        self.isMuted = isMuted
        self.unreadCount = unreadCount
        self.mentionCount = mentionCount
        self.readStateAvailable = readStateAvailable
        self.lastMessagePreview = lastMessagePreview
    }

    /// Formatted unread badge ("1"..."99+"), or nil when unread state is unavailable, zero, or muted.
    public var unreadBadgeText: String? {
        guard readStateAvailable, !isMuted, let unreadCount, unreadCount > 0 else {
            return nil
        }
        return IMInboxSummary.badgeText(unreadCount)
    }

    /// Formatted `@mention` badge ("@1"..."@99+"), shown even when the channel is muted.
    public var mentionBadgeText: String? {
        guard readStateAvailable, mentionCount > 0 else {
            return nil
        }
        guard let badge = IMInboxSummary.badgeText(mentionCount) else {
            return nil
        }
        return "@\(badge)"
    }

    /// Leading SF Symbol name representing Discord-style channel semantics.
    public var symbolName: String {
        if isReadOnlyAnnouncement || kind == 2 {
            return "megaphone.fill"
        }
        if visibility > 0 {
            return "lock.fill"
        }
        return "number"
    }
}

/// Category group inside the club channel sidebar.
public struct ChannelDiscordCategoryGroup: Equatable, Sendable, Identifiable {
    public let id: Int64
    public let title: String
    public let position: Int
    public let channels: [ChannelDiscordItemProjection]

    public init(
        id: Int64,
        title: String,
        position: Int,
        channels: [ChannelDiscordItemProjection]
    ) {
        self.id = id
        self.title = title
        self.position = position
        self.channels = channels
    }

    public var totalUnreadCount: Int {
        channels.reduce(0) { partial, channel in
            guard channel.readStateAvailable, !channel.isMuted else { return partial }
            return partial + max(0, channel.unreadCount ?? 0)
        }
    }

    public var totalMentionCount: Int {
        channels.reduce(0) { partial, channel in
            guard channel.readStateAvailable else { return partial }
            return partial + max(0, channel.mentionCount)
        }
    }
}

/// Projects a `ChannelDirectoryListing` + per-channel mention/mute overlays into Discord-style category groups.
public struct ChannelCategoryDirectoryProjection: Equatable, Sendable {
    public let clubID: Int64
    public let groups: [ChannelDiscordCategoryGroup]
    public let totalUnmutedUnreadCount: Int
    public let totalMentionCount: Int
    public let hasUnavailableReadState: Bool

    public init(
        listing: ChannelDirectoryListing,
        mentionCountsByChannelID: [Int64: Int] = [:],
        mutedOverrideByChannelID: [Int64: Bool] = [:],
        unreadOverrideByChannelID: [Int64: Int] = [:],
        uncategorizedTitle: String = "频道"
    ) {
        self.clubID = listing.clubID

        let sortedCategories = listing.categories.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.id < $1.id
        }

        let playableChannels = listing.channels.filter { $0.kind != 0 && $0.archivedAt == nil }
        let sortedChannels = playableChannels.sorted {
            if $0.position != $1.position { return $0.position < $1.position }
            return $0.id < $1.id
        }

        var hasUnavailable = false
        func projectChannel(_ entry: ChannelDirectoryEntry) -> ChannelDiscordItemProjection {
            let stateAvailable = entry.myState?.readStateAvailable == true
            if !stateAvailable {
                hasUnavailable = true
            }
            let baseMuted = (entry.myState?.notifyPref ?? 0) == 2
            let isMuted = mutedOverrideByChannelID[entry.id] ?? baseMuted
            let rawUnread: Int?
            if stateAvailable {
                let value = unreadOverrideByChannelID[entry.id] ?? entry.myState?.unreadCount ?? 0
                rawUnread = max(0, value)
            } else {
                rawUnread = nil
            }
            let mentions = stateAvailable ? max(0, mentionCountsByChannelID[entry.id] ?? 0) : 0
            return ChannelDiscordItemProjection(
                id: entry.id,
                clubID: entry.clubID,
                categoryID: entry.categoryID,
                name: entry.name,
                kind: entry.kind,
                visibility: entry.visibility,
                position: entry.position,
                isReadOnlyAnnouncement: entry.kind == 2,
                isArchived: entry.archivedAt != nil,
                isMuted: isMuted,
                unreadCount: rawUnread,
                mentionCount: mentions,
                readStateAvailable: stateAvailable,
                lastMessagePreview: entry.lastMessagePreview
            )
        }

        let projectedAll = sortedChannels.map(projectChannel)
        let knownCategoryIDs = Set(sortedCategories.map { $0.id })

        var builtGroups: [ChannelDiscordCategoryGroup] = []
        let uncategorized = projectedAll.filter { channel in
            guard let categoryID = channel.categoryID else { return true }
            return !knownCategoryIDs.contains(categoryID)
        }
        if !uncategorized.isEmpty {
            builtGroups.append(
                ChannelDiscordCategoryGroup(
                    id: 0,
                    title: uncategorizedTitle,
                    position: -1,
                    channels: uncategorized
                )
            )
        }

        for category in sortedCategories {
            let categoryChannels = projectedAll.filter { $0.categoryID == category.id }
            if !categoryChannels.isEmpty {
                builtGroups.append(
                    ChannelDiscordCategoryGroup(
                        id: category.id,
                        title: category.name,
                        position: category.position,
                        channels: categoryChannels
                    )
                )
            }
        }

        self.groups = builtGroups
        self.totalUnmutedUnreadCount = builtGroups.reduce(0) { $0 + $1.totalUnreadCount }
        self.totalMentionCount = builtGroups.reduce(0) { $0 + $1.totalMentionCount }
        self.hasUnavailableReadState = hasUnavailable
    }

    public var totalUnreadBadgeText: String? {
        IMInboxSummary.badgeText(totalUnmutedUnreadCount)
    }

    /// Returns a new projection after marking `channelID` as read up to the latest message.
    public func markingChannelRead(
        _ channelID: Int64,
        listing: ChannelDirectoryListing,
        mentionCountsByChannelID: [Int64: Int] = [:],
        mutedOverrideByChannelID: [Int64: Bool] = [:],
        unreadOverrideByChannelID: [Int64: Int] = [:]
    ) -> ChannelCategoryDirectoryProjection {
        var nextMentions = mentionCountsByChannelID
        nextMentions[channelID] = 0
        var nextUnreads = unreadOverrideByChannelID
        nextUnreads[channelID] = 0
        return ChannelCategoryDirectoryProjection(
            listing: listing,
            mentionCountsByChannelID: nextMentions,
            mutedOverrideByChannelID: mutedOverrideByChannelID,
            unreadOverrideByChannelID: nextUnreads
        )
    }
}

// MARK: - Discord-Style Message Author/Time Burst Grouping, Replies/Threads, and Attachments

/// Inline reply or thread reference attached to a channel message.
public struct ChannelReplyThreadReference: Equatable, Sendable {
    public let replyToMessageID: Int
    public let replyAuthorName: String
    public let replyPreviewText: String
    public let threadRootMessageID: Int?
    public let threadReplyCount: Int

    public init(
        replyToMessageID: Int,
        replyAuthorName: String,
        replyPreviewText: String,
        threadRootMessageID: Int? = nil,
        threadReplyCount: Int = 0
    ) {
        self.replyToMessageID = replyToMessageID
        self.replyAuthorName = replyAuthorName
        self.replyPreviewText = replyPreviewText
        self.threadRootMessageID = threadRootMessageID
        self.threadReplyCount = max(0, threadReplyCount)
    }
}

/// Attachment/media projection aligned with backend `ImMessage.type` (1=text, 2=image, 3=card/poll, 13=location).
public enum ChannelAttachmentKind: String, Equatable, Sendable {
    case image
    case pollCard
    case routeOrActivityCard
    case locationPin
    case fileDocument
}

public struct ChannelAttachmentProjection: Equatable, Sendable {
    public let kind: ChannelAttachmentKind
    public let url: String?
    public let title: String
    public let subtitle: String?
    public let isOriginApproved: Bool

    public init(
        kind: ChannelAttachmentKind,
        url: String?,
        title: String,
        subtitle: String? = nil,
        isOriginApproved: Bool = true
    ) {
        self.kind = kind
        self.url = url
        self.title = title
        self.subtitle = subtitle
        self.isOriginApproved = isOriginApproved
    }
}

/// Wire-compatible helper to construct `MessagingMessage` instances and carry optimistic client metadata.
public struct ChannelTranscriptMessage: Equatable, Identifiable {
    public var id: String {
        if let clientMessageID, !clientMessageID.isEmpty, wireMessage.id <= 0 {
            return "client-\(clientMessageID)"
        }
        return "msg-\(wireMessage.id)-\(clientMessageID ?? "")"
    }

    public let wireMessage: MessagingMessage
    public var clientMessageID: String?
    public var sendState: String?
    public var mediaURL: String?

    public init(
        wireMessage: MessagingMessage,
        clientMessageID: String? = nil,
        sendState: String? = nil,
        mediaURL: String? = nil
    ) {
        self.wireMessage = wireMessage
        self.clientMessageID = clientMessageID
        self.sendState = sendState
        self.mediaURL = mediaURL
    }

    /// Creates a `ChannelTranscriptMessage` backed by a decoded `MessagingMessage`.
    public static func make(
        id: Int,
        conversationID: Int,
        senderID: Int?,
        senderName: String? = nil,
        senderAvatar: String? = nil,
        type: Int = 1,
        content: String? = nil,
        extraJSON: String? = nil,
        mediaURL: String? = nil,
        statusWireValue: Int = 0,
        sendState: String? = nil,
        createdAt: String? = nil,
        clientMessageID: String? = nil
    ) -> ChannelTranscriptMessage {
        let safeID = max(1, id)
        let safeConversationID = max(1, conversationID)
        var payload: [String: Any] = [
            "id": safeID,
            "conversationId": safeConversationID,
            "status": statusWireValue
        ]
        if let senderID { payload["senderId"] = senderID }
        if let senderName { payload["senderName"] = senderName }
        if let senderAvatar { payload["senderAvatar"] = senderAvatar }
        payload["msgType"] = type
        if let content { payload["content"] = content }
        if let extraJSON { payload["extraJson"] = extraJSON }
        if let createdAt { payload["createTime"] = createdAt }

        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data()
        let decoded = try! JSONDecoder().decode(MessagingMessage.self, from: data)
        return ChannelTranscriptMessage(
            wireMessage: decoded,
            clientMessageID: clientMessageID,
            sendState: sendState,
            mediaURL: mediaURL
        )
    }
}

/// Individual message item inside a Discord-style author/time burst group.
public struct ChannelBurstMessageItem: Equatable, Identifiable {
    public let id: String
    public let transcriptMessage: ChannelTranscriptMessage
    public var message: MessagingMessage { transcriptMessage.wireMessage }
    public let isFirstInBurst: Bool
    public let displayBody: String
    public let isFilteredBySafetyHook: Bool
    public let replyReference: ChannelReplyThreadReference?
    public let attachments: [ChannelAttachmentProjection]
    /// Backend `ApiImController` does not expose emoji reaction endpoints; kept false per spec ("reactions only if the backend supports them").
    public let supportsReactions: Bool

    public init(
        transcriptMessage: ChannelTranscriptMessage,
        isFirstInBurst: Bool,
        displayBody: String,
        isFilteredBySafetyHook: Bool = false,
        replyReference: ChannelReplyThreadReference? = nil,
        attachments: [ChannelAttachmentProjection] = [],
        supportsReactions: Bool = false
    ) {
        self.id = transcriptMessage.id
        self.transcriptMessage = transcriptMessage
        self.isFirstInBurst = isFirstInBurst
        self.displayBody = displayBody
        self.isFilteredBySafetyHook = isFilteredBySafetyHook
        self.replyReference = replyReference
        self.attachments = attachments
        self.supportsReactions = supportsReactions
    }
}

/// A group of consecutive messages sent by the same author within a 5-minute window.
public struct ChannelMessageBurstGroup: Equatable, Identifiable {
    public let id: String
    public let senderID: Int
    public let senderName: String
    public let senderAvatar: String
    public let senderRoleBadge: String?
    public let headerTimestampText: String
    public let precedingDividerText: String?
    public let isSystemGroup: Bool
    public let items: [ChannelBurstMessageItem]

    public init(
        id: String,
        senderID: Int,
        senderName: String,
        senderAvatar: String,
        senderRoleBadge: String?,
        headerTimestampText: String,
        precedingDividerText: String?,
        isSystemGroup: Bool,
        items: [ChannelBurstMessageItem]
    ) {
        self.id = id
        self.senderID = senderID
        self.senderName = senderName
        self.senderAvatar = senderAvatar
        self.senderRoleBadge = senderRoleBadge
        self.headerTimestampText = headerTimestampText
        self.precedingDividerText = precedingDividerText
        self.isSystemGroup = isSystemGroup
        self.items = items
    }
}

/// Groups channel messages by author and time window (default 300s / 5 minutes), respecting visibility, content filters, and reply/attachment projections.
public enum ChannelMessageBurstGrouper {
    public static let defaultBurstWindowSeconds: TimeInterval = 5 * 60
    /// Confirmed in `ApiImController.java`: no reaction endpoints exist in backend IM contract.
    public static let backendSupportsReactions: Bool = false

    public static func formatDivider(_ divider: IMInboxTime.DividerText) -> String {
        switch divider {
        case let .today(clock):
            return "今天 \(clock)"
        case let .yesterday(clock):
            return "昨天 \(clock)"
        case let .date(month, day, clock):
            return String(format: "%02d-%02d %@", month, day, clock)
        }
    }

    public static func group(
        messages: [ChannelTranscriptMessage],
        roleBadgeByMemberID: [Int: String] = [:],
        replyReferencesByMessageID: [Int: ChannelReplyThreadReference] = [:],
        contentFilter: ChannelContentFilterHook = .default,
        burstWindowSeconds: TimeInterval = defaultBurstWindowSeconds,
        now: Date = Date()
    ) -> [ChannelMessageBurstGroup] {
        // Filter out messages from blocked senders immediately (App Store 1.2 safety requirement)
        let visibleAfterBlock = messages.filter { item in
            !contentFilter.shouldHideMessageImmediately(item.wireMessage)
        }
        guard !visibleAfterBlock.isEmpty else { return [] }

        let wireMessages = visibleAfterBlock.map(\.wireMessage)
        let dividersByMessageID = IMInboxTime.dividers(for: wireMessages, now: now)

        var groups: [ChannelMessageBurstGroup] = []
        var currentMessages: [ChannelTranscriptMessage] = []
        var currentDividerText: String?
        var currentLastDate: Date?

        func flushCurrentGroup() {
            guard let first = currentMessages.first else { return }
            let firstWire = first.wireMessage
            let firstSenderID = firstWire.senderID ?? 0
            let isSystem = firstWire.isPayloadVisible && (firstSenderID <= 0 || firstWire.type == 99 || firstWire.type == 100)
            let headerTimestamp = firstWire.createdAt.flatMap {
                IMInboxTime.parse($0)
            }.map {
                formatDivider(IMInboxTime.dividerText($0, now: now))
            } ?? (firstWire.createdAt ?? "")

            let burstItems: [ChannelBurstMessageItem] = currentMessages.enumerated().map { index, item in
                let filterResult = contentFilter.evaluate(message: item.wireMessage)
                let attachments = projectAttachments(for: item)
                let replyRef = extractReplyReference(
                    for: item.wireMessage,
                    allMessages: wireMessages,
                    explicitReferences: replyReferencesByMessageID
                )
                return ChannelBurstMessageItem(
                    transcriptMessage: item,
                    isFirstInBurst: index == 0,
                    displayBody: filterResult.displayText,
                    isFilteredBySafetyHook: filterResult.wasModified,
                    replyReference: replyRef,
                    attachments: attachments,
                    supportsReactions: backendSupportsReactions
                )
            }

            let senderName: String
            if let rawName = firstWire.senderName?.trimmingCharacters(in: .whitespacesAndNewlines), !rawName.isEmpty {
                senderName = rawName
            } else if !firstWire.isPayloadVisible {
                senderName = "已撤回/屏蔽消息"
            } else if isSystem {
                senderName = "系统通知"
            } else {
                senderName = "成员 #\(firstSenderID)"
            }

            groups.append(
                ChannelMessageBurstGroup(
                    id: "burst-\(first.id)",
                    senderID: firstSenderID,
                    senderName: senderName,
                    senderAvatar: firstWire.senderAvatar ?? "",
                    senderRoleBadge: roleBadgeByMemberID[firstSenderID],
                    headerTimestampText: headerTimestamp,
                    precedingDividerText: currentDividerText,
                    isSystemGroup: isSystem,
                    items: burstItems
                )
            )
            currentMessages.removeAll(keepingCapacity: true)
            currentDividerText = nil
            currentLastDate = nil
        }

        for (index, item) in visibleAfterBlock.enumerated() {
            let message = item.wireMessage
            let rawDivider = dividersByMessageID[message.id].map(formatDivider)
            // The first message in the transcript always gets a divider in `IMInboxTime.dividers`,
            // while subsequent dividers indicate a >5m gap.
            let gapDivider = index == 0 ? nil : rawDivider
            let parsedDate = IMInboxTime.parse(message.createdAt)
            let senderID = message.senderID ?? 0
            let isSystemOrTombstone = senderID <= 0 || !message.isPayloadVisible

            if let previous = currentMessages.last?.wireMessage {
                let prevSenderID = previous.senderID ?? 0
                let previousIsSystemOrTombstone = prevSenderID <= 0 || !previous.isPayloadVisible
                let sameSender = prevSenderID == senderID && senderID > 0
                let withinWindow: Bool
                if let prevDate = currentLastDate, let currDate = parsedDate {
                    let delta = currDate.timeIntervalSince(prevDate)
                    withinWindow = delta >= 0 && delta < burstWindowSeconds
                } else {
                    withinWindow = gapDivider == nil
                }

                if sameSender && !isSystemOrTombstone && !previousIsSystemOrTombstone && gapDivider == nil && withinWindow {
                    currentMessages.append(item)
                    if let parsedDate {
                        currentLastDate = parsedDate
                    }
                    continue
                } else {
                    flushCurrentGroup()
                }
            }

            currentDividerText = rawDivider
            currentMessages = [item]
            currentLastDate = parsedDate
        }

        flushCurrentGroup()
        return groups
    }

    public static func projectAttachments(for item: ChannelTranscriptMessage) -> [ChannelAttachmentProjection] {
        let message = item.wireMessage
        guard message.isPayloadVisible else { return [] }
        var result: [ChannelAttachmentProjection] = []

        if message.type == 2 {
            let rawURL = (item.mediaURL?.isEmpty == false ? item.mediaURL : message.content) ?? ""
            result.append(
                ChannelAttachmentProjection(
                    kind: .image,
                    url: rawURL,
                    title: "图片附件",
                    subtitle: nil,
                    isOriginApproved: isApprovedAttachmentURL(rawURL)
                )
            )
        } else if message.type == 3 {
            let text = message.content ?? ""
            if text.contains("poll_id") || text.contains("投票") {
                result.append(
                    ChannelAttachmentProjection(
                        kind: .pollCard,
                        url: item.mediaURL,
                        title: "频道投票卡片",
                        subtitle: text
                    )
                )
            } else {
                result.append(
                    ChannelAttachmentProjection(
                        kind: .routeOrActivityCard,
                        url: item.mediaURL,
                        title: message.card?.title ?? "俱乐部活动/路线卡片",
                        subtitle: message.card?.subtitle ?? text
                    )
                )
            }
        } else if message.type == 13 {
            result.append(
                ChannelAttachmentProjection(
                    kind: .locationPin,
                    url: item.mediaURL,
                    title: "位置分享",
                    subtitle: message.content
                )
            )
        }

        return result
    }

    private static func isApprovedAttachmentURL(_ raw: String) -> Bool {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.hasPrefix("https://") || trimmed.hasPrefix("http://127.0.0.1") || trimmed.hasPrefix("http://localhost")
    }

    private static func extractReplyReference(
        for message: MessagingMessage,
        allMessages: [MessagingMessage],
        explicitReferences: [Int: ChannelReplyThreadReference]
    ) -> ChannelReplyThreadReference? {
        if let explicit = explicitReferences[message.id] {
            return explicit
        }
        guard let body = message.content, body.hasPrefix("> #") else {
            return nil
        }
        let digits = body.dropFirst(3).prefix { $0.isNumber }
        guard let targetID = Int(digits), targetID > 0 else {
            return nil
        }
        let parent = allMessages.first { $0.id == targetID }
        let author = parent?.senderName ?? "成员 #\(parent?.senderID ?? 0)"
        let preview = parent?.isPayloadVisible == true ? (parent?.content ?? "") : "原消息不可用"
        let replyCount = allMessages.filter {
            guard let text = $0.content else { return false }
            return text.hasPrefix("> #\(targetID)")
        }.count
        return ChannelReplyThreadReference(
            replyToMessageID: targetID,
            replyAuthorName: author,
            replyPreviewText: preview,
            threadRootMessageID: targetID,
            threadReplyCount: replyCount
        )
    }
}

// MARK: - Optimistic Send, Send-Receipt Recovery (`POST /api/im/send-receipt`), and Retry State Machine

/// Explicit send state for an outbound channel message.
public enum ChannelOutboundSendPhase: String, Equatable, Sendable {
    case pending
    case sending
    case sent
    case failed
    case verifyingReceipt
}

public struct ChannelOutboundMessageRecord: Equatable, Identifiable {
    public var id: String { clientMessageID }
    public let conversationID: Int
    public let clientMessageID: String
    public let senderID: Int
    public let content: String
    public let messageType: Int
    public let replyToMessageID: Int?
    public let createdAt: String
    public var phase: ChannelOutboundSendPhase
    public var attemptCount: Int
    public var failureReason: String?
    public var confirmedServerMessage: MessagingMessage?

    public init(
        conversationID: Int,
        clientMessageID: String,
        senderID: Int,
        content: String,
        messageType: Int = 1,
        replyToMessageID: Int? = nil,
        createdAt: String,
        phase: ChannelOutboundSendPhase = .pending,
        attemptCount: Int = 0,
        failureReason: String? = nil,
        confirmedServerMessage: MessagingMessage? = nil
    ) {
        self.conversationID = conversationID
        self.clientMessageID = clientMessageID
        self.senderID = senderID
        self.content = content
        self.messageType = messageType
        self.replyToMessageID = replyToMessageID
        self.createdAt = createdAt
        self.phase = phase
        self.attemptCount = attemptCount
        self.failureReason = failureReason
        self.confirmedServerMessage = confirmedServerMessage
    }

    public var canRetry: Bool {
        phase == .failed && confirmedServerMessage == nil
    }

    /// Projects this outbound record as a `ChannelTranscriptMessage` for immediate display in the transcript.
    public func asOptimisticTranscriptMessage(
        syntheticID: Int = 999_999,
        senderName: String? = nil,
        senderAvatar: String? = nil
    ) -> ChannelTranscriptMessage {
        if let confirmedServerMessage {
            return ChannelTranscriptMessage(
                wireMessage: confirmedServerMessage,
                clientMessageID: clientMessageID,
                sendState: ChannelOutboundSendPhase.sent.rawValue
            )
        }
        return ChannelTranscriptMessage.make(
            id: syntheticID,
            conversationID: conversationID,
            senderID: senderID,
            senderName: senderName,
            senderAvatar: senderAvatar,
            type: messageType,
            content: content,
            sendState: phase.rawValue,
            createdAt: createdAt,
            clientMessageID: clientMessageID
        )
    }
}

/// Resolution produced when retrying a failed/uncertain send via `OrdinaryIMSendReceiptResult`.
public enum ChannelSendRetryResolution: Equatable {
    /// `POST /api/im/send-receipt` returned `found: true`; reconciled to `.sent` without re-sending `POST /api/im/send`.
    case reconciledFromReceipt(MessagingMessage)
    /// `POST /api/im/send-receipt` returned `found: false`; caller must re-post `POST /api/im/send` using the identical `clientMessageID`.
    case resendRequired(clientMessageID: String, attempt: Int)
    /// Message is not in a retryable state.
    case ignored
}

/// Deterministic state machine for optimistic channel sends, receipt recovery (`POST /api/im/send-receipt`), and deduplicated polling merge.
public struct ChannelSendStateMachine: Equatable {
    public let conversationID: Int
    public let accountEpoch: Int64
    public private(set) var recordsByClientID: [String: ChannelOutboundMessageRecord]
    public private(set) var orderedClientIDs: [String]

    public init(conversationID: Int, accountEpoch: Int64 = 1) {
        self.conversationID = conversationID
        self.accountEpoch = accountEpoch
        self.recordsByClientID = [:]
        self.orderedClientIDs = []
    }

    public var orderedRecords: [ChannelOutboundMessageRecord] {
        orderedClientIDs.compactMap { recordsByClientID[$0] }
    }

    /// Enqueues a new optimistic message in `.pending` state.
    @discardableResult
    public mutating func enqueueOptimistic(
        clientMessageID: String,
        senderID: Int,
        content: String,
        messageType: Int = 1,
        replyToMessageID: Int? = nil,
        createdAt: String = "2026-04-17T12:00:00"
    ) -> ChannelOutboundMessageRecord {
        let normalizedID = clientMessageID.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = recordsByClientID[normalizedID] {
            return existing
        }
        let record = ChannelOutboundMessageRecord(
            conversationID: conversationID,
            clientMessageID: normalizedID,
            senderID: senderID,
            content: content,
            messageType: messageType,
            replyToMessageID: replyToMessageID,
            createdAt: createdAt,
            phase: .pending,
            attemptCount: 0
        )
        recordsByClientID[normalizedID] = record
        orderedClientIDs.append(normalizedID)
        return record
    }

    /// Transitions a `.pending` or `.failed` message into `.sending`.
    @discardableResult
    public mutating func markSending(clientMessageID: String) -> ChannelOutboundMessageRecord? {
        guard var record = recordsByClientID[clientMessageID] else { return nil }
        guard record.phase == .pending || record.phase == .failed || record.phase == .verifyingReceipt else {
            return record
        }
        record.phase = .sending
        record.attemptCount += 1
        record.failureReason = nil
        recordsByClientID[clientMessageID] = record
        return record
    }

    /// Marks an outbound message as `.sent` when `POST /api/im/send` returns the persisted message.
    @discardableResult
    public mutating func markSent(
        clientMessageID: String,
        serverMessage: MessagingMessage
    ) -> ChannelOutboundMessageRecord? {
        guard var record = recordsByClientID[clientMessageID] else { return nil }
        record.phase = .sent
        record.failureReason = nil
        record.confirmedServerMessage = serverMessage
        recordsByClientID[clientMessageID] = record
        return record
    }

    /// Marks an outbound message as `.failed` so the user can retry or inspect the failure.
    @discardableResult
    public mutating func markFailed(
        clientMessageID: String,
        reason: String
    ) -> ChannelOutboundMessageRecord? {
        guard var record = recordsByClientID[clientMessageID] else { return nil }
        guard record.phase != .sent else { return record }
        record.phase = .failed
        record.failureReason = reason
        recordsByClientID[clientMessageID] = record
        return record
    }

    /// Begins a retry by transitioning `.failed` -> `.verifyingReceipt` before calling `POST /api/im/send-receipt`.
    @discardableResult
    public mutating func beginRetryWithReceiptCheck(clientMessageID: String) -> Bool {
        guard var record = recordsByClientID[clientMessageID], record.canRetry else {
            return false
        }
        record.phase = .verifyingReceipt
        recordsByClientID[clientMessageID] = record
        return true
    }

    /// Applies the `OrdinaryIMSendReceiptResult` from `POST /api/im/send-receipt` before deciding whether to resend `POST /api/im/send`.
    public mutating func resolveRetryAfterReceiptCheck(
        clientMessageID: String,
        receiptResult: OrdinaryIMSendReceiptResult
    ) -> ChannelSendRetryResolution {
        guard var record = recordsByClientID[clientMessageID] else {
            return .ignored
        }
        guard record.phase == .verifyingReceipt || record.phase == .failed else {
            return .ignored
        }
        switch receiptResult {
        case let .found(serverMessage):
            record.phase = .sent
            record.failureReason = nil
            record.confirmedServerMessage = serverMessage
            recordsByClientID[clientMessageID] = record
            return .reconciledFromReceipt(serverMessage)
        case .notFound:
            record.phase = .sending
            record.attemptCount += 1
            record.failureReason = nil
            recordsByClientID[clientMessageID] = record
            return .resendRequired(clientMessageID: record.clientMessageID, attempt: record.attemptCount)
        }
    }

    /// Merges confirmed server transcript messages with any still-unconfirmed optimistic records, deduplicating by `clientMessageID` and `id`.
    public mutating func mergedTranscript(
        serverMessages: [ChannelTranscriptMessage],
        senderName: String? = nil,
        senderAvatar: String? = nil
    ) -> [ChannelTranscriptMessage] {
        let serverByClientID = Dictionary(
            serverMessages.compactMap { msg -> (String, ChannelTranscriptMessage)? in
                guard let cid = msg.clientMessageID, !cid.isEmpty else { return nil }
                return (cid, msg)
            },
            uniquingKeysWith: { _, latest in latest }
        )
        let serverIDs = Set(serverMessages.map { $0.wireMessage.id })

        for (cid, var record) in recordsByClientID {
            if let matched = serverByClientID[cid] {
                record.phase = .sent
                record.failureReason = nil
                record.confirmedServerMessage = matched.wireMessage
                recordsByClientID[cid] = record
            } else if let confirmedID = record.confirmedServerMessage?.id, serverIDs.contains(confirmedID) {
                record.phase = .sent
                recordsByClientID[cid] = record
            }
        }

        var combined = serverMessages
        for (idx, cid) in orderedClientIDs.enumerated() {
            guard let record = recordsByClientID[cid] else { continue }
            if serverByClientID[cid] != nil {
                continue
            }
            if let confirmedID = record.confirmedServerMessage?.id, serverIDs.contains(confirmedID) {
                continue
            }
            combined.append(
                record.asOptimisticTranscriptMessage(
                    syntheticID: 900_000 + idx,
                    senderName: senderName,
                    senderAvatar: senderAvatar
                )
            )
        }
        return combined
    }
}

// MARK: - Paging Up, New-Message Jump, and Real-Time Polling with Backoff (`POLL_MS = 8000`)

/// Exponential backoff schedule for channel polling, matching the mini-program's 8-second real-time poll (`subpackageB/pages/im/chat/index.js`).
public struct ChannelPollingBackoffSchedule: Equatable, Sendable {
    public static let baseIntervalMilliseconds: Int = 8_000
    public static let maxIntervalMilliseconds: Int = 60_000

    public private(set) var consecutiveFailures: Int = 0
    public private(set) var isStoppedForTerminalError: Bool = false
    public private(set) var terminalErrorCode: String?

    public init() {}

    public var nextDelayMilliseconds: Int? {
        guard !isStoppedForTerminalError else { return nil }
        guard consecutiveFailures > 0 else { return Self.baseIntervalMilliseconds }
        let shift = min(consecutiveFailures, 4)
        let multiplied = Self.baseIntervalMilliseconds * (1 << shift)
        return min(multiplied, Self.maxIntervalMilliseconds)
    }

    public mutating func recordSuccess() {
        guard !isStoppedForTerminalError else { return }
        consecutiveFailures = 0
    }

    public mutating func recordFailure(errorCode: String? = nil, httpStatus: Int? = nil) {
        if let errorCode,
           ["IM_HISTORY_ACCESS_DENIED", "IM_CONVERSATION_CLOSED", "HANGOUT_CLOSED"].contains(errorCode) {
            isStoppedForTerminalError = true
            terminalErrorCode = errorCode
            return
        }
        if let httpStatus, [401, 403, 409].contains(httpStatus) {
            isStoppedForTerminalError = true
            terminalErrorCode = errorCode ?? "HTTP_\(httpStatus)"
            return
        }
        consecutiveFailures += 1
    }
}

/// Manages transcript scroll position, upward pagination anchor, and the "Jump to new messages" pill.
public struct ChannelTranscriptViewportState: Equatable {
    public static let nearBottomThresholdPoints: Double = 120.0

    public private(set) var messages: [ChannelTranscriptMessage]
    public private(set) var oldestCursorID: Int?
    public private(set) var hasMoreOlderPages: Bool
    public private(set) var isNearBottom: Bool
    public private(set) var pendingNewMessageCount: Int
    public private(set) var firstUnreadNewMessageID: Int?
    public private(set) var preservedScrollAnchorMessageID: Int?
    public private(set) var watermarkMessageID: Int

    public init(
        initialMessages: [ChannelTranscriptMessage] = [],
        hasMoreOlderPages: Bool = false
    ) {
        let sorted = initialMessages.sorted { $0.wireMessage.id < $1.wireMessage.id }
        self.messages = sorted
        self.oldestCursorID = sorted.first?.wireMessage.id
        self.hasMoreOlderPages = hasMoreOlderPages
        self.isNearBottom = true
        self.pendingNewMessageCount = 0
        self.firstUnreadNewMessageID = nil
        self.preservedScrollAnchorMessageID = nil
        self.watermarkMessageID = sorted.map { $0.wireMessage.id }.max() ?? 0
    }

    public var showNewMessageJumpBanner: Bool {
        !isNearBottom && pendingNewMessageCount > 0
    }

    public mutating func updateScrollDistanceFromBottom(_ distancePoints: Double) {
        let near = distancePoints <= Self.nearBottomThresholdPoints
        isNearBottom = near
        if near {
            pendingNewMessageCount = 0
            firstUnreadNewMessageID = nil
        }
    }

    /// Prepends an older page fetched via `cursor_id`, preserving the top visible message ID so scroll position does not jump.
    public mutating func prependOlderPage(
        _ olderMessages: [ChannelTranscriptMessage],
        hasMore: Bool,
        currentTopVisibleMessageID: Int?
    ) {
        preservedScrollAnchorMessageID = currentTopVisibleMessageID ?? messages.first?.wireMessage.id
        var byID: [Int: ChannelTranscriptMessage] = [:]
        for msg in olderMessages {
            byID[msg.wireMessage.id] = msg
        }
        for msg in messages {
            byID[msg.wireMessage.id] = msg
        }
        messages = byID.values.sorted { $0.wireMessage.id < $1.wireMessage.id }
        oldestCursorID = messages.first?.wireMessage.id
        hasMoreOlderPages = hasMore
    }

    /// Merges polled messages (`POST /api/im/messages`); auto-scrolls when near bottom or increments the new-message jump counter when scrolled up.
    public mutating func applyPolledMessages(
        _ polled: [ChannelTranscriptMessage],
        viewerAccountID: Int
    ) {
        let existingIDs = Set(messages.map { $0.wireMessage.id })
        let genuinelyNew = polled.filter { msg in
            let id = msg.wireMessage.id
            guard id > watermarkMessageID else { return false }
            return !existingIDs.contains(id)
        }

        var byID: [Int: ChannelTranscriptMessage] = [:]
        for msg in messages {
            byID[msg.wireMessage.id] = msg
        }
        for msg in polled {
            byID[msg.wireMessage.id] = msg
        }
        messages = byID.values.sorted { $0.wireMessage.id < $1.wireMessage.id }
        if let maxID = messages.map({ $0.wireMessage.id }).max(), maxID > watermarkMessageID {
            watermarkMessageID = maxID
        }

        let newFromOthers = genuinelyNew.filter { ($0.wireMessage.senderID ?? 0) != viewerAccountID }
        guard !newFromOthers.isEmpty else { return }

        if isNearBottom {
            pendingNewMessageCount = 0
            firstUnreadNewMessageID = nil
        } else {
            if firstUnreadNewMessageID == nil {
                firstUnreadNewMessageID = newFromOthers.map { $0.wireMessage.id }.min()
            }
            pendingNewMessageCount += newFromOthers.count
        }
    }

    /// Handles tapping the "Jump to new messages" banner.
    @discardableResult
    public mutating func jumpToBottomClearingNewMessages() -> Int? {
        let targetID = firstUnreadNewMessageID ?? messages.last?.wireMessage.id
        isNearBottom = true
        pendingNewMessageCount = 0
        firstUnreadNewMessageID = nil
        return targetID
    }
}

// MARK: - Member List with Roles (`ChannelMemberRoleRoster`)

public enum ChannelMemberRoleTier: Int, Comparable, Equatable, Sendable, CaseIterable {
    case owner = 0
    case coOwner = 1
    case operatorAdmin = 2
    case eventStaff = 3
    case member = 4

    public static func < (lhs: ChannelMemberRoleTier, rhs: ChannelMemberRoleTier) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    public var sectionTitle: String {
        switch self {
        case .owner: return "主理人"
        case .coOwner: return "联席主理人"
        case .operatorAdmin: return "运营管理员"
        case .eventStaff: return "活动领队与核销"
        case .member: return "俱乐部成员"
        }
    }
}

public struct ChannelMemberRoleItem: Equatable, Sendable, Identifiable {
    public var id: Int { memberID }
    public let memberID: Int
    public let nickname: String
    public let avatar: String
    public let tier: ChannelMemberRoleTier
    public let roleCode: String
    public let badgeLabel: String
    public let holdsActiveRoleAssignment: Bool
    public let expiresText: String?

    public init(
        memberID: Int,
        nickname: String,
        avatar: String = "",
        tier: ChannelMemberRoleTier,
        roleCode: String,
        badgeLabel: String,
        holdsActiveRoleAssignment: Bool = false,
        expiresText: String? = nil
    ) {
        self.memberID = memberID
        self.nickname = nickname
        self.avatar = avatar
        self.tier = tier
        self.roleCode = roleCode
        self.badgeLabel = badgeLabel
        self.holdsActiveRoleAssignment = holdsActiveRoleAssignment
        self.expiresText = expiresText
    }
}

public struct ChannelMemberRoleSection: Equatable, Sendable, Identifiable {
    public var id: Int { tier.rawValue }
    public let tier: ChannelMemberRoleTier
    public let title: String
    public let members: [ChannelMemberRoleItem]

    public init(tier: ChannelMemberRoleTier, members: [ChannelMemberRoleItem]) {
        self.tier = tier
        self.title = "\(tier.sectionTitle) — \(members.count)"
        self.members = members
    }
}

public enum ChannelMemberRoleRoster {
    public static func buildSections(from members: [ChannelMemberRoleItem]) -> [ChannelMemberRoleSection] {
        let sorted = members.sorted {
            if $0.tier != $1.tier { return $0.tier < $1.tier }
            return $0.memberID < $1.memberID
        }
        return ChannelMemberRoleTier.allCases.compactMap { tier in
            let matching = sorted.filter { $0.tier == tier }
            guard !matching.isEmpty else { return nil }
            return ChannelMemberRoleSection(tier: tier, members: matching)
        }
    }

    public static func tier(forRoleCode roleCode: String) -> ChannelMemberRoleTier {
        switch roleCode.uppercased() {
        case "CLUB_OWNER", "OWNER":
            return .owner
        case "CLUB_CO_OWNER", "CO_OWNER":
            return .coOwner
        case "CLUB_OPERATOR", "OPERATOR", "ADMIN":
            return .operatorAdmin
        case "EVENT_LEAD", "EVENT_CHECKIN":
            return .eventStaff
        default:
            return .member
        }
    }
}

// MARK: - Safety (App Store Guideline 1.2) & Admin Moderation Controller

public struct ChannelContentFilterEvaluation: Equatable, Sendable {
    public let displayText: String
    public let wasModified: Bool
    public let matchedTerms: [String]

    public init(displayText: String, wasModified: Bool, matchedTerms: [String] = []) {
        self.displayText = displayText
        self.wasModified = wasModified
        self.matchedTerms = matchedTerms
    }
}

/// Pluggable content filtering hook required by App Store Review Guideline 1.2 for UGC channel messaging.
public struct ChannelContentFilterHook: Equatable, Sendable {
    public static let defaultObjectionableTerms: [String] = [
        "赌博", "诈骗", "洗钱", "外挂", "代刷", "色情", "微信号加我领奖"
    ]

    public let blockedSenderIDs: Set<Int>
    public let mutedKeywords: [String]
    public let maskObjectionableContent: Bool

    public init(
        blockedSenderIDs: Set<Int> = [],
        mutedKeywords: [String] = Self.defaultObjectionableTerms,
        maskObjectionableContent: Bool = true
    ) {
        self.blockedSenderIDs = blockedSenderIDs
        self.mutedKeywords = mutedKeywords
        self.maskObjectionableContent = maskObjectionableContent
    }

    public static let `default` = ChannelContentFilterHook()

    /// Immediately hides any message authored by a blocked user (`hidesBlockedSenderMessagesImmediately`).
    public func shouldHideMessageImmediately(_ message: MessagingMessage) -> Bool {
        guard let senderID = message.senderID, senderID > 0 else { return false }
        return blockedSenderIDs.contains(senderID)
    }

    /// Evaluates message visibility (`recalled`/`blocked`/`unknown` fail-closed) and masks objectionable terms.
    public func evaluate(message: MessagingMessage) -> ChannelContentFilterEvaluation {
        guard message.isPayloadVisible else {
            let placeholder: String
            switch message.status {
            case .recalled:
                placeholder = "该消息已撤回"
            case .blocked:
                placeholder = "该消息因违反社区安全规范已被屏蔽"
            case .unknown, .normal:
                placeholder = "消息不可用"
            }
            return ChannelContentFilterEvaluation(displayText: placeholder, wasModified: true)
        }

        let rawText = message.content ?? ""
        guard maskObjectionableContent, !rawText.isEmpty else {
            return ChannelContentFilterEvaluation(displayText: rawText, wasModified: false)
        }

        var masked = rawText
        var matched: [String] = []
        for term in mutedKeywords where !term.isEmpty {
            if masked.localizedCaseInsensitiveContains(term) {
                matched.append(term)
                masked = masked.replacingOccurrences(
                    of: term,
                    with: String(repeating: "＊", count: max(2, term.count)),
                    options: [.caseInsensitive]
                )
            }
        }

        return ChannelContentFilterEvaluation(
            displayText: masked,
            wasModified: !matched.isEmpty,
            matchedTerms: matched
        )
    }
}

/// Moderation & safety action descriptors wired to the exact mini-program and backend endpoints.
public enum ChannelSafetyModerationEndpoint: Equatable, Sendable {
    /// `POST /api/im/report` (`message_id`, `reason`)
    case reportMessage(messageID: Int, reason: String)
    /// `POST /api/club/governance/cases/report` (`club_id`, `target_type`, `target_id`, `reason_code`, `detail`)
    case reportClubUser(clubID: Int, targetMemberID: Int, reasonCode: String, detail: String)
    /// `POST /api/im/block` (`target_member_id`)
    case blockUser(targetMemberID: Int)
    /// `POST /api/im/unblock` (`target_member_id`)
    case unblockUser(targetMemberID: Int)
    /// `POST /api/im/mute` (`conversation_id`, `muted`)
    case muteChannel(conversationID: Int, muted: Bool)
    /// Admin/author message deletion or moderation recall inside club channel/community
    case deleteMessage(clubID: Int, channelID: Int, messageID: Int)
    /// `POST /api/club/remove-member` (`club_id`, `member_id`)
    case removeMember(clubID: Int, targetMemberID: Int)
    /// `POST /api/club/governance/ban` (`club_id`, `member_id`, `reason_code`, `reason_text`, `expires_at`)
    case banMember(clubID: Int, targetMemberID: Int, reasonCode: String, reasonText: String)
    /// `POST /api/club/governance/unban` (`club_id`, `ban_id`, `reason`)
    case unbanMember(clubID: Int, banID: Int, reason: String)

    public var apiPath: String {
        switch self {
        case .reportMessage:
            return "api/im/report"
        case .reportClubUser:
            return "api/club/governance/cases/report"
        case .blockUser:
            return "api/im/block"
        case .unblockUser:
            return "api/im/unblock"
        case .muteChannel:
            return "api/im/mute"
        case .deleteMessage:
            return "api/club/post/delete"
        case .removeMember:
            return "api/club/remove-member"
        case .banMember:
            return "api/club/governance/ban"
        case .unbanMember:
            return "api/club/governance/unban"
        }
    }
}

public enum ChannelModerationDenialReason: String, Error, Equatable, Sendable {
    case unauthenticated
    case channelAdmissionRequired
    case channelRevokedOrBanned
    case cannotTargetSelf
    case cannotTargetClubOwner
    case targetHoldsActiveRoleAssignment
    case insufficientModerationPermission
    case platformBanCannotBeUnbannedByClubAdmin
    case invalidMessageOrReason
}

/// Capabilities projected from `ClubGovernancePermissions` or role assignments.
public struct ChannelModerationCapabilities: Equatable, Sendable {
    public let canManageMembers: Bool
    public let canManageBans: Bool
    public let canManageContent: Bool
    public let canManageRoles: Bool

    public init(
        canManageMembers: Bool = false,
        canManageBans: Bool = false,
        canManageContent: Bool = false,
        canManageRoles: Bool = false
    ) {
        self.canManageMembers = canManageMembers
        self.canManageBans = canManageBans
        self.canManageContent = canManageContent
        self.canManageRoles = canManageRoles
    }

    public init(governancePermissions: ClubGovernancePermissions, scope: ClubGovernanceScope) {
        let isOwner = governancePermissions.allows("OWNER", scope: scope)
        let hasWrite = governancePermissions.allows("club:write", scope: scope)
        self.canManageMembers = isOwner || hasWrite || governancePermissions.allows("club:members:manage", scope: scope)
        self.canManageBans = isOwner || hasWrite || governancePermissions.allows("club:bans:manage", scope: scope)
        self.canManageContent = isOwner || hasWrite || governancePermissions.allows("club:content:manage", scope: scope)
        self.canManageRoles = governancePermissions.canManageRoles
    }
}

/// Evaluates user safety (Guideline 1.2) and club admin moderation permissions while preserving `ChannelRulesAdmission` and `ChannelRevokeIsolation`.
public struct ChannelSafetyModerationPolicy: Equatable, Sendable {
    public let clubID: Int
    public let viewerMemberID: Int
    public let viewerRoleTier: ChannelMemberRoleTier
    public let capabilities: ChannelModerationCapabilities
    public let hasAcceptedChannelRules: Bool
    public let isChannelAccessRevoked: Bool

    public init(
        clubID: Int,
        viewerMemberID: Int,
        viewerRoleTier: ChannelMemberRoleTier,
        capabilities: ChannelModerationCapabilities = ChannelModerationCapabilities(),
        hasAcceptedChannelRules: Bool = true,
        isChannelAccessRevoked: Bool = false
    ) {
        self.clubID = clubID
        self.viewerMemberID = viewerMemberID
        self.viewerRoleTier = viewerRoleTier
        self.capabilities = capabilities
        self.hasAcceptedChannelRules = hasAcceptedChannelRules
        self.isChannelAccessRevoked = isChannelAccessRevoked
    }

    public var canModerateMessages: Bool {
        guard viewerMemberID > 0, !isChannelAccessRevoked else { return false }
        return viewerRoleTier == .owner
            || viewerRoleTier == .coOwner
            || viewerRoleTier == .operatorAdmin
            || capabilities.canManageMembers
            || capabilities.canManageContent
    }

    public var canRemoveOrBanMembers: Bool {
        guard viewerMemberID > 0, !isChannelAccessRevoked else { return false }
        return viewerRoleTier == .owner
            || viewerRoleTier == .coOwner
            || viewerRoleTier == .operatorAdmin
            || capabilities.canManageMembers
            || capabilities.canManageBans
    }

    /// Evaluates whether the viewer can report a message (`POST /api/im/report`).
    public func validateReportMessage(
        message: MessagingMessage,
        reason: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard message.id > 0, message.isPayloadVisible else {
            return .failure(.invalidMessageOrReason)
        }
        guard (message.senderID ?? 0) != viewerMemberID else {
            return .failure(.cannotTargetSelf)
        }
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 200 else {
            return .failure(.invalidMessageOrReason)
        }
        return .success(.reportMessage(messageID: message.id, reason: trimmed))
    }

    /// Evaluates whether the viewer can report a user in the club (`POST /api/club/governance/cases/report`, enforces `CU-C-52` no self-report).
    public func validateReportUser(
        targetMemberID: Int,
        reasonCode: String,
        detail: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard targetMemberID > 0, targetMemberID != viewerMemberID else {
            return .failure(.cannotTargetSelf)
        }
        let code = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return .failure(.invalidMessageOrReason) }
        return .success(
            .reportClubUser(
                clubID: clubID,
                targetMemberID: targetMemberID,
                reasonCode: code,
                detail: detail.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    /// Evaluates whether the viewer can block or unblock a user (`POST /api/im/block`, `POST /api/im/unblock`).
    public func validateBlockUser(
        targetMemberID: Int,
        shouldBlock: Bool
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard targetMemberID > 0, targetMemberID != viewerMemberID else {
            return .failure(.cannotTargetSelf)
        }
        return .success(shouldBlock ? .blockUser(targetMemberID: targetMemberID) : .unblockUser(targetMemberID: targetMemberID))
    }

    /// Evaluates whether the viewer can delete/recall a message in a channel.
    public func validateDeleteMessage(
        channelID: Int,
        message: MessagingMessage
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard message.id > 0, message.isPayloadVisible else {
            return .failure(.invalidMessageOrReason)
        }
        let isAuthor = (message.senderID ?? 0) == viewerMemberID
        guard isAuthor || canModerateMessages else {
            return .failure(.insufficientModerationPermission)
        }
        return .success(.deleteMessage(clubID: clubID, channelID: channelID, messageID: message.id))
    }

    /// Evaluates whether an admin can remove a member (`POST /api/club/remove-member`), respecting `ApiClubController.holdsActiveRoleAssignment`.
    public func validateRemoveMember(
        target: ChannelMemberRoleItem
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard canRemoveOrBanMembers else { return .failure(.insufficientModerationPermission) }
        guard target.memberID != viewerMemberID else { return .failure(.cannotTargetSelf) }
        guard target.tier != .owner else { return .failure(.cannotTargetClubOwner) }
        if target.holdsActiveRoleAssignment {
            return .failure(.targetHoldsActiveRoleAssignment)
        }
        return .success(.removeMember(clubID: clubID, targetMemberID: target.memberID))
    }

    /// Evaluates whether an admin can ban a member (`POST /api/club/governance/ban`).
    public func validateBanMember(
        target: ChannelMemberRoleItem,
        reasonCode: String,
        reasonText: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard hasAcceptedChannelRules else { return .failure(.channelAdmissionRequired) }
        guard capabilities.canManageBans || viewerRoleTier == .owner || viewerRoleTier == .coOwner else {
            return .failure(.insufficientModerationPermission)
        }
        guard target.memberID != viewerMemberID else { return .failure(.cannotTargetSelf) }
        guard target.tier != .owner else { return .failure(.cannotTargetClubOwner) }
        let code = reasonCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else { return .failure(.invalidMessageOrReason) }
        return .success(
            .banMember(
                clubID: clubID,
                targetMemberID: target.memberID,
                reasonCode: code,
                reasonText: reasonText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }

    /// Evaluates whether an admin can lift a ban (`POST /api/club/governance/unban`), enforcing `ClubOpsBanRow.platformOnly`.
    public func validateUnbanMember(
        banRow: ClubOpsBanRow,
        reason: String
    ) -> Result<ChannelSafetyModerationEndpoint, ChannelModerationDenialReason> {
        guard viewerMemberID > 0 else { return .failure(.unauthenticated) }
        guard !isChannelAccessRevoked else { return .failure(.channelRevokedOrBanned) }
        guard capabilities.canManageBans || viewerRoleTier == .owner || viewerRoleTier == .coOwner else {
            return .failure(.insufficientModerationPermission)
        }
        if banRow.platformOnly {
            return .failure(.platformBanCannotBeUnbannedByClubAdmin)
        }
        return .success(
            .unbanMember(
                clubID: clubID,
                banID: banRow.id,
                reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        )
    }
}

// MARK: - Clubs Tab & Club Admin Parity Summary (Deliverables 1 & 4)

public struct ClubAdminSurfaceContractStatus: Equatable, Sendable, Identifiable {
    public var id: String { surfaceKey }
    public let surfaceKey: String
    public let miniProgramRoute: String
    public let title: String
    public let backendEndpoints: [String]
    public let isReadOnlyFallback: Bool
    public let flaggedOffFeatureNote: String?

    public init(
        surfaceKey: String,
        miniProgramRoute: String,
        title: String,
        backendEndpoints: [String],
        isReadOnlyFallback: Bool = false,
        flaggedOffFeatureNote: String? = nil
    ) {
        self.surfaceKey = surfaceKey
        self.miniProgramRoute = miniProgramRoute
        self.title = title
        self.backendEndpoints = backendEndpoints
        self.isReadOnlyFallback = isReadOnlyFallback
        self.flaggedOffFeatureNote = flaggedOffFeatureNote
    }
}

public enum ClubTabAndAdminParityCatalog {
    /// Deliverable 1: Clubs tab (`pages/talent/list` + `pages/club/*`) parity surfaces.
    public static let clubsTabSurfaces: [ClubAdminSurfaceContractStatus] = [
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.list",
            miniProgramRoute: "pages/talent/list/index",
            title: "俱乐部发现与列表",
            backendEndpoints: ["api/club/list", "api/club/my"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.detail",
            miniProgramRoute: "pages/club/detail/index",
            title: "俱乐部主页与内嵌频道",
            backendEndpoints: ["api/club/detail", "api/club/channels"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.apply_join",
            miniProgramRoute: "pages/club/apply/index",
            title: "加入/申请加入俱乐部",
            backendEndpoints: ["api/club/join", "api/club/join-requests/apply", "api/club/quit"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.enroll",
            miniProgramRoute: "pages/club/enroll/index",
            title: "俱乐部活动报名与候补",
            backendEndpoints: ["api/club/activity/join", "api/club/activity/cancel", "api/club/activity/detail"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.create_edit",
            miniProgramRoute: "pages/club/create/index",
            title: "创建与编辑俱乐部",
            backendEndpoints: ["api/club/create", "api/club/update"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.roles",
            miniProgramRoute: "pages/club/roles/index",
            title: "角色与权限委派",
            backendEndpoints: ["api/club/roles", "api/club/roles/assign", "api/club/roles/revoke"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.badges",
            miniProgramRoute: "pages/club/badges/index",
            title: "俱乐部徽章与成长体系",
            backendEndpoints: ["api/club/badges", "api/club/badges/save", "api/club/badges/grant"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.notices",
            miniProgramRoute: "pages/club/notify/index",
            title: "俱乐部公告与通知历史",
            backendEndpoints: ["api/club/notices", "api/club/notices/send"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.group_code",
            miniProgramRoute: "pages/club/group-code/index",
            title: "俱乐部入群码配置",
            backendEndpoints: ["api/club/group-code", "api/club/group-code/save"]
        )
    ]

    /// Deliverable 4: Club Admin (`workbench`, `customers`, `event-ops`, `join-requests`, `settlement` read-only with bank withdrawal flagged off).
    public static let clubAdminSurfaces: [ClubAdminSurfaceContractStatus] = [
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.workbench",
            miniProgramRoute: "pages/club/workbench/index",
            title: "主理人工作台（统一收敛至俱乐部管理 Tab）",
            backendEndpoints: ["api/club/workbench", "api/club/detail?tab=manage"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.customers",
            miniProgramRoute: "pages/club/customers/index",
            title: "客户资产与精细化CRM画像（只读视图）",
            backendEndpoints: ["api/club/customers", "api/club/customers/summary"],
            isReadOnlyFallback: true
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.event_ops",
            miniProgramRoute: "pages/club/event-ops/index",
            title: "赛事/活动排期、核销与代报",
            backendEndpoints: [
                "api/club/events",
                "api/club/events/save",
                "api/club/events/Checkin",
                "api/club/events/proxy-enroll"
            ]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.join_requests",
            miniProgramRoute: "pages/club/join-requests/index",
            title: "入会申请审批队列",
            backendEndpoints: ["api/club/join-requests", "api/club/join-requests/review"]
        ),
        ClubAdminSurfaceContractStatus(
            surfaceKey: "club.admin.settlement",
            miniProgramRoute: "pages/club/settlement/index",
            title: "俱乐部收支与结算流水（只读对账）",
            backendEndpoints: ["api/club/settlements", "api/club/settlements/export"],
            isReadOnlyFallback: true,
            flaggedOffFeatureNote: "pages/coop/withdraw 银行卡提现已按规范 Flagged Off，仅保留俱乐部结算单与订单分成只读核对。"
        )
    ]
}
